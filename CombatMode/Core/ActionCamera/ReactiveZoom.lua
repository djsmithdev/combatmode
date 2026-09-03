---------------------------------------------------------------------------------------
--  Core/ActionCamera/ReactiveZoom.lua — ACTION CAMERA — Reactive scroll-zoom
---------------------------------------------------------------------------------------
--  What it does: Replaces Blizzard's instant CameraZoomIn/CameraZoomOut globals with
--  eased versions that glide to an accumulated target. Successive scrolls in the same
--  direction add momentum; reversing direction resets the target. Based on DynamicCam /
--  LibCamera's technique: uses MoveViewInStart/MoveViewOutStart with a per-frame velocity
--  derived from an easing curve rather than CameraZoomIn/Out with a distance delta.
--  Always active when Action Camera is enabled (and DynamicCam is not loaded) — no option.
--  Architecture / how it works:
--    • CM.ReactiveZoom.Enable() / Disable() hook/restore CameraZoomIn + CameraZoomOut.
--    • Each hooked scroll call updates reactiveZoomTarget (from + step + optional momentum
--      bonus) and kicks off SetZoom().
--    • SetZoom(endValue, duration) runs an OnUpdate closure that computes the OutQuad
--      easing velocity each frame and drives MoveViewInStart / MoveViewOutStart. When the
--      camera overshoots or time expires it calls MoveViewInStop / MoveViewOutStop.
--    • CM.ReactiveZoom.Apply() enables when actionCamera is on and DynamicCam is absent;
--      called from Bootstrap and SituationDriver.Init.
--    • CM.ReactiveZoom.ResetTarget() clears in-flight state; called by Transition.lua
--      before a situation SetZoom so the situation zoom wins cleanly.
--    • Tunables are hardcoded (DynamicCam defaults): addIncrementsAlways=1,
--      addIncrements=2.5, incAddDifference=1.2, maxZoomTime=0.1. cameraZoomSpeed is
--      hardcoded to 20 via Transition.ApplySharedCVars.
--  Does not: Touch situation profiles or expose options UI.
--  Related: Core/ActionCamera/Transition.lua, Core/ActionCamera/SituationDriver.lua,
--  Constants/DatabaseDefaults.lua, UI/Options/Tabs/TabCamera.lua,
--  Core/Runtime/Bootstrap.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetCameraZoom = _G.GetCameraZoom
local MoveViewInStart = _G.MoveViewInStart
local MoveViewOutStart = _G.MoveViewOutStart
local MoveViewInStop = _G.MoveViewInStop
local MoveViewOutStop = _G.MoveViewOutStop
local GetCVar = _G.C_CVar and _G.C_CVar.GetCVar
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime

-- Lua stdlib
local math = _G.math
local abs = math.abs
local max = math.max
local min = math.min
local tonumber = _G.tonumber

CM.ReactiveZoom = CM.ReactiveZoom or {}
local RZ = CM.ReactiveZoom

local origZoomIn = _G.CameraZoomIn
local origZoomOut = _G.CameraZoomOut

-- DynamicCam-matching defaults (not user-configurable).
local ADD_INCREMENTS_ALWAYS = 1
local ADD_INCREMENTS = 2.5
local INC_ADD_DIFFERENCE = 1.2
local MAX_ZOOM_TIME = 0.1
local HARDCODED_ZOOM_SPEED = 20

local reactiveZoomTarget = nil
local driveFrame = nil
local enabled = false

