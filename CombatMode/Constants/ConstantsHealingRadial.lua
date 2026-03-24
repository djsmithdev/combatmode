---------------------------------------------------------------------------------------
--  Constants/ConstantsHealingRadial.lua — constants module: healing radial
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

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
