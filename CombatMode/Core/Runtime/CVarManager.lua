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
--    • GetEffectiveReticleTargetingCVarValues = preset ∪ global.reticleTargetingCVarOverrides;
--      global.reticleOutline == false swaps the outline CVars for Outline 0 + Blizzard's
--      fades. ApplyReticleOutlineCVars writes just those (Target Outline toggle).
--      global.selectionCircleMode (Selection Circle) drives ObjectSelectionCircle /
--      UnitNameFocused (both hidden from the CVar editor): "target" = the circle while a hard
--      target exists, "locked" = while it is also your focus (Target Lock), both only while
--      SoftTargetMatchLocked is 1 (the soft target then sits on that target); "soft" = Blizzard's
--      circle and name; "hidden" = none. ApplyReticleSelectionCircleCVars writes just those on
--      option changes and PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED; turning the circle on waits
--      until the soft target is on the hard target so it never slides over.
--    • ApplyMouseLookCamera / ClearMouseLookCamera — lock vs unlock (shoulder; MS via gate).
--    • SetDynamicPitch — sticky with the option; strength is global.dynamicPitchStrength
--      (ground pad). Flying pad is that value times Flying/Base so the air tilt stays
--      proportional. ApplyActionCamMotionSicknessGate keeps
--      CameraKeepCharacterCentered / CameraReduceUnexpectedMovement at 0 while pitch,
--      autofocus, or owned shoulder needs ActionCam (not freelook alone — toggling MS
--      with Mouse Look snaps skyriding FOV/zoom). Never re-enable MS while flying.
--      global.respectMotionSickness (Motion Sickness Protection): restore MS from snapshot
--      and suppress Dynamic Pitch / Shoulder Offset / Target Focus CVar writes (options stay
--      saved; turning Protection off re-applies them).
--    • SetShoulderOffset — tweens test_cameraOverShoulder with Vignette duration.
--    • SwapShoulder — keybind: negates char.shoulderOffset (tweened), or the live CVar when
--      DynamicCam / SteadyCam own it.
--      Intent (slider / DC snapshot) is separate from the live blend. Optional
--      global.shoulderFollowsMouseLook (default off): when on, ease with Mouse Look
--      chrome; when off, keep configured offset always. DynamicCam + follow: drive only
--      unlock→0 / restore; otherwise relinquish.
--      Mid-tween toggles retarget; never treat a mid-blend CVar sample as intent.
--    • SyncTargetFocusFromFocusUnit — Autofocus Locked Target (kept with DynamicCam;
--      forces MS off while focus+option active unless Motion Sickness Protection).
--    • ConfigStickyCrosshair: Blizzard-reset helper for Uninstall only.
--    • SetCursorFreelookCenteringCVar + SetCursorCenteredYPos — FreeLook bounce + Y sync.
--  Does not: Own SoftTarget UI widgets or freelook state machine.
--  Related: Constants/CVars.lua, Constants/DatabaseDefaults.lua,
--  Core/FreeLook/FreeLookController.lua, Core/Crosshair/Crosshair.lua,
--  Core/Crosshair/AssistedHighlight/Assist.lua, UI/Editors/ReticleCVarEditorData.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/Tabs/TabGeneral.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetCVar = _G.C_CVar.GetCVar
local GetCVarDefault = _G.C_CVar.GetCVarDefault
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsFlying = _G.IsFlying
local IsMounted = _G.IsMounted
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit

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
local pcall = _G.pcall
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
  -- CM values and break Uninstall.
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

local BLIZZARD_CVAR_TABLES = {
  "BlizzardReticleTargetingCVarValues",
  "BlizzardMouseLookCameraCVarValues",
  "BlizzardTargetFocusCVarValues",
}

--- Blizzard's own value for a managed CVar, or nil when the hard-coded tables do not list it.
local function BlizzardCVarDefault(name)
  for _, tableName in ipairs(BLIZZARD_CVAR_TABLES) do
    local value = CM.Constants[tableName][name]
    if value ~= nil then
      return value
    end
  end
  return nil
