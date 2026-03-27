---------------------------------------------------------------------------------------
--  Config/ReticleCVarEditorPanel.lua — Reticle Targeting CVar editor panel
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local C_CVar = _G.C_CVar
local C_Timer = _G.C_Timer
local debugstack = _G.debugstack
local GetTime = _G.GetTime
local GameTooltip = _G.GameTooltip
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local strfind = _G.strfind
local strlower = _G.strlower
local strupper = _G.strupper
local tonumber = _G.tonumber

local Data = CM.ReticleCVarEditorData
local Editor = CM.ReticleCVarEditor or {}
CM.ReticleCVarEditor = Editor
Editor.modifiedBy = Editor.modifiedBy or {}
--- Set when TraceCVarSource runs from C_CVar.SetCVar / ConsoleExec so CVAR_UPDATE can avoid overwriting attribution.
local reticleCVarSeenFromHook = {}
local pendingExternalUpdate = {}
local refreshQueued = false

local function IsIgnoredSource(source)
  local normalized = strlower(source or "")
  -- Only ignore UI chrome and Blizzard CVar wrappers; keep ReticleCVarEditorData.lua so saves show attribution.
  return strfind(normalized, "[\\/]combatmode[\\/]config[\\/]reticlecvareditorpanel%.lua")
    or strfind(normalized, "[_\\/]sharedxmlbase[\\/]cvarutil%.lua")
    or strfind(normalized, "[_\\/]sharedxml[\\/]cvarutil%.lua")
end

local function FindBestSourceFromTrace(trace)
  if not trace or trace == "" then
    return nil, nil
  end

  -- Prefer file:line entries in order, skipping wrappers/internal files.
  for source, lineNum in trace:gmatch('"@([^"]+)"%]:(%d+)') do
    if not IsIgnoredSource(source) then
      return source, lineNum
    end
  end

  -- Fallback for alternate stack format.
  for source, lineNum in trace:gmatch("in function <([^:%[>]+):(%d+)>") do
    if not IsIgnoredSource(source) then
      return source, lineNum
    end
  end

  return nil, nil
end

local function TraceCVarSource(cvar)
  local canonicalCVar = Data.CanonicalCVar(cvar)
  if not canonicalCVar then
    return
  end

  -- Wide stack: hooks sit above the real caller; need enough frames to reach addon code.
  local trace = ""
  if debugstack then
    trace = debugstack(2, 50, 50) or debugstack(3) or ""
  end
  local source, lineNum = FindBestSourceFromTrace(trace)
  if not source then
    source, lineNum = "Unknown source", "?"
  end

  local key = strlower(canonicalCVar)
  Editor.modifiedBy[key] = source .. ":" .. lineNum
  reticleCVarSeenFromHook[key] = true
end

function Editor.RequestRefresh()
  if refreshQueued then
    return
  end
  refreshQueued = true
  if not (C_Timer and C_Timer.After) then
    refreshQueued = false
    Editor.Refresh()
    return
  end
  C_Timer.After(0, function()
    refreshQueued = false
    for key in pairs(pendingExternalUpdate) do
      if not reticleCVarSeenFromHook[key] then
        Editor.modifiedBy[key] = "External change (CVAR_UPDATE)"
      end
      pendingExternalUpdate[key] = nil
      reticleCVarSeenFromHook[key] = nil
    end
    Editor.Refresh()
  end)
end

local function NormalizeSortText(str)
  str = str or ""
  str = str:gsub("|c........", ""):gsub("|r", "")
  return str:lower()
end

