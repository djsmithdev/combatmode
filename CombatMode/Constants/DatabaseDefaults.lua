---------------------------------------------------------------------------------------
--  Constants/DatabaseDefaults.lua — CONSTANTS — CombatModeDB defaults
---------------------------------------------------------------------------------------
--  What it does: Defines `CM.Constants.DatabaseDefaults` (global + char) merged by
--  `CM.InitDatabase` into AceDB-shaped CombatModeDB. This is the single source of truth
--  for new-install defaults across free-look, crosshair companions, click-cast, reticle,
--  and party radial.
--  Architecture / how it works:
--      mouseLookSpeed, pulseCursor, interactUnit, cycleFocusWithMouseWheel; crosshair*
--      (crosshairScale, opacity, Y, cast feedback), interactionHUD / Side / Scale,
--      assistedHighlightEnabled / Side / Scale; vignette; partyRadial (enabled,
--      showHealthBars, showBackground, scale; layout/fade fixed in Constants/PartyRadial.lua);
--      reticleTargetingCVarOverrides, priorCVarSnapshot, targetingMacroPreline*Override
--      (any/enemy + autoLockAny/autoLockEnemy); crosshairReactionColors (optional
--      per-state RGBA overrides — empty table = defaults from Assets);
--      crosshairSituationalCondition (user Lua → X texture override when true);
--      bindings.
--    • char: useGlobalBindings, shoulderOffset, reticleTargeting / enemyOnly /
--      autoTargetLockOnAttack, macroInjectionClickCastOnly, castAtCursorSpells,
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
    value = "TOGGLEFOCUSENEMY",
    macroName = "",
  },
  altbutton2 = {
    enabled = true,
    key = "ALT-BUTTON2",
    value = "TOGGLEFOCUSANY",
    macroName = "",
  },
  toggle = { key = "Combat Mode - Mouse Look", value = "BUTTON3" },
}

CM.Constants.DatabaseDefaults = {
  global = {
    -- general
    pulseCursor = true,
    hideTooltip = true,
    sheathWeaponsWithMouselook = false,
    interactUnit = "mouseover",
    cycleFocusWithMouseWheel = true,
    showTargetLockMarker = true,
    -- crosshair
    crosshair = true,
    crosshairCastFeedback = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairScale = 1.0,
    crosshairOpacity = 1.0,
    crosshairY = 100,
    -- interaction HUD
    interactionHUD = true,
    interactionHUDSide = "LEFT",
    interactionHUDScale = 1.0,
    -- combat assist
    assistedHighlightEnabled = true,
    assistedHighlightSide = "RIGHT",
    assistedHighlightScale = 1.0,
    -- reticle targeting
    reticleTargetingCVarOverrides = {},
    priorCVarSnapshot = nil,
    targetingMacroPrelineAnyOverride = nil,
    targetingMacroPrelineEnemyOverride = nil,
    targetingMacroPrelineAutoLockAnyOverride = nil,
    targetingMacroPrelineAutoLockEnemyOverride = nil,
    crosshairReactionColors = {},
    crosshairSituationalCondition = [[
local isPlayerDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
if isPlayerDead or isStealthed() then
  return true end
return false
]],
    -- click casting
    bindings = DefaultBindings,
    -- auto  unlock
    frameWatching = true,
    mountsToUnlock = "61447, 122708, 264058, 465235, 457485, 61425",
    watchlist = {
      "PawnUIFrame",
      "SortedPrimaryFrame",
      "WeakAurasOptions",
      "DUIQuestFrame",
      "Narci_Vignette",
      "EnhanceQoLConfigCenterFrame",
      "LWDialogFrame",
      "TAV_CoreFrame",
      "EQOLQuickCastVisual",
      "WeakTextures_MainFrame",
    },
    customCondition = "",
    -- action camera
    actionCamera = true,
    actionCamMouselookDisable = true,
    mouseLookSpeed = 100,
    actionCameraFov = 90,
    actionCameraMaxZoom = 15, -- cameraDistanceMaxZoomFactor: 1.0 multiplier = 15 yards base. UI stores yards (15–39).
    actionCameraZoomSpeed = 20,
    actionCameraHeadTracking = 1,
    vignette = true,
    vignetteFadeWithMouselook = true,
    -- radial
    partyRadial = {
      enabled = true,
      showHealthBars = true,
      showBackground = true,
      scale = 1.0,
    },
    -- dev
    silenceAlerts = true,
    debugMode = false,
  },
  char = {
    -- reticle targeting
    reticleTargeting = true,
    reticleTargetingEnemyOnly = true,
    autoTargetLockOnAttack = false,
    macroInjectionClickCastOnly = false,
    excludeFromTargetingSpells = "871, 45438, 642, 198589",
    castAtCursorSpells = "6544, 204596, 189110, 1234796, 190356, 207684",
    -- click casting
    useGlobalBindings = false,
    bindings = DefaultBindings,
    -- action camera
    stickyCrosshair = false,
    shoulderOffset = 1.2,
  },
}
