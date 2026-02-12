---------------------------------------------------------------------------------------
--                                     CORE LOGIC                                    --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- Check if running on Retail or Classic
local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

-- CACHING GLOBAL VARIABLES
-- Slightly better performance than doing a global lookup every time
local CreateFrame = _G.CreateFrame
local CreateMacro = _G.CreateMacro
local DisableAddOn = _G.C_AddOns.DisableAddOn
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
local GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GameTooltip = _G.GameTooltip
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetCursorPosition = _G.GetCursorPosition
local GetMacroInfo = _G.GetMacroInfo
local GetTime = _G.GetTime
local GetUIPanel = _G.GetUIPanel
local InCinematic = _G.InCinematic
local IsInCinematicScene = _G.IsInCinematicScene
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local loadstring = _G.loadstring
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local OpenToCategory = _G.Settings.OpenToCategory
local OpenSettingsPanel = _G.C_SettingsUtil and _G.C_SettingsUtil.OpenSettingsPanel
local pcall = _G.pcall
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetCVar = _G.C_CVar.SetCVar
local SetModifiedClick = _G.SetModifiedClick
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding
local SpellIsTargeting = _G.SpellIsTargeting
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitReaction = _G.UnitReaction
local UnitIsPlayer = _G.UnitIsPlayer
local unpack = _G.unpack

-- INSTANTIATING ADDON & ENCAPSULATING NAMESPACE
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
_G["CM"] = CM

-- INITIAL STATE VARIABLES
--[[
Changes when Free Look state is modified through user input
("Toggle" or "Press & Hold" keybinds and "/cm" cmd)
]] --
local FreeLookOverride = false

---------------------------------------------------------------------------------------
--                                 UTILITY FUNCTIONS                                 --
---------------------------------------------------------------------------------------
local function FetchDataFromTOC()
  local dataRetuned = {}
  local keysToFetch = {
    "Version",
    "Title",
    "Notes",
    "Author",
    "X-Discord",
    "X-Curse",
    "X-Contributors"
  }

  for _, key in ipairs(keysToFetch) do
    dataRetuned[string.upper(key)] = GetAddOnMetadata("CombatMode", key)
  end

  return dataRetuned
end

CM.METADATA = FetchDataFromTOC()

function CM.DebugPrint(statement)
  if CM.DB.global.debugMode then
    print(CM.Constants.BasePrintMsg .. "|cff909090: " .. tostring(statement) .. "|r")
  end
end

local LAST_PRINT_TIME = 0
local function PreventDebugSpam(msg)
  local currentTime = GetTime()

  if currentTime - LAST_PRINT_TIME > 3 then
    CM.DebugPrint(msg)
    LAST_PRINT_TIME = currentTime
  end
end

local function OpenConfigPanel()
  if InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end

  -- Use the new API if available (Patch 12.0.0+)
  if OpenSettingsPanel then
    local categoryID = AceConfigDialog.BlizOptionsIDMap[CM.METADATA["TITLE"]]
    OpenSettingsPanel(categoryID)
  else
    -- Fallback to old API for older clients
    OpenToCategory(CM.METADATA["TITLE"])
  end
end

local function UndoCMChanges()
  if InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot run this cmd while in combat.|r")
    return
  end
  CM:ResetCVarsToDefault()
  DisableAddOn("CombatMode")
  ReloadUI()
end

local function DisplayPopup()
  if CM.DB.char.seenWarning then
    return
  end

  local function OnClosePopup()
    CM.DB.char.seenWarning = true
    OpenConfigPanel()
  end

  StaticPopupDialogs["CombatMode Warning"] = {
    text = CM.Constants.PopupMsg,
    button1 = "Ok",
    OnButton1 = OnClosePopup,
    OnHide = OnClosePopup,
    timeout = 0,
    whileDead = true
  }

  StaticPopup_Show("CombatMode Warning")
end

function CM.MacroExists(name)
  return GetMacroInfo(name) ~= nil
end

local function CreateTargetMacros()
  local function createMacroIfNotExists(macroName, icon, macroText)
    if not CM.MacroExists(macroName) then
      CreateMacro(macroName, icon, macroText, false)
    end
  end

  local macroIcon = "ability_hisek_aim"

  for macroName, macroText in pairs(CM.Constants.Macros) do
    createMacroIfNotExists(macroName, macroIcon, macroText)
  end
