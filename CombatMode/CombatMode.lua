-- IMPORTS
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- DEVELOPER NOTE
-- You can access the global CM store in any file by calling _G.GetGlobalStore() on a localized CM.
-- Each additional file has its own object within the CM store. Follow this pattern when making changes.
-- Properties from the main CombatMode.lua file are assigned directly to the CM obj.
-- Ex: You can get CustomCVarValues from Constants.lua by referencing the CM.Constants.CustomCVarValues

-- INSTANTIATING ADDON & CREATING FRAME
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
local CrosshairFrame = _G.CreateFrame("Frame", "CombatModeCrosshairFrame", _G.UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")

-- INITIAL STATE VARIABLES
local isCursorLockedState = false -- State used to prevent the OnUpdate function from executing code needlessly
local updateInterval = 0.15 -- How often the code in the OnUpdate function will run (in seconds)
local debugMode = false -- If true, CM.DebugPrint will run and print state logs to game chat

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
  if debugMode then
    print(CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r: " .. tostring(statement))
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
end

-- CROSSHAIR STATE HANDLING FUNCTIONS
local function SetCrosshairAppearance(state)
  if state == "hostile" then
    CrosshairTexture:SetTexture(CM.Constants.CrosshairActiveTexture)
    CrosshairTexture:SetVertexColor(1, .2, 0.3, 1)
  elseif state == "friendly" then
    CrosshairTexture:SetTexture(CM.Constants.CrosshairActiveTexture)
    CrosshairTexture:SetVertexColor(0, 1, 0.3, .8)
  else -- "base" falls here
    CrosshairTexture:SetTexture(CM.Constants.CrosshairTexture)
    CrosshairTexture:SetVertexColor(1, 1, 1, .5)
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
end

local function HandleCrosshairReactionToTarget(target)
  local isTargetVisible = _G.UnitIsVisible(target)
  local isTargetHostile = _G.UnitReaction("player", target) and _G.UnitReaction("player", target) <= 4
  local isTargetAPlayer = _G.UnitPlayerControlled(target)

  if not isTargetVisible or isTargetAPlayer then
    return SetCrosshairAppearance("base")
  end

  if isTargetHostile then
    SetCrosshairAppearance("hostile")
  else
    SetCrosshairAppearance("friendly")
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
           CursorUnlockFrameGroupVisible(CM.Constants.WildcardFramesToCheck) or _G.SpellIsTargeting()
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

local function OverrideDefaultButtons()
  for _, button in pairs(CM.Constants.ButtonsToOverride) do
    CM.SetNewBinding(CM.DB.profile.bindings[button])
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

-- Re-locking Free Look & re-setting CVars after reload/portal
local function Rematch()
  local isReticleTargetingActive = CM.DB.global.reticleTargeting
  if isReticleTargetingActive then
    CM.LoadReticleTargetCVars()
  end
  ToggleFreeLook()
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

-- STANDARD ACE 3 METHODS
-- Code that you want to run when the addon is first loaded goes here.
function CM:OnInitialize()
  self.DB = AceDB:New("CombatModeDB")
  AceConfig:RegisterOptionsTable("Combat Mode", CM.Options.ConfigOptions)
  self.OPTIONS = AceConfigDialog:AddToBlizOptions("Combat Mode", "Combat Mode")
  self:RegisterChatCommand("cm", "OpenConfigCMD")
  self:RegisterChatCommand("combatmode", "OpenConfigCMD")
  self.DB = AceDB:New("CombatModeDB", CM.Options.DatabaseDefaults, true)
end

-- Called when the addon is enabled
function CM:OnEnable()
  RenameBindableActions()
  OverrideDefaultButtons()
  InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CreateCrosshair()
  CreateTargetMacros()

  -- Registering Blizzard Events from Constants.lua
  for _, event in pairs(CM.Constants.BLIZZARD_EVENTS) do
    self:RegisterEvent(event, _G.CombatMode_OnEvent)
  end
end

-- Called when the addon is disabled
function CM:OnDisable()
  self.LoadBlizzardDefaultCVars()
end

-- FIRES WHEN SPECIFIC EVENTS HAPPEN IN GAME
function _G.CombatMode_OnEvent(event)
  if event == "PLAYER_SOFT_ENEMY_CHANGED" then
    HandleCrosshairReactionToTarget("softenemy")
  end

  if event == "PLAYER_SOFT_FRIEND_CHANGED" then
    HandleCrosshairReactionToTarget("softfriend")
  end

  if event == "PLAYER_SOFT_INTERACT_CHANGED" then
    HandleCrosshairReactionToTarget("softinteract")
  end

  if event == "PLAYER_ENTERING_WORLD" then
    Rematch()
    print(CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r" ..
            "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r")
  end
end

-- FIRES WHEN GAME STATE CHANGES HAPPEN
function _G.CombatMode_OnUpdate(self, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;

  -- Bypassing the update cycle check when spell targeting so we can relock asap, without adding latency to player actions
  if _G.SpellIsTargeting() then
    UnlockFreeLook()
    isCursorLockedState = false
    return
  end

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if (self.TimeSinceLastUpdate > updateInterval) then
    if SuspendingCursorLock() then
      UnlockFreeLook()
      isCursorLockedState = false
    elseif not isCursorLockedState then
      LockFreeLook()
      isCursorLockedState = true
    end

    self.TimeSinceLastUpdate = 0;
  end
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
