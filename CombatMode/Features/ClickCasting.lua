---------------------------------------------------------------------------------------
--  Features/ClickCasting.lua — CLICK CASTING — overrides, macros, ground @cursor
---------------------------------------------------------------------------------------
--  Builds secure macro proxy buttons and SetMouselookOverrideBinding wiring so
--  action-bar and click-cast inputs run pre-lines (reticle /target selection) and
--  optional [@cursor] casts for whitelisted ground spells. Keyboard slot overrides
--  duplicate that path when macroInjectionClickCastOnly is off.
--
--  Architecture:
--    • Core enables via BootstrapFeatureModules (OverrideDefaultButtons, ApplyGroundCastKeyOverrides,
--      ApplyToggleFocusTargetBinding) and REFRESH_BINDINGS_EVENTS → RefreshClickCastMacros.
--    • All injection paths honor CM.DB.char.reticleTargeting; GetBindingsLocation()
--      selects char vs global binding storage.
--    • Toggle-focus macro text is updated here; binding name is Combat Mode specific.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local C_ActionBar = _G.C_ActionBar
local C_Spell = _G.C_Spell
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
local strtrim = _G.strtrim
local string = _G.string
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

-- Click-cast macro wrapper: binding value (e.g. ACTIONBUTTON1) -> pre-line + /click frameName.
local CLICKCAST_BARS = {
  { bind = "ACTIONBUTTON",          frame = "ActionButton",              count = 12 },
  { bind = "MULTIACTIONBAR1BUTTON", frame = "MultiBarBottomLeftButton",  count = 12 },
  { bind = "MULTIACTIONBAR2BUTTON", frame = "MultiBarBottomRightButton", count = 12 },
  { bind = "MULTIACTIONBAR3BUTTON", frame = "MultiBarRightButton",       count = 12 },
  { bind = "MULTIACTIONBAR4BUTTON", frame = "MultiBarLeftButton",        count = 12 },
}
local BindingToClickFrame = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    BindingToClickFrame[bar.bind .. i] = bar.frame .. i
  end
end

-- Helper function to check which action bar type is currently active
-- Returns the frame prefix for the active bar type, or nil if using default bar
local function GetActiveActionBarType()
  if C_ActionBar then
    -- Check for override action bar (vehicles, quest UIs, etc.)
    if C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() then
      return "OverrideActionBarButton"
    end
    -- Check for bonus action bar (druid forms, rogue stealth, etc.)
    if C_ActionBar.HasBonusActionBar and C_ActionBar.HasBonusActionBar() then
      return "BonusActionButton"
    end
    -- Check for extra action bar (encounter-specific abilities)
    if C_ActionBar.HasExtraActionBar and C_ActionBar.HasExtraActionBar() then
      -- Extra action bar uses ExtraActionButton1, not ACTIONBUTTON bindings
      return nil
    end
    -- Check for temp shapeshift action bar
    if C_ActionBar.HasTempShapeshiftActionBar and C_ActionBar.HasTempShapeshiftActionBar() then
      return "TempShapeshiftActionButton"
    end
  end

  -- Fallback to frame visibility check for override bar (for older clients or if API unavailable)
  local overrideBar = _G.OverrideActionBar
  if overrideBar and overrideBar:IsShown() then
    return "OverrideActionBarButton"
  end

  -- Default action bar
  return nil
end

-- Helper function to resolve the correct frame name for ACTIONBUTTON bindings
-- Checks for OverrideActionBarButton, BonusActionButton, or TempShapeshiftActionButton when active,
-- falls back to ActionButton otherwise
local function ResolveActionButtonFrame(bindingValue)
  if not bindingValue:match("^ACTIONBUTTON") then
    -- Not an ACTIONBUTTON binding, return the mapped frame directly
    return BindingToClickFrame[bindingValue]
  end

  -- Extract button number from binding (e.g., "ACTIONBUTTON5" -> 5)
  local buttonNum = bindingValue:match("(%d+)$")
  if not buttonNum then
    return BindingToClickFrame[bindingValue]
  end

  -- Check which action bar type is currently active
  local activeBarType = GetActiveActionBarType()
  if activeBarType then
    local frameName = activeBarType .. buttonNum
    local ok, actionFrame = pcall(function() return _G[frameName] end)
    if ok and actionFrame then
      -- Check if the frame has an action assigned
      local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
      local action = rawAction and tonumber(rawAction)
      if action and action > 0 then
        return frameName
      end
    end
  end

  -- Fall back to regular ActionButton
  return BindingToClickFrame[bindingValue]
