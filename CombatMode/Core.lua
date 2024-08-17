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

-- CACHING GLOBAL VARIABLES
-- Slightly better performance than doing a global lookup every time
local CreateFrame = _G.CreateFrame
local CreateMacro = _G.CreateMacro
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
local GetAuraDataBySpellName = _G.C_UnitAuras.GetAuraDataBySpellName
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetCursorPosition = _G.GetCursorPosition
local GetMacroInfo = _G.GetMacroInfo
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
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitReaction = _G.UnitReaction
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

local function OpenConfigPanel()
  if InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end
  OpenToCategory(CM.METADATA["TITLE"])
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

local function CreateTargetMacros()
  local macroExists = function(name)
    return GetMacroInfo(name) ~= nil
  end

  local function createMacroIfNotExists(macroName, icon, macroText)
    if not macroExists(macroName) then
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

--[[
  Checking if DynamicCam is loaded so we can relinquish control of a few camera features
  as DynamicCam allows fine-grained control of Mouselook Speed & Target Focus
]] --
local function IsDCLoaded()
  local DC = AceAddon:GetAddon("DynamicCam", true)
  CM.DynamicCam = DC ~= nil and true or false
  if CM.DynamicCam then
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

  CM.HandleFriendlyTargeting()
end

function CM.HandleFriendlyTargeting()
  if CM.DB.char.reticleTargeting and CM.DB.char.friendlyTargeting then
    if not UnitAffectingCombat("player") or CM.DB.char.friendlyTargetingInCombat then
      CM.DebugPrint("Enabling Friendly Targeting")
      SetCVar("SoftTargetFriend", 3)
    else
      CM.DebugPrint("Disabling Friendly Targeting")
      SetCVar("SoftTargetFriend", 0)
    end
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
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.TagetFocusCVarValues,
    BlizzValues = CM.Constants.BlizzardTagetFocusCVarValues,
    FeatureName = "Sticky Crosshair"
  }

  LoadCVars(info)
end

function CM.SetMouseLookSpeed()
  local XSpeed = CM.DB.global.mouseLookSpeed
  local YSpeed = CM.DB.global.mouseLookSpeed / 2 -- Blizz wants pitch speed as 1/2 of yaw speed
  SetCVar("cameraYawMoveSpeed", XSpeed)
  SetCVar("cameraPitchMoveSpeed", YSpeed)
end

function CM.SetShoulderOffset()
  local offset = CM.DB.char.shoulderOffset
  SetCVar("test_cameraOverShoulder", offset)
end

function CM.SetCrosshairPriority()
  SetCVar("enableMouseoverCast", 1)
  SetModifiedClick("MOUSEOVERCAST", "NONE")
  SaveBindings(GetCurrentBindingSet())
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

---------------------------------------------------------------------------------------
--                           CROSSHAIR HANDLING FUNCTIONS                            --
---------------------------------------------------------------------------------------
-- SETTING UP CROSSHAIR FRAME & ANIMATION
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)
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
      CrosshairFrame:SetScale(endingScale)
      CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos / endingScale)
    end
  end)

  CrosshairTexture:SetTexture(textureToUse)
  CrosshairTexture:SetVertexColor(r, g, b, a)
  CrosshairAnimation:Play(reverseAnimation)
  if state == "base" then
    CrosshairFrame:SetScale(startingScale)
    CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  end
end

function CM.ShowCrosshair()
  CrosshairTexture:Show()
end

function CM.HideCrosshair()
  CrosshairTexture:Hide()
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

