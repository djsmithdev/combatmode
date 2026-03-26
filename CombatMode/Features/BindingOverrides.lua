---------------------------------------------------------------------------------------
--  Features/BindingOverrides.lua — CLICK CASTING — overrides, macros, ground @cursor
---------------------------------------------------------------------------------------
--  Builds secure macro proxy buttons and SetMouselookOverrideBinding wiring so
--  action-bar and click-cast inputs run pre-lines (reticle /target selection) and
--  optional [@cursor] casts for whitelisted ground spells. Keyboard slot overrides
--  duplicate that path when macroInjectionClickCastOnly is off (priority overrides). Mouselook uses
--  LeftButton on proxy buttons.
--
--  Architecture:
--    • Core enables via BootstrapFeatureModules (OverrideDefaultButtons, ApplyGroundCastKeyOverrides,
--      ApplyToggleFocusTargetBinding) and REFRESH_BINDINGS_EVENTS (coalesced in Core.lua) → RefreshClickCastMacros.
--    • All injection paths honor CM.DB.char.reticleTargeting; GetBindingsLocation()
--      selects char vs global binding storage.
--    • Toggle-focus macro text is updated here; binding name is Combat Mode specific.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local ClearOverrideBindings = _G.ClearOverrideBindings
local GetActionInfo = _G.GetActionInfo
local GetBindingKey = _G.GetBindingKey
local InCombatLockdown = _G.InCombatLockdown
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding
local SetOverrideBinding = _G.SetOverrideBinding
local SetOverrideBindingClick = _G.SetOverrideBindingClick
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

-- Click-cast macro wrapper: binding value (e.g. ACTIONBUTTON1) -> pre-line + /click frameName.
local CLICKCAST_BARS = {
  { bind = "ACTIONBUTTON", frame = "ActionButton", count = 12 },
  { bind = "MULTIACTIONBAR1BUTTON", frame = "MultiBarBottomLeftButton", count = 12 },
  { bind = "MULTIACTIONBAR2BUTTON", frame = "MultiBarBottomRightButton", count = 12 },
  { bind = "MULTIACTIONBAR3BUTTON", frame = "MultiBarRightButton", count = 12 },
  { bind = "MULTIACTIONBAR4BUTTON", frame = "MultiBarLeftButton", count = 12 },
}

-- Reticle targeting macro text helpers live in TargetingMacroBuilder.lua.

