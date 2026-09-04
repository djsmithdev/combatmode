---------------------------------------------------------------------------------------
--  Core/ActionCamera/SituationDriver.lua — ACTION CAMERA — situation FSM + events
---------------------------------------------------------------------------------------
--  What it does: Owns the Action Camera situation state machine. Evaluates the three
--  situations (Mounted > Combat > Base) on triggered events and a ~1s safety poll,
--  migrates old flat DB keys on first load, and drives Transition.lua to cross-fade
--  camera CVars when the active situation changes.
--  Architecture / how it works:
--    • CM.ActionCamera.Evaluate(instant) — pick highest-priority matching situation;
--      call ChangeSituation when it differs from the current one.
--    • CM.ActionCamera.GetActiveId() — current situation id.
--    • CM.ActionCamera.ApplyProfile(id, instant) — apply a profile immediately (used by
--      options live preview and Rematch); no-op when Action Camera preset is off.
--    • CM.ActionCamera.Shutdown() — clear state + disable reactive zoom (preset off).
--    • Migration: MigrateActionCameraDB() runs once if actionCameraProfiles is nil,
--      seeding from old flat keys and char.shoulderOffset / char.stickyCrosshair.
--    • EventRouter integration: CM.Constants.BLIZZARD_EVENTS.ACTION_CAMERA_EVENTS added
--      in Gameplay.lua; HandleEventByCategory dispatches to CM.ActionCamera.OnEvent.
--    • Safety poll: ~1s C_Timer loop while Action Camera is enabled (mount takeoff etc.).
--    • Pauses situation transitions when actionCamMouselookDisable is on and freelook
--      is permanently off (ConfigActionCameraMouselookDisable owns those CVars then).
--      Resumes and re-applies CVars without setZoom when freelook is locked again.
--  Does not: Implement easing math (Transition.lua), register WoW events on the root
--    frame (Embeds.xml/Bootstrap), or own options sliders.
--  Related: Core/ActionCamera/Transition.lua, Constants/ActionCamera.lua,
--  Constants/DatabaseDefaults.lua, Core/Runtime/CVarManager.lua,
--  Core/Runtime/EventRouter.lua, Constants/Gameplay.lua,
--  UI/Options/Tabs/TabCamera.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer

-- Lua stdlib
local pairs = _G.pairs
local type = _G.type
local ipairs = _G.ipairs

local AC = CM.ActionCamera or {}
CM.ActionCamera = AC

local CONSTS = CM.Constants
local SITUATIONS = CONSTS.ActionCameraSituations
local PROFILE_DEFAULTS = CONSTS.ActionCameraProfileDefaults

-- Current active situation id. nil = not yet determined.
local currentId = nil
-- True while a permanent-unlock (MouseLook disabled) is pausing situation changes.
local paused = false

-- -----------------------------------------------------------------------
-- DB helpers
-- -----------------------------------------------------------------------

-- Deep-copy a profile defaults table.
local function CopyDefaults(src)
  local out = {}
  for k, v in pairs(src) do
    out[k] = v
  end
  return out
end

-- Get the live DB profiles table, creating it if absent.
local function GetProfiles()
  local g = CM.DB and CM.DB.global
  if not g then
    return nil
  end
  if type(g.actionCameraProfiles) ~= "table" then
    g.actionCameraProfiles = {
      base = CopyDefaults(PROFILE_DEFAULTS.base),
      mounted = CopyDefaults(PROFILE_DEFAULTS.mounted),
      combat = CopyDefaults(PROFILE_DEFAULTS.combat),
    }
  end
  return g.actionCameraProfiles
end

-- Return a profile for the given id with defaults for any nil field.
function AC.GetProfile(id)
  local profiles = GetProfiles()
  local def = PROFILE_DEFAULTS[id] or PROFILE_DEFAULTS.base
  if not profiles then
    return CopyDefaults(def)
  end
  local raw = profiles[id]
  if type(raw) ~= "table" then
    profiles[id] = CopyDefaults(def)
    return CopyDefaults(def)
  end
  -- Fill missing fields from defaults, and preserve stored keys not in defaults
  -- (e.g. setZoom which defaults to nil).
  local out = {}
  for k, v in pairs(def) do
    local stored = raw[k]
    out[k] = (stored ~= nil) and stored or v
  end
  for k, v in pairs(raw) do
    if out[k] == nil then
      out[k] = v
    end
  end
  return out
