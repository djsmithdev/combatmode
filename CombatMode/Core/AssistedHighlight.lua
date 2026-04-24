---------------------------------------------------------------------------------------
--  Core/AssistedHighlight.lua — ASSISTED HIGHLIGHT — suggested spell icon + keybind
---------------------------------------------------------------------------------------
--  Shows the Blizzard Assisted Combat "next cast" suggestion anchored to Combat Mode's
--  crosshair. Mirrors Core/InteractionHUD.lua architecture:
--    • Crosshair owns the anchor frame; this module owns the widget lifecycle.
--    • Crosshair calls CM.InitAssistedHighlight({ crosshairFrame, crosshairTexture }).
--    • Runtime/Crosshair call CM.UpdateCrosshairAssistedHighlight() to refresh.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local IsMouselooking = _G.IsMouselooking
local UnitAffectingCombat = _G.UnitAffectingCombat

local C_AssistedCombat = _G.C_AssistedCombat
local C_ActionBar = _G.C_ActionBar
local C_Spell = _G.C_Spell

-- Lua stdlib
local math = _G.math
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local tonumber = _G.tonumber
local type = _G.type

local crosshairFrame
local crosshairTexture

local AssistedHighlightFrame
local AssistedHighlightVisual
local AssistedHighlightLockInDriver
local AssistedHighlightWasShown = false

-- Caches
local assistedActionSlotSet
local actionSlotCommandMap

local function EnsureAssistedHighlight()
  if AssistedHighlightFrame then
    return
  end
  if not crosshairFrame then
    return
  end

  -- Per-module lock-in animation driver (mirrors Core/Animations.lua crosshair lock-in style).
  AssistedHighlightLockInDriver = CreateFrame("Frame", nil, crosshairFrame)
  AssistedHighlightLockInDriver:Hide()

  AssistedHighlightFrame = CreateFrame("Frame", nil, crosshairFrame)
  AssistedHighlightFrame:Hide()
  AssistedHighlightFrame:SetFrameStrata(crosshairFrame:GetFrameStrata())
  AssistedHighlightFrame:SetFrameLevel(crosshairFrame:GetFrameLevel() + 20)

  -- Visual subframe: keep outer anchored; animate inner so scale origin is centered.
  AssistedHighlightVisual = CreateFrame("Frame", nil, AssistedHighlightFrame)
  AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", 0, 0)
  AssistedHighlightVisual:Hide()

  AssistedHighlightFrame.shadow = AssistedHighlightVisual:CreateTexture(nil, "BORDER")
  AssistedHighlightFrame.shadow:SetVertexColor(1, 1, 1, 1)
  AssistedHighlightFrame.shadow:SetAlpha(0.7)

  AssistedHighlightFrame.icon = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightFrame.icon:SetPoint("CENTER", AssistedHighlightVisual, "CENTER", 0, 0)
  AssistedHighlightFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  AssistedHighlightFrame.iconMask = AssistedHighlightVisual:CreateMaskTexture()
  AssistedHighlightFrame.iconMask:SetTexture(
    "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE",
    "CLAMPTOBLACKADDITIVE"
  )
  AssistedHighlightFrame.iconMask:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER")
  AssistedHighlightFrame.icon:AddMaskTexture(AssistedHighlightFrame.iconMask)

  AssistedHighlightFrame.iconBorder = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightFrame.iconBorder:SetDrawLayer("OVERLAY", 5)
  AssistedHighlightFrame.iconBorder:SetDesaturated(true)
  AssistedHighlightFrame.iconBorder:SetAlpha(1)
  AssistedHighlightFrame.iconBorder:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)
  AssistedHighlightFrame.iconBorder:Show()

  AssistedHighlightFrame.keybindText =
    AssistedHighlightVisual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  AssistedHighlightFrame.keybindText:SetJustifyH("LEFT")
  AssistedHighlightFrame.keybindText:SetText("")
  AssistedHighlightFrame.keybindText:SetShadowColor(0, 0, 0, 1)
  AssistedHighlightFrame.keybindText:SetShadowOffset(1, -1)
  AssistedHighlightFrame.keybindText:Hide()

  -- Lock-in animation: scale/alpha tween when the frame shows.
  local LOCK_IN_DURATION = 0.25
  local totalElapsed = -1
  local startScale = 1.3
  local startAlpha = 0.0
  local targetScale = 1.0
  local targetAlpha = 1.0
  local baseAlpha = 0.85 -- must match ApplyCrosshairAssistedHighlightOptions()

  AssistedHighlightLockInDriver:SetScript("OnUpdate", function(_, elapsed)
    if totalElapsed == -1 then
      return
    end
    totalElapsed = totalElapsed + elapsed
    if totalElapsed >= LOCK_IN_DURATION then
      totalElapsed = -1
      AssistedHighlightLockInDriver:Hide()
      if AssistedHighlightVisual then
        AssistedHighlightVisual:SetScale(targetScale)
        AssistedHighlightVisual:SetAlpha(baseAlpha)
      end
      return
    end
    local progress = totalElapsed / LOCK_IN_DURATION
    progress = math.max(0, math.min(1, progress))
    local eased = 1 - (1 - progress) * (1 - progress)

    local currentScale = startScale + (targetScale - startScale) * eased
    if AssistedHighlightVisual then
      AssistedHighlightVisual:SetScale(math.max(0.01, currentScale))
      local currentAlpha = startAlpha + (targetAlpha - startAlpha) * eased
      AssistedHighlightVisual:SetAlpha(currentAlpha * baseAlpha)
    end
  end)

  function AssistedHighlightFrame:PlayLockIn()
    if not AssistedHighlightLockInDriver then
      return
    end
    baseAlpha = 0.85
    targetAlpha = 1.0
    targetScale = 1.0
    startScale = 1.3
    startAlpha = 0.0
    if AssistedHighlightVisual then
      AssistedHighlightVisual:SetScale(startScale)
      AssistedHighlightVisual:SetAlpha(0)
      AssistedHighlightVisual:Show()
    end
    totalElapsed = 0
    AssistedHighlightLockInDriver:Show()
  end
