---------------------------------------------------------------------------------------
--  Core/PartyRadial/Lifecycle.lua — PARTYRADIAL — show/hide, fade, preview, freelook
---------------------------------------------------------------------------------------
--  What it does: Owns freelook dismiss hooks, mainFrame alpha fade, mouse tracking,
--  Show/Hide/ShowFromKeybind/HideFromKeybind, and options layout preview.
--  Architecture / how it works:
--    • CM.PartyRadialLifecycle: OnMouselookChanged, DismissOnLoad, SetCaptureActive,
--      Show/Hide/ExecuteAndHide, keybind open/close, IsActive/IsEnabled,
--      SetOptionsPreview / IsOptionsPreviewActive.
--    • OnUpdate calls HealthBars.UpdateAllHealthBarGlowPulses; layout/fade durations from
--      CM.Constants.PartyRadialLayout; geometry helpers via Visual.
--  Does not: Own frame creation, secure attributes, or roster build internals.
--  Related: Core/PartyRadial/Visual.lua, HealthBars.lua, RoleIcons.lua, PartyData.lua,
--  Core/FreeLook/FreeLookController.lua, UI/Options/Tabs/TabPartyRadial.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local InCombatLockdown = _G.InCombatLockdown
local debugstack = _G.debugstack

-- Lua stdlib
local math = _G.math
local string = _G.string
local tostring = _G.tostring

local HR = CM.PartyRadial
local PartyData = CM.PartyRadialPartyData
local HealthBars = CM.PartyRadialHealthBars
local RoleIcons = CM.PartyRadialRoleIcons
local Visual = CM.PartyRadialVisual
local Lifecycle = {}
CM.PartyRadialLifecycle = Lifecycle

local function GetState()
  return HR.GetState()
end

local RefreshPartyData = PartyData.RefreshPartyData
local BuildPreviewPartyData = PartyData.BuildPreviewPartyData
local UpdateAllHealthBarGlowPulses = HealthBars.UpdateAllHealthBarGlowPulses
local ResetHealthBarAnimState = HealthBars.ResetHealthBarAnimState
local RequestPartySpecInspects = RoleIcons.RequestPartySpecInspects
local SetSliceMouseEnabled = Visual.SetSliceMouseEnabled
local GetMouseAngleAndDistanceFromCenter = Visual.GetMouseAngleAndDistanceFromCenter
local GetSliceFromAngle = Visual.GetSliceFromAngle
local UpdateAllSlices = Visual.UpdateAllSlices
local HighlightSlice = Visual.HighlightSlice
local SLICE_RADIUS = CM.Constants.PartyRadialLayout.sliceRadius
local BASE_SLICE_SIZE = CM.Constants.PartyRadialLayout.baseSliceSize
local FADE_IN_DURATION = CM.Constants.PartyRadialLayout.fadeInDuration
local FADE_OUT_DURATION = CM.Constants.PartyRadialLayout.fadeOutDuration
local SLICE_SCALE_DURATION = CM.Constants.PartyRadialLayout.sliceScaleDuration

-- Forward declarations for mutual local calls
local Hide, SetOptionsPreview, IsEnabled, Show, ExecuteAndHide
local ShowFromKeybind, HideFromKeybind, IsActive, IsOptionsPreviewActive
local OnMouselookChanged, DismissOnLoad, SetCaptureActive
local StartOptionsPreviewVisuals, StopOptionsPreviewVisuals

OnMouselookChanged = function(isMouselooking)
  -- Dismiss radial if mouselook activates while radial is open
  -- This prevents the radial from staying open when user toggles mouselook via regular keybind
  CM.DebugPrint(
    "Party Radial: OnMouselookChanged("
      .. tostring(isMouselooking)
      .. ") active="
      .. tostring(GetState().isActive)
      .. " btn="
      .. tostring(GetState().currentButton)
      .. " toggling="
      .. tostring(GetState().isTogglingMouselook)
  )

  -- Skip if the radial itself is toggling mouselook (Show calling UnlockFreeLook,
  -- or Hide calling LockFreeLook). Without this guard, Show() sets isActive=true
  -- then calls UnlockFreeLook() which fires OnMouselookChanged(false), which sees
  -- isActive + currentButton and immediately calls Hide() — closing the radial
  -- before it ever displays.
  if GetState().isTogglingMouselook then
    return
  end

  if GetState().isActive then
    -- Hide when mouselook is reactivated externally, or when it was opened via mouse
    -- button and mouselook is dropped externally. For keybind-opened radial
    -- (currentButton == nil), lifecycle is managed by the keybind handler.
    if isMouselooking or GetState().currentButton then
      Hide()
    end
  end