end

-- This prevents the auto running bug.
local function IsDefaultMouseActionBeingUsed()
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

--[[
  Checking if DynamicCam is loaded so we can relinquish control of a few camera features
  as DynamicCam allows fine-grained control of Mouselook Speed & Target Focus
]] --
local function IsDCLoaded()
  local DC = AceAddon:GetAddon("DynamicCam", true)
  CM.DynamicCam = DC ~= nil and true or false
  if CM.DynamicCam and not CM.DB.global.silenceAlerts then
    print(CM.Constants.BasePrintMsg ..
            "|cff909090: |cffE52B50DynamicCam detected!|r Handing over control of |cffE37527• Camera Features|r.|r")
  end
end

---------------------------------------------------------------------------------------
--                              CVAR HANDLING FUNCTIONS                              --
---------------------------------------------------------------------------------------
local function LoadCVars(info)
  local CVarType, CMValues, BlizzValues, FeatureName = info.CVarType, info.CMValues, info.BlizzValues, info.FeatureName
  local CVarsToLoad

  if CVarType == "combatmode" then
    CVarsToLoad = CMValues
    CM.DebugPrint(FeatureName .. " CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = BlizzValues
    CM.DebugPrint(FeatureName .. " CVars RESET")
  else
    CM.DebugPrint("Invalid CVarType specified in fn CM.ConfigCVars() for " .. FeatureName .. ": " .. tostring(CVarType))
    return
  end

  for name, value in pairs(CVarsToLoad) do
    SetCVar(name, value)
  end
end

function CM.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ReticleTargetingCVarValues,
    BlizzValues = CM.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting"
  }

  LoadCVars(info)
end

function CM.ConfigActionCamera(CVarType)
  if CM.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ActionCameraCVarValues,
    BlizzValues = CM.Constants.BlizzardActionCameraCVarValues,
    FeatureName = "Action Camera"
  }

  LoadCVars(info)
  if CVarType == "combatmode" then
    CM.SetShoulderOffset()
  end
  -- Disable the Action Cam warning message.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

function CM.ConfigStickyCrosshair(CVarType)
  if CM.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.TagetFocusCVarValues,
    BlizzValues = CM.Constants.BlizzardTagetFocusCVarValues,
    FeatureName = "Sticky Crosshair"
  }

  LoadCVars(info)
end

function CM.SetMouseLookSpeed()
  if CM.DynamicCam then
    return
  end

  local XSpeed = CM.DB.global.mouseLookSpeed
  local YSpeed = CM.DB.global.mouseLookSpeed / 2 -- Blizz wants pitch speed as 1/2 of yaw speed
  SetCVar("cameraYawMoveSpeed", XSpeed)
  SetCVar("cameraPitchMoveSpeed", YSpeed)
  CM.DebugPrint("Setting Camera Turn Speed X to " .. XSpeed .. " and Y to " .. YSpeed)
end

function CM.SetShoulderOffset()
  if CM.DynamicCam then
    return
  end

  local offset = CM.DB.char.shoulderOffset
  SetCVar("test_cameraOverShoulder", offset)
  CM.DebugPrint("Setting Shoulder Offset to " .. offset)
end

function CM.SetCrosshairPriority(enabled)
  if ON_RETAIL_CLIENT == false then
    return
  end
  if enabled then
    SetCVar("enableMouseoverCast", 1)
    SetModifiedClick("MOUSEOVERCAST", "NONE")
    SaveBindings(GetCurrentBindingSet())
    CM.DebugPrint("Enabling Crosshair Priority")
  else
    SetCVar("enableMouseoverCast", 0)
    CM.DebugPrint("Disabling Crosshair Priority")
  end
end

