---------------------------------------------------------------------------------------
--  Core/Runtime/EventRouter.lua — RUNTIME — event map + CombatMode_OnEvent
---------------------------------------------------------------------------------------
--  What it does: Builds eventCategoryMap from Constants.BLIZZARD_EVENTS and implements
--  global CombatMode_OnEvent(self, event, ...) — first arg is the root frame. Dispatches
--  free-look lock/unlock, Rematch, deferred binding flush, click-cast refresh,
--  crosshair cast feedback, Assisted Highlight cast hooks, and Party Radial combat/roster.
--  Architecture / how it works:
--    • BuildEventCategoryMap / GetEventCategoryMap used at enable time.
--    • REFRESH_BINDINGS_EVENTS coalesced via C_Timer so one RefreshClickCastMacros runs
--      after bursts (also Toggle Focus + Party Radial side effects). Self-echo events
--      during apply are suppressed; Assisted Combat suggestion slots and unchanged
--      ACTIONBAR_SLOT_CHANGED are skipped.
--    • CAST_FEEDBACK_EVENTS → OnCrosshairCastFeedbackEvent; player casts also
--      OnAssistedHighlightCastProgress (dark swipe) and SUCCEEDED →
--      OnAssistedHighlightSpellCast(spellID).
--    • ASSISTED_HIGHLIGHT_EVENTS → OnAssistedHighlightAssistedActionCast.
--    • FRIENDLY_TARGETING_EVENTS double as Party Radial combat start/end +
--      FlushDeferredBindingChanges / FlushPendingClickCastRefresh on PLAYER_REGEN_ENABLED.
--    • FOCUS_LOCK_EVENTS → UpdateFocusNameplateMarker + OnCrosshairFocusLockEvent.
--    • FOCUS_NAMEPLATE_EVENTS → OnFocusNameplateMarkerEvent (ADD/REMOVE).
--  Does not: RegisterEvent itself (root frame / Bootstrap) or own feature logic.
--  Related: Constants/Gameplay.lua, Core/FreeLook/FreeLookController.lua,
--  Core/ClickCasting/BindingOverrides.lua, Core/Crosshair/Crosshair.lua,
--  Core/Crosshair/AssistedHighlight/{Keybinds,CastProgress,Feedback,Assist}.lua,
--  Core/Crosshair/FocusNameplateMarker.lua, Core/PartyRadial/PartyRadial.lua,
--  Core/Runtime/BindingQueue.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local GetTime = _G.GetTime

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local select = _G.select

local eventCategoryMap = {}

-- Coalesce REFRESH_BINDINGS_EVENTS: one RefreshClickCastMacros after bursts.
-- Our override re-applies can echo UPDATE_BINDINGS / ACTIONBAR_SLOT_CHANGED; suppress
-- those while applying. Unchanged action-bar content is skipped via fingerprint.
local clickCastRefreshGen = 0
local clickCastRefreshReason = "bar" -- "cvar" | event name
local clickCastRefreshSlot = nil -- ACTIONBAR_SLOT_CHANGED payload when present
local selfBindingEventSuppressUntil = 0
local lastActionBarFingerprint = nil

local function SuppressSelfBindingEvents(seconds)
  local now = GetTime and GetTime() or 0
  local untilTime = now + (seconds or 0.2)
  if untilTime > selfBindingEventSuppressUntil then
    selfBindingEventSuppressUntil = untilTime
  end
end

local function IsSelfBindingEventSuppressed()
  return GetTime and GetTime() < selfBindingEventSuppressUntil
end

local function ActionBarContentUnchanged()
  if not CM.GetActionBarContentFingerprint then
    return false
  end
  local fp = CM.GetActionBarContentFingerprint()
  if lastActionBarFingerprint ~= nil and fp == lastActionBarFingerprint then
    return true
  end
  return false
end

local function RememberActionBarFingerprint()
  if CM.GetActionBarContentFingerprint then
    lastActionBarFingerprint = CM.GetActionBarContentFingerprint()
  end
end