end

--- Restore CVars from the pre-CM snapshot; managed CVars missing from it (added by an update
--- after the snapshot was taken) and every CVar when no snapshot exists fall back to the
--- hard-coded Blizzard tables.
function CM.RestorePriorCVars()
  local globalDB = CM.DB and CM.DB.global
  local snap = globalDB and globalDB.priorCVarSnapshot
  restoringCVars = true

  if SnapshotIsPopulated(snap) then
    for name, value in pairs(snap) do
      SetCVar(name, value)
    end
    for _, name in ipairs(CM.Constants.ManagedCVarNames) do
      if snap[name] == nil then
        local fallback = BlizzardCVarDefault(name)
        if fallback ~= nil then
          SetCVar(name, fallback)
        end
      end
    end
    -- Freelook centering must never linger after uninstall; force off even if missing.
    SetCVar("CursorFreelookCentering", snap.CursorFreelookCentering or 0)
    CM.DebugPrint("Restored prior CVar snapshot (" .. CountKeys(snap) .. " keys).")
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

--- Whether two existing units are the same unit. Comparisons can be restricted ("secret") in
--- some situations: any error counts as no match.
local function UnitsMatch(unitA, unitB)
  if not (UnitExists(unitA) and UnitExists(unitB)) then
    return false
  end
  local ok, same = pcall(function()
    return UnitIsUnit(unitA, unitB) == true
  end)
  return ok and same == true
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

  -- Target Outline off: outlines disabled, selection fade back to Blizzard's (these CVars are
  -- excluded from the CVar editor, so there are no overrides to honor).
  local g = CM.DB and CM.DB.global
  if not CM.IsRetailClient then
    -- Forever accepts these CVars but draws no target outline (tested in game), so leave them alone.
    for _, cvar in ipairs(CM.Constants.ReticleOutlineCVarNames) do
      resolved[cvar] = nil
    end
  elseif g and g.reticleOutline == false then
    local blizzard = CM.Constants.BlizzardReticleTargetingCVarValues
    for _, cvar in ipairs(CM.Constants.ReticleOutlineCVarNames) do
      resolved[cvar] = blizzard[cvar]
    end
    resolved["Outline"] = 0
  end

  -- Selection circle (and name), hidden by the preset. The soft target follows the player, not the
  -- (shifted) crosshair, so Blizzard's circle on it can sit on a different unit than the crosshair.
  -- "target" / "locked" light the circle only while SoftTargetMatchLocked is 1: the soft target then
  -- sits on the hard target, so the circle cannot land elsewhere. "soft" is Blizzard's own.
  local mode = g and g.selectionCircleMode
  if mode ~= "locked" and mode ~= "soft" and mode ~= "hidden" then
    mode = "target"
  end
  local matchLocked = tonumber(resolved["SoftTargetMatchLocked"]) == 1
  local showCircle = mode == "soft"
  if mode == "target" then
    showCircle = matchLocked and UnitExists("target")
  elseif mode == "locked" then
    showCircle = matchLocked and UnitsMatch("focus", "target")
  end
  local blizzard = CM.Constants.BlizzardReticleTargetingCVarValues
  if showCircle then
    resolved["ObjectSelectionCircle"] = blizzard["ObjectSelectionCircle"]
  end
  if mode == "soft" then
    resolved["UnitNameFocused"] = blizzard["UnitNameFocused"]
  end

  return resolved
end

--- Writes just the outline CVars (preset, or the "off" values) after the Target Outline option
--- changes. Out of combat and only while Reticle Targeting is on (otherwise the CVars are not ours).
function CM.ApplyReticleOutlineCVars()
  if InCombatLockdown() or not (CM.DB and CM.DB.char and CM.DB.char.reticleTargeting) then
    return
  end
  local effective = CM.GetEffectiveReticleTargetingCVarValues()
  local subset = {}
  for _, cvar in ipairs(CM.Constants.ReticleOutlineCVarNames) do
    subset[cvar] = effective[cvar]
  end
  CM.SetCVars(subset)
