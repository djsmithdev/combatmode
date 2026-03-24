---------------------------------------------------------------------------------------
--  Config/ConfigHealingRadial.lua — Healing radial (toggle, keybind, visuals)
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Header, Description = U.Spacing, U.Header, U.Description

-- WoW API
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

CM.Config.HealingRadialOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("radial", 1),
    description = Description("radial", 2),
    enabled = {
      type = "toggle",
      name = "Enable |cff00FF7FHealing Radial|r",
      desc =
      "Enables a radial menu for quickly casting helpful spells at party members. While |cffE52B50Mouse Look|r is active and you're in a party, hold a mouse button to display the radial, flick toward your target, and release to cast.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 2.3,
      order = 3,
      confirm = true,
      confirmText = CM.METADATA["TITLE"] ..
          "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to the |cff00FF7FHealing Radial|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.global.healingRadial.enabled = value
        -- Reload required: frame is only created in HR.Initialize() when enabled is true
        ReloadUI()
      end,
      get = function()
        return CM.DB.global.healingRadial.enabled
      end
    },
    keybind = {
      type = "keybinding",
      name = "|cffffd700Toggle / Hold - Radial|r",
      desc =
      "Tap to toggle the |cff00FF7FHealing Radial|r menu |cff00FF7FOn|r or |cffE52B50Off|r.\n\nHold to temporarily display it — releasing closes it.",
      width = 1.25,
      order = 4,
      set = function(_, key)
        CM.TryApplyBindingChange("healing radial keybinding", function()
          local oldKey =
              (GetBindingKey("Combat Mode - Healing Radial"))
          if oldKey then SetBinding(oldKey) end
          SetBinding(key, "Combat Mode - Healing Radial")
          SaveBindings(GetCurrentBindingSet())
        end)
      end,
      get = function()
        return (GetBindingKey("Combat Mode - Healing Radial"))
      end,
      disabled = function()
        return not CM.DB.global.healingRadial.enabled
      end
    },
    visualGroup = {
      type = "group",
      name = "Visual Settings",
      order = 5,
      inline = true,
      args = {
        sliceRadius = {
          type = "range",
          name = "Radial Size",
          desc = "Distance from center to each party member slice.\n\n|cffffd700Default:|r |cff00FF7F120|r",
          min = 100,
          max = 200,
          step = 10,
          width = 1.75,
          order = 1,
          set = function(_, value)
            CM.DB.global.healingRadial.sliceRadius = value
            if CM.HealingRadial and
                CM.HealingRadial.UpdateSlicePositionsAndSizes then
              CM.HealingRadial.UpdateSlicePositionsAndSizes()
            end
          end,
          get = function()
            return CM.DB.global.healingRadial.sliceRadius
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        },
        spacing = Spacing(0.15, 1.1),
        sliceSize = {
          type = "range",
          name = "Slice Scale",
          desc =
          "Scale factor for slice elements (role icon, name, health bar). Hover increases by 10%.\n\n|cffffd700Default:|r |cff00FF7F1.0|r (100%)",
          min = 0.5,
          max = 1.5,
          step = 0.1,
          width = 1.75,
          order = 2,
          set = function(_, value)
            CM.DB.global.healingRadial.sliceSize = value
            if CM.HealingRadial and
                CM.HealingRadial.UpdateSlicePositionsAndSizes then
              CM.HealingRadial.UpdateSlicePositionsAndSizes()
            end
          end,
          get = function()
            return CM.DB.global.healingRadial.sliceSize
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        },
        spacing2 = Spacing("full", 2.1),
        nameFontSize = {
          type = "range",
          name = "Name Font Size",
          desc = "Size of party member names on each slice.\n\n|cffffd700Default:|r |cff00FF7F13|r",
          min = 8,
          max = 24,
          step = 1,
          width = 1.75,
          order = 3,
          set = function(_, value)
            CM.DB.global.healingRadial.nameFontSize = value
          end,
          get = function()
            return CM.DB.global.healingRadial.nameFontSize or 13
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        },
        spacing3 = Spacing(0.15, 3.1),
        roleIconSize = {
          type = "range",
          name = "Role Icon Size",
          desc = "Size of the role icons (tank, healer, DPS) on each slice.\n\n|cffffd700Default:|r |cff00FF7F64|r",
          min = 16,
          max = 96,
          step = 16,
          width = 1.75,
          order = 4,
          set = function(_, value)
            CM.DB.global.healingRadial.roleIconSize = value
          end,
          get = function()
            return CM.DB.global.healingRadial.roleIconSize or 64
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        },
        spacing4 = Spacing("full", 4.1),
        showHealthBars = {
          type = "toggle",
          name = "Show Health Bars",
          desc = "Display health bars on each party member slice.\n\n|cffffd700Default:|r |cffE52B50Off|r",
          width = 1.9,
          order = 5,
          set = function(_, value)
            CM.DB.global.healingRadial.showHealthBars = value
          end,
          get = function()
            return CM.DB.global.healingRadial.showHealthBars
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        },
        showBackground = {
          type = "toggle",
          name = "Show Radial Background",
          desc = "Display a background behind the |cff00FF7FHealing Radial|r.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
          width = 1.2,
          order = 6,
          set = function(_, value)
            CM.DB.global.healingRadial.showBackground = value
          end,
          get = function()
            return CM.DB.global.healingRadial.showBackground
          end,
          disabled = function()
            return not CM.DB.global.healingRadial.enabled
          end
        }
      }
    },
    spacing3 = Spacing("full", 5.1),
    layoutInfo = {
      type = "group",
      name = "|cffffd700Layout Information|r",
      order = 6,
      inline = true,
      args = {
        layoutNote = {
          type = "description",
          name =
          "|cff909090Party members are automatically positioned by role:|r\n\n|cffcfcfcf• |cff00d1ffTank|r at 12 o'clock (top)\n• |cff00ff00Healer|r at 7 o'clock (bottom-left)\n• |cffff6060DPS|r fill remaining positions\n\nYour character is included in the radial at your role's position.|r",
          order = 1
        }
      }
    },
    devnote = {
      type = "group",
      name = "|cffffd700Developer Note|r",
      order = 7,
      inline = true,
      args = {
        note = {
          type = "description",
          name =
          "|cff909090The |cff00FF7FHealing Radial|r uses the same spell assignments as |cffB47EDCClick Casting|r. Configure which spells are bound to each mouse button in the Click Casting tab.|r\n\n|cffFF5050Note:|r Party assignments can only be updated outside of combat due to WoW API restrictions.",
          order = 1
        }
      }
    }
  }
}
