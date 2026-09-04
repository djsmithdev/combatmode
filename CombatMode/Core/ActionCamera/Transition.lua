---------------------------------------------------------------------------------------
--  Core/ActionCamera/Transition.lua — ACTION CAMERA — CVar cross-fade engine
---------------------------------------------------------------------------------------
--  What it does: Drives the DynamicCam-like, interrupt-safe eased transition between
--  Action Camera situation profiles. On each OnUpdate tick it interpolates all numeric
--  profile CVars from their live start values toward the target profile, handles the
--  instant-toggle semantics for test_cameraDynamicPitch, and exposes StartTransition /
--  SyncTargetFocusFromFocusUnit for SituationDriver and EventRouter.
--  Architecture / how it works:
--    • CM.ActionCamera.StartTransition(profile, instant[, dur[, skipZoom]]) — begin or
--      interrupt. If a transition is in progress, snapshots the current blended values
--      as new starts. skipZoom=true restores CVars without CameraZoomIn/Out (mouselook Resume).
--    • CM.ActionCamera.OnTransitionUpdate(elapsed) — called by the root frame OnUpdate
--      in SituationDriver (not Embeds.xml OnUpdate) so it stays idle when AC is off.
--    • InOutQuad easing: t in [0,1] → 2t² for t<0.5, else 1-(-2t+2)²/2.
--    • test_cameraDynamicPitch: shared DB toggle; enable on enter, disable after exit ease.
--    • test_cameraTargetFocusEnemyEnable: driven by UnitExists("focus") (Target Lock /
--      cycle / auto-lock), not by situation profiles. SyncTargetFocusFromFocusUnit on
--      PLAYER_FOCUS_CHANGED and after snaps/transitions.
--    • setZoom: if profile.setZoom is set (yards), CameraZoomIn/Out is issued at
--      transition start so the camera glides concurrently with CVar easing.
--    • When instant=true (login, Rematch): snap all values, no OnUpdate loop needed.
--    • CM.SetCVar used for all writes so prior-snapshot + debug flow is honoured.
--  Does not: Own the OnUpdate registration or evaluate situations.
--  Related: Core/ActionCamera/SituationDriver.lua, Constants/ActionCamera.lua,
--  Core/Runtime/CVarManager.lua, Core/Runtime/EventRouter.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetCVar = _G.C_CVar and _G.C_CVar.GetCVar
local GetCameraZoom = _G.GetCameraZoom
local CameraZoomIn = _G.CameraZoomIn
local CameraZoomOut = _G.CameraZoomOut
local UnitExists = _G.UnitExists

-- Lua stdlib
local math = _G.math
local type = _G.type
local tonumber = _G.tonumber

local AC = CM.ActionCamera or {}
CM.ActionCamera = AC

local CONSTS = CM.Constants
local DISTANCE_BASE = CONSTS.ACTION_CAMERA_DISTANCE_BASE_YARDS or 15