function CM.SetFriendlyTargeting(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

-- Temporarily disable friendly targeting during combat
local function HandleFriendlyTargetingInCombat()
  local CharConfig = CM.DB.char or {}
  local isFriendlyTargetingInCombatOn = CharConfig.reticleTargeting and CharConfig.friendlyTargeting and
                                          CharConfig.friendlyTargetingInCombat

  if not isFriendlyTargetingInCombatOn then
    return
  end

  local InCombat = UnitAffectingCombat("player")

  if InCombat then
    CM.SetFriendlyTargeting(false)
  else
    CM.SetFriendlyTargeting(true)
  end
end

local function CenterCursor(shouldCenter)
  if shouldCenter then
    SetCVar("CursorFreelookCentering", 1)
    CM.DebugPrint("Locking cursor to crosshair position.")
  else
    SetCVar("CursorFreelookCentering", 0)
    CM.DebugPrint("Freeing cursor from crosshair position.")
  end
end

function CM:ResetCVarsToDefault()
  self.ConfigReticleTargeting("blizzard")
  self.ConfigActionCamera("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.SetCrosshairPriority(false)
  self.SetFriendlyTargeting(false)

  print(CM.Constants.BasePrintMsg .. "|cff909090: all changes have been reverted.|r")
end

---------------------------------------------------------------------------------------
--                           CROSSHAIR HANDLING FUNCTIONS                            --
---------------------------------------------------------------------------------------
-- SETTING UP CROSSHAIR FRAME & ANIMATION
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")
local CrosshairAnimation = CrosshairFrame:CreateAnimationGroup()
local ScaleAnimation = CrosshairAnimation:CreateAnimation("Scale")
local STARTING_SCALE = 1
local ENDING_SCALE = 0.9
local SCALE_DURATION = 0.15
ScaleAnimation:SetDuration(SCALE_DURATION)
ScaleAnimation:SetScaleFrom(STARTING_SCALE, STARTING_SCALE)
ScaleAnimation:SetScaleTo(ENDING_SCALE, ENDING_SCALE)
ScaleAnimation:SetSmoothProgress(SCALE_DURATION)
ScaleAnimation:SetSmoothing("IN_OUT")

local function HideCrosshairWhileMounted()
  return CM.DB.global.crosshairMounted and IsMounted()
end

local function SetCrosshairAppearance(state)
  local CrosshairAppearance = CM.DB.global.crosshairAppearance
  local crosshairYPos = CM.DB.global.crosshairY
  local r, g, b, a = unpack(CM.Constants.CrosshairReactionColors[state])
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false

  -- Sets new scale at the end of animation
  CrosshairAnimation:SetScript("OnFinished", function()
    if state ~= "base" then
      CrosshairFrame:SetScale(ENDING_SCALE)
      CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos / ENDING_SCALE)
    end
  end)

  CrosshairTexture:SetTexture(textureToUse)
  CrosshairTexture:SetVertexColor(r, g, b, a)
  CrosshairAnimation:Play(reverseAnimation)
  if state == "base" then
    CrosshairFrame:SetScale(STARTING_SCALE)
    CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  end
end

function CM.DisplayCrosshair(shouldShow)
  if shouldShow then
    CrosshairTexture:Show()
  else
    CrosshairTexture:Hide()
  end
end

-- Adjusts centered cursor vertical positioning to match crosshair's
local function AdjustCenteredCursorYPos(crosshairYPos)
  local cursorCenteredYpos = (crosshairYPos / 1000) + 0.5 -- adding 0.5 to prevent going below screen center
  local adjustment = (crosshairYPos * 0.15) / 1000 -- lowering the cursor by 15% of YPos to keep it within xhair
  cursorCenteredYpos = cursorCenteredYpos - adjustment
  SetCVar("CursorCenteredYPos", cursorCenteredYpos)
end

function CM.CreateCrosshair()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairYPos = UserConfig.crosshairY or DefaultConfig.crosshairY

  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  CrosshairFrame:SetSize(UserConfig.crosshairSize or DefaultConfig.crosshairSize,
    UserConfig.crosshairSize or DefaultConfig.crosshairSize)
  CrosshairFrame:SetAlpha(UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity)

  SetCrosshairAppearance("base")
  AdjustCenteredCursorYPos(crosshairYPos)
end

-- Track the last known unit under cursor and its reaction to update the crosshair appearance
local lastKnownUnit = nil
local lastKnownUnitReaction = nil

-- Get the unit under the cursor and its reaction type for crosshair reactions
local function GetUnitUnderCursor()
  -- Check for game object interaction first using softinteract
  local isTargetObject = UnitIsGameObject("softinteract")
  if isTargetObject then
    return "softinteract", "object"
  end

  -- If not a game object, check for regular units using mouseover
  if UnitExists("mouseover") and UnitGUID("mouseover") then
    local reaction = UnitReaction("player", "mouseover")
    local reactionType
    if reaction then
      if UnitIsPlayer("mouseover") then
        if UnitCanAttack("player", "mouseover") then
          reactionType = "hostile"
        else
          reactionType = "friendly_player"
        end
      elseif reaction <= 4 then
        reactionType = "hostile"
      elseif reaction >= 5 then
        reactionType = "friendly_npc"
      else
        reactionType = "neutral"
      end
    else
      reactionType = "base"
    end

    PreventDebugSpam("Found mouseover unit (reaction: " .. reactionType .. ")")
    return "mouseover", reactionType
  end
-- no valid unit found (meaning it's not aiming at anything)
  PreventDebugSpam("No unit under cursor, setting base appearance")
  return nil, nil
end

-- Update crosshair appearance based on unit under cursor
local function UpdateCrosshairReaction()
  if not CM.DB.global.crosshair or HideCrosshairWhileMounted() then
    return
  end

  local currentUnit, currentReaction = GetUnitUnderCursor()

  -- Update if unit changed OR if reaction type changed (for same unit)
  if currentUnit ~= lastKnownUnit or currentReaction ~= lastKnownUnitReaction then
    lastKnownUnit = currentUnit
    lastKnownUnitReaction = currentReaction

    if currentUnit then
      SetCrosshairAppearance(currentReaction or "base")
    else
      SetCrosshairAppearance("base")
    end
  end
end

---------------------------------------------------------------------------------------
--                                CURSOR PULSE EFFECT                                --
---------------------------------------------------------------------------------------
local PULSE_DURATION = 0.4; -- total duration of the effect
local PULSE_STARTING_ALPHA = 0.5; -- initial transparency
local PULSE_STARTING_SIZE = 256 -- initial size of texture
local PULSE_TOTAL_ELAPSED = -1;

local PulseFrame = CreateFrame("Frame", nil, UIParent)
local PulseTexture = PulseFrame:CreateTexture(nil, "BACKGROUND")

local function CreatePulse()
  PulseFrame:SetSize(0, 0)
  PulseFrame:Hide()
  PulseTexture:SetAtlas(CM.Constants.PulseAtlas, true)
  PulseTexture:SetVertexColor(1, 1, 1, 1)
  PulseTexture:SetAllPoints()
end

local function UpdatePulse(_, elapsed)
  if PULSE_TOTAL_ELAPSED == -1 then
    return
  end

  PULSE_TOTAL_ELAPSED = PULSE_TOTAL_ELAPSED + elapsed
  if PULSE_TOTAL_ELAPSED > PULSE_DURATION then
    PULSE_TOTAL_ELAPSED = -1
    PulseFrame:Hide()
    return
  end

  local progress = PULSE_TOTAL_ELAPSED / PULSE_DURATION
  local invertedProgress = 1 - progress * progress

  local alpha = invertedProgress * PULSE_STARTING_ALPHA
  PulseTexture:SetAlpha(alpha)

  local size = invertedProgress * PULSE_STARTING_SIZE
  PulseFrame:SetSize(size, size)

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  PulseFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (cursorX / scale) - size / 2, (cursorY / scale) - size / 2)
end

local function ShowCursorPulse()
  PULSE_TOTAL_ELAPSED = 0
  PulseFrame:Show()
end

PulseFrame:SetScript("OnUpdate", UpdatePulse)

---------------------------------------------------------------------------------------
--                      FRAME WATCHING / CURSOR UNLOCK FUNCTIONS                     --
---------------------------------------------------------------------------------------
local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G[frameName]
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      PreventDebugSpam(frameName .. " is visible, preventing re-locking.")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for wildcardFrameName, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      if wildcardFrameName == "OPieRT" then
        -- Hiding crosshair because OPie runs MouselookStop() itself,
        -- which skips UnlockCursor()'s checks to hide crosshair
        if CM.DB.global.crosshair then
          CM.DisplayCrosshair(false)
        end
        CenterCursor(false)
      end
      return true
    end
  end
end

local function IsCustomConditionTrue()
  if not CM.DB.global.customCondition then
    return false
  end

  local func, err = loadstring(CM.DB.global.customCondition)

  if not func then
    CM.DebugPrint("Invalid custom condition " .. err)
    return false
  else
    -- Calling the fn() protected to check evaluation
    local success, result = pcall(func)

    if not success then
      CM.DebugPrint("Error executing custom condition: " .. result)
      return false
    end

    return result
  end
end

local function IsVendorMountOut()
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

local function IsFeignDeathActive()
  return GetPlayerAuraBySpellID(5384) ~= nil
end

local function IsInPetBattle()
  if ON_RETAIL_CLIENT then
    return _G.C_PetBattles.IsInBattle()
  else
    return false
  end
end

local function IsUnlockFrameVisible()
  local isGenericPanelOpen = (GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center")) and true or false
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function IsHealingRadialActive()
  return CM.HealingRadial and CM.HealingRadial.IsActive and CM.HealingRadial.IsActive()
end

local function ShouldFreeLookBeOff()
  local evaluate = IsCustomConditionTrue() or
                     (FreeLookOverride or SpellIsTargeting() or InCinematic() or IsInCinematicScene() or
                       IsUnlockFrameVisible() or IsVendorMountOut() or IsInPetBattle() or IsFeignDeathActive() or
                       IsHealingRadialActive())
  return evaluate
end

-- FRAME WATCHING FOR SERIALIZED FRAMES (Ex: Opie rings)
local function InitializeWildcardFrameTracking(frameArr)
  CM.DebugPrint("Looking for wildcard frames...")

  -- Initialise the table by going through ALL available globals once and keeping the ones that match
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

---------------------------------------------------------------------------------------
--                             BUTTON OVERRIDE FUNCTIONS                             --
---------------------------------------------------------------------------------------
function CM.GetBindingsLocation()
  return CM.DB.char.useGlobalBindings and "global" or "char"
end

function CM.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then
    return
  end

  local valueToUse
  if buttonSettings.value == "MACRO" then
    valueToUse = "MACRO " .. buttonSettings.macroName
  elseif buttonSettings.value == "CLEARTARGET" then
    valueToUse = "MACRO CM_ClearTarget"
  elseif buttonSettings.value == "CLEARFOCUS" then
    valueToUse = "MACRO CM_ClearFocus"
  else
    valueToUse = buttonSettings.value
  end
  SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

function CM.OverrideDefaultButtons()
  for _, button in pairs(CM.Constants.ButtonsToOverride) do
    CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button])
  end
