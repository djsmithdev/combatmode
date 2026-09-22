---------------------------------------------------------------------------------------
--  Constants/AllyCycle.lua — CONSTANTS — Ally Cycle HUD layout + role atlases
---------------------------------------------------------------------------------------
--  What it does: Static layout sizes, widgetstatusbar health-bar chrome tuning, role
--  atlases, shadow pads, and out-of-range alpha for the Ally Cycle HUD.
--  Architecture / how it works:
--    • AllyCycleLayout — role/name/bar/marker sizes, shadow pads.
--    • AllyCycleHealthBar — widgetstatusbar kit; low-HP glow (red) + aggro glow (yellow).
--    • AllyCycleRoleAtlases — UI-Frame Tank / Healer / Dps icons (FrameGeneral).
--  Does not: Own cycle roster, secure buttons, or DB.global.allyCycle settings.
--  Related: Core/AllyCycle/{Cycle,HUD,AllyCycle}.lua, UI/Options/Tabs/TabAllyCycle.lua,
--  Constants/DatabaseDefaults.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...

CM.Constants.AllyCycleLayout = {
  -- Name + bar stay centered; role icon left of bar, raid marker right.
  roleIconSize = 20,
  nameFontSize = 11,
  nameMaxWidth = 120,
  -- Extra lift above the bar row (name sits higher / more breathing room).
  nameLift = 6,
  gap = 2,
  companionOffset = CM.Constants.CrosshairCompanionOffsetX or 24,
  -- PetJournal-BattleSlot-Shadow (same atlas as Interaction HUD).
  shadowAtlas = "PetJournal-BattleSlot-Shadow",
  shadowAlpha = 0.7,
  shadowPadL = 56,
  shadowPadR = 56,
  shadowPadT = 36,
  shadowPadB = 28,
  -- Negative = down (WoW UI Y is up-positive).
  shadowShiftY = -10,
  -- Whole-cluster alpha when UnitInRange is false.
  outOfRangeAlpha = 0.3,
  -- Slightly smaller than the role icon; drawn above the health-bar chrome.
  raidMarkerSize = 16,
  -- Horizontal gap from bar right edge (role icon still uses `gap`).
  raidMarkerGap = 4,
}

CM.Constants.AllyCycleHealthBar = {
  width = 72,
  height = 10,
  lowPct = 0.25,
  -- Low-HP glow (red atlas tinted red).
  glowR = 1,
  glowG = 0.12,
  glowB = 0.08,
  -- Aggro glow (same atlas, yellow tint).
  aggroGlowR = 1,
  aggroGlowG = 0.85,
  aggroGlowB = 0.12,
  glowPulsePeriod = 1.15,
  glowPulseMin = 0.35,
  glowPulseMax = 1.0,
  fillWhiteAtlas = "widgetstatusbar-fill-white",
}

CM.Constants.AllyCycleRoleAtlases = {
  TANK = "UI-Frame-TankIcon",
  HEALER = "UI-Frame-HealerIcon",
  DAMAGER = "UI-Frame-DpsIcon",
  NONE = "UI-Frame-DpsIcon",
}
