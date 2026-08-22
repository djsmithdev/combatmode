---------------------------------------------------------------------------------------
-- Core/Crosshair/CrosshairImprovements.lua — CROSSHAIR — range color overlay
---------------------------------------------------------------------------------------
local _, CM = ...
local CMI = CreateFrame("Frame", "CombatModeCrosshairImprovementsFrame", UIParent)

local playerClass
local db
local crosshairTexture
local optionsFrame
local hooksInstalled = false
local timeSinceUpdate = 1
local lastColor

local function CopyTable(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for key, child in pairs(value) do copy[key] = CopyTable(child) end
  return copy
end

local classSpells = {
  WARRIOR = { melee = { 1464, 6552, 12294 }, ranged = { 100, 57755, 355 } },
  PALADIN = { melee = { 35395, 96231 }, ranged = { 20271, 24275, 62124 } },
  HUNTER = { melee = { 187707, 186270 }, ranged = { 185358, 193455, 56641 } },
  ROGUE = { melee = { 1752, 1329, 1766, 53 }, ranged = { 185565, 199804, 36554, 185438 } },
  PRIEST = { melee = {}, ranged = { 585, 589 } },
  DEATHKNIGHT = { melee = { 49998, 47528 }, ranged = { 47541, 49576, 56222 } },
  SHAMAN = { melee = { 73899, 57994 }, ranged = { 188196, 188389 } },
  MAGE = { melee = { 108853, 120 }, ranged = { 116, 133, 30451 } },
  WARLOCK = { melee = {}, ranged = { 686, 29722, 172 } },
  MONK = { melee = { 100780, 116705 }, ranged = { 115546, 117952 } },
  DRUID = { melee = { 5221, 33917, 106839 }, ranged = { 5176, 93402, 8921, 6795 } },
  DEMONHUNTER = { melee = { 162794, 162243, 183752 }, ranged = { 185123, 185245 } },
  EVOKER = { melee = { 362969, 361469 }, ranged = { 356995, 357208 } },
}

local nativeColorMap = {
  hostile = "colorHostile", friendly_npc = "colorFriendlyNPC", friendly_player = "colorFriendlyPlayer",
  object = "colorObject", base = "colorBase", mounted = "colorMounted", focus = "colorFocus",
}

local function GetDB()
  db = CM.DB and CM.DB.global and CM.DB.global.crosshairImprovements
  return db
end

local function IsKnown(spellID)
  if not spellID then return false end
  if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(spellID) then return true end
  if IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(spellID) then return true end
  if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID) ~= nil
end