end

function CM.ResetBindingOverride(buttonSettings)
  SetMouselookOverrideBinding(buttonSettings.key, nil)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- Unbinding MOVEANDSTEER to avoid potential bug when toggling free look with the same key
local function UnbindMoveAndSteer()
  local key = GetBindingKey("MOVEANDSTEER")
  if key then
    SetBinding(key, "Combat Mode Toggle")
  end
  SaveBindings(GetCurrentBindingSet())
end

-- Matches the bindable actions values defined in Constants.ActionsToProcess with more readable names for the UI
local function RenameBindableActions()
  for _, bindingAction in pairs(CM.Constants.ActionsToProcess) do
    local bindingUiName = _G["BINDING_NAME_" .. bindingAction]
    CM.Constants.OverrideActions[bindingAction] = bindingUiName or bindingAction
  end
end

---------------------------------------------------------------------------------------
--                             FREE LOOK STATE FUNCTIONS                             --
---------------------------------------------------------------------------------------
-- Helper function to handle UI state changes when toggling free look
local function HandleFreeLookUIState(isLocking, isPermanentUnlock)
  if CM.DB.global.crosshair then
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

  if CM.DB.global.crosshair and CM.DB.char.stickyCrosshair then
    CM.ConfigStickyCrosshair(isLocking and "combatmode" or "blizzard")
  end