local function BuildListFrame(parent, width, height)
  local frame = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
  frame:SetSize(width, height)
  frame:SetFrameStrata(parent:GetFrameStrata())
  frame:SetFrameLevel(parent:GetFrameLevel() + 2)
  frame.itemHeight = 18
  frame.minValue = 0
  frame.value = 0
  frame.items = {}
  frame.rows = {}
  frame.sortColumn = 1
  frame.sortAscending = true

  local cols = {
    { "CVar", 180, "LEFT" },
    { "Description", 405, "LEFT" },
    { "Value", 60, "RIGHT" },
  }
  frame.columns = cols

  local headerButtons = {}
  local x = 8
  for index, col in ipairs(cols) do
    local button = CreateFrame("Button", nil, frame)
    button:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", x, 0)
    button:SetSize(col[2], 18)
    button:SetNormalFontObject("GameFontHighlightSmallLeft")
    button:SetHighlightFontObject("GameFontNormalSmallLeft")
    button:SetText(col[1])
    local fs = button:GetFontString()
    fs:SetAllPoints()
    fs:SetJustifyH(col[3])
    button:SetScript("OnClick", function()
      if frame.sortColumn == index then
        frame.sortAscending = not frame.sortAscending
      else
        frame.sortColumn = index
        frame.sortAscending = true
      end
      frame:SortAndUpdate()
    end)
    headerButtons[index] = button
    x = x + col[2] + 4
  end
  frame.headerButtons = headerButtons

  local scrollbar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
  scrollbar:SetPoint("TOPRIGHT", 0, -18)
  scrollbar:SetPoint("BOTTOMRIGHT", 0, 16)
  scrollbar:SetMinMaxValues(0, 0)
  scrollbar:SetValueStep(1)
  frame.scrollbar = scrollbar

  local function UpdateRows()
    local visibleRows = frame.visibleRows or 0
    for i = 1, visibleRows do
      local itemIndex = i + frame.value
      local row = frame.rows[i]
      local wasMouseOver = row:IsMouseOver()
      if wasMouseOver then
        local onLeave = row:GetScript("OnLeave")
        if onLeave then
          onLeave(row)
        end
      end
      local item = frame.items[itemIndex]
      if item then
        row.value = item.key
        row.cvar = item.cvarText
        row.description = item.descText
        row.displayValue = item.valueTextRaw
        row.cols[1]:SetText(item.cvarText)
        row.cols[2]:SetText(item.descText)
        row.cols[3]:SetText(item.valueText)
        row:Show()
      else
        row.value = nil
        row:Hide()
      end
      if wasMouseOver and row:IsShown() then
        local onEnter = row:GetScript("OnEnter")
        if onEnter then
          onEnter(row)
        end
      end
    end

    if frame.value <= 0 then
      scrollbar.ScrollUpButton:Disable()
    else
      scrollbar.ScrollUpButton:Enable()
    end
    if frame.value >= frame.maxValue then
      scrollbar.ScrollDownButton:Disable()
    else
      scrollbar.ScrollDownButton:Enable()
    end
  end

  frame.UpdateRows = UpdateRows

  function frame:SortAndUpdate()
    local column = self.sortColumn
    local ascending = self.sortAscending
    table.sort(self.items, function(a, b)
      local av = NormalizeSortText(a.sortable[column])
      local bv = NormalizeSortText(b.sortable[column])
      if av == bv then
        return a.key < b.key
      end
      if ascending then
        return av < bv
      end
      return av > bv
    end)
    self:UpdateRows()
  end

  function frame:SetItems(items)
    self.items = items or {}
    self.visibleRows = math.max(1, math.floor((self:GetHeight() - 12) / self.itemHeight))
    if self.EnsureRows then
      self:EnsureRows(self.visibleRows)
    end
    self.maxValue = math.max(#self.items - self.visibleRows, 0)
    if self.value > self.maxValue then
      self.value = self.maxValue
    end
    self.scrollbar:SetMinMaxValues(0, self.maxValue)
    self.scrollbar:SetValue(self.value)
    self:SortAndUpdate()
  end

  frame:EnableMouseWheel(true)
  frame:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then
      self.value = math.max(0, self.value - 1)
    else
      self.value = math.min(self.maxValue, self.value + 1)
    end
    self.scrollbar:SetValue(self.value)
    self:UpdateRows()
  end)

  scrollbar.ScrollUpButton:SetScript("OnClick", function()
    frame.value = math.max(0, frame.value - 1)
    scrollbar:SetValue(frame.value)
    frame:UpdateRows()
  end)
  scrollbar.ScrollDownButton:SetScript("OnClick", function()
    frame.value = math.min(frame.maxValue, frame.value + 1)
    scrollbar:SetValue(frame.value)
    frame:UpdateRows()
  end)
  scrollbar:SetScript("OnValueChanged", function(_, value)
    frame.value = math.floor(value)
    frame:UpdateRows()
  end)

  local lastClickTime = 0

  local function CreateRow(rowIndex)
    local row = CreateFrame("Frame", nil, frame)
    row:SetWidth(width - 34)
    row:SetHeight(frame.itemHeight)
    row:EnableMouse(true)
    if rowIndex == 1 then
      row:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    else
      row:SetPoint("TOPLEFT", frame.rows[rowIndex - 1], "BOTTOMLEFT", 0, 0)
    end

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.1)
    bg:Hide()
    row.bg = bg

    row.cols = {}
    local xOffset = 0
    for colIndex, col in ipairs(cols) do
      local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmallLeft")
      fs:SetPoint("LEFT", xOffset, 0)
      fs:SetWidth(col[2])
      fs:SetWordWrap(false)
      fs:SetMaxLines(1)
      fs:SetJustifyH(col[3])
      row.cols[colIndex] = fs
      xOffset = xOffset + col[2] + 4
    end

    row:SetScript("OnEnter", function(self)
      if not self.value then
        return
      end
      self.bg:Show()
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      local rowData = Editor.rowDataByKey and Editor.rowDataByKey[self.value]
      if rowData then
        GameTooltip:AddLine(rowData.cvar, 1, 0.82, 0.2)
        GameTooltip:AddLine(" ")
        if rowData.description ~= "" then
          GameTooltip:AddLine(rowData.description, 0.9, 0.9, 0.9, true)
        end
        GameTooltip:AddDoubleLine("Default Value:", rowData.defaultValue, 0.2, 1, 0.6, 0.2, 1, 0.6)
        local modifiedBy = Editor.modifiedBy[strlower(rowData.cvar)]
        if modifiedBy then
          GameTooltip:AddDoubleLine("Last Modified By:", modifiedBy, 1, 0, 0, 1, 0, 0)
        end
      end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
      self.bg:Hide()
      GameTooltip:Hide()
    end)
    row:SetScript("OnMouseDown", function(self)
      if not self.value then
        return
      end
      local now = GetTime()
      if now - lastClickTime <= 0.25 then
        Editor.ShowInlineEditor(self)
      else
        lastClickTime = now
      end
    end)

    return row
  end

  function frame:EnsureRows(count)
    local existing = #self.rows
    for i = existing + 1, count do
      self.rows[i] = CreateRow(i)
    end
    for i = count + 1, existing do
      local row = self.rows[i]
      if row then
        row.value = nil
        row:Hide()
      end
    end
  end

  return frame
