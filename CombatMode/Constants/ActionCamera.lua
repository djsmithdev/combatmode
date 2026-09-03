---------------------------------------------------------------------------------------
--  Constants/ActionCamera.lua — CONSTANTS — Action Camera situation definitions
---------------------------------------------------------------------------------------
--  What it does: Declares the three Action Camera situations (Base, Mounted, Combat),
--  their priorities, trigger events, condition functions, default per-profile values,
--  the ordered list of CVars each profile applies, and transition defaults.
--  Architecture / how it works:
--    • CM.Constants.ActionCameraSituations — ordered list of situation defs consumed by
--      SituationDriver. Each entry: id, priority, events (list), condition (fn).
--    • CM.Constants.ActionCameraProfileDefaults — default table for each profile id; all
--      three profiles share the same keys. Used by DatabaseDefaults migration and DB init.
--    • CM.Constants.ActionCameraNumericCVars — ordered list of CVar keys that the
--      Transition module eases. Does not include boolean toggles (actionCameraDynamicPitch
--      global; Target Focus enable follows UnitExists("focus")).
--    • CM.Constants.ActionCameraToggleCVars — CVars that are instant-set booleans.
--    • CM.Constants.ActionCameraTransitionDefault — hardcoded situation blend duration (s).
--  Does not: Call SetCVar, read DB, or register events.
--  Related: Core/ActionCamera/SituationDriver.lua, Core/ActionCamera/Transition.lua,
--  Constants/DatabaseDefaults.lua, Core/Runtime/CVarManager.lua,
--  UI/Options/Tabs/TabCamera.lua
---------------------------------------------------------------------------------------
local _, CM = ...

local IsMounted = _G.IsMounted
local UnitOnTaxi = _G.UnitOnTaxi
local UnitAffectingCombat = _G.UnitAffectingCombat

-- Distance base matches Blizzard's cameraDistanceMaxZoomFactor scale (1.0 = 15 yards).
CM.Constants.ACTION_CAMERA_DISTANCE_BASE_YARDS = 15

-- Transition duration in seconds (used by Transition.lua; configurable via DB).
CM.Constants.ActionCameraTransitionDefault = 0.75

-- Ordered list of numeric CVar keys the Transition module linearly interpolates.
-- Boolean toggles (actionCameraDynamicPitch global; Target Focus follows focus unit)
-- are handled separately.
CM.Constants.ActionCameraNumericCVars = {
  "cameraFov",
  "test_cameraOverShoulder",
  "test_cameraHeadMovementStrength",
}

-- Hardcoded pitch / enemy-target-focus intensities (not per-situation; toggles only).
CM.Constants.ActionCameraPitchBase = 0.4
CM.Constants.ActionCameraPitchFlying = 0.75
CM.Constants.ActionCameraPitchDownScale = 0.25
CM.Constants.ActionCameraTargetFocusYaw = 0.7
CM.Constants.ActionCameraTargetFocusPitch = 0.2

-- Instant-set toggle CVars (not eased). Target Focus enable is driven by focus unit.
CM.Constants.ActionCameraToggleCVars = {
  "test_cameraDynamicPitch",
}

-- Default values shared by all three profile defaults (Base / Mounted / Combat).
-- These are account-wide; no char-scoped keys.
local PROFILE_DEFAULTS = {
  -- Camera
  fov = 75,
  setZoom = 7, -- yards
  shoulder = 1.2,
  headTracking = 1,
}

-- Per-profile defaults; each profile starts as a copy of PROFILE_DEFAULTS.
-- These are the factory defaults; actual DB values may differ after migration/user changes.
CM.Constants.ActionCameraProfileDefaults = {
  base = {
    fov = PROFILE_DEFAULTS.fov,
    setZoom = PROFILE_DEFAULTS.setZoom,
    shoulder = PROFILE_DEFAULTS.shoulder,
    headTracking = PROFILE_DEFAULTS.headTracking,
  },
  mounted = {
    fov = 85,
    setZoom = 15,
    shoulder = 0,
    headTracking = 1,
  },
  combat = {
    fov = 80,
    setZoom = 10,
    shoulder = 1.2,
    headTracking = 1,
  },
}

-- Situation definitions. Processed in priority order (highest wins).
-- events: list of WoW event strings that may trigger re-evaluation.
-- condition: function that returns true when this situation is active.
CM.Constants.ActionCameraSituations = {
  {
    id = "mounted",
    priority = 100,
    events = { "PLAYER_MOUNT_DISPLAY_CHANGED", "UNIT_AURA" },
    -- Filter UNIT_AURA to player in SituationDriver.
    condition = function()
      return (IsMounted and IsMounted()) and not (UnitOnTaxi and UnitOnTaxi("player"))
    end,
  },
  {
    id = "combat",
    priority = 50,
    -- PLAYER_REGEN_DISABLED triggers immediate evaluation in SituationDriver.
    events = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA" },
    condition = function()
      return UnitAffectingCombat and UnitAffectingCombat("player") == true
    end,
  },
  {
    id = "base",
    priority = 0,
    events = {}, -- always active as fallback; no dedicated events needed
    condition = function()
      return true
    end,
  },
}
