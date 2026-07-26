---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabReticleTargeting.lua — OPTIONS TAB — Reticle Targeting
---------------------------------------------------------------------------------------
--  Registers the "Reticle Targeting" tab: the reticle toggles (confirm + ReloadUI), the
--  exclude/@cursor spell lists, and the execute buttons that open the custom Reticle CVar
--  editor (UI/Editors/ReticleCVarEditorPanel.lua) and the Targeting Macro
--  Prelines editor. Sticky targeting lives on the Action Camera tab; the Target Lock
--  "selected target not crosshair" toggle lives on the General tab. Feature APIs
--  unchanged (CM.ConfigReticleTargeting, RefreshClickCastMacros).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local strtrim = _G.strtrim

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

UI.Options.AddTab({
  id = "reticle",
  label = "Reticle Targeting",
  build = function(ctx)
    ctx:Header("RETICLE TARGETING")

    ctx:Toggle({
      label = "Enable Reticle Targeting",
      desc = "Aim the crosshair at units to pick targets instead of tab-targeting.",
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
      label = "Enemies Only",
      desc = "Only target hostile units, ignoring friendly NPCs and Players.",
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
      label = "Click Casting Only",
      desc = "Apply reticle targeting logic only to Click Casting binds.",
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
      label = "Excluded Spells",
      desc = "Spells to skip the reticle targeting logic, even if assigned to Click Casting binds.",
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
      label = "Cast at Crosshair",
      desc = "Ground spells to automatically cast at the crosshair location.",
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
    ctx:Header("ADVANCED")
    ctx:Description(
      "Modify Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines. Be cautious: editing these values could break Reticle Targeting and Target Lock."
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
