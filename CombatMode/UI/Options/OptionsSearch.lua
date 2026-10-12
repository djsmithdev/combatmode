---------------------------------------------------------------------------------------
--  UI/Options/OptionsSearch.lua — OPTIONS — top-left search for option rows
---------------------------------------------------------------------------------------
--  What it does: Search box in the options title bar (a magnifier icon that expands on click). As you type, a dropdown lists
--  options whose label, description, section or tab name contains every typed word (so
--  searching a section or tab lists all the options inside it). Up/Down move the
--  highlighted result, Enter picks it, Escape clears. Picking a result
--  switches to its tab (and Click Casting segment), scrolls the row into view, and
--  flashes it.
--  Architecture / how it works:
--    • Index: built on first search from Options.controls. OptionsPanel's ctx tags each
--      searchable control with `control.search` = { label, desc, tab, group, footer }.
--      Layouts without a search context (editors) are not indexed.
--    • Matching: each typed word must appear in the label, description, section header or
--      tab name. Ranking: label starts with the whole query (3) > label contains it (2) >
--      matched by words or description (1) > matched only through section / tab name (0),
--      which keeps layout order so a section or tab lists its options top to bottom. Ties
--      keep tab order. The result list scrolls once it passes MAX_VISIBLE rows.
--    • Navigation: Options.SelectTabById, then the segment selector for the group, then
--      scroll using frame positions (GetTop) so nested cards and segment panels work.
--    • The results hang off the search box like an expanding select: while open the box
--      widens to RESULTS_W and its own fill/border go transparent, so the popup surface
--      (input fill + control border, covering the box area too) is the one container, with
--      the box as its header row and a divider under it, like the expanded selects. The popup, click-outside catcher and clear button are
--      children of the options window at frame levels above its content (catcher < popup <
--      box < clear button), so they stay layered correctly when the window is raised.
--  Section headers are indexed too (Options.sections, filled by ctx:Header): picking one
--  scrolls to the header and flashes the whole section (header through its last row).
--  Does not: Search ButtonRow buttons. Footer utilities
--  have no tab, so they are flashed in place.
--  Related: UI/Options/OptionsPanel.lua (ctx tagging, SelectTabById, GetTabScroll),
--  UI/Options/Tabs/TabClickCasting.lua (RegisterSegmentSelector), UI/Options/Widgets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

-- Lua stdlib
local concat = _G.table.concat
local find = _G.string.find
local gmatch = _G.string.gmatch
local gsub = _G.string.gsub
local ipairs = _G.ipairs
local lower = _G.string.lower
local sub = _G.string.sub
local tinsert = _G.table.insert
local tsort = _G.table.sort

local UI = CM.UI
local C = UI.Colors
local Options = UI.Options

local COLLAPSED_W = UI.Sizes.search -- resting state: just the magnifier icon
local SEARCH_GAP = 16 -- space between the header divider and the search box
local EXPAND_SPEED = 20 -- higher = faster expand / collapse
local SEARCH_H = UI.Sizes.search
local RESULTS_W = 260
local ROW_H = 22 -- same row height as the dropdown menus
local MAX_VISIBLE = 12 -- rows shown before the list scrolls
local BAR_GUTTER = 10 -- room reserved for the scroll bar when the list overflows
local SCROLL_PAD = 12
local FLASH_DURATION = 1.2
local FLASH_ALPHA = 0.35

local index
local box
local edit
local placeholder
local clearBtn
local expanded = false
local SetExpanded -- assigned below (the result rows need it before it is defined)
local popup
local scroll
local content
local catcher
local emptyText
local rows = {}
local shown = {}
local selected = 1

local function TabName(tabId)
  for _, def in ipairs(Options.tabDefs) do
    if def.id == tabId then
      return UI.StripColors(def.label) or ""
    end
  end
  return ""
end

--- "FORCE LOCK" -> "Force Lock" for the results list.
local function SectionTitle(name)
  return (
    gsub(lower(name), "(%a)(%w*)", function(first, rest)
      return string.upper(first) .. rest
    end)
  )
end