end

local CLICKCAST_PRE_LINE_ANY =
"/target [@focus,exists,nodead] focus; [nomounted,@mouseover,exists] mouseover"                             -- used if reticleTargetingEnemyOnly is OFF- Targets any mouseover unit if it exists.
local CLICKCAST_PRE_LINE_ENEMY =
"/target [@focus,exists,nodead] focus; [nomounted,@mouseover,harm,nodead][nomounted,@anyenemy,harm,nodead]" --  used if reticleTargetingEnemyOnly is ON - This preline will first try to cast the spell at the unit under the crosshair (mouseover) that is hostile (harm) and alive (nodead). If no unit matches that condition, it tries to find a locked target through the "target" portion of the anyenemy UnitId. If no target exists, it falls back to the "softenemy" UnitId, which is Action Targeting.

-- Returns true if spellId is in the user's "Cast @Cursor Spells" list (comma-separated names in options).
local function IsCastAtCursorSpell(spellId)
  if not spellId or spellId <= 0 then return false end
  local list = CM.DB.char.castAtCursorSpells
  if not list or list == "" then return false end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then set[n] = true end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then return false end
  return set[spellName:lower()] == true
end

-- Returns true if spellId is in the user's "Exclude from targeting" blacklist (no pre-line applied).
local function IsExcludedFromTargetingSpell(spellId)
  if not spellId or spellId <= 0 then return false end
  local list = CM.DB.char.excludeFromTargetingSpells
  if not list or list == "" then return false end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then set[n] = true end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then return false end
  return set[spellName:lower()] == true
end