end

-- -----------------------------------------------------------------------
-- Migration
-- -----------------------------------------------------------------------

local function MigrateActionCameraDB()
  local g = CM.DB and CM.DB.global
  local c = CM.DB and CM.DB.char
  if not g or not c then
    return
  end
  -- Only run once: if profiles already exist, skip.
  if type(g.actionCameraProfiles) == "table" then
    return
  end

  -- Read old flat keys (may be nil if already cleaned or never set).
  local oldFov = g.actionCameraFov
  local oldZoom = g.actionCameraMaxZoom or 20
  local oldHeadTracking = g.actionCameraHeadTracking
  local oldShoulder = (type(c.shoulderOffset) == "number") and c.shoulderOffset or nil

  -- Promote maxZoom to shared global key (no longer per-situation).
  if g.actionCameraMaxZoom == nil or g.actionCameraMaxZoom == 15 then
    g.actionCameraMaxZoom = oldZoom
  end

  -- Seed all three profiles from factory defaults, overlaying any legacy flat keys.
  -- Mounted keeps its own shoulder default (0); do not stamp the old flat shoulder onto it.
  local function MakeProfile(defaultsId)
    local def = PROFILE_DEFAULTS[defaultsId]
    local shoulder = def.shoulder
    if defaultsId ~= "mounted" and oldShoulder ~= nil then
      shoulder = oldShoulder
    end
    return {
      fov = oldFov or def.fov,
      setZoom = def.setZoom,
      shoulder = shoulder,
      headTracking = oldHeadTracking or def.headTracking,
    }
  end

  g.actionCameraProfiles = {
    base = MakeProfile("base"),
    mounted = MakeProfile("mounted"),
    combat = MakeProfile("combat"),
  }

  CM.DebugPrint(
    "ActionCamera: migrated old flat keys → per-situation profiles "
      .. "(fov="
      .. tostring(oldFov)
      .. " zoom="
      .. tostring(oldZoom)
      .. " shoulder="
      .. tostring(oldShoulder)
      .. ")"
  )
end

-- -----------------------------------------------------------------------
-- Situation evaluation
-- -----------------------------------------------------------------------

local function IsDriverEnabled()
  if CM.DynamicCam then
    return false
  end
  local g = CM.DB and CM.DB.global
  return g and g.actionCamera == true
end

local function FindBestSituation()
  local bestId = "base"
  local bestPriority = -1
  for _, sit in ipairs(SITUATIONS) do
    if sit.priority > bestPriority then
      local ok, result = pcall(sit.condition)
      if ok and result then
        bestPriority = sit.priority
        bestId = sit.id
      end
    end
  end
  return bestId
end

local function ApplyCurrentProfile(instant, skipZoom)
  if not currentId then
    return
  end
  local profile = AC.GetProfile(currentId)
  if CM.ActionCamera.StartTransition then
    CM.ActionCamera.StartTransition(profile, instant, nil, skipZoom)
  end
end

local function ChangeSituation(newId, instant)
  if newId == currentId then
    return
  end
  local prev = currentId
  currentId = newId
  CM.DebugPrint("ActionCamera: situation " .. tostring(prev) .. " → " .. tostring(newId))
  ApplyCurrentProfile(instant)
end

--- Evaluate situations and apply a transition if the active one changed.
--- @param instant boolean  If true, snap without easing (login, Rematch).
function AC.Evaluate(instant)
  if not IsDriverEnabled() then
    return
  end
  if paused then
    return
  end
  local best = FindBestSituation()
  if instant or currentId == nil then
    currentId = best
    ApplyCurrentProfile(true)
  else
    ChangeSituation(best, false)
  end
