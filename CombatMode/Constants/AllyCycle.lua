---------------------------------------------------------------------------------------
--  Constants/AllyCycle.lua — CONSTANTS — Ally Cycle HUD layout + role atlases
---------------------------------------------------------------------------------------
--  What it does: Static layout sizes, widgetstatusbar health-bar chrome tuning, role
--  atlases, shadow pads, and out-of-range alpha for the Ally Cycle HUD.
--  Architecture / how it works:
--    • AllyCycleLayout — role/name/bar/marker/index sizes, shadow pads, cycle slide.
--    • AllyCycleHealthBar — widgetstatusbar kit; low-HP glow (red) + aggro glow (yellow).
--    • AllyCycleRoleAtlases — UI-Frame Tank / Healer / Dps icons (FrameGeneral).
--  Does not: Own cycle roster, secure buttons, or DB.global.allyCycle settings.
--  Related: Core/AllyCycle/{Cycle,HUD,AllyCycle}.lua, UI/Options/Tabs/TabAllyCycle.lua,
--  Constants/DatabaseDefaults.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...

CM.Constants.AllyCycleLayout = {
  -- Name + bar stay centered; role icon left of bar, cycle index right;
  -- raid marker sits just above the name.
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
  -- Slightly smaller than the role icon; sits above the name.
  raidMarkerSize = 16,
  -- Gap between marker bottom and name top (WoW Y is up-positive).
  raidMarkerLift = 4,
  -- Horizontal gap from bar right edge to cycle index (role icon still uses `gap`).
  indexGap = 2,
  indexFontSize = 10,
  -- Enough for "40/40" so the bar stays centered as the digits change.
  indexMinWidth = 28,
  -- Cycle advance: short slide in from below (up) / above (down), ease-out.
  cycleSlidePx = 3,
  cycleAnimSec = 0.14,
  cycleAnimFromAlpha = 0.75,
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
