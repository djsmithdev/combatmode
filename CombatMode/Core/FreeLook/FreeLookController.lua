---------------------------------------------------------------------------------------
--  Core/FreeLook/FreeLookController.lua — FREELOOK — mouselook state machine
---------------------------------------------------------------------------------------
--  What it does: Owns Mouse Look lock/unlock, cursor-mode keybind behavior,
--  ShouldFreeLookBeOff aggregation, CursorFreelookCentering bounce
--  (force CVar 0 → MouselookStart → deferred set to 1), tooltip hide while locked,
--  optional sheath-with-mouselook (intentional toggle only), and the OPie rematch
--  latch (NotifyOpieUnlockFrameVisible / RematchFreeLookAfterOpieIfNeeded).
--  Architecture / how it works:
--    • LockFreeLook / UnlockFreeLook drive MouselookStart/Stop + crosshair display +
--      centering helpers via CVarManager.
--    • StartFreeLookFresh forces centering off, starts mouselook, then deferred
--      SetCursorFreelookCentering(true) so the cursor recenters reliably.
--    • ShouldFreeLookBeOff consults AutoCursorUnlock predicates, SpellIsTargeting,
--      cinematics, FreeLookOverride, default LMB/RMB held.
--    • SheathWeaponsWithMouselook: unsheath on intentional Mouse Look; sheath on
--      tap unlock (poll detects binding release) and Auto Cursor Unlock. Hold
--      never sheaths. Party Radial, ground targeting, and OPie keep weapons drawn.
--      Sheath requests are debounced (~1.5s) so rapid Mouse Look toggle does not
--      flash sheath/unsheath; unsheath and re-lock cancel any pending sheath.
--    • OPie: when a ring is visible, unlock path may free centering; Rematch after
--      the ring closes re-bounces freelook if still desired.
--  Does not: Own frame-watch lists/predicates (AutoCursorUnlock) or CVar preset tables.
--  Related: Core/FreeLook/AutoCursorUnlock.lua, Core/Runtime/CVarManager.lua,
--  Core/Runtime/Runtime.lua, Core/PartyRadial/PartyRadial.lua,
--  Core/Crosshair/Animations.lua, Core/Crosshair/Crosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local GameTooltip = _G.GameTooltip
local GetBindingKey = _G.GetBindingKey
local GetSheathState = _G.GetSheathState
local GetTime = _G.GetTime
local InCinematic = _G.InCinematic
local IsInCinematicScene = _G.IsInCinematicScene
local IsKeyDown = _G.IsKeyDown
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local SpellIsTargeting = _G.SpellIsTargeting
local ToggleSheath = _G.ToggleSheath

-- Lua stdlib
local string = _G.string

-- INITIAL STATE VARIABLES
local FreeLookOverride = false -- Changes when Free Look state is modified through user input ("Toggle / Hold" keybind and "/cm" cmd)
local CursorModeShowTime = 0 -- GetTime() when cursor was unlocked via keybind (for spurious key-up filter)
local opieUnlockSeen = false -- Latched while an OPie ring was reported visible
local pendingTapSheath = false -- True until tap sheath is applied or hold is confirmed
local pendingSheathToken = 0 -- Bumped to cancel a scheduled sheath debounce
local SHEATH_STATE_SHEATHED = 1
local MOUSE_LOOK_BINDING = "Combat Mode - Mouse Look"
local CURSOR_MODE_HOLD_THRESHOLD = 0.3
local CURSOR_MODE_SPURIOUS_KEY_UP = 0.05
local CURSOR_MODE_SHEATH_POLL = 0.05
-- Delay sheath-on so quick Mouse Look re-entry (e.g. pull → click → lock) does not flash.
local SHEATH_DEBOUNCE_SEC = 1.5
local MOUSE_BINDING_BUTTON = {
  BUTTON1 = "LeftButton",
  BUTTON2 = "RightButton",
  BUTTON3 = "MiddleButton",
  BUTTON4 = "Button4",
  BUTTON5 = "Button5",
}

local function IsPartyRadialActive()
  return CM.PartyRadial and CM.PartyRadial.IsActive and CM.PartyRadial.IsActive()
end

local function CancelPendingSheath()
  pendingSheathToken = pendingSheathToken + 1
end

