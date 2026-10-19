---------------------------------------------------------------------------------------
--  Core/Runtime/Runtime.lua — RUNTIME — addon shell, DB, slash, OnUpdate
---------------------------------------------------------------------------------------
--  What it does: Receives the AddOn namespace (`local addonName, CM = ...`), optional
--  `_G.CM` alias, TOC METADATA, native CombatModeDB merge, slash `/acm` `/actioncombatmode`,
--  lifecycle (ADDON_LOADED / PLAYER_LOGIN → OnInitialize / OnEnable), Rematch
--  coordination, throttled CombatMode_OnUpdate (ReconcileFreeLook + crosshair reaction),
--  welcome/changelog scheduling, and UninstallCombatMode.
--  Architecture / how it works:
--    • InitDatabase merges Constants.DatabaseDefaults into global + char["Name - Realm"],
--      then coerces Forever-style 1/0 flags to real booleans (CM.DbBool / NormalizeBools)
--      wherever defaults declare a boolean — so == true / ~= false / if x stay correct.
--      Also drops leftover global.partyRadial (feature removed in 4.7.0), turns the old
--      reticleHideSoftIndicator toggle into global.selectionCircleMode and the
--      assistedHighlightEnabled toggle into global.assistedHighlightMode, drops the
--      interactionHUDSide / Scale / Padding keys (Interaction HUD merged into Combat Assist), and
--      turns off click-cast slots that used the removed Toggle Focus Any / Enemy actions.
--      Rewrites the shipped situational default (dead-or-stealth + Arrows) to
--      dead-only + Invisible when the saved values still match that default.
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
  -- Standalone options window (UI/Options/OptionsPanel.lua). Combat guard is
  -- handled inside CM.OpenOptions.
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
  if not (CM.UI and CM.UI.ShowWelcome) then
    return false
  end
  if CM.DB.global.seenWarning and not debugMode then
    -- Account that never saw the setup wizard (installed before it existed): run the tour
    -- once, without the welcome modal. Finishing or skipping sets seenWizard, and the
    -- wizard then opens the changelog if this version has not been seen.
    if CM.DB.global.seenWizard or not (CM.Wizard and CM.Wizard.Start) then
      return false
    end
    C_Timer.After(0.75, function()
      if CM.DB.global.seenWizard or not (CM.Wizard and CM.Wizard.Start) then
        ScheduleChangelogIfNewVersion()
        return
      end
      CM.DebugPrint("Starting setup wizard for an existing install")
      CM.Wizard.Start()
    end)
    return true
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
    if CM.DB.global.seenWarning and not (CM.DB.global and CM.DB.global.debugMode) then
      ScheduleChangelogIfNewVersion()
      return
    end
    CM.DebugPrint("Showing first-install welcome modal")
    CM.UI.ShowWelcome(CM.Constants.PopupMsg, function()
      CM.DB.global.seenWarning = true
      -- New installs go through the setup wizard (it opens the options panel for its tour);
      -- if it is unavailable fall back to just opening the panel.
      if CM.Wizard and CM.Wizard.Start and (not CM.DB.global.seenWizard or debugMode) then
        -- A new install (or reset) has nothing to catch up on, so the changelog stays out of
        -- the wizard's way: count this version as seen instead of opening it beside the tour.
        CM.DB.global.lastSeenChangelogVersion = CM.METADATA["VERSION"]
        CM.Wizard.Start()
      else
        OpenConfigPanel()
        ScheduleChangelogIfNewVersion()
      end
    end)
  end)
  return true
end

function CM.MacroExists(name)
  return GetMacroInfo(name) ~= nil
end

--[[
  Checking if DynamicCam or SteadyCam are loaded so we can relinquish camera controls.
  Autofocus Locked Target stays with Combat Mode. When shoulderFollowsMouseLook is on,
  permanent unlock still eases shoulder to 0 (then restores on re-lock).
]]
--
local function IsCamAddonLoaded()
  CM.SteadyCam = IsAddOnLoaded("SteadyCam")
  CM.DynamicCam = IsAddOnLoaded("DynamicCam")

  CM.CameraOwner = CM.SteadyCam and "SteadyCam" or CM.DynamicCam and "DynamicCam" or nil

  if CM.CameraOwner and not CM.DB.global.silenceAlerts then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: |cffE52B50"
        .. CM.CameraOwner
        .. " detected!|r Handing over turn speed, shoulder, and dynamic pitch.|r"
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