end

local function LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    -- NOTE: CursorFreelookCentering is intentionally NOT set to 1 here.
    -- The CVar is bugged since 10.2 and causes camera jolt when set to 1.
    -- See Constants.lua comment and https://github.com/Stanzilla/WoWUIBugs/issues/504
    HandleFreeLookUIState(true, false)
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(true)
    end
    CM.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

    if CM.DB.global.pulseCursor then
      ShowCursorPulse()
    end

    HandleFreeLookUIState(false, false)
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(false)
    end
    CM.DebugPrint("Free Look Disabled")
  end
end

local function UnlockFreeLookPermanent()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

    if CM.DB.global.pulseCursor then
      ShowCursorPulse()
    end

    HandleFreeLookUIState(false, true)
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(false)
    end
    CM.DebugPrint("Free Look Disabled (Permanent)")
  end
end

local function ToggleFreeLook(state)
  if IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  -- the Override state change is enough to trigger a Free Look update, but we call the fns directly to bypass the OnUpdate throttle
  if not state then
    LockFreeLook()
    FreeLookOverride = false
  elseif state then
    UnlockFreeLookPermanent()
    FreeLookOverride = true
  end
end

---------------------------------------------------------------------------------------
--                                   EVENT HANDLING                                  --
---------------------------------------------------------------------------------------
-- Rematch is called after every reload and this is where we make sure our config persists
local function Rematch()
  IsDCLoaded()
  CM.SetMouseLookSpeed()

  if CM.DB.global.actionCamera then
    CM.ConfigActionCamera("combatmode")
  end

  if CM.DB.char.reticleTargeting then
    CM.ConfigReticleTargeting("combatmode")

    if CM.DB.char.crosshairPriority then
      CM.SetCrosshairPriority(true)
    end

    if CM.DB.char.friendlyTargeting then
      CM.SetFriendlyTargeting(true)
    end
  end

  if CM.DB.global.crosshair then
    SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
  elseif CM.DB.global.crosshair == false then
    CM.DisplayCrosshair(false)
  end

  LockFreeLook()
