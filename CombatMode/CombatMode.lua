-- CORE LOGIC
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- INSTANTIATING ADDON & ENCAPSULATING NAMESPACE
---@class CM : AceAddon
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
_G["CM"] = CM

-- SETTING UP CROSSHAIR ANIMATION
local CrosshairFrame = _G.CreateFrame("Frame", "CombatModeCrosshairFrame", _G.UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")
local CrosshairAnimation = CrosshairFrame:CreateAnimationGroup()
local ScaleAnimation = CrosshairAnimation:CreateAnimation("Scale")
local startingScale = 1
local endingScale = 0.8
local scaleDuration = 0.15
ScaleAnimation:SetDuration(scaleDuration)
ScaleAnimation:SetScaleFrom(startingScale, startingScale)
ScaleAnimation:SetScaleTo(endingScale, endingScale)
ScaleAnimation:SetSmoothProgress(scaleDuration)
ScaleAnimation:SetSmoothing("IN_OUT")

-- INITIAL STATE VARIABLES
local FreeLookOverride = false -- Changes when Free Look state is modified through user input ("Toggle" or "Press & Hold" keybinds and "/cm" cmd)

-- UTILITY FUNCTIONS
local function FetchDataFromTOC()
  local dataRetuned = {}
  local keysToFetch = {
    "Version",
    "Title",
    "Notes",
    "Author",
    "X-Discord",
    "X-Curse"
  }

  for _, key in ipairs(keysToFetch) do
    dataRetuned[string.upper(key)] = _G.C_AddOns.GetAddOnMetadata("CombatMode", key)
  end

  return dataRetuned
end

CM.METADATA = FetchDataFromTOC()

function CM.DebugPrint(statement)
  if CM.DB.global.debugMode then
    print(CM.Constants.BasePrintMsg .. "|cff909090: " .. tostring(statement) .. "|r")
  end
end

local function DisplayPopup()
  if CM.DB.char.seenWarning then
    return
  end

  local function OnClosePopup()
    CM.DB.char.seenWarning = true
  end

  _G.StaticPopupDialogs["CombatMode Warning"] = {
    text = CM.Constants.PopupMsg,
    button1 = "Ok",
    OnButton1 = OnClosePopup(),
    OnHide = OnClosePopup(),
    timeout = 0,
    whileDead = true
  }

  _G.StaticPopup_Show("CombatMode Warning")
end

function CM.LoadCVars(CVarType)
  local CVarsToLoad = {}
  -- Determine which set of CVar values to use based on the input parameter
  if CVarType == "combatmode" then
    CVarsToLoad = CM.Constants.CustomCVarValues
    CM.DebugPrint("Reticle Target CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = CM.Constants.BlizzardCVarValues
    CM.DebugPrint("Reticle Target CVars RESET")
  else
    error("Invalid CVarType specified in fn CM.LoadCVars(): " .. tostring(CVarType))
  end

  for name, value in pairs(CVarsToLoad) do
    _G.SetCVar(name, value)
  end
end

local function CreateTargetMacros()
  local macroExists = function(name)
    return _G.GetMacroInfo(name) ~= nil
  end

  local function createMacroIfNotExists(macroName, icon, macroText)
    if not macroExists(macroName) then
      _G.CreateMacro(macroName, icon, macroText, false)
    end
  end

  local macroIcon = "ability_hisek_aim"

  for macroName, macroText in pairs(CM.Constants.Macros) do
    createMacroIfNotExists(macroName, macroIcon, macroText)
  end
end

-- If left or right mouse buttons are being used while not free looking - meaning you're using the default mouse actions - then it won't allow you to lock into Free Look.
-- This prevents the auto running bug.
local function IsDefaultMouseActionBeingUsed()
  return _G.IsMouseButtonDown("LeftButton") or _G.IsMouseButtonDown("RightButton")
end

local function CenterCursor(shouldCenter)
  if not CM.DB.global.reticleTargeting then
    return
  end
  if shouldCenter then
    _G.SetCVar("CursorFreelookCentering", 1)
    CM.DebugPrint("Locking cursor to crosshair position.")
  else
    _G.SetCVar("CursorFreelookCentering", 0)
    CM.DebugPrint("Freeing cursor from crosshair position.")
  end
end

-- CROSSHAIR STATE HANDLING FUNCTIONS
local function HideWhileMounted()
  return CM.DB.global.crosshairMounted and _G.IsMounted()
end

local function SetCrosshairAppearance(state)
  local CrosshairAppearance = CM.DB.global.crosshairAppearance
  local yOffset = CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  local crosshairPositionVariance = 1000 -- from -500 min to 500 max

  -- Adjusts centered cursor vertical positioning
  local cursorCenteredYpos = (yOffset / crosshairPositionVariance) + 0.5 - 0.015
  _G.SetCVar("CursorCenteredYPos", cursorCenteredYpos)

  -- Sets new scale at the end of animation
  CrosshairAnimation:SetScript("OnFinished", function()
    if state == "hostile" or state == "friendly" or state == "object" then
      CrosshairFrame:SetScale(endingScale)
      CrosshairFrame:SetPoint("CENTER", 0, yOffset / endingScale)
    end
  end)

  if state == "hostile" then
    CrosshairTexture:SetTexture(CrosshairAppearance.Active)
    CrosshairTexture:SetVertexColor(1, .2, 0.3, 1)
    CrosshairAnimation:Play()
  elseif state == "friendly" then
    CrosshairTexture:SetTexture(CrosshairAppearance.Active)
    CrosshairTexture:SetVertexColor(0, 1, 0.3, .8)
    CrosshairAnimation:Play()
  elseif state == "object" then
    CrosshairTexture:SetTexture(CrosshairAppearance.Active)
    CrosshairTexture:SetVertexColor(1, 0.8, 0.2, .8)
    CrosshairAnimation:Play()
  elseif state == "mounted" then
    CrosshairTexture:SetVertexColor(1, 1, 1, 0)
    CrosshairAnimation:Play()
  else -- "base" falls here
    CrosshairTexture:SetTexture(CrosshairAppearance.Base)
    CrosshairTexture:SetVertexColor(1, 1, 1, .5)
    CrosshairAnimation:Play(true) -- reverse
    CrosshairFrame:SetScale(startingScale)
    CrosshairFrame:SetPoint("CENTER", 0, yOffset)
  end
end

function CM.ShowCrosshair()
  CrosshairTexture:Show()
end

function CM.HideCrosshair()
  CrosshairTexture:Hide()
end

local function CreateCrosshair()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or DefaultConfig.crosshairY)
  CrosshairFrame:SetSize(CM.DB.global.crosshairSize or DefaultConfig.crosshairSize,
    CM.DB.global.crosshairSize or DefaultConfig.crosshairSize)
  CrosshairFrame:SetAlpha(CM.DB.global.crosshairOpacity or DefaultConfig.crosshairOpacity)
  SetCrosshairAppearance("base")

  if CM.DB.global.crosshair then
    CM.ShowCrosshair()
  else
    CM.HideCrosshair()
  end
end

function CM.UpdateCrosshair()
  if CM.DB.global.crosshairY then
    CrosshairFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY)
  end

  if CM.DB.global.crosshairSize then
    CrosshairFrame:SetSize(CM.DB.global.crosshairSize, CM.DB.global.crosshairSize)
  end

  if CM.DB.global.crosshairOpacity then
    CrosshairFrame:SetAlpha(CM.DB.global.crosshairOpacity)
  end

  if CM.DB.global.crosshairAppearance then
    CrosshairTexture:SetTexture(CM.DB.global.crosshairAppearance.Base)
  end
