---------------------------------------------------------------------------------------
--  Core/Runtime/Runtime.lua — RUNTIME — addon shell, DB, slash, OnUpdate
---------------------------------------------------------------------------------------
--  What it does: Receives the AddOn namespace (`local addonName, CM = ...`), optional
--  `_G.CM` alias, TOC METADATA, native CombatModeDB merge, slash `/cm` `/combatmode`,
--  lifecycle (ADDON_LOADED / PLAYER_LOGIN → OnInitialize / OnEnable), Rematch
--  coordination, throttled CombatMode_OnUpdate (free-look + crosshair reaction),
--  welcome/changelog scheduling, and UninstallCombatMode.
--  Architecture / how it works:
--    • InitDatabase merges Constants.DatabaseDefaults into global + char["Name - Realm"].
--    • GetBindingsLocation → "global" vs "char" from useGlobalBindings.
--    • RuntimeRematch reapplies CVars/bindings/crosshair after PEW / rematch events.
--    • OnEnable registers root-frame events (via Bootstrap path) and starts freelook.
--    • Uninstall restores priorCVarSnapshot, BUTTON1/2 camera binds, disables addon,
--      ReloadUI.
--    • DebugPrint / DebugPrintThrottled gated by debugMode.
--  Does not: Own SetCVar helpers (CVarManager) or category dispatch (EventRouter).
--  Related: Core/Runtime/Bootstrap.lua, Core/Runtime/EventRouter.lua,
--  Core/Runtime/CVarManager.lua, Core/FreeLook/FreeLookController.lua,
--  Core/Crosshair/Crosshair.lua, UI/Options/OptionsPanel.lua,
--  UI/Changelog/ChangelogPanel.lua
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

--- One-time fixes for bad defaults already merged into SavedVariables.
local function MigrateSavedDatabase(sv)
  local g = sv.global
  if type(g) ~= "table" then
    return
  end
  local cond = g.crosshairSituationalCondition
  if type(cond) ~= "string" then
    return
  end
  local fixed = cond
  if fixed:find("isStealthed%(%)", 1, true) then
    fixed = fixed:gsub("isStealthed%(%)", "(IsStealthed and IsStealthed())")
  end
  fixed = fixed:gsub("\r?\nlocal isStealthed = IsStealthed and IsStealthed%(%)\r?\n", "\n")
  fixed = fixed:gsub("or isStealthed then", "or (IsStealthed and IsStealthed()) then")
  if fixed ~= cond then
    g.crosshairSituationalCondition = fixed
  end
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
  MigrateSavedDatabase(sv)
end

function CM:OnResetDB()
  CM.DebugPrint("Reseting Combat Mode settings.")
  local defaults = CM.Constants.DatabaseDefaults
  local sv = _G.CombatModeDB or {}

  -- Keep the pre-CM CVar snapshot so Uninstall still restores the player's original
  -- values after a settings wipe. (Next enable refreshes it before CM writes.)
  local priorCVars = CM.DB and CM.DB.global and CM.DB.global.priorCVarSnapshot

  for k in pairs(sv) do
    sv[k] = nil
  end
  _G.CombatModeDB = sv

  local charKey = GetCharKey()
  sv.global = DeepCopy(defaults.global or {})
  sv.char = {
    [charKey] = DeepCopy(defaults.char or {}),
  }
  if type(priorCVars) == "table" then
    sv.global.priorCVarSnapshot = priorCVars
  end
  BindDatabaseViews(sv, charKey)
  ReloadUI()
end

--- Full leave path: restore pre-CM CVars, reset left/right click to Blizzard camera
--- defaults, stop freelook, disable the addon, reload. Used by the options sidebar
--- Uninstall button.
function CM.UninstallCombatMode()
  if InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot uninstall while in combat.|r")
    return
  end

  if IsMouselooking() then
    MouselookStop()
  end

  if CM.RestorePriorCVars then
    CM.RestorePriorCVars()
  end
  if CM.RestorePriorBindings then
    CM.RestorePriorBindings()
  end

  if CM.OnDisable then
    -- Skip a second CVar restore; OnDisable only tears down UI/events here.
    CM:OnDisable(true)
  end

  print(
    CM.Constants.BasePrintMsg
      .. "|cff909090: restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon.|r"
  )
  DisableAddOn(addonName)
  ReloadUI()
end

---------------------------------------------------------------------------------------
--                                   EVENT HANDLING                                  --
---------------------------------------------------------------------------------------
-- Rematch is called after every reload and this is where we make sure our config persists
local function Rematch()
  -- Bootstrap already captured; Ensure is a no-op once sessionSnapshotCaptured is set.
  if CM.EnsurePriorCVarSnapshot then
    CM.EnsurePriorCVarSnapshot()
  end
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

  -- Dismiss party radial so it is not considered "active" after load (fixes crosshair
  -- not showing when party radial is enabled, since IsPartyRadialActive() would block)
  if CM.PartyRadial and CM.PartyRadial.DismissOnLoad then
    CM.PartyRadial.DismissOnLoad()
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

    CM.Profile("CombatMode_OnUpdate:fullTick", function()
      if CM.IsDefaultMouseActionBeingUsed() then
        return
      end

      local isMouselooking = IsMouselooking()

      if CM.ShouldFreeLookBeOff() then
        CM.UnlockFreeLook()
        return
      end

      -- OPie may rematch mouselook itself after freeing CursorFreelookCentering; a plain
      -- LockFreeLook no-ops when already looking and leaves the cursor visible.
      if not (CM.RematchFreeLookAfterOpieIfNeeded and CM.RematchFreeLookAfterOpieIfNeeded()) then
        if not isMouselooking then
          CM.LockFreeLook()
        end
      end

      CM.Profile("UpdateCrosshairReaction", CM.UpdateCrosshairReaction)
      if CM.UpdateCrosshairAssistedHighlight then
        CM.Profile("UpdateCrosshairAssistedHighlight", CM.UpdateCrosshairAssistedHighlight)
      end
    end)
  end
end

---------------------------------------------------------------------------------------
--                            KEYBIND FUNCTIONS & COMMANDS                           --
---------------------------------------------------------------------------------------
-- FUNCTIONS CALLED FROM BINDINGS.XML

function _G.CombatMode_PartyRadialKey(keystate)
  if not CM.PartyRadial then
    return
  end
  local HR = CM.PartyRadial
  CM.DebugPrint(
    "PartyRadialKey: keystate=" .. tostring(keystate) .. " isActive=" .. tostring(HR.IsActive())
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

local function RegisterSlashCommands()
  _G.SLASH_COMBATMODE1 = "/cm"
  _G.SLASH_COMBATMODE2 = "/combatmode"
  _G.SlashCmdList["COMBATMODE"] = function()
    CM:OpenConfigCMD()
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

function CM:OnDisable(skipCVarRestore)
  if not enabled then
    return
  end
  enabled = false
  CM.HideCrosshairFrame()
  if not skipCVarRestore and CM.RestorePriorCVars then
    CM.RestorePriorCVars()
  end
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
