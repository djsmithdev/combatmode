---------------------------------------------------------------------------------------
--  UI/Options/WhatsNew.lua — OPTIONS — "What's New" balloon beside the options window
---------------------------------------------------------------------------------------
--  What it does: A balloon docked to the right of CombatModeOptionsFrame that lists every
--  option, section and tab flagged `newFeatureFlag = true`, grouped by tab. Clicking an entry
--  navigates the main window to it (tab, Click Casting segment, scroll, flash) and leaves the
--  balloon open.
--  Architecture / how it works:
--    • No list of its own: entries come from the registries OptionsPanel's layout fills
--      (Options.controls `search.newFeature`, Options.sections `newFeature`, Options.tabDefs
--      `newFeatureFlag`). Adding the flag to a new option adds it here.
--    • Options.HasWhatsNew() tells the title bar whether to show its button;
--      Options.ToggleWhatsNew(anchor) opens / closes the balloon, rebuilt on every open.
--    • Navigation is Options.NavigateTo (OptionsSearch.lua), the same path search results use.
--    • Anchored to the options window (follows it when dragged), flipped to its left when
--      there is no room on the right; closes with the options window.
--  Does not: Decide what is new (the flags do) or draw the NEW badges (Widgets.lua).
--  Related: UI/Options/OptionsPanel.lua (button, registries), UI/Options/OptionsSearch.lua
--  (NavigateTo), UI/Options/Widgets.lua (newFeatureFlag).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

-- Lua stdlib
local gsub = _G.string.gsub
local ipairs = _G.ipairs
local lower = _G.string.lower
local max = _G.math.max
local min = _G.math.min
local tinsert = _G.table.insert
local upper = _G.string.upper

local UI = CM.UI
local C = UI.Colors
local Options = UI.Options

local BALLOON_W = 300
local BALLOON_MAX_H = 420 -- the list scrolls past this
local TOP_CHROME = 44 -- title bar above the list
local BALLOON_GAP = 12 -- same gap the editors keep from the options window
local PAD = 14
local ROW_H = 24
local HEADING_H = 26
local BAR_GUTTER = 12

local balloon
local scroll
local content
local rows = {}
local headings = {}

--- "FORCE LOCK" -> "Force Lock".
local function TitleCase(name)
  return (
    gsub(lower(name), "(%a)(%w*)", function(first, rest)
      return upper(first) .. rest
    end)
  )
end

--- Flagged things grouped by tab, in sidebar order:
--- { { name, entries = { { label, hint, entry } } } }.
local function CollectGroups()
  local byTab, groups = {}, {}
  for _, def in ipairs(Options.tabDefs) do
    local group = {
      id = def.id,
      name = UI.StripColors(def.label) or "",
      flagged = def.newFeatureFlag,
      entries = {},
    }
    byTab[def.id] = group
    tinsert(groups, group)
  end
  for _, section in ipairs(Options.sections) do
    local group = section.newFeature and byTab[section.tab]
    if group then
      tinsert(group.entries, {
        label = TitleCase(section.label),
        hint = "Section",
        entry = {
          tab = section.tab,
          group = section.group,
          control = section.header,
          section = section,
        },
      })
    end
  end
  for _, control in ipairs(Options.controls) do
    local meta = control.search
    local group = meta and meta.newFeature and control.frame and byTab[meta.tab]
    if group then
      tinsert(group.entries, {
        label = meta.label,
        hint = meta.section and TitleCase(meta.section) or "",
        entry = { tab = meta.tab, group = meta.group, control = control },
      })
    end
  end
  local result = {}
  for _, group in ipairs(groups) do
    if #group.entries == 0 and group.flagged then
      -- A new tab with no flagged option of its own: the tab itself is the entry.
      tinsert(group.entries, { label = group.name, hint = "Tab", entry = { tab = group.id } })
    end
    if #group.entries > 0 then
      tinsert(result, group)
    end
  end
  return result
end

--- True when anything is flagged, so the title bar only shows the button when it has content.
function Options.HasWhatsNew()
  return #CollectGroups() > 0
end