end

local function SetAssistedHighlightShadowAtlas()
  if not (AssistedHighlightFrame and AssistedHighlightFrame.shadow) then
    return
  end
  local atlas = "Radial_Wheel_BG_Small"
  if _G.C_Texture and _G.C_Texture.GetAtlasInfo then
    local ok, info = pcall(_G.C_Texture.GetAtlasInfo, atlas)
    if not ok or not info then
      atlas = "PetJournal-BattleSlot-Shadow"
      CM.DebugPrintThrottled(
        "assistedHighlightShadowAtlas",
        "Assisted Highlight: atlas Radial_Wheel_BG_Small not found; falling back to " .. atlas,
        10
      )
    end
  end
  AssistedHighlightFrame.shadow:SetAtlas(atlas)
end

local function SetAssistedHighlightIconBorderAtlas()
  if not (AssistedHighlightFrame and AssistedHighlightFrame.iconBorder) then
    return
  end
  local atlas = "Evergreen-toast-celebration-content-ring"
  if _G.C_Texture and _G.C_Texture.GetAtlasInfo then
    local ok, info = pcall(_G.C_Texture.GetAtlasInfo, atlas)
    if not ok or not info then
      atlas = "UI-Quickslot2"
      CM.DebugPrintThrottled(
        "assistedHighlightIconBorderAtlas",
        "Assisted Highlight: item border atlas missing; falling back to " .. atlas,
        10
      )
    end
  end
  AssistedHighlightFrame.iconBorder:SetAtlas(atlas, false)
end

