---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabReticleTargeting.lua — OPTIONS TAB — reticle targeting
---------------------------------------------------------------------------------------
--  What it does: Wires Reticle Targeting enable (reload + ConfigReticleTargeting),
--  enemy-only preline mode, Auto Target Lock (selects auto-lock preline pair),
--  macroInjectionClickCastOnly, exclude / cast-at-crosshair spell multi-selects,
--  Target Lock keybinds / marker / autofocus, and Advanced buttons that open
--  the Reticle CVar editor and Targeting Macro Prelines editor.
--  Architecture / how it works:
--    • DB.char: reticleTargeting, reticleTargetingEnemyOnly, autoTargetLockOnAttack,
--      macroInjectionClickCastOnly, stickyCrosshair, excludeFromTargetingSpells,
--      castAtCursorSpells.
--    • DB.global: showTargetLockMarker, autofocusLockedTarget.
--    • macroInjectionClickCastOnly disabled/forced when ThirdPartyActionBarsActive.
--    • Spell lists stored as spell-ID CSV; membership in TargetingMacroBuilder.
--    • Target Lock keybinds go through TryApplyBindingChange + AssignNamedKeybind.
--  Does not: Own CVar override table UI (ReticleCVarEditor*) or secure proxies.
--  Related: Core/Runtime/CVarManager.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, Core/Crosshair/FocusNameplateMarker.lua,
--  UI/Options/SpellMultiSelect.lua, UI/Editors/ReticleCVarEditorPanel.lua,
--  UI/Editors/TargetingMacroPrelinesEditor.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey
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
      charSpecific = true,
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
      charSpecific = true,
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
      label = "Auto Target Lock",
      desc = "Target Lock engages automatically when attacking units.",
      charSpecific = true,
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.char.autoTargetLockOnAttack
      end,
      set = function(value)
        CM.DB.char.autoTargetLockOnAttack = value
        ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Click Casting Only",
      desc = "Apply reticle targeting logic only to Click Casting binds.",
      charSpecific = true,
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
    ctx:SpellMultiSelect({
      label = "Excluded Spells",
      desc = "Spells to skip the reticle targeting logic.",
      charSpecific = true,
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
    ctx:SpellMultiSelect({
      label = "Cast at Crosshair",
      desc = "Ground spells to cast at the crosshair location.",
      charSpecific = true,
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
    ctx:Header("TARGET LOCK")

    ctx:Keybind({
      label = "Target Lock Keybind",
      desc = "Tap to lock the reticle to your target, preventing it from swapping. Tap again to unlock.\n"
        .. "Follows Reticle Targeting settings.",
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("target lock keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Toggle Focus Target", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Keybind({
      label = "Cycle Lock - Next",
      desc = "Move Target Lock to the next valid nearby target.",
      get = function()
        return GetBindingKey("Combat Mode - Cycle Focus Next")
      end,
      set = function(key)
        CM.TryApplyBindingChange("cycle focus next keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Cycle Focus Next", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Keybind({
      label = "Cycle Lock - Previous",
      desc = "Move Target Lock to the previous valid nearby target.",
      get = function()
        return GetBindingKey("Combat Mode - Cycle Focus Previous")
      end,
      set = function(key)
        CM.TryApplyBindingChange("cycle focus previous keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Cycle Focus Previous", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Target Lock Marker",
      desc = "Show a crosshair marker on the nameplate of the locked target.",
      get = function()
        return CM.DB.global.showTargetLockMarker ~= false
      end,
      set = function(value)
        CM.DB.global.showTargetLockMarker = value
        if CM.ClearFocusNameplateMarker then
          CM.ClearFocusNameplateMarker()
        end
        if value and CM.UpdateFocusNameplateMarker then
          CM.UpdateFocusNameplateMarker()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Autofocus Locked Target",
      desc = "Pulls the camera toward your locked target.",
      get = function()
        return CM.DB.global.autofocusLockedTarget ~= false
      end,
      set = function(value)
        CM.DB.global.autofocusLockedTarget = value
        if CM.SyncTargetFocusFromFocusUnit then
          CM.SyncTargetFocusFromFocusUnit()
        end
      end,
      watermarkWhenDisabled = function()
        if CM.DynamicCam then
          return "Control relinquished to DynamicCam"
        end
        return nil
      end,
      disabled = function()
        return CM.DynamicCam or not CM.DB.char.reticleTargeting
      end,
    })

    ctx:Gap()
    ctx:Header("ADVANCED")
    ctx:Description({
      text = "Modify Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines.",
      warning = "Warning: editing these values could break Reticle Targeting and Target Lock.",
    })
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
