---------------------------------------------------------------------------------------
--  Constants/Gameplay.lua — CONSTANTS — macros, event groups, bindable actions
---------------------------------------------------------------------------------------
--  What it does: Central static gameplay tables: account macros Combat Mode creates,
--  BLIZZARD_EVENTS category lists for EventRouter, ClickCastBars / ActionsToProcess /
--  OverrideActions / ButtonsToOverride for click-cast UI and secure overrides.
--  Architecture / how it works:
--    • Macros (texts only; run from secure proxy buttons, never created in the player's
--      macro list): CM_ClearTarget/Focus, CM_ToggleFocus{Any,Enemy} + CM_SwitchFocus{Any,Enemy} (Target Lock key)
--      (Toggle: target-first-then-mouseover on lock, clear focus + target on unlock; Switch: the unit
--      under the crosshair becomes the lock, an empty crosshair unlocks),
--      CM_CycleFocusEnemy{Next,Prev}, CM_StartAttack / CM_PetAttack (hostile /tar
--      then /startattack or /petattack; hides raw Blizzard STARTATTACK / PETATTACK)
--    • BLIZZARD_EVENTS groups: UNLOCK/LOCK/FREELOOK_RECONCILE/REMATCH, FRIENDLY_TARGETING,
--      SELECTION_CIRCLE,
--      UNCATEGORIZED, REFRESH_BINDINGS (bars/vehicles/CVAR_UPDATE), FOCUS_LOCK,
--      CAST_FEEDBACK (player cast/channel), ASSISTED_HIGHLIGHT
--      (ASSISTED_COMBAT_ACTION_SPELL_CAST), FOCUS_NAMEPLATE (nameplate add/remove for
--      Target Lock nameplate marker).
--    • ClickCastBars: ACTIONBUTTON + MULTIACTIONBAR1–7 (MultiBar5–7 = Dragonflight+
--      Edit Mode bars) with Blizzard frame prefixes and action-slot bases. Shared by
--      BindingOverrides, TargetingMacroBuilder, AddonActionBarResolver, Assist keybinds.
--    • ReticleTargetingBuiltinExcludeSpellIds: skyriding spells that skip preline injection
--      (not shown in the Excluded Spells options UI).
--    • ActionsToProcess = ClickCastBars slots + other bindable Blizzard actions
--      (pings, arena target/focus, vehicles, party pets, sit/sheath/run, pitch, …);
--      OverrideActions labels CM-specific clear/toggle/macro choices;
--      ButtonsToOverride lists the 8 mouse slots.
--  Does not: Register events, create macros, or SetOverrideBinding (Bootstrap /
--  EventRouter / BindingOverrides do).
--  Related: Core/Runtime/EventRouter.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/Runtime/Bootstrap.lua, UI/Options/Tabs/TabClickCasting.lua,
--  Core/Crosshair/AssistedHighlight/{CastProgress,Feedback,Assist}.lua,
--  Core/Crosshair/Animations.lua, Core/Crosshair/FocusNameplateMarker.lua
---------------------------------------------------------------------------------------
local _, CM = ...

-- Lua stdlib
local ipairs = _G.ipairs

