---------------------------------------------------------------------------------------
--  Core/Dev/FunctionProfiler.lua — DEV — per-function CPU + memory profiler
---------------------------------------------------------------------------------------
--  What it does: Thin wrapper around C_AddOnProfiler.MeasureCall (patch 11.1.7+).
--  Tracks cumulative per-call stats (calls, totalMs, minMs, maxMs, totalAllocB,
--  totalDeallocB) and prints a sorted summary when Debug Mode is toggled off.
--  Architecture / how it works:
--    • CM.Profile(key, func, ...) — wraps a single call and accumulates results.
--    • All profiling is gated by CM.profilingEnabled (toggled via Debug Mode toggle).
--    • When disabled, CM.Profile just calls func(...) with zero overhead.
--    • CM.StartProfiling / CM.StopAndReportProfiling — public API used by the
--      Debug Mode toggle in the options panel.
--    • CPU stats via C_AddOnProfiler.GetAddOnMetric for CombatMode (always-on).
--  Does not: Profile Blizzard APIs, profile memory on non-11.1.7 clients, or auto-start.
--  Related: Core/Runtime/Runtime.lua, C_AddOnProfiler.MeasureCall
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local C_AddOnProfiler = _G.C_AddOnProfiler
local table = _G.table
local string = _G.string
local math = _G.math
local tostring = _G.tostring
local pairs = _G.pairs
local pcall = _G.pcall
local print = _G.print

local HAS_MEASURE_CALL = C_AddOnProfiler and C_AddOnProfiler.MeasureCall
local HAS_GET_METRIC = C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric
local HAS_ADD_EVENT = C_AddOnProfiler and C_AddOnProfiler.AddMeasuredCallEvent

-- Gate: profiling is opt-in via Debug Mode toggle
CM.profilingEnabled = nil -- nil / false = off

-- Cumulative stats { calls=n, totalMs=n, minMs=n, maxMs=n, totalAllocB=n, totalDeallocB=n }
local profileData = {}

local function ResetProfileData()
  for k in pairs(profileData) do
    profileData[k] = nil
  end
end

--- Profile one function call. Returns the function's return values.
--- When profiling is off, calls func(...) directly with no overhead.
function CM.Profile(key, func, ...)
  if CM.profilingEnabled and HAS_MEASURE_CALL then
    local results, ok, r1, r2, r3, r4

    -- pcall inside MeasureCall so profiling errors don't break the addon
    ok, results, r1, r2, r3, r4 = pcall(C_AddOnProfiler.MeasureCall, func, ...)
    if not ok then
      -- MeasureCall itself errored (e.g. func is nil) — fall through to direct call
      return func(...)
    end

    if results then
      local entry = profileData[key]
      if not entry then
        entry =
          { calls = 0, totalMs = 0, minMs = nil, maxMs = nil, totalAllocB = 0, totalDeallocB = 0 }
        profileData[key] = entry
      end
      entry.calls = entry.calls + 1
      local ms = results.elapsedMilliseconds or 0
      entry.totalMs = entry.totalMs + ms
      entry.totalAllocB = entry.totalAllocB + (results.allocatedBytes or 0)
      entry.totalDeallocB = entry.totalDeallocB + (results.deallocatedBytes or 0)
      if entry.minMs == nil or ms < entry.minMs then
        entry.minMs = ms
      end
      if entry.maxMs == nil or ms > entry.maxMs then
        entry.maxMs = ms
      end
    end
    return r1, r2, r3, r4
  end
  return func(...)
end

--- Mark a named waypoint within the current MeasureCall (for sub-event profiling).
function CM.ProfileEvent(name)
  if CM.profilingEnabled and HAS_ADD_EVENT then
    pcall(C_AddOnProfiler.AddMeasuredCallEvent, name)
  end
end

local function SortByTotalMs(a, b)
  return (profileData[a].totalMs or 0) > (profileData[b].totalMs or 0)
end

