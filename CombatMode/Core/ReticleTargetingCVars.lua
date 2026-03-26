---------------------------------------------------------------------------------------
--  Core/ReticleTargetingCVars.lua — RETICLE TARGETING — action-targeting CVar presets
---------------------------------------------------------------------------------------
--  Owns the action-targeting/soft-targeting CVar preset application used by reticle
--  targeting and the Interaction HUD fallback preset.
--
--  Notes:
--    • The crosshair UI and reaction logic live in Core/Crosshair.lua.
--    • Core applies these via Core/Runtime.lua and UI toggles.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local SetCVar = _G.C_CVar.SetCVar

-- Lua stdlib
local pairs = _G.pairs

function CM.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ReticleTargetingCVarValues,
    BlizzValues = CM.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting",
  }

  CM.ApplyCVarConfig(info)
end

function CM.HandleSoftTargetFriend(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

--- SoftTarget subset for Interaction HUD when Reticle Targeting is disabled (full preset is ConfigReticleTargeting).
function CM.ConfigInteractionHUDSoftTarget()
  local t = CM.Constants and CM.Constants.InteractionHUDSoftTargetCVarValues
  if not t then
    return
  end
  for name, value in pairs(t) do
    SetCVar(name, value)
  end
  CM.DebugPrint("Interaction HUD SoftTarget CVars applied")
end
