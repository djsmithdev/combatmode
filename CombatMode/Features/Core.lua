---------------------------------------------------------------------------------------
--  Features/Core.lua — CORE — addon shell, lifecycle, free look, global drivers
---------------------------------------------------------------------------------------
--  Instantiates the AceAddon "CombatMode" object, SavedVariables (AceDB), slash
--  commands, and Blizzard options registration. Owns the mouselook "free look" state
--  machine (lock/unlock, cursor centering CVars, tooltip/action-cam/sticky hooks),
--  Rematch on layout/reload, and the throttled global OnUpdate loop that enforces
--  free look and refreshes crosshair reactions.
--
--  Architecture:
--    • Loaded early (Features/Core.lua); defines _G.CM and CM.METADATA from the TOC.
--    • Calls into feature modules: Reticle, ClickCasting, Pulse, CursorUnlock,
--      HealingRadial (Initialize / mouselook notifications / dismiss-on-load).
--    • Exposes globals for XML: CombatMode_OnEvent, CombatMode_OnUpdate, keybind
--      handlers (CombatMode_CursorModeKey, CombatMode_HealingRadialKey).
--    • Shared CVar helpers here (ApplyCVarConfig, camera, sticky, shoulder, speed)
--      are used by Config and by Reticle (reticle targeting lives in Reticle.lua).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigCmd = LibStub("AceConfigCmd-3.0")

-- WoW API
local CreateMacro = _G.CreateMacro
local DisableAddOn = _G.C_AddOns.DisableAddOn
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
local GameTooltip = _G.GameTooltip
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetMacroInfo = _G.GetMacroInfo
local GetTime = _G.GetTime
local InCinematic = _G.InCinematic
local IsInCinematicScene = _G.IsInCinematicScene
local InCombatLockdown = _G.InCombatLockdown
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local OpenToCategory = _G.Settings.OpenToCategory
local OpenSettingsPanel = _G.C_SettingsUtil and _G.C_SettingsUtil.OpenSettingsPanel
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetCVar = _G.C_CVar.SetCVar
local SpellIsTargeting = _G.SpellIsTargeting
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local UIParent = _G.UIParent
local C_Timer = _G.C_Timer

-- Lua stdlib
local ipairs = _G.ipairs
local type = _G.type
local pcall = _G.pcall

-- INSTANTIATING ADDON & ENCAPSULATING NAMESPACE
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
_G["CM"] = CM

-- INITIAL STATE VARIABLES
-- Changes when Free Look state is modified through user input ("Toggle / Hold" keybind and "/cm" cmd)
local FreeLookOverride = false
local CursorModeShowTime = 0 -- GetTime() when cursor was unlocked via keybind (for spurious key-up filter)
local deferredBindingQueue = {}
local eventCategoryMap = {}

-- Coalesce REFRESH_BINDINGS_EVENTS: one RefreshClickCastMacros after bursts.
local clickCastRefreshGen = 0
local clickCastRefreshReason = "bar" -- "cvar" | "bar"

local function DebugPrintClickCastRefreshReason()
  if clickCastRefreshReason == "cvar" then
    CM.DebugPrint("ActionButtonUseKeyDown changed, refreshing binding macros")
  else
    CM.DebugPrint("Action Bar state changed, refreshing binding macros")
  end
end

local function ScheduleClickCastBindingRefresh()
  if not C_Timer or not C_Timer.After then
    DebugPrintClickCastRefreshReason()
    CM.RefreshClickCastMacros()
    return
  end
  clickCastRefreshGen = clickCastRefreshGen + 1
  local myGen = clickCastRefreshGen
  C_Timer.After(0.1, function()
    if myGen ~= clickCastRefreshGen then
      return
    end
    DebugPrintClickCastRefreshReason()
    CM.RefreshClickCastMacros()
  end)
end

---------------------------------------------------------------------------------------
--                                 UTILITY FUNCTIONS                                 --
---------------------------------------------------------------------------------------
local function FetchDataFromTOC()
  local dataReturned = {}
  local keysToFetch = {
    "Version",
    "Title",
    "Notes",
    "Author",
    "X-Discord",
    "X-Curse",
    "X-Contributors",
  }

  for _, key in ipairs(keysToFetch) do
    dataReturned[string.upper(key)] = GetAddOnMetadata("CombatMode", key)
  end

  return dataReturned
end

CM.METADATA = FetchDataFromTOC()

function CM.DebugPrint(statement)
  if not (CM.DB and CM.DB.global and CM.DB.global.debugMode) then
    return
  end
  print(CM.Constants.BasePrintMsg .. "|cff909090: " .. tostring(statement) .. "|r")