local function HandleCrosshairReactionToTarget(target)
  local isTargetVisible = (UnitExists(target) and UnitGUID(target)) and true or false
  local reaction = UnitReaction("player", target)
  local isTargetHostile = reaction and reaction <= 4
  local isTargetFriendly = reaction and reaction >= 5
  local isTargetObject = UnitIsGameObject(target)

  if isTargetVisible then
    SetCrosshairAppearance(isTargetHostile and "hostile" or isTargetFriendly and "friendly" or "base")
  elseif isTargetObject then
    SetCrosshairAppearance("object")
  else
    SetCrosshairAppearance("base")
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
      CM.DebugPrint(frameName .. " is visible, preventing re-locking.")
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

  local customConditionFunction, error = loadstring("return " .. CM.DB.global.customCondition)
  if not customConditionFunction then
    CM.DebugPrint(error)
    return false
  else
    return customConditionFunction()
  end
end

local function IsVendorMountOut()
  if not CM.DB.global.mountCheck then
    return false
  end

  local function checkMount(mount)
    return GetAuraDataBySpellName("player", mount, "HELPFUL") ~= nil
  end

  for _, mount in ipairs(CM.Constants.MountsToCheck) do
    if checkMount(mount) then
      return true
    end
  end

  return false
end

local function IsUnlockFrameVisible()
  local isGenericPanelOpen = (GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center")) and true or false
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function ShouldFreeLookBeOff()
  local evaluate = FreeLookOverride or SpellIsTargeting() or InCinematic() or IsInCinematicScene() or
                     IsUnlockFrameVisible() or IsCustomConditionTrue() or IsVendorMountOut()

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
  if buttonSettings.value == "CUSTOMACTION" then
    valueToUse = buttonSettings.customAction
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
local function LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    CenterCursor(true)
    GameTooltip:SetScript("OnShow", GameTooltip.Hide)

    if CM.DB.global.crosshair then
      CM.ShowCrosshair()
    end

    CM.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if IsMouselooking() then
    GameTooltip:SetScript("OnShow", GameTooltip.Show)
    CenterCursor(false)
    MouselookStop()

    if CM.DB.global.pulseCursor then
      ShowCursorPulse()
    end

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

---------------------------------------------------------------------------------------
--                                   EVENT HANDLING                                  --
---------------------------------------------------------------------------------------
-- Rematch is called after every reload and this is where we make sure our config persists
local function Rematch()
  CM.SetMouseLookSpeed()

  if CM.DB.global.actionCamera then
    CM.ConfigActionCamera("combatmode")
    CM.SetShoulderOffset()
  end

  if CM.DB.char.reticleTargeting then
    CM.ConfigReticleTargeting("combatmode")

    if CM.DB.char.crosshairPriority then
      CM.SetCrosshairPriority()
    end
  end

  if CM.DB.global.crosshair then
    SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
  elseif CM.DB.global.crosshair == false then
    CM.HideCrosshair()
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
      IsDCLoaded()
    end,
    TARGETING_EVENTS = function()
      if not HideCrosshairWhileMounted() then
        HandleCrosshairReactionToTarget(event == "PLAYER_SOFT_ENEMY_CHANGED" and "softenemy" or "softinteract")
      end
    end,
    FRIENDLY_TARGETING_EVENTS = function()
      CM.HandleFriendlyTargeting()
    end,
    UNCATEGORIZED_EVENTS = function()
      SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")
    end
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

    if not IsMouselooking() then
      LockFreeLook()
    end
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

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  if not input or input:trim() == "" then
    OpenConfigPanel()
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

  -- Registering Blizzard Events from Constants.lua
  for _, events_to_register in pairs(CM.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(events_to_register) do
      self:RegisterEvent(event, _G.CombatMode_OnEvent)
    end
  end

  -- Greeting message that is printed to chat on initial load
  print(CM.Constants.BasePrintMsg .. "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r")

  DisplayPopup()
end

--[[
Unhook, Unregister Events, Hide frames that you created.
You would probably only use an OnDisable if you want to
build a "standby" mode, or be able to toggle modules on/off.
]] --
function CM:OnDisable()
  CrosshairFrame:Hide()
  self.ConfigReticleTargeting("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.ConfigActionCamera("blizzard")
  self:UnregisterAllEvents()
end