CM.Constants.Macros = {
  CM_ClearTarget = "/stopmacro [noexists]\n/cleartarget",
  CM_ClearFocus = "/stopmacro [noexists]\n/clearfocus",
  -- A condition group with only @unit (no boolean) is ALWAYS true — need ,exists
  -- (or harm/nodead/etc.) so unlock / fallthrough works. [] = focus player last.
  CM_ToggleFocusAny = "/cleartarget [@focus,exists]\n/focus [@focus,exists] none; [@target,exists]; [@mouseover,exists][]\n/tar [@focus,exists]",
  CM_ToggleFocusEnemy = "/cleartarget [@focus,exists]\n/focus [@focus,exists] none; [@target,harm,nodead]; [@mouseover,harm,nodead][]\n/tar [@focus,exists]",
  -- Target Lock "Switch" behavior: the unit under the crosshair becomes the lock (replacing any
  -- current one); an empty crosshair unlocks. The Enemy variant ignores a friendly / dead unit under
  -- the crosshair (the lock stays: cleartarget + the focus re-target below restore the same target).
  CM_SwitchFocusAny = "/cleartarget [@focus,exists]\n/focus [@mouseover,exists]; [@mouseover,noexists] none\n/tar [@focus,exists]",
  CM_SwitchFocusEnemy = "/cleartarget [@focus,exists]\n/focus [@mouseover,harm,nodead]; [@mouseover,noexists] none\n/tar [@focus,exists]",
  -- Mouse-wheel Target Lock cycle (nearest / previous enemy, then focus).
  CM_CycleFocusEnemyNext = "/targetenemy [@focus,exists]\n/focus [@target,exists]",
  CM_CycleFocusEnemyPrev = "/targetenemy [@focus,exists] 1\n/focus [@target,exists]",
  -- Click-cast Start Attack / Pet Attack: hostile under the reticle, then swing.
  CM_StartAttack = "/tar [@focus,harm];[nomounted,@mouseover,harm,nodead][nomounted,@anyenemy]\n/startattack",
  CM_PetAttack = "/tar [@focus,harm];[nomounted,@mouseover,harm,nodead][nomounted,@anyenemy]\n/petattack",
}

