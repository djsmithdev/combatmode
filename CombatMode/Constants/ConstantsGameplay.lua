---------------------------------------------------------------------------------------
--  Constants/ConstantsGameplay.lua — constants module: gameplay tables
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

CM.Constants.Macros = {
  CM_ClearTarget = "/stopmacro [noexists]\n/cleartarget",
  CM_ClearFocus = "/stopmacro [noexists]\n/clearfocus",
  CM_ToggleFocusAny = "/focus [@focus,exists] none; [@mouseover,exists][]",
  CM_ToggleFocusEnemy = "/focus [@focus,exists] none; [@mouseover,exists,harm,nodead][]",
  CM_ToggleFocusTarget = "/focus [@focus,exists] none; [@target,exists][]"
}

-- EVENTS TO BE TRACKED
CM.Constants.BLIZZARD_EVENTS = {
  -- Events that fire UnlockFreeLook()
  UNLOCK_EVENTS = {
    "LOADING_SCREEN_ENABLED", -- This forces a relock when quick-loading (e.g: loading after starting m+ run) thanks to the OnUpdate fn
    "BARBER_SHOP_OPEN", "CINEMATIC_START", "PLAY_MOVIE",
    "HOUSE_EDITOR_MODE_CHANGED"
  },
  -- Events that fire LockFreeLook()
  LOCK_EVENTS = { "CINEMATIC_STOP", "STOP_MOVIE" },
  -- Events that fire Rematch()
  REMATCH_EVENTS = {
    "PLAYER_ENTERING_WORLD" -- Loading Cvars on every reload
  },
  FRIENDLY_TARGETING_EVENTS = {
    "PLAYER_REGEN_ENABLED", -- Disabling friendly targeting when leaving combat
    "PLAYER_REGEN_DISABLED" -- Enabling friendly targeting when entering combat
  },
  -- Events that don't fall within the previous categories
  UNCATEGORIZED_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED", -- Toggling crosshair when mounting/dismounting
    "PLAYER_REGEN_ENABLED"          -- Resetting crosshair when leaving combat
  },
  -- Events that trigger refresh of click-cast bindings (and Healing Radial slice attrs when applicable)
  REFRESH_BINDINGS_EVENTS = {
    "UPDATE_BINDINGS",                                                -- User changed/saved keybinds; refresh overrides so they match new bindings
    "HOUSE_EDITOR_MODE_CHANGED",                                      -- Enter/exit housing edit mode; refresh so action bar overrides are skipped in editor
    "GROUP_ROSTER_UPDATE",                                            -- Party composition changed
    "ACTIONBAR_SLOT_CHANGED",                                         -- Action bar spell/item changed
    "UPDATE_VEHICLE_ACTIONBAR",                                       -- Vehicle action bar updated
    "UPDATE_POSSESS_BAR", "PET_BAR_UPDATE", "UPDATE_BONUS_ACTIONBAR", -- Bonus bar changed (druid form, rogue stealth, etc.)
    "UPDATE_OVERRIDE_ACTIONBAR",                                      -- Override bar appeared/changed (vehicle, quest UI)
    "UPDATE_SHAPESHIFT_FORM",                                         -- Shapeshift form changed
    "ACTIONBAR_PAGE_CHANGED",                                         -- Action bar page switched
    "PLAYER_GAINS_VEHICLE_DATA",                                      -- Player entered a vehicle
    "PLAYER_LOSES_VEHICLE_DATA",                                      -- Player exited a vehicle
    "UNIT_ENTERED_VEHICLE",                                           -- Player entered a vehicle (alternative)
    "UNIT_EXITED_VEHICLE"                                             -- Player exited a vehicle (alternative)
  },
  -- Events for focus lock detection
  FOCUS_LOCK_EVENTS = {
    "PLAYER_FOCUS_CHANGED" -- Focus changed (lock-in animation)
  }

}

