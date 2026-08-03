---------------------------------------------------------------------------------------
--  Core/PartyRadial/PartyRadial.lua — PARTYRADIAL — façade (CM.PartyRadial public API)
---------------------------------------------------------------------------------------
--  What it does: Thin public API over Party Radial submodules: Initialize, roster/
--  combat/action-bar/binding event handlers, and re-exports of sibling module functions
--  onto CM.PartyRadial (behavior unchanged from the former monolith).
--  Architecture / how it works:
--    • Load last after PartyData → SecureBindings → HealthBars → RoleIcons → Visual →
--      Lifecycle (see Embeds.xml).
--    • Wires Visual/Lifecycle/Secure public surfaces onto CM.PartyRadial; GetState from
--      PartyData.
--  Does not: Own feature internals (siblings).
--  Related: Core/PartyRadial/*.lua, Core/Runtime/EventRouter.lua,
--  Core/Runtime/Bootstrap.lua, Core/FreeLook/FreeLookController.lua,
--  UI/Options/Tabs/TabPartyRadial.lua
---------------------------------------------------------------------------------------
local _, CM = ...

local HR = CM.PartyRadial
local PartyData = CM.PartyRadialPartyData
local Secure = CM.PartyRadialSecure
local RoleIcons = CM.PartyRadialRoleIcons
local Visual = CM.PartyRadialVisual
local Lifecycle = CM.PartyRadialLifecycle

local function GetState()
  return HR.GetState()
end

-- Visual / layout
HR.UpdateMainFramePosition = Visual.UpdateMainFramePosition
HR.UpdateSlicePositionsAndSizes = Visual.UpdateSlicePositionsAndSizes
HR.UpdateAllSlices = Visual.UpdateAllSlices
HR.HighlightSlice = Visual.HighlightSlice
HR.ApplyVisualConfig = Visual.ApplyVisualConfig

-- Lifecycle
HR.OnMouselookChanged = Lifecycle.OnMouselookChanged
HR.DismissOnLoad = Lifecycle.DismissOnLoad
HR.SetCaptureActive = Lifecycle.SetCaptureActive
HR.IsOptionsPreviewActive = Lifecycle.IsOptionsPreviewActive
HR.SetOptionsPreview = Lifecycle.SetOptionsPreview
HR.Show = Lifecycle.Show
HR.ExecuteAndHide = Lifecycle.ExecuteAndHide
HR.Hide = Lifecycle.Hide
HR.ShowFromKeybind = Lifecycle.ShowFromKeybind
HR.HideFromKeybind = Lifecycle.HideFromKeybind
HR.IsActive = Lifecycle.IsActive
HR.IsEnabled = Lifecycle.IsEnabled

---------------------------------------------------------------------------------------
--                              EVENT HANDLING                                       --
---------------------------------------------------------------------------------------
function HR.OnGroupRosterUpdate()
  PartyData.RefreshPartyData()
  Secure.UpdateSecureButtonTargets()
  -- Rebuild macrotext because [@unitId] in the macrotext depends on which
  -- party member is assigned to each slice (changes with roster)
  Secure.UpdateSliceActionAttributes()
  RoleIcons.RequestPartySpecInspects()

  local RadialState = GetState()
  if RadialState.optionsPreviewActive then
    PartyData.BuildPreviewPartyData()
    Visual.UpdateAllSlices()
  elseif RadialState.isActive then
    Visual.UpdateAllSlices()
  end
end

-- Called when combat starts (PLAYER_REGEN_DISABLED).
-- Pre-enable mouse on slices so they're ready to receive clicks if the radial
-- opens during combat (EnableMouse is protected during InCombatLockdown).
function HR.OnCombatStart()
  local RadialState = GetState()
  if RadialState.optionsPreviewActive then
    -- Keep the preview flag; hide visuals until combat ends (protected SetPoint/SetScale).
    Lifecycle.StopOptionsPreviewVisuals()
  end
  Visual.SetSliceMouseEnabled(true)
end

function HR.OnCombatEnd()
  local RadialState = GetState()
  -- Apply any pending updates that were blocked during combat
  if RadialState.pendingUpdate then
    RadialState.pendingUpdate = false
    Secure.UpdateSecureButtonTargets()
    Secure.UpdateSliceActionAttributes()
    HR.UpdateSlicePositionsAndSizes()
    HR.UpdateMainFramePosition()
  end

  -- If radial is not active, disable mouse on slices so invisible slices
  -- don't intercept clicks now that we're out of combat
  if not RadialState.isActive then
    Visual.SetSliceMouseEnabled(false)
  end

  if RadialState.optionsPreviewActive and not RadialState.isActive then
    Lifecycle.StartOptionsPreviewVisuals()
  end
end

-- Called when action bar content changes (ACTIONBAR_SLOT_CHANGED).
-- Refreshes the modified attributes so slices cast the correct spells.
function HR.OnActionBarChanged()
  Secure.UpdateSliceActionAttributes()
end

-- Called when the user changes a mouse button binding in the Config panel.
-- Rebuilds the slot map from the updated binding settings.
function HR.OnBindingChanged()
  Secure.UpdateSliceActionAttributes()
end

---------------------------------------------------------------------------------------
--                              INITIALIZATION                                       --
---------------------------------------------------------------------------------------
function HR.Initialize()
  -- Ensure defaults exist
  if not CM.DB.global.partyRadial then
    CM.DB.global.partyRadial = CM.Constants.DatabaseDefaults.global.partyRadial
  end

  -- Only create the frame and overlay when party radial is enabled (avoids drawing anything when disabled)
  if CM.DB.global.partyRadial.enabled then
    Visual.CreateMainFrame()
    PartyData.RefreshPartyData()
    Secure.UpdateSecureButtonTargets()
    Secure.UpdateSliceActionAttributes()
  end

  CM.DebugPrint("Party Radial: Initialized")
end
