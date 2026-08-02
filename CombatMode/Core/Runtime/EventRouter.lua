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
--      after bursts; also ApplyToggleFocusTargetBinding (UPDATE_BINDINGS),
--      InvalidateAssistedHighlightKeybindCache + Party Radial hooks.
--    • CAST_FEEDBACK_EVENTS → OnCrosshairCastFeedbackEvent; player casts also
--      OnAssistedHighlightCastProgress (dark swipe) and SUCCEEDED →
--      OnAssistedHighlightSpellCast(spellID).
--    • ASSISTED_HIGHLIGHT_EVENTS → OnAssistedHighlightAssistedActionCast.
--    • FRIENDLY_TARGETING_EVENTS double as Party Radial combat start/end + FlushDeferred
--      + FlushFocusCycleWheelBindingsIfDirty on PLAYER_REGEN_ENABLED.
--    • FOCUS_LOCK_EVENTS → OnCrosshairFocusLockEvent + UpdateFocusCycleWheelBindings.
--  Does not: RegisterEvent itself (root frame / Bootstrap) or own feature logic.
--  Related: Constants/Gameplay.lua, Core/FreeLook/FreeLookController.lua,
--  Core/ClickCasting/BindingOverrides.lua, Core/Crosshair/Crosshair.lua,
--  Core/Crosshair/AssistedHighlight/{Keybinds,CastProgress,Feedback,Assist}.lua,
--  Core/PartyRadial/PartyRadial.lua, Core/Runtime/BindingQueue.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local select = _G.select

local eventCategoryMap = {}

-- Coalesce REFRESH_BINDINGS_EVENTS: one RefreshClickCastMacros after bursts.
local clickCastRefreshGen = 0
local clickCastRefreshReason = "bar" -- "cvar" | "bar"

local function DebugPrintClickCastRefreshReason()
  if clickCastRefreshReason == "cvar" then
    CM.DebugPrint("ActionButtonUseKeyDown changed, refreshing binding macros")
  else
    CM.DebugPrint("Action Bar state changed, refreshing binding macros")
  end
end

local function ScheduleClickCastBindingRefresh()
  if not C_Timer or not C_Timer.After then
    DebugPrintClickCastRefreshReason()
    CM.RefreshClickCastMacros()
    return
  end
  clickCastRefreshGen = clickCastRefreshGen + 1
  local myGen = clickCastRefreshGen
  C_Timer.After(0.1, function()
    if myGen ~= clickCastRefreshGen then
      return
    end
    DebugPrintClickCastRefreshReason()
    CM.RefreshClickCastMacros()
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
        if CM.FlushFocusCycleWheelBindingsIfDirty then
          CM.FlushFocusCycleWheelBindingsIfDirty()
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

      if event == "CVAR_UPDATE" then
        clickCastRefreshReason = "cvar"
      else
        clickCastRefreshReason = "bar"
      end
      ScheduleClickCastBindingRefresh()

      if event == "CVAR_UPDATE" then
        return
      end

      if CM.ApplyToggleFocusTargetBinding then
        CM.ApplyToggleFocusTargetBinding()
      end

      if CM.InvalidateAssistedHighlightKeybindCache then
        CM.InvalidateAssistedHighlightKeybindCache()
      end
      -- Party Radial: update slice targets and spell attributes when roster or action bar changes
      if not CM.PartyRadial then
        return
      end
      if event == "GROUP_ROSTER_UPDATE" and CM.PartyRadial.OnGroupRosterUpdate then
        CM.PartyRadial.OnGroupRosterUpdate()
      elseif CM.PartyRadial.OnActionBarChanged then
        CM.PartyRadial.OnActionBarChanged()
      end
    end,
    FOCUS_LOCK_EVENTS = function()
      CM.OnCrosshairFocusLockEvent(event)
      if CM.UpdateFocusCycleWheelBindings then
        CM.UpdateFocusCycleWheelBindings()
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
  for _, category in ipairs(categories) do
    HandleEventByCategory(category, event, ...)
  end
end
