-- IMPORTS
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- DEVELOPER NOTE
-- You can access the global CM store in any file by calling _G.GetGlobalStore() on a localized CM.
-- Each additional file has its own table within the CM store. Follow this pattern when making changes.
-- Properties from the main CombatMode.lua file are assigned directly to the CM obj.
-- Ex: You can get CustomCVarValues from Constants.lua by referencing the CM.Constants.CustomCVarValues

-- INSTANTIATING ADDON & CREATING FRAME
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
local CrosshairFrame = _G.CreateFrame("Frame", "CombatModeCrosshairFrame", _G.UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")

-- SETTING UP CROSSHAIR ANIMATION
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
local isCursorLockedState = false -- State used to prevent the OnUpdate function from executing code needlessly
local updateInterval = 0.15 -- How often the code in the OnUpdate function will run (in seconds)
local isCursorManuallyUnlocked = false -- True if the user currently has Free Look disabled, whether by using the "Toggle" or "Press & Hold" keybind

-- UTILITY FUNCTIONS
function _G.GetGlobalStore()
  return AceAddon:GetAddon("CombatMode")
end

local function FetchDataFromTOC()
  local keysToFetch = {
    "Version",
    "Title",
    "Notes",
    "Author",
    "X-Discord",
    "X-Curse"
  }
  local dataRetuned = {}

  for _, key in ipairs(keysToFetch) do
    dataRetuned[string.upper(key)] = _G.C_AddOns.GetAddOnMetadata("CombatMode", key)
  end

  return dataRetuned
end

CM.METADATA = FetchDataFromTOC()

function CM.DebugPrint(statement)
  if CM.DB.global.debugMode then
    print(
      CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r|cff909090: " .. tostring(statement) ..
        "|r")
  end
end

function CM.LoadReticleTargetCVars()
  for name, value in pairs(CM.Constants.CustomCVarValues) do
    _G.SetCVar(name, value)
  end

  CM.DebugPrint("Reticle Target CVars LOADED")
end

function CM.LoadBlizzardDefaultCVars()
  for name, value in pairs(CM.Constants.BlizzardCVarValues) do
    _G.SetCVar(name, value)
  end

  CM.DebugPrint("Reticle Target CVars RESET")
end

local function CreateTargetMacros()
  local doesClearTargetMacroExist = _G.GetMacroInfo("CM_ClearTarget")
  if not doesClearTargetMacroExist then
    _G.CreateMacro("CM_ClearTarget", "INV_MISC_QUESTIONMARK", "/stopmacro [noexists]\n/cleartarget", false);
  end

  local doesClearFocusMacroExist = _G.GetMacroInfo("CM_ClearFocus")
  if not doesClearFocusMacroExist then
    _G.CreateMacro("CM_ClearFocus", "INV_MISC_QUESTIONMARK", "/clearfocus", false);
  end

  local doesTargetCrosshairMacroExist = _G.GetMacroInfo("CM_TargetCrosshair")
  if not doesTargetCrosshairMacroExist then
    _G.CreateMacro("CM_TargetCrosshair", "INV_MISC_QUESTIONMARK", "/target [@mouseover,harm,nodead]\n/startattack", false);
  end
end

-- If left or right mouse buttons are being used while not free looking - meaning you're using the default mouse actions - then it won't allow you to lock into Free Look.
-- This prevents the auto running bug.
local function IsDefaultMouseActionBeingUsed()
  -- disabling this here cause linting doesn't know what it wants here
  ---@diagnostic disable-next-line: param-type-mismatch
  return _G.IsMouseButtonDown("LeftButton") or _G.IsMouseButtonDown("RightButton")
end

local function CenterCursor(shouldCenter)
  local isReticleTargetingActive = CM.DB.global.reticleTargeting
  if shouldCenter and isReticleTargetingActive then
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
  local yOffset = CM.DB.global.crosshairY or 100
  -- Adjusts centered cursor vertical positioning
  local cursorCenteredYpos = (yOffset / 1000) + 0.5 - 0.015
  _G.SetCVar("CursorCenteredYPos", cursorCenteredYpos)

  -- Sets new scale at the end of animation
  CrosshairAnimation:SetScript("OnFinished", function()
    if state == "hostile" or state == "friendly" then
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
  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or 100)
  CrosshairFrame:SetSize(CM.DB.global.crosshairSize or 64, CM.DB.global.crosshairSize or 64)
  CrosshairFrame:SetAlpha(CM.DB.global.crosshairOpacity or 1.0)
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
  local isTargetVisible = _G.UnitIsVisible(target)
  local reaction = _G.UnitReaction("player", target)
  local isTargetHostile = reaction and reaction <= 4
  local isTargetFriendly = reaction and reaction >= 5

  if isTargetVisible then
    SetCrosshairAppearance(isTargetHostile and "hostile" or isTargetFriendly and "friendly" or "base")
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
        isCursorLockedState = false
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

local function ShouldCursorBeFreed()
  local shouldLock = not isCursorLockedState
  local shouldUnlock = isCursorManuallyUnlocked or _G.SpellIsTargeting() or _G.InCinematic() or
                         CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or
                         CursorUnlockFrameVisible(CM.DB.global.watchlist) or
                         CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or IsCustomConditionTrue() or
                         HasNarcissusOpen()

  return shouldUnlock, shouldLock
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

    isCursorLockedState = true
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

    isCursorLockedState = false
    CM.DebugPrint("Free Look Disabled")
  end
end

local function ToggleFreeLook()
  if not _G.IsMouselooking() then
    LockFreeLook()
  elseif _G.IsMouselooking() then
    UnlockFreeLook()
  end
end

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  if not _G.InCombatLockdown() and not input or input:trim() == "" then
    UnlockFreeLook()
    isCursorManuallyUnlocked = true
    AceConfigDialog:Open("Combat Mode")
  else
    AceConfigCmd.HandleCommand(self, "mychat", "Combat Mode", input)
  end
end

-- STANDARD ACE 3 METHODS
-- do init tasks here, like loading the Saved Variables,
-- or setting up slash commands.
function CM:OnInitialize()
  self.DB = AceDB:New("CombatModeDB", CM.Options.DatabaseDefaults, true)

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
  print(CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r" ..
          "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r")
end

-- Unhook, Unregister Events, Hide frames that you created.
-- You would probably only use an OnDisable if you want to
-- build a "standby" mode, or be able to toggle modules on/off.
function CM:OnDisable()
  self.LoadBlizzardDefaultCVars()
end

-- Re-locking Free Look & re-setting CVars after reload/portal
local function Rematch()
  local isReticleTargetingActive = CM.DB.global.reticleTargeting
  local isCrosshairPriorityActive = CM.DB.global.crosshairPriority

  if isReticleTargetingActive then
    CM.LoadReticleTargetCVars()
  end

  if isCrosshairPriorityActive then
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
      HandleCrosshairReactionToTarget(event == "PLAYER_SOFT_ENEMY_CHANGED" and "softenemy" or "softinteract") -- if we use "mouseover" the corsshair will jitter like crazy because of blizzard's weird and inconsistent hitboxes
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
function _G.CombatMode_OnUpdate(self, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if (self.TimeSinceLastUpdate > updateInterval) and not IsDefaultMouseActionBeingUsed() then
    local shouldUnlock, shouldLock = ShouldCursorBeFreed()
    if shouldUnlock then
      UnlockFreeLook()
    elseif shouldLock then
      LockFreeLook()
    end

    self.TimeSinceLastUpdate = 0;
  end
end

-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CombatModeToggleKey()
  if IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  ToggleFreeLook()
  isCursorManuallyUnlocked = not isCursorManuallyUnlocked
end

function _G.CombatModeHoldKey(keystate)
  if IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  if keystate == "down" then
    UnlockFreeLook()
    isCursorManuallyUnlocked = true
  else
    LockFreeLook()
    isCursorManuallyUnlocked = false
  end
end