-- Ordered list of all binding names (ACTIONBUTTON1..12, MULTIACTIONBAR1BUTTON1..12, etc.)
local OrderedBindingNames = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    OrderedBindingNames[#OrderedBindingNames + 1] = bar.bind .. i
  end
end

local GroundCastKeyOverrideOwner = CreateFrame("Frame", nil, UIParent)
local SlotFramesByBindingName = {}
for idx, bindingName in ipairs(OrderedBindingNames) do
  local f = CreateFrame("Button", "CombatModeSlot" .. idx, GroundCastKeyOverrideOwner, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  SlotFramesByBindingName[bindingName] = f
end

local function GetClickCastPreLine()
  if not CM.DB.char.reticleTargeting then return nil end
  if CM.DB.char.reticleTargetingEnemyOnly then return CLICKCAST_PRE_LINE_ENEMY end
  return CLICKCAST_PRE_LINE_ANY
end

local CLICKCAST_KEYS = { "BUTTON1", "BUTTON2", "SHIFT-BUTTON1", "SHIFT-BUTTON2", "CTRL-BUTTON1", "CTRL-BUTTON2",
  "ALT-BUTTON1", "ALT-BUTTON2" }
local ClickCastFramesByKey = {}
for i, key in ipairs(CLICKCAST_KEYS) do
  local f = CreateFrame("Button", "CombatModeClickCast" .. i, UIParent, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  ClickCastFramesByKey[key] = f
end

-- Secure action button for toggle focus target
local ToggleFocusTargetOverrideOwner = CreateFrame("Frame", nil, UIParent)
local ToggleFocusTargetButton = CreateFrame("Button", "CombatModeToggleFocusTarget", ToggleFocusTargetOverrideOwner,
  "SecureActionButtonTemplate")
ToggleFocusTargetButton:SetAttribute("type", "macro")
-- macrotext set by UpdateToggleFocusTargetMacroText() based on reticleTargetingEnemyOnly
ToggleFocusTargetButton:RegisterForClicks("AnyUp", "AnyDown")

local function UpdateToggleFocusTargetMacroText()
  if not ToggleFocusTargetButton then return end
  local char_config = CM.DB.char
  local macros_const = CM.Constants.Macros
  local macroFocusCrosshair = char_config.reticleTargetingEnemyOnly and macros_const.CM_ToggleFocusEnemy or
      macros_const.CM_ToggleFocusAny
  local macroText = char_config.focusCurrentTargetNotCrosshair and macros_const.CM_ToggleFocusTarget or
      macroFocusCrosshair
  ToggleFocusTargetButton:SetAttribute("macrotext", macroText)
end

local function BuildClickCastMacroText(bindingValue)
  -- When reticle targeting is off, no macro wrapping (no pre-line, no castAtCursor, no excludeFromTargeting).
  if not CM.DB.char.reticleTargeting then return nil end
  -- For ACTIONBUTTON bindings, use a conditional /click so action bar type is resolved
  -- at macro run time (works when action bars change in combat; we can't refresh bindings then).
  local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  local useConditionalClick = buttonNum ~= nil

  local clickFrame = ResolveActionButtonFrame(bindingValue)
  if not clickFrame then return nil end

  -- Check if this is a special action bar button (don't inject preline for special bar abilities)
  local isSpecialBarButton = clickFrame:match("^OverrideActionBarButton") or
      clickFrame:match("^BonusActionButton") or
      clickFrame:match("^TempShapeshiftActionButton")

  local castLine
  if useConditionalClick then
    -- Use conditional macro to check for override bar at runtime
    -- (works when exiting vehicle in combat; we can't refresh bindings then)
    -- For bonus/shapeshift bars, bindings are refreshed via events when out of combat
    castLine = "/click [overridebar][possessbar][shapeshift][vehicleui] OverrideActionBarButton" ..
        buttonNum .. "; ActionButton" .. buttonNum
  else
    castLine = "/click " .. clickFrame
  end

  -- For ACTIONBUTTON bindings, check slot directly (same as IsSlotMacro) to avoid stale action attributes after dismounting
  if useConditionalClick and buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      local getOk, atype = pcall(GetActionInfo, slotNum)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
      end
    end
  end

  local ok, actionFrame = pcall(function() return _G[clickFrame] end)
  if ok and actionFrame then
    local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
    local action = rawAction and tonumber(rawAction)
    if action and action > 0 then
      local getOk, atype, id = pcall(GetActionInfo, action)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
        -- Special action bar abilities (override, bonus, shapeshift): don't inject pre-line, just click the button directly
        if isSpecialBarButton then
          return castLine
        end
        -- Ground-targeted spell from whitelist: use /cast [@cursor] only (no pre-line).
        if atype == "spell" and id and type(id) == "number" and id > 0 and IsCastAtCursorSpell(id) then
          local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
          local spellName = spellInfo and spellInfo.name
          if spellName and spellName ~= "" then
            return "/cast [@cursor] " .. spellName
          end
          return "/cast [@cursor] spell:" .. id
        end
        -- Spell in blacklist (e.g. self-cast defensives): don't apply targeting pre-line.
        if atype == "spell" and id and type(id) == "number" and id > 0 and IsExcludedFromTargetingSpell(id) then
          return castLine
        end
      end
    end
  end

  -- Don't inject preline for special action bar buttons
  if isSpecialBarButton then
    return castLine
  end

  local pre = GetClickCastPreLine()
  -- Do not prefix pre-line with [nooverridebar]; that can be misinterpreted in combat and echo to chat.
  return pre and (pre .. "\n" .. castLine) or castLine
end

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

  -- For non-ACTIONBUTTON bindings, use resolved frame and check its action
  local frameToCheck = ResolveActionButtonFrame(bindingValue)
  if not frameToCheck then return false end
  local ok, actionFrame = pcall(function() return _G[frameToCheck] end)
  if not ok or not actionFrame then return false end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
  local action = rawAction and tonumber(rawAction)
  if not action or action <= 0 then return false end
  local getOk, atype = pcall(GetActionInfo, action)
  return getOk and atype == "macro"
end

--- Spell id on the resolved action bar button for this binding, or nil if not a spell (e.g. macro, empty).
--- Mirrors resolution inside BuildClickCastMacroText so behavior stays aligned.
local function GetSpellIdForActionBarBinding(bindingName)
  local clickFrame = ResolveActionButtonFrame(bindingName)
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

  local ok, actionFrame = pcall(function() return _G[clickFrame] end)
  if not ok or not actionFrame then
    return nil
  end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
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
  if not _G.C_HouseEditor or not _G.C_HouseEditor.IsHouseEditorActive then return false end
  local ok, active = pcall(_G.C_HouseEditor.IsHouseEditorActive)
  return ok and active
end

-- Override keyboard keys (Q, E, etc.) to click our slot frame so the same macro logic runs (pre-line + /click or /cast [@cursor] for ground spells). No per-spell macros.
-- When macroInjectionClickCastOnly is true, skip keyboard overrides so only the 8 click-cast mouse bindings get the injection.
function CM.ApplyGroundCastKeyOverrides()
  if InCombatLockdown() then return end
  ClearOverrideBindings(GroundCastKeyOverrideOwner)
  -- When reticle targeting is off, no macro injection on keybinds at all.
  if not CM.DB.char.reticleTargeting then return end
  -- When macroInjectionClickCastOnly is on, only click-cast bindings get injection; skip keyboard overrides.
  if CM.DB.char.macroInjectionClickCastOnly then return end
  -- When House Editor (housing) is active, do not override action bar keys so housing bindings (e.g. R to return item to box) work.
  if IsHouseEditorActive() then return end
  for _, bindingName in ipairs(OrderedBindingNames) do
    local key = GetBindingKey(bindingName)
    if key then
      local realFrame = ResolveActionButtonFrame(bindingName)
      if realFrame and IsSlotMacro(bindingName) then
        -- Slot is a macro: bind key to click the real action bar button directly (same as click-cast path).
        -- Using an intermediate frame with a /click macro breaks in default UI (key doesn't fire the macro).
        -- We refresh on UPDATE_OVERRIDE_ACTIONBAR etc., so the key will click OverrideActionBarButton when
        -- mounted and ActionButton when not. In-combat dismount cannot refresh, so key may stay on override bar until out of combat.
        SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, realFrame, "LeftButton")
      else
        -- Excluded-from-reticle: no targeting pre-line needed, but CombatModeSlot* + macrotext is still a macro
        -- path (breaks Press and Hold). SetOverrideBindingClick on the bar button simulates a mouse click and
        -- often casts on release only. Dispatch the native binding name instead so keyboard + Press and Hold work.
        local spellId = GetSpellIdForActionBarBinding(bindingName)
        if
            realFrame
            and spellId
            and IsExcludedFromTargetingSpell(spellId)
            and not IsCastAtCursorSpell(spellId)
        then
          SetOverrideBinding(GroundCastKeyOverrideOwner, false, key, bindingName)
        else
          local frame = SlotFramesByBindingName[bindingName]
          local macroText = BuildClickCastMacroText(bindingName)
          if frame and macroText then
            SetClickCastFrameMacro(frame, macroText)
            SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, frame:GetName(), "LeftButton")
          end
        end
      end
    end
  end
end

function CM.RefreshClickCastMacros()
  if InCombatLockdown() then return end
  -- Re-apply all bindings so macro slots get "click real button" and spell slots get our frame.
  -- This refreshes both keyboard bindings (via ApplyGroundCastKeyOverrides) and mouse button bindings (via OverrideDefaultButtons)
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
end

local function ClickCastMouseButton(key)
  return key:match("BUTTON2") and "RightButton" or "LeftButton"
end

function CM.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then return end

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
      local realFrame = ResolveActionButtonFrame(value)
      if realFrame and IsSlotMacro(value) then
        -- Slot is a macro: bind key to click the real action bar button so the macro runs as written.
        valueToUse = "CLICK " .. realFrame .. ":" .. ClickCastMouseButton(key)
      else
        local frame = ClickCastFramesByKey[key]
        local macroText = BuildClickCastMacroText(value)
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
  if InCombatLockdown() then return end
  UpdateToggleFocusTargetMacroText()
  local key = GetBindingKey("Combat Mode - Toggle Focus Target")
  if key then
    ClearOverrideBindings(ToggleFocusTargetOverrideOwner)
    SetOverrideBindingClick(ToggleFocusTargetOverrideOwner, false, key, ToggleFocusTargetButton:GetName(), "LeftButton")
    CM.DebugPrint("Toggle Focus Target binding applied to " .. tostring(key))
  end
end

-- Handler for toggle focus target keybinding (fallback - should be overridden)
function _G.CombatMode_ToggleFocusTarget()
  -- Nothing inside here will work as it will be overriden by ApplyToggleFocusTargetBinding calling UpdateToggleFocusTargetMacroText
end
