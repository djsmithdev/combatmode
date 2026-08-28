---------------------------------------------------------------------------------------
--  Core/Runtime/UserLuaCondition.lua — RUNTIME — cached user Lua condition evaluator
---------------------------------------------------------------------------------------
--  What it does: Compiles and runs user-authored Lua snippets from SavedVariables with
--  per-consumer cache (source string + compiled func). Used by Auto Unlock and crosshair
--  situational texture override.
--  Architecture / how it works:
--    • CM.EvaluateUserLuaCondition(source, cache, errorLabel) — empty source → false;
--      compile/runtime errors log via throttled CM.DebugPrintThrottled and return false.
--    • `cache` is a caller-owned table { source, func } reused across hot-path calls.
--  Does not: Own DB keys or feature-specific semantics (callers supply source strings).
--  Related: Core/FreeLook/AutoCursorUnlock.lua, Core/Crosshair/Crosshair.lua,
--  UI/Options/Tabs/TabAutoCursorUnlock.lua, UI/Options/Tabs/TabCrosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local loadstring = _G.loadstring
local pcall = _G.pcall
local tostring = _G.tostring

local function LogUserLuaConditionError(errorLabel, message)
  local label = errorLabel or "User condition"
  local throttleKey = label .. ":" .. message
  CM.DebugPrintThrottled(throttleKey, label .. ": " .. message, 10)
end

--- @param source string|nil User Lua; empty/nil → false.
--- @param cache table Caller-owned { source, func } for compile cache.
--- @param errorLabel string|nil Prefix for CM.DebugPrint on compile/runtime errors.
function CM.EvaluateUserLuaCondition(source, cache, errorLabel)
  if not source or source == "" then
    cache.source = source
    cache.func = nil
    return false
  end

  if source ~= cache.source then
    cache.source = source
    local func, err = loadstring(source)
    if not func then
      LogUserLuaConditionError(errorLabel, tostring(err))
      cache.func = nil
      return false
    end
    cache.func = func
  end

  if not cache.func then
    return false
  end

  local success, result = pcall(cache.func)
  if not success then
    LogUserLuaConditionError(errorLabel, tostring(result))
    return false
  end

  return result and true or false
end
