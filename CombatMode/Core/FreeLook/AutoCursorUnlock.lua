---------------------------------------------------------------------------------------
--  Core/FreeLook/AutoCursorUnlock.lua — FREE LOOK — auto-drop mouselook (panels, Lua)
---------------------------------------------------------------------------------------
--  Supplies CM.IsUnlockFrameVisible (static + wildcard frame name matching),
--  vendor/mount/pet-battle/feign checks, and CM.IsCustomConditionTrue for optional
--  user Lua. FreeLookController.ShouldFreeLookBeOff() combines these with spell targeting,
--  cinematics, healing radial, etc., so the global OnUpdate can call UnlockFreeLook.
--
--  Architecture:
--    • CM.InitializeWildcardFrameTracking called once from Runtime bootstrap; uses
--      Constants/FrameWatch.lua (WildcardFramesToMatch / FramesToCheck).
--    • Read-only queries from FreeLook; no direct mouselook Start/Stop here (except
--      the OPie branch frees CursorFreelookCentering + hides the crosshair).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetUIPanel = _G.GetUIPanel
local loadstring = _G.loadstring
local tinsert = _G.table.insert

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local string = _G.string

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
local cachedCustomConditionSource
local cachedCustomConditionFunc

function CM.IsCustomConditionTrue()
  local source = CM.DB.global.customCondition
  if not source or source == "" then
    cachedCustomConditionSource = source
    cachedCustomConditionFunc = nil
    return false
  end

  if source ~= cachedCustomConditionSource then
    cachedCustomConditionSource = source
    local func, err = loadstring(source)
    if not func then
      CM.DebugPrint("Invalid custom condition " .. tostring(err))
      cachedCustomConditionFunc = nil
      return false
    end
    cachedCustomConditionFunc = func
  end

  if not cachedCustomConditionFunc then
    return false
  end

  local success, result = pcall(cachedCustomConditionFunc)

  if not success then
    CM.DebugPrint("Error executing custom condition: " .. tostring(result))
    return false
  end

  return result
end

function CM.IsVendorMountOut()
  if not CM.DB.global.mountCheck then
    return false
  end

  local function checkMount(mount)
    return GetPlayerAuraBySpellID(mount) ~= nil
  end

  for _, mount in ipairs(CM.Constants.MountsToCheck) do
    if checkMount(mount) then
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