local function PrintProfileReport()
  if not CM.profilingEnabled then
    print(CM.Constants.BasePrintMsg .. " Profiling is off. Toggle Debug Mode on to start.")
    return
  end
  local keys = {}
  for k in pairs(profileData) do
    keys[#keys + 1] = k
  end
  table.sort(keys, SortByTotalMs)

  print(CM.Constants.BasePrintMsg .. " |cffE0B847--- Profile Report ---|r")
  print(
    CM.Constants.BasePrintMsg
      .. " |cff909090Key                 Calls   Total(ms)  Avg(ms)   Min(ms)   Max(ms)   Alloc(B)   Dealloc(B)|r"
  )
  for _, key in ipairs(keys) do
    local d = profileData[key]
    local avg = d.calls > 0 and string.format("%.4f", d.totalMs / d.calls) or "-"
    print(
      string.format(
        "%s %-18s %6d  %8.4f  %8s  %8.4f  %8.4f  %9d  %9d",
        CM.Constants.BasePrintMsg,
        key,
        d.calls,
        d.totalMs,
        avg,
        d.minMs or 0,
        d.maxMs or 0,
        d.totalAllocB,
        d.totalDeallocB
      )
    )
  end
  print(CM.Constants.BasePrintMsg .. " |cffE0B847--- End Report ---|r")
end

local AddOnProfilerMetric = {
  SessionAverageTime = 0,
  RecentAverageTime = 1,
  EncounterAverageTime = 2,
  LastTime = 3,
  PeakTime = 4,
  CountTimeOver1Ms = 5,
  CountTimeOver5Ms = 6,
  CountTimeOver10Ms = 7,
  CountTimeOver50Ms = 8,
  CountTimeOver100Ms = 9,
  CountTimeOver500Ms = 10,
  CountTimeOver1000Ms = 11,
}

local function PrintCPUStats()
  local lines = {}
  lines[#lines + 1] = CM.Constants.BasePrintMsg .. " |cffE0B847CombatMode CPU Stats|r"
  if not HAS_GET_METRIC then
    lines[#lines + 1] = CM.Constants.BasePrintMsg
      .. " C_AddOnProfiler.GetAddOnMetric not available (pre-11.0.7 client?)"
    for _, line in ipairs(lines) do
      print(line)
    end
    return
  end

  for label, metric in pairs(AddOnProfilerMetric) do
    local ok, val = pcall(C_AddOnProfiler.GetAddOnMetric, "CombatMode", metric)
    if ok and val ~= nil then
      if label:find("^Count") then
        lines[#lines + 1] =
          string.format("%s %-30s %s", CM.Constants.BasePrintMsg, label, tostring(math.floor(val)))
      else
        lines[#lines + 1] = string.format("%s %-30s %.4f ms", CM.Constants.BasePrintMsg, label, val)
      end
    end
  end

  -- Also print overall metrics (sum across all addons) for comparison
  if C_AddOnProfiler.GetOverallMetric then
    local ok, overall =
      pcall(C_AddOnProfiler.GetOverallMetric, AddOnProfilerMetric.RecentAverageTime)
    if ok and overall ~= nil then
      lines[#lines + 1] = string.format(
        "%s %-30s %.4f ms",
        CM.Constants.BasePrintMsg,
        "All-Addons RecentAverage",
        overall
      )
    end
  end

  for _, line in ipairs(lines) do
    print(line)
  end
end

function CM.StartProfiling()
  CM.profilingEnabled = true
  ResetProfileData()
  print(
    CM.Constants.BasePrintMsg
      .. " Profiling |cff00ff00ON|r. Toggle Debug Mode off to stop and report."
  )
end

function CM.StopAndReportProfiling()
  PrintProfileReport()
  PrintCPUStats()
  ResetProfileData()
  CM.profilingEnabled = nil
  print(CM.Constants.BasePrintMsg .. " Profiling |cffff4444OFF|r.")
end
