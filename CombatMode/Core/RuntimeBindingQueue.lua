---------------------------------------------------------------------------------------
--  Core/RuntimeBindingQueue.lua — deferred binding queue (combat-safe apply)
---------------------------------------------------------------------------------------
--  Owns deferred binding writes used while in combat lockdown and exposes shared
--  CM helpers used by config modules and runtime bootstrap.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

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