--- Builds the searchable list once, from every control tagged by OptionsPanel's layout.
local function EnsureIndex()
  if index then
    return
  end
  index = {}
  -- Section headers are searchable too; picking one highlights the whole section.
  for _, section in ipairs(Options.sections) do
    local tabName = TabName(section.tab)
    tinsert(index, {
      control = section.header,
      section = section,
      label = SectionTitle(section.label),
      lowerLabel = lower(section.label),
      lowerDesc = "",
      lowerSection = "",
      lowerTab = lower(tabName),
      tab = section.tab,
      group = section.group,
      tabName = tabName .. " \194\183 Section",
      order = #index + 1,
    })
  end
  for _, control in ipairs(Options.controls) do
    local meta = control.search
    if meta and control.frame then
      local desc = meta.desc and gsub(meta.desc, "\n", " ") or ""
      tinsert(index, {
        control = control,
        label = meta.label,
        lowerLabel = lower(meta.label),
        lowerDesc = lower(desc),
        lowerSection = meta.section and lower(meta.section) or "",
        lowerTab = lower(meta.footer and "Sidebar" or TabName(meta.tab)),
        tab = meta.tab,
        group = meta.group,
        tabName = meta.footer and "Sidebar" or TabName(meta.tab),
        order = #index + 1,
      })
    end
  end
end