-- Active transition state
local active = false
local elapsed_total = 0
local duration = 0
local starts = {} -- [cvar] = start numeric value
local targets = {} -- [cvar] = target numeric value
local targetPitch = false -- target dynamicPitch bool
local targetSetZoom = nil -- target setZoom yards (nil = don't force)
local currentPitch = false

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------

local function InOutQuad(t)
  if t < 0.5 then
    return 2 * t * t
  else
    local u = -2 * t + 2
    return 1 - u * u / 2
  end
end

-- Issue CameraZoomIn/Out to reach the target distance. Relies on cameraZoomSpeed for
-- the travel rate, so the camera glides rather than snapping.
local function ZoomToDistance(targetYards)
  if not targetYards or not GetCameraZoom then
    return
  end
  local current = GetCameraZoom() or 0
  local delta = targetYards - current
  if math.abs(delta) < 0.1 then
    return
  end
  -- Clear any reactive zoom in-flight target so the situation zoom wins cleanly.
  if CM.ReactiveZoom and CM.ReactiveZoom.ResetTarget then
    CM.ReactiveZoom.ResetTarget()
  end
  if delta < 0 then
    CameraZoomIn(-delta)
  else
    CameraZoomOut(delta)
  end
end

local function ReadCVar(name)
  if not GetCVar then
    return 0
  end
  return tonumber(GetCVar(name)) or 0
end

local function WantDynamicPitch()
  local g = CM.DB and CM.DB.global
  return g and g.actionCameraDynamicPitch ~= false
end

--- Enable enemy Target Focus CVar when autofocusLockedTarget is on and UnitExists("focus");
--- off when focus is clear or the option is disabled. Driven by Target Lock / cycle /
--- auto-lock (PLAYER_FOCUS_CHANGED). Skipped when DynamicCam owns camera CVars.
local function SyncTargetFocusFromFocusUnit()
  if CM.DynamicCam then
    return
  end
  local g = CM.DB and CM.DB.global
  local optOn = g and g.autofocusLockedTarget ~= false
  local want = optOn and UnitExists and UnitExists("focus") == true
  CM.SetCVar("test_cameraTargetFocusEnemyEnable", want and 1 or 0)
end

-- Convert profile table fields to the CVar key/value pairs that are numeric.
-- Returns a flat table {cvarName = number}.
local function ProfileToNumericCVars(profile)
  local out = {}
  out["cameraFov"] = profile.fov or 75
  out["test_cameraOverShoulder"] = profile.shoulder or 1.2
  out["test_cameraHeadMovementStrength"] = profile.headTracking or 1
  return out
end

-- Apply the shared (non-per-situation) camera CVars from global DB / hardcoded defaults.
local function ApplySharedCVars()
  local g = CM.DB and CM.DB.global
  if not g then
    return
  end
  local BASE = DISTANCE_BASE
  CM.SetCVar("cameraDistanceMaxZoomFactor", (g.actionCameraMaxZoom or 20) / BASE)
  -- Hardcoded; not exposed in options. Reactive zoom + this speed are always-on with AC.
  CM.SetCVar("cameraZoomSpeed", 20)
  -- Always pull camera toward feet on ground collision (DynamicCam-style max cutoff).
  CM.SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 39)
  -- Pitch pads + enemy target-focus strengths: same for every situation.
  CM.SetCVar("test_cameraDynamicPitchBaseFovPad", CONSTS.ActionCameraPitchBase or 0.4)
  CM.SetCVar("test_cameraDynamicPitchBaseFovPadFlying", CONSTS.ActionCameraPitchFlying or 0.75)
  CM.SetCVar(
    "test_cameraDynamicPitchBaseFovPadDownScale",
    CONSTS.ActionCameraPitchDownScale or 0.25
  )
  CM.SetCVar("test_cameraTargetFocusEnemyStrengthYaw", CONSTS.ActionCameraTargetFocusYaw or 0.7)
  CM.SetCVar("test_cameraTargetFocusEnemyStrengthPitch", CONSTS.ActionCameraTargetFocusPitch or 0.2)
  -- Vertical pitch enable is shared (not per-situation).
  local wantPitch = WantDynamicPitch()
  CM.SetCVar("test_cameraDynamicPitch", wantPitch and 1 or 0)
  currentPitch = wantPitch
end

-- Snap all CVars to profile immediately (no easing). Used on login / instant apply.
-- @param skipZoom boolean|nil  If true, do not issue CameraZoomIn/Out (mouselook resume).
local function SnapToProfile(profile, skipZoom)
  active = false
  elapsed_total = 0

  ApplySharedCVars()
  local nvars = ProfileToNumericCVars(profile)
  for cvar, value in _G.pairs(nvars) do
    CM.SetCVar(cvar, value)
  end

  -- Toggles: snap pitch from shared DB; Target Focus follows focus unit.
  local wantPitch = WantDynamicPitch()
  CM.SetCVar("test_cameraDynamicPitch", wantPitch and 1 or 0)
  currentPitch = wantPitch
  SyncTargetFocusFromFocusUnit()

  if not skipZoom then
    ZoomToDistance(profile.setZoom)
  end