local function EnsureRow(i)
  if rows[i] then
    return rows[i]
  end
  local row = CreateFrame("Button", nil, content)
  row:SetHeight(ROW_H)
  UI.StyleRounded(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control, 1)

  row.hint = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  row.hint:SetPoint("RIGHT", row, "RIGHT", -8, 0)
  row.hint:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

  row.label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
  row.label:SetPoint("RIGHT", row.hint, "LEFT", -8, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetWordWrap(false)
  row.label:SetTextColor(C.text[1], C.text[2], C.text[3])

  row:SetScript("OnEnter", function(self)
    self:cmSetFillGradient(C.hoverFillTop, C.hoverFillBottom)
    self:cmSetBorderGradient(C.hoverBorderTop, C.hoverBorderBottom)
  end)
  row:SetScript("OnLeave", function(self)
    self:cmSetFill(0, 0, 0, 0)
    self:cmSetBorder(0, 0, 0, 0)
  end)
  row:SetScript("OnClick", function(self)
    if self.target then
      Options.NavigateTo(self.target)
    end
  end)
  rows[i] = row
  return row
end

local function EnsureHeading(i)
  if headings[i] then
    return headings[i]
  end
  local heading = UI.CreateFontString(content, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  heading:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  heading:SetJustifyH("LEFT")
  headings[i] = heading
  return heading
end

local function Render()
  local groups = CollectGroups()
  local y, rowCount = 0, 0
  for gi, group in ipairs(groups) do
    local heading = EnsureHeading(gi)
    heading:ClearAllPoints()
    heading:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -(y + 8))
    heading:SetText(upper(group.name))
    heading:Show()
    y = y + HEADING_H
    for _, item in ipairs(group.entries) do
      rowCount = rowCount + 1
      local row = EnsureRow(rowCount)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
      row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
      row.label:SetText(item.label)
      row.hint:SetText(item.hint)
      row.target = item.entry
      row:Show()
      y = y + ROW_H
    end
    y = y + 6
  end
  for i = rowCount + 1, #rows do
    rows[i].target = nil
    rows[i]:Hide()
  end
  for i = #groups + 1, #headings do
    headings[i]:Hide()
  end
  content:SetHeight(max(y, 1))
  -- Only as tall as the list needs, up to the cap.
  balloon:SetHeight(min(TOP_CHROME + y + PAD, BALLOON_MAX_H))
  if scroll.cmUpdate then
    scroll.cmUpdate()
  end
end

--- Docks the balloon to the right of the options window, or to its left when the screen
--- has no room on the right.
local function Dock(anchor)
  balloon:ClearAllPoints()
  local right = anchor:GetRight() or 0
  if right + BALLOON_GAP + BALLOON_W > (UIParent:GetWidth() or 0) then
    balloon:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -BALLOON_GAP, 0)
  else
    balloon:SetPoint("TOPLEFT", anchor, "TOPRIGHT", BALLOON_GAP, 0)
  end
end

local function EnsureBalloon(anchor)
  if balloon then
    return balloon
  end
  balloon = UI.CreateBareWindow("CombatModeWhatsNewFrame", "- What's New", BALLOON_W, BALLOON_MAX_H)
  balloon:Hide()

  scroll, content = UI.CreateScrollFrame(balloon)
  scroll:SetPoint("TOPLEFT", balloon, "TOPLEFT", PAD - 2, -TOP_CHROME)
  scroll:SetPoint("BOTTOMRIGHT", balloon, "BOTTOMRIGHT", -(PAD + BAR_GUTTER), PAD)
  scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, -4)
  scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 4)
  content:SetWidth(BALLOON_W - PAD * 2 - BAR_GUTTER)

  -- The balloon belongs to the options window: it goes with it.
  anchor:HookScript("OnHide", function()
    balloon:Hide()
  end)
  return balloon
end

function Options.HideWhatsNew()
  if balloon then
    balloon:Hide()
  end
end

--- Opens the balloon beside `anchor` (the options window), or closes it when already open.
function Options.ToggleWhatsNew(anchor)
  EnsureBalloon(anchor)
  if balloon:IsShown() then
    balloon:Hide()
    return
  end
  Dock(anchor)
  Render()
  balloon:Show()
  balloon:Raise()
end