local COMPACT_KEY_MAP = {
  ["CTRL"] = "Ctrl",
  ["SHIFT"] = "Shift",
  ["ALT"] = "Alt",
  ["META"] = "M",
  ["MOUSE1"] = "M1",
  ["MOUSE2"] = "M2",
  ["MOUSE3"] = "M3",
  ["MOUSE4"] = "M4",
  ["MOUSE5"] = "M5",
  ["LEFTBUTTON"] = "M1",
  ["RIGHTBUTTON"] = "M2",
  ["MIDDLEBUTTON"] = "M3",
  ["BUTTON1"] = "M1",
  ["BUTTON2"] = "M2",
  ["BUTTON3"] = "M3",
  ["BUTTON4"] = "M4",
  ["BUTTON5"] = "M5",
  ["MOUSEWHEELUP"] = "MwU",
  ["MOUSEWHEELDOWN"] = "MwD",
  ["NUMPAD0"] = "N0",
  ["NUMPAD1"] = "N1",
  ["NUMPAD2"] = "N2",
  ["NUMPAD3"] = "N3",
  ["NUMPAD4"] = "N4",
  ["NUMPAD5"] = "N5",
  ["NUMPAD6"] = "N6",
  ["NUMPAD7"] = "N7",
  ["NUMPAD8"] = "N8",
  ["NUMPAD9"] = "N9",
  ["NUMPADDECIMAL"] = "N.",
  ["NUMPADPLUS"] = "N+",
  ["NUMPADMINUS"] = "N-",
  ["NUMPADMULTIPLY"] = "N*",
  ["NUMPADDIVIDE"] = "N/",
  ["SPACE"] = "SpB",
  ["BACKSPACE"] = "BS",
  ["DELETE"] = "Del",
  ["INSERT"] = "Ins",
  ["HOME"] = "Hm",
  ["END"] = "End",
  ["PAGEUP"] = "PU",
  ["PAGEDOWN"] = "PD",
  ["ESCAPE"] = "Esc",
  ["CAPSLOCK"] = "Cap",
  ["NUMLOCK"] = "NL",
  ["PRINTSCREEN"] = "PrS",
  ["SCROLLLOCK"] = "SL",
  ["PAUSE"] = "Pau",
  ["TAB"] = "Tab",
}

local function AbbreviateKey(raw)
  if not raw or raw == "" then
    return nil
  end
  local parts = {}
  for token in raw:gmatch("[^%-]+") do
    local upper = token:upper()
    local mapped = COMPACT_KEY_MAP[upper]
    parts[#parts + 1] = mapped or token
  end
  return table.concat(parts, "+")
end

local function FormatKeybindText(bindingKey)
  return AbbreviateKey(bindingKey) or bindingKey
end

local CLICK_ICON_LEFT = "|A:NPE_LeftClick:28:28|a"
local CLICK_ICON_RIGHT = "|A:NPE_RightClick:28:28|a"

local CLICKCAST_BINDING_ORDER = {
  { dbKey = "button1", mod = nil, icon = CLICK_ICON_LEFT },
  { dbKey = "button2", mod = nil, icon = CLICK_ICON_RIGHT },
  { dbKey = "shiftbutton1", mod = "Shift+", icon = CLICK_ICON_LEFT },
  { dbKey = "shiftbutton2", mod = "Shift+", icon = CLICK_ICON_RIGHT },
  { dbKey = "ctrlbutton1", mod = "Ctrl+", icon = CLICK_ICON_LEFT },
  { dbKey = "ctrlbutton2", mod = "Ctrl+", icon = CLICK_ICON_RIGHT },
  { dbKey = "altbutton1", mod = "Alt+", icon = CLICK_ICON_LEFT },
  { dbKey = "altbutton2", mod = "Alt+", icon = CLICK_ICON_RIGHT },
}

local function IsAssistedCombatHighlightCVarEnabled()
  if _G.GetCVarBool then
    return _G.GetCVarBool("assistedCombatHighlight") == true
  end
  if _G.C_CVar and _G.C_CVar.GetCVar then
    return _G.C_CVar.GetCVar("assistedCombatHighlight") == "1"
  end
  if _G.GetCVar then
    return _G.GetCVar("assistedCombatHighlight") == "1"
  end
  return false
end

local function GetSuggestedAssistedSpellID()
  if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then
    return nil
  end
  local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell)
  spellID = ok and spellID or nil
  spellID = spellID and tonumber(spellID) or nil
  if not spellID or spellID <= 0 then
    return nil
  end
  return spellID
