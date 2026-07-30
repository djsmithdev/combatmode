---------------------------------------------------------------------------------------
--  Core/Runtime/BindingQueue.lua — RUNTIME — combat-deferred binding applies
---------------------------------------------------------------------------------------
--  What it does: Queues binding/protected apply functions while InCombatLockdown and
--  flushes them when combat ends so click-cast / interact / party-radial keybind changes
--  never violate lockdown.
--  Architecture / how it works:
--    • TryApplyBindingChange(context, applyFn) — runs immediately out of combat; else
--      enqueues and prints a deferred notice.
--    • FlushDeferredBindingChanges — called from EventRouter on PLAYER_REGEN_ENABLED;
--      pcall each applyFn.
--  Does not: Build macros or call SetOverrideBinding itself (callers pass closures).
--  Related: Core/ClickCasting/BindingOverrides.lua, Core/Runtime/EventRouter.lua,
--  Core/Runtime/Bootstrap.lua, UI/Options/Tabs/TabGeneral.lua,
--  UI/Options/Tabs/TabClickCasting.lua, UI/Options/Tabs/TabPartyRadial.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local InCombatLockdown = _G.InCombatLockdown

-- Lua stdlib
local ipairs = _G.ipairs
local pcall = _G.pcall
local type = _G.type

local deferredBindingQueue = {}

function CM.TryApplyBindingChange(context, applyFn)
  if type(applyFn) ~= "function" then
    return false
  end

  if InCombatLockdown() then
    deferredBindingQueue[#deferredBindingQueue + 1] = {
      context = context or "binding change",
      applyFn = applyFn,
    }
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: deferred "
        .. (context or "binding change")
        .. " until combat ends.|r"
    )
    return false
  end

  local ok, err = pcall(applyFn)
  if not ok then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: failed to apply "
        .. (context or "binding change")
        .. ": "
        .. tostring(err)
        .. "|r"
    )
    return false
  end

  return true
end

function CM.FlushDeferredBindingChanges()
  if InCombatLockdown() then
    return
  end
  if #deferredBindingQueue == 0 then
    return
  end

  local pending = deferredBindingQueue
  deferredBindingQueue = {}

  for _, change in ipairs(pending) do
    CM.TryApplyBindingChange(change.context, change.applyFn)
  end

  print(CM.Constants.BasePrintMsg .. "|cff909090: applied deferred binding updates.|r")
end
