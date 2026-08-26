---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Keybinds.lua — CROSSHAIR — assist keybind resolve
---------------------------------------------------------------------------------------
--  What it does: Resolves click-cast or keyboard keybind glyphs for the Assisted Combat
--  suggestion icon (modifier BLPs + mouse atlases, or abbreviated FrizQT OUTLINE text).
--  Owns action-slot / assisted-slot caches and style apply helpers.
--  Architecture / how it works:
--    • CM.AssistedHighlightKeybinds table: GetClickCastDisplayForSpell,
--      FormatKeybindText / GetFirstBindingKeyForSpell, ApplyClickCast/Keyboard styles,
--      STYLE_CLICKCAST / STYLE_KEYBOARD, preview icon markups.
--    • ActionSlotToBindingName uses CM.Constants.ClickCastBars actionBase ranges
--      (incl. MultiBar5–7 slots 145–180).
--    • CM.InvalidateAssistedHighlightKeybindCache clears slot maps (EventRouter bars).
--  Does not: Own IconMask chrome, ProcLoop/fade, cast swipe/press/break (sibling modules).
--  Related: Core/Crosshair/AssistedHighlight/Assist.lua, Core/Runtime/EventRouter.lua,
--  Core/ClickCasting/BindingOverrides.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_ActionBar = _G.C_ActionBar

-- Lua stdlib
local math = _G.math
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local table = _G.table
local tonumber = _G.tonumber
local type = _G.type

local Keybinds = {}
CM.AssistedHighlightKeybinds = Keybinds

local assistedActionSlotSet
local actionSlotCommandMap

local KEYBOARD_KEYBIND_FONT = "Fonts\\FRIZQT__.TTF"
local KEYBOARD_KEYBIND_FONT_SIZE = 15
local KEYBOARD_KEYBIND_FONT_FLAGS = "OUTLINE"

Keybinds.STYLE_CLICKCAST = "clickcast"
Keybinds.STYLE_KEYBOARD = "keyboard"
Keybinds.KEYBOARD_OFFSET_X = 10
Keybinds.KEYBOARD_OFFSET_Y = 12

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

function Keybinds.FormatKeybindText(bindingKey)
  return AbbreviateKey(bindingKey) or bindingKey
end

-- Native mouse atlases are 52x69 (Interface/HelpFrame/NewPlayerExperienceParts).
-- |A:atlas:height:width| must keep that aspect; modifier BLPs stay square.
local CLICK_MOD_ICON_SIZE = 28
local CLICK_MOUSE_ICON_HEIGHT = 28
local CLICK_MOUSE_ICON_WIDTH = math.floor(CLICK_MOUSE_ICON_HEIGHT * 52 / 69 + 0.5) -- 21
local CLICK_ICON_LEFT = "|A:newplayertutorial-icon-mouse-leftbutton:"
  .. CLICK_MOUSE_ICON_HEIGHT
  .. ":"
  .. CLICK_MOUSE_ICON_WIDTH
  .. "|a"
local CLICK_ICON_RIGHT = "|A:newplayertutorial-icon-mouse-rightbutton:"
  .. CLICK_MOUSE_ICON_HEIGHT
  .. ":"
  .. CLICK_MOUSE_ICON_WIDTH
  .. "|a"

local function ModifierTextureMarkup(path)
  if not path or path == "" then
    return nil
  end
  return "|T" .. path .. ":" .. CLICK_MOD_ICON_SIZE .. ":" .. CLICK_MOD_ICON_SIZE .. "|t"
end

local MOD_ICON_SHIFT = ModifierTextureMarkup(CM.Constants.ModifierKeyShift)
local MOD_ICON_CTRL = ModifierTextureMarkup(CM.Constants.ModifierKeyCtrl)
local MOD_ICON_ALT = ModifierTextureMarkup(CM.Constants.ModifierKeyAlt)

Keybinds.CLICK_ICON_LEFT = CLICK_ICON_LEFT
Keybinds.CLICK_ICON_RIGHT = CLICK_ICON_RIGHT
Keybinds.MOD_ICON_SHIFT = MOD_ICON_SHIFT
Keybinds.MOD_ICON_CTRL = MOD_ICON_CTRL
Keybinds.MOD_ICON_ALT = MOD_ICON_ALT

local CLICKCAST_BINDING_ORDER = {
  { dbKey = "button1", mod = nil, icon = CLICK_ICON_LEFT },
  { dbKey = "button2", mod = nil, icon = CLICK_ICON_RIGHT },
  { dbKey = "shiftbutton1", mod = MOD_ICON_SHIFT, icon = CLICK_ICON_LEFT },
  { dbKey = "shiftbutton2", mod = MOD_ICON_SHIFT, icon = CLICK_ICON_RIGHT },
  { dbKey = "ctrlbutton1", mod = MOD_ICON_CTRL, icon = CLICK_ICON_LEFT },
  { dbKey = "ctrlbutton2", mod = MOD_ICON_CTRL, icon = CLICK_ICON_RIGHT },
  { dbKey = "altbutton1", mod = MOD_ICON_ALT, icon = CLICK_ICON_LEFT },
  { dbKey = "altbutton2", mod = MOD_ICON_ALT, icon = CLICK_ICON_RIGHT },
}

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

--- True when `slot` is a Blizzard Assisted Combat action button (suggestion spell churn).
function CM.IsAssistedCombatActionSlot(slot)
  slot = tonumber(slot)
  if not slot or slot <= 0 then
    return false
  end
  return BuildAssistedActionSlotSet()[slot] == true
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
  local bars = CM.Constants and CM.Constants.ClickCastBars
  if bars then
    for _, bar in ipairs(bars) do
      local base = bar.actionBase
      local count = bar.count or 12
      if base and slot >= base and slot < base + count then
        return bar.bind .. (slot - base + 1)
      end
    end
  end
  return nil
end

function Keybinds.GetClickCastDisplayForSpell(spellID)
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
        return entry.mod .. entry.icon, Keybinds.STYLE_CLICKCAST
      end
      return entry.icon, Keybinds.STYLE_CLICKCAST
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

  return ActionSlotToBindingName(actionSlot)
end

function Keybinds.GetFirstBindingKeyForSpell(spellID)
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

function Keybinds.ApplyClickCastKeybindStyle(label)
  if not label then
    return
  end
  label:SetTextColor(1, 1, 1, 1)
  label:SetShadowColor(0, 0, 0, 1)
  label:SetShadowOffset(1, -1)
end

function Keybinds.ApplyKeyboardKeybindStyle(label)
  if not label then
    return
  end
  label:SetFont(KEYBOARD_KEYBIND_FONT, KEYBOARD_KEYBIND_FONT_SIZE, KEYBOARD_KEYBIND_FONT_FLAGS)
  label:SetTextColor(1, 1, 1, 1)
  label:SetShadowColor(0, 0, 0, 0)
  label:SetShadowOffset(0, 0)
end
