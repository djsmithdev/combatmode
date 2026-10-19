---------------------------------------------------------------------------------------
--  UI/Options/OptionsPanel.lua — OPTIONS — standalone options shell
---------------------------------------------------------------------------------------
--  What it does: Owns CombatModeOptionsFrame — sidebar tabs, content host, left-of-center
--  dock, instant tab switching, and footer utilities (Silence Alerts / Debug Mode,
--  Changelog / Reset / Uninstall).
--  Title bar carries the options search box (OptionsSearch.lua). Layout ctx tags controls
--  with search metadata (label, desc, tab, segment group) for it.
--  Exposes CM.OpenOptions / Close / Toggle / GetOptionsFrame and UI.Options.AddTab,
--  plus SelectTabById, GetTabScroll and RegisterSegmentSelector for search navigation.
--  Architecture / how it works:
--    • AddTab({id, label, newFeatureFlag?, build, onSelect, onDeselect}) — tabs register
--      at load; newFeatureFlag draws the Horde "NEW" badge on the tab button (far right).
--      In-content headers/options use Alliance via Widgets `newFeatureFlag`.
--      onSelect/onDeselect drive Crosshair / Ally Cycle preview.
--    • ctx:WatermarkPage(text) stamps the tab scroll viewport (same overlay as
--      per-row watermarkWhenDisabled) so a whole page can be inert.
--    • Layout ctx passed to build() wraps Widgets factories.
--    • Combat-guarded open where needed; not a Blizzard Settings host.
--  Does not: Own per-feature option wiring (Tabs/*) or changelog body text.
--  Related: UI/Options/Draw.lua, UI/Options/Widgets.lua,
--  UI/Options/BlizzardSettingsBridge.lua, UI/Changelog/ChangelogPanel.lua,
--  Core/Runtime/Runtime.lua, UI/Options/Tabs/TabCrosshair.lua,
--  UI/Options/Tabs/TabAllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local floor = _G.math.floor
local max = _G.math.max
local type = _G.type

local UI = CM.UI
local C = UI.Colors
UI.Options = UI.Options or {}
local Options = UI.Options
Options.tabDefs = Options.tabDefs or {}

local WINDOW_W, WINDOW_H = 820, 560
local SIDEBAR_W = 186
local CONTENT_PAD = 14
-- Distance from the window edge to the right edge of the page scroll bars (flush to the frame).
local SCROLLBAR_INSET = 6
-- Header right buttons (community links, close): icon size, and the header's vertical centre.
local HEADER_BUTTON_SIZE = 22
local HEADER_CLOSE_SIZE = 32
local HEADER_CENTER_Y = 30
-- Gap above and below the page scroll bars (so they clear the header line and the frame).
local SCROLLBAR_PAD_Y = 10
-- Space under the last row of a tab, inside the scrolling content.
local TAB_BOTTOM_PAD = 24
-- Height of the brand title art in the header (the header band is 59px tall).
local TITLE_ART_H = 56
-- Background of the logo container in the header.
local BRAND_BG_ATLAS = "housing-floor-list-bg-active"
-- How far the atlas extends past the cell (clipped): wider than tall, since the cell is wide.
local BRAND_BG_BLEED_X = 56
local BRAND_BG_BLEED_Y = 32
-- Space between the sidebar divider and the page content (mockup: ~15px).
local CONTENT_LEFT = 15

local frame
local chrome
local tabs = {}
local activeTab
local tabActivated = false

--- Parks the window left of screen center so the crosshair and companions stay clear
--- for live options previews. On wide displays it sits farther in from the left edge;
--- on narrower ones it clamps to a small left inset. Called on every OpenOptions; drag is
--- still allowed during the session but the next open re-docks (position is not persisted).
function Options.DockWindowLeft()
  if not frame then
    return
  end
  local parent = _G.UIParent
  local parentW = parent:GetWidth() or 0
  local panelW = frame:GetWidth() or WINDOW_W
  local leftPad = 24
  -- Keep clearance past the crosshair + Ally HUD / companion chrome.
  local clearFromCenter = 280
  local maxRight = (parentW * 0.5) - clearFromCenter
  local x = maxRight - panelW
  if x < leftPad then
    x = leftPad
  end
  frame:ClearAllPoints()
  frame:SetPoint("LEFT", parent, "LEFT", x, 0)
end

--- Tab registration entry point for UI/Options/Tabs/*.lua.
--- def = { id, label, newFeatureFlag?, build = function(ctx) end,
---         onSelect = function() end, onDeselect = function() end }
--- onSelect/onDeselect also fire when the window is shown/hidden on that tab, so tabs can
--- own transient side effects (e.g. the Crosshair tab's live reticle preview).
function Options.AddTab(def)
  Options.tabDefs[#Options.tabDefs + 1] = def
end

---------------------------------------------------------------------------------------
--                              VERTICAL LAYOUT MANAGER                              --
---------------------------------------------------------------------------------------
-- Gap between consecutive placed controls (options, headers, cards, buttons).
local ITEM_GAP = 12

local function NewLayout(content, width, clip)
  local ctx = { content = content, width = width, y = -8, clip = clip, gap = ITEM_GAP }
  -- Placement records, used by ctx:Reflow() for rows that can be hidden (`hidden` option).
  ctx.items = {}

  --- Dim + block the visible page (scroll viewport, or content if no clip).
  function ctx:WatermarkPage(text)
    if type(text) == "table" then
      text = text.text
    end
    local parent = self.clip or self.content
    if not parent or not UI.CreateWatermark then
      return nil
    end
    local mark = UI.CreateWatermark(parent, text or "Unavailable", UI.Fonts.header)
    mark:Show()
    self.pageWatermark = mark
    return mark
  end

  function ctx:PlaceFrame(childFrame, height, hidden)
    if self.originY == nil then
      self.originY = self.y
    end
    self.items[#self.items + 1] = { frame = childFrame, height = height, hidden = hidden }
    -- The open section (see ctx:Header) extends to the last frame placed under it.
    if self.sectionRec then
      self.sectionRec.lastFrame = childFrame
    end
    childFrame:ClearAllPoints()
    childFrame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, self.y)
    childFrame:SetWidth(self.width)
    self.y = self.y - height - self.gap
    -- A row with a `hidden` predicate makes this layout re-flow whenever options sync.
    if hidden and not self.reflowHooked then
      self.reflowHooked = true
      Options.AddReflowHook(function()
        self:Reflow()
      end)
    end
  end

  --- Re-places every row, skipping (and hiding) those whose `hidden()` is true, so the
  --- rows below move up. Only meaningful for layouts that place everything via PlaceFrame
  --- and Gap (e.g. the Click Casting panels).
  function ctx:Reflow()
    if self.originY == nil then
      return
    end
    local y = self.originY
    for _, item in ipairs(self.items) do
      if item.spacer then
        y = y - item.spacer
      elseif item.hidden and item.hidden() then
        item.frame:Hide()
      else
        item.frame:Show()
        item.frame:ClearAllPoints()
        item.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, y)
        y = y - item.height - self.gap
      end
    end
    self.y = y
  end

  --- Records what the options search needs (label, description, owning tab / segment)
  --- on a control built from `o`. Only layouts with `self.search` set are searchable.
  local function TagSearch(self, control, o)
    if not self.search or not o or type(o.label) ~= "string" then
      return control
    end
    local label = UI.StripColors(o.label)
    if not label or label == "" then
      return control
    end
    local desc = o.desc
    if type(desc) == "function" then
      local ok, value = pcall(desc)
      desc = ok and value or nil
    end
    control.search = {
      label = (self.search.prefix or "") .. label,
      desc = type(desc) == "string" and UI.StripColors(desc) or nil,
      tab = self.search.tab,
      group = self.search.group,
      footer = self.search.footer,
      section = self.section,
    }
    return control
  end

  function ctx:Place(control, o)
    if control.SetWidthTo then
      control.SetWidthTo(self.width)
    end
    self:PlaceFrame(control.frame, control.height, o and o.hidden)
    return TagSearch(self, control, o)
  end

  function ctx:Header(text)
    -- Remember the section so the options search can match (and list) its options by name.
    local name = type(text) == "table" and (text.text or text.label) or text
    self.section = UI.StripColors(name)
    -- The previous section ends before this header, so close it before placing.
    self.sectionRec = nil
    local control = self:Place(UI.MakeHeader(self.content, text))
    if self.search and self.section and self.section ~= "" then
      self.sectionRec = {
        label = self.section,
        tab = self.search.tab,
        group = self.search.group,
        header = control,
        lastFrame = control.frame,
      }
      Options.sections[#Options.sections + 1] = self.sectionRec
    end
    return control
  end
  function ctx:Description(text)
    return self:Place(UI.MakeDescription(self.content, text))
  end
  function ctx:Toggle(o)
    return self:Place(UI.MakeToggle(self.content, o), o)
  end
  function ctx:Slider(o)
    return self:Place(UI.MakeSlider(self.content, o), o)
  end
  function ctx:Dropdown(o)
    return self:Place(UI.MakeDropdown(self.content, o), o)
  end
  function ctx:Keybind(o)
    return self:Place(UI.MakeKeybind(self.content, o), o)
  end
  function ctx:TextInput(o)
    return self:Place(UI.MakeTextInput(self.content, o), o)
  end
  function ctx:SpellMultiSelect(o)
    return self:Place(UI.MakeSpellMultiSelect(self.content, o), o)
  end
  function ctx:MountMultiSelect(o)
    return self:Place(UI.MakeMountMultiSelect(self.content, o), o)
  end
  function ctx:FrameMultiSelect(o)
    return self:Place(UI.MakeFrameMultiSelect(self.content, o), o)
  end
  function ctx:Button(o)
    local control = UI.MakeButton(self.content, o)
    -- Row-style option buttons share the toggle/dropdown layout (title left, control right).
    if o.layout == "row" then
      return self:Place(control, o)
    end
    -- Full-width footer-style buttons span the content width; compact pills keep a fixed width.
    if o.width == "full" then
      if control.SetWidthTo then
        control.SetWidthTo(self.width)
      end
      self:PlaceFrame(control.frame, control.height)
    else
      control.frame:ClearAllPoints()
      control.frame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, self.y)
      if control.SetWidthTo then
        control.SetWidthTo(self.width)
      else
        control.frame:SetWidth(o.pixelWidth or 200)
        control.frame:SetHeight(control.height)
      end
      self.y = self.y - control.height - self.gap
      if self.sectionRec then
        self.sectionRec.lastFrame = control.frame
      end
    end
    return TagSearch(self, control, o)
  end

  --- Places two or more buttons on one horizontal row, splitting the content width evenly.
  --- Each entry is a normal MakeButton opts table (label, func, confirm, …).
  function ctx:ButtonRow(buttons)
    local n = #buttons
    if n == 0 then
      return
    end
    local gap = 8
    local btnW = floor((self.width - gap * (n - 1)) / n)
    local host = CreateFrame("Frame", nil, self.content)
    local rowH = 0
    local x = 0
    for _, o in ipairs(buttons) do
      o.pixelWidth = btnW
      o.width = nil
      local control = UI.MakeButton(host, o)
      control.frame:ClearAllPoints()
      control.frame:SetPoint("TOPLEFT", host, "TOPLEFT", x, 0)
      if control.SetWidthTo then
        control.SetWidthTo(btnW)
      else
        control.frame:SetWidth(btnW)
        control.frame:SetHeight(control.height)
      end
      -- MakeButton only expands the inner button for width="full"; force equal columns here.
      control.button:SetWidth(btnW)
      rowH = max(rowH, control.height)
      x = x + btnW + gap
    end
    host:SetHeight(rowH)
    self:PlaceFrame(host, rowH)
    return host
  end

  function ctx:Gap(h)
    if self.originY == nil then
      self.originY = self.y
    end
    self.items[#self.items + 1] = { spacer = h or 10 }
    self.y = self.y - (h or 10)
  end

  --- Inline group card with a title and its own nested layout.
  function ctx:Card(titleText, buildInner)
    local card = UI.CreateCard(self.content)
    local title
    local topPad = 8
    if titleText and titleText ~= "" then
      title = UI.CreateFontString(card, "OVERLAY", UI.Fonts.base, "GameFontNormal")
      title:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -8)
      title:SetText(UI.StripColors(titleText) or "")
      title:SetTextColor(C.text[1], C.text[2], C.text[3])
      topPad = 26
    end

    local inner = CreateFrame("Frame", nil, card)
    inner:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -topPad)
    inner:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -topPad)

    local innerCtx = NewLayout(inner, self.width - 24)
    innerCtx.y = -4
    innerCtx.search = self.search
    buildInner(innerCtx)
    local usedInner = -innerCtx.y + 4
    inner:SetHeight(usedInner)

    local cardHeight = topPad + usedInner + 8
    card:SetHeight(cardHeight)
    self:PlaceFrame(card, cardHeight)
    return card
  end

  function ctx:Finish()
    -- PlaceFrame always subtracts the item gap after the last control; drop that trailing
    -- gap so content height matches the visible widgets (avoids a phantom scrollbar and
    -- empty space under the final row).
    local height = -self.y - self.gap
    if height < 1 then
      height = 1
    end
    self.content:SetHeight(height)
  end

  return ctx
end

-- Exposed so standalone editors (e.g. the prelines editor) can reuse the layout.
UI.NewLayout = NewLayout

--- Builds the standalone rounded, movable window chrome (title bar + close X) with no
--- content region. Used directly by editors that manage their own custom layout.
function UI.CreateBareWindow(globalName, titleText, width, height)
  local win = CreateFrame("Frame", globalName, UIParent)
  win:SetSize(width, height)
  win:SetFrameStrata("DIALOG")
  win:SetToplevel(true)
  UI.StyleWindow(win)
  UI.BlockBehindTooltips(win)
  win:SetPoint("CENTER")

  local titleBar = CreateFrame("Frame", nil, win)
  titleBar:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
  titleBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", -12, -10)
  titleBar:SetHeight(24)

  local title = UI.CreateFontString(titleBar, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  title:SetPoint("LEFT", titleBar, "LEFT", 30, 0)
  -- Same treatment as section headers: uppercase cream title over a fading accent rule.
  -- Callers pass "<addon title markup (atlas + texture escapes)> - Panel Name"; keep only the
  -- panel name (uppercasing the escapes would corrupt them). The logo sits to its left.
  local panelName = (UI.StripColors(titleText) or "")
    :gsub("|[Aa].-|[Aa]", "")
    :gsub("|T.-|t", "")
    :gsub("^%s*%-?%s*", "")
  title:SetText(panelName:upper())
  title:SetTextColor(C.text[1], C.text[2], C.text[3])

  local logo = titleBar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(CM.Constants.Logo)
  logo:SetSize(24, 24)
  logo:SetPoint("LEFT", titleBar, "LEFT", 0, 0)

  local rule = UI.CreateLine(win, false, C.headerRule, "fade")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -36)
  rule:SetPoint("TOPRIGHT", win, "TOPRIGHT", -12, -36)

  UI.EnableDrag(win, titleBar, false)
  UI.EnableEscClose(win, globalName)

  local closeX = UI.CreateCloseButton(win)
  closeX:SetPoint("TOPRIGHT", win, "TOPRIGHT", -8, -8)

  win.titleBar = titleBar
  win.titleText = title
  return win
end

--- Builds a standalone rounded, movable window (title bar + close X + content)
--- and returns (window, ctx). Used by editors that are not tabs of the main panel.
--- opts.noScroll = true → plain content frame (no window scrollbar); size with
--- UI.SizeWindowToContent after ctx:Finish(). Default is a scroll pane.
function UI.CreateWindow(globalName, titleText, width, height, opts)
  opts = opts or {}
  local win = UI.CreateBareWindow(globalName, titleText, width, height)

  local contentWidth
  local content
  local scroll

  if opts.noScroll then
    -- Fixed layout: content is a normal frame, not a ScrollFrame child.
    contentWidth = width - 28
    content = CreateFrame("Frame", nil, win)
    content:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -44)
    content:SetWidth(contentWidth)
    content:SetHeight(10)
  else
    scroll, content = UI.CreateScrollFrame(win)
    scroll:SetPoint("TOPLEFT", win, "TOPLEFT", 14, -44)
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -22, 0)
    scroll.cmScrollBar:SetPoint("TOP", scroll, "TOP", 0, -SCROLLBAR_PAD_Y)
    scroll.cmScrollBar:SetPoint("BOTTOM", scroll, "BOTTOM", 0, SCROLLBAR_PAD_Y)
    scroll.cmScrollBar:SetPoint("RIGHT", win, "RIGHT", -SCROLLBAR_INSET, 0)

    contentWidth = width - 22 - CONTENT_PAD
    content:SetSize(contentWidth, 10)

    win:EnableMouseWheel(true)
    win:SetScript("OnMouseWheel", function(_, delta)
      if scroll.cmScrollTo then
        local current = scroll.cmGetTargetScroll and scroll.cmGetTargetScroll()
          or scroll:GetVerticalScroll()
        scroll.cmScrollTo(current - delta * 72, false)
      end
    end)
    win:HookScript("OnShow", function()
      if scroll.cmUpdate then
        scroll.cmUpdate()
      end
    end)
  end

  local ctx = NewLayout(content, contentWidth, scroll)
  if scroll then
    -- The scroll area runs to the window edge, so the content carries its own bottom padding.
    local finish = ctx.Finish
    function ctx:Finish()
      finish(self)
      content:SetHeight(content:GetHeight() + TAB_BOTTOM_PAD)
    end
  end
  win.ctx = ctx
  win.content = content
  win.scroll = scroll
  win.cmNoScroll = opts.noScroll and true or nil
  return win, ctx
end

--- Sizes a CreateWindow shell to its laid-out content height (call after ctx:Finish()).
--- Chrome matches CreateWindow anchors: TOP -44 / BOTTOM +14.
function UI.SizeWindowToContent(win)
  if not win or not win.content then
    return
  end
  local contentH = win.content:GetHeight() or 0
  win:SetHeight(contentH + 44 + 14)
  if win.scroll and win.scroll.cmUpdate then
    win.scroll.cmUpdate()
  end
end

--- Outer height for the Prelines editor, which measures once via
--- SizeWindowToContent and publishes with UI.SetSecondaryEditorHeight.
UI.SecondaryEditorHeight = nil

function UI.GetSecondaryEditorHeight()
  if UI.SecondaryEditorHeight and UI.SecondaryEditorHeight > 1 then
    return UI.SecondaryEditorHeight
  end
  local prelines = _G.CombatModeTargetingMacroPrelinesEditor
  if prelines then
    local h = prelines:GetHeight()
    if h and h > 1 then
      UI.SecondaryEditorHeight = h
      return h
    end
  end
  -- Provisional until the Prelines editor is built and sized to content.
  return 340
end

function UI.SetSecondaryEditorHeight(height)
  if type(height) ~= "number" or height < 1 then
    return
  end
  UI.SecondaryEditorHeight = height
  local prelines = _G.CombatModeTargetingMacroPrelinesEditor
  if prelines then
    prelines:SetHeight(height)
  end
end

-- Back-compat alias used by the first fit pass.
UI.SizeWindowToScrollContent = UI.SizeWindowToContent

---------------------------------------------------------------------------------------
--                                  SHELL BUILDERS                                   --
---------------------------------------------------------------------------------------
-- Tab states are monochrome: unselected is dim grey on transparent, selected is a faint
-- grey wash with accent-yellow text.
-- onSelect/onDeselect are paired: they fire on tab switches and on window show/hide, but
-- never twice in a row for the same tab.
local function ActivateTab()
  if tabActivated or not activeTab then
    return
  end
  tabActivated = true
  if activeTab.def.onSelect then
    activeTab.def.onSelect()
  end
end

local function DeactivateTab()
  if UI.Options.CancelKeybindCapture then
    UI.Options.CancelKeybindCapture()
  end
  if not tabActivated then
    return
  end
  tabActivated = false
  if activeTab and activeTab.def.onDeselect then
    activeTab.def.onDeselect()
  end
end

local function SelectTab(tab)
  if activeTab == tab and tab.scroll:IsShown() then
    return
  end

  DeactivateTab()
  -- onSelect previews only fire while the shell is shown; pre-show selects skip them.
  local shown = frame and frame:IsShown()

  for _, t in ipairs(tabs) do
    t.selected = (t == tab)
    t.button:cmSetTabSelected(t == tab)
    if t ~= tab then
      t.scroll:SetScript("OnUpdate", nil)
      t.scroll:Hide()
      if t.bar then
        t.bar:SetScript("OnUpdate", nil)
        t.bar:Hide()
      end
    end
  end

  tab.scroll:SetScript("OnUpdate", nil)
  tab.scroll:Show()
  if tab.scroll.cmUpdate then
    tab.scroll.cmUpdate()
  end

  activeTab = tab
  if shown then
    ActivateTab()
  end
end

local function FindTab(id)
  for _, t in ipairs(tabs) do
    if t.def.id == id then
      return t
    end
  end
end

--- Switches the sidebar to the tab with `id`. Used by the options search.
function Options.SelectTabById(id)
  local tab = FindTab(id)
  if tab then
    SelectTab(tab)
  end
end

--- Scroll ScrollFrame of the tab with `id` (nil if unknown). Used by the options search.
function Options.GetTabScroll(id)
  local tab = FindTab(id)
  return tab and tab.scroll
end

--- Sidebar button of the tab with `id` (nil if unknown). Used by the setup wizard tour.
function Options.GetTabButton(id)
  local tab = FindTab(id)
  return tab and tab.button
end

local FOCUS_SCROLL_PAD = 24

--- Control registered on tab `tabId` labelled `label` (first control of the tab / group when
--- `label` is nil or not found). Used by the setup wizard tour.
function Options.FindControl(tabId, label, group)
  local first
  for _, control in ipairs(Options.controls) do
    local search = control.search
    if search and search.tab == tabId and (not group or search.group == group) then
      first = first or control
      if label and search.label == label then
        return control
      end
    end
  end
  return first
end

--- Selects tab `tabId` (and Click Casting segment `group`), scrolls the control labelled
--- `label` into view and returns its frame; falls back to the tab's sidebar button. Used by
--- the setup wizard tour.
function Options.FocusControl(tabId, label, group)
  Options.SelectTabById(tabId)
  local selectSegment = group and Options.segmentSelectors[tabId]
  if selectSegment then
    selectSegment(group)
  end
  local found = Options.FindControl(tabId, label, group)
  if not found then
    return Options.GetTabButton(tabId)
  end
  local tabScroll = Options.GetTabScroll(tabId)
  local rowTop = found.frame:GetTop()
  local contentTop = tabScroll and tabScroll:GetScrollChild():GetTop()
  if tabScroll and rowTop and contentTop and tabScroll.cmScrollTo then
    tabScroll.cmScrollTo(contentTop - rowTop - FOCUS_SCROLL_PAD, true)
  end
  return found.frame
end

--- Selects tab `tabId`, scrolls the section headed `label` (a ctx:Header title) to the top and
--- returns { header frame, last frame of the section }, or nil. Used by the setup wizard tour.
function Options.FocusSection(tabId, label)
  Options.SelectTabById(tabId)
  for _, section in ipairs(Options.sections) do
    if section.tab == tabId and section.label == label then
      local header = section.header.frame
      local tabScroll = Options.GetTabScroll(tabId)
      local headerTop = header:GetTop()
      local contentTop = tabScroll and tabScroll:GetScrollChild():GetTop()
      if tabScroll and headerTop and contentTop and tabScroll.cmScrollTo then
        tabScroll.cmScrollTo(contentTop - headerTop - FOCUS_SCROLL_PAD, true)
      end
      return { header, section.lastFrame }
    end
  end
end

--- Segment bars (e.g. Click Casting modifiers) register a selector so search can switch
--- to the segment that owns a result. `select(groupId)` must update the bar and content.
Options.segmentSelectors = Options.segmentSelectors or {}
function Options.RegisterSegmentSelector(tabId, select)
  Options.segmentSelectors[tabId] = select
end

local function BuildSidebarButton(def, index)
  local button = CreateFrame("Button", nil, frame)
  -- Mockup: 148x29 rows, 32px pitch, first row centred ~80px below the window top.
  button:SetSize(SIDEBAR_W - 18, 34)
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -72 - (index - 1) * 38)
  local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.nav, "GameFontNormal")
  label:SetPoint("LEFT", button, "LEFT", 20, 0)
  label:SetText(UI.StripColors(def.label) or "")
  button.label = label

  -- Shared tab look (selected pill, orange capsule marker, hover wash).
  UI.StyleTab(button, label, 20)

  -- Shared "NEW" badge — Horde atlas, far right of the tab button.
  if def.newFeatureFlag and UI.CreateNewFeatureBadge then
    local badge = UI.CreateNewFeatureBadge(button)
    badge:ClearAllPoints()
    badge:SetPoint("TOPLEFT", label, "TOPRIGHT", UI.NewFeatureBadge.gap, UI.NewFeatureBadge.lift)
    button.badge = badge
  end

  return button
end

local function BuildTab(def, index)
  local scroll, content = UI.CreateScrollFrame(frame)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W + CONTENT_LEFT, -61)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 0)
  -- The bar is shorter than the scroll area so it does not touch the header line or the frame.
  scroll.cmScrollBar:SetPoint("TOP", scroll, "TOP", 0, -SCROLLBAR_PAD_Y)
  scroll.cmScrollBar:SetPoint("BOTTOM", scroll, "BOTTOM", 0, SCROLLBAR_PAD_Y)
  scroll.cmScrollBar:SetPoint("RIGHT", frame, "RIGHT", -SCROLLBAR_INSET, 0)

  local contentWidth = WINDOW_W - SIDEBAR_W - CONTENT_LEFT - 22
  content:SetSize(contentWidth, 10)

  local ctx = NewLayout(content, contentWidth, scroll)
  ctx.search = { tab = def.id }
  def.build(ctx)
  ctx:Finish()
  -- The scroll area runs to the window edge, so the content carries its own bottom padding:
  -- the last row can be scrolled fully into view with a little room below it.
  content:SetHeight(content:GetHeight() + TAB_BOTTOM_PAD)

  local tab = { def = def, scroll = scroll, bar = scroll.cmScrollBar }
  tab.button = BuildSidebarButton(def, index)
  tab.button:SetScript("OnClick", function()
    SelectTab(tab)
  end)
  tabs[#tabs + 1] = tab
  return tab
end

--- Utility controls pinned to the bottom of the sidebar (formerly the About tab): the
--- silence-alerts / debug toggles and the changelog / reset / uninstall buttons.
local function BuildSidebarFooter()
  -- Footer buttons are inset from the sidebar edges (x=13), pinned near the window bottom.
  local footerW = SIDEBAR_W - 26
  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 13, 8)
  footer:SetWidth(footerW)

  local fctx = NewLayout(footer, footerW)
  fctx.y = 0
  fctx.gap = 5
  fctx.search = { footer = true }

  fctx:Toggle({
    label = "Silence Alerts",
    compact = true,
    descBelow = true,
    get = function()
      return CM.DB.global.silenceAlerts
    end,
    set = function(value)
      CM.DB.global.silenceAlerts = value
    end,
  })
  fctx:Toggle({
    label = "Debug Mode",
    compact = true,
    descBelow = true,
    get = function()
      return CM.DB.global.debugMode
    end,
    set = function(value)
      CM.DB.global.debugMode = value
      if value then
        if CM.StartProfiling then
          CM.StartProfiling()
        end
      else
        if CM.StopAndReportProfiling then
          CM.StopAndReportProfiling()
        end
      end
    end,
  })
  fctx:Gap(4)
  fctx:Button({
    label = "Reset to Defaults",
    width = "full",
    confirm = true,
    confirmText = "Reset all Action Combat Mode settings to defaults and reload?",
    func = function()
      CM:OnResetDB()
    end,
  })
  fctx:Button({
    label = "Uninstall",
    width = "full",
    danger = true,
    confirm = true,
    confirmText = "Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload.",
    func = function()
      if CM.UninstallCombatMode then
        CM.UninstallCombatMode()
      end
    end,
  })

  footer:SetHeight(-fctx.y)

  -- Divider separating the tab list from the footer utilities.
  local sep = UI.CreateLine(chrome, false, C.divider, "ends")
  sep:SetHeight(1)
  sep:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 10)
  sep:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 10)
end

local function RefreshActiveTabScroll()
  if not activeTab or not activeTab.scroll then
    return
  end
  if activeTab.scroll.cmUpdate then
    activeTab.scroll.cmUpdate()
  end
  if activeTab.bar and activeTab.bar:IsShown() then
    activeTab.bar:SetAlpha(1)
  end
end

local function BuildShell()
  frame = CreateFrame("Frame", "CombatModeOptionsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(WINDOW_W, WINDOW_H)
  frame:SetFrameStrata("HIGH")
  frame:SetToplevel(true)
  -- Stay hidden until OpenOptions. Frames default to shown; if SelectTab runs while
  -- shown it snaps the tab in, and a premature cmUpdate can leave the bar permanently
  -- invisible until the next tab switch.
  frame:Hide()
  -- 2px orange-brown frame (fill inset 2) like the mockup.
  UI.StyleWindow(frame)
  UI.BlockBehindTooltips(frame)
  Options.DockWindowLeft()

  -- Background zones (header lighter, sidebar darker, page = window fill). Created first so
  -- everything else draws over them; only their outer corners are rounded, matching the
  -- window's inner radius, so they never poke out of the frame.
  local innerRadius = UI.Radius.window
  local headerZone =
    UI.CreateZone(frame, C.headerBg, innerRadius, { TOPLEFT = true, TOPRIGHT = true })
  headerZone:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  headerZone:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  headerZone:SetHeight(60)
  local sidebarZone = UI.CreateZone(frame, C.sidebarBg, innerRadius, { BOTTOMLEFT = true })
  sidebarZone:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -61)
  sidebarZone:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  sidebarZone:SetWidth(SIDEBAR_W - 4)
  headerZone:cmSetFillGradient(C.headerBgTop, C.headerBgBottom)
  sidebarZone:cmSetFillGradient(C.sidebarBgTop, C.sidebarBgBottom)
  -- The zones cover the window-level inner shadow, so continue it across each of them.
  UI.AddZoneShadow(headerZone, frame)
  UI.AddZoneShadow(sidebarZone, frame)

  -- Chrome overlay: hairlines live here, not on the window itself.
  -- A frame's own textures draw below its child frames, so anything attached directly to
  -- the window would be hidden under the zones above.
  chrome = CreateFrame("Frame", nil, frame)
  chrome:SetAllPoints(frame)

  -- Title bar (drag handle): search left, title centre, links right (centre ~27px down).
  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -15)
  titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -15)
  titleBar:SetHeight(30)

  -- Hairline under the header band.
  local headerLine = UI.CreateLine(chrome, false, C.divider, "ends")
  headerLine:SetHeight(1)
  headerLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -60)
  headerLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -60)

  -- Brand cell: the title art, centred over the sidebar (same width as the side panel), then a
  -- vertical divider, then the version chip and the search box beyond it.
  local brand = CreateFrame("Frame", nil, titleBar)
  local artW, artH = CM.Constants.TitleSize(TITLE_ART_H)
  local titleArt = brand:CreateTexture(nil, "ARTWORK")
  titleArt:SetTexture(CM.Constants.Title)
  titleArt:SetSize(artW, artH)
  titleArt:SetPoint("CENTER", brand, "CENTER", 0, 0)
  -- The brand cell is a container over the sidebar column (inset a few pixels so it clears the
  -- window frame and divider) with a background atlas behind the logo.
  brand:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  brand:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", SIDEBAR_W - 4, -60)
  if CM.GetAtlasInfo(BRAND_BG_ATLAS) then
    -- Drawn larger than the cell and clipped to it, so the atlas fills the container (its own
    -- soft edges / padding fall outside the visible area).
    brand:SetClipsChildren(true)
    local brandBg = brand:CreateTexture(nil, "BACKGROUND")
    CM.SetAtlas(brandBg, BRAND_BG_ATLAS, false)
    brandBg:SetPoint("TOPLEFT", brand, "TOPLEFT", -BRAND_BG_BLEED_X, BRAND_BG_BLEED_Y)
    brandBg:SetPoint("BOTTOMRIGHT", brand, "BOTTOMRIGHT", BRAND_BG_BLEED_X, -BRAND_BG_BLEED_Y)
  end
  -- Version number as a button: the control surface with a copper outline. Clicking it opens
  -- the changelog (there is no separate changelog button).
  local chip = CreateFrame("Button", nil, titleBar)
  UI.StyleControl(chip, nil, UI.Radius.control)
  chip:SetScript("OnEnter", function(self)
    self:cmControlHover(true)
  end)
  chip:SetScript("OnLeave", function(self)
    self:cmControlHover(false)
  end)
  chip:SetScript("OnClick", function()
    CM.Config.ShowChangelog()
  end)
  UI.AttachTooltip(chip, "View the changelog", "ANCHOR_BOTTOM")
  local a = C.accent
  chip:cmSetBorderGradient(
    { a[1] * 0.85, a[2] * 0.85, a[3] * 0.85, 1 },
    { a[1] * 0.5, a[2] * 0.5, a[3] * 0.5, 1 }
  )
  local version = UI.CreateFontString(chip, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
  version:SetText("v" .. (CM.METADATA["VERSION"] or ""))
  version:SetTextColor(a[1], a[2], a[3])
  version:SetPoint("CENTER", chip, "CENTER", 0, 0)
  local CHIP_PAD_X, CHIP_H = 12, UI.Sizes.search
  local chipW = (version:GetStringWidth() or 0) + CHIP_PAD_X * 2
  chip:SetSize(chipW, CHIP_H)

  local headerDivider = UI.CreateLine(chrome, true, C.divider, "ends")
  headerDivider:SetWidth(1)
  headerDivider:SetHeight(54)
  headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W - 4, -3)
  -- Version chip just past the divider (same vertical centre as the header).
  chip:SetPoint("LEFT", headerDivider, "RIGHT", 16, 0)
  -- Setup wizard cog between the version chip and the search box (same vertical centre).
  local cog = CreateFrame("Button", nil, titleBar)
  UI.StyleControl(cog, nil, UI.Radius.control)
  cog:SetSize(CHIP_H, CHIP_H)
  cog:SetPoint("LEFT", chip, "RIGHT", 8, 0)
  local cogIcon = cog:CreateTexture(nil, "OVERLAY")
  CM.SetAtlas(cogIcon, "QuestLog-icon-setting", false)
  cogIcon:SetSize(CHIP_H - 16, CHIP_H - 16)
  cogIcon:SetPoint("CENTER")
  cog:SetScript("OnEnter", function(self)
    self:cmControlHover(true)
  end)
  cog:SetScript("OnLeave", function(self)
    self:cmControlHover(false)
  end)
  cog:SetScript("OnClick", function()
    UI.Confirm("Run the setup wizard again?", function()
      if CM.Wizard and CM.Wizard.Start then
        CM.Wizard.Start()
      end
    end)
  end)
  UI.AttachTooltip(cog, "Run the setup wizard", "ANCHOR_BOTTOM")
  Options.BuildSearchBox(titleBar, cog, 10)

  UI.EnableDrag(frame, titleBar, false)
  UI.EnableEscClose(frame, "CombatModeOptionsFrame")

  frame:HookScript("OnShow", function()
    ActivateTab()
    RefreshActiveTabScroll()
    -- Layout heights settle after Show; refresh once more so the thumb/bar appear.
    if C_Timer and C_Timer.After then
      C_Timer.After(0, RefreshActiveTabScroll)
    end
  end)
  frame:HookScript("OnHide", DeactivateTab)

  -- Header right: close X and the community links, all centred on the header's vertical middle
  -- (the close button sets the line; the icons are anchored to it and to each other).
  local closeX = UI.CreateCloseButton(frame, HEADER_CLOSE_SIZE)
  closeX:SetPoint("CENTER", frame, "TOPRIGHT", -26, -HEADER_CENTER_Y)

  -- Community links (frameless icons) immediately left of the close X.
  -- LaunchURL / CopyToClipboard are protected; clicks open a copy-link EditBox popup.
  local githubBtn = UI.CreateIconLinkButton(
    frame,
    CM.Constants.GitHubIcon,
    CM.Constants.GitHubURL,
    "GitHub Repository",
    "GitHub",
    HEADER_BUTTON_SIZE
  )
  githubBtn:SetPoint("RIGHT", closeX, "LEFT", -12, 0)

  local discordBtn = UI.CreateIconLinkButton(
    frame,
    CM.Constants.DiscordIcon,
    CM.Constants.DiscordURL,
    "Discord Server",
    "Discord",
    HEADER_BUTTON_SIZE
  )
  discordBtn:SetPoint("RIGHT", githubBtn, "LEFT", -14, 0)

  -- Sidebar/content divider
  local divider = UI.CreateLine(chrome, true, C.divider, "ends")
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W - 4, -61)
  divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDEBAR_W - 4, 0)

  for index, def in ipairs(Options.tabDefs) do
    BuildTab(def, index)
  end

  BuildSidebarFooter()

  if tabs[1] then
    SelectTab(tabs[1])
  end
end

---------------------------------------------------------------------------------------
--                                    LIFECYCLE                                      --
---------------------------------------------------------------------------------------
local initialized = false

function Options.Initialize()
  if initialized then
    return
  end
  initialized = true
  BuildShell()
end

local function CombatBlocked()
  if InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return true
  end
  return false
end

function CM.OpenOptions()
  if CombatBlocked() then
    return
  end
  Options.Initialize()
  Options.DockWindowLeft()
  frame:Show()
  frame:Raise()
  Options.Sync()
end

function CM.CloseOptions()
  if frame then
    frame:Hide()
  end
end

function CM.ToggleOptions()
  if frame and frame:IsShown() then
    frame:Hide()
    return
  end
  CM.OpenOptions()
end

--- Returns the standalone window frame (used by editors that anchor to it).
function CM.GetOptionsFrame()
  return frame
end