end

-- Clear radial state after loading screen / zone change so IsPartyRadialActive() is false
-- and crosshair visibility can sync correctly. Does not re-engage mouselook or touch crosshair.
DismissOnLoad = function()
  if GetState().optionsPreviewActive then
    SetOptionsPreview(false)
  end
  if not GetState().isActive then
    if GetState().mainFrame then
      GetState().fadeMode = nil
      GetState().mainFrame:SetScript("OnUpdate", nil)
      GetState().mainFrame:SetAlpha(0)
    end
    return
  end
  if GetState().mainFrame then
    GetState().fadeMode = nil
    GetState().mainFrame:SetScript("OnUpdate", nil)
    GetState().mainFrame:SetAlpha(0)
  end
  SetSliceMouseEnabled(false)
  GetState().isActive = false
  GetState().selectedSlice = nil
  GetState().currentButton = nil
  GetState().boundKey = nil
end

-- Toggle the party radial system (called when enabled/disabled in settings).
-- When enabling/disabling, the config setter forces ReloadUI() so the frame is created
-- or not in HR.Initialize(); this is only for any other callers that need to dismiss the radial.
SetCaptureActive = function(active)
  if not active and GetState().isActive then
    Hide()
  end
  if active then
    CM.DebugPrint("Party Radial: Activated")
  else
    CM.DebugPrint("Party Radial: Deactivated")
  end
end

local function PreviewOnUpdate(_, elapsed)
  UpdateAllHealthBarGlowPulses(elapsed)
  GetState().sliceRefreshElapsed = (GetState().sliceRefreshElapsed or 0) + elapsed
  if GetState().sliceRefreshElapsed >= (GetState().sliceRefreshInterval or 0.08) then
    GetState().sliceRefreshElapsed = 0
    UpdateAllSlices()
  end
end

StopOptionsPreviewVisuals = function()
  if GetState().mainFrame then
    GetState().fadeMode = nil
    GetState().mainFrame:SetScript("OnUpdate", nil)
    GetState().mainFrame:SetAlpha(0)
  end
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
      slice.targetScale = 1.0
      slice.scaleStart = 1.0
      slice.scaleElapsed = -1
      if slice.innerFrame then
        slice.innerFrame:SetScale(1.0)
        slice.innerFrame:SetAlpha(1.0)
      end
    end
  end
  SetSliceMouseEnabled(false)
end

StartOptionsPreviewVisuals = function()
  if not GetState().mainFrame then
    return
  end
  BuildPreviewPartyData()
  Visual.UpdateMainFramePosition()
  Visual.UpdateSlicePositionsAndSizes()
  if GetState().wheelBG then
    GetState().wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  GetState().sliceRefreshElapsed = 0
  ResetHealthBarAnimState()
  UpdateAllSlices()
  -- Layout-only: do not steal clicks or cast while tweaking settings.
  SetSliceMouseEnabled(false)
  GetState().fadeMode = nil
  GetState().mainFrame:SetAlpha(1)
  GetState().mainFrame:SetScript("OnUpdate", PreviewOnUpdate)
end

IsOptionsPreviewActive = function()
  return GetState().optionsPreviewActive
end

--- Forces the Party Radial on-screen for the options tab without freelook unlock,
--- mouse capture, or marking IsActive(). Empty roster slots use placeholders.
SetOptionsPreview = function(enabled)
  enabled = enabled and true or false
  if GetState().optionsPreviewActive == enabled then
    return
  end

  if enabled then
    if InCombatLockdown() or not IsEnabled() or not GetState().mainFrame then
      return
    end
    -- Gameplay radial must not stay "active" under a layout preview.
    if GetState().isActive then
      Hide()
    end
    GetState().optionsPreviewActive = true
    StartOptionsPreviewVisuals()
    return
  end

  GetState().optionsPreviewActive = false
  GetState().previewPartyData = nil
  StopOptionsPreviewVisuals()
  -- Restore secure-button roster without placeholders.
  RefreshPartyData()
end