end

local debugThrottleLastAt = {}
--- Throttle repeated debug lines per logical channel (seconds). Requires debug mode on.
function CM.DebugPrintThrottled(key, msg, intervalSec)
  if not (CM.DB and CM.DB.global and CM.DB.global.debugMode) then
    return
  end
  intervalSec = intervalSec or 3
  local now = GetTime()
  local last = debugThrottleLastAt[key] or 0
  if now - last <= intervalSec then
    return
  end
  debugThrottleLastAt[key] = now
  CM.DebugPrint(msg)
end

--- Which DB root holds mouselook click bindings ("char" vs "global").
function CM.GetBindingsLocation()
  return CM.DB.char.useGlobalBindings and "global" or "char"
end

-- Locale-appropriate font file from a Blizzard FontObject (ru/zh/etc.); avoids Latin-only Friz for unit names.
local FALLBACK_UI_FONT_PATH = "Fonts\\FRIZQT__.TTF"

function CM.SetFontStringFromTemplate(fontString, pixelSize, templateFontObject)
  if not fontString or not pixelSize then
    return
  end
  local template = templateFontObject or _G.GameFontNormalSmall
  local path, flags
  if template and template.GetFont then
    path, _, flags = template:GetFont()
  end
  if type(path) ~= "string" or path == "" then
    path = FALLBACK_UI_FONT_PATH
  end
  fontString:SetFont(path, pixelSize, flags)
end

function CM.SetCursorFreelookCentering(shouldCenter)
  -- Edit Mode crosshair drives aligned cursor (CursorFreelookCentering + CursorCenteredYPos in Reticle).
  local useCrosshairCursor = shouldCenter and CM.IsCrosshairEnabled()
  if useCrosshairCursor then
    SetCVar("CursorFreelookCentering", 1)
    CM.DebugPrint("Locking cursor to crosshair position.")
  else
    SetCVar("CursorFreelookCentering", 0)
    CM.DebugPrint("Freeing cursor from crosshair position.")
  end
end

function CM.TryApplyBindingChange(context, applyFn)
  if type(applyFn) ~= "function" then
    return false
  end

  if InCombatLockdown() then
    deferredBindingQueue[#deferredBindingQueue + 1] = {
      context = context or "binding change",
      applyFn = applyFn,
    }
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: deferred "
        .. (context or "binding change")
        .. " until combat ends.|r"
    )
    return false
  end

  local ok, err = pcall(applyFn)
  if not ok then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: failed to apply "
        .. (context or "binding change")
        .. ": "
        .. tostring(err)
        .. "|r"
    )
    return false
  end

  return true
end

function CM.FlushDeferredBindingChanges()
  if InCombatLockdown() then
    return
  end
  if #deferredBindingQueue == 0 then
    return
  end

  local pending = deferredBindingQueue
  deferredBindingQueue = {}

  for _, change in ipairs(pending) do
    CM.TryApplyBindingChange(change.context, change.applyFn)
  end

  print(CM.Constants.BasePrintMsg .. "|cff909090: applied deferred binding updates.|r")
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
    whileDead = true,
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
]]
--
local function IsDCLoaded()
  local DC = AceAddon:GetAddon("DynamicCam", true)
  CM.DynamicCam = DC ~= nil and true or false
  if CM.DynamicCam and not CM.DB.global.silenceAlerts then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: |cffE52B50DynamicCam detected!|r Handing over control of |cffE37527• Camera Features|r.|r"
    )
  end
end

---------------------------------------------------------------------------------------
--                              CVAR HANDLING FUNCTIONS                              --
---------------------------------------------------------------------------------------
function CM.ApplyCVarConfig(info)
  local CVarType, CMValues, BlizzValues, FeatureName =
    info.CVarType, info.CMValues, info.BlizzValues, info.FeatureName
  local CVarsToLoad

  if CVarType == "combatmode" then
    CVarsToLoad = CMValues
    CM.DebugPrint(FeatureName .. " CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = BlizzValues
    CM.DebugPrint(FeatureName .. " CVars RESET")
  else
    CM.DebugPrint(
      "Invalid CVarType in CM.ApplyCVarConfig for " .. FeatureName .. ": " .. tostring(CVarType)
    )
    return
  end

  for name, value in pairs(CVarsToLoad) do
    SetCVar(name, value)
  end
end

function CM.ConfigActionCamera(CVarType)
  if CM.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ActionCameraCVarValues,
    BlizzValues = CM.Constants.BlizzardActionCameraCVarValues,
    FeatureName = "Action Camera",
  }

  CM.ApplyCVarConfig(info)
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
    CMValues = CM.Constants.TargetFocusCVarValues,
    BlizzValues = CM.Constants.BlizzardTargetFocusCVarValues,
    FeatureName = "Sticky Crosshair",
  }

  CM.ApplyCVarConfig(info)
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