end

--[[
Handle events based on their category.
You need to first register the event in the CM.Constants.BLIZZARD_EVENTS table before using it here.
Checks which category in the table the event that's been fired belongs to, and then calls the appropriate function.
]] --
local function HandleEventByCategory(category, event)
  local eventHandlers = {
    UNLOCK_EVENTS = function()
      UnlockFreeLook()
    end,
    LOCK_EVENTS = function()
      LockFreeLook()
    end,
    REMATCH_EVENTS = function()
      Rematch()
    end,
    FRIENDLY_TARGETING_EVENTS = function()
      HandleFriendlyTargetingInCombat()
      -- Also handle combat end for healing radial pending updates
      if event == "PLAYER_REGEN_ENABLED" and CM.HealingRadial and CM.HealingRadial.OnCombatEnd then
        CM.HealingRadial.OnCombatEnd()
      end
    end,
    UNCATEGORIZED_EVENTS = function()
      SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")
    end,
    HEALING_RADIAL_EVENTS = function()
      if CM.HealingRadial and CM.HealingRadial.OnGroupRosterUpdate then
        CM.HealingRadial.OnGroupRosterUpdate()
      end
    end,

  }

  if eventHandlers[category] then
    eventHandlers[category]()
  end
end

-- FIRES WHEN ONE OF OUR REGISTERED EVENTS HAPPEN IN GAME
function _G.CombatMode_OnEvent(event)
  for category, registered_events in pairs(CM.Constants.BLIZZARD_EVENTS) do
    for _, registered_event in ipairs(registered_events) do
      if event == registered_event then
        HandleEventByCategory(category, event)
      end
    end
  end
end

