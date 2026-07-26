---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabReticleTargeting.lua — OPTIONS TAB — Reticle Targeting
---------------------------------------------------------------------------------------
--  Registers the "Reticle Targeting" tab. Reproduces Config/ConfigReticleTargeting.lua:
--  the reticle toggles (confirm + ReloadUI), the exclude/@cursor spell lists, and the
--  execute buttons that open the custom Reticle CVar editor and the Targeting Macro
--  Prelines editor. Sticky targeting lives on the Action Camera tab; the Target Lock
--  "selected target not crosshair" toggle lives on the General tab. Feature APIs
--  unchanged (CM.ConfigReticleTargeting, RefreshClickCastMacros).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local strtrim = _G.strtrim

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making changes to Reticle Targeting.\nProceed?"

UI.Options.AddTab({
  id = "reticle",
  label = "Reticle Targeting",
  build = function(ctx)
    ctx:Header("RETICLE TARGETING")
    ctx:Description(
      "Enable Combat Mode to transform the default tab-targeting combat into an action-oriented experience, where the Crosshair dictates target acquisition."
    )

    ctx:Toggle({
      label = "Enable Reticle Targeting",
      desc = "Configures Blizzard's Action Targeting to be more precise, wrapping actions with targeting macro conditionals.\nThis overrides SoftTarget CVars.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.char.reticleTargeting
      end,
      set = function(value)
        CM.DB.char.reticleTargeting = value
        if value then
          CM.ConfigReticleTargeting("combatmode")
        else
          CM.ConfigReticleTargeting("blizzard")
        end
        ReloadUI()
      end,
    })
    ctx:Toggle({
      label = "Only Allow Reticle To Target Enemies",
      desc = "Only allow Reticle Targeting to select hostile units, ignoring friendly NPCs and Players.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.char.reticleTargetingEnemyOnly
      end,
      set = function(value)
        CM.DB.char.reticleTargetingEnemyOnly = value
        ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Limit Reticle Targeting To Click Casting Actions",
      desc = "Reticle unit targeting and ground-targeted macro injection apply only to Click Casting bindings.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.char.macroInjectionClickCastOnly
      end,
      set = function(value)
        CM.DB.char.macroInjectionClickCastOnly = value
        ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting or CM.ThirdPartyActionBarsActive == true
      end,
    })
    ctx:Gap()
    ctx:TextInput({
      label = "Spells to exclude from Reticle Targeting (comma separated)",
      desc = "Spells you DON'T want the targeting macro conditionals applied to.",
      multiline = 4,
      get = function()
        return CM.DB.char.excludeFromTargetingSpells or ""
      end,
      set = function(value)
        CM.DB.char.excludeFromTargetingSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:TextInput({
      label = "Ground-targeted spells cast at the Reticle (comma separated)",
      desc = "Ground-targeted abilities cast with @cursor directly at the crosshair without placing the green circle.",
      multiline = 4,
      get = function()
        return CM.DB.char.castAtCursorSpells or ""
      end,
      set = function(value)
        CM.DB.char.castAtCursorSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })

    ctx:Gap()
    ctx:Header("CUSTOM SETTINGS")
    ctx:Description(
      "Modify Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines.\nBe cautious: editing these values could break Reticle Targeting and Target Lock."
    )
    ctx:ButtonRow({
      {
        label = "Reticle Targeting CVar Editor",
        func = function()
          CM.OpenReticleTargetingCVarEditor()
        end,
      },
      {
        label = "Targeting Macro Prelines Editor",
        func = function()
          CM.OpenTargetingMacroPrelinesEditor()
        end,
      },
    })
  end,
})