function CM:ResetCVarsToDefault()
  self.ConfigReticleTargeting("blizzard")
  self.ConfigActionCamera("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.HandleSoftTargetFriend(false)

  print(CM.Constants.BasePrintMsg .. "|cff909090: all changes have been reverted.|r")
end

local function IsHealingRadialActive()
  return CM.HealingRadial and CM.HealingRadial.IsActive and CM.HealingRadial.IsActive()
end

local function ShouldFreeLookBeOff()
  return CM.IsCustomConditionTrue()
    or (
      FreeLookOverride
      or SpellIsTargeting()
      or InCinematic()
      or IsInCinematicScene()
      or CM.IsUnlockFrameVisible()
      or CM.IsVendorMountOut()
      or CM.IsInPetBattle()
      or CM.IsFeignDeathActive()
      or IsHealingRadialActive()
    )
end

-- Unbinding MOVEANDSTEER to avoid potential bug when toggling free look with the same key
local function UnbindMoveAndSteer()
  CM.TryApplyBindingChange("MOVEANDSTEER unbind", function()
    local key = GetBindingKey("MOVEANDSTEER")
    if key then
      SetBinding(key, "Combat Mode - Mouse Look")
    end
    SaveBindings(GetCurrentBindingSet())
  end)
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
  if CM.IsCrosshairEnabled() then
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

  if CM.IsCrosshairEnabled() and CM.DB.char.stickyCrosshair then
    CM.ConfigStickyCrosshair(isLocking and "combatmode" or "blizzard")
  end
end

function CM.LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    -- Defer UI state changes to avoid taint during protected mouselook initialization
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        CM.SetCursorFreelookCentering(true)
        HandleFreeLookUIState(true, false)
      end)
    else
      CM.SetCursorFreelookCentering(true)
      HandleFreeLookUIState(true, false)
    end
    CM.ShowCrosshairLockIn()
    -- Notify Healing Radial of mouselook state change
    if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
      CM.HealingRadial.OnMouselookChanged(true)
    end
    CM.DebugPrint("Free Look Enabled")
  end
end

local function RunUnlockFreeLookDeferredUI(isPermanentUnlock)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      CM.SetCursorFreelookCentering(false)
      HandleFreeLookUIState(false, isPermanentUnlock)
    end)
  else
    CM.SetCursorFreelookCentering(false)
    HandleFreeLookUIState(false, isPermanentUnlock)
  end
end

function CM.UnlockFreeLook()
  if not IsMouselooking() then
    return
  end
  RunUnlockFreeLookDeferredUI(false)
  MouselookStop()

  if CM.DB.global.pulseCursor then
    CM.ShowCursorPulse()
  end

  if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
    CM.HealingRadial.OnMouselookChanged(false)
  end
  CM.DebugPrint("Free Look Disabled")
end

local function UnlockFreeLookPermanent()
  if not IsMouselooking() then
    return
  end
  RunUnlockFreeLookDeferredUI(true)
  MouselookStop()

  if CM.DB.global.pulseCursor then
    CM.ShowCursorPulse()
  end

  if CM.HealingRadial and CM.HealingRadial.OnMouselookChanged then
    CM.HealingRadial.OnMouselookChanged(false)
  end
  CM.DebugPrint("Free Look Disabled (Permanent)")
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

    if not CM.DB.char.reticleTargetingEnemyOnly then
      CM.HandleSoftTargetFriend(true)
    end
  elseif CM.IsCrosshairEnabled() and CM.IsInteractionHUDEnabled() then
    CM.ConfigInteractionHUDSoftTarget()
  end

  CM.OnRematchCrosshair()

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
]]
--
local function HandleEventByCategory(category, event, ...)
  local cvarName = select(1, ...)
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
      if event == "PLAYER_REGEN_ENABLED" then
        CM.FlushDeferredBindingChanges()
      end
    end,
    UNCATEGORIZED_EVENTS = function()
      CM.OnCrosshairUncategorizedEvent()
    end,
    REFRESH_BINDINGS_EVENTS = function()
      if event == "CVAR_UPDATE" then
        if cvarName ~= "ActionButtonUseKeyDown" then
          return
        end
      end

      if event == "CVAR_UPDATE" then
        clickCastRefreshReason = "cvar"
      else
        clickCastRefreshReason = "bar"
      end
      ScheduleClickCastBindingRefresh()

      if event == "CVAR_UPDATE" then
        return
      end

      -- Healing Radial: update slice targets and spell attributes when roster or action bar changes
      if not CM.HealingRadial then
        return
      end
      if event == "GROUP_ROSTER_UPDATE" and CM.HealingRadial.OnGroupRosterUpdate then
        CM.HealingRadial.OnGroupRosterUpdate()
      elseif CM.HealingRadial.OnActionBarChanged then
        CM.HealingRadial.OnActionBarChanged()
      end
    end,
    FOCUS_LOCK_EVENTS = function()
      CM.OnCrosshairFocusLockEvent(event)
    end,
  }

  if eventHandlers[category] then
    eventHandlers[category]()
  end