---------------------------------------------------------------------------------------
--                                   GAME STATE LOOP                                 --
---------------------------------------------------------------------------------------
--[[
The game engine will call the OnUpdate function once each frame.
This is (in most cases) extremely excessive, hence why we're adding a throttle.
]] --
local ON_UPDATE_INTERVAL = 0.15
local TIME_SINCE_LAST_UPDATE = 0
function _G.CombatMode_OnUpdate(_, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  TIME_SINCE_LAST_UPDATE = TIME_SINCE_LAST_UPDATE + elapsed

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if (TIME_SINCE_LAST_UPDATE >= ON_UPDATE_INTERVAL) then
    TIME_SINCE_LAST_UPDATE = 0

    if IsDefaultMouseActionBeingUsed() then
      return
    end

    if ShouldFreeLookBeOff() then
      UnlockFreeLook()
      return
    end

    if not IsMouselooking() then
      LockFreeLook()
    end

    -- Update crosshair appearance based on unit under cursor
    UpdateCrosshairReaction()

  end
end

---------------------------------------------------------------------------------------
--                            KEYBIND FUNCTIONS & COMMANDS                           --
---------------------------------------------------------------------------------------
-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CombatMode_ToggleKey()
  local state = IsMouselooking()
  ToggleFreeLook(state)
end

function _G.CombatMode_HoldKey(keystate)
  local state = keystate == "down"
  ToggleFreeLook(state)
end

function _G.CombatMode_HealingRadialKey(keystate)
  if not CM.HealingRadial then return end
  if keystate == "down" then
    CM.HealingRadial.ShowFromKeybind()
  elseif keystate == "up" then
    CM.HealingRadial.HideFromKeybind()
  end
end

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  if not input or input:trim() == "" then
    OpenConfigPanel()
  else
    AceConfigCmd.HandleCommand(self, "mychat", CM.METADATA["TITLE"], input)
  end
end

-- /CMRESET CHAT COMMAND
function CM:RunUndoCMD(input)
  if not input or input:trim() == "" then
    UndoCMChanges()
  else
    AceConfigCmd.HandleCommand(self, "mychat", CM.METADATA["TITLE"], input)
  end
end

---------------------------------------------------------------------------------------
--                                STANDARD ACE3 METHODS                              --
---------------------------------------------------------------------------------------
--[[
Do init tasks here, like loading the Saved Variables,
or setting up slash commands.
]] --
function CM:OnInitialize()
  self.DB = AceDB:New("CombatModeDB", CM.Constants.DatabaseDefaults, true)

  local parentTable = CM.METADATA["TITLE"]

  -- REGISTERING SETTINGS TREE
  -- main category
  AceConfig:RegisterOptionsTable(parentTable, CM.Config.AboutOptions)
  AceConfigDialog:AddToBlizOptions(parentTable)
  -- subcategories
  for _, option in ipairs(CM.Config.OptionCategories) do
    AceConfig:RegisterOptionsTable(option.id, option.table)
    AceConfigDialog:AddToBlizOptions(option.id, option.name, parentTable)
  end

  self:RegisterChatCommand("cm", "OpenConfigCMD")
  self:RegisterChatCommand("combatmode", "OpenConfigCMD")
  self:RegisterChatCommand("undocm", "RunUndoCMD")
end

function CM:OnResetDB()
  CM.DebugPrint("Reseting Combat Mode settings.")
  self.DB:ResetDB("Default")
  ReloadUI();
end

--[[
Do more initialization here, that really enables the use of your addon.
Register Events, Hook functions, Create Frames, Get information from
the game that wasn't available in OnInitialize
]] --
function CM:OnEnable()
  RenameBindableActions()
  CM.OverrideDefaultButtons()
  UnbindMoveAndSteer()
  InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CM.CreateCrosshair()
  CreatePulse()
  CreateTargetMacros()

  -- Initialize Healing Radial module
  if CM.HealingRadial and CM.HealingRadial.Initialize then
    CM.HealingRadial.Initialize()
  end

  -- Registering Blizzard Events from Constants.lua
  for _, events_to_register in pairs(CM.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(events_to_register) do
      self:RegisterEvent(event, _G.CombatMode_OnEvent)
    end
  end

  -- Greeting message that is printed to chat on initial load
  if not CM.DB.global.silenceAlerts then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r")
  end

  DisplayPopup()
end

--[[
Unhook, Unregister Events, Hide frames that you created.
You would probably only use an OnDisable if you want to
build a "standby" mode, or be able to toggle modules on/off.
]] --
function CM:OnDisable()
  CrosshairFrame:Hide()
  self:ResetCVarsToDefault()
  self:UnregisterAllEvents()
end