local function IsMouseButtonStillDown(buttonKey)
  if not buttonKey then
    return false
  end

  -- Determine which base button we're checking
  local isButton1 = buttonKey:find("BUTTON1")
  local isButton2 = buttonKey:find("BUTTON2")

  -- Check the actual mouse button state
  local mouseDown = false
  if isButton1 then
    mouseDown = _G.IsMouseButtonDown("LeftButton")
  elseif isButton2 then
    mouseDown = _G.IsMouseButtonDown("RightButton")
  end

  return mouseDown
end

---------------------------------------------------------------------------------------
--                         MAINFRAME SHOW/HIDE ALPHA FADE                            --
---------------------------------------------------------------------------------------
local function EaseOutQuad(progress)
  local inv = 1 - progress
  return 1 - inv * inv
end

local function ResetRadialHideVisuals()
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
      slice.targetScale = 1.0
      slice.scaleStart = 1.0
      slice.scaleElapsed = -1
      if slice.innerFrame then
        slice.innerFrame:SetScale(1.0)
        slice.innerFrame:SetAlpha(1.0)
      end
    end
  end

  local arrowFrame = GetState().centerArrowFrame
  if arrowFrame then
    arrowFrame.arrowLockInElapsed = -1
    arrowFrame:SetScale(1.0)
    arrowFrame:SetAlpha(1.0)
  end
end

local function FinishFadeOutVisuals()
  ResetRadialHideVisuals()
  if GetState().mainFrame then
    GetState().mainFrame:SetAlpha(0)
    if not GetState().isActive then
      GetState().mainFrame:SetScript("OnUpdate", nil)
    end
  end
end

-- Returns true while a fade is still running.
local function UpdateRadialFade(elapsed)
  if not GetState().fadeMode or not GetState().mainFrame then
    return false
  end

  local duration = GetState().fadeMode == "in" and FADE_IN_DURATION or FADE_OUT_DURATION
  GetState().fadeElapsed = GetState().fadeElapsed + elapsed
  local progress = GetState().fadeElapsed / duration
  if progress >= 1 then
    GetState().mainFrame:SetAlpha(GetState().fadeTo)
    local mode = GetState().fadeMode
    GetState().fadeMode = nil
    GetState().fadeElapsed = 0
    if mode == "out" then
      FinishFadeOutVisuals()
    end
    return false
  end

  local eased = EaseOutQuad(progress)
  local alpha = GetState().fadeFrom + (GetState().fadeTo - GetState().fadeFrom) * eased
  GetState().mainFrame:SetAlpha(alpha)
  return true
end

local function StartRadialFade(toAlpha)
  local frame = GetState().mainFrame
  if not frame then
    return
  end

  local fromAlpha = frame:GetAlpha() or 0
  GetState().fadeFrom = fromAlpha
  GetState().fadeTo = toAlpha
  GetState().fadeElapsed = 0
  if toAlpha >= fromAlpha then
    GetState().fadeMode = "in"
  else
    GetState().fadeMode = "out"
  end

  if math.abs(toAlpha - fromAlpha) < 0.001 then
    frame:SetAlpha(toAlpha)
    local mode = GetState().fadeMode
    GetState().fadeMode = nil
    GetState().fadeElapsed = 0
    if mode == "out" then
      FinishFadeOutVisuals()
    end
  end
end

local function FadeOutOnUpdate(_, elapsed)
  if not UpdateRadialFade(elapsed) and GetState().mainFrame and not GetState().isActive then
    GetState().mainFrame:SetScript("OnUpdate", nil)
  end
end

