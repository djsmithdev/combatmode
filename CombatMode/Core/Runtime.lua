---------------------------------------------------------------------------------------
--  Core/Runtime.lua — RUNTIME — addon shell, lifecycle, free look, global drivers
---------------------------------------------------------------------------------------
--  Instantiates the AceAddon "CombatMode" object, SavedVariables (AceDB), and slash
--  commands. Options live in the standalone window (UI/Options/*; CM.OpenOptions).
--  Coordinates runtime modules,
--  Rematch on layout/reload, and the throttled global OnUpdate loop that enforces
--  free look via Core/FreeLookController.lua and refreshes crosshair reactions.
--  First-login welcome modal (CM.UI.ShowWelcome, deferred past load-end UI reset);
--  ScheduleChangelogIfNewVersion → CM.Config.MaybeShowChangelogOnNewVersion
--  (ConfigChangelogPanel.lua) when addon version changes (or always in Debug Mode).
--
--  Architecture:
--    • Loaded early (Core/Runtime.lua); defines _G.CM and CM.METADATA from the TOC.
--    • Calls into runtime modules: FreeLookController, Crosshair, ClickCasting,
--      Animations, AutoCursorUnlock, HealingRadial.
--    • Exposes globals for XML: CombatMode_OnEvent, CombatMode_OnUpdate, keybind
--      handlers (CombatMode_CursorModeKey, CombatMode_HealingRadialKey).
--    • Shared CVar helpers live in Core/RuntimeCVarManager.lua and are used by Config
--      and by Crosshair/Interaction HUD flows.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

-- WoW API
local C_Timer = _G.C_Timer
local DisableAddOn = _G.C_AddOns.DisableAddOn
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
local GetMacroInfo = _G.GetMacroInfo
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsMouselooking = _G.IsMouselooking
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local ipairs = _G.ipairs
local type = _G.type

-- INSTANTIATING ADDON & ENCAPSULATING NAMESPACE
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
_G["CM"] = CM

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

local function OpenConfigPanel()
  -- Standalone options window (UI/Options/OptionsPanel.lua). Combat guard and healing
  -- radial dismiss are handled inside CM.OpenOptions.
  if CM.OpenOptions then
    CM.OpenOptions()
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

local function ScheduleChangelogIfNewVersion()
  C_Timer.After(0.5, function()
    if CM.Config and CM.Config.MaybeShowChangelogOnNewVersion then
      CM.Config.MaybeShowChangelogOnNewVersion()
    end
  end)
end

local function DisplayPopup()
  -- Debug Mode re-plays the first-install welcome on every reload so the themed
  -- welcome modal can be verified without wiping SavedVariables.
  local debugMode = CM.DB.global and CM.DB.global.debugMode
  if (CM.DB.char.seenWarning and not debugMode) or not (CM.UI and CM.UI.ShowWelcome) then
    return false
  end

  -- Defer past Blizzard's load-end CloseSpecialWindows / UI reset. Showing a modal
  -- synchronously in OnEnable gets torn down immediately (OnHide → opens options +
  -- changelog), which is why the welcome appeared "missing" while the changelog still
  -- showed.
  CM.DebugPrint("Scheduling first-install welcome modal")
  C_Timer.After(0.75, function()
    if not (CM.UI and CM.UI.ShowWelcome) then
      return
    end
    if CM.DB.char.seenWarning and not (CM.DB.global and CM.DB.global.debugMode) then
      ScheduleChangelogIfNewVersion()
      return
    end
    CM.DebugPrint("Showing first-install welcome modal")
    CM.UI.ShowWelcome(CM.Constants.PopupMsg, function()
      CM.DB.char.seenWarning = true
      OpenConfigPanel()
      ScheduleChangelogIfNewVersion()
    end)
  end)
  return true
end

function CM.MacroExists(name)
  return GetMacroInfo(name) ~= nil
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
        .. "|cff909090: |cffE52B50DynamicCam detected!|r Handing over control of |cffE37527• Action Camera|r.|r"
    )
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

CM.RuntimeRematch = Rematch

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

    if CM.IsDefaultMouseActionBeingUsed() then
      return
    end

    if CM.ShouldFreeLookBeOff() then
      CM.UnlockFreeLook()
      return
    end

    if not IsMouselooking() then
      CM.LockFreeLook()
    end

    CM.UpdateCrosshairReaction()
    if CM.UpdateCrosshairAssistedHighlight then
      CM.UpdateCrosshairAssistedHighlight()
    end
  end
end

---------------------------------------------------------------------------------------
--                            KEYBIND FUNCTIONS & COMMANDS                           --
---------------------------------------------------------------------------------------
-- FUNCTIONS CALLED FROM BINDINGS.XML

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

-- CREATING /CM CHAT COMMAND — opens the standalone options window.
function CM:OpenConfigCMD()
  OpenConfigPanel()
end

-- /UNDOCM CHAT COMMAND — resets CVars, disables the addon, reloads.
function CM:RunUndoCMD()
  UndoCMChanges()
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
function CM:OnEnable()
  CM.ApplyThirdPartyActionBarPolicy()

  CM.BootstrapFeatureModules()
  CM.BuildEventCategoryMap()

  -- Registering Blizzard Events from Constants.lua
  for eventName in pairs(CM.GetEventCategoryMap()) do
    self:RegisterEvent(eventName, _G.CombatMode_OnEvent)
  end

  -- Greeting message that is printed to chat on initial load
  if not CM.DB.global.silenceAlerts then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r"
    )
  end

  -- Welcome modal owns the post-dismiss changelog schedule. Only open the changelog
  -- from here when the welcome was skipped (already seen, and not Debug Mode).
  if not DisplayPopup() then
    ScheduleChangelogIfNewVersion()
  end
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