end

local function LiteralizePattern(str)
  return str:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1")
end

local function MakeCaseInsensitivePattern(text)
  return LiteralizePattern(text):gsub("%a", function(c)
    return "[" .. strlower(c) .. strupper(c) .. "]"
  end)
end

--- True when live GetCVar differs from `CM.Constants.ReticleTargetingCVarValues` for this row.
local function LiveCVarDiffersFromCombatModePreset(currentStr, presetStr)
  local cur, preset = tonumber(currentStr), tonumber(presetStr)
  if cur ~= nil and preset ~= nil then
    return cur ~= preset
  end
  return (currentStr or "") ~= (presetStr or "")
end

local function BuildDisplayRows(filterText)
  local rows = Data.GetRows()
  local pattern = nil
  local listItems = {}
  local rowDataByKey = {}

  if filterText and filterText ~= "" then
    pattern = MakeCaseInsensitivePattern(filterText)
  end

  for _, row in ipairs(rows) do
    local cvarText = row.cvar
    local descText = row.description
    local valueTextRaw = row.currentValue
    local valueText = row.currentValue
    local isOutOfSync = LiveCVarDiffersFromCombatModePreset(row.currentValue, row.defaultValue)
    if isOutOfSync then
      valueText = "|cffff0000" .. row.currentValue .. "|r"
    end

    local include = true
    if pattern then
      include = cvarText:find(pattern) or descText:find(pattern) or valueTextRaw:find(pattern)
    end

    if include then
      if pattern then
        cvarText = cvarText:gsub(pattern, "|cffff0000%1|r")
        descText = descText:gsub(pattern, "|cffff0000%1|r")
        valueText = valueText:gsub(pattern, "|cffff0000%1|r")
      end
      local key = row.cvar
      listItems[#listItems + 1] = {
        key = key,
        sortable = { row.cvar, row.description, row.currentValue },
        cvarText = cvarText,
        descText = descText,
        valueText = valueText,
        valueTextRaw = valueTextRaw,
      }
      rowDataByKey[key] = row
    end
  end

  return listItems, rowDataByKey