end

local function HandleCrosshairReactionToTarget(target)
  local isTargetVisible = (_G.UnitExists(target) and _G.UnitGUID(target)) and true or false
  local reaction = _G.UnitReaction("player", target)
  local isTargetHostile = reaction and reaction <= 4
  local isTargetFriendly = reaction and reaction >= 5
  local isTargetObject = _G.UnitIsGameObject(target)

  if isTargetVisible then
    SetCrosshairAppearance(isTargetHostile and "hostile" or isTargetFriendly and "friendly" or "base")
  elseif isTargetObject then
    SetCrosshairAppearance("object")
  else
    SetCrosshairAppearance("base")
  end
end

-- FRAME WATCHING / CURSOR UNLOCK
local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G[frameName]
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      CM.DebugPrint(frameName .. " is visible, preventing re-locking.")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for wildcardFrameName, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      if wildcardFrameName == "OPieRT" then
        -- Hiding crosshair because OPie runs _G.MouselookStop() itself,
        -- which skips UnlockCursor()'s checks to hide crosshair
        if CM.DB.global.crosshair then
          CM.HideCrosshair()
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

  local customConditionFunction, error = _G.loadstring(CM.DB.global.customCondition)
  if not customConditionFunction then
    CM.DebugPrint(error)
    return false
  else
    return customConditionFunction()
  end