-- Active easing state (mirrors LibCamera's closure approach but without the lib).
local easeBeginTime = nil
local easeBeginValue = nil
local easeEndValue = nil
local easeDuration = nil

-- -----------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------

local function GetZoomSpeed()
  return tonumber(GetCVar and GetCVar("cameraZoomSpeed")) or HARDCODED_ZOOM_SPEED
end

local function GetMaxZoomYards()
  local g = CM.DB and CM.DB.global
  return (g and g.actionCameraMaxZoom) or 20
end

-- OutQuad: fast start, decelerates to target (matches DynamicCam default).
local function OutQuad(t, b, c, d)
  t = t / d
  return -c * t * (t - 2) + b
end

-- Approximate instantaneous velocity of the easing curve at time t (yards/sec).
local INTERVAL = 1 / 60
local function EaseVelocity(t, b, c, d)
  local half = INTERVAL / 2
  if t > half and (t + half) < d then
    return (OutQuad(t + half, b, c, d) - OutQuad(t - half, b, c, d)) / INTERVAL
  elseif t + INTERVAL < d then
    return (OutQuad(t + INTERVAL, b, c, d) - OutQuad(t, b, c, d)) / INTERVAL
  else
    -- Last interval: linear finish.
    return (easeEndValue - GetCameraZoom()) / INTERVAL
  end
end

-- -----------------------------------------------------------------------
-- Zoom drive
-- -----------------------------------------------------------------------

local function StopZooming()
  if driveFrame then
    driveFrame:SetScript("OnUpdate", nil)
  end
  MoveViewInStop()
  MoveViewOutStop()
  easeBeginTime = nil
  easeBeginValue = nil
  easeEndValue = nil
  easeDuration = nil
end

local function SetZoom(endValue, duration)
  StopZooming()

  if not driveFrame then
    driveFrame = CreateFrame("Frame", "CombatModeReactiveZoomFrame")
  end

  -- Values are captured on the first OnUpdate tick (one frame after SetZoom),
  -- identical to LibCamera's pattern.
  easeEndValue = endValue
  easeDuration = duration

  driveFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    easeBeginTime = easeBeginTime or now
    easeBeginValue = easeBeginValue or GetCameraZoom()
    local change = easeEndValue - easeBeginValue

    local currentValue = GetCameraZoom()
    local t = now - easeBeginTime

    local beyondTarget = (change > 0 and currentValue >= easeEndValue)
      or (change < 0 and currentValue <= easeEndValue)

    if not beyondTarget and (easeBeginTime + easeDuration) > now then
      local speed = EaseVelocity(t, easeBeginValue, change, easeDuration)
      if speed and speed ~= 0 then
        local zoomSpeed = GetZoomSpeed()
        if speed > 0 then
          MoveViewOutStart(speed / zoomSpeed)
        else
          MoveViewInStart(-speed / zoomSpeed)
        end
      end
    else
      -- Done — stop camera movement and clear state.
      StopZooming()
      reactiveZoomTarget = nil
    end
  end)
end

-- -----------------------------------------------------------------------
-- Hooked zoom functions
-- -----------------------------------------------------------------------

local function ReactiveZoom(zoomIn, increments)
  if increments == 0 then
    return
  end

  local current = GetCameraZoom()

  -- Reset target when reversing direction.
  if zoomIn then
    if reactiveZoomTarget and reactiveZoomTarget > current then
      reactiveZoomTarget = nil
    end
  else
    if reactiveZoomTarget and reactiveZoomTarget < current then
      reactiveZoomTarget = nil
    end
  end

  local from = reactiveZoomTarget or current
  local step = increments + ADD_INCREMENTS_ALWAYS

  -- Momentum bonus when already mid-travel.
  if reactiveZoomTarget and abs(reactiveZoomTarget - current) > INC_ADD_DIFFERENCE then
    step = step + ADD_INCREMENTS
  end

  if zoomIn then
    reactiveZoomTarget = max(0, from - step)
  else
    reactiveZoomTarget = min(GetMaxZoomYards(), from + step)
  end

  -- Compute travel time: how long at native zoom speed (capped to maxZoomTime).
  local distance = abs(reactiveZoomTarget - current)
  local zoomSpeed = GetZoomSpeed()
  local duration = min(MAX_ZOOM_TIME, distance / zoomSpeed)
  if duration < (1 / 120) then
    -- Too short to ease — use originals for a clean single-frame snap.
    if zoomIn then
      origZoomIn(distance)
    else
      origZoomOut(distance)
    end
    reactiveZoomTarget = nil
    return
  end

  SetZoom(reactiveZoomTarget, duration)
end

local function ReactiveZoomIn(increments)
  ReactiveZoom(true, increments)
end

local function ReactiveZoomOut(increments)
  ReactiveZoom(false, increments)
end

-- -----------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------

function RZ.Enable()
  if enabled then
    return
  end
  enabled = true
  reactiveZoomTarget = nil
  _G.CameraZoomIn = ReactiveZoomIn
  _G.CameraZoomOut = ReactiveZoomOut
end

function RZ.Disable()
  if not enabled then
    return
  end
  enabled = false
  StopZooming()
  reactiveZoomTarget = nil
  _G.CameraZoomIn = origZoomIn
  _G.CameraZoomOut = origZoomOut
end

function RZ.IsEnabled()
  return enabled
end

--- Enable when Action Camera is on and DynamicCam is not loaded; otherwise disable.
function RZ.Apply()
  local g = CM.DB and CM.DB.global
  if g and g.actionCamera == true and not CM.DynamicCam then
    RZ.Enable()
  else
    RZ.Disable()
  end
end

--- Reset the in-flight target (e.g. after a situation SetZoom so the situation zoom wins).
function RZ.ResetTarget()
  StopZooming()
  reactiveZoomTarget = nil
end
