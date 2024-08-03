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
local C_AddOns = _G.C_AddOns
local CreateFrame = _G.CreateFrame
local CreateMacro = _G.CreateMacro
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetMacroInfo = _G.GetMacroInfo
local GetUIPanel = _G.GetUIPanel
local InCinematic = _G.InCinematic
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local loadstring = _G.loadstring
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local Narci = _G.Narci
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetModifiedClick = _G.SetModifiedClick
local SetCVar = _G.SetCVar
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
---@class CM : AceAddon
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
_G["CM"] = CM

-- INITIAL STATE VARIABLES
local FreeLookOverride = false -- Changes when Free Look state is modified through user input ("Toggle" or "Press & Hold" keybinds and "/cm" cmd)

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
    "X-Curse"
  }

  for _, key in ipairs(keysToFetch) do
    dataRetuned[string.upper(key)] = C_AddOns.GetAddOnMetadata("CombatMode", key)
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
    print(CM.Constants.BasePrintMsg .. "Cannot open settings while in combat.")
    return
  end

  FreeLookOverride = true
  AceConfigDialog:Open(CM.METADATA["TITLE"])
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
    CM.DebugPrint("Invalid CVarType specified in fn CM.LoadCVars(): " .. tostring(CVarType))
  end

  for name, value in pairs(CVarsToLoad) do
    SetCVar(name, value)
  end
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

local function CenterCursor(shouldCenter)
  if not CM.DB.char.reticleTargeting then
    return
  end
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
  local r, g, b, a = unpack(CM.Constants.CrosshairReactionColors[state])
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false
  local yOffset = CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  local crosshairPositionVariance = 1000 -- from -500 min to 500 max

  -- Adjusts centered cursor vertical positioning
  local cursorCenteredYpos = (yOffset / crosshairPositionVariance) + 0.5 - 0.015
  SetCVar("CursorCenteredYPos", cursorCenteredYpos)

  -- Sets new scale at the end of animation
  CrosshairAnimation:SetScript("OnFinished", function()
    if state ~= "base" then
      CrosshairFrame:SetScale(endingScale)
      CrosshairFrame:SetPoint("CENTER", 0, yOffset / endingScale)
    end
  end)

  CrosshairTexture:SetTexture(textureToUse)
  CrosshairTexture:SetVertexColor(r, g, b, a)
  CrosshairAnimation:Play(reverseAnimation)
  if state == "base" then
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

  local customConditionFunction, error = loadstring(CM.DB.global.customCondition)
  if not customConditionFunction then
    CM.DebugPrint(error)
    return false
  else
    return customConditionFunction()
  end
end

local function IsThirdPartyAddonOpen()
  -- Narci = Narcissus
  local addons = (Narci and Narci.isActive)
  return addons
end

local function IsUnlockFrameVisible()
  local isGenericPanelOpen = (GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center")) and true or false
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function ShouldFreeLookBeOff()
  local evaluate = FreeLookOverride or SpellIsTargeting() or InCinematic() or IsUnlockFrameVisible() or
                     IsCustomConditionTrue() or IsThirdPartyAddonOpen()

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

    if CM.DB.global.crosshair then
      CM.ShowCrosshair()
    end

    CM.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

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
-- Re-locking Free Look & re-setting CVars after reload/portal
local function Rematch()
  if CM.DB.char.reticleTargeting then
    CM.LoadCVars("combatmode")
  end

  if CM.DB.char.crosshairPriority then
    SetCVar("enableMouseoverCast", 1)
    SetModifiedClick("MOUSEOVERCAST", "NONE")
    SaveBindings(GetCurrentBindingSet())
  end

  if CM.DB.global.crosshair then
    SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")
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
    TARGETING_EVENTS = function()
      if not HideCrosshairWhileMounted() then
        HandleCrosshairReactionToTarget(event == "PLAYER_SOFT_ENEMY_CHANGED" and "softenemy" or "softinteract")
      end
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
        return
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

  AceConfig:RegisterOptionsTable(CM.METADATA["TITLE"], CM.Config.ConfigOptions)
  AceConfigDialog:AddToBlizOptions(CM.METADATA["TITLE"])
  AceConfig:RegisterOptionsTable("Combat Mode: Advanced", CM.Config.AdvancedConfigOptions)
  AceConfigDialog:AddToBlizOptions("Combat Mode: Advanced", "Advanced", CM.METADATA["TITLE"])

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
  InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CreateCrosshair()
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
  self.LoadCVars("blizzard")
  self:UnregisterAllEvents()
end