local function TrackMousePosition(_, elapsed)
  if GetState().fadeMode == "in" then
    UpdateRadialFade(elapsed)
  end

  if not GetState().isActive then
    return
  end

  -- Check button release to close the radial (only when opened via mouse button, not keybind)
  if GetState().currentButton then
    local elapsed_since_show = _G.GetTime() - (GetState().showTime or 0)
    if elapsed_since_show > 0.2 then
      if not IsMouseButtonStillDown(GetState().currentButton) then
        CM.DebugPrint(
          "Party Radial: Button released, closing (combat=" .. tostring(InCombatLockdown()) .. ")"
        )
        ExecuteAndHide()
        return
      end
    end
  end
  -- When opened via keybind, key release is handled by HideFromKeybind()
  -- via runOnUp binding (with spurious key-up counter).

  -- Radial selection: cursor angle picks a slice, but only within a reasonable
  -- distance from center. Beyond the outer edge of slices, nothing is selected
  -- so the hover animation doesn't mislead the user into clicking outside the frames.
  -- Uses GetState().maxSelectDistance computed at Show time (combat-safe, no DB access).
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  local sliceIndex = nil
  if distance > CENTER_DEAD_ZONE and distance <= (GetState().maxSelectDistance or 160) then
    sliceIndex = GetSliceFromAngle(angle)
  end
  if sliceIndex ~= GetState().selectedSlice then
    GetState().selectedSlice = sliceIndex
    HighlightSlice(sliceIndex)
  end

  -- Center: static X (Icon_Close) always visible; over dead zone show Select_Close and hide rotating arrow
  -- Center size is fixed (CENTER_FIXED_SIZE), not tied to crosshair.
  local arrowFrame = GetState().centerArrowFrame
  local arrowTex = GetState().centerArrowTexture
  local centerSelectClose = GetState().centerSelectClose
  if arrowFrame and arrowTex then
    local overDeadCenter = (distance <= CENTER_DEAD_ZONE)
    if centerSelectClose then
      if overDeadCenter then
        centerSelectClose:Show()
        arrowTex:Hide()
      else
        centerSelectClose:Hide()
        arrowTex:Show()
      end
    end
    if arrowFrame.arrowLockInElapsed == -1 then
      -- Alpha: full when over dead center; 1.0 over a player, 0.5 not over a player when outside center
      local arrowAlpha
      if overDeadCenter then
        arrowAlpha = 1.0
      else
        local selectedSlice = sliceIndex and GetState().sliceFrames[sliceIndex]
        local unitId = selectedSlice and selectedSlice:GetAttribute("unit")
        arrowAlpha = (unitId and unitId ~= "") and 1.0 or 0.5
      end
      arrowFrame:SetAlpha(arrowAlpha)
    end
    -- Rotation: angle 0 = right, 90 = up; atlas arrow points down, so rotate by (angle + 90) to align with cursor
    arrowTex:SetRotation(math.rad(angle + 90))
  end

  -- Smooth scale transition on innerFrame (duration-based, always combat-safe).
  -- innerFrame is a regular Frame child, so SetScale is never protected.
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice and slice.innerFrame and slice.scaleElapsed and slice.scaleElapsed >= 0 then
      slice.scaleElapsed = slice.scaleElapsed + elapsed
      if slice.scaleElapsed >= SLICE_SCALE_DURATION then
        slice.scaleElapsed = -1
        slice.innerFrame:SetScale(slice.targetScale)
      else
        local progress = slice.scaleElapsed / SLICE_SCALE_DURATION
        local scale = slice.scaleStart + (slice.targetScale - slice.scaleStart) * progress
        slice.innerFrame:SetScale(scale)
      end
    end
  end

  UpdateAllHealthBarGlowPulses(elapsed)

  -- Update expensive slice/unit status at a short cadence instead of every frame.
  GetState().sliceRefreshElapsed = (GetState().sliceRefreshElapsed or 0) + elapsed
  if GetState().sliceRefreshElapsed >= (GetState().sliceRefreshInterval or 0.08) then
    GetState().sliceRefreshElapsed = 0
    UpdateAllSlices()
  end
end

Show = function(buttonKey)
  if not CM.DB.global.partyRadial or not CM.DB.global.partyRadial.enabled then
    return false
  end
  if not GetState().mainFrame then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  if GetState().optionsPreviewActive then
    SetOptionsPreview(false)
  end

  -- Store state
  GetState().isActive = true
  GetState().currentButton = buttonKey
  GetState().wasMouselooking = _G.IsMouselooking()
  GetState().showTime = _G.GetTime()
  -- Cache max selection distance for TrackMousePosition
  GetState().maxSelectDistance = SLICE_RADIUS + BASE_SLICE_SIZE / 2

  -- Stop mouselook so cursor is free for slice selection
  -- Use UnlockFreeLook() instead of direct MouselookStop() to ensure proper state management
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't immediately close us
  if GetState().wasMouselooking then
    GetState().isTogglingMouselook = true
    CM.UnlockFreeLook()
    GetState().isTogglingMouselook = false
  end

  -- Initial selection from current cursor angle
  -- Only select within dead zone → outer edge of slices range
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  GetState().selectedSlice = nil
  if distance > CENTER_DEAD_ZONE and distance <= GetState().maxSelectDistance then
    GetState().selectedSlice = GetSliceFromAngle(angle)
  end
  -- Update visuals first so slice alpha is set to 1 for populated slices
  -- (HighlightSlice checks GetAlpha() > 0 to decide if a slice can be scaled)
  GetState().sliceRefreshElapsed = 0
  ResetHealthBarAnimState()
  UpdateAllSlices()
  RequestPartySpecInspects()

  -- Enable mouse on slices so they can receive clicks (out of combat only;
  -- in combat, slices keep EnableMouse from last out-of-combat Show, which is true)
  SetSliceMouseEnabled(true)

  -- Fade mainFrame + children in via alpha (combat-safe).
  if GetState().wheelBG then
    GetState().wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  StartRadialFade(1)

  -- Apply initial highlight AFTER slices are visible
  HighlightSlice(GetState().selectedSlice)

  -- Start mouse tracking (also drives fade-in)
  GetState().mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation (always start from base scale 1.0 to prevent compounding)
  local arrowFrame = GetState().centerArrowFrame
  if arrowFrame then
    local baseArrowScale = 1.0
    local baseArrowAlpha = 1.0
    arrowFrame.arrowLockInOriginalScale = baseArrowScale
    arrowFrame.arrowLockInOriginalAlpha = baseArrowAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = baseArrowScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = baseArrowScale
    arrowFrame.arrowLockInTargetAlpha = baseArrowAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Party Radial: Shown for " .. buttonKey)

  return true
