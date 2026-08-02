---------------------------------------------------------------------------------------
--  Constants/PartyRadial.lua — CONSTANTS — party radial slice metadata
---------------------------------------------------------------------------------------
--  What it does: Defines the five-slice layout for party radial (default roles, angles,
--  labels), per-slice arc width, and static role-icon atlas / ranged-spec lookup tables
--  used by the runtime wheel.
--  Architecture / how it works:
--    • PartyRadialSlices[1..5] — angle degrees (0 = right, 90 = up), defaultRole, label.
--    • PartyRadialSliceArc = 72 (360/5).
--    • PartyRadialRoleAtlases — LFG role icon atlases (normal/disabled; DPS melee+ranged).
--    • PartyRadialRangedSpecIDs / PartyRadialRangedDamagerClasses — melee vs ranged DPS
--      heuristics when UnitGroupRolesAssigned is DAMAGER (no Mainline melee/ranged API).
--  Does not: Own CM.PartyRadial UI, secure attributes, or DB.global.partyRadial settings.
--  Related: Core/PartyRadial/PartyRadial.lua, UI/Options/Tabs/TabPartyRadial.lua,
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