end

local function BuildEventCategoryMap()
  eventCategoryMap = {}
  for category, registeredEvents in pairs(CM.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(registeredEvents) do
      eventCategoryMap[event] = eventCategoryMap[event] or {}
      eventCategoryMap[event][#eventCategoryMap[event] + 1] = category
    end
  end
end

-- FIRES WHEN ONE OF OUR REGISTERED EVENTS HAPPEN IN GAME
function _G.CombatMode_OnEvent(event, ...)
  local categories = eventCategoryMap[event]
  if not categories then
    return
  end
  for _, category in ipairs(categories) do
    HandleEventByCategory(category, event, ...)
  end
end

---------------------------------------------------------------------------------------
--                                   GAME STATE LOOP                                 --
---------------------------------------------------------------------------------------
--[[
The game engine will call the OnUpdate function once each frame.
This is (in most cases) extremely excessive, hence why we're adding a throttle.
]]
--
local ON_UPDATE_INTERVAL = 0.15
local TIME_SINCE_LAST_UPDATE = 0
function _G.CombatMode_OnUpdate(_, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  TIME_SINCE_LAST_UPDATE = TIME_SINCE_LAST_UPDATE + elapsed

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if TIME_SINCE_LAST_UPDATE >= ON_UPDATE_INTERVAL then
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

    CM.UpdateCrosshairReaction()
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
      CM.DebugPrint(
        "Cursor Mode: Ignoring spurious key-up (elapsed=" .. string.format("%.3f", elapsed) .. "s)"
      )
      return
    end
    -- Hold release: re-lock mouselook
    CM.LockFreeLook()
    FreeLookOverride = false
  end
end

function _G.CombatMode_HealingRadialKey(keystate)
  if not CM.HealingRadial then
    return
  end
  local HR = CM.HealingRadial
  CM.DebugPrint(
    "HealingRadialKey: keystate=" .. tostring(keystate) .. " isActive=" .. tostring(HR.IsActive())
  )
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
]]
--
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
  ReloadUI()
end

--[[
Do more initialization here, that really enables the use of your addon.
Register Events, Hook functions, Create Frames, Get information from
the game that wasn't available in OnInitialize
]]
--
local function BootstrapFeatureModules()
  RenameBindableActions()
  CM.OverrideDefaultButtons()
  CM.ApplyGroundCastKeyOverrides()
  UnbindMoveAndSteer()
  CM.InitializeWildcardFrameTracking(CM.Constants.WildcardFramesToMatch)
  CM.CreateCrosshair()
  CM.RegisterCrosshairEditMode()
  CM.InitializeCursorPulse()
  CreateTargetMacros()
  CM.ApplyToggleFocusTargetBinding()
  if CM.HealingRadial and CM.HealingRadial.Initialize then
    CM.HealingRadial.Initialize()
  end
end

function CM:OnEnable()
  BootstrapFeatureModules()
  BuildEventCategoryMap()

  -- Registering Blizzard Events from Constants.lua
  for eventName in pairs(eventCategoryMap) do
    self:RegisterEvent(eventName, _G.CombatMode_OnEvent)
  end

  -- Greeting message that is printed to chat on initial load
  if not CM.DB.global.silenceAlerts then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r"
    )
  end

  DisplayPopup()
end

--[[
Unhook, Unregister Events, Hide frames that you created.
You would probably only use an OnDisable if you want to
build a "standby" mode, or be able to toggle modules on/off.
]]
--
function CM:OnDisable()
  CM.HideCrosshairFrame()
  self:ResetCVarsToDefault()
  self:UnregisterAllEvents()
end