end

local function HasNarcissusOpen()
  return _G.Narci and _G.Narci.isActive
end

local function IsUnlockFrameVisible()
  local isGenericPanelOpen = (_G.GetUIPanel("left") or _G.GetUIPanel("right") or _G.GetUIPanel("center")) and true or
                               false
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function ShouldFreeLookBeOff()
  local shouldUnlock = FreeLookOverride or _G.SpellIsTargeting() or _G.InCinematic() or IsUnlockFrameVisible() or
                         IsCustomConditionTrue() or HasNarcissusOpen()

  return shouldUnlock
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

-- OVERRIDE BUTTONS
function CM.GetBindingsLocation()
  return CM.DB.char.useGlobalBindings and "global" or "char"
end

function CM.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then
    return
  end

  local valueToUse
  if buttonSettings.value == "CUSTOMACTION" then
    valueToUse = buttonSettings.customAction
  elseif buttonSettings.value == "CLEARTARGET" then
    valueToUse = "MACRO CM_ClearTarget"
  elseif buttonSettings.value == "CLEARFOCUS" then
    valueToUse = "MACRO CM_ClearFocus"
  else
    valueToUse = buttonSettings.value
  end
  _G.SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

function CM.OverrideDefaultButtons()
  for _, button in pairs(CM.Constants.ButtonsToOverride) do
    CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button])
  end
end

function CM.ResetBindingOverride(buttonSettings)
  _G.SetMouselookOverrideBinding(buttonSettings.key, nil)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- Matches the bindable actions values defined in Constants.ActionsToProcess with more readable names for the UI
local function RenameBindableActions()
  for _, bindingAction in pairs(CM.Constants.ActionsToProcess) do
    local bindingUiName = _G["BINDING_NAME_" .. bindingAction]
    CM.Constants.OverrideActions[bindingAction] = bindingUiName or bindingAction
  end
end

-- FREE LOOK STATE HANDLING
local function LockFreeLook()
  if not _G.IsMouselooking() then
    _G.MouselookStart()
    CenterCursor(true)

    if CM.DB.global.crosshair then
      CM.ShowCrosshair()
    end

    CM.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if _G.IsMouselooking() then
    CenterCursor(false)
    _G.MouselookStop()

    if CM.DB.global.crosshair then
      CM.HideCrosshair()
    end

    CM.DebugPrint("Free Look Disabled")
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
    UnlockFreeLook()
    FreeLookOverride = true
  end
end

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  if not _G.InCombatLockdown() and not input or input:trim() == "" then
    FreeLookOverride = true
    AceConfigDialog:Open("Combat Mode")
  else
    AceConfigCmd.HandleCommand(self, "mychat", "Combat Mode", input)
  end
end

-- Re-locking Free Look & re-setting CVars after reload/portal
local function Rematch()
  if CM.DB.global.reticleTargeting then
    CM.LoadCVars("combatmode")
  end

  if CM.DB.global.crosshairPriority then
    _G.SetCVar("enableMouseoverCast", 1)
  end

  LockFreeLook()
end

