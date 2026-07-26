---------------------------------------------------------------------------------------
--  Constants/HealingRadial.lua — CONSTANTS — party radial slice metadata
---------------------------------------------------------------------------------------
--  Owns CM.Constants.HealingRadialSlices (default role + angle per 5-man slot). Consumed
--  by Core/HealingRadial/HealingRadial.lua and the Party Radial options tab.
---------------------------------------------------------------------------------------
local _, CM = ...

-- Slice positions for 5-man content (angles in degrees, 0 = right, 90 = up)
-- Each slice covers 72 degrees (360/5)
CM.Constants.HealingRadialSlices = {
  [1] = { defaultRole = "TANK", angle = 90, label = "12 o'clock (top)" },
  [2] = { defaultRole = "DAMAGER", angle = 162, label = "10 o'clock (upper-left)" },
  [3] = { defaultRole = "HEALER", angle = 234, label = "7 o'clock (lower-left)" },
  [4] = { defaultRole = "DAMAGER", angle = 306, label = "5 o'clock (lower-right)" },
  [5] = { defaultRole = "DAMAGER", angle = 18, label = "2 o'clock (upper-right)" },
}

CM.Constants.HealingRadialSliceArc = 72 -- degrees per slice