--- Coerce SavedVariables truthy flags. Forever may store 1/0 instead of true/false;
--- Lua treats 0 as truthy, and `x == true` fails for 1 — both break feature gates.
function CM.DbBool(value, default)
  if value == nil then
    return default and true or false
  end
  if value == false or value == 0 then
    return false
  end
  if value == true or value == 1 then
    return true
  end
  return not not value
end

--- Where defaults declare a boolean, rewrite Forever 1/0 (and keep real bools) in place.
-- Click-cast Toggle Focus Any / Enemy were removed (the Target Lock key replaces them): turn off any
-- slot still using one so no removed action stays selected.
local REMOVED_CLICK_CAST_ACTIONS = { TOGGLEFOCUSANY = true, TOGGLEFOCUSENEMY = true }
local function DropRemovedClickCastActions(bindings)
  if type(bindings) ~= "table" then
    return
  end
  for _, setting in pairs(bindings) do
    if type(setting) == "table" and REMOVED_CLICK_CAST_ACTIONS[setting.value] then
      setting.enabled = false
      setting.value = "CLEARFOCUS"
    end
  end
end

local function NormalizeBools(dest, defaults)
  if type(dest) ~= "table" or type(defaults) ~= "table" then
    return
  end
  for k, def in pairs(defaults) do
    local cur = dest[k]
    if type(def) == "boolean" then
      if cur ~= nil then
        dest[k] = CM.DbBool(cur, def)
      end
    elseif type(def) == "table" and type(cur) == "table" then
      NormalizeBools(cur, def)
    end
  end
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

  -- Saved crosshair appearances are resolved before the merge: MergeDefaults would graft the
  -- default table's other keys (BaseId/ActiveId, or Hidden on the situational one) onto a saved
  -- table of a different shape. NormalizeCrosshairAppearance rebuilds them from the catalog ids.
  local savedGlobal = type(sv.global) == "table" and sv.global or {}
  local savedAppearance = savedGlobal.crosshairAppearance
  local savedSituational = savedGlobal.crosshairSituationalAppearance

  sv.global = MergeDefaults(sv.global or {}, defaults.global or {})
  NormalizeBools(sv.global, defaults.global or {})
  if savedAppearance ~= nil then
    sv.global.crosshairAppearance = CM.Constants.NormalizeCrosshairAppearance(savedAppearance)
      or CM.Constants.CrosshairTextureObj.Default
  end
  if savedSituational ~= nil then
    sv.global.crosshairSituationalAppearance = CM.Constants.NormalizeCrosshairAppearance(
      savedSituational
    ) or CM.Constants.CrosshairSituationalHidden
  end

  if type(sv.char) ~= "table" then
    sv.char = {}
  end
  local charKey = GetCharKey()
  sv.char[charKey] = MergeDefaults(sv.char[charKey] or {}, defaults.char or {})
  NormalizeBools(sv.char[charKey], defaults.char or {})
  -- Removed click-cast actions: every saved binding set (account-wide and each character).
  DropRemovedClickCastActions(sv.global.bindings)
  for _, charDb in pairs(sv.char) do
    if type(charDb) == "table" then
      DropRemovedClickCastActions(charDb.bindings)
    end
  end

  BindDatabaseViews(sv, charKey)
  -- Welcome / setup wizard flags moved from per-character to account-wide: any character
  -- that already saw them counts for the whole account.
  for _, charDb in pairs(sv.char) do
    if type(charDb) == "table" then
      if charDb.seenWarning ~= nil then
        sv.global.seenWarning = sv.global.seenWarning or charDb.seenWarning == true
        charDb.seenWarning = nil
      end
      if charDb.seenWizard ~= nil then
        sv.global.seenWizard = sv.global.seenWizard or CM.DbBool(charDb.seenWizard, false)
        charDb.seenWizard = nil
      end
    end
  end
  -- Party Radial removed in 4.7.0; drop leftover settings so they do not linger in SV.
  if sv.global then
    sv.global.partyRadial = nil
    -- The Combat Assist on/off toggle became the always / only in combat / hidden dropdown.
    if sv.global.assistedHighlightEnabled ~= nil then
      local on = CM.DbBool(sv.global.assistedHighlightEnabled, true)
      sv.global.assistedHighlightMode = on and "always" or "hidden"
      sv.global.assistedHighlightEnabled = nil
    end
    -- The Interaction HUD merged into the Combat Assist HUD; it shares that HUD's layout.
    sv.global.interactionHUDSide = nil
    sv.global.interactionHUDScale = nil
    sv.global.interactionHUDPadding = nil
    -- 5.0.3's Hide Soft Targeting Indicator toggle became the Selection Circle dropdown.
    if sv.global.reticleHideSoftIndicator ~= nil then
      local hidden = CM.DbBool(sv.global.reticleHideSoftIndicator, true)
      sv.global.selectionCircleMode = hidden and "target" or "soft"
      sv.global.reticleHideSoftIndicator = nil
    end
    local oldSituational = 'local deadOrGhost = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")\n'
      .. "local isPlayerStealthed = IsStealthed and IsStealthed()\n"
      .. "if deadOrGhost or isPlayerStealthed then\n"
      .. "  return true end\n"
      .. "return false\n"
    local function TrimEnd(text)
      return (text:gsub("%s+$", ""))
    end
    if
      type(sv.global.crosshairSituationalCondition) == "string"
      and TrimEnd(sv.global.crosshairSituationalCondition) == TrimEnd(oldSituational)
    then
      sv.global.crosshairSituationalCondition = defaults.global.crosshairSituationalCondition
      local appearance = sv.global.crosshairSituationalAppearance
      if type(appearance) == "table" and appearance.Name == "Arrows" then
        sv.global.crosshairSituationalAppearance = CM.Constants.CrosshairSituationalHidden
      end
    end
  end
  if CM.MigrateMouseLookCameraDB then
    CM.MigrateMouseLookCameraDB()
  end
