---------------------------------------------------------------------------------------
--  Core/FreeLook/AutoCursorUnlock.lua — FREELOOK — unlock predicates
---------------------------------------------------------------------------------------
--  What it does: Answers whether the cursor should stay unlocked: watched frames,
--  wildcard groups (incl. OPie), vendor mounts, pet battle, feign death, and optional
--  customCondition loadstring. OPie visibility also notifies FreeLookController so
--  centering can rematch after the ring closes.
--  Architecture / how it works:
--    • IsUnlockFrameVisible — FramesToCheck + watchlist + wildcard tracking when
--      DB.global.frameWatching.
--    • InitializeWildcardFrameTracking — hooks/create listeners for dynamic names.
--    • IsVendorMountOut / IsInPetBattle / IsFeignDeathActive / IsCustomConditionTrue.
--    • OPie path may free centering + hide crosshair via FreeLook helpers.
--  Does not: Own Lock/Unlock or ShouldFreeLookBeOff aggregation.
--  Related: Constants/FrameWatch.lua, Core/FreeLook/FreeLookController.lua,
--  Core/Runtime/UserLuaCondition.lua, UI/Options/Tabs/TabAutoCursorUnlock.lua,
--  Core/Crosshair/Crosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetUIPanel = _G.GetUIPanel

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local string = _G.string
local tinsert = _G.table.insert

local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in ipairs(frameArr) do
    local curFrame = _G[frameName]
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      CM.DebugPrintThrottled("cursorUnlock", frameName .. " is visible, preventing re-locking.")
      return true
    end
  end

  return false
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for wildcardFrameName, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      if wildcardFrameName == "OPieRT" then
        -- OPie calls MouselookStop() itself, so UnlockFreeLook often no-ops (already
        -- stopped). Still hide the crosshair and free CursorFreelookCentering so the
        -- ring gets a usable cursor; FreeLookController latches this for a bounce rematch
        -- when the ring closes.
        if CM.NotifyOpieUnlockFrameVisible then
          CM.NotifyOpieUnlockFrameVisible()
        end
        if CM.IsCrosshairEnabled() then
          CM.DisplayCrosshair(false)
        end
        CM.SetCursorFreelookCentering(false)
      end
      return true
    end
  end

  return false
end

function CM.IsUnlockFrameVisible()
  if GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center") then
    return true
  end

  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck)
    or CursorUnlockFrameVisible(CM.DB.global.watchlist)
    or CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck)
end

-- Cache compiled custom-condition Lua; OnUpdate calls this often and empty/default
-- strings must not recompile every tick.
local customConditionCache = {}

function CM.IsCustomConditionTrue()
  return CM.EvaluateUserLuaCondition(
    CM.DB.global.customCondition,
    customConditionCache,
    "Invalid custom condition"
  )
end

function CM.IsVendorMountOut()
  local csv = CM.DB.global.mountsToUnlock
  if not csv or csv == "" then
    return false
  end

  for part in csv:gmatch("[^,]+") do
    local id = tonumber(part:match("^%s*(.-)%s*$"))
    if id and GetPlayerAuraBySpellID(id) then
      return true
    end
  end

  return false
end

function CM.IsFeignDeathActive()
  return GetPlayerAuraBySpellID(5384) ~= nil
end

function CM.IsInPetBattle()
  if ON_RETAIL_CLIENT then
    return _G.C_PetBattles.IsInBattle()
  end
  return false
end

function CM.InitializeWildcardFrameTracking(frameArr)
  CM.DebugPrint("Looking for wildcard frames...")

  for _, frameNameToFind in pairs(frameArr) do
    CM.Constants.WildcardFramesToCheck[frameNameToFind] = {}
    local frameGroup = CM.Constants.WildcardFramesToCheck[frameNameToFind]
    local staticCandidates = CM.Constants.WildcardFrameCandidates
      and CM.Constants.WildcardFrameCandidates[frameNameToFind]
    if staticCandidates then
      for _, candidateFrame in ipairs(staticCandidates) do
        if _G[candidateFrame] then
          CM.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. candidateFrame)
          tinsert(frameGroup, candidateFrame)
        end
      end
    end
    if #frameGroup == 0 then
      -- Fallback scan keeps compatibility for addons that generate runtime frame IDs.
      for frameName in pairs(_G) do
        if string.match(frameName, frameNameToFind) then
          CM.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
          tinsert(frameGroup, frameName)
        end
      end
    end
  end

  CM.DebugPrint("Wildcard frames initialized")
end