-- Immediate idempotent ToggleSheath when the option is on (no debounce).
local function ApplyWeaponsSheathedNow(wantSheathed)
  if not (CM.DB and CM.DB.global and CM.DB.global.sheathWeaponsWithMouselook) then
    return
  end
  if not (GetSheathState and ToggleSheath) then
    return
  end
  local state = GetSheathState()
  if not state then
    return
  end
  local isSheathed = state == SHEATH_STATE_SHEATHED
  if wantSheathed == isSheathed then
    return
  end
  ToggleSheath()
end

-- Unsheath immediately; sheath after SHEATH_DEBOUNCE_SEC (cancelledable by unsheath/re-lock).
local function ApplyWeaponsSheathed(wantSheathed)
  if not wantSheathed then
    CancelPendingSheath()
    ApplyWeaponsSheathedNow(false)
    return
  end
  if not (CM.DB and CM.DB.global and CM.DB.global.sheathWeaponsWithMouselook) then
    return
  end
  CancelPendingSheath()
  local token = pendingSheathToken
  if not (C_Timer and C_Timer.After) then
    ApplyWeaponsSheathedNow(true)
    return
  end
  C_Timer.After(SHEATH_DEBOUNCE_SEC, function()
    if token ~= pendingSheathToken then
      return
    end
    ApplyWeaponsSheathedNow(true)
  end)
end

-- Temporary gameplay unlocks keep weapons drawn; Auto Cursor Unlock / etc. may sheath.
local function ShouldKeepWeaponsDrawnOnTempUnlock()
  if FreeLookOverride then
    return true
  end
  if IsPartyRadialActive() then
    return true
  end
  if SpellIsTargeting() then
    return true
  end
  -- Set by AutoCursorUnlock while an OPie ring is visible (before UnlockFreeLook).
  if opieUnlockSeen then
    return true
  end
  return false
end

local function IsMouseLookBindingKeyDown()
  if not GetBindingKey then
    return false
  end
  local key1, key2 = GetBindingKey(MOUSE_LOOK_BINDING)
  for i = 1, 2 do
    local key = (i == 1) and key1 or key2
    if key then
      if IsKeyDown and IsKeyDown(key) then
        return true
      end
      local mouseButton = MOUSE_BINDING_BUTTON[key]
      if mouseButton and IsMouseButtonDown(mouseButton) then
        return true
      end
    end
  end
  return false
end

local function CancelPendingTapSheath()
  pendingTapSheath = false
  CancelPendingSheath()
end

-- Never sheath on unlock press (hold would flash). Poll until the binding is up
-- (tap → sheath) or the hold threshold elapses while still down (hold → no sheath).
local function ScheduleTapSheathPoll()
  pendingTapSheath = true
  if not (C_Timer and C_Timer.After) then
    pendingTapSheath = false
    return
  end

  local function poll()
    if not pendingTapSheath then
      return
    end
    if not FreeLookOverride then
      pendingTapSheath = false
      return
    end

    local elapsed = GetTime() - CursorModeShowTime
    if IsMouseLookBindingKeyDown() then
      if elapsed >= CURSOR_MODE_HOLD_THRESHOLD then
        -- Hold confirmed: keep weapons drawn.
        pendingTapSheath = false
        return
      end
      C_Timer.After(CURSOR_MODE_SHEATH_POLL, poll)
      return
    end

    -- Key/button released. Ignore the near-instant MouselookStop spurious window.
    if elapsed < CURSOR_MODE_SPURIOUS_KEY_UP then
      C_Timer.After(CURSOR_MODE_SHEATH_POLL, poll)
      return
    end

    pendingTapSheath = false
    ApplyWeaponsSheathed(true)
  end

  C_Timer.After(CURSOR_MODE_SPURIOUS_KEY_UP, poll)
end

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
      or IsPartyRadialActive()
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
  -- When enabled, freelook centers the cursor on the crosshair (CursorFreelookCentering +
  -- CursorCenteredYPos applied in Crosshair).
  local useCrosshairCursor = shouldCenter and CM.IsCrosshairEnabled()
  if useCrosshairCursor then
    CM.SetCursorFreelookCenteringCVar(true)
    CM.DebugPrint("Locking cursor to crosshair position.")
  else
    CM.SetCursorFreelookCenteringCVar(false)
    CM.DebugPrint("Freeing cursor from crosshair position.")
  end
end