end

function CM:OnResetDB()
  CM.DebugPrint("Reseting Action Combat Mode settings.")
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
  IsCamAddonLoaded()

  IsCamAddonLoaded()

  CM.SetMouseLookSpeed()
  if CM.SetDynamicPitch then
    CM.SetDynamicPitch()
  end
  if CM.SetShoulderOffset then
    CM.SetShoulderOffset()
  end
  if CM.SyncTargetFocusFromFocusUnit then
    CM.SyncTargetFocusFromFocusUnit()
  end
  -- ApplyMouseLookCamera (MS + shoulder retarget) also runs from LockFreeLook.

  if CM.DB.char.reticleTargeting then
    CM.ConfigReticleTargeting("combatmode")

    if not CM.DB.char.reticleTargetingEnemyOnly then
      CM.HandleSoftTargetFriend(true)
    end
  elseif CM.IsCrosshairEnabled() and CM.IsInteractionHUDEnabled() then
    CM.ConfigInteractionHUDSoftTarget()
  end

  CM.OnRematchCrosshair()

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

--- Free-look half of the tick: unlock when something wants the cursor, otherwise (re)lock.
--- Also run straight from CURRENT_SPELL_CAST_CHANGED so a ground spell frees the cursor (and
--- placing or cancelling it re-locks) without waiting for the next throttled tick.
--- Returns true when the caller may go on to the crosshair updates.
function CM.ReconcileFreeLook()
  if CM.IsDefaultMouseActionBeingUsed() then
    return false
  end

  local isMouselooking = IsMouselooking()

  if CM.ShouldFreeLookBeOff() then
    CM.UnlockFreeLook()
    return false
  end

  -- OPie may rematch mouselook itself after freeing CursorFreelookCentering; a plain
  -- LockFreeLook no-ops when already looking and leaves the cursor visible.
  if not (CM.RematchFreeLookAfterOpieIfNeeded and CM.RematchFreeLookAfterOpieIfNeeded()) then
    if not isMouselooking then
      CM.LockFreeLook()
    end
  end
  return true
end

function _G.CombatMode_OnUpdate(_, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  TIME_SINCE_LAST_UPDATE = TIME_SINCE_LAST_UPDATE + elapsed

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if TIME_SINCE_LAST_UPDATE >= ON_UPDATE_INTERVAL then
    TIME_SINCE_LAST_UPDATE = 0

    CM.Profile("CombatMode_OnUpdate:fullTick", function()
      if not CM.ReconcileFreeLook() then
        return
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

-- CREATING /CM CHAT COMMAND — opens the standalone options window.
function CM:OpenConfigCMD()
  OpenConfigPanel()
end

local function RegisterSlashCommands()
  _G.SLASH_COMBATMODE1 = "/acm"
  _G.SLASH_COMBATMODE2 = "/actioncombatmode"
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
        .. "|cff909090: Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings.|r"
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
