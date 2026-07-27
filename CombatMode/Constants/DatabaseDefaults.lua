---------------------------------------------------------------------------------------
--  Constants/DatabaseDefaults.lua — CONSTANTS — CombatModeDB defaults (global + char)
---------------------------------------------------------------------------------------
--  Owns CM.Constants.DatabaseDefaults merged by Core/Runtime/Runtime.lua (InitDatabase).
--  Includes global targetingMacroPrelineAnyOverride / targetingMacroPrelineEnemyOverride
--  (nil = built-in prelines; edited via UI/Editors/TargetingMacroPrelinesEditor.lua),
--  reticleTargetingCVarOverrides (Reticle CVar editor; merged in Core/Runtime/CVarManager.lua),
--  and priorCVarSnapshot (refreshed at each enable before CM overwrites; restored by
--  Uninstall; preserved across Reset to Defaults).
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
    mountCheck = false,
    customCondition = "",
    crosshair = true,
    crosshairMounted = false,
    hideTooltip = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairSize = 64,
    crosshairOpacity = 1.0,
    interactionHUD = true,
    assistedHighlightEnabled = true,
    assistedHighlightSize = 32,
    assistedHighlightOffsetX = 80,
    assistedHighlightOffsetY = 40,
    assistedHighlightShowKeybind = true,
    assistedHighlightKeybindAnchor = "RIGHT",
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
      sliceRadius = 120,
      sliceSize = 1.0,
      showHealthBars = false,
      showBackground = true,
      roleIconSize = 64,
      nameFontSize = 13,
      healthyColor = { 0, 0.8, 0, 1 },
      damagedColor = { 1, 1, 0, 1 },
      criticalColor = { 1, 0, 0, 1 },
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
    castAtCursorSpells = "Heroic Leap, Shift, Sigil of Flame, 189110, 190356",
    excludeFromTargetingSpells = "Shield Wall, Ice Block, Divine Shield, 198589",
    stickyCrosshair = false,
    bindings = DefaultBindings,
  },
}