end

local function BuildActionSlotCommandMap()
  local map = {}
  local actionButtonUtil = _G.ActionButtonUtil
  local buttonNames = (actionButtonUtil and actionButtonUtil.ActionBarButtonNames)
    or _G.DEFAULT_ACTION_BUTTON_NAMES
  local buttonCount = tonumber(_G.NUM_ACTIONBAR_BUTTONS) or 12

  if type(buttonNames) == "table" then
    for _, prefix in ipairs(buttonNames) do
      for index = 1, buttonCount do
        local button = _G[prefix .. index]
        if button then
          local slotID = tonumber(button.action)
          if not slotID and button.GetAttribute then
            slotID = tonumber(button:GetAttribute("action"))
          end
          if slotID and slotID > 0 and not map[slotID] then
            local command = button.commandName or button.keyBoundTarget
            if not command and button.GetName then
              local name = button:GetName()
              if name and name ~= "" then
                command = "CLICK " .. name .. ":LeftButton"
              end
            end
            if command and command ~= "" then
              map[slotID] = command
            end
          end
        end
      end
    end
  end

  return map
end

function CM.InvalidateAssistedHighlightKeybindCache()
  actionSlotCommandMap = nil
  assistedActionSlotSet = nil
end

local function BuildAssistedActionSlotSet()
  if assistedActionSlotSet then
    return assistedActionSlotSet
  end
  local set = {}
  if
    C_ActionBar
    and C_ActionBar.HasAssistedCombatActionButtons
    and C_ActionBar.FindAssistedCombatActionButtons
    and C_ActionBar.HasAssistedCombatActionButtons()
  then
    local ok, slots = pcall(C_ActionBar.FindAssistedCombatActionButtons)
    slots = ok and slots or nil
    if type(slots) == "table" then
      for _, value in ipairs(slots) do
        local slot = tonumber(value)
        if slot and slot > 0 then
          set[slot] = true
        end
      end
      for key, value in pairs(slots) do
        local slot
        if type(value) == "number" then
          slot = value
        elseif value == true and type(key) == "number" then
          slot = key
        end
        if slot and slot > 0 then
          set[slot] = true
        end
      end
    end
  end
  assistedActionSlotSet = set
  return assistedActionSlotSet
end

local function GetFirstActionSlotForSpell(spellID)
  if not (spellID and C_ActionBar and C_ActionBar.FindSpellActionButtons) then
    return nil
  end
  local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)
  slots = ok and slots or nil
  if type(slots) ~= "table" then
    return nil
  end

  local assistedSlots = BuildAssistedActionSlotSet()
  local firstSlot
  local firstSlotIncludingAssisted
  for _, value in ipairs(slots) do
    local slot = tonumber(value)
    if slot and slot > 0 then
      if not firstSlotIncludingAssisted or slot < firstSlotIncludingAssisted then
        firstSlotIncludingAssisted = slot
      end
      if not assistedSlots[slot] and (not firstSlot or slot < firstSlot) then
        firstSlot = slot
      end
    end
  end
  for key, value in pairs(slots) do
    local slot
    if type(value) == "number" then
      slot = value
    elseif value == true and type(key) == "number" then
      slot = key
    end
    if slot and slot > 0 then
      if not firstSlotIncludingAssisted or slot < firstSlotIncludingAssisted then
        firstSlotIncludingAssisted = slot
      end
      if not assistedSlots[slot] and (not firstSlot or slot < firstSlot) then
        firstSlot = slot
      end
    end
  end
  return firstSlot or firstSlotIncludingAssisted
end

