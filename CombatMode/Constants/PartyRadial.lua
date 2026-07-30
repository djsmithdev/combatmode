---------------------------------------------------------------------------------------
--  Constants/PartyRadial.lua — CONSTANTS — party radial slice metadata
---------------------------------------------------------------------------------------
--  What it does: Defines the five-slice layout for party radial (default roles, angles,
--  labels) and the per-slice arc width used by the runtime wheel.
--  Architecture / how it works:
--    • PartyRadialSlices[1..5] — angle degrees (0 = right, 90 = up), defaultRole, label.
--    • PartyRadialSliceArc = 72 (360/5).
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