local function RunLockFreeLookDeferredUI()
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      CM.SetCursorFreelookCentering(true)
      HandleFreeLookUIState(true, false)
    end)
  else
    CM.SetCursorFreelookCentering(true)
    HandleFreeLookUIState(true, false)
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

-- Force CursorFreelookCentering to 0, then MouselookStart, then deferred set to 1.
-- Required by the 10.2 Blizzard quirk (see Constants/CVars.lua): starting mouselook while
-- the CVar is already 1 (or writing 1 mid-look) can leave the cursor visible.
local function StartFreeLookFresh()
  CM.SetCursorFreelookCenteringCVar(false)
  MouselookStart()
  RunLockFreeLookDeferredUI()
  CM.ShowCrosshairLockIn()
  if CM.PartyRadial and CM.PartyRadial.OnMouselookChanged then
    CM.PartyRadial.OnMouselookChanged(true)
  end
  CM.DebugPrint("Free Look Enabled")
end

function CM.LockFreeLook()
  if IsMouselooking() then
    return
  end
  StartFreeLookFresh()
  -- Returning to intentional Mouse Look (e.g. after Auto Cursor Unlock).
  if not FreeLookOverride then
    ApplyWeaponsSheathed(false)
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

  if CM.PartyRadial and CM.PartyRadial.OnMouselookChanged then
    CM.PartyRadial.OnMouselookChanged(false)
  end

  -- Auto Cursor Unlock / mount / pet battle / etc. sheath; hold/radial/ground/OPie do not.
  if not ShouldKeepWeaponsDrawnOnTempUnlock() then
    ApplyWeaponsSheathed(true)
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

  if CM.PartyRadial and CM.PartyRadial.OnMouselookChanged then
    CM.PartyRadial.OnMouselookChanged(false)
  end
  CM.DebugPrint("Free Look Disabled (Permanent)")
end

-- Called from AutoCursorUnlock while an OPie ring frame is visible.
function CM.NotifyOpieUnlockFrameVisible()
  opieUnlockSeen = true
end

-- After freelook should be on again: if an OPie ring had forced centering off (and may
-- have rematched mouselook itself), bounce so StartFreeLookFresh can apply centering.
function CM.RematchFreeLookAfterOpieIfNeeded()
  if not opieUnlockSeen then
    return false
  end
  opieUnlockSeen = false

  CM.DebugPrint("OPie ring closed — bouncing free-look rematch.")
  if IsMouselooking() then
    MouselookStop()
  end
  StartFreeLookFresh()
  return true
end

-- Unified cursor mode keybind: tap to toggle, hold to temporarily unlock.
-- Uses the same spurious key-up filter as the Party Radial keybind.
-- MouselookStop() fires spurious key-up events for held keys, so we ignore
-- key-ups within 0.3s of unlocking. A quick tap leaves the cursor free (toggle);
-- holding longer than 0.3s re-locks on release (hold).
-- Sheath polls the binding: tap sheaths after release; hold never sheaths.
function _G.CombatMode_CursorModeKey(keystate)
  if CM.IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  if keystate == "down" then
    if not IsMouselooking() and FreeLookOverride then
      -- Already unlocked via previous tap — re-lock (toggle off)
      CancelPendingTapSheath()
      CM.LockFreeLook()
      FreeLookOverride = false
      CursorModeShowTime = 0 -- No spurious filter needed for lock
      ApplyWeaponsSheathed(false)
    elseif IsMouselooking() then
      -- Currently mouselooking — unlock cursor (tap or hold; sheath only if tap)
      CursorModeShowTime = GetTime()
      UnlockFreeLookPermanent()
      FreeLookOverride = true
      ScheduleTapSheathPoll()
    end
  elseif keystate == "up" then
    if not FreeLookOverride then
      -- Already re-locked on key-down (toggle-off case), nothing to do
      return
    end
    -- Ignore spurious key-ups from MouselookStop (within 0.3s)
    local elapsed = GetTime() - CursorModeShowTime
    if elapsed < CURSOR_MODE_HOLD_THRESHOLD then
      CM.DebugPrint(
        "Cursor Mode: Ignoring spurious key-up (elapsed=" .. string.format("%.3f", elapsed) .. "s)"
      )
      return
    end
    -- Hold release: re-lock mouselook; do not sheath
    CancelPendingTapSheath()
    CM.LockFreeLook()
    FreeLookOverride = false
  end
end
