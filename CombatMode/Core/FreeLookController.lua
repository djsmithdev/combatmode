---------------------------------------------------------------------------------------
--  Core/FreeLookController.lua — FREE LOOK — mouselook state machine + cursor keybind
---------------------------------------------------------------------------------------
--  Owns free-look/mouselook transition behavior:
--    • lock/unlock transitions and UI side effects
--    • temporary/permanent unlock handling
--    • cursor-mode keybind tap/hold logic with spurious key-up filtering
--    • free-look gating checks consumed by Runtime OnUpdate
--
--  Runtime remains the coordinator and calls exported CM helpers from this module.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local C_Timer = _G.C_Timer
local GameTooltip = _G.GameTooltip
local GetTime = _G.GetTime
local InCinematic = _G.InCinematic
local IsInCinematicScene = _G.IsInCinematicScene
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local SpellIsTargeting = _G.SpellIsTargeting

-- Lua stdlib
local string = _G.string

-- INITIAL STATE VARIABLES
local FreeLookOverride = false -- Changes when Free Look state is modified through user input ("Toggle / Hold" keybind and "/cm" cmd)
local CursorModeShowTime = 0 -- GetTime() when cursor was unlocked via keybind (for spurious key-up filter)

-- This prevents the auto running bug.
function CM.IsDefaultMouseActionBeingUsed()
  return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end

local tooltipHidden = false
local isTooltipHooked = false
local function HideTooltip(shouldHide)
  tooltipHidden = shouldHide

  if not isTooltipHooked then
    GameTooltip:HookScript("OnShow", function(self)
      if tooltipHidden then
        self:Hide()
      end
    end)
    isTooltipHooked = true
  end
  -- Hide it immediately in case there's a tooltip still fading while mouse locking
  if tooltipHidden and GameTooltip:IsShown() then
    GameTooltip:Hide()
  end
end

local function IsHealingRadialActive()
  return CM.HealingRadial and CM.HealingRadial.IsActive and CM.HealingRadial.IsActive()
end

function CM.ShouldFreeLookBeOff()
  return CM.IsCustomConditionTrue()
    or (
      FreeLookOverride
      or SpellIsTargeting()
      or InCinematic()
      or IsInCinematicScene()
      or CM.IsUnlockFrameVisible()
      or CM.IsVendorMountOut()
      or CM.IsInPetBattle()
      or CM.IsFeignDeathActive()
      or IsHealingRadialActive()
    )
end

-- Helper function to handle UI state changes when toggling free look
local function HandleFreeLookUIState(isLocking, isPermanentUnlock)
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(isLocking)
  end

  if CM.DB.global.hideTooltip then
    HideTooltip(isLocking)
  end

  -- Only reset Action Camera settings on permanent unlocks (user-initiated), not temporary ones (UI panels)
  if CM.DB.global.actionCamera and CM.DB.global.actionCamMouselookDisable then
    if isLocking or (not isLocking and isPermanentUnlock) then
      CM.ConfigActionCamera(isLocking and "combatmode" or "blizzard")
    end
  end

  if CM.IsCrosshairEnabled() and CM.DB.char.stickyCrosshair then
    CM.ConfigStickyCrosshair(isLocking and "combatmode" or "blizzard")
  end
end

function CM.SetCursorFreelookCentering(shouldCenter)
  -- Edit Mode crosshair drives aligned cursor (CursorFreelookCentering + CursorCenteredYPos in Crosshair).
  local useCrosshairCursor = shouldCenter and CM.IsCrosshairEnabled()
  if useCrosshairCursor then
    CM.SetCursorFreelookCenteringCVar(true)
    CM.DebugPrint("Locking cursor to crosshair position.")
  else
    CM.SetCursorFreelookCenteringCVar(false)
    CM.DebugPrint("Freeing cursor from crosshair position.")
  end
end

function CM.LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    -- Defer UI state changes to avoid taint during protected mouselook initialization
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        CM.SetCursorFreelookCentering(true)
        HandleFreeLookUIState(true, false)
      end)
    else
      CM.SetCursorFreelookCentering(true)
      HandleFreeLookUIState(true, false)
    end
    CM.ShowCrosshairLockIn()
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(true)
    end
    CM.DebugPrint("Free Look Enabled")
  end
end

local function RunUnlockFreeLookDeferredUI(isPermanentUnlock)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      CM.SetCursorFreelookCentering(false)
      HandleFreeLookUIState(false, isPermanentUnlock)
    end)
  else
    CM.SetCursorFreelookCentering(false)
    HandleFreeLookUIState(false, isPermanentUnlock)
  end
end

function CM.UnlockFreeLook()
  if not IsMouselooking() then
    return
  end
  RunUnlockFreeLookDeferredUI(false)
  MouselookStop()

  if CM.DB.global.pulseCursor then
    CM.ShowCursorPulse()
  end

  if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
    CM.HealingRadial.OnMouselookChanged(false)
  end
  CM.DebugPrint("Free Look Disabled")
end

local function UnlockFreeLookPermanent()
  if not IsMouselooking() then
    return
  end
  RunUnlockFreeLookDeferredUI(true)
  MouselookStop()

  if CM.DB.global.pulseCursor then
    CM.ShowCursorPulse()
  end

  if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
    CM.HealingRadial.OnMouselookChanged(false)
  end
  CM.DebugPrint("Free Look Disabled (Permanent)")
end

-- Unified cursor mode keybind: tap to toggle, hold to temporarily unlock.
-- Uses the same spurious key-up filter as the Healing Radial keybind.
-- MouselookStop() fires spurious key-up events for held keys, so we ignore
-- key-ups within 0.3s of unlocking. A quick tap leaves the cursor free (toggle);
-- holding longer than 0.3s re-locks on release (hold).
function _G.CombatMode_CursorModeKey(keystate)
  if CM.IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  if keystate == "down" then
    if not IsMouselooking() and FreeLookOverride then
      -- Already unlocked via previous tap — re-lock (toggle off)
      CM.LockFreeLook()
      FreeLookOverride = false
      CursorModeShowTime = 0 -- No spurious filter needed for lock
    elseif IsMouselooking() then
      -- Currently mouselooking — unlock cursor
      CursorModeShowTime = GetTime()
      UnlockFreeLookPermanent()
      FreeLookOverride = true
    end
  elseif keystate == "up" then
    if not FreeLookOverride then
      -- Already re-locked on key-down (toggle-off case), nothing to do
      return
    end
    -- Ignore spurious key-ups from MouselookStop (within 0.3s)
    local elapsed = GetTime() - CursorModeShowTime
    if elapsed < 0.3 then
      CM.DebugPrint(
        "Cursor Mode: Ignoring spurious key-up (elapsed=" .. string.format("%.3f", elapsed) .. "s)"
      )
      return
    end
    -- Hold release: re-lock mouselook
    CM.LockFreeLook()
    FreeLookOverride = false
  end
end
