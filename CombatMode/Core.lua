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
local C_Spell = _G.C_Spell
local GetActionInfo = _G.GetActionInfo
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
local C_ActionBar = _G.C_ActionBar
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
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding
local strtrim = _G.strtrim
local ClearOverrideBindings = _G.ClearOverrideBindings
local SetOverrideBindingClick = _G.SetOverrideBindingClick
local SpellIsTargeting = _G.SpellIsTargeting
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local UIParent = _G.UIParent
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
("Toggle / Hold" keybind and "/cm" cmd)
]] --
local FreeLookOverride = false
local CursorModeShowTime = 0 -- GetTime() when cursor was unlocked via keybind (for spurious key-up filter)

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

  -- Dismiss healing radial if active (opening config panel should close radial)
  if CM.HealingRadial and CM.HealingRadial.IsActive and CM.HealingRadial.IsActive() then
    CM.HealingRadial.Hide()
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

-- Disabling this for now while we're testing the new macro wrapper implementation for targeting
-- function CM.HandleMouseoverCasting(enabled)
--   if ON_RETAIL_CLIENT == false then
--     return
--   end
--   if enabled then
--     SetCVar("enableMouseoverCast", 1)
--     SetModifiedClick("MOUSEOVERCAST", "NONE")
--     SaveBindings(GetCurrentBindingSet())
--     CM.DebugPrint("Enabling Crosshair Priority")
--   else
--     SetCVar("enableMouseoverCast", 0)
--     CM.DebugPrint("Disabling Crosshair Priority")
--   end
-- end

