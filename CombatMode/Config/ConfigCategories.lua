---------------------------------------------------------------------------------------
--  Config/ConfigCategories.lua — option category assembly for AceConfig / Blizzard options
---------------------------------------------------------------------------------------
--  Shared UI builders live in Config/ConfigShared.lua. Each submenu is defined in
--  Config/Config*.lua (About, MouseLook, ReticleTargeting, ClickCasting, HealingRadial,
--  Advanced). This file only wires CM.Config.OptionCategories for Core:OnInitialize
--  (AceConfig + AddToBlizOptions).
--
--  Load order (Embeds.xml): Config*.lua before this file; ConfigShared.lua first.
---------------------------------------------------------------------------------------
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

CM.Config.OptionCategories = {
  {
    id = "CombatMode_FreeLook",
    name = "|cffE52B50 • Mouse Look|r",
    table = CM.Config.MouseLookOptions
  },
  {
    id = "CombatMode_ReticleTargeting",
    name = "|cff00FFFF • Reticle Targeting|r",
    table = CM.Config.ReticleTargetingOptions
  },
  {
    id = "CombatMode_ClickCasting",
    name = "|cffB47EDC • Click Casting|r",
    table = CM.Config.ClickCastingOptions
  },
  {
    id = "CombatMode_HealingRadial",
    name = "|cff00FF7F • Healing Radial|r",
    table = CM.Config.HealingRadialOptions
  },
  {
    id = "CombatMode_Advanced",
    name = "|cffffffff • Advanced|r",
    table = CM.Config.AdvancedOptions
  }
}
