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
--    • SetShoulderOffset — tweens test_cameraOverShoulder with Vignette duration.
--      Intent (slider / DC snapshot) is separate from the live blend. Optional
--      global.shoulderFollowsMouseLook (default off): when on, ease with Mouse Look
--      chrome; when off, keep configured offset always. DynamicCam + follow: drive only
--      unlock→0 / restore; otherwise relinquish.
--      Mid-tween toggles retarget; never treat a mid-blend CVar sample as intent.
--    • SyncTargetFocusFromFocusUnit — Autofocus Locked Target (kept with DynamicCam;
--      forces MS ActionCam gates off while focus+option active so Target Focus works).
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
local CreateFrame = _G.CreateFrame
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
local min = math.min
local next = _G.next
local pairs = _G.pairs
local tonumber = _G.tonumber
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

-- ---------------------------------------------------------------------------
-- Shoulder offset (test_cameraOverShoulder)
-- Intent vs display: desired target is configured slider or a DynamicCam snapshot;
-- shoulderCurrent is the tween output. Duration matches Vignette.
--
-- global.shoulderFollowsMouseLook (default false): when on, shoulder tracks Mouse Look
-- chrome (configured while locked → 0 on permanent unlock). When off, keep the
-- configured offset at all times (mounted still forces 0).
--
-- DynamicCam + follow on: drive only unlock→0 and zero→restore; nil desired = relinquish.
-- DynamicCam + follow off: never write (full relinquish).
--   mid-tween toggle → retarget from shoulderCurrent (never sample mid-CVar as intent)
-- ---------------------------------------------------------------------------
local SHOULDER_CVAR = "test_cameraOverShoulder"
local SHOULDER_EPS = 0.001

local dcRestore = nil -- pending restore after unlock→0; nil while relinquished
local dcFadingToZero = false

local shoulderFrame
local shoulderCurrent = nil
local fadeActive = false
local fadeFrom = 0
local fadeTo = 0
local fadeElapsed = 0

local function NearlyEqual(a, b)
  return math.abs(a - b) <= SHOULDER_EPS
end

local function IsCameraChromeOn()
  return CM.IsMouseLookCameraChromeActive and CM.IsMouseLookCameraChromeActive()
end

--- Default false: keep configured offset. True = ease with Mouse Look.
local function ShoulderFollowsMouseLook()
  local g = CM.DB and CM.DB.global
  return g and g.shoulderFollowsMouseLook == true
end

local function ShoulderFadeDuration()
  return (CM.Constants and CM.Constants.MouseLookCameraFadeDuration) or 0.35
end

local function ReadShoulderCVar()
  return tonumber(GetCVar(SHOULDER_CVAR)) or 0
end

local function SyncShoulderCurrentFromLive()
  if shoulderCurrent == nil or not fadeActive then
    shoulderCurrent = ReadShoulderCVar()
  end
end

local function RelinquishShoulderToLive()
  fadeActive = false
  shoulderCurrent = ReadShoulderCVar()
end

local function ConfiguredShoulderOffset()
  if IsMounted and IsMounted() then
    return 0
  end
  local offset = CM.DB and CM.DB.char and CM.DB.char.shoulderOffset
  if type(offset) ~= "number" then
    return 1.2
  end
  return offset
end

--- Desired shoulder, or nil to stop writing (DynamicCam owns the CVar).
local function DesiredShoulderOffset()
  if not ShoulderFollowsMouseLook() then
    if CM.DynamicCam then
      return nil
    end
    return ConfiguredShoulderOffset()
  end
  if not IsCameraChromeOn() then
    if CM.DynamicCam then
      return dcFadingToZero and 0 or nil
    end
    return 0
  end
  if CM.DynamicCam then
    return dcRestore
  end
  return ConfiguredShoulderOffset()
end

local function StartShoulderFade(from, to)
  shoulderCurrent = from
  fadeTo = to
  if NearlyEqual(from, to) then
    fadeActive = false
    CM.SetCVar(SHOULDER_CVAR, to)
  else
    fadeFrom = from
    fadeElapsed = 0
    fadeActive = true
  end
  -- Retargeting away from unlock→0 must clear the latch so live-DC adopt can run later.
  if CM.DynamicCam and dcFadingToZero and not NearlyEqual(to, 0) then
    dcFadingToZero = false
  end
end

--- Keep / start a fade toward desired; settle DynamicCam latches when already there.
local function EnsureShoulderAtDesired(desired)
  if desired == nil then
    RelinquishShoulderToLive()
    return
  end
  if not fadeActive then
    if not NearlyEqual(shoulderCurrent, desired) then
      StartShoulderFade(shoulderCurrent, desired)
    elseif CM.DynamicCam and dcFadingToZero and NearlyEqual(desired, 0) then
      dcFadingToZero = false
    elseif CM.DynamicCam and dcRestore ~= nil and NearlyEqual(desired, dcRestore) then
      dcRestore = nil
    end
  elseif not NearlyEqual(fadeTo, desired) then
    StartShoulderFade(shoulderCurrent, desired)
  end
end