local function ActionSlotToBindingName(actionSlot)
  local slot = tonumber(actionSlot)
  if not slot or slot < 1 then
    return nil
  end
  local index = ((slot - 1) % 12) + 1
  local group = math.floor((slot - 1) / 12)
  if group == 0 then
    return "ACTIONBUTTON" .. index
  elseif group == 1 then
    return "MULTIACTIONBAR1BUTTON" .. index
  elseif group == 2 then
    return "MULTIACTIONBAR2BUTTON" .. index
  elseif group == 3 then
    return "MULTIACTIONBAR3BUTTON" .. index
  elseif group == 4 then
    return "MULTIACTIONBAR4BUTTON" .. index
  end
  return nil
end

local function GetClickCastDisplayForSpell(spellID)
  if not (CM.DB and CM.DB.global and CM.DB.char) then
    return nil
  end
  local actionSlot = GetFirstActionSlotForSpell(spellID)
  if not actionSlot then
    return nil
  end
  local bindingName = ActionSlotToBindingName(actionSlot)
  if not bindingName then
    return nil
  end

  local location = CM.GetBindingsLocation and CM.GetBindingsLocation() or "char"
  local bindingsRoot = CM.DB[location]
  local bindings = bindingsRoot and bindingsRoot.bindings
  if type(bindings) ~= "table" then
    return nil
  end

  for _, entry in ipairs(CLICKCAST_BINDING_ORDER) do
    local setting = bindings[entry.dbKey]
    if setting and setting.enabled and setting.value == bindingName then
      if entry.mod then
        return entry.mod .. entry.icon
      end
      return entry.icon
    end
  end

  return nil
end

local function GetBindingCommandForActionSlot(slot)
  local actionSlot = tonumber(slot)
  if not actionSlot or actionSlot < 1 then
    return nil
  end

  if not actionSlotCommandMap then
    actionSlotCommandMap = BuildActionSlotCommandMap()
  end
  if actionSlotCommandMap and actionSlotCommandMap[actionSlot] then
    return actionSlotCommandMap[actionSlot]
  end

  local index = ((actionSlot - 1) % 12) + 1
  local group = math.floor((actionSlot - 1) / 12)
  if group == 0 then
    return "ACTIONBUTTON" .. index
  elseif group == 1 then
    return "MULTIACTIONBAR1BUTTON" .. index
  elseif group == 2 then
    return "MULTIACTIONBAR2BUTTON" .. index
  elseif group == 3 then
    return "MULTIACTIONBAR3BUTTON" .. index
  elseif group == 4 then
    return "MULTIACTIONBAR4BUTTON" .. index
  end

  return nil
end

local function GetFirstBindingKeyForSpell(spellID)
  local slot = GetFirstActionSlotForSpell(spellID)
  if not slot then
    return nil
  end
  local command = GetBindingCommandForActionSlot(slot)
  if not command or not _G.GetBindingKey then
    return nil
  end
  local key1, key2 = _G.GetBindingKey(command)
  return key1 or key2
end

local function ShouldShowAssistedHighlightIcon()
  if not (CM.DB and CM.DB.global) then
    return false
  end
  local enabled = CM.DB.global.assistedHighlightEnabled
  if enabled == nil then
    enabled = CM.Constants.DatabaseDefaults.global.assistedHighlightEnabled
  end
  if not enabled then
    return false
  end
  if CM.IsCrosshairEditModeActive then
    return true
  end
  if not CM.IsCrosshairEnabled() or CM.HideCrosshairWhileMounted() then
    return false
  end
  if not (crosshairTexture and crosshairTexture.IsShown and crosshairTexture:IsShown()) then
    return false
  end
  if not IsMouselooking() then
    return false
  end
  if not (UnitAffectingCombat and UnitAffectingCombat("player")) then
    return false
  end
  if not IsAssistedCombatHighlightCVarEnabled() then
    return false
  end
  if C_AssistedCombat and C_AssistedCombat.IsAvailable then
    local ok, isAvailable = pcall(C_AssistedCombat.IsAvailable)
    if ok and isAvailable == false then
      return false
    end
  end
  return true