end

-- The circle waits until the soft target is on the hard target: when a target is set the soft
-- target is still on the previous unit for a moment, and the circle would be seen sliding over.
-- Polled every SELECTION_CIRCLE_POLL_SEC for at most SELECTION_CIRCLE_MAX_WAIT_SEC, then given up
-- (the circle stays off rather than risking the wrong unit).
local SELECTION_CIRCLE_POLL_SEC = 0.02
local SELECTION_CIRCLE_MAX_WAIT_SEC = 0.5
local SOFT_UNITS = { "softenemy", "softfriend", "softinteract" }
local selectionCircleToken = 0

--- True when the hard target is also a soft target, or when no soft target exists at all (the
--- circle then cannot land on another unit).
local function SoftTargetOnTarget()
  local anySoft = false
  for _, unit in ipairs(SOFT_UNITS) do
    if UnitExists(unit) then
      anySoft = true
      if UnitsMatch(unit, "target") then
        return true
      end
    end
  end
  return not anySoft
end

--- Writes the selection circle CVars whose effective value differs from the current one.
--- Turning the circle on waits for SoftTargetOnTarget (`pollStart` is when the wait began; not in
--- "soft" mode, where Blizzard's circle is wanted wherever the soft target is); turning it off is
--- immediate. A newer call supersedes a pending poll. UnitNameFocused is refused in combat
--- (logged as ADDON_ACTION_BLOCKED), so it is skipped there.
local function ApplySelectionCircleCVars(pollStart)
  selectionCircleToken = selectionCircleToken + 1
  local effective = CM.GetEffectiveReticleTargetingCVarValues()
  local softMode = CM.DB.global.selectionCircleMode == "soft"
  local inCombat = InCombatLockdown()
  local subset = {}
  local waitForSoftTarget = false
  for _, cvar in ipairs(CM.Constants.ReticleSelectionCircleCVarNames) do
    local wanted = tonumber(effective[cvar])
    local blocked = inCombat and cvar == "UnitNameFocused"
    if not blocked and tonumber(GetCVar(cvar)) ~= wanted then
      local circleOn = cvar == "ObjectSelectionCircle" and wanted == 1 and not softMode
      if circleOn and not SoftTargetOnTarget() then
        waitForSoftTarget = true
      else
        subset[cvar] = effective[cvar]
      end
    end
  end
  if next(subset) then
    CM.SetCVars(subset)
  end
  if waitForSoftTarget then
    local startedAt = pollStart or GetTime()
    if GetTime() - startedAt < SELECTION_CIRCLE_MAX_WAIT_SEC then
      local token = selectionCircleToken
      C_Timer.After(SELECTION_CIRCLE_POLL_SEC, function()
        if token == selectionCircleToken then
          ApplySelectionCircleCVars(startedAt)
        end
      end)
    end
  end
end

--- Syncs the selection circle CVars after the Selection Circle option changes and on every
--- target / focus change. Only while Reticle Targeting is on (otherwise the CVars are not ours).
function CM.ApplyReticleSelectionCircleCVars()
  if CM.DB and CM.DB.char and CM.DB.char.reticleTargeting then
    ApplySelectionCircleCVars()
  end
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

--- Motion Sickness Protection: do not drive ActionCam feature CVars / leave MS alone.
local function RespectMotionSickness()
  -- Delegated: SteadyCam's own Motion Sickness Protection decides (it also gates
  -- Focus Locked Target here).
  if CM.SteadyCam then
    local api = _G.SteadyCamAPI
    return api ~= nil and api.RespectsMotionSickness ~= nil and api.RespectsMotionSickness() == true
  end
  local g = CM.DB and CM.DB.global
  return g and g.respectMotionSickness == true
