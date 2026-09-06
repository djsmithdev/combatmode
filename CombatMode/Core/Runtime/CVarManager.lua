---------------------------------------------------------------------------------------
--  Core/Runtime/CVarManager.lua — RUNTIME — all addon SetCVar writes
---------------------------------------------------------------------------------------
--  What it does: Single owner of Combat Mode CVar writes. Captures/restores
--  priorCVarSnapshot, merges reticleTargetingCVarOverrides into effective reticle
--  values, applies Mouse Look camera prefs (shoulder + MS on lock/unlock; sticky
--  dynamic pitch via SetDynamicPitch), Target Focus sync, mouselook turn speed,
--  Interaction HUD SoftTarget subset, and CursorFreelookCentering / CursorCenteredYPos
--  helpers for FreeLook + Crosshair.
--  Architecture / how it works:
--    • Always calls live `_G.C_CVar.SetCVar` so Reticle CVar editor attribution hooks see CM.
--    • CapturePriorCVarSnapshot / EnsurePriorCVarSnapshot once per install over ManagedCVarNames;
--      RestorePriorCVars used by Uninstall; restoringCVars suppresses re-snapshot.
--      N.B. a populated priorCVarSnapshot in the DB is never overwritten (prevents
--      contaminating the snapshot with CM's own CVar values on subsequent logins).
--    • GetEffectiveReticleTargetingCVarValues = preset ∪ global.reticleTargetingCVarOverrides.
--    • ApplyMouseLookCamera / ClearMouseLookCamera — lock vs unlock (shoulder; MS via gate).
--    • SetDynamicPitch — sticky with the option; ApplyActionCamMotionSicknessGate keeps
--      CameraKeepCharacterCentered / CameraReduceUnexpectedMovement at 0 while pitch (or
--      freelook / autofocus) needs ActionCam, otherwise Blizzard suppresses pitch.
--    • SetShoulderOffset / SyncTargetFocusFromFocusUnit / SetMouseLookSpeed.
--      SetShoulderOffset forces 0 while IsMounted(); EventRouter refreshes on mount change.
--    • ConfigStickyCrosshair: Blizzard-reset helper for Uninstall only.
--    • SetCursorFreelookCenteringCVar + SetCursorCenteredYPos — FreeLook bounce + Y sync.
--  Does not: Own SoftTarget UI widgets or freelook state machine.
--  Related: Constants/CVars.lua, Constants/DatabaseDefaults.lua,
--  Core/FreeLook/FreeLookController.lua, Core/Crosshair/Crosshair.lua,
--  Core/Crosshair/InteractionHUD/HUD.lua, UI/Editors/ReticleCVarEditorData.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/Tabs/TabGeneral.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetCVar = _G.C_CVar.GetCVar
local GetCVarDefault = _G.C_CVar.GetCVarDefault
local IsMounted = _G.IsMounted
local UnitExists = _G.UnitExists

-- Always resolve through the live C_CVar.SetCVar so hooksecurefunc consumers
-- (e.g. Reticle CVar editor attribution) see Combat Mode writes. A load-time
-- local would bypass those hooks.
local function SetCVar(name, value)
  return _G.C_CVar.SetCVar(name, value)
end

-- Lua stdlib
local ipairs = _G.ipairs
local math = _G.math
local next = _G.next
local pairs = _G.pairs
local type = _G.type
local tostring = _G.tostring

-- Suppress snapshot capture while restoring (avoid treating restored values as "prior").
local restoringCVars = false
-- True after CapturePriorCVarSnapshot this login; Ensure becomes a no-op so Rematch
-- / later SetCVar cannot overwrite the pre-apply snapshot with CM values.
local sessionSnapshotCaptured = false

local function SnapshotIsPopulated(snap)
  return type(snap) == "table" and next(snap) ~= nil
end

local function CountKeys(t)
  local n = 0
  if type(t) ~= "table" then
    return 0
  end
  for _ in pairs(t) do
    n = n + 1
  end
  return n
end

--- Force-capture current managed CVar values. Call once at enable/bootstrap *before*
--- any Combat Mode writes so Uninstall restores what the player had this session.
function CM.CapturePriorCVarSnapshot()
  if restoringCVars then
    return
  end
  local globalDB = CM.DB and CM.DB.global
  if not globalDB then
    return
  end
  -- Once a populated snapshot exists, never overwrite it. On subsequent logins CM's own
  -- CVar values are already live, so re-capturing would contaminate the snapshot with
  -- CM values and break Uninstall (the reported SoftTargetIconInteract / GameObject bug).
  if SnapshotIsPopulated(globalDB.priorCVarSnapshot) then
    return
  end

  local snap = {}
  local names = CM.Constants.ManagedCVarNames
  if type(names) == "table" then
    for _, name in ipairs(names) do
      local value = GetCVar(name)
      if value ~= nil then
        snap[name] = value
      end
    end
  end
  globalDB.priorCVarSnapshot = snap
  sessionSnapshotCaptured = true
  CM.DebugPrint("Captured prior CVar snapshot (" .. CountKeys(snap) .. " keys).")
end

--- Safety net for SetCVar paths that run before CapturePriorCVarSnapshot.
--- No-op once this session's pre-apply snapshot exists (do not refresh mid-session).
function CM.EnsurePriorCVarSnapshot()
  if restoringCVars or sessionSnapshotCaptured then
    return
  end
  CM.CapturePriorCVarSnapshot()
end

--- Restore CVars from the pre-CM snapshot. Falls back to hard-coded Blizzard tables
--- when no snapshot exists.
function CM.RestorePriorCVars()
  local globalDB = CM.DB and CM.DB.global
  local snap = globalDB and globalDB.priorCVarSnapshot
  restoringCVars = true

  if SnapshotIsPopulated(snap) then
    for name, value in pairs(snap) do
      SetCVar(name, value)
    end
    -- Freelook centering must never linger after uninstall; force off even if missing.
    SetCVar("CursorFreelookCentering", snap.CursorFreelookCentering or 0)
    CM.DebugPrint("Restored prior CVar snapshot (" .. CountKeys(snap) .. " keys).")
    -- SoftTarget icon CVars are always forced to Blizzard defaults (0) on uninstall.
    -- These are set exclusively by CM; existing snapshots may be contaminated with CM's own
    -- values from a previous login, leaving icons on after uninstall (reported bug).
    -- Always reset to 0 regardless of snapshot contents.
    SetCVar("SoftTargetIconInteract", 0)
    SetCVar("SoftTargetIconGameObject", 0)
  else
    CM.DebugPrint("No prior CVar snapshot — falling back to Blizzard preset tables.")
    CM.ConfigReticleTargeting("blizzard")
    CM.SetCVars(CM.Constants.BlizzardMouseLookCameraCVarValues)
    CM.ConfigStickyCrosshair("blizzard")
    CM.HandleSoftTargetFriend(false)
    SetCVar("CursorFreelookCentering", 0)
    local yawDefault = GetCVarDefault and GetCVarDefault("cameraYawMoveSpeed")
    local pitchDefault = GetCVarDefault and GetCVarDefault("cameraPitchMoveSpeed")
    if yawDefault then
      SetCVar("cameraYawMoveSpeed", yawDefault)
    end
    if pitchDefault then
      SetCVar("cameraPitchMoveSpeed", pitchDefault)
    end
  end

  restoringCVars = false
end

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
  CM.EnsurePriorCVarSnapshot()
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

--- One-shot migration from Action Camera situation profiles / legacy flat keys
--- into flat Mouse Look camera prefs (char.shoulderOffset, global.dynamicPitch).
function CM.MigrateMouseLookCameraDB()
  local g = CM.DB and CM.DB.global
  local c = CM.DB and CM.DB.char
  if not g or not c then
    return
  end

  if type(c.shoulderOffset) ~= "number" then
    local shoulder = 1.2
    local profiles = g.actionCameraProfiles
    if type(profiles) == "table" and type(profiles.base) == "table" then
      if type(profiles.base.shoulder) == "number" then
        shoulder = profiles.base.shoulder
      end
    end
    c.shoulderOffset = shoulder
  end

  if g.dynamicPitch == nil then
    if g.actionCameraDynamicPitch ~= nil then
      g.dynamicPitch = g.actionCameraDynamicPitch ~= false
    else
      g.dynamicPitch = true
    end
  end

  -- Stop reading obsolete Action Camera keys (leave them nil so they do not linger).
  g.actionCamera = nil
  g.actionCamMouselookDisable = nil
  g.actionCameraProfiles = nil
  g.actionCameraMaxZoom = nil
  g.actionCameraDynamicPitch = nil
  g.actionCameraFov = nil
  g.actionCameraZoomSpeed = nil
  g.actionCameraHeadTracking = nil
end

--- Apply configured shoulder while freelook can use it; force 0 while mounted
--- (matches old Mounted Action Camera profile — offset looks wrong on mounts).
function CM.SetShoulderOffset()
  if CM.DynamicCam then
    return
  end
  local offset = 0
  if not (IsMounted and IsMounted()) then
    offset = CM.DB and CM.DB.char and CM.DB.char.shoulderOffset
    if type(offset) ~= "number" then
      offset = 1.2
    end
  end
  CM.SetCVar("test_cameraOverShoulder", offset)
  CM.DebugPrint("Setting Shoulder Offset to " .. tostring(offset))
end

local function ApplyDynamicPitchPads()
  local CONSTS = CM.Constants
  CM.SetCVar("test_cameraDynamicPitchBaseFovPad", CONSTS.MouseLookCameraPitchBase or 0.4)
  CM.SetCVar("test_cameraDynamicPitchBaseFovPadFlying", CONSTS.MouseLookCameraPitchFlying or 0.75)
  CM.SetCVar(
    "test_cameraDynamicPitchBaseFovPadDownScale",
    CONSTS.MouseLookCameraPitchDownScale or 0.25
  )
  CM.SetCVar(
    "test_cameraDynamicPitchSmartPivotCutoffDist",
    CONSTS.MouseLookCameraPitchSmartPivotCutoff or 39
  )
end

--- ActionCam features (dynamic pitch, shoulder, target focus) are no-ops while
--- CameraKeepCharacterCentered / CameraReduceUnexpectedMovement are 1.
local function NeedActionCamMotionSicknessOff()
  if CM.IsMouselooking and CM.IsMouselooking() then
    return true
  end
  local g = CM.DB and CM.DB.global
  if g and g.dynamicPitch ~= false then
    return true
  end
  if g and g.autofocusLockedTarget ~= false and UnitExists and UnitExists("focus") == true then
    return true
  end
  return false
end

function CM.ApplyActionCamMotionSicknessGate()
  if CM.DynamicCam then
    return
  end
  local off = NeedActionCamMotionSicknessOff()
  local v = off and 0 or 1
  CM.SetCVar("CameraKeepCharacterCentered", v)
  CM.SetCVar("CameraReduceUnexpectedMovement", v)
end

--- Sticky Dynamic Pitch (option-gated, not freelook). Pads + master CVar + MS gate
--- so unlock / option toggles actually take effect.
function CM.SetDynamicPitch()
  if CM.DynamicCam then
    return
  end
  local wantPitch = CM.DB and CM.DB.global and CM.DB.global.dynamicPitch ~= false
  if wantPitch then
    ApplyDynamicPitchPads()
  end
  CM.SetCVar("test_cameraDynamicPitch", wantPitch and 1 or 0)
  CM.ApplyActionCamMotionSicknessGate()
  CM.DebugPrint("Dynamic Pitch " .. (wantPitch and "on" or "off"))
end

--- Apply Mouse Look camera chrome while freelook is locked (MS off, shoulder).
function CM.ApplyMouseLookCamera()
  if CM.DynamicCam then
    return
  end
  CM.ApplyActionCamMotionSicknessGate()
  CM.SetShoulderOffset()
  CM.DebugPrint("Mouse Look camera applied")
end

--- Clear Mouse Look camera chrome while freelook is unlocked (shoulder 0; MS follows gate).
function CM.ClearMouseLookCamera()
  if CM.DynamicCam then
    return
  end
  CM.SetCVars(CM.Constants.MouseLookCameraUnlockedValues)
  CM.ApplyActionCamMotionSicknessGate()
  CM.DebugPrint("Mouse Look camera cleared")
end

--- Enable enemy Target Focus when autofocusLockedTarget is on and UnitExists("focus").
function CM.SyncTargetFocusFromFocusUnit()
  if CM.DynamicCam then
    return
  end
  local g = CM.DB and CM.DB.global
  local optOn = g and g.autofocusLockedTarget ~= false
  local want = optOn and UnitExists and UnitExists("focus") == true
  local strengths = CM.Constants.TargetFocusCVarValues
  if strengths then
    CM.SetCVar(
      "test_cameraTargetFocusEnemyStrengthYaw",
      strengths["test_cameraTargetFocusEnemyStrengthYaw"] or 0.7
    )
    CM.SetCVar(
      "test_cameraTargetFocusEnemyStrengthPitch",
      strengths["test_cameraTargetFocusEnemyStrengthPitch"] or 0.2
    )
  end
  CM.SetCVar("test_cameraTargetFocusEnemyEnable", want and 1 or 0)
  CM.ApplyActionCamMotionSicknessGate()
end

--- Blizzard-reset helper for Uninstall only.
function CM.ConfigStickyCrosshair(CVarType)
  if CM.DynamicCam then
    return
  end
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.TargetFocusCVarValues,
    BlizzValues = CM.Constants.BlizzardTargetFocusCVarValues,
    FeatureName = "Sticky Crosshair (uninstall reset)",
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

--- Restore the player's pre-Combat Mode CVars (snapshot preferred; Blizzard tables fallback).
--- Prefer CM.UninstallCombatMode for a full leave; this is the CVar half only.
function CM:ResetCVarsToDefault()
  CM.RestorePriorCVars()
  print(CM.Constants.BasePrintMsg .. "|cff909090: camera and targeting CVars restored.|r")
end
