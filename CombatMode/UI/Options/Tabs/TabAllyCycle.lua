---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAllyCycle.lua — OPTIONS TAB — Ally Cycle + HUD
---------------------------------------------------------------------------------------
--  What it does: Up/Down keybinds, Skip Self, Keep Ally After Harm, and Ally HUD
--  show/side/scale. Unbound keys disable.
--  Architecture / how it works:
--    • DB.global.allyCycle; onSelect/onDeselect → SetAllyCycleOptionsPreview.
--    • Skip Self → skipPlayer + ApplyAllyCycleBindings (secure attribute).
--    • Keep Ally After Harm → SetAllyCycleRestoreAfterHarm + RefreshClickCastMacros.
--  Does not: Own secure roster or build click-cast macrotext.
--  Related: Core/AllyCycle/{Cycle,HUD,AllyCycle}.lua, Constants/DatabaseDefaults.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, UI/Options/OptionsPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey

local UI = CM.UI

local HUD_SIDE_VALUES = {
  TOP = "Top",
  BOTTOM = "Bottom",
  LEFT = "Left",
  RIGHT = "Right",
}
local HUD_SIDE_ORDER = { "TOP", "BOTTOM", "LEFT", "RIGHT" }

local function ApplyHud()
  if CM.ApplyAllyCycleHUDLayout then
    CM.ApplyAllyCycleHUDLayout()
  end
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end

local function AllyCycleDb()
  if not CM.DB.global.allyCycle then
    CM.DB.global.allyCycle = {
      showHud = true,
      hudSide = "BOTTOM",
      scale = 1.0,
      skipPlayer = true,
      restoreAllyAfterHarm = false,
      restoreAllyAfterHarmSet = false,
    }
  end
  return CM.DB.global.allyCycle
end

UI.Options.AddTab({
  id = "allycycle",
  label = "Ally Cycle",
  newFeatureFlag = true,
  onSelect = function()
    if CM.SetAllyCycleOptionsPreview then
      CM.SetAllyCycleOptionsPreview(true)
    end
  end,
  onDeselect = function()
    if CM.SetAllyCycleOptionsPreview then
      CM.SetAllyCycleOptionsPreview(false)
    end
  end,
  build = function(ctx)
    ctx:Header({ text = "ALLY CYCLE", newFeatureFlag = true })

    ctx:Description({
      text = "Ally Cycle lets you attack enemies and assist allies simultaneously by allowing selection of group members while in Mouse Look."
        .. "When an ally is selected, helpful spells are cast on them, while harmful spells continue to target your hostile Crosshair target.",
    })

    ctx:Keybind({
      label = "Ally Cycle - Next",
      desc = "Target the next group member.",
      get = function()
        return GetBindingKey(CM.AllyCycleBindUp or "Combat Mode - Ally Cycle Next")
      end,
      set = function(key)
        CM.TryApplyBindingChange("ally cycle next keybinding", function()
          CM.AssignNamedKeybind(CM.AllyCycleBindUp or "Combat Mode - Ally Cycle Next", key)
          if CM.ApplyAllyCycleBindings then
            CM.ApplyAllyCycleBindings()
          end
          if CM.RefreshClickCastMacros then
            CM.RefreshClickCastMacros()
          end
        end)
      end,
    })
    ctx:Keybind({
      label = "Ally Cycle - Previous",
      desc = "Target the previous group member.",
      get = function()
        return GetBindingKey(CM.AllyCycleBindDown or "Combat Mode - Ally Cycle Previous")
      end,
      set = function(key)
        CM.TryApplyBindingChange("ally cycle previous keybinding", function()
          CM.AssignNamedKeybind(CM.AllyCycleBindDown or "Combat Mode - Ally Cycle Previous", key)
          if CM.ApplyAllyCycleBindings then
            CM.ApplyAllyCycleBindings()
          end
          if CM.RefreshClickCastMacros then
            CM.RefreshClickCastMacros()
          end
        end)
      end,
    })
    ctx:Toggle({
      label = "Skip Self",
      desc = "Skip yourself when cycling through group members.",
      get = function()
        return CM.IsAllyCycleSkipPlayer and CM.IsAllyCycleSkipPlayer()
      end,
      set = function(value)
        AllyCycleDb().skipPlayer = value and true or false
        if CM.ApplyAllyCycleBindings then
          CM.ApplyAllyCycleBindings()
        end
      end,
    })
    ctx:Toggle({
      label = "Keep Ally After Harm",
      desc = "After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed.",
      get = function()
        return CM.IsAllyCycleRestoreAfterHarm and CM.IsAllyCycleRestoreAfterHarm()
      end,
      set = function(value)
        if CM.SetAllyCycleRestoreAfterHarm then
          CM.SetAllyCycleRestoreAfterHarm(value)
        end
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      disabled = function()
        return CM.DB.char.autoTargetLockOnAttack == true
      end,
      watermarkWhenDisabled = function()
        if CM.DB.char.autoTargetLockOnAttack == true then
          return "Disabled while Auto Target Lock is on"
        end
        return nil
      end,
    })

    ctx:Gap()
    ctx:Header({ text = "ALLY HUD", newFeatureFlag = true })

    ctx:Toggle({
      label = "Show Ally HUD",
      desc = "Show a unit frame for the currently selected group member.",
      get = function()
        return AllyCycleDb().showHud ~= false
      end,
      set = function(value)
        AllyCycleDb().showHud = value
        ApplyHud()
      end,
    })
    ctx:Dropdown({
      label = "HUD Position",
      desc = "Where the Ally HUD sits relative to the crosshair.",
      values = HUD_SIDE_VALUES,
      order = HUD_SIDE_ORDER,
      get = function()
        return AllyCycleDb().hudSide or "BOTTOM"
      end,
      set = function(value)
        AllyCycleDb().hudSide = value
        ApplyHud()
      end,
    })
    ctx:Slider({
      label = "HUD Scale",
      desc = "Scales the size of the Ally HUD.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
      get = function()
        return AllyCycleDb().scale or 1
      end,
      set = function(value)
        AllyCycleDb().scale = value
        ApplyHud()
      end,
    })
  end,
})