end

function Editor.Refresh()
  if not Editor.frame then
    return
  end
  local filterText = Editor.filterBox:GetText() or ""
  local items, rowDataByKey = BuildDisplayRows(filterText)
  Editor.rowDataByKey = rowDataByKey
  Editor.listFrame:SetItems(items)
end

function Editor.ShowInlineEditor(row)
  if not row or not row.value then
    return
  end

  if _G.InCombatLockdown() then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: cannot edit Reticle Targeting CVars while in combat.|r"
    )
    return
  end

  local input = Editor.inlineInput
  local blocker = Editor.inlineBlocker
  if input.currentLabel then
    input.currentLabel:Show()
  end
  row.cols[3]:Hide()
  input.currentLabel = row.cols[3]
  input.currentKey = row.value
  input:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  input:SetText(row.displayValue or "")
  input:HighlightText()
  blocker:Show()
  input:Show()
  input:SetFocus()
end

function CM.OpenReticleTargetingCVarEditor()
  if not Editor.frame then
    local frame = CreateFrame(
      "Frame",
      "CombatModeReticleCVarEditor",
      _G.UIParent,
      "BasicFrameTemplateWithInset"
    )
    frame:SetSize(735, 400)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    frame.TitleText:SetText(CM.METADATA["TITLE"] .. " - Reticle Targeting CVar Editor")

    local subtitle = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -40)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -40, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(
      "Double-click a row to edit. Overrides are account-wide and replace CombatMode defaults."
    )

    local filterBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    filterBox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 2, -12)
    filterBox:SetPoint("RIGHT", frame, "RIGHT", -44, 0)
    filterBox:SetHeight(20)
    filterBox:SetAutoFocus(false)
    filterBox:SetMaxLetters(120)
    filterBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
    end)
    filterBox:SetScript("OnEnterPressed", function(self)
      self:ClearFocus()
    end)
    filterBox:SetScript("OnTextChanged", function()
      Editor.RequestRefresh()
    end)

    local listFrame = BuildListFrame(frame, 700, 300)
    listFrame:SetPoint("TOP", filterBox, "BOTTOM", 0, -26)
    listFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, 42)

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(260, 24)
    resetButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 12)
    -- List uses frame level parent+2; without this, the list steals clicks on most of the button.
    resetButton:SetFrameStrata(frame:GetFrameStrata())
    resetButton:SetFrameLevel(listFrame:GetFrameLevel() + 20)
    resetButton:SetText("Reset All to CombatMode Defaults")
    resetButton:SetScript("OnClick", function()
      if Data.ClearAllOverrides() then
        Editor.Refresh()
      end
    end)

    local blocker = CreateFrame("Frame", nil, listFrame)
    blocker:SetAllPoints()
    blocker:EnableMouse(true)
    blocker:EnableMouseWheel(true)
    blocker:SetScript("OnMouseDown", function()
      Editor.inlineInput:ClearFocus()
    end)
    blocker:SetScript("OnMouseWheel", function() end)
    local blackout = blocker:CreateTexture(nil, "BACKGROUND")
    blackout:SetAllPoints()
    blackout:SetColorTexture(0, 0, 0, 0.2)
    blocker:Hide()

    local inlineInput = CreateFrame("EditBox", nil, blocker, "InputBoxTemplate")
    inlineInput:SetSize(60, 18)
    inlineInput:SetAutoFocus(false)
    inlineInput:SetJustifyH("RIGHT")
    inlineInput:SetTextInsets(5, 8, 0, 0)
    inlineInput:Hide()
    inlineInput:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      self:Hide()
    end)
    inlineInput:SetScript("OnEnterPressed", function(self)
      if Data.SetOverride(self.currentKey, self:GetText() or "") then
        self:Hide()
        Editor.Refresh()
      end
    end)
    inlineInput:SetScript("OnEditFocusLost", function(self)
      self:Hide()
    end)
    inlineInput:SetScript("OnHide", function(self)
      blocker:Hide()
      if self.currentLabel then
        self.currentLabel:Show()
      end
    end)

    frame:SetScript("OnShow", function()
      Editor.RequestRefresh()
    end)

    Editor.frame = frame
    Editor.filterBox = filterBox
    Editor.listFrame = listFrame
    Editor.inlineInput = inlineInput
    Editor.inlineBlocker = blocker
  end

  Editor.frame:Show()
  Editor.frame:Raise()

  -- Anchor the editor to the left of the Settings panel (when possible).
  do
    local frame = Editor.frame
    local anchor = _G.SettingsPanel or _G.InterfaceOptionsFrame
    local ui = _G.UIParent
    if frame and anchor and anchor.GetLeft and anchor.GetTop then
      local desiredLeft = (anchor:GetLeft() or 0) - frame:GetWidth() - 12
      local desiredTop = (anchor:GetTop() or 0) - 18

      if ui and ui.GetWidth then
        local minLeft = 12
        desiredLeft = math.max(desiredLeft, minLeft)
      end

      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", ui, "BOTTOMLEFT", desiredLeft, desiredTop)
    end
  end