-- Ordered list of all binding names (ACTIONBUTTON1..12, MULTIACTIONBAR1BUTTON1..12, etc.)
local OrderedBindingNames = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    OrderedBindingNames[#OrderedBindingNames + 1] = bar.bind .. i
  end
end

-- Owner frame only for ClearOverrideBindings / SetOverrideBinding*; proxy buttons live on UIParent
-- like CombatModeClickCast* so secure macro execution matches the working mouselook path.
local GroundCastKeyOverrideOwner = CreateFrame("Frame", nil, UIParent)
local SlotFramesByBindingName = {}

for idx, bindingName in ipairs(OrderedBindingNames) do
  local f = CreateFrame("Button", "CombatModeSlot" .. idx, UIParent, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  SlotFramesByBindingName[bindingName] = f
end

-- Click pre-line moved to TargetingMacroBuilder.lua

local CLICKCAST_KEYS = {
  "BUTTON1",
  "BUTTON2",
  "SHIFT-BUTTON1",
  "SHIFT-BUTTON2",
  "CTRL-BUTTON1",
  "CTRL-BUTTON2",
  "ALT-BUTTON1",
  "ALT-BUTTON2",
}
local ClickCastFramesByKey = {}
for i, key in ipairs(CLICKCAST_KEYS) do
  local f =
    CreateFrame("Button", "CombatModeClickCast" .. i, UIParent, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  ClickCastFramesByKey[key] = f
end

-- Secure action button for toggle focus target
local ToggleFocusTargetOverrideOwner = CreateFrame("Frame", nil, UIParent)
local ToggleFocusTargetButton = CreateFrame(
  "Button",
  "CombatModeToggleFocusTarget",
  ToggleFocusTargetOverrideOwner,
  "SecureActionButtonTemplate"
)
ToggleFocusTargetButton:SetAttribute("type", "macro")
-- macrotext set by UpdateToggleFocusTargetMacroText() based on reticleTargetingEnemyOnly
ToggleFocusTargetButton:RegisterForClicks("AnyUp", "AnyDown")

local function UpdateToggleFocusTargetMacroText()
  if not ToggleFocusTargetButton then
    return
  end
  local char_config = CM.DB.char
  local macros_const = CM.Constants.Macros
  local macroFocusCrosshair = char_config.reticleTargetingEnemyOnly
      and macros_const.CM_ToggleFocusEnemy
    or macros_const.CM_ToggleFocusAny
  local macroText = char_config.focusCurrentTargetNotCrosshair and macros_const.CM_ToggleFocusTarget
    or macroFocusCrosshair
  ToggleFocusTargetButton:SetAttribute("macrotext", macroText)
end

-- BuildClickCastMacroText moved to TargetingMacroBuilder.lua

local function SetClickCastFrameMacro(frame, macroText)
  if frame and macroText and not InCombatLockdown() then
    frame:SetAttribute("macrotext", macroText)
  end
end

-- Returns true if the given action bar binding (e.g. ACTIONBUTTON5) currently has a macro in that slot.
-- Always checks the regular ActionButton slot directly, not override/bonus bars, since macros are stored in the slot itself.
local function IsSlotMacro(bindingValue)
  -- For ACTIONBUTTON bindings, check the slot number directly (1-12) instead of using the frame's action attribute,
  -- which may be stale after dismounting (e.g., still pointing to override bar action 127 that no longer exists)
  local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  if buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      -- Check the slot directly - this works even when frame's action attribute is stale after dismounting
      local getOk, atype = pcall(GetActionInfo, slotNum)
      return getOk and atype == "macro"
    end
  end

  -- For non-ACTIONBUTTON bindings, use effective (addon) frame and check its action
  local frameToCheck = CM.GetEffectiveBarButtonFrameName(bindingValue)
  if not frameToCheck then
    return false
  end
  local ok, actionFrame = pcall(function()
    return _G[frameToCheck]
  end)
  if not ok or not actionFrame then
    return false
  end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action")
    or actionFrame.action
  local action = rawAction and tonumber(rawAction)
  if not action or action <= 0 then
    return false
  end
  local getOk, atype = pcall(GetActionInfo, action)
  return getOk and atype == "macro"
end

--- Spell id on the resolved action bar button for this binding, or nil if not a spell (e.g. macro, empty).
--- Mirrors resolution inside BuildClickCastMacroText so behavior stays aligned.
local function GetSpellIdForActionBarBinding(bindingName)
  local clickFrame = CM.GetEffectiveBarButtonFrameName(bindingName)
  if not clickFrame then
    return nil
  end
  local buttonNum = bindingName:match("^ACTIONBUTTON(%d+)$")
  local useConditionalClick = buttonNum ~= nil

  if useConditionalClick and buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      local getOk, atype = pcall(GetActionInfo, slotNum)
      if getOk and atype == "macro" then
        return nil
      end
    end
  end

  local ok, actionFrame = pcall(function()
    return _G[clickFrame]
  end)
  if not ok or not actionFrame then
    return nil
  end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action")
    or actionFrame.action
  local action = rawAction and tonumber(rawAction)
  if not action or action <= 0 then
    return nil
  end
  local getOk, atype, id = pcall(GetActionInfo, action)
  if not getOk or atype ~= "spell" or not id or type(id) ~= "number" or id <= 0 then
    return nil
  end
  return id
end

-- House Editor (housing) is active; do not override action bar keys so housing bindings (e.g. R to return item) work.
local function IsHouseEditorActive()
  if not _G.C_HouseEditor or not _G.C_HouseEditor.IsHouseEditorActive then
    return false
  end
  local ok, active = pcall(_G.C_HouseEditor.IsHouseEditorActive)
  return ok and active
end

local function IsMouseBindingKey(key)
  if not key or key == "" then
    return false
  end
  return key:match("BUTTON%d+") ~= nil or key:match("MOUSEWHEEL") ~= nil
end

-- Ground keyboard path: override keys to click a frame.
-- Use LeftButton clicks; this is the most reliable click type across Blizzard bars and our proxy buttons.
-- Priority overrides so ReassignBindings does not replace Combat Mode last.
local GROUND_CAST_KEY_PRIORITY = true

local function ApplyGroundCastKeyboardBinding(key, frameName)
  if not key or not frameName or frameName == "" then
    return
  end
  -- Match ApplyToggleFocusTargetBinding: SetOverrideBindingClick drives SecureActionButtonTemplate reliably.
  SetOverrideBindingClick(
    GroundCastKeyOverrideOwner,
    GROUND_CAST_KEY_PRIORITY,
    key,
    frameName,
    "LeftButton"
  )
end

-- Override keyboard keys (Q, E, etc.) to click our slot frame so the same macro logic runs (pre-line + /click or /cast [@cursor] for ground spells). No per-spell macros.
-- When macroInjectionClickCastOnly is true, skip keyboard overrides so only the 8 click-cast mouse bindings get the injection.
function CM.ApplyGroundCastKeyOverrides()
  if InCombatLockdown() then
    return
  end
  ClearOverrideBindings(GroundCastKeyOverrideOwner)
  -- When reticle targeting is off, no macro injection on keybinds at all.
  if not CM.DB.char.reticleTargeting then
    return
  end
  -- When macroInjectionClickCastOnly is on, only click-cast bindings get injection; skip keyboard overrides.
  if CM.DB.char.macroInjectionClickCastOnly then
    return
  end
  -- When House Editor (housing) is active, do not override action bar keys so housing bindings (e.g. R to return item to box) work.
  if IsHouseEditorActive() then
    return
  end

  for _, bindingName in ipairs(OrderedBindingNames) do
    local key1 = GetBindingKey(bindingName)
    local key2 = select(2, GetBindingKey(bindingName))
    local keys = { key1, key2 }

    for _, key in ipairs(keys) do
      -- Never override mouse-button bindings here; click-cast already owns mouse buttons.
      if key and not IsMouseBindingKey(key) then
        local realFrame = CM.GetEffectiveBarButtonFrameName(bindingName)
        if realFrame and IsSlotMacro(bindingName) then
          -- Slot is a macro: do not inject. Prefer the native binding name so the macro runs as written.
          SetOverrideBinding(GroundCastKeyOverrideOwner, GROUND_CAST_KEY_PRIORITY, key, bindingName)
        else
          local spellId = GetSpellIdForActionBarBinding(bindingName)
          if
            realFrame
            and spellId
            and CM.IsExcludedFromTargetingSpell(spellId)
            and not CM.IsCastAtCursorSpell(spellId)
          then
            SetOverrideBinding(
              GroundCastKeyOverrideOwner,
              GROUND_CAST_KEY_PRIORITY,
              key,
              bindingName
            )
          else
            local frame = SlotFramesByBindingName[bindingName]
            local macroText = CM.BuildClickCastMacroText(bindingName)
            if frame and macroText then
              SetClickCastFrameMacro(frame, macroText)
              ApplyGroundCastKeyboardBinding(key, frame:GetName())
            end
          end
        end
      end
    end
  end
end

function CM.RefreshClickCastMacros()
  if InCombatLockdown() then
    return
  end
  CM.ClearAddonButtonCaches()
  -- Re-apply all bindings so macro slots get "click real button" and spell slots get our frame.
  -- This refreshes both keyboard bindings (via ApplyGroundCastKeyOverrides) and mouse button bindings (via OverrideDefaultButtons)
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
end

local function ClickCastMouseButton(key)
  return key:match("BUTTON2") and "RightButton" or "LeftButton"
end

function CM.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then
    return
  end

  local key, value = buttonSettings.key, buttonSettings.value
  local valueToUse
  if value == "MACRO" then
    valueToUse = "MACRO " .. buttonSettings.macroName
  elseif value == "CLEARTARGET" then
    valueToUse = "MACRO CM_ClearTarget"
  elseif value == "CLEARFOCUS" then
    valueToUse = "MACRO CM_ClearFocus"
  elseif value == "TOGGLEFOCUSANY" then
    valueToUse = "MACRO CM_ToggleFocusAny"
  elseif value == "TOGGLEFOCUSENEMY" then
    valueToUse = "MACRO CM_ToggleFocusEnemy"
  else
    -- When reticle targeting is off, no macro wrapping: use raw binding (no pre-line, no castAtCursor/excludeFromTargeting).
    if not CM.DB.char.reticleTargeting then
      valueToUse = value
    else
      local realFrame = CM.GetEffectiveBarButtonFrameName(value)
      if realFrame and IsSlotMacro(value) then
        -- Slot is a macro: bind key to click the real action bar button so the macro runs as written.
        valueToUse = "CLICK " .. realFrame .. ":" .. ClickCastMouseButton(key)
      else
        local frame = ClickCastFramesByKey[key]
        local macroText = CM.BuildClickCastMacroText(value)
        if frame and macroText then
          SetClickCastFrameMacro(frame, macroText)
          valueToUse = "CLICK " .. frame:GetName() .. ":" .. ClickCastMouseButton(key)
        else
          valueToUse = value
        end
      end
    end
  end
  SetMouselookOverrideBinding(key, valueToUse)
  CM.DebugPrint(key .. "'s override binding is now " .. valueToUse)
end

function CM.OverrideDefaultButtons()
  for _, button in pairs(CM.Constants.ButtonsToOverride) do
    CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button])
  end
end

function CM.ResetBindingOverride(buttonSettings)
  SetMouselookOverrideBinding(buttonSettings.key, nil)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- Apply override binding for toggle focus target
function CM.ApplyToggleFocusTargetBinding()
  if InCombatLockdown() then
    return
  end
  UpdateToggleFocusTargetMacroText()
  local key = GetBindingKey("Combat Mode - Toggle Focus Target")
  if key then
    ClearOverrideBindings(ToggleFocusTargetOverrideOwner)
    SetOverrideBindingClick(
      ToggleFocusTargetOverrideOwner,
      false,
      key,
      ToggleFocusTargetButton:GetName(),
      "LeftButton"
    )
    CM.DebugPrint("Toggle Focus Target binding applied to " .. tostring(key))
  end
end

-- Handler for toggle focus target keybinding (fallback - should be overridden)
function _G.CombatMode_ToggleFocusTarget()
  -- Nothing inside here will work as it will be overriden by ApplyToggleFocusTargetBinding calling UpdateToggleFocusTargetMacroText
end
