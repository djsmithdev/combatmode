---------------------------------------------------------------------------------------
--  Config/ConfigShared.lua — shared AceConfig builders (spacing, headers, groups)
---------------------------------------------------------------------------------------
--  Loaded after ConfigNamespace.lua and before other Config/Config*.lua + ConfigCategories.lua.
--  Exposes CM.Config.OptionsUI for
--  category files to avoid duplicating layout helpers and GetButtonOverrideGroup.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

local function Spacing(width, order)
  return { type = "description", name = " ", width = width, order = order }
end

local function Header(option, order)
  local headers = {
    about = { type = "header", name = "|cffffffffABOUT|r", order = order },
    freelook = {
      type = "header",
      name = "|cffE52B50MOUSE LOOK|r",
      order = order,
    },
    unlock = {
      type = "header",
      name = "|cffffd700AUTO CURSOR UNLOCK|r",
      order = order,
    },
    reticle = {
      type = "header",
      name = "|cff00FFFFRETICLE TARGETING|r",
      order = order,
    },
    clicks = {
      type = "header",
      name = "|cffB47EDCCLICK CASTING|r",
      order = order,
    },
    radial = {
      type = "header",
      name = "|cff00FF7FHEALING RADIAL|r",
      order = order,
    },
    advanced = {
      type = "header",
      name = "|cffffffffADVANCED|r",
      order = order,
    },
    custom = {
      type = "header",
      name = "|cffE52B50CUSTOM SETTINGS|r",
      order = order,
    },
  }
  return headers[option]
end

local function Description(option, order)
  local descriptions = {
    freelook = {
      type = "description",
      name = "\nSet keybinds to activate |cffE52B50Mouse Look|r, interact with |cff00FFFFCrosshair|r target, and configure the behavior of the camera.\n\n",
      fontSize = "medium",
      order = order,
    },
    unlock = {
      type = "description",
      name = "\nSelect whether |cffE52B50Mouse Look|r should be automatically disabled when specific frames are visible, re-enabling once they're closed. |cff909090You can add additional |cffE37527AddOn|r frames to the |cffffd700Watchlist|r to trigger this effect.|r\n\n",
      fontSize = "medium",
      order = order,
    },
    reticle = {
      type = "description",
      name = "\nEnable Combat Mode to transform the default tab-targeting combat into an action-oriented experience, where the |cff00FFFFCrosshair|r dictates target acquisition.\n\n",
      fontSize = "medium",
      order = order,
    },
    prelines = {
      type = "description",
      name = "\nEdit the targeting |cffB47EDEMacro|r preline inserted before actions when |cff00FFFFReticle Targeting|r is enabled.\n\n",
      fontSize = "medium",
      order = order,
    },
    clicks = {
      type = "description",
      name = "\nSelect which actions are fired when Left and Right clicking as well as their modified presses while in |cffE52B50Mouse Look|r mode.\n\n",
      fontSize = "medium",
      order = order,
    },
    radial = {
      type = "description",
      name = "\nA radial menu for quickly casting helpful spells at party members. While |cffE52B50Mouse Look|r is active and you're in a party, hold a mouse button to display the radial, flick toward your target, and release to cast.\n\n",
      fontSize = "medium",
      order = order,
    },
    advanced = {
      type = "description",
      name = "\nCreate your own custom condition that forces a |cffffd700Cursor Unlock|r by entering a chunk of Lua code that at the end evaluates to |cff00FF7FTrue|r if the cursor should be freed, |cffE52B50False|r otherwise.\n\n|cff909090For example, this would unlock the cursor while standing still but not while mounted: \n\n|cff69ccf0local isStill = GetUnitSpeed('player') == 0 \nlocal onMount = IsMounted()\nreturn not onMount and isStill|r\n\n",
      fontSize = "medium",
      order = order,
    },
  }
  return descriptions[option]
end

