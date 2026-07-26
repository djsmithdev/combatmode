---------------------------------------------------------------------------------------
--  UI/Options/OptionsPanel.lua — OPTIONS WINDOW — standalone shell + layout + lifecycle
---------------------------------------------------------------------------------------
--  Owns CombatModeOptionsFrame: a standalone, movable window with a left sidebar tab
--  list and a right scroll content area. Replaces the former Ace3/Blizzard-embedded
--  options. Exposes CM.OpenOptions / CM.ToggleOptions / CM.CloseOptions (combat-guarded),
--  a lazy Initialize() that builds every tab once, and the central SyncControls pass.
--
--  Tab content is contributed by UI/Options/Tabs/*.lua via CM.UI.Options.AddTab; this
--  module owns only the shell, the vertical layout manager (ctx), tab switching, and the
--  pinned sidebar footer (silence/debug toggles + changelog/reset buttons, formerly the
--  About tab). Widget construction/feature wiring lives in Widgets.lua + the tab builders.
--
--  Tabs may declare onSelect/onDeselect for transient side effects; they fire in pairs on
--  tab switches and on window show/hide. Tab content crossfades on switch. The window
--  always opens docked left-of-center (Options.DockWindowLeft) so the crosshair and
--  party radial stay clear for live previews.
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

local UI = CM.UI
local C = UI.Colors
UI.Options = UI.Options or {}
local Options = UI.Options
Options.tabDefs = Options.tabDefs or {}

local WINDOW_W, WINDOW_H = 740, 600
local SIDEBAR_W = 176
local CONTENT_PAD = 14

local frame
local tabs = {}
local activeTab
local tabActivated = false
local tabFadeGen = 0

local TAB_FADE_DURATION = 0.16

--- Eased alpha tween on a frame. `gen` cancels stale tweens when the user switches tabs
--- quickly. `onDone` runs only if this generation is still current.
local function FadeAlpha(frameObj, toAlpha, gen, onDone)
  UI.FadeAlpha(frameObj, toAlpha, TAB_FADE_DURATION, function()
    if gen ~= tabFadeGen then
      return
    end
    if onDone then
      onDone()
    end
  end)
end

--- Parks the window left of screen center so the crosshair and party radial stay clear
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
  -- Party radial outer reach is ~sliceRadius(120)+half slice; keep a little air past that.
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
--- def = { id, label, build = function(ctx) end,
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

local function NewLayout(content, width)
  local ctx = { content = content, width = width, y = -8 }

  function ctx:PlaceFrame(childFrame, height)
    childFrame:ClearAllPoints()
    childFrame:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, self.y)
    childFrame:SetWidth(self.width)
    self.y = self.y - height - ITEM_GAP
  end

  function ctx:Place(control)
    if control.SetWidthTo then
      control.SetWidthTo(self.width)
    end
    self:PlaceFrame(control.frame, control.height)
    return control
  end

  function ctx:Header(text)
    return self:Place(UI.MakeHeader(self.content, text))
  end
  function ctx:Description(text)
    return self:Place(UI.MakeDescription(self.content, text))
  end
  function ctx:Toggle(o)
    return self:Place(UI.MakeToggle(self.content, o))
  end
  function ctx:Slider(o)
    return self:Place(UI.MakeSlider(self.content, o))
  end
  function ctx:Dropdown(o)
    return self:Place(UI.MakeDropdown(self.content, o))
  end
  function ctx:Keybind(o)
    return self:Place(UI.MakeKeybind(self.content, o))
  end
  function ctx:TextInput(o)
    return self:Place(UI.MakeTextInput(self.content, o))
  end
  function ctx:Button(o)
    local control = UI.MakeButton(self.content, o)
    -- Row spans the content width so under-button descriptions can wrap; the button
    -- itself stays compact unless width = "full".
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
      self.y = self.y - control.height - ITEM_GAP
    end
    return control
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
    buildInner(innerCtx)
    local usedInner = -innerCtx.y + 4
    inner:SetHeight(usedInner)

    local cardHeight = topPad + usedInner + 8
    card:SetHeight(cardHeight)
    self:PlaceFrame(card, cardHeight)
    return card
  end

  function ctx:Finish()
    -- PlaceFrame always subtracts ITEM_GAP after the last control; drop that trailing
    -- gap so content height matches the visible widgets (avoids a phantom scrollbar and
    -- empty space under the final row).
    local height = -self.y - ITEM_GAP
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
  UI.StyleRounded(win, C.windowBg, C.windowBorder, UI.Radius.window)
  win:SetPoint("CENTER")

  local titleBar = CreateFrame("Frame", nil, win)
  titleBar:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -10)
  titleBar:SetPoint("TOPRIGHT", win, "TOPRIGHT", -12, -10)
  titleBar:SetHeight(24)

  local title = UI.CreateFontString(titleBar, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  title:SetPoint("LEFT", titleBar, "LEFT", 2, 0)
  title:SetText(UI.StripColors(titleText) or "")
  title:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

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
    scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -22, 14)
    scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
    scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)

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

  local ctx = NewLayout(content, contentWidth)
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
  if not tabActivated then
    return
  end
  tabActivated = false
  if activeTab and activeTab.def.onDeselect then
    activeTab.def.onDeselect()
  end
end

local function SelectTab(tab)
  if activeTab == tab and tab.scroll:IsShown() and tab.scroll:GetAlpha() >= 0.99 then
    return
  end

  DeactivateTab()
  tabFadeGen = tabFadeGen + 1
  local gen = tabFadeGen
  local previous = activeTab
  -- OnUpdate does not run while the shell is hidden; snap on first build / pre-show select.
  local animate = frame and frame:IsShown()

  for _, t in ipairs(tabs) do
    t.selected = (t == tab)
    if t == tab then
      t.button:cmSetFill(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
      t.button:cmSetBorder(0, 0, 0, 0)
      t.button.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    else
      t.button:cmSetFill(0, 0, 0, 0)
      t.button:cmSetBorder(0, 0, 0, 0)
      t.button.label:SetTextColor(0.56, 0.56, 0.56)
    end
    -- Hide unrelated panes immediately; previous/incoming are handled by the crossfade.
    if t ~= tab and t ~= previous then
      t.scroll:SetScript("OnUpdate", nil)
      t.scroll:Hide()
      t.scroll:SetAlpha(1)
      if t.bar then
        t.bar:SetScript("OnUpdate", nil)
        t.bar:Hide()
        t.bar:SetAlpha(1)
      end
    end
  end

  local function FinishOutgoing(outgoing)
    if not outgoing or outgoing == tab then
      return
    end
    outgoing.scroll:SetScript("OnUpdate", nil)
    outgoing.scroll:Hide()
    outgoing.scroll:SetAlpha(1)
    if outgoing.bar then
      outgoing.bar:SetScript("OnUpdate", nil)
      outgoing.bar:Hide()
      outgoing.bar:SetAlpha(1)
    end
  end

  if not animate then
    FinishOutgoing(previous)
    tab.scroll:SetScript("OnUpdate", nil)
    tab.scroll:SetAlpha(1)
    tab.scroll:Show()
    if tab.scroll.cmUpdate then
      tab.scroll.cmUpdate()
    end
    if tab.bar then
      tab.bar:SetScript("OnUpdate", nil)
      tab.bar:SetAlpha(1)
    end
    activeTab = tab
    return
  end

  -- Incoming pane: start transparent, then ease in.
  tab.scroll:SetScript("OnUpdate", nil)
  tab.scroll:SetAlpha(0)
  tab.scroll:Show()
  if tab.bar then
    tab.bar:SetScript("OnUpdate", nil)
    tab.bar:SetAlpha(0)
  end
  if tab.scroll.cmUpdate then
    tab.scroll.cmUpdate()
  end

  activeTab = tab
  ActivateTab()

  if previous and previous ~= tab and previous.scroll:IsShown() then
    FadeAlpha(previous.scroll, 0, gen, function()
      if gen ~= tabFadeGen then
        return
      end
      FinishOutgoing(previous)
    end)
    if previous.bar and previous.bar:IsShown() then
      FadeAlpha(previous.bar, 0, gen)
    end
  else
    FinishOutgoing(previous)
  end

  FadeAlpha(tab.scroll, 1, gen)
  if tab.bar and tab.bar:IsShown() then
    FadeAlpha(tab.bar, 1, gen)
  elseif tab.bar then
    -- cmUpdate may have hidden the bar (track/range not ready yet). Keep alpha at 1 so a
    -- later OnSizeChanged/OnScrollRangeChanged Show() is actually visible.
    tab.bar:SetAlpha(1)
  end
end

local function BuildSidebarButton(def, index)
  local button = CreateFrame("Button", nil, frame)
  button:SetSize(SIDEBAR_W - 24, 28)
  button:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -56 - (index - 1) * 32)
  UI.StyleRounded(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

  local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.nav, "GameFontNormal")
  label:SetPoint("LEFT", button, "LEFT", 10, 0)
  label:SetText(UI.StripColors(def.label) or "")
  button.label = label
  return button
end

local function BuildTab(def, index)
  local scroll, content = UI.CreateScrollFrame(frame)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W, -52)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 16)
  scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)

  local contentWidth = WINDOW_W - SIDEBAR_W - 22 - CONTENT_PAD
  content:SetSize(contentWidth, 10)

  local ctx = NewLayout(content, contentWidth)
  def.build(ctx)
  ctx:Finish()

  local tab = { def = def, scroll = scroll, bar = scroll.cmScrollBar }
  tab.button = BuildSidebarButton(def, index)
  tab.button:SetScript("OnClick", function()
    SelectTab(tab)
  end)
  tab.button:SetScript("OnEnter", function(self)
    if not tab.selected then
      self:cmSetFill(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
    end
  end)
  tab.button:SetScript("OnLeave", function(self)
    if not tab.selected then
      self:cmSetFill(0, 0, 0, 0)
    end
  end)
  tabs[#tabs + 1] = tab
  return tab
end

--- Utility controls pinned to the bottom of the sidebar (formerly the About tab): the
--- silence-alerts / debug toggles and the changelog / reset-to-defaults buttons.
local function BuildSidebarFooter()
  local footer = CreateFrame("Frame", nil, frame)
  footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)
  footer:SetWidth(SIDEBAR_W - 24)

  local fctx = NewLayout(footer, SIDEBAR_W - 24)
  fctx.y = 0

  fctx:Toggle({
    label = "Silence Alerts",
    desc = "Stops the printing of alert messages in the chat window after a reload.",
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
    desc = "Enables the printing of state logs in the chat window.",
    descBelow = true,
    get = function()
      return CM.DB.global.debugMode
    end,
    set = function(value)
      CM.DB.global.debugMode = value
    end,
  })
  fctx:Gap(6)
  fctx:Button({
    label = "View Changelog",
    width = "full",
    func = function()
      CM.Config.ShowChangelog()
    end,
  })
  fctx:Button({
    label = "Reset to Defaults",
    width = "full",
    confirm = true,
    confirmText = "A UI Reload is required when making this change. Proceed?",
    func = function()
      CM:OnResetDB()
    end,
  })

  footer:SetHeight(-fctx.y)

  -- Divider separating the tab list from the footer utilities.
  local sep = frame:CreateTexture(nil, "ARTWORK")
  sep:SetColorTexture(1, 1, 1, 0.06)
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
  -- shown it crossfades the scrollbar to alpha 0, and a premature cmUpdate can leave
  -- the bar permanently invisible until the next tab switch.
  frame:Hide()
  UI.StyleRounded(frame, C.windowBg, C.windowBorder, UI.Radius.window)
  Options.DockWindowLeft()

  -- Title bar (drag handle)
  local titleBar = CreateFrame("Frame", nil, frame)
  titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
  titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
  titleBar:SetHeight(30)

  local logo = titleBar:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(CM.Constants.Logo)
  logo:SetSize(26, 26)
  logo:SetPoint("LEFT", titleBar, "LEFT", 0, 0)

  -- Combat Mode wordmark header art (assets/cmtitle.blp, ~95x22 source → keep ratio).
  local titleArt = titleBar:CreateTexture(nil, "ARTWORK")
  titleArt:SetTexture(CM.Constants.Title)
  titleArt:SetSize(121, 28)
  titleArt:SetPoint("LEFT", logo, "RIGHT", 8, 0)

  local version = UI.CreateFontString(titleBar, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  version:SetPoint("LEFT", titleArt, "RIGHT", 10, -1)
  version:SetText(CM.METADATA["VERSION"] or "")
  version:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

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

  local closeX = UI.CreateCloseButton(frame)
  closeX:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)

  -- Sidebar/content divider
  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, 0.06)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W - 4, -48)
  divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDEBAR_W - 4, 12)

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
  -- Mouselook auto-disables via the frame watcher: CombatModeOptionsFrame is registered
  -- in CM.Constants.FramesToCheck, so the cursor unlocks while this window is shown.
  if CM.HealingRadial and CM.HealingRadial.IsActive and CM.HealingRadial.IsActive() then
    CM.HealingRadial.Hide()
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
