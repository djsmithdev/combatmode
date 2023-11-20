-- IMPORTS
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- DEVELOPER NOTE
-- You can access the global CM store in any file by calling _G.GetGlobalStore()
-- Each file has its own separate object within the CM store. And ideally you'd follow that pattern.
-- Properties from the main CombatMode.lua file are assigned directly to the CM obj.
-- Ex: You can get info from Constants.lua by referencing CM.Constants

-- INSTANTIATING ADDON & CREATING FRAME
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
local CrosshairFrame = _G.CreateFrame("Frame", "CombatModeCrosshairFrame", _G.UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")

-- INITIAL STATE VARIABLES
local isCursorLocked = false
local lastStateUpdateTime = 0
local debugMode = false

-- UTILITY FUNCTIONS
function _G.GetGlobalStore()
  return AceAddon:GetAddon("CombatMode")
end

function CM.DebugPrint(statement)
  if debugMode then
    print("|cffff0000Combat Mode:|r " .. statement)
  end
end

local function CreateTargetMacros()
  local doesClearTargetMacroExist = _G.GetMacroInfo("CM_ClearTarget")
  if not doesClearTargetMacroExist then
    _G.CreateMacro("CM_ClearTarget", "INV_MISC_QUESTIONMARK", "/stopmacro [noexists]\n/cleartarget", false);
  end

  local doesClearFocusMacroExist = _G.GetMacroInfo("CM_ClearFocus")
  if not doesClearFocusMacroExist then
    _G.CreateMacro("CM_ClearFocus", "INV_MISC_QUESTIONMARK", "/stopmacro [noexists]\n/clearfocus", false);
  end
end

-- CROSSHAIR STATE HANDLING FUNCTIONS
local function BaseCrosshairState()
  local crossBase = "Interface\\AddOns\\CombatMode\\assets\\crosshair.tga"
  CrosshairTexture:SetTexture(crossBase)
  CrosshairTexture:SetVertexColor(1, 1, 1, .5)
end

local function HostileCrosshairState()
  local crossHit = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"
  CrosshairTexture:SetTexture(crossHit)
  CrosshairTexture:SetVertexColor(1, .2, 0.3, 1)
end

local function FriendlyCrosshairState()
  local crossHit = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"
  CrosshairTexture:SetTexture(crossHit)
  CrosshairTexture:SetVertexColor(0, 1, 0.3, .8)
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
  BaseCrosshairState()

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
end

local function CrosshairReactToTarget(target)
  local isTargetVisible = _G.UnitIsVisible(target)
  local isTargetHostile = _G.UnitReaction("player", target) and _G.UnitReaction("player", target) <= 4

  if isTargetVisible then
    if isTargetHostile then
      HostileCrosshairState()
    else
      FriendlyCrosshairState()
    end
  else
    BaseCrosshairState()
  end
end

-- FRAME WATCHING
local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G.getglobal(frameName)
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      -- CM.DebugPrint(frameName .. " is visible, enabling cursor")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for _, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      return true
    end
  end
end

local function SuspendingCursorLock()
  return CursorUnlockFrameVisible(CM.Constants.FramesToCheck) or CursorUnlockFrameVisible(CM.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CM.Constants.wildcardFramesToCheck) or _G.SpellIsTargeting()
end

-- FRAME WATCHING FOR SERIALIZED FRAMES (Ex: Opie rings)
local function InitializeWildcardFrameTracking(frameArr)
  CM.DebugPrint("Looking for wildcard frames...")

  -- Initialise the table by going through ALL available globals once and keeping the ones that match
  for _, frameNameToFind in pairs(frameArr) do
    CM.Constants.wildcardFramesToCheck[frameNameToFind] = {}

    for frameName in pairs(_G) do
      if string.match(frameName, frameNameToFind) then
        CM.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
        local frameGroup = CM.Constants.wildcardFramesToCheck[frameNameToFind]
        frameGroup[#frameGroup + 1] = frameName
      end
    end
  end

  CM.DebugPrint("Wildcard frames initialized")
end

-- OVERRIDE BUTTONS
function CM.SetNewBinding(buttonSettings)
  local valueToUse
  if buttonSettings.value == CM.Constants.overrideActions.MACRO then
    valueToUse = "MACRO " .. buttonSettings.macro
  elseif buttonSettings.value == CM.Constants.overrideActions.CLEARTARGET then
    valueToUse = "MACRO CM_ClearTarget"
  elseif buttonSettings.value == CM.Constants.overrideActions.CLEARFOCUS then
    valueToUse = "MACRO CM_ClearFocus"
  else
    valueToUse = buttonSettings.value
  end
  _G.SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

local function OverrideDefaultButtons()
  for _, button in pairs(CM.Constants.buttonsToOverride) do
    CM.SetNewBinding(CM.DB.profile.bindings[button])
  end
end

function CM.ResetBindingOverride(buttonSettings)
  _G.SetMouselookOverrideBinding(buttonSettings.key, nil)
  CM.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- FREE LOOK STATE HANDLING
local function LockFreeLook()
  if not _G.IsMouselooking() or not SuspendingCursorLock() then
    _G.MouselookStart()

    if CM.DB.global.crosshair then
      CM.ShowCrosshair()
    end

    CM.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if _G.IsMouselooking() then
    _G.MouselookStop()

    if CM.DB.global.crosshair then
      CM.HideCrosshair()
    end

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

-- Relocking Free Look & setting CVars after reload/portal
local function Rematch()
  local isReticleTargetingActive = CM.DB.global.reticleTargeting
  if isReticleTargetingActive then
    CM.Constants.loadReticleTargetCvars()
  end
  ToggleFreeLook()
end

-- UpdateState will be fired when changes in game state happen
-- Responsible for unlocking Free Look when opening frames & casting targeting spells
local function UpdateState()
  -- Calling this without the delay so we don't add latency to player actions
  if _G.SpellIsTargeting() then
    UnlockFreeLook()
    isCursorLocked = false
    return
  end

  local currentTime = _G.GetTime()
  if currentTime - lastStateUpdateTime < .15 then
    return
  end
  lastStateUpdateTime = currentTime

  if SuspendingCursorLock() then
    UnlockFreeLook()
    isCursorLocked = false
  elseif not isCursorLocked then
    LockFreeLook()
    isCursorLocked = true
  end
end

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  ToggleFreeLook()
  if not input or input:trim() == "" then
    AceConfigDialog:Open("Combat Mode")
  else
    AceConfigCmd.HandleCommand(self, "mychat", "Combat Mode", input)
  end
end

-- INITIALIZING DEFAULT CONFIG
function CM:OnInitialize()
  self.DB = AceDB:New("CombatModeDB")
  AceConfig:RegisterOptionsTable("Combat Mode", CM.Options.configOptions)
  self.OPTIONS = AceConfigDialog:AddToBlizOptions("Combat Mode", "Combat Mode")
  self:RegisterChatCommand("cm", "OpenConfigCMD")
  self:RegisterChatCommand("combatmode", "OpenConfigCMD")
  self.DB = AceDB:New("CombatModeDB", CM.Options.databaseDefaults, true)
end

-- LOADING ADDON IN
function CM:OnEnable()
  OverrideDefaultButtons()
  InitializeWildcardFrameTracking(CM.Constants.wildcardFramesToMatch)
  CreateCrosshair()
  CreateTargetMacros()

  -- Registering Blizzard Events from Constants.lua
  for _, event in pairs(CM.Constants.BLIZZARD_EVENTS) do
    self:RegisterEvent(event, _G.CombatMode_OnEvent)
  end
end

-- FIRES WHEN SPECIFIC EVENTS HAPPEN IN GAME
function _G.CombatMode_OnEvent(event)
  if not SuspendingCursorLock() then
    if event == "PLAYER_SOFT_ENEMY_CHANGED" then
      CrosshairReactToTarget("target")
    end

    if event == "PLAYER_SOFT_INTERACT_CHANGED" then
      CrosshairReactToTarget("softInteract")
    end
  end

  if event == "PLAYER_ENTERING_WORLD" then
    Rematch()
    print("|cffff0000Combat Mode:|r |cff909090 Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings |r")
  end
end

-- FIRES WHEN GAME STATE CHANGES HAPPEN
function _G.CombatMode_OnUpdate()
  UpdateState()
end

-- FIRES WHEN ADDON IS LOADED
function _G.CombatMode_OnLoad()
  CM.DebugPrint("ADDON LOADED")
end

-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CombatModeToggleKey()
  ToggleFreeLook()
end

function _G.CombatModeHoldKey(keystate)
  if keystate == "down" then
    UnlockFreeLook()
  else
    LockFreeLook()
  end
end