-- Blizzard bindings that Combat Mode replaces in Click Casting with a macro of its own (keyed by
-- binding name, listed first and tinted in the action dropdown). Both act on the unit under the
-- crosshair (@mouseover); the markers prefer the hard target and only use the unit under the
-- crosshair when there is none.
--  • Ping System: /ping types are the locale-independent numbers 1 Attack, 2 Warning, 3 On My Way,
--    4 Assist; no type is the contextual ping (Blizzard's "Ping"). Unit pings only: /ping @cursor
--    would use the real cursor position, which stays where the cursor was before Mouse Look.
--  • Raid target markers: /tm <1-8, 0 clears>.
CM.Constants.BlizzardActionMacros = {
  TOGGLEPINGLISTENER = "/ping [@mouseover,exists]",
  PINGATTACK = "/ping [@mouseover,exists] 1",
  PINGWARNING = "/ping [@mouseover,exists] 2",
  PINGONMYWAY = "/ping [@mouseover,exists] 3",
  PINGASSIST = "/ping [@mouseover,exists] 4",
}
CM.Constants.BlizzardActionOrder = {
  "TOGGLEPINGLISTENER",
  "PINGATTACK",
  "PINGWARNING",
  "PINGONMYWAY",
  "PINGASSIST",
}
for marker = 1, 8 do
  local id = "RAIDTARGET" .. marker
  CM.Constants.BlizzardActionMacros[id] = "/tm [@target,exists] "
    .. marker
    .. "; [@mouseover,exists] "
    .. marker
  CM.Constants.BlizzardActionOrder[#CM.Constants.BlizzardActionOrder + 1] = id
end
CM.Constants.BlizzardActionMacros.RAIDTARGETNONE = "/tm [@target,exists] 0; [@mouseover,exists] 0"
CM.Constants.BlizzardActionOrder[#CM.Constants.BlizzardActionOrder + 1] = "RAIDTARGETNONE"

-- EVENTS TO BE TRACKED
CM.Constants.BLIZZARD_EVENTS = {
  -- Events that fire UnlockFreeLook()
  UNLOCK_EVENTS = {
    "LOADING_SCREEN_ENABLED", -- This forces a relock when quick-loading (e.g: loading after starting m+ run) thanks to the OnUpdate fn
    "BARBER_SHOP_OPEN",
    "CINEMATIC_START",
    "PLAY_MOVIE",
    "HOUSE_EDITOR_MODE_CHANGED",
  },
  -- Events that fire LockFreeLook()
  LOCK_EVENTS = { "CINEMATIC_STOP", "STOP_MOVIE" },
  -- Events that run the free-look check right away instead of waiting for the next tick
  FREELOOK_RECONCILE_EVENTS = {
    "CURRENT_SPELL_CAST_CHANGED", -- Ground spell (green circle) started / placed / cancelled
  },
  -- Events that fire Rematch()
  REMATCH_EVENTS = {
    "PLAYER_ENTERING_WORLD", -- Loading Cvars on every reload
  },
  FRIENDLY_TARGETING_EVENTS = {
    "PLAYER_REGEN_ENABLED", -- Disabling friendly targeting when leaving combat
    "PLAYER_REGEN_DISABLED", -- Enabling friendly targeting when entering combat
  },
  -- Events that don't fall within the previous categories
  UNCATEGORIZED_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED", -- Toggling crosshair when mounting/dismounting
    "PLAYER_REGEN_ENABLED", -- Resetting crosshair when leaving combat
  },
  -- Events that trigger refresh of click-cast bindings (and Ally Cycle roster when applicable)
  REFRESH_BINDINGS_EVENTS = {
    "UPDATE_BINDINGS", -- User changed/saved keybinds; refresh overrides so they match new bindings
    "HOUSE_EDITOR_MODE_CHANGED", -- Enter/exit housing edit mode; refresh so action bar overrides are skipped in editor
    "GROUP_ROSTER_UPDATE", -- Party composition changed
    "ACTIONBAR_SLOT_CHANGED", -- Action bar spell/item changed
    "UPDATE_VEHICLE_ACTIONBAR", -- Vehicle action bar updated
    "UPDATE_POSSESS_BAR",
    "PET_BAR_UPDATE",
    "UPDATE_BONUS_ACTIONBAR", -- Bonus bar changed (druid form, rogue stealth, etc.)
    "UPDATE_OVERRIDE_ACTIONBAR", -- Override bar appeared/changed (vehicle, quest UI)
    "UPDATE_SHAPESHIFT_FORM", -- Shapeshift form changed
    "ACTIONBAR_PAGE_CHANGED", -- Action bar page switched
    "PLAYER_GAINS_VEHICLE_DATA", -- Player entered a vehicle
    "PLAYER_LOSES_VEHICLE_DATA", -- Player exited a vehicle
    "UNIT_ENTERED_VEHICLE", -- Player entered a vehicle (alternative)
    "UNIT_EXITED_VEHICLE", -- Player exited a vehicle (alternative)
    "CVAR_UPDATE", -- ActionButtonUseKeyDown etc.; click-cast macro LeftButton phase must stay in sync
    "PLAYER_SPECIALIZATION_CHANGED", -- Ally Cycle restore-after-harm follows healer spec until toggled
  },
  -- Selection circle: show/hide it with the hard target / focus
  SELECTION_CIRCLE_EVENTS = {
    "PLAYER_TARGET_CHANGED",
    "PLAYER_FOCUS_CHANGED",
  },
  -- Events for focus lock detection
  FOCUS_LOCK_EVENTS = {
    "PLAYER_FOCUS_CHANGED", -- Focus changed (lock-in animation)
  },
  -- Nameplate add/remove for Target Lock nameplate marker (arrive / clear when plate exists)
  FOCUS_NAMEPLATE_EVENTS = {
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
  },
  -- Player cast/channel feedback for crosshair grow / explode / break
  CAST_FEEDBACK_EVENTS = {
    "UNIT_SPELLCAST_START",
    "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_SUCCEEDED",
    "UNIT_SPELLCAST_CHANNEL_START",
    "UNIT_SPELLCAST_CHANNEL_STOP",
  },
  -- Assisted Combat highlight cast hooks (suggestion refresh)
  ASSISTED_HIGHLIGHT_EVENTS = {
    "ASSISTED_COMBAT_ACTION_SPELL_CAST",
  },
  -- Ally Cycle skips offline / other-zone members: recheck when connection or zone changes
  ALLY_AVAILABILITY_EVENTS = {
    "UNIT_CONNECTION",
    "ZONE_CHANGED_NEW_AREA",
    "PLAYER_ENTERING_WORLD",
  },
  -- Soft-interact target changed: refresh the interaction mode of the crosshair HUD
  INTERACT_HUD_EVENTS = {
    "PLAYER_SOFT_INTERACT_CHANGED",
  },
  -- Radial Menu: repaint cooldowns / counts while open; re-store slices when known spells change
  RADIAL_MENU_EVENTS = {
    "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN",
    "BAG_UPDATE_DELAYED",
    "SPELL_UPDATE_USABLE", -- Slice usability (resources, form)
    "PLAYER_REGEN_DISABLED", -- Combat-blocked actions grey out
    "PLAYER_REGEN_ENABLED",
    "SPELLS_CHANGED",
    "GROUP_ROSTER_UPDATE", -- Party Wheel pages follow the group
    "UNIT_CONNECTION", -- Party Wheel: offline members can't be picked
  },
}

-- Action-bar bindings for click-cast dropdown + reticle /click injection.
-- actionBase = Blizzard action slot for button 1 (Retail MultiBar5–7 = 145/157/169).
CM.Constants.ClickCastBars = {
  { bind = "ACTIONBUTTON", frame = "ActionButton", count = 12, actionBase = 1 },
  {
    bind = "MULTIACTIONBAR1BUTTON",
    frame = "MultiBarBottomLeftButton",
    count = 12,
    actionBase = 61,
  },
  {
    bind = "MULTIACTIONBAR2BUTTON",
    frame = "MultiBarBottomRightButton",
    count = 12,
    actionBase = 49,
  },
  { bind = "MULTIACTIONBAR3BUTTON", frame = "MultiBarRightButton", count = 12, actionBase = 25 },
  { bind = "MULTIACTIONBAR4BUTTON", frame = "MultiBarLeftButton", count = 12, actionBase = 37 },
  { bind = "MULTIACTIONBAR5BUTTON", frame = "MultiBar5Button", count = 12, actionBase = 145 },
  { bind = "MULTIACTIONBAR6BUTTON", frame = "MultiBar6Button", count = 12, actionBase = 157 },
  { bind = "MULTIACTIONBAR7BUTTON", frame = "MultiBar7Button", count = 12, actionBase = 169 },
}

-- Skyriding abilities: always skip reticle targeting preline (not editable in Excluded Spells).
CM.Constants.ReticleTargetingBuiltinExcludeSpellIds = {
  [372608] = true, -- Surge Forward
  [372610] = true, -- Skyward Ascent
  [361584] = true, -- Whirling Surge
  [425782] = true, -- Second Wind
  [403092] = true, -- Aerial Halt
}

-- Non-bar bindable actions shown in the Click Casting action dropdown.
-- Includes high-value Retail IDs (pings, arena target/focus, vehicles, party pets,
-- sit/sheath/run, pitch) that older BindingID wiki lists omitted.
local ACTIONS_TO_PROCESS_EXTRA = {
  "FOCUSTARGET",
  "FOLLOWTARGET",
  "INTERACTTARGET",
  "INTERACTMOUSEOVER",
  "JUMP",
  "MOVEANDSTEER",
  "MOVEBACKWARD",
  "MOVEFORWARD",
  "PITCHUP",
  "PITCHDOWN",
  "SITORSTAND",
  "TOGGLESHEATH",
  "TOGGLERUN",
  "STARTAUTORUN",
  "STOPAUTORUN",
  "TARGETFOCUS",
  "TARGETLASTHOSTILE",
  "TARGETLASTTARGET",
  "TARGETNEARESTENEMY",
  "TARGETNEARESTENEMYPLAYER",
  "TARGETNEARESTFRIEND",
  "TARGETNEARESTFRIENDPLAYER",
  "TARGETPET",
  "TARGETPREVIOUSENEMY",
  "TARGETPREVIOUSENEMYPLAYER",
  "TARGETPREVIOUSFRIEND",
  "TARGETPREVIOUSFRIENDPLAYER",
  "TARGETSCANENEMY",
  "TARGETSELF",
  "TARGETMOUSEOVER",
  "ASSISTTARGET",
  "ATTACKTARGET",
  "STOPATTACK",
  "STOPCASTING",
  "EXTRAACTIONBUTTON1",
  "ACTIONPAGE1",
  "ACTIONPAGE2",
  "ACTIONPAGE3",
  "ACTIONPAGE4",
  "ACTIONPAGE5",
  "ACTIONPAGE6",
  "BONUSACTIONBUTTON1",
  "BONUSACTIONBUTTON10",
  "BONUSACTIONBUTTON2",
  "BONUSACTIONBUTTON3",
  "BONUSACTIONBUTTON4",
  "BONUSACTIONBUTTON5",
  "BONUSACTIONBUTTON6",
  "BONUSACTIONBUTTON7",
  "BONUSACTIONBUTTON8",
  "BONUSACTIONBUTTON9",
  "CAMERAZOOMIN",
  "CAMERAZOOMOUT",
  "DISMOUNT",
  "NEXTACTIONPAGE",
  "PREVIOUSACTIONPAGE",
  "RAIDTARGET1",
  "RAIDTARGET2",
  "RAIDTARGET3",
  "RAIDTARGET4",
  "RAIDTARGET5",
  "RAIDTARGET6",
  "RAIDTARGET7",
  "RAIDTARGET8",
  "RAIDTARGETNONE",
  "SCREENSHOT",
  "SHAPESHIFTBUTTON1",
  "SHAPESHIFTBUTTON10",
  "SHAPESHIFTBUTTON2",
  "SHAPESHIFTBUTTON3",
  "SHAPESHIFTBUTTON4",
  "SHAPESHIFTBUTTON5",
  "SHAPESHIFTBUTTON6",
  "SHAPESHIFTBUTTON7",
  "SHAPESHIFTBUTTON8",
  "SHAPESHIFTBUTTON9",
  "STRAFELEFT",
  "STRAFERIGHT",
  "TARGETPARTYMEMBER1",
  "TARGETPARTYMEMBER2",
  "TARGETPARTYMEMBER3",
  "TARGETPARTYMEMBER4",
  "TARGETPARTYPET1",
  "TARGETPARTYPET2",
  "TARGETPARTYPET3",
  "TARGETPARTYPET4",
  "TARGETARENA1",
  "TARGETARENA2",
  "TARGETARENA3",
  "TARGETARENA4",
  "TARGETARENA5",
  "FOCUSARENA1",
  "FOCUSARENA2",
  "FOCUSARENA3",
  "FOCUSARENA4",
  "FOCUSARENA5",
  "TOGGLEAUTORUN",
  "TURNLEFT",
  "TURNRIGHT",
  "VEHICLEEXIT",
  "VEHICLENEXTSEAT",
  "VEHICLEPREVSEAT",
  "TOGGLEPINGLISTENER",
  "PINGATTACK",
  "PINGWARNING",
  "PINGONMYWAY",
  "PINGASSIST",
}

CM.Constants.ActionsToProcess = {}
for _, bar in ipairs(CM.Constants.ClickCastBars) do
  for i = 1, bar.count do
    CM.Constants.ActionsToProcess[#CM.Constants.ActionsToProcess + 1] = bar.bind .. i
  end
end
for _, id in ipairs(ACTIONS_TO_PROCESS_EXTRA) do
  CM.Constants.ActionsToProcess[#CM.Constants.ActionsToProcess + 1] = id
end

CM.Constants.OverrideActions = {
  CLEARTARGET = "|cff69ccf0Clear Target|r",
  CLEARFOCUS = "|cff69ccf0Clear Focus|r",
  STARTATTACK = "|cff69ccf0Start Attack|r",
  PETATTACK = "|cff69ccf0Pet Attack|r",
  TOGGLEFOCUSANY = "|cff69ccf0Toggle Focus Any|r",
  TOGGLEFOCUSENEMY = "|cff69ccf0Toggle Focus Enemy|r",
  MACRO = "|cff69ccf0Run MACRO|r",
}

CM.Constants.ButtonsToOverride = {
  "button1",
  "button2",
  "shiftbutton1",
  "shiftbutton2",
  "ctrlbutton1",
  "ctrlbutton2",
  "altbutton1",
  "altbutton2",
}
