---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAllyCycle.lua — OPTIONS TAB — Ally Cycle + HUD
---------------------------------------------------------------------------------------
--  What it does: Wires Ally Cycle Up/Down keybinds and Ally HUD show/side/scale.
--  Unbound cycle keys disable the feature (Target Lock pattern).
--  Architecture / how it works:
--    • DB.global.allyCycle.*; ApplyAllyCycleBindings after keybind sets;
--      ApplyAllyCycleHUDLayout / RefreshAllyCycleHUD after visual sets.
--    • onSelect/onDeselect → SetAllyCycleOptionsPreview (crosshair + sample Ally HUD).
--  Does not: Own secure roster or macro prelines.
--  Related: Core/AllyCycle/{Cycle,HUD,AllyCycle}.lua, Constants/AllyCycle.lua,
--  Constants/DatabaseDefaults.lua, UI/Options/OptionsPanel.lua
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
      hudSide = "TOP",
      scale = 1.0,
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
      text = "Ally Cycle lets you attack enemies and assist allies simultaneously by allowing selection of group members while in Mouse Look.\n"
        .. "When an ally is selected, helpful spells are cast on them, while harmful spells continue to target your hostile Crosshair target.",
    })

    ctx:Keybind({
      label = "Ally Cycle - Next",
      desc = "Target the next group member.",
      get = function()
        return GetBindingKey(CM.AllyCycleBindUp or "Combat Mode - Ally Cycle Up")
      end,
      set = function(key)
        CM.TryApplyBindingChange("ally cycle up keybinding", function()
          CM.AssignNamedKeybind(CM.AllyCycleBindUp or "Combat Mode - Ally Cycle Up", key)
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
        return GetBindingKey(CM.AllyCycleBindDown or "Combat Mode - Ally Cycle Down")
      end,
      set = function(key)
        CM.TryApplyBindingChange("ally cycle down keybinding", function()
          CM.AssignNamedKeybind(CM.AllyCycleBindDown or "Combat Mode - Ally Cycle Down", key)
          if CM.ApplyAllyCycleBindings then
            CM.ApplyAllyCycleBindings()
          end
          if CM.RefreshClickCastMacros then
            CM.RefreshClickCastMacros()
          end
        end)
      end,
    })

    ctx:Gap()
    ctx:Header({ text = "ALLY HUD", newFeatureFlag = true })

    ctx:Toggle({
      label = "Show Ally HUD",
      desc = "Show an indicator for the currently selected group member beside the crosshair.",
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
        return AllyCycleDb().hudSide or "TOP"
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