local function GetButtonOverrideGroup(modifier, groupOrder)
  local button1Settings, button2Settings, groupName, button1Name, button2Name
  if modifier then
    button1Settings = modifier .. "button1"
    button2Settings = modifier .. "button2"

    local capitalisedModifier = (string.upper(modifier))
    groupName = capitalisedModifier .. " + Clicks"
    button1Name = "|cffB47EDE" .. capitalisedModifier .. " + Left Click Action" .. "|r"
    button2Name = "|cffB47EDE" .. capitalisedModifier .. " + Right Click Action" .. "|r"
  else
    button1Settings = "button1"
    button2Settings = "button2"

    groupName = "Base Clicks"
    button1Name = "|cffB47EDE" .. "Left Click Action" .. "|r"
    button2Name = "|cffB47EDE" .. "Right Click Action" .. "|r"
  end

  return {
    type = "group",
    name = groupName,
    order = groupOrder,
    args = {
      overrideButton1Toggle = {
        type = "toggle",
        name = "|A:NPE_LeftClick:38:38|a",
        desc = "Enables the use of the "
          .. button1Name
          .. " casting override while in |cffE52B50Mouse Look|r mode.",
        width = 0.4,
        order = 1,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled = value
          if value then
            CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
          else
            CM.ResetBindingOverride(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
          end
          if CM.HealingRadial and CM.HealingRadial.OnBindingChanged then
            CM.HealingRadial.OnBindingChanged()
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled
        end,
        disabled = modifier == nil,
      },
      button1 = {
        name = button1Name,
        desc = "",
        type = "select",
        width = 1.5,
        order = 1.1,
        values = CM.Constants.OverrideActions,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
          if CM.HealingRadial and CM.HealingRadial.OnBindingChanged then
            CM.HealingRadial.OnBindingChanged()
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled
        end,
      },
      spacing = Spacing(0.1, 1.2),
      button1macro = {
        name = "Macro Name",
        desc = "Enter the name of the |cff69ccf0Macro|r you'd like to bind to this |cffB47EDEClick Casting action|r.",
        type = "input",
        width = 1.65,
        order = 1.3,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].macroName = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].macroName
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled
            or CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value ~= "MACRO"
        end,
        validate = function(_, value)
          if not CM.MacroExists(value) then
            CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName = ""
            return CM.METADATA["TITLE"] .. "\n\n|cffcfcfcfNo macro found with that name.|r"
          else
            return true
          end
        end,
      },
      buttonbreak = {
        type = "description",
        name = " ",
        width = "full",
        order = 1.4,
      },
      overrideButton2Toggle = {
        type = "toggle",
        name = "|A:NPE_RightClick:38:38|a",
        desc = "Enable the use of the "
          .. button2Name
          .. " casting override while in |cffE52B50Mouse Look|r mode.",
        width = 0.4,
        order = 2,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled = value
          if value then
            CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
          else
            CM.ResetBindingOverride(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
          end
          if CM.HealingRadial and CM.HealingRadial.OnBindingChanged then
            CM.HealingRadial.OnBindingChanged()
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled
        end,
        disabled = modifier == nil,
      },
      button2 = {
        name = button2Name,
        desc = "",
        type = "select",
        width = 1.5,
        order = 2.1,
        values = CM.Constants.OverrideActions,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
          if CM.HealingRadial and CM.HealingRadial.OnBindingChanged then
            CM.HealingRadial.OnBindingChanged()
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled
        end,
      },
      spacing2 = Spacing(0.1, 2.2),
      button2macro = {
        name = "Macro Name",
        desc = "Enter the name of the |cff69ccf0Macro|r you'd like to bind to this |cffB47EDEClick Casting action|r.",
        type = "input",
        width = 1.65,
        order = 2.3,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled
            or CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value ~= "MACRO"
        end,
        validate = function(_, value)
          if not CM.MacroExists(value) then
            CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName = ""
            return CM.METADATA["TITLE"] .. "\n\n|cffcfcfcfNo macro found with that name.|r"
          else
            return true
          end
        end,
      },
      spacing3 = Spacing("full", 3),
      devnote = {
        type = "group",
        name = "|cffffd700Developer Note|r",
        order = 4,
        inline = true,
        args = {
          note = {
            type = "description",
            name = "|cff909090To directly assign a |cffcfcfcfMacro|r as a |cffB47EDEClick Casting Action|r, select |cff69ccf0Run MACRO|r from the drop-down list and type its name in the input.|r",
            order = 4,
          },
        },
      },
    },
  }
end

CM.Config.OptionsUI = {
  Spacing = Spacing,
  Header = Header,
  Description = Description,
  GetButtonOverrideGroup = GetButtonOverrideGroup,
}