end

function CM.ApplyCrosshairAssistedHighlightOptions()
  EnsureAssistedHighlight()
  if not AssistedHighlightFrame then
    return
  end
  if not (CM.DB and CM.DB.global) then
    return
  end
  AssistedHighlightFrame:SetFrameStrata(crosshairFrame:GetFrameStrata())
  AssistedHighlightFrame:SetFrameLevel(crosshairFrame:GetFrameLevel() + 20)

  local g = CM.DB.global
  local d = CM.Constants.DatabaseDefaults.global
  local size = tonumber(g.assistedHighlightSize or d.assistedHighlightSize) or 36
  local offsetX = tonumber(g.assistedHighlightOffsetX or d.assistedHighlightOffsetX) or 0
  local offsetY = tonumber(g.assistedHighlightOffsetY or d.assistedHighlightOffsetY) or 0
  local opacity = 1 -- fixed, not user-adjustable
  local fontSize = 14 -- fixed, not user-adjustable
  local keybindAnchor = g.assistedHighlightKeybindAnchor
    or d.assistedHighlightKeybindAnchor
    or "RIGHT"

  AssistedHighlightFrame:SetSize(size, size)
  AssistedHighlightFrame:ClearAllPoints()
  AssistedHighlightFrame:SetPoint("CENTER", crosshairFrame, "CENTER", offsetX, offsetY)
  AssistedHighlightFrame:SetAlpha(opacity)
  if AssistedHighlightVisual then
    AssistedHighlightVisual:SetSize(size, size)
    AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", 0, 0)
  end

  SetAssistedHighlightShadowAtlas()
  AssistedHighlightFrame.shadow:SetSize(size * 2.15, size * 2.15)
  AssistedHighlightFrame.shadow:ClearAllPoints()
  AssistedHighlightFrame.shadow:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)

  SetAssistedHighlightIconBorderAtlas()
  AssistedHighlightFrame.icon:SetSize(size, size)
  AssistedHighlightFrame.iconMask:SetSize(size, size)
  if AssistedHighlightFrame.iconBorder then
    AssistedHighlightFrame.iconBorder:SetSize(size * 1.4, size * 1.4)
  end

  if AssistedHighlightFrame.keybindText then
    AssistedHighlightFrame.keybindText:ClearAllPoints()
    if keybindAnchor == "LEFT" then
      AssistedHighlightFrame.keybindText:SetPoint(
        "RIGHT",
        AssistedHighlightFrame.icon,
        "LEFT",
        -11,
        0
      )
      AssistedHighlightFrame.keybindText:SetJustifyH("RIGHT")
    elseif keybindAnchor == "TOP" then
      AssistedHighlightFrame.keybindText:SetPoint(
        "BOTTOM",
        AssistedHighlightFrame.icon,
        "TOP",
        0,
        6
      )
      AssistedHighlightFrame.keybindText:SetJustifyH("CENTER")
    elseif keybindAnchor == "BOTTOM" then
      AssistedHighlightFrame.keybindText:SetPoint(
        "TOP",
        AssistedHighlightFrame.icon,
        "BOTTOM",
        0,
        -6
      )
      AssistedHighlightFrame.keybindText:SetJustifyH("CENTER")
    else
      AssistedHighlightFrame.keybindText:SetPoint(
        "LEFT",
        AssistedHighlightFrame.icon,
        "RIGHT",
        11,
        0
      )
      AssistedHighlightFrame.keybindText:SetJustifyH("LEFT")
    end
  end

  CM.SetFontStringFromTemplate(AssistedHighlightFrame.keybindText, fontSize, _G.GameFontNormalSmall)
  AssistedHighlightFrame.keybindText:SetTextColor(1, 1, 1, 1)
  AssistedHighlightFrame.keybindText:SetShadowColor(0, 0, 0, 1)
  AssistedHighlightFrame.keybindText:SetShadowOffset(1, -1)
end

