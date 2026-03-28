---------------------------------------------------------------------------------------
--  Config/ConfigReticleTargeting.lua — Reticle targeting (CVars, spells, editors)
---------------------------------------------------------------------------------------
--  Opens Reticle CVar editor (CM.OpenReticleTargetingCVarEditor) and preline editor
--  (CM.OpenTargetingMacroPrelinesEditor) from execute buttons.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Header, Description = U.Spacing, U.Header, U.Description

-- WoW API
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local strtrim = _G.strtrim

CM.Config.ReticleTargetingOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("reticle", 1),
    description = Description("reticle", 2),
    reticleTargeting = {
      type = "toggle",
      name = "Enable |cff00FFFFReticle Targeting|r |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nConfigures Blizzard's |cffffd700Action Targeting|r feature to be more precise and responsive. \n\nWraps actions with |cffB47EDEtargeting macro conditionals|r that select the unit under the crosshair when using an ability. \n\n|cffFF5050Be aware that this will override all CVar values related to SoftTarget.|r \n\n|cff909090Uncheck to reset them to their default values.|r\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.75,
      order = 3,
      confirmText = CM.METADATA["TITLE"]
        .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      confirm = true,
      set = function(_, value)
        CM.DB.char.reticleTargeting = value
        if value then
          CM.ConfigReticleTargeting("combatmode")
        else
          CM.ConfigReticleTargeting("blizzard")
        end
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.reticleTargeting
      end,
    },
    spacing0 = Spacing(0.25, 3.1),
    reticleTargetingEnemyOnly = {
      type = "toggle",
      name = "Only Allow Reticle To Target Enemies |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nOnly allow |cff00FFFFReticle Targeting|r to select hostile units, ignoring friendly NPCs and Players.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.75,
      order = 4,
      confirm = true,
      confirmText = CM.METADATA["TITLE"]
        .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.reticleTargetingEnemyOnly = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.reticleTargetingEnemyOnly
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    },
    macroInjectionClickCastOnly = {
      type = "toggle",
      name = "Limit |cff00FFFFReticle Targeting|r To |cffB47EDEClick Casting|r Actions |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nWhen enabled, the reticle unit targeting and ground-targeted macro injection apply only to |cffB47EDEClick Casting|r bindings. All other action bar slots will not have the targeting macro injection applied.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
      order = 5,
      confirm = true,
      confirmText = CM.METADATA["TITLE"]
        .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.macroInjectionClickCastOnly = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.macroInjectionClickCastOnly
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting or CM.ThirdPartyActionBarsActive == true
      end,
    },
    spacing1 = Spacing(0.25, 5.1),
    focusCurrentTargetNotCrosshair = {
      type = "toggle",
      name = "|cffcc00ffTarget Lock|r Selected Target |cffE52B50Not|r The Crosshair |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nWhen enabled, |cffcc00ffTarget Lock|r will lock onto your currently selected target rather than the unit under your crosshair.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
      order = 5.2,
      confirm = true,
      confirmText = CM.METADATA["TITLE"]
        .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.focusCurrentTargetNotCrosshair = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.focusCurrentTargetNotCrosshair
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    },
    stickyCrosshair = {
      type = "toggle",
      name = "Sticky Targeting |cff3B73FF©|r |cffE37527•|r",
      desc = "|cff3B73FF© Character-based option|r\n\nMakes |cff00FFFFReticle Targeting|r stick to enemies slightly, making it harder to untarget them by accident.\n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
      order = 5.4,
      set = function(_, value)
        CM.DB.char.stickyCrosshair = value
        if value then
          CM.ConfigStickyCrosshair("combatmode")
        else
          CM.ConfigStickyCrosshair("blizzard")
        end
      end,
      get = function()
        return CM.DB.char.stickyCrosshair
      end,
      disabled = function()
        return CM.DynamicCam or not CM.IsCrosshairEnabled()
      end,
    },
    spacing13 = Spacing("full", 5.5),
    excludeFromTargetingSpells = {
      name = "Spells to |cffE52B50exclude|r from |cff00FFFFReticle Targeting|r:",
      desc = "Spells that you |cffE52B50DON'T|r want the |cffB47EDEtargeting macro conditionals|r applied to, thus not being able to select the crosshair unit.\n\n|cff909090Ex: Shield Wall, Ice Block, Divine Shield.|r\n\n|cffffd700Separate names with commas.|r\n|cffffd700Names are case insensitive.|r",
      type = "input",
      multiline = 6,
      width = "full",
      order = 6,
      set = function(_, value)
        CM.DB.char.excludeFromTargetingSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      get = function()
        return CM.DB.char.excludeFromTargetingSpells or ""
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    },
    spacing2 = Spacing("full", 6.1),
    castAtCursorSpells = {
      name = "|cff00ff00Ground-targeted|r spells to be cast at the |cff00FFFFReticle|r:",
      desc = "|cff00ff00Ground-targeted|r abilities that you want cast with the |cffB47EDE@cursor|r modifier directly at the position of the crosshair without requiring the |cff00ff00green circle|r to be placed.\n\n|cff909090Ex: Heroic Leap, Shift, Blizzard.|r\n\n|cffffd700Separate names with commas.|r \n|cffffd700Names are case insensitive.|r",
      type = "input",
      multiline = 6,
      width = "full",
      order = 7,
      set = function(_, value)
        CM.DB.char.castAtCursorSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      get = function()
        return CM.DB.char.castAtCursorSpells or ""
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    },
    spacing11 = Spacing("full", 8),
    header2 = Header("custom", 9),
    spacing14 = Spacing("full", 9.1),
    editReticleTargetingCVars = {
      type = "execute",
      name = "Edit Reticle Targeting CVars",
      desc = "Open the Reticle Targeting CVar editor.",
      width = 1.75,
      order = 10,
      func = function()
        CM.OpenReticleTargetingCVarEditor()
      end,
    },
    spacing12 = Spacing(0.25, 11),
    editTargetingMacroPrelines = {
      type = "execute",
      name = "Edit Targeting Macro Prelines",
      desc = "Open the Targeting Macro Prelines editor.",
      width = 1.75,
      order = 12,
      func = function()
        CM.OpenTargetingMacroPrelinesEditor()
      end,
    },
  },
}
