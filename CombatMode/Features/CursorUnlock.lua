---------------------------------------------------------------------------------------
--  Features/CursorUnlock.lua — CURSOR UNLOCK — auto-drop mouselook (panels, Lua)
---------------------------------------------------------------------------------------
--  Supplies CM.IsUnlockFrameVisible (static + wildcard frame name matching),
--  vendor/mount/pet-battle/feign checks, and CM.IsCustomConditionTrue for optional
--  user Lua. Core.ShouldFreeLookBeOff() combines these with spell targeting,
--  cinematics, healing radial, etc., so the global OnUpdate can call UnlockFreeLook.
--
--  Architecture:
--    • CM.InitializeWildcardFrameTracking called once from Core bootstrap; uses
--      Constants.WildcardFramesToMatch / FramesToCheck.
--    • Read-only queries from Core; no direct mouselook Start/Stop here.
--    • Retail-only LibEditMode usage where applicable (layout sync hooks).

local _G = _G
local LibStub = _G.LibStub
local GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetUIPanel = _G.GetUIPanel
local ipairs = _G.ipairs
local loadstring = _G.loadstring
local pairs = _G.pairs
local pcall = _G.pcall
local string = _G.string

local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G[frameName]
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      CM.DebugPrintThrottled("cursorUnlock", frameName .. " is visible, preventing re-locking.")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for wildcardFrameName, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      if wildcardFrameName == "OPieRT" then
        if CM.DB.global.crosshair then
          CM.DisplayCrosshair(false)
        end
        CM.SetCursorFreelookCentering(false)
      end
      return true
    end
  end
end

function CM.IsUnlockFrameVisible()
  local isGenericPanelOpen = (GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center")) and true or false
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

function CM.IsCustomConditionTrue()
  if not CM.DB.global.customCondition then
    return false
  end

  local func, err = loadstring(CM.DB.global.customCondition)

  if not func then
    CM.DebugPrint("Invalid custom condition " .. err)
    return false
  end

  local success, result = pcall(func)

  if not success then
    CM.DebugPrint("Error executing custom condition: " .. result)
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

    for frameName in pairs(_G) do
      if string.match(frameName, frameNameToFind) then
        CM.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
        local frameGroup = CM.Constants.WildcardFramesToCheck[frameNameToFind]
        frameGroup[#frameGroup + 1] = frameName
      end
    end
  end

  CM.DebugPrint("Wildcard frames initialized")
end