end

--- Re-evaluate immediately (used from event handler).
function AC.OnEvent(event, ...)
  if not IsDriverEnabled() then
    return
  end
  -- UNIT_AURA: only care about player unit.
  if event == "UNIT_AURA" then
    local unit = ...
    if unit ~= "player" then
      return
    end
  end
  -- PLAYER_REGEN_DISABLED triggers immediately (entering combat).
  AC.Evaluate(false)
end

--- Returns the current active situation id.
function AC.GetActiveId()
  return currentId
end

--- Apply a specific profile directly (live preview from options or Rematch).
--- @param id string  "base", "mounted", or "combat".
--- @param instant boolean
function AC.ApplyProfile(id, instant)
  if not IsDriverEnabled() then
    return
  end
  local profile = AC.GetProfile(id)
  if CM.ActionCamera.StartTransition then
    CM.ActionCamera.StartTransition(profile, instant)
  end
end

-- -----------------------------------------------------------------------
-- Pause / resume (Disable with Mouse Look)
-- -----------------------------------------------------------------------

--- Called by FreeLookController when ActionCamera + mouselock-disable mode kicks in.
--- While paused, situation changes are suppressed to avoid fighting ConfigActionCameraMouselookDisable.
function AC.Pause()
  if not IsDriverEnabled() then
    return
  end
  paused = true
  if CM.ActionCamera.StopTransition then
    CM.ActionCamera.StopTransition()
  end
end

--- Resume situation tracking and re-apply the active profile CVars.
--- Skips setZoom so toggling Mouse Look does not yank camera distance.
--- Evaluate(false) alone is a no-op when the situation did not change, so pitch /
--- shoulder stomped by ConfigActionCameraMouselookDisable would stay off.
function AC.Resume()
  if not IsDriverEnabled() then
    return
  end
  paused = false
  local best = FindBestSituation()
  local skipZoom = true
  if currentId == nil or best ~= currentId then
    local prev = currentId
    currentId = best
    CM.DebugPrint(
      "ActionCamera: situation " .. tostring(prev) .. " → " .. tostring(best) .. " (resume)"
    )
    ApplyCurrentProfile(false, skipZoom)
  else
    ApplyCurrentProfile(false, skipZoom)
  end
end

function AC.IsPaused()
  return paused
end

--- Stop the driver and reactive zoom. Called when Action Camera preset is turned off
--- so freelook unlock/lock cannot re-apply profiles after disable.
function AC.Shutdown()
  paused = false
  currentId = nil
  if CM.ActionCamera.StopTransition then
    CM.ActionCamera.StopTransition()
  end
  if CM.ReactiveZoom and CM.ReactiveZoom.Disable then
    CM.ReactiveZoom.Disable()
  end
  CM.DebugPrint("ActionCamera: shutdown")
end

-- -----------------------------------------------------------------------
-- Safety poll (~1s)
-- -----------------------------------------------------------------------

local function SchedulePoll()
  if not C_Timer or not C_Timer.After then
    return
  end
  C_Timer.After(1.1, function()
    if IsDriverEnabled() then
      AC.Evaluate(false)
      SchedulePoll()
    end
  end)
end

-- -----------------------------------------------------------------------
-- OnUpdate relay (called by SituationDriver from Embeds.xml root frame)
-- -----------------------------------------------------------------------

function AC.OnUpdate(elapsed)
  if not IsDriverEnabled() then
    return
  end
  if paused then
    return
  end
  if CM.ActionCamera.OnTransitionUpdate then
    CM.ActionCamera.OnTransitionUpdate(elapsed)
  end
end

-- -----------------------------------------------------------------------
-- Initialise (called from Rematch / Bootstrap)
-- -----------------------------------------------------------------------

function AC.Init()
  MigrateActionCameraDB()
  if not IsDriverEnabled() then
    AC.Shutdown()
    return
  end
  if CM.ReactiveZoom then
    CM.ReactiveZoom.Apply()
  end
  AC.Evaluate(true)
  SchedulePoll()
end
