---------------------------------------------------------------------------------------
--  Constants/DatabaseDefaults.lua — CONSTANTS — CombatModeDB defaults
---------------------------------------------------------------------------------------
--  What it does: Defines `CM.Constants.DatabaseDefaults` (global + char) merged by
--  `CM.InitDatabase` into AceDB-shaped CombatModeDB. This is the single source of truth
--  for new-install defaults across free-look, crosshair companions, click-cast, reticle,
--  and party radial.
--  Architecture / how it works:
--    • global: free-look / crosshair / Interaction HUD / Assisted Combat / reticle /
--      click-cast bindings / auto-unlock / Action Camera (actionCamera,
--      actionCamMouselookDisable, actionCameraProfiles, actionCameraMaxZoom,
--      actionCameraDynamicPitch) / vignette / partyRadial / debug.
--    • char: reticle targeting, click-cast bindings, useGlobalBindings.
--    • Per-situation Action Camera values live in Constants/ActionCamera.lua
--      (ActionCameraProfileDefaults); SituationDriver seeds actionCameraProfiles on first load.
--    • DefaultBindings seeds button1/2 + shift/ctrl/alt mouse slots and Mouse Look toggle.
--  Does not: Migrate saved data or apply CVars/bindings at runtime.
--  Related: Core/Runtime/Runtime.lua, Core/Runtime/CVarManager.lua,
--  Core/ActionCamera/SituationDriver.lua, Constants/ActionCamera.lua,
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
    showTargetLockMarker = true,
    autofocusLockedTarget = true, -- Action Camera Target Focus Enemy while focus exists
    -- crosshair
    crosshair = true,
    crosshairCastFeedback = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairScale = 1.0,
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
local isPlayerStealthed = IsStealthed and IsStealthed()
if isPlayerDead or isPlayerStealthed then
  return true end
return false
]],
    -- click casting
    bindings = DefaultBindings,
    -- auto unlock
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
    -- Per-situation profiles seeded by SituationDriver from ActionCameraProfileDefaults.
    actionCameraProfiles = nil,
    actionCameraMaxZoom = 20,
    actionCameraDynamicPitch = true,
    -- vignette
    vignette = true,
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
  },
}