local knownMelee, knownRanged, spellRanges = {}, {}, {}
local function CacheSpells()
  wipe(knownMelee); wipe(knownRanged); wipe(spellRanges)
  local spells = classSpells[playerClass]
  if not spells then return end
  for _, spellID in ipairs(spells.melee or {}) do if IsKnown(spellID) then knownMelee[#knownMelee + 1] = spellID end end
  for _, spellID in ipairs(spells.ranged or {}) do if IsKnown(spellID) then knownRanged[#knownRanged + 1] = spellID end end
end

local function SpellInRange(spellID, unit)
  if not spellID or not unit or not UnitExists(unit) then return nil end
  local result = C_Spell and C_Spell.IsSpellInRange and C_Spell.IsSpellInRange(spellID, unit)
  if result == true or result == 1 then return true elseif result == false or result == 0 then return false end
  if IsSpellInRange then
    result = IsSpellInRange(spellID, unit)
    if result == true or result == 1 then return true elseif result == false or result == 0 then return false end
  end
  local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
  if name and C_Spell and C_Spell.IsSpellInRange then
    result = C_Spell.IsSpellInRange(name, unit)
    if result == true or result == 1 then return true elseif result == false or result == 0 then return false end
  end
  return nil
end

local function SpellRange(spellID)
  if spellRanges[spellID] then return spellRanges[spellID] end
  local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
  spellRanges[spellID] = (info and info.maxRange and info.maxRange > 0) and info.maxRange or 5
  return spellRanges[spellID]
end

local function GetAimUnit()
  if UnitExists("mouseover") and UnitCanAttack("player", "mouseover") then return "mouseover" end
  if UnitExists("softenemy") and UnitCanAttack("player", "softenemy") then return "softenemy" end
end

local function GetRangeState(unit)
  if not unit or UnitIsDeadOrGhost(unit) or not UnitCanAttack("player", unit) then return nil end
  local active = {}
  for index = 1, 3 do
    local spell = db.customSpells[index]
    if spell and spell.id and SpellInRange(spell.id, unit) == true then
      active[#active + 1] = { index = index, range = SpellRange(spell.id) }
    end
  end
  if #active > 0 then
    table.sort(active, function(left, right) return left.range < right.range end)
    return "CUSTOM_" .. active[1].index
  end
  for _, spellID in ipairs(knownMelee) do if SpellInRange(spellID, unit) == true then return "MELEE" end end
  if #knownMelee == 0 or playerClass == "PRIEST" or playerClass == "WARLOCK" or playerClass == "MAGE" or playerClass == "EVOKER" then
    if SpellInRange(6603, unit) == true then return "MELEE" end
  end
  for _, spellID in ipairs(knownRanged) do if SpellInRange(spellID, unit) == true then return "RANGED" end end
  return "OUT_OF_RANGE"
end

local function FindCrosshairTexture()
  if crosshairTexture and crosshairTexture.GetTexture and crosshairTexture:GetTexture() then return crosshairTexture end
  local root = _G.CombatModeCrosshairFrame
  if not root then return end
  local function Scan(parent, depth)
    if depth > 2 then return end
    for _, region in ipairs({ parent:GetRegions() }) do
      if region and region.GetObjectType and region:GetObjectType() == "Texture" and region:GetTexture() then return region end
    end
    for _, child in ipairs({ parent:GetChildren() }) do local found = Scan(child, depth + 1); if found then return found end end
  end
  crosshairTexture = Scan(root, 0)
  return crosshairTexture
end

local function ApplyNativeColors()
  if not db or not CM.Constants or not CM.Constants.CrosshairReactionColors then return end
  for state, key in pairs(nativeColorMap) do
    local color = db[key]
    if color then CM.Constants.CrosshairReactionColors[state] = { color.r, color.g, color.b, color.a or 1 } end
  end
end

local function ApplyRangeColor()
  if not db or not db.enabled or IsMounted() then return end
  if CM.IsFocusLockReticleSuppressed and CM.IsFocusLockReticleSuppressed() then return end
  local unit = GetAimUnit()
  if not unit then lastColor = nil; return end
  local state = GetRangeState(unit)
  local color
  if state and state:sub(1, 7) == "CUSTOM_" then color = db.customSpells[tonumber(state:sub(-1))].color
  elseif state == "MELEE" then color = db.colorMelee
  elseif state == "RANGED" then color = db.colorRanged
  elseif state == "OUT_OF_RANGE" then color = db.colorOutOfRange
  else color = db.colorNeutral end
  local texture = FindCrosshairTexture()
  if not texture or not texture.IsShown or not texture:IsShown() then return end
  local key = string.format("%.4f:%.4f:%.4f:%.4f", color.r, color.g, color.b, color.a or 1)
  if key ~= lastColor then texture:SetVertexColor(color.r, color.g, color.b, color.a or 1); lastColor = key end
end

local function Refresh()
  GetDB(); CacheSpells(); ApplyNativeColors(); lastColor = nil; ApplyRangeColor()
  if CM.UpdateCrosshairReaction then CM.UpdateCrosshairReaction() end
end

local function InstallHooks()
  if hooksInstalled or not hooksecurefunc or not CM.UpdateCrosshairReaction or not CM.CreateCrosshair then return end
  hooksInstalled = true
  hooksecurefunc(CM, "UpdateCrosshairReaction", function() ApplyRangeColor() end)
  hooksecurefunc(CM, "CreateCrosshair", function() crosshairTexture = nil; lastColor = nil; ApplyRangeColor() end)
end

local function AddTooltip(frame, title, description)
  if not frame or not frame.EnableMouse then return end
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(title, 1, .82, 0); GameTooltip:AddLine(description, nil, nil, nil, true); GameTooltip:Show() end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function ColorButton(parent, label, key, x, y, description)
  local button = CreateFrame("Button", nil, parent); button:SetSize(190, 22); button:SetPoint("TOPLEFT", x, y); AddTooltip(button, label, description)
  local swatch = button:CreateTexture(nil, "BACKGROUND"); swatch:SetSize(18, 18); swatch:SetPoint("LEFT")
  local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); text:SetPoint("LEFT", swatch, "RIGHT", 7, 0); text:SetText(label)
  local function Update() local color = db[key]; swatch:SetColorTexture(color.r, color.g, color.b, color.a or 1) end
  button:SetScript("OnClick", function()
    local color, old = db[key], CopyTable(db[key])
    local info = { r = color.r, g = color.g, b = color.b, opacity = color.a or 1, hasOpacity = true,
      swatchFunc = function() color.r, color.g, color.b = ColorPickerFrame:GetColorRGB(); Update(); Refresh() end,
      opacityFunc = function() color.a = ColorPickerFrame:GetColorAlpha(); Update(); Refresh() end,
      cancelFunc = function() db[key] = old; Update(); Refresh() end }
    if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info) else ColorPickerFrame:SetColorRGB(info.r, info.g, info.b); ColorPickerFrame:Show() end
  end)
  Update(); return button
end

local function CreateOptions()
  if optionsFrame then return optionsFrame end
  local f = CreateFrame("Frame", "CombatModeCrosshairImprovementsOptionsFrame", UIParent, "BackdropTemplate"); optionsFrame = f
  f:SetSize(500, 650); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } }); f:SetBackdropColor(.08, .08, .10, .96); f:SetBackdropBorderColor(.78, .61, .23, 1)
  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); title:SetPoint("TOP", 0, -18); title:SetText("Combat Mode Crosshair Improvements"); title:SetTextColor(.9, .82, .6)
  local sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); sub:SetPoint("TOP", title, "BOTTOM", 0, -6); sub:SetText("Changes apply instantly while Combat Mode owns the crosshair.")
  local enabled = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate"); enabled:SetPoint("TOPLEFT", 24, -65); enabled.text:SetText("Enable range colors"); enabled:SetScript("OnClick", function(self) db.enabled = self:GetChecked(); if db.enabled then Refresh() else ApplyNativeColors(); CM.UpdateCrosshairReaction() end end); AddTooltip(enabled, "Enable range colors", "Apply melee, ranged, out-of-range, and spell-override colors to hostile targets.")
  local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); h:SetPoint("TOPLEFT", 24, -108); h:SetText("State Colors"); h:SetTextColor(1, .82, 0)
  ColorButton(f, "Neutral", "colorNeutral", 34, -135, "Fallback CCI color when no hostile aim unit is active."); ColorButton(f, "Melee", "colorMelee", 270, -135, "Used when a known melee spell can reach the hostile aim unit."); ColorButton(f, "Ranged", "colorRanged", 34, -170, "Used when a ranged spell can reach but no melee spell can."); ColorButton(f, "Out of Range", "colorOutOfRange", 270, -170, "Used when no known or configured spell can reach the hostile aim unit.")
  local nh = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); nh:SetPoint("TOPLEFT", 24, -212); nh:SetText("Combat Mode Colors"); nh:SetTextColor(1, .82, 0)
  ColorButton(f, "Hostile", "colorHostile", 34, -240, "Native hostile reaction color; CCI range colors override it for hostile units.", true); ColorButton(f, "Friendly NPC", "colorFriendlyNPC", 270, -240, "Native friendly NPC reaction color.", true); ColorButton(f, "Friendly Player", "colorFriendlyPlayer", 34, -275, "Native friendly player reaction color.", true); ColorButton(f, "Object", "colorObject", 270, -275, "Native interactable object reaction color.", true); ColorButton(f, "Base", "colorBase", 34, -310, "Native idle/base crosshair color.", true); ColorButton(f, "Mounted", "colorMounted", 270, -310, "Native mounted color; transparent by default because Combat Mode hides the reticle while mounted.", true); ColorButton(f, "Focus", "colorFocus", 34, -345, "Native focus/nameplate marker color.", true)
  local oh = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); oh:SetPoint("TOPLEFT", 24, -385); oh:SetText("Spell Overrides (Auto Sorted)"); oh:SetTextColor(1, .82, 0)
  local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); desc:SetPoint("TOPLEFT", oh, "BOTTOMLEFT", 0, -5); desc:SetText("Drag utility or attack spells here. The shortest in-range spell wins.")
  local slots = {}
  local function RefreshSlot(i)
    local slot, data = slots[i], db.customSpells[i]
    if data.id then slot.icon:SetTexture((C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(data.id)) or "Interface\\Icons\\INV_Misc_QuestionMark"); slot.label:SetText((C_Spell.GetSpellName and C_Spell.GetSpellName(data.id)) or ("Spell #" .. data.id)); slot.clear:Show() else slot.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); slot.label:SetText("Slot " .. i .. " (Drag Spell Here)"); slot.clear:Hide() end
    slot.swatch:SetColorTexture(data.color.r, data.color.g, data.color.b, data.color.a or 1)
  end
  for i = 1, 3 do
    local slot = {}; slots[i] = slot; slot.button = CreateFrame("Button", nil, f, "BackdropTemplate"); slot.button:SetSize(30, 30); slot.button:SetPoint("TOPLEFT", 34, -445 - ((i - 1) * 40)); slot.icon = slot.button:CreateTexture(nil, "ARTWORK"); slot.icon:SetPoint("TOPLEFT", 3, -3); slot.icon:SetPoint("BOTTOMRIGHT", -3, 3); AddTooltip(slot.button, "Spell override slot", "Drag a spell here to give it priority when it is in range.")
    slot.swatch = f:CreateTexture(nil, "ARTWORK"); slot.swatch:SetSize(18, 18); slot.swatch:SetPoint("LEFT", slot.button, "RIGHT", 12, 0); slot.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); slot.label:SetPoint("LEFT", slot.swatch, "RIGHT", 10, 0)
    slot.clear = CreateFrame("Button", nil, f, "UIPanelButtonTemplate"); slot.clear:SetSize(45, 18); slot.clear:SetPoint("LEFT", slot.label, "RIGHT", 8, 0); slot.clear:SetText("Clear"); AddTooltip(slot.clear, "Clear spell override", "Remove this spell and return to normal range-state colors."); slot.clear:SetScript("OnClick", function() db.customSpells[i].id = false; RefreshSlot(i); Refresh() end)
    local drop = function() local kind, first, _, third = GetCursorInfo(); if kind == "spell" then db.customSpells[i].id = tonumber(third or first); ClearCursor(); RefreshSlot(i); Refresh() end end; slot.button:RegisterForDrag("LeftButton"); slot.button:SetScript("OnReceiveDrag", drop); slot.button:SetScript("OnClick", drop)
    local colorButton = CreateFrame("Button", nil, f); colorButton:SetSize(18, 18); colorButton:SetPoint("LEFT", slot.clear, "RIGHT", 8, 0); AddTooltip(colorButton, "Override color", "Color used when this is the shortest configured spell in range."); colorButton:SetScript("OnClick", function() local color, old = db.customSpells[i].color, CopyTable(db.customSpells[i].color); local info = { r = color.r, g = color.g, b = color.b, opacity = color.a or 1, hasOpacity = true, swatchFunc = function() color.r, color.g, color.b = ColorPickerFrame:GetColorRGB(); RefreshSlot(i); Refresh() end, opacityFunc = function() color.a = ColorPickerFrame:GetColorAlpha(); RefreshSlot(i); Refresh() end, cancelFunc = function() db.customSpells[i].color = old; RefreshSlot(i); Refresh() end }; if ColorPickerFrame.SetupColorPickerAndShow then ColorPickerFrame:SetupColorPickerAndShow(info) else ColorPickerFrame:SetColorRGB(info.r, info.g, info.b); ColorPickerFrame:Show() end end); RefreshSlot(i)
  end
  local reset = CreateFrame("Button", nil, f, "GameMenuButtonTemplate"); reset:SetSize(120, 22); reset:SetPoint("BOTTOMLEFT", 24, 16); reset:SetText("Reset Defaults"); AddTooltip(reset, "Reset defaults", "Restore all CCI colors and spell override colors."); reset:SetScript("OnClick", function() local defaults = CM.Constants.DatabaseDefaults.global.crosshairImprovements; db = CopyTable(defaults); CM.DB.global.crosshairImprovements = db; for i = 1, 3 do RefreshSlot(i) end; Refresh() end)
  local close = CreateFrame("Button", nil, f, "GameMenuButtonTemplate"); close:SetSize(90, 22); close:SetPoint("BOTTOMRIGHT", -24, 16); close:SetText("Close"); AddTooltip(close, "Close", "Close this configuration window."); close:SetScript("OnClick", function() f:Hide() end); table.insert(UISpecialFrames, f:GetName()); f:Hide(); return f