end
CM.MotionSicknessProtectionOn = RespectMotionSickness

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
  -- SteadyCam frames the character on foot and on every mount: never write.
  if CM.SteadyCam then
    return nil
  end
  -- Protection clears CM-owned shoulder; with DynamicCam, stop writing entirely.
  if RespectMotionSickness() then
    if CM.DynamicCam then
      return nil
    end
    return 0
  end
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
    CM.DebugPrint("Shoulder Offset relinquished to " .. tostring(CM.CameraOwner))
  else
    CM.DebugPrint("Shoulder Offset target " .. tostring(desired))
  end
end

--- Swap shoulders (the keybind): mirror the shoulder to the other side of the character.
--- Works with other camera addons too: when we drive the CVar, the configured offset is negated and
--- tweened (through 0); when DynamicCam / SteadyCam own it, the live CVar is negated directly.
function CM.SwapShoulder()
  local char = CM.DB and CM.DB.char
  if not char then
    return
  end
  -- Keep the saved side in step so it survives the next Shoulder Offset refresh and relog.
  char.shoulderOffset = -(tonumber(char.shoulderOffset) or 1.2)
  EnsureShoulderOffsetDriver()
  if DesiredShoulderOffset() ~= nil then
    -- A DynamicCam restore target (after unlock→0) is a captured value, so mirror it too.
    if dcRestore ~= nil then
      dcRestore = -dcRestore
    end
    CM.SetShoulderOffset()
    return
  end
  RelinquishShoulderToLive()
  local live = ReadShoulderCVar()
  CM.SetCVar(SHOULDER_CVAR, -live)
  shoulderCurrent = -live
end

function _G.CombatMode_SwapShoulder()
  CM.SwapShoulder()
end

local function ApplyDynamicPitchPads()
  local CONSTS = CM.Constants
  local baseDefault = CONSTS.MouseLookCameraPitchBase or 0.4
  local flyingDefault = CONSTS.MouseLookCameraPitchFlying or 0.75
  local flyingScale = baseDefault > 0 and (flyingDefault / baseDefault) or 1
  local minPad = CONSTS.MouseLookCameraPitchStrengthMin or 0
  local maxPad = CONSTS.MouseLookCameraPitchStrengthMax or 1
  local g = CM.DB and CM.DB.global
  local strength = g and tonumber(g.dynamicPitchStrength)
  if strength == nil then
    strength = CONSTS.MouseLookCameraPitchDefault or 0
  end
  if strength < minPad then
    strength = minPad
  elseif strength > maxPad then
    strength = maxPad
  end
  CM.SetCVar("test_cameraDynamicPitchBaseFovPad", strength)
  CM.SetCVar("test_cameraDynamicPitchBaseFovPadFlying", strength * flyingScale)
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
--- Do not key this off freelook alone: flipping MS with Mouse Look lock/unlock snaps
--- skyriding FOV/zoom when Dynamic Pitch is off (pitch-on keeps MS sticky at 0).
local function ShoulderNeedsActionCam()
  if CM.CameraOwner then
    return false
  end
  if ShoulderFollowsMouseLook() then
    return IsCameraChromeOn()
  end
  return not NearlyEqual(ConfiguredShoulderOffset(), 0)
end

local function NeedActionCamMotionSicknessOff()
  if RespectMotionSickness() then
    return false
  end
  local g = CM.DB and CM.DB.global
  if g and g.dynamicPitch ~= false then
    return true
  end
  if g and g.autofocusLockedTarget == true and UnitExists and UnitExists("focus") == true then
    return true
  end
  if ShoulderNeedsActionCam() then
    return true
  end
  return false
end

local function MotionSicknessReleaseValues()
  local snap = CM.DB and CM.DB.global and CM.DB.global.priorCVarSnapshot
  if type(snap) == "table" then
    local keep = tonumber(snap.CameraKeepCharacterCentered)
    local reduce = tonumber(snap.CameraReduceUnexpectedMovement)
    if keep ~= nil and reduce ~= nil then
      return keep, reduce
    end
  end
  return 1, 1
end

