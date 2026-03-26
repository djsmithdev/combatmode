---------------------------------------------------------------------------------------
--  Core/RuntimeEventRouter.lua — event map build + category dispatch
---------------------------------------------------------------------------------------
--  Owns Runtime event category map and global XML event handler wiring while keeping
--  public/global names stable.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

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
      if CM.HealingRadial then
        if event == "PLAYER_REGEN_DISABLED" and CM.HealingRadial.OnCombatStart then
          CM.HealingRadial.OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" and CM.HealingRadial.OnCombatEnd then
          CM.HealingRadial.OnCombatEnd()
        end
      end
      if event == "PLAYER_REGEN_ENABLED" then
        CM.FlushDeferredBindingChanges()
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
      -- Healing Radial: update slice targets and spell attributes when roster or action bar changes
      if not CM.HealingRadial then
        return
      end
      if event == "GROUP_ROSTER_UPDATE" and CM.HealingRadial.OnGroupRosterUpdate then
        CM.HealingRadial.OnGroupRosterUpdate()
      elseif CM.HealingRadial.OnActionBarChanged then
        CM.HealingRadial.OnActionBarChanged()
      end
    end,
    FOCUS_LOCK_EVENTS = function()
      CM.OnCrosshairFocusLockEvent(event)
    end,
  }

  if eventHandlers[category] then
    eventHandlers[category]()
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
function _G.CombatMode_OnEvent(event, ...)
  local categories = eventCategoryMap[event]
  if not categories then
    return
  end
  for _, category in ipairs(categories) do
    HandleEventByCategory(category, event, ...)
  end
end