end

local function OpenOptions() GetDB(); local f = CreateOptions(); f:Show() end
CM.OpenCrosshairImprovements = OpenOptions
SLASH_COMBATMODECROSSHAIRIMPROVEMENTS1 = "/cci"
SlashCmdList.COMBATMODECROSSHAIRIMPROVEMENTS = function() GetDB(); local f = CreateOptions(); if f:IsShown() then f:Hide() else OpenOptions() end end

local settingsRegistered = false
local function RegisterSettingsPanel()
  if settingsRegistered then return end
  settingsRegistered = true
  local panel = CreateFrame("Frame")
  panel.name = "Crosshair Improvements"
  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge3"); title:SetPoint("TOP", 0, -45); title:SetText("Combat Mode Crosshair Improvements")
  local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight"); description:SetPoint("TOP", title, "BOTTOM", 0, -18); description:SetWidth(500); description:SetJustifyH("CENTER"); description:SetText("Class-aware hostile range colors, spell overrides, and native Combat Mode reaction colors.")
  local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate"); button:SetSize(180, 30); button:SetPoint("TOP", description, "BOTTOM", 0, -24); button:SetText("Open Configurator"); button:SetScript("OnClick", OpenOptions)
  if Settings and Settings.RegisterCanvasLayoutCategory then local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name); Settings.RegisterAddOnCategory(category) elseif InterfaceOptions_AddCategory then InterfaceOptions_AddCategory(panel) end
end

CMI:RegisterEvent("PLAYER_ENTERING_WORLD"); CMI:RegisterEvent("SPELLS_CHANGED"); CMI:RegisterEvent("PLAYER_TALENT_UPDATE"); CMI:RegisterEvent("PLAYER_TARGET_CHANGED"); CMI:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
CMI:SetScript("OnEvent", function(_, event)
  GetDB(); if event == "PLAYER_ENTERING_WORLD" then _, playerClass = UnitClass("player"); ApplyNativeColors(); InstallHooks(); RegisterSettingsPanel() elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" then CacheSpells() end
  lastColor = nil
end)
CMI:SetScript("OnUpdate", function(_, elapsed) if not db then GetDB() end; if not db or not db.enabled then return end; timeSinceUpdate = timeSinceUpdate + elapsed; if timeSinceUpdate >= .10 then timeSinceUpdate = 0; ApplyRangeColor() end end)