local function WriteMotionSicknessCVars(keep, reduce)
  local curKeep = tonumber(GetCVar("CameraKeepCharacterCentered"))
  local curReduce = tonumber(GetCVar("CameraReduceUnexpectedMovement"))
  if curKeep == keep and curReduce == reduce then
    return
  end
  CM.SetCVar("CameraKeepCharacterCentered", keep)
  CM.SetCVar("CameraReduceUnexpectedMovement", reduce)
end

--- Restore MS CVars from prior snapshot (or Blizzard-on defaults). Used when enabling
--- respectMotionSickness or when ActionCam no longer needs MS off.
function CM.RestoreMotionSicknessFromSnapshot()
  if CM.CameraOwner then
    return
  end
  local keep, reduce = MotionSicknessReleaseValues()
  WriteMotionSicknessCVars(keep, reduce)
end

function CM.ApplyActionCamMotionSicknessGate()
  if CM.CameraOwner then
    return
  end
  if RespectMotionSickness() then
    CM.RestoreMotionSicknessFromSnapshot()
    return
  end
  local off = NeedActionCamMotionSicknessOff()
  local keep, reduce
  if off then
    keep, reduce = 0, 0
  else
    -- Re-enabling MS mid-air snaps skyriding camera; leave CVars alone until grounded.
    if IsFlying and IsFlying() then
      return
    end
    keep, reduce = MotionSicknessReleaseValues()
  end
  WriteMotionSicknessCVars(keep, reduce)
end

--- Sticky Dynamic Pitch (option-gated, not freelook). Pads + master CVar + MS gate
--- so unlock / option toggles actually take effect. Forced off under Motion Sickness Protection.
function CM.SetDynamicPitch()
  if CM.CameraOwner then
    return
  end
  local wantPitch = CM.DB
    and CM.DB.global
    and CM.DB.global.dynamicPitch ~= false
    and not RespectMotionSickness()
  if wantPitch then
    ApplyDynamicPitchPads()
  end
  CM.SetCVar("test_cameraDynamicPitch", wantPitch and 1 or 0)
  CM.ApplyActionCamMotionSicknessGate()
  CM.DebugPrint("Dynamic Pitch " .. (wantPitch and "on" or "off"))
end

--- Apply Mouse Look camera chrome while freelook is locked (MS off when we own it, shoulder).
function CM.ApplyMouseLookCamera()
  if not CM.CameraOwner then
    CM.ApplyActionCamMotionSicknessGate()
  end
  CM.SetShoulderOffset()
  CM.DebugPrint("Mouse Look camera applied")
end

--- Clear Mouse Look camera chrome while freelook is unlocked (tween shoulder to 0; MS gate).
function CM.ClearMouseLookCamera()
  CM.SetShoulderOffset()
  if not CM.CameraOwner then
    CM.ApplyActionCamMotionSicknessGate()
  end
  CM.DebugPrint("Mouse Look camera cleared")
end

--- Enable enemy Target Focus when autofocusLockedTarget is on and UnitExists("focus").
--- Kept even with DynamicCam: Target Lock autofocus is a Combat Mode feature, not a
--- camera-preset handoff. When active, force motion-sickness ActionCam gates off —
--- Target Focus is a no-op while those CVars are 1. When inactive with DC, leave MS alone.
--- Motion Sickness Protection forces Target Focus off (option value preserved).
function CM.SyncTargetFocusFromFocusUnit()
  local g = CM.DB and CM.DB.global
  local optOn = g and g.autofocusLockedTarget == true and not RespectMotionSickness()
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
    WriteMotionSicknessCVars(0, 0)
  elseif not CM.CameraOwner then
    CM.ApplyActionCamMotionSicknessGate()
  end
end

--- Re-apply ActionCam feature CVars after Motion Sickness Protection toggles (or login).
function CM.ApplyMotionSicknessProtectionState()
  if CM.SetDynamicPitch then
    CM.SetDynamicPitch()
  end
  if CM.SetShoulderOffset then
    CM.SetShoulderOffset()
  end
  if CM.SyncTargetFocusFromFocusUnit then
    CM.SyncTargetFocusFromFocusUnit()
  end
  if not CM.CameraOwner then
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
  if CM.CameraOwner then
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
