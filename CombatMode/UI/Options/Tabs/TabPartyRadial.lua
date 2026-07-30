---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabPartyRadial.lua — OPTIONS TAB — Party Radial + preview
---------------------------------------------------------------------------------------
--  What it does: Wires party radial enable (reload), open keybind, and simplified visual
--  options: Health Bars and Background. Layout geometry (slice radius, scale, role icon
--  size, name font size) is fixed in Core/PartyRadial. SetOptionsPreview on tab
--  select/deselect for layout-only preview.
--  Architecture / how it works:
--    • Config under DB.global.partyRadial.*; ApplyVisualConfig after visual sets.
--    • Keybind via TryApplyBindingChange + AssignNamedKeybind (clears Interact orphans
--      and refreshes Target Lock override).
--  Does not: Own secure slice attributes or roster hooks (CM.PartyRadial runtime).
--  Related: Core/PartyRadial/PartyRadial.lua, Constants/PartyRadial.lua,
--  Constants/DatabaseDefaults.lua, UI/Options/OptionsPanel.lua,
--  Core/Runtime/BindingQueue.lua, Core/ClickCasting/BindingOverrides.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey
local ReloadUI = _G.ReloadUI

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

local function RadialEnabled()
  return CM.DB.global.partyRadial.enabled
end

local function RadialDisabled()
  return not RadialEnabled()
end

local function ApplyVisualConfig()
  if CM.PartyRadial and CM.PartyRadial.ApplyVisualConfig then
    CM.PartyRadial.ApplyVisualConfig()
  end
end

UI.Options.AddTab({
  id = "partyradial",
  label = "Party Radial",
  onSelect = function()
    if CM.PartyRadial and CM.PartyRadial.SetOptionsPreview then
      CM.PartyRadial.SetOptionsPreview(true)
    end
  end,
  onDeselect = function()
    if CM.PartyRadial and CM.PartyRadial.SetOptionsPreview then
      CM.PartyRadial.SetOptionsPreview(false)
    end
  end,
  build = function(ctx)
    ctx:Header("PARTY RADIAL")
    ctx:Description(
      "During Mouse Look, use the Party Radial to quickly cast spells and target party members."
    )

    ctx:Toggle({
      label = "Enable Party Radial",
      desc = "Radial menu for quickly casting spells at party members.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = RadialEnabled,
      set = function(value)
        CM.DB.global.partyRadial.enabled = value
        ReloadUI()
      end,
    })
    ctx:Keybind({
      label = "Party Radial Keybind",
      desc = "Tap to toggle the Party Radial. Hold to show temporarily.",
      get = function()
        return (GetBindingKey("Combat Mode - Party Radial"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("party radial keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Party Radial", key)
        end)
      end,
      disabled = RadialDisabled,
    })

    ctx:Toggle({
      label = "Health Bars",
      desc = "Show health bars on each slice.",
      get = function()
        return CM.DB.global.partyRadial.showHealthBars
      end,
      set = function(value)
        CM.DB.global.partyRadial.showHealthBars = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
    ctx:Toggle({
      label = "Background",
      desc = "Show a background behind the radial.",
      get = function()
        return CM.DB.global.partyRadial.showBackground
      end,
      set = function(value)
        CM.DB.global.partyRadial.showBackground = value
        ApplyVisualConfig()
      end,
      disabled = RadialDisabled,
    })
  end,
})