function CM.UpdateCrosshairAssistedHighlight()
  EnsureAssistedHighlight()
  if not AssistedHighlightFrame then
    return
  end

  if CM.IsCrosshairEditModeActive then
    if not ShouldShowAssistedHighlightIcon() then
      AssistedHighlightFrame:Hide()
      AssistedHighlightWasShown = false
      return
    end
    CM.ApplyCrosshairAssistedHighlightOptions()
    AssistedHighlightFrame.icon:SetTexture(134400) -- INV_Misc_QuestionMark
    AssistedHighlightFrame.icon:Show()
    if AssistedHighlightFrame.shadow then
      AssistedHighlightFrame.shadow:Show()
    end
    if AssistedHighlightFrame.iconBorder then
      AssistedHighlightFrame.iconBorder:Show()
    end
    local showKeybind = CM.DB.global.assistedHighlightShowKeybind
    if showKeybind == nil then
      showKeybind = CM.Constants.DatabaseDefaults.global.assistedHighlightShowKeybind
    end
    if showKeybind then
      AssistedHighlightFrame.keybindText:SetText("Shift+" .. CLICK_ICON_LEFT)
      AssistedHighlightFrame.keybindText:Show()
    else
      AssistedHighlightFrame.keybindText:Hide()
    end
    AssistedHighlightFrame:Show()
    if AssistedHighlightVisual then
      AssistedHighlightVisual:Show()
    end
    if not AssistedHighlightWasShown and AssistedHighlightFrame.PlayLockIn then
      AssistedHighlightFrame:PlayLockIn()
    end
    AssistedHighlightWasShown = true
    return
  end

  if not ShouldShowAssistedHighlightIcon() then
    AssistedHighlightFrame:Hide()
    AssistedHighlightWasShown = false
    return
  end

  local spellID = GetSuggestedAssistedSpellID()
  if not spellID then
    AssistedHighlightFrame:Hide()
    AssistedHighlightWasShown = false
    return
  end

  if not (C_Spell and C_Spell.GetSpellInfo) then
    AssistedHighlightFrame:Hide()
    AssistedHighlightWasShown = false
    return
  end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  info = ok and info or nil
  local texture = info and info.iconID
  if not texture then
    AssistedHighlightFrame:Hide()
    AssistedHighlightWasShown = false
    return
  end

  AssistedHighlightFrame.icon:SetTexture(texture)
  AssistedHighlightFrame.icon:Show()
  if AssistedHighlightFrame.shadow then
    AssistedHighlightFrame.shadow:Show()
  end
  if AssistedHighlightFrame.iconBorder then
    AssistedHighlightFrame.iconBorder:Show()
  end

  local showKeybind = CM.DB.global.assistedHighlightShowKeybind
  if showKeybind == nil then
    showKeybind = CM.Constants.DatabaseDefaults.global.assistedHighlightShowKeybind
  end
  if showKeybind then
    local text = GetClickCastDisplayForSpell(spellID)
    if not text then
      local key = GetFirstBindingKeyForSpell(spellID)
      text = FormatKeybindText(key)
    end
    if text and text ~= "" then
      AssistedHighlightFrame.keybindText:SetText(text)
      AssistedHighlightFrame.keybindText:SetShadowColor(0, 0, 0, 1)
      AssistedHighlightFrame.keybindText:SetShadowOffset(1, -1)
      AssistedHighlightFrame.keybindText:Show()
    else
      AssistedHighlightFrame.keybindText:Hide()
    end
  else
    AssistedHighlightFrame.keybindText:Hide()
  end

  AssistedHighlightFrame:Show()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:Show()
  end
  if not AssistedHighlightWasShown and AssistedHighlightFrame.PlayLockIn then
    AssistedHighlightFrame:PlayLockIn()
  end
  AssistedHighlightWasShown = true
end

function CM.InitAssistedHighlight(opts)
  crosshairFrame = opts and opts.crosshairFrame or crosshairFrame
  crosshairTexture = opts and opts.crosshairTexture or crosshairTexture
end