end

-- -----------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------

--- Begin (or interrupt) a transition to the given profile.
--- @param profile table  The target profile from DB.actionCameraProfiles[id].
--- @param instant boolean  If true, snap immediately with no easing.
--- @param dur number|nil  Override duration in seconds (uses DB/constants default if nil).
--- @param skipZoom boolean|nil  If true, restore CVars without forcing setZoom (Pause/Resume).
function AC.StartTransition(profile, instant, dur, skipZoom)
  if not profile then
    return
  end

  if instant then
    SnapToProfile(profile, skipZoom)
    return
  end

  ApplySharedCVars()
  local newTargets = ProfileToNumericCVars(profile)

  -- If mid-transition, snapshot current blended values as new starts (interrupt safety).
  local newStarts = {}
  for cvar in _G.pairs(newTargets) do
    if active and starts[cvar] ~= nil then
      -- Compute current blended value rather than live CVar (avoids rounding noise).
      local blend = InOutQuad(math.min(elapsed_total / duration, 1))
      newStarts[cvar] = (starts[cvar] or 0) + ((targets[cvar] or 0) - (starts[cvar] or 0)) * blend
    else
      newStarts[cvar] = ReadCVar(cvar)
    end
  end

  starts = newStarts
  targets = newTargets
  targetPitch = WantDynamicPitch()
  targetSetZoom = skipZoom and nil or profile.setZoom
  -- Re-read live pitch CVar: Pause + mouselook-disable can zero pitch while
  -- currentPitch is still true in memory, which would skip re-enable below.
  currentPitch = ReadCVar("test_cameraDynamicPitch") ~= 0
  duration = (type(dur) == "number" and dur > 0) and dur
    or CONSTS.ActionCameraTransitionDefault
    or 0.75
  elapsed_total = 0
  active = true

  -- DynamicCam toggle-group: enable pitch *before* easing strengths up.
  if targetPitch and not currentPitch then
    CM.SetCVar("test_cameraDynamicPitch", 1)
    currentPitch = true
  end

  -- Target Focus follows focus unit independently of situation blends.
  SyncTargetFocusFromFocusUnit()

  -- Issue zoom command at transition *start* so the camera glides concurrently with
  -- CVar easing (shoulder, FOV, etc.) rather than sequentially after it.
  ZoomToDistance(targetSetZoom)

  -- If disabling pitch, zeroing is handled in OnTransitionUpdate at blend end.
end

--- Called every frame by SituationDriver while a transition is in progress.
--- @param elapsed number  Frame delta in seconds.
--- @return boolean  true while still transitioning; false when complete.
function AC.OnTransitionUpdate(elapsed)
  if not active then
    return false
  end

  elapsed_total = elapsed_total + elapsed
  local t = math.min(elapsed_total / duration, 1)
  local blend = InOutQuad(t)

  for cvar, target in _G.pairs(targets) do
    local start = starts[cvar] or target
    local value = start + (target - start) * blend
    CM.SetCVar(cvar, value)
  end

  if t >= 1 then
    active = false

    -- Toggle-group: disable pitch *after* strengths have eased to 0.
    if not targetPitch and currentPitch then
      CM.SetCVar("test_cameraDynamicPitch", 0)
      currentPitch = false
    end

    return false
  end

  return true
end

--- Returns true if a transition is currently running.
function AC.IsTransitioning()
  return active
end

--- Force-stop any active transition without applying final values.
function AC.StopTransition()
  active = false
  elapsed_total = 0
end

--- Re-apply shared (non-per-situation) camera CVars from DB. Called by options UI when
--- maxZoom / dynamic pitch change. Zoom speed is hardcoded to 20.
AC.ApplySharedCVars = ApplySharedCVars

--- Sync test_cameraTargetFocusEnemyEnable to UnitExists("focus"). Called from
--- EventRouter on PLAYER_FOCUS_CHANGED and after profile snaps/transitions.
AC.SyncTargetFocusFromFocusUnit = SyncTargetFocusFromFocusUnit
