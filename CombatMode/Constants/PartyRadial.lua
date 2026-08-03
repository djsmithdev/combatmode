---------------------------------------------------------------------------------------
--  Constants/PartyRadial.lua — CONSTANTS — party radial slice metadata + layout
---------------------------------------------------------------------------------------
--  What it does: Defines the five-slice layout for party radial (default roles, angles,
--  labels), per-slice arc width, fixed layout/fade/health-bar sizes, and static role-icon
--  atlas / ranged-spec lookup tables used by the runtime wheel.
--  Architecture / how it works:
--    • PartyRadialSlices[1..5] — angle degrees (0 = right, 90 = up), defaultRole, label.
--    • PartyRadialSliceArc = 72 (360/5).
--    • PartyRadialLayout — fixed slice radius/sizes + fade durations (not DB options).
--    • PartyRadialHealthBar — bar size, low-health threshold, glow/controlled pulse.
--    • PartyRadialRoleAtlases — LFG role icon atlases (normal/disabled; DPS melee+ranged).
--    • PartyRadialRangedSpecIDs / PartyRadialRangedDamagerClasses — melee vs ranged DPS
--      heuristics when UnitGroupRolesAssigned is DAMAGER (no Mainline melee/ranged API).
--  Does not: Own CM.PartyRadial UI, secure attributes, or DB.global.partyRadial settings.
--  Related: Core/PartyRadial/*.lua, UI/Options/Tabs/TabPartyRadial.lua,
--  Constants/DatabaseDefaults.lua
---------------------------------------------------------------------------------------
local _, CM = ...

-- Slice positions for 5-man content (angles in degrees, 0 = right, 90 = up)
-- Each slice covers 72 degrees (360/5)
CM.Constants.PartyRadialSlices = {
  [1] = { defaultRole = "TANK", angle = 90, label = "12 o'clock (top)" },
  [2] = { defaultRole = "DAMAGER", angle = 162, label = "10 o'clock (upper-left)" },
  [3] = { defaultRole = "HEALER", angle = 234, label = "7 o'clock (lower-left)" },
  [4] = { defaultRole = "DAMAGER", angle = 306, label = "5 o'clock (lower-right)" },
  [5] = { defaultRole = "DAMAGER", angle = 18, label = "2 o'clock (upper-right)" },
}

CM.Constants.PartyRadialSliceArc = 72 -- degrees per slice

-- Fixed layout (not user-configurable; options only toggle enabled/bars/background).
CM.Constants.PartyRadialLayout = {
  baseSliceSize = 80,
  centerFixedSize = 64,
  sliceRadius = 120,
  sliceScale = 1.0,
  roleIconSize = 64,
  nameFontSize = 13,
  fadeInDuration = 0.18,
  fadeOutDuration = 0.22,
  sliceScaleDuration = 0.1,
}

-- Health bar chrome + shared pulse tuning (widgetstatusbar kit, native fill height 15).
CM.Constants.PartyRadialHealthBar = {
  width = 72,
  height = 10,
  lowPct = 0.25,
  glowR = 1,
  glowG = 0.12,
  glowB = 0.08,
  glowPulsePeriod = 1.15,
  glowPulseMin = 0.35,
  glowPulseMax = 1.0,
  controlledOverlayPulsePeriod = 0.55,
  fillWhiteAtlas = "widgetstatusbar-fill-white",
}

-- LFG role icon atlases (interface/lfgframe/uilfgprompts). Controlled overlay uses
-- DeclineMark (X, no backdrop) faded over the normal role icon. DPS uses melee by
-- default; ranged when known.
CM.Constants.PartyRadialRoleAtlases = {
  TANK = {
    normal = "UI-LFG-RoleIcon-Tank",
    disabled = "UI-LFG-RoleIcon-Tank-Disabled",
  },
  HEALER = {
    normal = "UI-LFG-RoleIcon-Healer",
    disabled = "UI-LFG-RoleIcon-Healer-Disabled",
  },
  DAMAGER = {
    normal = "UI-LFG-RoleIcon-DPS",
    disabled = "UI-LFG-RoleIcon-DPS-Disabled",
    ranged = "UI-LFG-RoleIcon-RangedDPS",
    rangedDisabled = "UI-LFG-RoleIcon-RangedDPS-Disabled",
  },
  controlled = "UI-LFG-DeclineMark",
}

-- Spec IDs that are ranged DPS (no durable Mainline melee/ranged API).
CM.Constants.PartyRadialRangedSpecIDs = {
  [62] = true, -- Mage Arcane
  [63] = true, -- Mage Fire
  [64] = true, -- Mage Frost
  [102] = true, -- Druid Balance
  [253] = true, -- Hunter Beast Mastery
  [254] = true, -- Hunter Marksmanship
  [258] = true, -- Priest Shadow
  [262] = true, -- Shaman Elemental
  [265] = true, -- Warlock Affliction
  [266] = true, -- Warlock Demonology
  [267] = true, -- Warlock Destruction
  [1467] = true, -- Evoker Devastation
  [1473] = true, -- Evoker Augmentation
}

-- When DAMAGER and spec is unknown: these class files are always ranged DPS.
CM.Constants.PartyRadialRangedDamagerClasses = {
  MAGE = true,
  WARLOCK = true,
  EVOKER = true,
  PRIEST = true, -- DPS priest is Shadow
}