-- FIRES WHEN SPECIFIC EVENTS HAPPEN IN GAME
-- You need to first register the event in the CM.Constants.BLIZZARD_EVENTS table before using it here
function _G.CombatMode_OnEvent(event)
  local UNLOCK_EVENTS = {
    "LOADING_SCREEN_ENABLED", -- This forces a relock when quick-loading (e.g: loading after starting m+ run) thanks to the OnUpdate fn
    "BARBER_SHOP_OPEN",
    "CINEMATIC_START",
    "PLAY_MOVIE"
  }

  for _, unlockEvent in ipairs(UNLOCK_EVENTS) do
    if event == unlockEvent then
      UnlockFreeLook()
      break
    end
  end

  local LOCK_EVENTS = {
    "CINEMATIC_STOP",
    "STOP_MOVIE"
  }

  for _, lockEvent in ipairs(LOCK_EVENTS) do
    if event == lockEvent then
      LockFreeLook()
      break
    end
  end

  -- Loading Cvars on every reload
  if event == "PLAYER_ENTERING_WORLD" then
    Rematch()
  end

  -- Events responsible for crosshair reaction
  if event == "PLAYER_SOFT_ENEMY_CHANGED" or event == "PLAYER_SOFT_INTERACT_CHANGED" then
    if not HideWhileMounted() then
      HandleCrosshairReactionToTarget(event == "PLAYER_SOFT_ENEMY_CHANGED" and "softenemy" or "softinteract")
    end

    -- Hiding crosshair while mounted
  elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    SetCrosshairAppearance(HideWhileMounted() and "mounted" or "base")

    -- Reseting crosshair when leaving combat
  elseif event == "PLAYER_REGEN_ENABLED" then
    if not HideWhileMounted() then
      SetCrosshairAppearance("base")
    end
  end
end

-- FIRES WHEN GAME STATE CHANGES HAPPEN
local ONUPDATE_INTERVAL = 0.15
local TimeSinceLastUpdate = 0
function _G.CombatMode_OnUpdate(_, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if (TimeSinceLastUpdate >= ONUPDATE_INTERVAL) then
    TimeSinceLastUpdate = 0

    if IsDefaultMouseActionBeingUsed() then
      return
    end

    if ShouldFreeLookBeOff() then
      UnlockFreeLook()
      return
    end

    if not _G.IsMouselooking() then
      LockFreeLook()
    end
  end
end

-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CombatModeToggleKey()
  local state = _G.IsMouselooking()
  ToggleFreeLook(state)
end

function _G.CombatModeHoldKey(keystate)
  local state = keystate == "down"
  ToggleFreeLook(state)
end

-- STANDARD ACE 3 METHODS
-- do init tasks here, like loading the Saved Variables,
-- or setting up slash commands.
function CM:OnInitialize()
  self.DB = AceDB:New("CombatModeDB", CM.Constants.DatabaseDefaults, true)

  AceConfig:RegisterOptionsTable("Combat Mode", CM.Options.ConfigOptions)
  AceConfigDialog:AddToBlizOptions("Combat Mode")
  AceConfig:RegisterOptionsTable("Combat Mode: Advanced", CM.Options.AdvancedConfigOptions)
  AceConfigDialog:AddToBlizOptions("Combat Mode: Advanced", "Advanced", "Combat Mode")

  self:RegisterChatCommand("cm", "OpenConfigCMD")
  self:RegisterChatCommand("combatmode", "OpenConfigCMD")
end

function CM:OnResetDB()
  CM.DebugPrint("Reseting Combat Mode settings.")
  self.DB:ResetDB("Default")
  _G.ReloadUI();
end

-- Do more initialization here, that really enables the use of your addon.
-- Register Events, Hook functions, Create Frames, Get information from
-- the game that wasn't available in OnInitialize
function CM:OnEnable()
  RenameBindableActions()
  CM.OverrideDefaultButtons()
  InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CreateCrosshair()
  CreateTargetMacros()

  -- Registering Blizzard Events from Constants.lua
  for _, event in pairs(CM.Constants.BLIZZARD_EVENTS) do
    self:RegisterEvent(event, _G.CombatMode_OnEvent)
  end

  -- Greeting message that is printed to chat on initial load
  print(CM.Constants.BasePrintMsg .. "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r")

  DisplayPopup()
end

-- Unhook, Unregister Events, Hide frames that you created.
-- You would probably only use an OnDisable if you want to
-- build a "standby" mode, or be able to toggle modules on/off.
function CM:OnDisable()
  CrosshairFrame:Hide()
  self.LoadCVars("blizzard")
  self:UnregisterAllEvents()
end
