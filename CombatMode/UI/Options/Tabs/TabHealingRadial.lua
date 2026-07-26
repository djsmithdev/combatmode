---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabHealingRadial.lua — OPTIONS TAB — Party Radial
---------------------------------------------------------------------------------------
--  Registers the "Party Radial" tab (runtime module remains CM.HealingRadial):
--  enable toggle (confirm + ReloadUI), keybind, and visual settings (radius, scale,
--  name font, role icon size, health bars, background). Live preview while this tab
--  is open via CM.HealingRadial.SetOptionsPreview (same onSelect/onDeselect pattern as
--  the Crosshair tab). Visual setters call ApplyVisualConfig so changes show live.
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

local function RadialEnabled()
  return CM.DB.global.healingRadial.enabled
end

local function RadialDisabled()
  return not RadialEnabled()
end

local function ApplyVisualConfig()
  if CM.HealingRadial and CM.HealingRadial.ApplyVisualConfig then
    CM.HealingRadial.ApplyVisualConfig()
  end
end

UI.Options.AddTab({
  id = "healingradial",
  label = "Party Radial",
  onSelect = function()
    if CM.HealingRadial and CM.HealingRadial.SetOptionsPreview then
      CM.HealingRadial.SetOptionsPreview(true)
    end
  end,
  onDeselect = function()
    if CM.HealingRadial and CM.HealingRadial.SetOptionsPreview then
      CM.HealingRadial.SetOptionsPreview(false)
    end
  end,
  build = function(ctx)
    ctx:Header("PARTY RADIAL")
    ctx:Description(
      "Hold a Click Casting action or the Party Radial keybind during Mouse Look, aim at a slice, and release to cast."
    )

    ctx:Toggle({
      label = "Enable Party Radial",
      desc = "Radial menu for quickly casting spells at party members.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = RadialEnabled,
      set = function(value)
        CM.DB.global.healingRadial.enabled = value
        ReloadUI()
      end,
    })
    ctx:Keybind({
      label = "Keybind",
      desc = "Tap to toggle. Hold to show temporarily.",
      get = function()
        return (GetBindingKey("Combat Mode - Healing Radial"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("party radial keybinding", function()
          local oldKey = (GetBindingKey("Combat Mode - Healing Radial"))
          if oldKey then
            SetBinding(oldKey)
          end
          if key ~= "" then
            SetBinding(key, "Combat Mode - Healing Radial")
          end
          SaveBindings(GetCurrentBindingSet())
        end)
      end,
      disabled = RadialDisabled,
    })

    ctx:Slider({
      label = "Size",
      desc = "Distance from center to each slice.",
      min = 100,
      max = 200,
      step = 10,
      get = function()
        return CM.DB.global.healingRadial.sliceRadius
      end,
      set = function(value)
        CM.DB.global.healingRadial.sliceRadius = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Slider({
      label = "Slice Scale",
      desc = "Scale of icons, names, and health bars.",
      min = 0.5,
      max = 1.5,
      step = 0.1,
      get = function()
        return CM.DB.global.healingRadial.sliceSize
      end,
      set = function(value)
        CM.DB.global.healingRadial.sliceSize = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Slider({
      label = "Name Size",
      desc = "Party member name size.",
      min = 8,
      max = 24,
      step = 1,
      get = function()
        return CM.DB.global.healingRadial.nameFontSize or 13
      end,
      set = function(value)
        CM.DB.global.healingRadial.nameFontSize = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Slider({
      label = "Role Icon Size",
      desc = "Role icon size.",
      min = 16,
      max = 96,
      step = 16,
      get = function()
        return CM.DB.global.healingRadial.roleIconSize or 64
      end,
      set = function(value)
        CM.DB.global.healingRadial.roleIconSize = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Toggle({
      label = "Health Bars",
      desc = "Show health bars on each slice.",
      get = function()
        return CM.DB.global.healingRadial.showHealthBars
      end,
      set = function(value)
        CM.DB.global.healingRadial.showHealthBars = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Toggle({
      label = "Background",
      desc = "Show a background behind the radial.",
      get = function()
        return CM.DB.global.healingRadial.showBackground
      end,
      set = function(value)
        CM.DB.global.healingRadial.showBackground = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
  end,
})