end

-- Close the radial when the triggering mouse button is released.
-- Spell casting is handled by modified attributes on each slice:
--   type1="macro", macrotext1="/cast [@partyN] SpellName" (set out of combat)
--   SecureActionButtonTemplate resolves the modifier+button combo and fires the macro
-- This function is called from TrackMousePosition when the mouse button is released.
ExecuteAndHide = function()
  if not GetState().isActive then
    return
  end

  if GetState().selectedSlice then
    CM.DebugPrint("Party Radial: Closing (slice " .. GetState().selectedSlice .. " was hovered)")
  else
    CM.DebugPrint("Party Radial: Closing (no slice selected)")
  end

  Hide()
end

Hide = function()
  if not GetState().isActive then
    return
  end
  if not GetState().mainFrame then
    GetState().isActive = false
    GetState().selectedSlice = nil
    GetState().currentButton = nil
    GetState().boundKey = nil
    return
  end
  CM.DebugPrint("Party Radial: HR.Hide called from: " .. (debugstack(2, 1, 0) or "unknown"))

  -- Disable mouse immediately so a fading radial cannot steal clicks.
  -- Only works out of combat (EnableMouse is protected on secure frames in combat).
  SetSliceMouseEnabled(false)

  -- Mark inactive so ShouldFreeLookBeOff() via IsPartyRadialActive()
  -- no longer detects the radial as open (freelook can return during fade-out).
  GetState().isActive = false
  GetState().selectedSlice = nil

  -- Re-engage mouselook if it was active before radial opened
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't re-enter
  if GetState().wasMouselooking then
    -- Restore crosshair before starting mouselook (needed for lock-in animation)
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    end
    -- LockFreeLook handles MouselookStart, UI state, animations, and notifies
    -- radial via OnMouselookChanged — guard prevents re-entry
    GetState().isTogglingMouselook = true
    CM.SetCursorFreelookCenteringCVar(false)
    CM.LockFreeLook()
    GetState().isTogglingMouselook = false
  else
    -- Restore crosshair even if mouselook wasn't active
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    end
  end

  -- Visual fade-out continues after logical close (combat-safe SetAlpha only).
  StartRadialFade(0)
  if GetState().fadeMode == "out" then
    GetState().mainFrame:SetScript("OnUpdate", FadeOutOnUpdate)
  else
    -- Already at 0 (or snap-finished); ensure OnUpdate is cleared.
    GetState().mainFrame:SetScript("OnUpdate", nil)
  end

  CM.DebugPrint("Party Radial: Hidden (combat=" .. tostring(InCombatLockdown()) .. ")")
end