--- Score for one entry, or nil when some typed word is in neither label nor description.
local function Score(entry, words, query)
  local viaGroup = false
  for _, word in ipairs(words) do
    if not find(entry.lowerLabel, word, 1, true) and not find(entry.lowerDesc, word, 1, true) then
      -- Not in the option itself: the word may name its section header or its tab.
      if
        not find(entry.lowerSection, word, 1, true) and not find(entry.lowerTab, word, 1, true)
      then
        return nil
      end
      viaGroup = true
    end
  end
  if viaGroup then
    return 0
  end
  if sub(entry.lowerLabel, 1, #query) == query then
    return 3
  end
  if find(entry.lowerLabel, query, 1, true) then
    return 2
  end
  return 1
end

local function Close()
  if popup then
    popup:Hide()
    catcher:Hide()
    -- Give the box its own input surface back.
    box:cmSetFill(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    box:cmSetBorderGradient(C.controlBorderTop, C.controlBorderBottom)
  end
  shown = {}
  selected = 1
end

--- Paints the selected row (keyboard or hover) and clears the rest.
local function Highlight()
  for i, row in ipairs(rows) do
    if row.entry and i == selected then
      row:cmSetFillGradient(C.hoverFillTop, C.hoverFillBottom)
      row:cmSetBorderGradient(C.hoverBorderTop, C.hoverBorderBottom)
    else
      row:cmSetFill(0, 0, 0, 0)
      row:cmSetBorder(0, 0, 0, 0)
    end
  end
end

--- Moves the selection by `delta` rows, clamped to the results.
local function Move(delta)
  if #shown == 0 then
    return
  end
  selected = math.max(1, math.min(#shown, selected + delta))
  Highlight()
  -- Keep the selected row inside the visible part of a scrolling list.
  local top = (selected - 1) * ROW_H
  local viewH = scroll:GetHeight() or 0
  local cur = scroll:GetVerticalScroll() or 0
  local target
  if top < cur then
    target = top
  elseif top + ROW_H > cur + viewH then
    target = top + ROW_H - viewH
  end
  if target and scroll.cmScrollTo then
    scroll.cmScrollTo(target, true)
  end
end

--- Highlights the matched row. It is the same rounded background wash as the row hover
--- highlight (UI.CreateRoundedHover over the same bounds, behind the row's text), in the
--- accent colour, fading out over FLASH_DURATION.
local function Flash(holder, host, topFrame, bottomFrame)
  local flash = holder.cmSearchFlash
  if not flash then
    -- Same bounds the hover wash uses (see AddRowHover in Widgets.lua); for a section they run
    -- from the header down to its last row.
    local bounds = CreateFrame("Frame", nil, host)
    bounds:SetPoint("TOPLEFT", topFrame, "TOPLEFT", 0, 2)
    bounds:SetPoint("BOTTOMRIGHT", bottomFrame, "BOTTOMRIGHT", 0, -2)
    bounds:EnableMouse(false)
    local slice = UI.CreateRoundedHover(
      host,
      bounds,
      { C.accent[1], C.accent[2], C.accent[3], FLASH_ALPHA },
      UI.Radius.control
    )
    flash = { slice = slice, driver = bounds, elapsed = 0 }
    bounds:SetScript("OnUpdate", function(_, elapsed)
      flash.elapsed = flash.elapsed + (elapsed or 0)
      local p = flash.elapsed / FLASH_DURATION
      if p >= 1 then
        flash.slice.Hide()
        bounds:Hide()
        return
      end
      flash.slice.SetColor(C.accent[1], C.accent[2], C.accent[3], FLASH_ALPHA * (1 - p))
    end)
    holder.cmSearchFlash = flash
  end
  flash.elapsed = 0
  flash.slice.SetColor(C.accent[1], C.accent[2], C.accent[3], FLASH_ALPHA)
  flash.slice.Show()
  flash.driver:Show()
end

local function Navigate(entry)
  if entry.tab then
    Options.SelectTabById(entry.tab)
    local selectSegment = entry.group and Options.segmentSelectors[entry.tab]
    if selectSegment then
      selectSegment(entry.group)
    end
    local tabScroll = Options.GetTabScroll(entry.tab)
    local rowTop = entry.control.frame:GetTop()
    local contentTop = tabScroll and tabScroll:GetScrollChild():GetTop()
    if tabScroll and rowTop and contentTop then
      tabScroll.cmScrollTo(contentTop - rowTop - SCROLL_PAD, true)
    end
  end
  if entry.section then
    -- Whole section: header through its last row. The bounds live on the tab content (a
    -- plain frame below its rows), so the wash sits behind every row.
    local header = entry.section.header.frame
    Flash(entry.section, header:GetParent(), header, entry.section.lastFrame)
  else
    local frame = entry.control.frame
    Flash(frame, frame, frame, frame)
  end
end

--- Creates result row `i` on first use (a tab or section can list dozens of options).
local function EnsureRow(i)
  if rows[i] then
    return rows[i]
  end
  do
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)
    UI.StyleRounded(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control, 1)

    row.tabName = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    row.tabName:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.tabName:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

    row.label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.button, "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.label:SetPoint("RIGHT", row.tabName, "LEFT", -8, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetTextColor(C.text[1], C.text[2], C.text[3])

    row.index = i
    row:SetScript("OnEnter", function(self)
      selected = self.index
      Highlight()
    end)
    row:SetScript("OnClick", function(self)
      local entry = self.entry
      Close()
      edit:SetText("")
      edit:ClearFocus()
      SetExpanded(false)
      if entry then
        Navigate(entry)
      end
    end)
    rows[i] = row
    return row
  end
end

local function Render()
  for i = 1, #shown do
    EnsureRow(i)
  end
  for i, row in ipairs(rows) do
    local entry = shown[i]
    if entry then
      row.entry = entry
      row.label:SetText(entry.label)
      row.tabName:SetText(entry.tabName)
      row:Show()
    else
      row.entry = nil
      row:Hide()
    end
  end
  emptyText:SetShown(#shown == 0)
  local count = #shown
  local visible = math.min(math.max(count, 1), MAX_VISIBLE)
  local needsBar = count > MAX_VISIBLE
  local scrollW = RESULTS_W - 8 - (needsBar and BAR_GUTTER or 0)
  scroll:SetSize(scrollW, visible * ROW_H)
  content:SetSize(scrollW, math.max(count * ROW_H, 1))
  scroll:SetShown(count > 0)
  UI.SetMenuBarActive(scroll.cmScrollBar, needsBar)
  if scroll.cmUpdate then
    scroll.cmUpdate()
  end
  popup:SetHeight(SEARCH_H + 4 + visible * ROW_H + 4)
  selected = math.max(1, math.min(selected, #shown))
  Highlight()
end

local function Open()
  -- The popup surface behind it takes over as the container (no separate box outline).
  box:cmSetFill(0, 0, 0, 0)
  box:cmSetBorder(0, 0, 0, 0)
  Render()
  catcher:Show()
  popup:Show()
end

--- Re-runs the search for the current text. Only called for typed input.
local function Refresh()
  local words = {}
  for word in gmatch(lower(edit:GetText()), "%S+") do
    words[#words + 1] = word
  end
  if #words == 0 then
    Close()
    return
  end

  EnsureIndex()
  local query = concat(words, " ")
  local scored = {}
  for _, entry in ipairs(index) do
    local score = Score(entry, words, query)
    if score then
      scored[#scored + 1] = { entry = entry, score = score }
    end
  end
  tsort(scored, function(a, b)
    if a.score ~= b.score then
      return a.score > b.score
    end
    return a.entry.order < b.entry.order
  end)

  shown = {}
  for i = 1, #scored do
    shown[i] = scored[i].entry
  end
  selected = 1
  if scroll.cmScrollTo then
    scroll.cmScrollTo(0, true)
  end
  Open()
end

local function UpdatePlaceholder()
  local hasText = edit:GetText() ~= ""
  if placeholder then
    placeholder:SetShown(expanded and not hasText)
  end
  if clearBtn then
    clearBtn:SetShown(expanded and hasText)
  end
end

--- Expands the box to the results width (or collapses it to just the magnifier), animated
--- unless `instant`. The edit is only shown while expanded so the collapsed icon is one
--- click target.
function SetExpanded(on, instant)
  expanded = on
  if on then
    -- Back to the plain input surface (the collapsed button may be showing its hover fill).
    box:cmSetFill(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
  end
  box.cmTargetW = on and RESULTS_W or COLLAPSED_W
  if on then
    edit:Show()
  end
  UpdatePlaceholder()
  if instant then
    box:SetScript("OnUpdate", nil)
    box:SetWidth(box.cmTargetW)
    edit:SetShown(on)
    return
  end
  box:SetScript("OnUpdate", function(self, elapsed)
    local width = self:GetWidth()
    local target = self.cmTargetW
    local nextWidth = width + (target - width) * math.min(1, (elapsed or 0) * EXPAND_SPEED)
    if math.abs(target - nextWidth) < 0.5 then
      nextWidth = target
      self:SetScript("OnUpdate", nil)
      if not expanded then
        edit:Hide()
      end
    end
    self:SetWidth(nextWidth)
  end)
end

--- Builds the search box into the options title bar (left side). Called from BuildShell.
function Options.BuildSearchBox(titleBar, leftOf, gap)
  local window = titleBar:GetParent()

  box = CreateFrame("Frame", nil, titleBar, "BackdropTemplate")
  box:SetSize(COLLAPSED_W, SEARCH_H)
  if leftOf then
    -- Sits to the right of `leftOf` (the header's version chip).
    box:SetPoint("LEFT", leftOf, "RIGHT", gap or SEARCH_GAP, 0)
  else
    box:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
  end
  -- Shared search-box look (dark fill, quiet outline, cream magnifier).
  local icon = UI.StyleSearchBox(box)

  edit = CreateFrame("EditBox", nil, box)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(60)
  edit:EnableMouse(true)
  UI.SetEditBoxFont(edit)
  edit:SetTextColor(C.text[1], C.text[2], C.text[3])
  edit:SetPoint("TOPLEFT", box, "TOPLEFT", 28, -4)
  edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 4)

  placeholder = UI.CreateFontString(box, "OVERLAY", UI.Fonts.input, "GameFontHighlightSmall")
  placeholder:SetPoint("LEFT", box, "LEFT", 28, 0)
  placeholder:SetText("Search options...")
  placeholder:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 0.7)

  edit:SetScript("OnEditFocusGained", function()
    if not expanded then
      SetExpanded(true)
    end
  end)
  edit:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then
      SetExpanded(false)
    end
  end)
  -- Collapsed button hover: the same lighter gradient as the buttons, and a brighter icon.
  box:SetScript("OnEnter", function()
    if not expanded then
      box:cmSetFillGradient(C.buttonHoverTop, C.buttonHover)
      icon:SetVertexColor(1, 1, 1)
    end
  end)
  box:SetScript("OnLeave", function()
    if not expanded then
      box:cmSetFill(C.inputBg[1], C.inputBg[2], C.inputBg[3], C.inputBg[4])
    end
    icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
  end)
  -- Clicking the collapsed icon expands the box and starts typing.
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function()
    SetExpanded(true)
    edit:SetFocus()
  end)

  edit:SetScript("OnTextChanged", function(_, userInput)
    UpdatePlaceholder()
    if userInput then
      Refresh()
    end
  end)
  edit:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    Close()
    self:ClearFocus()
  end)
  edit:SetScript("OnArrowPressed", function(_, key)
    if key == "UP" then
      Move(-1)
    elseif key == "DOWN" then
      Move(1)
    end
  end)
  edit:SetScript("OnEnterPressed", function(self)
    local chosen = shown[selected]
    Close()
    self:SetText("")
    self:ClearFocus()
    SetExpanded(false)
    if chosen then
      Navigate(chosen)
    end
  end)

  -- Clear (×) button. It lives on UIParent above the catcher below, so it still works
  -- while results are open. Shown only when the box has text.
  clearBtn = CreateFrame("Button", nil, window)
  clearBtn:SetSize(16, 16)
  clearBtn:SetPoint("RIGHT", box, "RIGHT", -4, 0)
  clearBtn:SetFrameLevel(window:GetFrameLevel() + 230)
  local clearGlyph = UI.CreateFontString(clearBtn, "OVERLAY", 14, "GameFontNormalLarge")
  clearGlyph:SetPoint("CENTER", clearBtn, "CENTER", 0, 0)
  clearGlyph:SetText("\195\151") -- multiplication sign, same glyph as the window close X
  clearGlyph:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  clearBtn:SetScript("OnEnter", function()
    clearGlyph:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  clearBtn:SetScript("OnLeave", function()
    clearGlyph:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  end)
  clearBtn:SetScript("OnClick", function()
    edit:SetText("")
    Close()
    edit:SetFocus()
  end)
  clearBtn:Hide()

  -- Click-outside catcher: a full-screen button under the dropdown. Clicking it closes
  -- the results (the same click is consumed, like UI.MakeDropdown's menu).
  catcher = CreateFrame("Button", nil, window)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameLevel(window:GetFrameLevel() + 150)
  catcher:RegisterForClicks("AnyUp")
  catcher:SetScript("OnClick", function()
    Close()
    edit:ClearFocus()
  end)
  catcher:Hide()

  popup = CreateFrame("Frame", nil, window)
  popup:SetFrameLevel(window:GetFrameLevel() + 200)
  popup:SetWidth(RESULTS_W)
  popup:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
  popup:EnableMouse(true)
  -- Input surface + control outline; covers the box area so box and list read as one control.
  UI.StyleField(popup)
  local rule = UI.CreateLine(popup, false, C.divider, "ends")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -SEARCH_H)
  rule:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -8, -SEARCH_H)
  popup:Hide()
  -- The box sits above the popup as its header row.
  box:SetFrameLevel(window:GetFrameLevel() + 210)

  emptyText = UI.CreateFontString(popup, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  emptyText:SetPoint("LEFT", popup, "TOPLEFT", 12, -(SEARCH_H + 4 + ROW_H / 2))
  emptyText:SetText("No matching options")
  emptyText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

  scroll, content = UI.CreateScrollFrame(popup)
  scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -(SEARCH_H + 4))
  scroll.cmScrollBar:SetPoint("TOP", scroll, "TOP", 0, 0)
  scroll.cmScrollBar:SetPoint("BOTTOM", scroll, "BOTTOM", 0, 0)
  scroll.cmScrollBar:SetPoint("RIGHT", popup, "RIGHT", -5, 0)
  UI.SetMenuBarActive(scroll.cmScrollBar, false)
  SetExpanded(false, true)

  -- Closing the window closes the results and returns the search to its collapsed icon.
  window:HookScript("OnHide", function()
    Close()
    edit:SetText("")
    clearBtn:Hide()
    SetExpanded(false, true)
  end)
  window:HookScript("OnShow", UpdatePlaceholder)
end
