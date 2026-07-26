---------------------------------------------------------------------------------------
--  Core/Runtime.lua — RUNTIME — addon shell, lifecycle, free look, global drivers
---------------------------------------------------------------------------------------
--  Instantiates the Combat Mode AddOn namespace (`CM` via `...`), SavedVariables
--  (CombatModeDB), and slash commands. Options live in the standalone window
--  (UI/Options/*; CM.OpenOptions). Coordinates runtime modules, Rematch on layout/reload,
--  and the throttled global OnUpdate loop that enforces free look via
--  Core/FreeLookController.lua and refreshes crosshair reactions. First-login welcome
--  modal (CM.UI.ShowWelcome, deferred past load-end UI reset);
--  ScheduleChangelogIfNewVersion → CM.Config.MaybeShowChangelogOnNewVersion
--  (UI/Changelog/ChangelogPanel.lua) when addon version changes (or always in Debug Mode).
--
--  Architecture:
--    • Loaded early (Core/Runtime.lua); receives the shared AddOn namespace table and
--      sets CM.METADATA from the TOC. Other modules use `local _, CM = ...`.
--    • Optional `_G.CM = CM` alias for debug / external scripts (primary handle is `...`).
--    • Lifecycle: ADDON_LOADED → InitDatabase + slash; PLAYER_LOGIN → enable/bootstrap.
--    • Calls into runtime modules: FreeLookController, Crosshair, ClickCasting,
--      Animations, AutoCursorUnlock, HealingRadial.
--    • Exposes globals for XML: CombatMode_OnEvent, CombatMode_OnUpdate, keybind
--      handlers (CombatMode_CursorModeKey, CombatMode_HealingRadialKey).
--    • Shared CVar helpers live in Core/RuntimeCVarManager.lua and are used by editors
--      and by Crosshair/Interaction HUD flows.
---------------------------------------------------------------------------------------
local addonName, CM = ...
local _G = _G

-- Debug / WeakAura / macro compatibility only — modules must use `local _, CM = ...`.
_G.CM = CM

-- WoW API
local C_AddOns = _G.C_AddOns
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local DisableAddOn = C_AddOns.DisableAddOn
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata
local GetMacroInfo = _G.GetMacroInfo
local GetRealmName = _G.GetRealmName
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local IsMouselooking = _G.IsMouselooking
local MouselookStop = _G.MouselookStop
local ReloadUI = _G.ReloadUI
local UnitName = _G.UnitName

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local string_upper = _G.string.upper
local type = _G.type
local tostring = _G.tostring

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
    dataReturned[string_upper(key)] = GetAddOnMetadata(addonName, key)
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
  if CM.OnDisable then
    CM:OnDisable()
  end
  DisableAddOn(addonName)
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
  local loaded = IsAddOnLoaded("DynamicCam")
  CM.DynamicCam = loaded and true or false
  if CM.DynamicCam and not CM.DB.global.silenceAlerts then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: |cffE52B50DynamicCam detected!|r Handing over control of |cffE37527• Action Camera|r.|r"
    )
  end
end

---------------------------------------------------------------------------------------
--                              SAVED VARIABLES (NATIVE)                             --
---------------------------------------------------------------------------------------
-- AceDB-compatible on-disk shape: CombatModeDB.global + CombatModeDB.char["Name - Realm"].
-- Application code keeps using CM.DB.global / CM.DB.char.

local function DeepCopy(src)
  if type(src) ~= "table" then
    return src
  end
  local copy = {}
  for k, v in pairs(src) do
    copy[k] = DeepCopy(v)
  end
  return copy
end

--- Fill missing keys from defaults (nested). Does not overwrite existing user values.
local function MergeDefaults(dest, defaults)
  if type(defaults) ~= "table" then
    return dest
  end
  if type(dest) ~= "table" then
    dest = {}
  end
  for k, v in pairs(defaults) do
    if type(v) == "table" then
      if type(dest[k]) ~= "table" then
        dest[k] = DeepCopy(v)
      else
        MergeDefaults(dest[k], v)
      end
    elseif dest[k] == nil then
      dest[k] = v
    end
  end
  return dest
end

local function GetCharKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Unknown"
  return name .. " - " .. realm
end

local function BindDatabaseViews(sv, charKey)
  CM.DB = {
    global = sv.global,
    char = sv.char[charKey],
  }
end

function CM.InitDatabase()
  local defaults = CM.Constants.DatabaseDefaults
  _G.CombatModeDB = _G.CombatModeDB or {}
  local sv = _G.CombatModeDB

  sv.global = MergeDefaults(sv.global or {}, defaults.global or {})

  if type(sv.char) ~= "table" then
    sv.char = {}
  end
  local charKey = GetCharKey()
  sv.char[charKey] = MergeDefaults(sv.char[charKey] or {}, defaults.char or {})

  BindDatabaseViews(sv, charKey)
end

function CM:OnResetDB()
  CM.DebugPrint("Reseting Combat Mode settings.")
  local defaults = CM.Constants.DatabaseDefaults
  local sv = _G.CombatModeDB or {}
  for k in pairs(sv) do
    sv[k] = nil
  end
  _G.CombatModeDB = sv

  local charKey = GetCharKey()
  sv.global = DeepCopy(defaults.global or {})
  sv.char = {
    [charKey] = DeepCopy(defaults.char or {}),
  }
  BindDatabaseViews(sv, charKey)
  ReloadUI()
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

  -- Early OnUpdate can start mouselook before Rematch; CursorFreelookCentering only
  -- hides the cursor across a fresh start (force 0 → Start → deferred 1). Bounce so
  -- LockFreeLook is not a no-op when already looking.
  if IsMouselooking() then
    MouselookStop()
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

    -- OPie may rematch mouselook itself after freeing CursorFreelookCentering; a plain
    -- LockFreeLook no-ops when already looking and leaves the cursor visible.
    if not (CM.RematchFreeLookAfterOpieIfNeeded and CM.RematchFreeLookAfterOpieIfNeeded()) then
      if not IsMouselooking() then
        CM.LockFreeLook()
      end
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

local function RegisterSlashCommands()
  _G.SLASH_COMBATMODE1 = "/cm"
  _G.SLASH_COMBATMODE2 = "/combatmode"
  _G.SlashCmdList["COMBATMODE"] = function()
    CM:OpenConfigCMD()
  end

  _G.SLASH_UNDOCM1 = "/undocm"
  _G.SlashCmdList["UNDOCM"] = function()
    CM:RunUndoCMD()
  end
end

---------------------------------------------------------------------------------------
--                                   LIFECYCLE                                       --
---------------------------------------------------------------------------------------
local initialized = false
local enabled = false

function CM:OnInitialize()
  if initialized then
    return
  end
  initialized = true
  CM.InitDatabase()
  RegisterSlashCommands()
end

function CM:OnEnable()
  if enabled then
    return
  end
  enabled = true

  CM.ApplyThirdPartyActionBarPolicy()

  CM.BootstrapFeatureModules()
  CM.BuildEventCategoryMap()

  -- Register Blizzard events on the root XML frame (OnEvent → CombatMode_OnEvent).
  local frame = _G.CombatModeFrame
  if frame then
    for eventName in pairs(CM.GetEventCategoryMap()) do
      frame:RegisterEvent(eventName)
    end
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

function CM:OnDisable()
  if not enabled then
    return
  end
  enabled = false
  CM.HideCrosshairFrame()
  self:ResetCVarsToDefault()
  local frame = _G.CombatModeFrame
  if frame then
    frame:UnregisterAllEvents()
  end
end

-- Bootstrap frame: ADDON_LOADED / PLAYER_LOGIN (CombatModeFrame is created later in Embeds).
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= addonName then
      return
    end
    CM:OnInitialize()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    CM:OnEnable()
    self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