--- Unlock snapshot: fade goal / prior restore / fade origin — never a mid-tween sample.
local function IntendedShoulderForUnlockSnapshot()
  if fadeActive then
    if not NearlyEqual(fadeTo, 0) then
      return fadeTo
    end
    if dcRestore ~= nil then
      return dcRestore
    end
    if not NearlyEqual(fadeFrom, 0) then
      return fadeFrom
    end
  end
  return ReadShoulderCVar()
end

--- Called from FreeLook while chrome is still active, before it clears.
function CM.SnapshotShoulderBeforeChromeClear()
  if not CM.DynamicCam or not ShoulderFollowsMouseLook() then
    return
  end
  dcRestore = IntendedShoulderForUnlockSnapshot()
  dcFadingToZero = true
  SyncShoulderCurrentFromLive()
  CM.DebugPrint("Shoulder snapshot intent: " .. tostring(dcRestore))
end

--- Settled chrome-on: if DC already wrote a non-zero shoulder, drop snapshot and relinquish.
local function TryAdoptLiveDynamicCamShoulder()
  if not CM.DynamicCam or not ShoulderFollowsMouseLook() or not IsCameraChromeOn() then
    return false
  end
  if fadeActive or dcFadingToZero then
    return false
  end
  local live = ReadShoulderCVar()
  if NearlyEqual(live, 0) then
    return false
  end
  dcRestore = nil
  RelinquishShoulderToLive()
  return true
end

local function OnShoulderFadeCompleted(desired)
  if not CM.DynamicCam then
    return
  end
  if dcFadingToZero and NearlyEqual(desired, 0) then
    dcFadingToZero = false
  end
  if dcRestore ~= nil and NearlyEqual(fadeTo, dcRestore) then
    dcRestore = nil
  end
end

local function ShoulderOnUpdate(_, elapsed)
  if shoulderCurrent == nil then
    shoulderCurrent = ReadShoulderCVar()
  end
  local desired = DesiredShoulderOffset()
  if desired == nil then
    RelinquishShoulderToLive()
    return
  end
  EnsureShoulderAtDesired(desired)
  if not fadeActive then
    return
  end
  fadeElapsed = fadeElapsed + (elapsed or 0)
  local t = min(1, fadeElapsed / ShoulderFadeDuration())
  shoulderCurrent = fadeFrom + (fadeTo - fadeFrom) * t
  CM.SetCVar(SHOULDER_CVAR, shoulderCurrent)
  if t >= 1 then
    fadeActive = false
    shoulderCurrent = fadeTo
    OnShoulderFadeCompleted(desired)
  end
end

local function EnsureShoulderOffsetDriver()
  if not shoulderFrame then
    shoulderFrame = CreateFrame("Frame", "CombatModeShoulderOffsetFrame")
  end
  if shoulderCurrent == nil then
    shoulderCurrent = ReadShoulderCVar()
  end
  shoulderFrame:SetScript("OnUpdate", ShoulderOnUpdate)
end

--- Apply / retarget shoulder (tweens over vignette fade duration).
function CM.SetShoulderOffset()
  EnsureShoulderOffsetDriver()
  SyncShoulderCurrentFromLive()
  -- Drop unlock/restore latches when not following Mouse Look (option toggled off).
  if not ShoulderFollowsMouseLook() then
    dcFadingToZero = false
    dcRestore = nil
  end
  if TryAdoptLiveDynamicCamShoulder() then
    CM.DebugPrint("Shoulder Offset relinquished to DynamicCam (live)")
    return
  end
  local desired = DesiredShoulderOffset()
  EnsureShoulderAtDesired(desired)
  if desired == nil then
    CM.DebugPrint("Shoulder Offset relinquished to DynamicCam")
  else
    CM.DebugPrint("Shoulder Offset target " .. tostring(desired))
  end
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

--- Apply Mouse Look camera chrome while freelook is locked (MS off when we own it, shoulder).
function CM.ApplyMouseLookCamera()
  if not CM.DynamicCam then
    CM.ApplyActionCamMotionSicknessGate()
  end
  CM.SetShoulderOffset()
  CM.DebugPrint("Mouse Look camera applied")
end

--- Clear Mouse Look camera chrome while freelook is unlocked (tween shoulder to 0; MS gate).
function CM.ClearMouseLookCamera()
  CM.SetShoulderOffset()
  if not CM.DynamicCam then
    CM.ApplyActionCamMotionSicknessGate()
  end
  CM.DebugPrint("Mouse Look camera cleared")
end

--- Enable enemy Target Focus when autofocusLockedTarget is on and UnitExists("focus").
--- Kept even with DynamicCam: Target Lock autofocus is a Combat Mode feature, not a
--- camera-preset handoff. When active, force motion-sickness ActionCam gates off —
--- Target Focus is a no-op while those CVars are 1. When inactive with DC, leave MS alone.
function CM.SyncTargetFocusFromFocusUnit()
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
  if want then
    CM.SetCVar("CameraKeepCharacterCentered", 0)
    CM.SetCVar("CameraReduceUnexpectedMovement", 0)
  elseif not CM.DynamicCam then
    CM.ApplyActionCamMotionSicknessGate()
  end
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