CM.Constants.ActionsToProcess = {
  "ACTIONBUTTON1", "ACTIONBUTTON2", "ACTIONBUTTON3", "ACTIONBUTTON4",
  "ACTIONBUTTON5", "ACTIONBUTTON6", "ACTIONBUTTON7", "ACTIONBUTTON8",
  "ACTIONBUTTON9", "ACTIONBUTTON10", "ACTIONBUTTON11", "ACTIONBUTTON12",
  "MULTIACTIONBAR1BUTTON1", "MULTIACTIONBAR1BUTTON2",
  "MULTIACTIONBAR1BUTTON3", "MULTIACTIONBAR1BUTTON4",
  "MULTIACTIONBAR1BUTTON5", "MULTIACTIONBAR1BUTTON6",
  "MULTIACTIONBAR1BUTTON7", "MULTIACTIONBAR1BUTTON8",
  "MULTIACTIONBAR1BUTTON9", "MULTIACTIONBAR1BUTTON10",
  "MULTIACTIONBAR1BUTTON11", "MULTIACTIONBAR1BUTTON12",
  "MULTIACTIONBAR2BUTTON1", "MULTIACTIONBAR2BUTTON2",
  "MULTIACTIONBAR2BUTTON3", "MULTIACTIONBAR2BUTTON4",
  "MULTIACTIONBAR2BUTTON5", "MULTIACTIONBAR2BUTTON6",
  "MULTIACTIONBAR2BUTTON7", "MULTIACTIONBAR2BUTTON8",
  "MULTIACTIONBAR2BUTTON9", "MULTIACTIONBAR2BUTTON10",
  "MULTIACTIONBAR2BUTTON11", "MULTIACTIONBAR2BUTTON12",
  "MULTIACTIONBAR3BUTTON1", "MULTIACTIONBAR3BUTTON2",
  "MULTIACTIONBAR3BUTTON3", "MULTIACTIONBAR3BUTTON4",
  "MULTIACTIONBAR3BUTTON5", "MULTIACTIONBAR3BUTTON6",
  "MULTIACTIONBAR3BUTTON7", "MULTIACTIONBAR3BUTTON8",
  "MULTIACTIONBAR3BUTTON9", "MULTIACTIONBAR3BUTTON10",
  "MULTIACTIONBAR3BUTTON11", "MULTIACTIONBAR3BUTTON12",
  "MULTIACTIONBAR4BUTTON1", "MULTIACTIONBAR4BUTTON2",
  "MULTIACTIONBAR4BUTTON3", "MULTIACTIONBAR4BUTTON4",
  "MULTIACTIONBAR4BUTTON5", "MULTIACTIONBAR4BUTTON6",
  "MULTIACTIONBAR4BUTTON7", "MULTIACTIONBAR4BUTTON8",
  "MULTIACTIONBAR4BUTTON9", "MULTIACTIONBAR4BUTTON10",
  "MULTIACTIONBAR4BUTTON11", "MULTIACTIONBAR4BUTTON12", "FOCUSTARGET",
  "FOLLOWTARGET", "INTERACTTARGET", "INTERACTMOUSEOVER", "JUMP",
  "MOVEANDSTEER", "MOVEBACKWARD", "MOVEFORWARD", "TARGETFOCUS",
  "TARGETLASTHOSTILE", "TARGETLASTTARGET", "TARGETNEARESTENEMY",
  "TARGETNEARESTENEMYPLAYER", "TARGETNEARESTFRIEND",
  "TARGETNEARESTFRIENDPLAYER", "TARGETPET", "TARGETPREVIOUSENEMY",
  "TARGETPREVIOUSENEMYPLAYER", "TARGETPREVIOUSFRIEND",
  "TARGETPREVIOUSFRIENDPLAYER", "TARGETSCANENEMY", "TARGETSELF",
  "TARGETMOUSEOVER", "ASSISTTARGET", "ATTACKTARGET", "PETATTACK",
  "STARTATTACK", "STOPATTACK", "STOPCASTING", "EXTRAACTIONBUTTON1",
  "ACTIONPAGE1", "ACTIONPAGE2", "ACTIONPAGE3", "ACTIONPAGE4", "ACTIONPAGE5",
  "ACTIONPAGE6", "BONUSACTIONBUTTON1", "BONUSACTIONBUTTON10",
  "BONUSACTIONBUTTON2", "BONUSACTIONBUTTON3", "BONUSACTIONBUTTON4",
  "BONUSACTIONBUTTON5", "BONUSACTIONBUTTON6", "BONUSACTIONBUTTON7",
  "BONUSACTIONBUTTON8", "BONUSACTIONBUTTON9", "CAMERAZOOMIN", "CAMERAZOOMOUT",
  "DISMOUNT", "NEXTACTIONPAGE", "PREVIOUSACTIONPAGE", "RAIDTARGET1",
  "RAIDTARGET2", "RAIDTARGET3", "RAIDTARGET4", "RAIDTARGET5", "RAIDTARGET6",
  "RAIDTARGET7", "RAIDTARGET8", "RAIDTARGETNONE", "SCREENSHOT",
  "SHAPESHIFTBUTTON1", "SHAPESHIFTBUTTON10", "SHAPESHIFTBUTTON2",
  "SHAPESHIFTBUTTON3", "SHAPESHIFTBUTTON4", "SHAPESHIFTBUTTON5",
  "SHAPESHIFTBUTTON6", "SHAPESHIFTBUTTON7", "SHAPESHIFTBUTTON8",
  "SHAPESHIFTBUTTON9", "STRAFELEFT", "STRAFERIGHT", "TARGETPARTYMEMBER1",
  "TARGETPARTYMEMBER2", "TARGETPARTYMEMBER3", "TARGETPARTYMEMBER4",
  "TOGGLEAUTORUN", "TURNLEFT", "TURNRIGHT"
}

CM.Constants.OverrideActions = {
  CLEARFOCUS = "|cff69ccf0Clear Focus|r",
  CLEARTARGET = "|cff69ccf0Clear Target|r",
  TOGGLEFOCUSANY = "|cff69ccf0Toggle Focus Any|r",
  TOGGLEFOCUSENEMY = "|cff69ccf0Toggle Focus Enemy|r",
  MACRO = "|cff69ccf0Run MACRO|r"
}

CM.Constants.ButtonsToOverride = {
  "button1", "button2", "shiftbutton1", "shiftbutton2", "ctrlbutton1",
  "ctrlbutton2", "altbutton1", "altbutton2"
}
