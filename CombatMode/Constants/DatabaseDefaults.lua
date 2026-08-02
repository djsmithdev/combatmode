---------------------------------------------------------------------------------------
--  Constants/DatabaseDefaults.lua — CONSTANTS — CombatModeDB defaults
---------------------------------------------------------------------------------------
--  What it does: Defines `CM.Constants.DatabaseDefaults` (global + char) merged by
--  `CM.InitDatabase` into AceDB-shaped CombatModeDB. This is the single source of truth
--  for new-install defaults across free-look, crosshair companions, click-cast, reticle,
--  and party radial.
--  Architecture / how it works:
--      mouseLookSpeed, pulseCursor, interactUnit, cycleFocusWithMouseWheel; crosshair*,
--      crosshairCastFeedback, interactionHUD / interactionHUDSide (default LEFT),
--      assistedHighlightEnabled / assistedHighlightSide (default RIGHT), crosshairY;
--      reticleTargetingCVarOverrides, priorCVarSnapshot, targetingMacroPreline*Override;
--      bindings; partyRadial (enabled, showHealthBars, showBackground; layout/scale fixed in Core).
--    • char: useGlobalBindings, shoulderOffset, reticleTargeting / enemyOnly /
--      macroInjectionClickCastOnly, focusCurrentTargetNotCrosshair, castAtCursorSpells,
--      excludeFromTargetingSpells, stickyCrosshair, bindings.
--    • DefaultBindings seeds button1/2 + shift/ctrl/alt mouse slots and Mouse Look toggle.
--  Does not: Migrate saved data or apply CVars/bindings at runtime.
--  Related: Core/Runtime/Runtime.lua, Core/Runtime/CVarManager.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, UI/Options/Tabs/TabCrosshair.lua,
--  UI/Editors/TargetingMacroPrelinesEditor.lua, Core/PartyRadial/PartyRadial.lua,
--  UI/Options/Tabs/TabClickCasting.lua
---------------------------------------------------------------------------------------
local _, CM = ...

local DefaultBindings = {
  button1 = {
    enabled = true,
    key = "BUTTON1",
    value = "ACTIONBUTTON1",
    macroName = "",
  },
  button2 = {
    enabled = true,
    key = "BUTTON2",
    value = "ACTIONBUTTON2",
    macroName = "",
  },
  shiftbutton1 = {
    enabled = true,
    key = "SHIFT-BUTTON1",
    value = "ACTIONBUTTON3",
    macroName = "",
  },
  shiftbutton2 = {
    enabled = true,
    key = "SHIFT-BUTTON2",
    value = "ACTIONBUTTON4",
    macroName = "",
  },
  ctrlbutton1 = {
    enabled = true,
    key = "CTRL-BUTTON1",
    value = "ACTIONBUTTON5",
    macroName = "",
  },
  ctrlbutton2 = {
    enabled = true,
    key = "CTRL-BUTTON2",
    value = "ACTIONBUTTON6",
    macroName = "",
  },
  altbutton1 = {
    enabled = true,
    key = "ALT-BUTTON1",
    value = "FOCUSTARGET",
    macroName = "",
  },
  altbutton2 = {
    enabled = true,
    key = "ALT-BUTTON2",
    value = "CLEARFOCUS",
    macroName = "",
  },
  toggle = { key = "Combat Mode - Mouse Look", value = "BUTTON3" },
}

CM.Constants.DatabaseDefaults = {
  global = {
    frameWatching = true,
    watchlist = {
      "PawnUIFrame",
      "SortedPrimaryFrame",
      "WeakAurasOptions",
      "DUIQuestFrame",
      "Narci_Vignette",
    },
    actionCamera = false,
    actionCamMouselookDisable = false,
    mouseLookSpeed = 120,
    pulseCursor = true,
    -- Unsheath in Mouse Look; sheath on tap-off and Auto Cursor Unlock (not hold/radial/OPie/ground).
    sheathWeaponsWithMouselook = true,
    -- While Mouse Look + Target Lock (focus): wheel cycles nearest/previous enemy and re-focuses.
    cycleFocusWithMouseWheel = true,
    -- Subtle SFX when Target Lock (focus) is acquired or cleared.
    targetLockSounds = true,
    -- "mouseover" (INTERACTMOUSEOVER) or "target" (INTERACTTARGET); ALT+key binds the other.
    interactUnit = "mouseover",
    mountCheck = false,
    customCondition = "",
    crosshair = true,
    crosshairMounted = false,
    hideTooltip = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairSize = 64,
    crosshairOpacity = 1.0,
    crosshairCastFeedback = true,
    interactionHUD = true,
    interactionHUDSide = "LEFT",
    assistedHighlightEnabled = true,
    assistedHighlightSide = "RIGHT",
    crosshairY = 100,
    silenceAlerts = false,
    debugMode = false,
    reticleTargetingCVarOverrides = {},
    -- Populated at each enable before the first CM CVar write.
    priorCVarSnapshot = nil,
    targetingMacroPrelineAnyOverride = nil,
    targetingMacroPrelineEnemyOverride = nil,
    bindings = DefaultBindings,
    partyRadial = {
      enabled = false,
      showHealthBars = false,
      showBackground = true,
      fadeInDuration = 0.08,
      fadeOutDuration = 0.05,
    },
  },
  char = {
    useGlobalBindings = false,
    shoulderOffset = 1.0,
    reticleTargeting = true,
    reticleTargetingEnemyOnly = true,
    macroInjectionClickCastOnly = false,
    focusCurrentTargetNotCrosshair = false,
    castAtCursorSpells = "6544, 204596, 189110, 1234796, 190356", -- Heroic Leap, Sigil of Flame, Infernal Strike, Shift, Blizzard
    excludeFromTargetingSpells = "871, 45438, 642, 198589", -- Shield Wall, Ice Block, Divine Shield, Blur
    stickyCrosshair = false,
    bindings = DefaultBindings,
  },
}