function CM.HandleSoftTargetFriend(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
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
  -- self.HandleMouseoverCasting(false)
  self.HandleSoftTargetFriend(false)

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
  -- Show texture when not in mounted state (mounted state has alpha 0, so texture visibility doesn't matter)
  if state ~= "mounted" and IsMouselooking() then
    CrosshairTexture:Show()
  end
  CrosshairAnimation:Play(reverseAnimation)
  if state == "base" then
    CrosshairFrame:SetScale(STARTING_SCALE)
    CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  end
end

function CM.DisplayCrosshair(shouldShow)
  if shouldShow then
    CrosshairTexture:Show()
    -- Restore frame opacity from config so crosshair is not left dimmed by lock-in animation
    local DefaultConfig = CM.Constants.DatabaseDefaults.global
    local UserConfig = CM.DB.global or {}
    local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
    CrosshairFrame:SetAlpha(crosshairOpacity)
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
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  CrosshairFrame:SetSize(crosshairSize, crosshairSize)
  CrosshairFrame:SetAlpha(crosshairOpacity)

  SetCrosshairAppearance("base")
  AdjustCenteredCursorYPos(crosshairYPos)
end

-- Debug crosshair: shows a texture at the cursor position while in mouselook (when debug mode is on),
-- so you can verify the cursor is being moved to the crosshair position.
local DebugCrosshairFrame = CreateFrame("Frame", "CombatModeDebugCrosshairFrame", UIParent)
DebugCrosshairFrame:SetFrameStrata("DIALOG")
DebugCrosshairFrame:SetFrameLevel(0)
local DebugCrosshairTexture = DebugCrosshairFrame:CreateTexture(nil, "OVERLAY")
DebugCrosshairTexture:SetTexture("Interface\\AddOns\\CombatMode\\assets\\crosshairX.blp")
DebugCrosshairTexture:SetAllPoints(DebugCrosshairFrame)
DebugCrosshairTexture:SetBlendMode("BLEND")
DebugCrosshairTexture:SetVertexColor(0, 1, 0, 1) -- green so it's obvious it's the cursor-position marker
DebugCrosshairFrame:SetAlpha(0.8)
DebugCrosshairFrame:Hide()

local DebugCrosshairUpdater = CreateFrame("Frame", nil, UIParent)
DebugCrosshairUpdater:SetScript("OnUpdate", function()
  if not (CM.DB.global and CM.DB.global.debugMode) then
    DebugCrosshairFrame:Hide()
    return
  end
  if IsMouselooking() then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    DebugCrosshairFrame:ClearAllPoints()
    DebugCrosshairFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    local size = (CM.DB.global.crosshairSize) or (CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global and CM.Constants.DatabaseDefaults.global.crosshairSize) or 64
    DebugCrosshairFrame:SetSize(size, size)
    DebugCrosshairFrame:Show()
  else
    DebugCrosshairFrame:Hide()
  end
end)

-- Track the last known appearance state to prevent unnecessary updates
local lastKnownAppearanceState = nil

-- Get the reaction type for a given unitID
-- Returns: reactionType string ("hostile", "friendly_player", "friendly_npc", "neutral", "object", "base")
local function GetUnitReactionType(unitID)
  if not unitID then
    return "base"
  end

  -- Check if unit exists and has a GUID
  if not UnitExists(unitID) or not UnitGUID(unitID) then
    return "base"
  end

  -- Check for game object first
  local isTargetObject = UnitIsGameObject(unitID)
  if isTargetObject then
    return "object"
  end

  -- Get reaction value
  local reaction = UnitReaction("player", unitID)
  if not reaction then
    return "base"
  end

  -- Determine reaction type based on reaction value and unit type
  if UnitIsPlayer(unitID) then
    if UnitCanAttack("player", unitID) then
      return "hostile"
    else
      return "friendly_player"
    end
  elseif reaction <= 4 then
    return "hostile"
  elseif reaction >= 5 then
    return "friendly_npc"
  else
    return "neutral"
  end
end

-- Get the unit under the cursor and its reaction type for crosshair reactions
local function GetUnitUnderCursor()
  -- Check for game object interaction first using softinteract
  local isTargetObject = UnitIsGameObject("softinteract")
  if isTargetObject then
    return "softinteract", "object"
  end

  -- If not a game object, check for regular units using mouseover
  if UnitExists("mouseover") and UnitGUID("mouseover") then
    local reactionType = GetUnitReactionType("mouseover")
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

  -- Check for focus target first (highest priority)
  local hasFocus = UnitExists("focus")

  local currentUnit, currentReaction = GetUnitUnderCursor()

  -- Determine the appearance state: focus takes priority over unit under cursor
  local appearanceState
  if hasFocus then
    appearanceState = "focus"
  elseif currentUnit then
    appearanceState = currentReaction or "base"
  else
    appearanceState = "base"
  end

  -- Only update if the appearance state actually changed (prevents scale animations when mouseover changes while focus is active)
  if appearanceState ~= lastKnownAppearanceState then
    lastKnownAppearanceState = appearanceState
    SetCrosshairAppearance(appearanceState)
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

function CM.ShowCursorPulse()
  PULSE_TOTAL_ELAPSED = 0
  PulseFrame:Show()
end

PulseFrame:SetScript("OnUpdate", UpdatePulse)

---------------------------------------------------------------------------------------
--                            CROSSHAIR LOCK-IN ANIMATION                             --
---------------------------------------------------------------------------------------
local LOCK_IN_DURATION = 0.25 -- duration of lock-in animation
local LOCK_IN_STARTING_SCALE = 1.3 -- start larger, snap down to 1.0
local LOCK_IN_STARTING_ALPHA = 0.0 -- start invisible, fade in
local LOCK_IN_TOTAL_ELAPSED = -1 -- -1 = idle, 0+ = animating
local LOCK_IN_TARGET_SCALE = 1.0 -- what scale to animate toward
local LOCK_IN_TARGET_ALPHA = 1.0 -- target alpha (full opacity)
local LOCK_IN_ORIGINAL_Y_POS = 0 -- configured crosshair Y (visual position at scale 1.0)

local function UpdateCrosshairLockIn(_, elapsed)
  if LOCK_IN_TOTAL_ELAPSED == -1 then
    return
  end

  LOCK_IN_TOTAL_ELAPSED = LOCK_IN_TOTAL_ELAPSED + elapsed

  if LOCK_IN_TOTAL_ELAPSED >= LOCK_IN_DURATION then
    -- Lock-in animation complete
    LOCK_IN_TOTAL_ELAPSED = -1
    CrosshairFrame:SetScale(LOCK_IN_TARGET_SCALE)
    CrosshairFrame:SetAlpha(LOCK_IN_TARGET_ALPHA)
    local finalYPos = LOCK_IN_ORIGINAL_Y_POS / LOCK_IN_TARGET_SCALE
    CrosshairFrame:SetPoint("CENTER", 0, finalYPos)
    return
  end

  local progress = LOCK_IN_TOTAL_ELAPSED / LOCK_IN_DURATION
  progress = math.max(0, math.min(1, progress))
  local easedProgress = 1 - (1 - progress) * (1 - progress)

  local currentScale = LOCK_IN_STARTING_SCALE + (LOCK_IN_TARGET_SCALE - LOCK_IN_STARTING_SCALE) * easedProgress
  currentScale = math.max(0.01, currentScale)
  CrosshairFrame:SetScale(currentScale)

  local currentAlpha = LOCK_IN_STARTING_ALPHA + (LOCK_IN_TARGET_ALPHA - LOCK_IN_STARTING_ALPHA) * easedProgress
  CrosshairFrame:SetAlpha(currentAlpha)

  CrosshairFrame:SetPoint("CENTER", 0, LOCK_IN_ORIGINAL_Y_POS / currentScale)
end

function CM.ShowCrosshairLockIn()
  if not CM.DB.global.crosshair then
    return
  end

  CrosshairTexture:Show()
  local crosshairYPos = CM.DB.global.crosshairY or 0
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local configuredOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  -- Start from current visual state so rapid re-triggers don't jump; always animate TO configured rest state
  -- so stacking (lock/unlock many times quickly) doesn't leave crosshair dimmed or wrong scale.
  local currentScale = CrosshairFrame:GetScale()
  LOCK_IN_ORIGINAL_Y_POS = crosshairYPos
  LOCK_IN_STARTING_SCALE = currentScale * 1.3
  LOCK_IN_STARTING_ALPHA = 0.0
  LOCK_IN_TARGET_SCALE = 1.0
  LOCK_IN_TARGET_ALPHA = configuredOpacity

  CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos / LOCK_IN_STARTING_SCALE)
  CrosshairFrame:SetScale(LOCK_IN_STARTING_SCALE)
  CrosshairFrame:SetAlpha(LOCK_IN_STARTING_ALPHA)

  LOCK_IN_TOTAL_ELAPSED = 0
end

-- Hook into crosshair frame's OnUpdate (reuse existing or add to it)
CrosshairFrame:SetScript("OnUpdate", function(self, elapsed)
  UpdateCrosshairLockIn(self, elapsed)
end)

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

-- House Editor (housing) is active; do not override action bar keys so housing bindings (e.g. R to return item) work.
local function IsHouseEditorActive()
  if not _G.C_HouseEditor or not _G.C_HouseEditor.IsHouseEditorActive then return false end
  local ok, active = pcall(_G.C_HouseEditor.IsHouseEditorActive)
  return ok and active
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
-- Click-cast macro wrapper: binding value (e.g. ACTIONBUTTON1) -> pre-line + /click frameName.
local CLICKCAST_BARS = {
  { bind = "ACTIONBUTTON", frame = "ActionButton", count = 12 },
  { bind = "MULTIACTIONBAR1BUTTON", frame = "MultiBarBottomLeftButton", count = 12 },
  { bind = "MULTIACTIONBAR2BUTTON", frame = "MultiBarBottomRightButton", count = 12 },
  { bind = "MULTIACTIONBAR3BUTTON", frame = "MultiBarRightButton", count = 12 },
  { bind = "MULTIACTIONBAR4BUTTON", frame = "MultiBarLeftButton", count = 12 },
}
local BindingToClickFrame = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    BindingToClickFrame[bar.bind .. i] = bar.frame .. i
  end
end

-- Helper function to check which action bar type is currently active
-- Returns the frame prefix for the active bar type, or nil if using default bar
local function GetActiveActionBarType()
  if C_ActionBar then
    -- Check for override action bar (vehicles, quest UIs, etc.)
    if C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() then
      return "OverrideActionBarButton"
    end
    -- Check for bonus action bar (druid forms, rogue stealth, etc.)
    if C_ActionBar.HasBonusActionBar and C_ActionBar.HasBonusActionBar() then
      return "BonusActionButton"
    end
    -- Check for extra action bar (encounter-specific abilities)
    if C_ActionBar.HasExtraActionBar and C_ActionBar.HasExtraActionBar() then
      -- Extra action bar uses ExtraActionButton1, not ACTIONBUTTON bindings
      return nil
    end
    -- Check for temp shapeshift action bar
    if C_ActionBar.HasTempShapeshiftActionBar and C_ActionBar.HasTempShapeshiftActionBar() then
      return "TempShapeshiftActionButton"
    end
  end

  -- Fallback to frame visibility check for override bar (for older clients or if API unavailable)
  local overrideBar = _G.OverrideActionBar
  if overrideBar and overrideBar:IsShown() then
    return "OverrideActionBarButton"
  end

  -- Default action bar
  return nil
end

-- Helper function to resolve the correct frame name for ACTIONBUTTON bindings
-- Checks for OverrideActionBarButton, BonusActionButton, or TempShapeshiftActionButton when active,
-- falls back to ActionButton otherwise
local function ResolveActionButtonFrame(bindingValue)
  if not bindingValue:match("^ACTIONBUTTON") then
    -- Not an ACTIONBUTTON binding, return the mapped frame directly
    return BindingToClickFrame[bindingValue]
  end

  -- Extract button number from binding (e.g., "ACTIONBUTTON5" -> 5)
  local buttonNum = bindingValue:match("(%d+)$")
  if not buttonNum then
    return BindingToClickFrame[bindingValue]
  end

  -- Check which action bar type is currently active
  local activeBarType = GetActiveActionBarType()
  if activeBarType then
    local frameName = activeBarType .. buttonNum
    local ok, actionFrame = pcall(function() return _G[frameName] end)
    if ok and actionFrame then
      -- Check if the frame has an action assigned
      local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
      local action = rawAction and tonumber(rawAction)
      if action and action > 0 then
        return frameName
      end
    end
  end

  -- Fall back to regular ActionButton
  return BindingToClickFrame[bindingValue]
end

local CLICKCAST_PRE_LINE_ANY = "/target [@focus,exists,nodead] focus; [nomounted,@mouseover,exists] mouseover" -- used if reticleTargetingEnemyOnly is OFF- Targets any mouseover unit if it exists.
local CLICKCAST_PRE_LINE_ENEMY = "/target [@focus,exists,nodead] focus; [nomounted,@mouseover,harm,nodead][nomounted,@anyenemy,harm,nodead]" --  used if reticleTargetingEnemyOnly is ON - This preline will first try to cast the spell at the unit under the crosshair (mouseover) that is hostile (harm) and alive (nodead). If no unit matches that condition, it tries to find a locked target through the "target" portion of the anyenemy UnitId. If no target exists, it falls back to the "softenemy" UnitId, which is Action Targeting.

-- Returns true if spellId is in the user's "Cast @Cursor Spells" list (comma-separated names in options).
local function IsCastAtCursorSpell(spellId)
  if not spellId or spellId <= 0 then return false end
  local list = CM.DB.char.castAtCursorSpells
  if not list or list == "" then return false end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then set[n] = true end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then return false end
  return set[spellName:lower()] == true
end

-- Returns true if spellId is in the user's "Exclude from targeting" blacklist (no pre-line applied).
local function IsExcludedFromTargetingSpell(spellId)
  if not spellId or spellId <= 0 then return false end
  local list = CM.DB.char.excludeFromTargetingSpells
  if not list or list == "" then return false end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then set[n] = true end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then return false end
  return set[spellName:lower()] == true
end

-- Ordered list of all binding names (ACTIONBUTTON1..12, MULTIACTIONBAR1BUTTON1..12, etc.)
local OrderedBindingNames = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    OrderedBindingNames[#OrderedBindingNames + 1] = bar.bind .. i
  end
end

local GroundCastKeyOverrideOwner = CreateFrame("Frame", nil, UIParent)
local SlotFramesByBindingName = {}
for idx, bindingName in ipairs(OrderedBindingNames) do
  local f = CreateFrame("Button", "CombatModeSlot" .. idx, GroundCastKeyOverrideOwner, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  SlotFramesByBindingName[bindingName] = f
end

local function GetClickCastPreLine()
  if not CM.DB.char.reticleTargeting then return nil end
  if CM.DB.char.reticleTargetingEnemyOnly then return CLICKCAST_PRE_LINE_ENEMY end
  return CLICKCAST_PRE_LINE_ANY
end

local CLICKCAST_KEYS = { "BUTTON1", "BUTTON2", "SHIFT-BUTTON1", "SHIFT-BUTTON2", "CTRL-BUTTON1", "CTRL-BUTTON2", "ALT-BUTTON1", "ALT-BUTTON2" }
local ClickCastFramesByKey = {}
for i, key in ipairs(CLICKCAST_KEYS) do
  local f = CreateFrame("Button", "CombatModeClickCast" .. i, UIParent, "SecureActionButtonTemplate")
  f:SetAttribute("type", "macro")
  f:RegisterForClicks("AnyUp", "AnyDown")
  ClickCastFramesByKey[key] = f
end

-- Secure action button for toggle focus target
local ToggleFocusTargetOverrideOwner = CreateFrame("Frame", nil, UIParent)
local ToggleFocusTargetButton = CreateFrame("Button", "CombatModeToggleFocusTarget", ToggleFocusTargetOverrideOwner, "SecureActionButtonTemplate")
ToggleFocusTargetButton:SetAttribute("type", "macro")
-- macrotext set by UpdateToggleFocusTargetMacroText() based on reticleTargetingEnemyOnly
ToggleFocusTargetButton:RegisterForClicks("AnyUp", "AnyDown")

local function UpdateToggleFocusTargetMacroText()
  if not ToggleFocusTargetButton then return end
  local macroText = CM.DB.char.reticleTargetingEnemyOnly and CM.Constants.Macros.CM_ToggleFocusEnemy or CM.Constants.Macros.CM_ToggleFocusAny
  ToggleFocusTargetButton:SetAttribute("macrotext", macroText)
end

local function BuildClickCastMacroText(bindingValue)
  -- When reticle targeting is off, no macro wrapping (no pre-line, no castAtCursor, no excludeFromTargeting).
  if not CM.DB.char.reticleTargeting then return nil end
  -- For ACTIONBUTTON bindings, use a conditional /click so action bar type is resolved
  -- at macro run time (works when action bars change in combat; we can't refresh bindings then).
  local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  local useConditionalClick = buttonNum ~= nil

  local clickFrame = ResolveActionButtonFrame(bindingValue)
  if not clickFrame then return nil end

  -- Check if this is a special action bar button (don't inject preline for special bar abilities)
  local isSpecialBarButton = clickFrame:match("^OverrideActionBarButton") or
                             clickFrame:match("^BonusActionButton") or
                             clickFrame:match("^TempShapeshiftActionButton")

  local castLine
  if useConditionalClick then
    -- Use conditional macro to check for override bar at runtime
    -- (works when exiting vehicle in combat; we can't refresh bindings then)
    -- For bonus/shapeshift bars, bindings are refreshed via events when out of combat
    castLine = "/click [overridebar] OverrideActionBarButton" .. buttonNum .. "; ActionButton" .. buttonNum
  else
    castLine = "/click " .. clickFrame
  end

  -- For ACTIONBUTTON bindings, check slot directly (same as IsSlotMacro) to avoid stale action attributes after dismounting
  if useConditionalClick and buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      local getOk, atype = pcall(GetActionInfo, slotNum)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
      end
    end
  end

  local ok, actionFrame = pcall(function() return _G[clickFrame] end)
  if ok and actionFrame then
    local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
    local action = rawAction and tonumber(rawAction)
    if action and action > 0 then
      local getOk, atype, id = pcall(GetActionInfo, action)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
        -- Special action bar abilities (override, bonus, shapeshift): don't inject pre-line, just click the button directly
        if isSpecialBarButton then
          return castLine
        end
        -- Ground-targeted spell from whitelist: use /cast [@cursor] only (no pre-line).
        if atype == "spell" and id and type(id) == "number" and id > 0 and IsCastAtCursorSpell(id) then
          local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
          local spellName = spellInfo and spellInfo.name
          if spellName and spellName ~= "" then
            return "/cast [@cursor] " .. spellName
          end
          return "/cast [@cursor] spell:" .. id
        end
        -- Spell in blacklist (e.g. self-cast defensives): don't apply targeting pre-line.
        if atype == "spell" and id and type(id) == "number" and id > 0 and IsExcludedFromTargetingSpell(id) then
          return castLine
        end
      end
    end
  end

  -- Don't inject preline for special action bar buttons
  if isSpecialBarButton then
    return castLine
  end

  local pre = GetClickCastPreLine()
  -- Do not prefix pre-line with [nooverridebar]; that can be misinterpreted in combat and echo to chat.
  return pre and (pre .. "\n" .. castLine) or castLine
end

local function SetClickCastFrameMacro(frame, macroText)
  if frame and macroText and not InCombatLockdown() then
    frame:SetAttribute("macrotext", macroText)
  end
end

-- Returns true if the given action bar binding (e.g. ACTIONBUTTON5) currently has a macro in that slot.
-- Always checks the regular ActionButton slot directly, not override/bonus bars, since macros are stored in the slot itself.
local function IsSlotMacro(bindingValue)
  -- For ACTIONBUTTON bindings, check the slot number directly (1-12) instead of using the frame's action attribute,
  -- which may be stale after dismounting (e.g., still pointing to override bar action 127 that no longer exists)
  local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  if buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      -- Check the slot directly - this works even when frame's action attribute is stale after dismounting
      local getOk, atype = pcall(GetActionInfo, slotNum)
      return getOk and atype == "macro"
    end
  end

  -- For non-ACTIONBUTTON bindings, use resolved frame and check its action
  local frameToCheck = ResolveActionButtonFrame(bindingValue)
  if not frameToCheck then return false end
  local ok, actionFrame = pcall(function() return _G[frameToCheck] end)
  if not ok or not actionFrame then return false end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action") or actionFrame.action
  local action = rawAction and tonumber(rawAction)
  if not action or action <= 0 then return false end
  local getOk, atype = pcall(GetActionInfo, action)
  return getOk and atype == "macro"
end

-- Override keyboard keys (Q, E, etc.) to click our slot frame so the same macro logic runs (pre-line + /click or /cast [@cursor] for ground spells). No per-spell macros.
-- When macroInjectionClickCastOnly is true, skip keyboard overrides so only the 8 click-cast mouse bindings get the injection.
function CM.ApplyGroundCastKeyOverrides()
  if InCombatLockdown() then return end
  ClearOverrideBindings(GroundCastKeyOverrideOwner)
  -- When reticle targeting is off, no macro injection on keybinds at all.
  if not CM.DB.char.reticleTargeting then return end
  -- When macroInjectionClickCastOnly is on, only click-cast bindings get injection; skip keyboard overrides.
  if CM.DB.char.macroInjectionClickCastOnly then return end
  -- When House Editor (housing) is active, do not override action bar keys so housing bindings (e.g. R to return item to box) work.
  if IsHouseEditorActive() then return end
  for _, bindingName in ipairs(OrderedBindingNames) do
    local key = GetBindingKey(bindingName)
    if key then
      local realFrame = ResolveActionButtonFrame(bindingName)
      if realFrame and IsSlotMacro(bindingName) then
        -- Slot is a macro: use conditional click macro so it works when override bar is active or inactive
        -- (prevents broken bindings after dismounting from skyriding mounts with override bars)
        local buttonNum = bindingName:match("^ACTIONBUTTON(%d+)$")
        if buttonNum then
          -- ACTIONBUTTON binding: use conditional click that checks override bar at runtime
          local frame = SlotFramesByBindingName[bindingName]
          if frame then
            local conditionalClickMacro = "/click [overridebar] OverrideActionBarButton" .. buttonNum .. "; ActionButton" .. buttonNum
            SetClickCastFrameMacro(frame, conditionalClickMacro)
            SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, frame:GetName(), "LeftButton")
          else
            -- Fallback: direct click to resolved frame (shouldn't happen, but safe)
            SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, realFrame, "LeftButton")
          end
        else
          -- Non-ACTIONBUTTON binding: direct click to resolved frame
          SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, realFrame, "LeftButton")
        end
      else
        local frame = SlotFramesByBindingName[bindingName]
        local macroText = BuildClickCastMacroText(bindingName)
        if frame and macroText then
          SetClickCastFrameMacro(frame, macroText)
          SetOverrideBindingClick(GroundCastKeyOverrideOwner, false, key, frame:GetName(), "LeftButton")
        end
      end
    end
  end
end

function CM.RefreshClickCastMacros()
  if InCombatLockdown() then return end
  -- Re-apply all bindings so macro slots get "click real button" and spell slots get our frame.
  -- This refreshes both keyboard bindings (via ApplyGroundCastKeyOverrides) and mouse button bindings (via OverrideDefaultButtons)
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
end

local function ClickCastMouseButton(key)
  return key:match("BUTTON2") and "RightButton" or "LeftButton"
end

function CM.GetBindingsLocation()
  return CM.DB.char.useGlobalBindings and "global" or "char"
end

function CM.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then return end

  local key, value = buttonSettings.key, buttonSettings.value
  local valueToUse
  if value == "MACRO" then
    valueToUse = "MACRO " .. buttonSettings.macroName
  elseif value == "CLEARTARGET" then
    valueToUse = "MACRO CM_ClearTarget"
  elseif value == "CLEARFOCUS" then
    valueToUse = "MACRO CM_ClearFocus"
  elseif value == "TOGGLEFOCUSANY" then
    valueToUse = "MACRO CM_ToggleFocusAny"
  elseif value == "TOGGLEFOCUSENEMY" then
    valueToUse = "MACRO CM_ToggleFocusEnemy"
  else
    -- When reticle targeting is off, no macro wrapping: use raw binding (no pre-line, no castAtCursor/excludeFromTargeting).
    if not CM.DB.char.reticleTargeting then
      valueToUse = value
    else
      local realFrame = ResolveActionButtonFrame(value)
      if realFrame and IsSlotMacro(value) then
        -- Slot is a macro: bind key to click the real action bar button so the macro runs as written.
        valueToUse = "CLICK " .. realFrame .. ":" .. ClickCastMouseButton(key)
      else
        local frame = ClickCastFramesByKey[key]
        local macroText = BuildClickCastMacroText(value)
        if frame and macroText then
          SetClickCastFrameMacro(frame, macroText)
          valueToUse = "CLICK " .. frame:GetName() .. ":" .. ClickCastMouseButton(key)
        else
          valueToUse = value
        end
      end
    end
  end
  SetMouselookOverrideBinding(key, valueToUse)
  CM.DebugPrint(key .. "'s override binding is now " .. valueToUse)
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
    SetBinding(key, "Combat Mode - Mouse Look")
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

function CM.LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    CenterCursor(true)
    HandleFreeLookUIState(true, false)
    CM.ShowCrosshairLockIn()
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(true)
    end
    CM.DebugPrint("Free Look Enabled")
  end
end

function CM.UnlockFreeLook()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

    if CM.DB.global.pulseCursor then
      CM.ShowCursorPulse()
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
      CM.ShowCursorPulse()
    end

    HandleFreeLookUIState(false, true)
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(false)
    end
    CM.DebugPrint("Free Look Disabled (Permanent)")
  end
end

-- NOTE: ToggleFreeLook() was removed. Its logic is now inlined in
-- CombatMode_CursorModeKey() which handles both tap-to-toggle and hold-to-unlock
-- via a single runOnUp="true" keybind with spurious key-up filtering.

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

    -- CM.HandleMouseoverCasting(true)

    -- if "Only Allow Reticle to Target Enemies" is turned off, activate Soft Targeting Friend
    if not CM.DB.char.reticleTargetingEnemyOnly then
      CM.HandleSoftTargetFriend(true)
    end
  -- else
  --   CM.HandleMouseoverCasting(false)
  end

  if CM.DB.global.crosshair then
    -- Stop lock-in animation so it does not leave crosshair at reduced opacity after load
    LOCK_IN_TOTAL_ELAPSED = -1
    -- Re-apply crosshair frame from config (scale, alpha, position) so we are not left
    -- in a half-finished animation state after loading screen / zone change
    CM.CreateCrosshair()
    -- Update crosshair appearance based on current state (focus, unit under cursor, etc.)
    if HideCrosshairWhileMounted() then
      SetCrosshairAppearance("mounted")
    else
      UpdateCrosshairReaction()
    end

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
    -- Sync crosshair visibility with mouselook state after load/zone change so the
    -- texture shows again when leaving dungeon or after loading screen
    CM.DisplayCrosshair(IsMouselooking())
  elseif CM.DB.global.crosshair == false then
    CM.DisplayCrosshair(false)
  end

  -- Dismiss healing radial so it is not considered "active" after load (fixes crosshair
  -- not showing when healing radial is enabled, since IsHealingRadialActive() would block)
  if CM.HealingRadial and CM.HealingRadial.DismissOnLoad then
    CM.HealingRadial.DismissOnLoad()
  end

  CM.LockFreeLook()
end

--[[
Handle events based on their category.
You need to first register the event in the CM.Constants.BLIZZARD_EVENTS table before using it here.
Checks which category in the table the event that's been fired belongs to, and then calls the appropriate function.
]] --
local function HandleEventByCategory(category, event)
  local eventHandlers = {
    UNLOCK_EVENTS = function()
      CM.UnlockFreeLook()
    end,
    LOCK_EVENTS = function()
      CM.LockFreeLook()
    end,
    REMATCH_EVENTS = function()
      Rematch()
    end,
    FRIENDLY_TARGETING_EVENTS = function()
      -- Handle combat start/end for healing radial
      if CM.HealingRadial then
        if event == "PLAYER_REGEN_DISABLED" and CM.HealingRadial.OnCombatStart then
          CM.HealingRadial.OnCombatStart()
        elseif event == "PLAYER_REGEN_ENABLED" and CM.HealingRadial.OnCombatEnd then
          CM.HealingRadial.OnCombatEnd()
        end
      end
    end,
    UNCATEGORIZED_EVENTS = function()
      -- Update crosshair appearance based on current state (focus, unit under cursor, etc.)
      -- Only override with mounted/base if actually mounted, otherwise use UpdateCrosshairReaction
      if HideCrosshairWhileMounted() then
        SetCrosshairAppearance("mounted")
        lastKnownAppearanceState = "mounted"
        -- Hide crosshair when mounted
        if IsMouselooking() then
          CM.DisplayCrosshair(false)
        end
      else
        -- Reset appearance state tracking to force update when dismounting
        lastKnownAppearanceState = nil
        UpdateCrosshairReaction()
        -- Show crosshair when dismounting / leaving combat (if mouselook is active) only when Show Crosshair is enabled
        if IsMouselooking() then
          if CM.DB.global.crosshair then
            CM.DisplayCrosshair(true)
          else
            CM.DisplayCrosshair(false)
          end
        end
      end
    end,
    REFRESH_BINDINGS_EVENTS = function()
      if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0.1, function()
          CM.DebugPrint("Action Bar state changed, refreshing binding macros")
          CM.RefreshClickCastMacros()
        end)
      else
        -- Fallback: refresh immediately if C_Timer not available
        CM.RefreshClickCastMacros()
      end

      -- Healing Radial: update slice targets and spell attributes when roster or action bar changes
      if not CM.HealingRadial then return end
      if event == "GROUP_ROSTER_UPDATE" and CM.HealingRadial.OnGroupRosterUpdate then
        CM.HealingRadial.OnGroupRosterUpdate()
      elseif CM.HealingRadial.OnActionBarChanged then
        CM.HealingRadial.OnActionBarChanged()
      end
    end,
    FOCUS_LOCK_EVENTS = function()
      if event == "PLAYER_FOCUS_CHANGED" then
        -- Play lock-in animation when focus is set (only if focus exists and mouselook is active)
        if UnitExists("focus") and IsMouselooking() then
          CM.ShowCrosshairLockIn()
        end
        -- Update crosshair appearance to show focus state
        UpdateCrosshairReaction()
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
      CM.UnlockFreeLook()
      return
    end

    if not IsMouselooking() then
      CM.LockFreeLook()
    end

    -- Update crosshair appearance based on unit under cursor
    UpdateCrosshairReaction()

  end
end

---------------------------------------------------------------------------------------
--                            KEYBIND FUNCTIONS & COMMANDS                           --
---------------------------------------------------------------------------------------
-- FUNCTIONS CALLED FROM BINDINGS.XML

-- Unified cursor mode keybind: tap to toggle, hold to temporarily unlock.
-- Uses the same spurious key-up filter as the Healing Radial keybind.
-- MouselookStop() fires spurious key-up events for held keys, so we ignore
-- key-ups within 0.3s of unlocking. A quick tap leaves the cursor free (toggle);
-- holding longer than 0.3s re-locks on release (hold).
function _G.CombatMode_CursorModeKey(keystate)
  if IsDefaultMouseActionBeingUsed() then
    CM.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  if keystate == "down" then
    if not IsMouselooking() and FreeLookOverride then
      -- Already unlocked via previous tap — re-lock (toggle off)
      CM.LockFreeLook()
      FreeLookOverride = false
      CursorModeShowTime = 0 -- No spurious filter needed for lock
    elseif IsMouselooking() then
      -- Currently mouselooking — unlock cursor
      CursorModeShowTime = GetTime()
      UnlockFreeLookPermanent()
      FreeLookOverride = true
    end
  elseif keystate == "up" then
    if not FreeLookOverride then
      -- Already re-locked on key-down (toggle-off case), nothing to do
      return
    end
    -- Ignore spurious key-ups from MouselookStop (within 0.3s)
    local elapsed = GetTime() - CursorModeShowTime
    if elapsed < 0.3 then
      CM.DebugPrint("Cursor Mode: Ignoring spurious key-up (elapsed=" .. string.format("%.3f", elapsed) .. "s)")
      return
    end
    -- Hold release: re-lock mouselook
    CM.LockFreeLook()
    FreeLookOverride = false
  end
end

function _G.CombatMode_HealingRadialKey(keystate)
  if not CM.HealingRadial then return end
  local HR = CM.HealingRadial
  CM.DebugPrint("HealingRadialKey: keystate=" .. tostring(keystate) .. " isActive=" .. tostring(HR.IsActive()))
  if keystate == "down" then
    if HR.IsActive() then
      -- Already open (tap-to-toggle: second press closes)
      HR.Hide()
    else
      HR.ShowFromKeybind()
    end
  elseif keystate == "up" then
    HR.HideFromKeybind()
  end
end

-- Apply override binding for toggle focus target
function CM.ApplyToggleFocusTargetBinding()
  if InCombatLockdown() then return end
  UpdateToggleFocusTargetMacroText()
  local key = GetBindingKey("Combat Mode - Toggle Focus Target")
  if key then
    ClearOverrideBindings(ToggleFocusTargetOverrideOwner)
    SetOverrideBindingClick(ToggleFocusTargetOverrideOwner, false, key, ToggleFocusTargetButton:GetName(), "LeftButton")
    CM.DebugPrint("Toggle Focus Target binding applied to " .. tostring(key))
  end
end

-- Handler for toggle focus target keybinding (fallback - should be overridden)
function _G.CombatMode_ToggleFocusTarget()
  -- This should be overridden by SetOverrideBindingClick, but kept as fallback
  CM.DebugPrint("Toggle Focus Target handler called (should be overridden)")
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
  CM.ApplyGroundCastKeyOverrides()
  UnbindMoveAndSteer()
  InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CM.CreateCrosshair()
  CreatePulse()
  CreateTargetMacros()

  -- Toggle focus target: macrotext (Any vs Enemy) set inside ApplyToggleFocusTargetBinding
  CM.ApplyToggleFocusTargetBinding()

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
