---------------------------------------------------------------------------------------
--  Core/Runtime/Bootstrap.lua — RUNTIME — enable sequencing
---------------------------------------------------------------------------------------
--  What it does: Ordered startup for feature modules after DB is ready: CVar snapshot,
--  apply overrides, wildcard frame tracking, crosshair + cursor pulse, legacy macro cleanup,
--  MOVEANDSTEER → Mouse Look rebind, toggle-focus bind, focus-cycle wheel refresh,
--  Ally Cycle init. Also RestorePriorBindings for uninstall (BUTTON1/BUTTON2 camera
--  defaults only).
--  Architecture / how it works:
--    • BootstrapFeatureModules() is the enable-time sequence Runtime calls.
--    • RemoveLegacyMacros — Combat Mode no longer creates CM_ macros (the click-cast actions
--      run Constants.Macros text from proxy buttons); older versions did, so delete leftovers that
--      still hold our original text and are not on an action bar.
--    • UnbindMoveAndSteer via TryApplyBindingChange + SaveBindings.
--  Does not: Own ongoing freelook OnUpdate or EventRouter dispatch.
--  Related: Core/Runtime/Runtime.lua, Core/Runtime/CVarManager.lua,
--  Core/ClickCasting/BindingOverrides.lua, Core/Crosshair/Crosshair.lua,
--  Core/FreeLook/AutoCursorUnlock.lua, Core/AllyCycle/AllyCycle.lua,
--  Constants/Gameplay.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local DeleteMacro = _G.DeleteMacro
local GetActionInfo = _G.GetActionInfo
local GetMacroBody = _G.GetMacroBody
local GetMacroIndexByName = _G.GetMacroIndexByName
local InCombatLockdown = _G.InCombatLockdown
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local UIParent = _G.UIParent

-- Lua stdlib
local pairs = _G.pairs
local strtrim = _G.strtrim

-- Suppress the experimental CVar confirmation popup so Mouse Look camera CVars
-- (shoulder, dynamic pitch) don't trigger a dialog on every login/reload.
-- WoW 12.1 moved this event out of UIParent into Blizzard_Game's internal
-- event router. Use GameEvent.UnregisterInternalEvent when available.
if _G.GameEvent and _G.GameEvent.UnregisterInternalEvent then
  _G.GameEvent.UnregisterInternalEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
else
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

local MAX_ACTION_SLOT = 180

local function NormalizeMacroText(text)
  text = (text or ""):gsub("\r", "")
  return strtrim(text)
end

local function IsMacroOnActionBar(macroIndex)
  for slot = 1, MAX_ACTION_SLOT do
    local actionType, id = GetActionInfo(slot)
    if actionType == "macro" and id == macroIndex then
      return true
    end
  end
  return false
end

--- Older versions created account macros named like CM.Constants.Macros. Delete the ones still
--- holding our original text (an edited macro is the player's) and not placed on an action bar.
local function RemoveLegacyMacros()
  if InCombatLockdown() then
    return
  end
  for macroName, macroText in pairs(CM.Constants.Macros) do
    local index = GetMacroIndexByName(macroName)
    if
      index
      and index > 0
      and NormalizeMacroText(GetMacroBody(index)) == NormalizeMacroText(macroText)
      and not IsMacroOnActionBar(index)
    then
      DeleteMacro(index)
      CM.DebugPrint("Removed legacy macro " .. macroName)
    end
  end
end

local function UnbindMoveAndSteer()
  CM.TryApplyBindingChange("MOVEANDSTEER unbind", function()
    local key = GetBindingKey("MOVEANDSTEER")
    if key then
      SetBinding(key, "Combat Mode - Mouse Look")
    end
    SaveBindings(GetCurrentBindingSet())
  end)
end

--- Reset left/right click to Blizzard camera defaults (click-drag camera / turn).
--- Does not clear Combat Mode keybind names (Mouse Look, Ally Cycle, etc.).
function CM.RestorePriorBindings()
  CM.TryApplyBindingChange("restore default mouse camera bindings", function()
    SetBinding("BUTTON1", "CAMERAORSELECTORMOVE")
    SetBinding("BUTTON2", "TURNORACTION")
    SaveBindings(GetCurrentBindingSet())
    CM.DebugPrint("Restored BUTTON1/BUTTON2 to default camera bindings.")
  end)
end

local function RenameBindableActions()
  for _, bindingAction in pairs(CM.Constants.ActionsToProcess) do
    local bindingUiName = _G["BINDING_NAME_" .. bindingAction]
    CM.Constants.OverrideActions[bindingAction] = bindingUiName or bindingAction
  end
end

--[[
Do more initialization here, that really enables the use of your addon.
Register Events, Hook functions, Create Frames, Get information from
the game that wasn't available in OnInitialize
]]
--
function CM.BootstrapFeatureModules()
  -- Capture pre-CM CVars before any feature module can write (e.g. crosshair Y centering).
  -- Always refresh for this enable session so Uninstall restores values from *now*,
  -- not a stale snapshot from an earlier install.
  if CM.CapturePriorCVarSnapshot then
    CM.CapturePriorCVarSnapshot()
  end
  RenameBindableActions()
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
  UnbindMoveAndSteer()
  CM.InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CM.CreateCrosshair()
  CM.InitializeCursorPulse()
  CM.InitializeVignette()
  RemoveLegacyMacros()
  -- Settings that change the preline reload the UI, so bring composed macros up to date here.
  if CM.RebuildComposedMacros then
    CM.RebuildComposedMacros()
  end
  CM.ApplyToggleFocusTargetBinding()
  CM.ApplyCycleFocusBindings()
  if CM.InitializeAllyCycle then
    CM.InitializeAllyCycle()
  end
  if CM.InitializeRadialMenu then
    CM.InitializeRadialMenu()
  end
end