local function DebugPrintClickCastRefreshReason()
  if clickCastRefreshReason == "cvar" then
    CM.DebugPrint("ActionButtonUseKeyDown changed, refreshing binding macros")
  elseif clickCastRefreshReason == "ACTIONBAR_SLOT_CHANGED" and clickCastRefreshSlot ~= nil then
    CM.DebugPrint(
      "Refreshing binding macros (ACTIONBAR_SLOT_CHANGED slot="
        .. tostring(clickCastRefreshSlot)
        .. ")"
    )
  else
    CM.DebugPrint("Refreshing binding macros (" .. tostring(clickCastRefreshReason) .. ")")
  end
end

local function RunClickCastBindingRefresh()
  CM.Profile("EventRouter:BindRefresh", function()
    -- Binding/attribute writes can echo UPDATE_BINDINGS and ACTIONBAR_SLOT_CHANGED.
    SuppressSelfBindingEvents(0.5)
    DebugPrintClickCastRefreshReason()
    CM.RefreshClickCastMacros()
    if
      CM.ApplyToggleFocusTargetBinding
      and (
        clickCastRefreshReason == "UPDATE_BINDINGS"
        or clickCastRefreshReason == "HOUSE_EDITOR_MODE_CHANGED"
      )
    then
      CM.ApplyToggleFocusTargetBinding()
      if CM.ApplyCycleFocusBindings then
        CM.ApplyCycleFocusBindings()
      end
    end
    if CM.PartyRadial and CM.PartyRadial.OnActionBarChanged then
      if clickCastRefreshReason == "GROUP_ROSTER_UPDATE" then
        if CM.PartyRadial.OnGroupRosterUpdate then
          CM.PartyRadial.OnGroupRosterUpdate()
        end
      elseif clickCastRefreshReason ~= "UPDATE_BINDINGS" then
        CM.PartyRadial.OnActionBarChanged()
      end
    end
    RememberActionBarFingerprint()
  end)
end

local function ScheduleClickCastBindingRefresh()
  if not C_Timer or not C_Timer.After then
    RunClickCastBindingRefresh()
    return
  end
  clickCastRefreshGen = clickCastRefreshGen + 1
  local myGen = clickCastRefreshGen
  C_Timer.After(0.15, function()
    if myGen ~= clickCastRefreshGen then
      return
    end
    RunClickCastBindingRefresh()
  end)
end