end

-- Trace only C_CVar.SetCVar: hooking global SetCVar as well would run second and overwrite attribution with a worse stack.
if C_CVar and C_CVar.SetCVar then
  hooksecurefunc(C_CVar, "SetCVar", function(cvar)
    TraceCVarSource(cvar)
    if Editor.frame and Editor.frame:IsVisible() then
      Editor.RequestRefresh()
    end
  end)
else
  hooksecurefunc("SetCVar", function(cvar)
    TraceCVarSource(cvar)
    if Editor.frame and Editor.frame:IsVisible() then
      Editor.RequestRefresh()
    end
  end)
end

hooksecurefunc("ConsoleExec", function(msg)
  if type(msg) == "string" then
    local cmd, cvar = msg:match("^(%S+)%s+(%S+)%s*(%S*)")
    if cmd then
      if strlower(cmd) == "set" then
        TraceCVarSource(cvar)
      else
        TraceCVarSource(cmd)
      end
    end
  end
  if Editor.frame and Editor.frame:IsVisible() then
    Editor.RequestRefresh()
  end
end)

local cvarEventFrame = CreateFrame("Frame")
cvarEventFrame:RegisterEvent("CVAR_UPDATE")
cvarEventFrame:SetScript("OnEvent", function(_, _, cvarName)
  local canonical = Data.CanonicalCVar(cvarName)
  if not canonical then
    return
  end
  if Editor.frame and Editor.frame:IsVisible() then
    pendingExternalUpdate[strlower(canonical)] = true
    Editor.RequestRefresh()
  end
end)