-- Open radial via keybind (targeting on hover, casting via mouse clicks on slices)
ShowFromKeybind = function()
  if not CM.DB.global.partyRadial or not CM.DB.global.partyRadial.enabled then
    return false
  end
  if not GetState().mainFrame then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  if GetState().optionsPreviewActive then
    SetOptionsPreview(false)
  end

  -- Find which key is bound so we can poll for release in TrackMousePosition
  local boundKey = _G.GetBindingKey("Combat Mode - Party Radial")

  -- Store state (currentButton = nil signals keybind mode)
  GetState().isActive = true
  GetState().currentButton = nil
  GetState().boundKey = boundKey
  GetState().keyUpCount = 0
  GetState().wasMouselooking = _G.IsMouselooking()
  GetState().showTime = _G.GetTime()
  -- Cache max selection distance for TrackMousePosition
  GetState().maxSelectDistance = SLICE_RADIUS + BASE_SLICE_SIZE / 2

  -- Stop mouselook so cursor is free for slice selection.
  -- NOTE: MouselookStop causes spurious key-up events for held keys. The
  -- time-based filter in HideFromKeybind handles this by ignoring key-ups
  -- that arrive within 0.3s of showing.
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't immediately close us
  if GetState().wasMouselooking then
    GetState().isTogglingMouselook = true
    CM.UnlockFreeLook()
    GetState().isTogglingMouselook = false
  end

  -- Initial selection from current cursor angle
  -- Only select within dead zone → outer edge of slices range
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  GetState().selectedSlice = nil
  if distance > CENTER_DEAD_ZONE and distance <= GetState().maxSelectDistance then
    GetState().selectedSlice = GetSliceFromAngle(angle)
  end
  -- Update visuals first so slice alpha is set to 1 for populated slices
  GetState().sliceRefreshElapsed = 0
  ResetHealthBarAnimState()
  UpdateAllSlices()
  RequestPartySpecInspects()

  -- Enable mouse on slices so they can receive clicks
  SetSliceMouseEnabled(true)

  -- Fade mainFrame + children in via alpha (combat-safe).
  if GetState().wheelBG then
    GetState().wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  StartRadialFade(1)

  -- Apply initial highlight AFTER slices are visible
  HighlightSlice(GetState().selectedSlice)

  -- Start mouse tracking (for health bar updates and OnEnter/OnLeave; also drives fade-in)
  GetState().mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation (always start from base scale 1.0 to prevent compounding)
  local arrowFrame = GetState().centerArrowFrame
  if arrowFrame then
    local baseArrowScale = 1.0
    local baseArrowAlpha = 1.0
    arrowFrame.arrowLockInOriginalScale = baseArrowScale
    arrowFrame.arrowLockInOriginalAlpha = baseArrowAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = baseArrowScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = baseArrowScale
    arrowFrame.arrowLockInTargetAlpha = baseArrowAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint(
    "Party Radial: Shown via keybind (combat="
      .. tostring(InCombatLockdown())
      .. ", wasML="
      .. tostring(GetState().wasMouselooking)
      .. ")"
  )
  return true
end

-- Close radial opened via keybind
HideFromKeybind = function()
  if not GetState().isActive then
    CM.DebugPrint("Party Radial: HideFromKeybind called but radial not active")
    return
  end
  local elapsed = _G.GetTime() - (GetState().showTime or 0)
  CM.DebugPrint(
    "Party Radial: HideFromKeybind elapsed="
      .. string.format("%.3f", elapsed)
      .. "s combat="
      .. tostring(InCombatLockdown())
  )
  -- Tap vs hold detection: if key-up arrives quickly (< 0.3s), treat as a tap —
  -- keep the radial open so the user can select a slice with the mouse. A second
  -- key-down (handled in CombatMode_PartyRadialKey) will close it.
  -- If key-up arrives after 0.3s, treat as a hold release — close the radial.
  if elapsed < 0.3 then
    CM.DebugPrint("Party Radial: Tap detected, keeping open")
    return
  end
  Hide()
end

IsActive = function()
  return GetState().isActive
end

IsEnabled = function()
  return CM.DB.global.partyRadial and CM.DB.global.partyRadial.enabled
end

Lifecycle.OnMouselookChanged = OnMouselookChanged
Lifecycle.DismissOnLoad = DismissOnLoad
Lifecycle.SetCaptureActive = SetCaptureActive
Lifecycle.IsOptionsPreviewActive = IsOptionsPreviewActive
Lifecycle.SetOptionsPreview = SetOptionsPreview
Lifecycle.Show = Show
Lifecycle.ExecuteAndHide = ExecuteAndHide
Lifecycle.Hide = Hide
Lifecycle.ShowFromKeybind = ShowFromKeybind
Lifecycle.HideFromKeybind = HideFromKeybind
Lifecycle.IsActive = IsActive
Lifecycle.IsEnabled = IsEnabled
Lifecycle.StartOptionsPreviewVisuals = StartOptionsPreviewVisuals
Lifecycle.StopOptionsPreviewVisuals = StopOptionsPreviewVisuals
