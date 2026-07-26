---------------------------------------------------------------------------------------
--  Core/Runtime/Bootstrap.lua — RUNTIME — startup/bootstrap helpers
---------------------------------------------------------------------------------------
--  Owns module bootstrap helpers invoked by Runtime: bind-name preparation, binding
--  safety setup, target macro initialization, and feature startup sequencing
--  (CM.BootstrapFeatureModules) in the same order as Runtime enable.
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
  RenameBindableActions()
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
  UnbindMoveAndSteer()
  CM.InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CM.CreateCrosshair()
  CM.InitializeCursorPulse()
  CreateTargetMacros()
  CM.ApplyToggleFocusTargetBinding()
  if CM.HealingRadial and CM.HealingRadial.Initialize then
    CM.HealingRadial.Initialize()
  end
end