--[[
Handle events based on their category.
You need to first register the event in the CM.Constants.BLIZZARD_EVENTS table before 
using it here.
Checks which category in the table the event that's been fired belongs to, and then 
calls the appropriate function.
]]
--
local function HandleEventByCategory(category, event, ...)
  local cvarName = select(1, ...)
  local eventHandlers = {
    UNLOCK_EVENTS = function()
      CM.UnlockFreeLook()
    end,
    LOCK_EVENTS = function()
      CM.LockFreeLook()
    end,
    REMATCH_EVENTS = function()
      if CM.RuntimeRematch then
        CM.RuntimeRematch()
      end
    end,
    FRIENDLY_TARGETING_EVENTS = function()
      if CM.PartyRadial then
        if event == "PLAYER_REGEN_DISABLED" and CM.PartyRadial.OnCombatStart then
          CM.PartyRadial.OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" and CM.PartyRadial.OnCombatEnd then
          CM.PartyRadial.OnCombatEnd()
        end
      end
      if event == "PLAYER_REGEN_ENABLED" then
        CM.FlushDeferredBindingChanges()
        if CM.FlushPendingClickCastRefresh then
          CM.FlushPendingClickCastRefresh()
        end
      end
    end,
    UNCATEGORIZED_EVENTS = function()
      CM.OnCrosshairUncategorizedEvent()
    end,
    REFRESH_BINDINGS_EVENTS = function()
      if event == "CVAR_UPDATE" and cvarName ~= "ActionButtonUseKeyDown" then
        return
      end

      -- Our own override / attribute writes echo as UPDATE_BINDINGS or ACTIONBAR_SLOT_CHANGED.
      if IsSelfBindingEventSuppressed() then
        return
      end

      -- Assisted Combat suggestion buttons rewrite their slot spell often; that must not
      -- rebuild click-cast overrides / Party Radial attrs.
      if event == "ACTIONBAR_SLOT_CHANGED" and CM.IsAssistedCombatActionSlot then
        if CM.IsAssistedCombatActionSlot(cvarName) then
          return
        end
      end

      -- Noisy ACTIONBAR_SLOT_CHANGED with unchanged spell/item/macro contents.
      if event == "ACTIONBAR_SLOT_CHANGED" and ActionBarContentUnchanged() then
        return
      end

      if event == "CVAR_UPDATE" then
        clickCastRefreshReason = "cvar"
        clickCastRefreshSlot = nil
      else
        clickCastRefreshReason = event
        if event == "ACTIONBAR_SLOT_CHANGED" then
          clickCastRefreshSlot = cvarName -- first payload arg is slot
        else
          clickCastRefreshSlot = nil
        end
      end
      ScheduleClickCastBindingRefresh()

      if event == "CVAR_UPDATE" then
        return
      end

      if CM.InvalidateAssistedHighlightKeybindCache then
        CM.InvalidateAssistedHighlightKeybindCache()
      end
    end,
    FOCUS_LOCK_EVENTS = function()
      -- Nameplate transfer suppresses the center reticle before reaction tint/scale.
      if CM.UpdateFocusNameplateMarker then
        CM.UpdateFocusNameplateMarker()
      end
      CM.OnCrosshairFocusLockEvent(event)
    end,
    FOCUS_NAMEPLATE_EVENTS = function(...)
      if CM.OnFocusNameplateMarkerEvent then
        CM.OnFocusNameplateMarkerEvent(event, ...)
      end
    end,
    CAST_FEEDBACK_EVENTS = function(...)
      if CM.OnCrosshairCastFeedbackEvent then
        CM.OnCrosshairCastFeedbackEvent(event, ...)
      end
      local unitTarget, castGUID, spellID = ...
      if unitTarget == "player" then
        if CM.OnAssistedHighlightCastProgress then
          CM.OnAssistedHighlightCastProgress(event, castGUID, spellID)
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" and CM.OnAssistedHighlightSpellCast then
          CM.OnAssistedHighlightSpellCast(spellID)
        end
      end
    end,
    ASSISTED_HIGHLIGHT_EVENTS = function()
      if CM.InvalidateSuggestedSpellCache then
        CM.InvalidateSuggestedSpellCache()
      end
      if CM.OnAssistedHighlightAssistedActionCast then
        CM.OnAssistedHighlightAssistedActionCast()
      end
    end,
  }

  if eventHandlers[category] then
    eventHandlers[category](...)
  end
end

function CM.BuildEventCategoryMap()
  eventCategoryMap = {}
  for category, registeredEvents in pairs(CM.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(registeredEvents) do
      eventCategoryMap[event] = eventCategoryMap[event] or {}
      eventCategoryMap[event][#eventCategoryMap[event] + 1] = category
    end
  end
end

function CM.GetEventCategoryMap()
  return eventCategoryMap
end

-- FIRES WHEN ONE OF OUR REGISTERED EVENTS HAPPEN IN GAME
-- CombatModeFrame XML OnEvent uses Blizzard's (self, event, ...) shape. AceEvent used to
-- invoke this as (event, ...) — accept both so rematch/lock/unlock keep working.
function _G.CombatMode_OnEvent(selfOrEvent, eventOrArg1, ...)
  local event
  if type(selfOrEvent) == "string" then
    event = selfOrEvent
    local categories = eventCategoryMap[event]
    if not categories then
      return
    end
    CM.ProfileEvent("OnEvent:" .. tostring(event))
    for _, category in ipairs(categories) do
      HandleEventByCategory(category, event, eventOrArg1, ...)
    end
    return
  end

  event = eventOrArg1
  if type(event) ~= "string" then
    return
  end
  local categories = eventCategoryMap[event]
  if not categories then
    return
  end
  CM.ProfileEvent("OnEvent:" .. tostring(event))
  for _, category in ipairs(categories) do
    HandleEventByCategory(category, event, ...)
  end
end
