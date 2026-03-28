---------------------------------------------------------------------------------------
--  Constants/ConstantsDatabaseDefaults.lua — constants module: db defaults
---------------------------------------------------------------------------------------
--  Includes global targetingMacroPrelineAnyOverride / targetingMacroPrelineEnemyOverride
--  (nil = use built-in prelines; edited via Config/TargetingMacroPrelinesEditor.lua)
--  and reticleTargetingCVarOverrides (Reticle CVar editor; merged in RuntimeCVarManager).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

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
    crosshairY = 100,
    crosshairLayoutPositions = {},
    silenceAlerts = false,
    debugMode = false,
    reticleTargetingCVarOverrides = {},
    targetingMacroPrelineAnyOverride = nil,
    targetingMacroPrelineEnemyOverride = nil,
    bindings = DefaultBindings,
    healingRadial = {
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
    castAtCursorSpells = "Heroic Leap, Shift, Sigil of Flame, Infernal Strike, Blizzard",
    excludeFromTargetingSpells = "Shield Wall, Ice Block, Divine Shield, Blur",
    stickyCrosshair = false,
    bindings = DefaultBindings,
  },
}
