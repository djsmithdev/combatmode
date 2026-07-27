---------------------------------------------------------------------------------------
--  Core/Runtime/Bootstrap.lua — RUNTIME — startup/bootstrap helpers
---------------------------------------------------------------------------------------
--  Owns module bootstrap helpers invoked by Runtime: bind-name preparation, binding
--  safety setup, target macro initialization, and feature startup sequencing
--  (CM.BootstrapFeatureModules) in the same order as Runtime enable.
--  UnbindMoveAndSteer reassigns MOVEANDSTEER's key to Mouse Look on enable.
--  CM.RestorePriorBindings (Uninstall) only resets BUTTON1/BUTTON2 to Blizzard camera
--  defaults — it does not clear Combat Mode keybind names.
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateMacro = _G.CreateMacro
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

-- Lua stdlib
local pairs = _G.pairs

local function CreateTargetMacros()
  local function createMacroIfNotExists(macroName, icon, macroText)
    if not CM.MacroExists(macroName) then
      CreateMacro(macroName, icon, macroText, false)
    end
  end

  local macroIcon = "ability_hisek_aim"

  for macroName, macroText in pairs(CM.Constants.Macros) do
    createMacroIfNotExists(macroName, macroIcon, macroText)
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
--- Does not clear Combat Mode keybind names (Mouse Look, Party Radial, etc.).
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
  CreateTargetMacros()
  CM.ApplyToggleFocusTargetBinding()
  if CM.PartyRadial and CM.PartyRadial.Initialize then
    CM.PartyRadial.Initialize()
  end
end
