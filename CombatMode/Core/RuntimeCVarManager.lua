---------------------------------------------------------------------------------------
--  Core/RuntimeCVarManager.lua — runtime CVar apply/reset helpers
---------------------------------------------------------------------------------------
--  Owns generic CVar loading and runtime camera/sticky-crosshair helpers used by
--  Runtime rematch and config options. Reticle targeting: CM.GetReticleTargetingCVarOverrides
--  (prune excluded keys), CM.GetEffectiveReticleTargetingCVarValues (presets +
--  CM.DB.global.reticleTargetingCVarOverrides).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local SetCVar = _G.C_CVar.SetCVar
local UIParent = _G.UIParent

-- Lua stdlib
local math = _G.math
local pairs = _G.pairs
local type = _G.type
local tostring = _G.tostring

function CM.GetReticleTargetingCVarOverrides()
  local globalDB = CM.DB and CM.DB.global
  if not globalDB then
    return {}
  end
  if type(globalDB.reticleTargetingCVarOverrides) ~= "table" then
    globalDB.reticleTargetingCVarOverrides = {}
  end
  local t = globalDB.reticleTargetingCVarOverrides
  local excluded = CM.Constants.ReticleTargetingCVarEditorExcluded
  if type(excluded) == "table" then
    for cvar in pairs(excluded) do
      if t[cvar] ~= nil then
        t[cvar] = nil
      end
    end
  end
  return t
end

function CM.GetEffectiveReticleTargetingCVarValues()
  local resolved = {}
  local defaults = CM.Constants.ReticleTargetingCVarValues
  local overrides = CM.GetReticleTargetingCVarOverrides()

  for cvar, value in pairs(defaults) do
    local override = overrides[cvar]
    if override ~= nil then
      resolved[cvar] = override
    else
      resolved[cvar] = value
    end
  end

  return resolved
end

function CM.SetCVar(name, value)
  SetCVar(name, value)
end

function CM.SetCVars(tbl)
  if type(tbl) ~= "table" then
    return
  end
  for name, value in pairs(tbl) do
    CM.SetCVar(name, value)
  end
end

function CM.SetCursorFreelookCenteringCVar(enabled)
  CM.SetCVar("CursorFreelookCentering", enabled and 1 or 0)
end

function CM.SetCursorCenteredYPos(normalized)
  if type(normalized) ~= "number" then
    return
  end
  normalized = math.max(0.01, math.min(0.99, normalized))
  CM.SetCVar("CursorCenteredYPos", normalized)
end

function CM.ApplyCVarConfig(info)
  local CVarType, CMValues, BlizzValues, FeatureName =
    info.CVarType, info.CMValues, info.BlizzValues, info.FeatureName
  local CVarsToLoad

  if CVarType == "combatmode" then
    CVarsToLoad = CMValues
    CM.DebugPrint(FeatureName .. " CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = BlizzValues
    CM.DebugPrint(FeatureName .. " CVars RESET")
  else
    CM.DebugPrint(
      "Invalid CVarType in CM.ApplyCVarConfig for " .. FeatureName .. ": " .. tostring(CVarType)
    )
    return
  end

  CM.SetCVars(CVarsToLoad)
end

function CM.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CM.GetEffectiveReticleTargetingCVarValues(),
    BlizzValues = CM.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting",
  }

  CM.ApplyCVarConfig(info)
end

function CM.HandleSoftTargetFriend(enabled)
  if enabled then
    CM.SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    CM.SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

--- SoftTarget subset for Interaction HUD when Reticle Targeting is disabled (full preset is ConfigReticleTargeting).
function CM.ConfigInteractionHUDSoftTarget()
  local t = CM.Constants and CM.Constants.InteractionHUDSoftTargetCVarValues
  if not t then
    return
  end
  CM.SetCVars(t)
  CM.DebugPrint("Interaction HUD SoftTarget CVars applied")
end

function CM.ConfigActionCamera(CVarType)
  if CM.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ActionCameraCVarValues,
    BlizzValues = CM.Constants.BlizzardActionCameraCVarValues,
    FeatureName = "Action Camera",
  }

  CM.ApplyCVarConfig(info)
  if CVarType == "combatmode" then
    CM.SetShoulderOffset()
  end
  -- Disable the Action Cam warning message.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

function CM.ConfigStickyCrosshair(CVarType)
  if CM.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.TargetFocusCVarValues,
    BlizzValues = CM.Constants.BlizzardTargetFocusCVarValues,
    FeatureName = "Sticky Crosshair",
  }

  CM.ApplyCVarConfig(info)
end

function CM.SetMouseLookSpeed()
  if CM.DynamicCam then
    return
  end

  local XSpeed = CM.DB.global.mouseLookSpeed
  local YSpeed = CM.DB.global.mouseLookSpeed / 2 -- Blizz wants pitch speed as 1/2 of yaw speed
  CM.SetCVar("cameraYawMoveSpeed", XSpeed)
  CM.SetCVar("cameraPitchMoveSpeed", YSpeed)
  CM.DebugPrint("Setting Camera Turn Speed X to " .. XSpeed .. " and Y to " .. YSpeed)
end

function CM.SetShoulderOffset()
  if CM.DynamicCam then
    return
  end

  local offset = CM.DB.char.shoulderOffset
  CM.SetCVar("test_cameraOverShoulder", offset)
  CM.DebugPrint("Setting Shoulder Offset to " .. offset)
end

function CM:ResetCVarsToDefault()
  self.ConfigReticleTargeting("blizzard")
  self.ConfigActionCamera("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.HandleSoftTargetFriend(false)

  print(CM.Constants.BasePrintMsg .. "|cff909090: all changes have been reverted.|r")
end
