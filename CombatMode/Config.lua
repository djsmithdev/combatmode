---------------------------------------------------------------------------------------
--                                CONFIG/OPTIONS PANEL                               --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- Check if running on Retail or Classic
local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

-- CACHING GLOBAL VARIABLES
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

CM.Config = {}

---------------------------------------------------------------------------------------
--                                 COMPONENT ASSEMBLER                               --
---------------------------------------------------------------------------------------
local function Spacing(width, order)
  return {
    type = "description",
    name = " ",
    width = width,
    order = order
  }
end

local function Header(option, order)
  local headers = {
    about = {
      type = "header",
      name = "|cffffffffABOUT|r",
      order = order
    },
    freelook = {
      type = "header",
      name = "|cffE52B50MOUSE LOOK|r",
      order = order
    },
    unlock = {
      type = "header",
      name = "|cff00FF7FAUTO CURSOR UNLOCK|r",
      order = order
    },
    reticle = {
      type = "header",
      name = "|cff00FFFFRETICLE TARGETING|r",
      order = order
    },
    clicks = {
      type = "header",
      name = "|cffB47EDCCLICK CASTING|r",
      order = order
    },
    advanced = {
      type = "header",
      name = "|cffffffffADVANCED|r",
      order = order
    }
  }
  return headers[option]
end

local function Description(option, order)
  local descriptions = {
    freelook = {
      type = "description",
      name = "\nSet keybinds to activate |cffE52B50Mouse Look|r, interact with |cff00FFFFCrosshair|r target, and configure the behavior of the camera.\n\n",
      fontSize = "medium",
      order = order
    },
    unlock = {
      type = "description",
      name = "\nSelect whether |cffE52B50Mouse Look|r should be automatically disabled when specific frames are visible, re-enabling once they're closed. |cff909090You can add additional |cffE37527AddOn|r frames to the |cffffd700Watchlist|r to trigger this effect.|r\n\n",
      fontSize = "medium",
      order = order
    },
    reticle = {
      type = "description",
      name = "\nEnable Combat Mode to transform the default tab-targeting combat into an action-oriented experience, where the |cff00FFFFCrosshair|r dictates target acquisition.\n\n",
      fontSize = "medium",
      order = order
    },
    clicks = {
      type = "description",
      name = "\nSelect which actions are fired when Left and Right clicking as well as their modified presses while in |cffE52B50Mouse Look|r mode.\n\n",
      fontSize = "medium",
      order = order
    },
    advanced = {
      type = "description",
      name = "\nCreate your own conditions that force a |cff00FF7FCursor Unlock|r by entering a chunk of Lua code that returns |cff00FF7FTrue|r if the cursor should be freed, |cffE52B50False|r otherwise.\n|cff909090E.g.: to unlock the cursor while standing still or riding a mount, enter: |cff69ccf0GetUnitSpeed(\"player\") == 0 or IsMounted()|r\n\n",
      fontSize = "medium",
      order = order
    }
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
    button1Name = capitalisedModifier .. " + Left Click"
    button2Name = capitalisedModifier .. " + Right Click"
  else
    button1Settings = "button1"
    button2Settings = "button2"

    groupName = "Base Clicks"
    button1Name = "Left Click"
    button2Name = "Right Click"
  end

  return {
    type = "group",
    name = groupName,
    order = groupOrder,
    args = {
      overrideButton1Toggle = {
        type = "toggle",
        name = "|A:NPE_LeftClick:38:38|a",
        desc = "Enables the use of the |cffB47EDE" .. button1Name ..
          "|r casting override while in |cffE52B50Mouse Look|r mode.",
        width = 0.4,
        order = 1,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled = value
          if value then
            CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
          else
            CM.ResetBindingOverride(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled
        end,
        disabled = modifier == nil
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
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled
        end
      },
      spacing = Spacing(0.1, 1.2),
      button1macro = {
        name = "Custom Action",
        desc = "Enter the name of the action you wish to be ran here.",
        type = "input",
        width = 1.65,
        order = 1.3,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].customAction = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button1Settings])
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].customAction
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled or
                   CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value ~= "CUSTOMACTION"
        end
      },
      buttonbreak = {
        type = "description",
        name = " ",
        width = "full",
        order = 1.4
      },
      overrideButton2Toggle = {
        type = "toggle",
        name = "|A:NPE_RightClick:38:38|a",
        desc = "Enable the use of the |cffB47EDE" .. button2Name ..
          "|r casting override while in |cffE52B50Mouse Look|r mode.",
        width = 0.4,
        order = 2,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled = value
          if value then
            CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
          else
            CM.ResetBindingOverride(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
          end
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled
        end,
        disabled = modifier == nil
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
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled
        end
      },
      spacing2 = Spacing(0.1, 2.2),
      button2macro = {
        name = "Custom Action",
        desc = "Enter the name of the action you wish to be ran here.",
        type = "input",
        width = 1.65,
        order = 2.3,
        set = function(_, value)
          CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].customAction = value
          CM.SetNewBinding(CM.DB[CM.GetBindingsLocation()].bindings[button2Settings])
        end,
        get = function()
          return CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].customAction
        end,
        disabled = function()
          return not CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled or
                   CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value ~= "CUSTOMACTION"
        end
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
            name = "|cff909090To use an action not listed on the dropdown menu, select |cff69ccf0Custom Action|r and then type the exact name of the action you'd like to cast. \nTo use a |cffcfcfcfMACRO|r as your |cff69ccf0Custom Action|r, type |cffcfcfcfMACRO MacroName|r into the input.|r\n",
            order = 4
          },
          wowwiki = {
            name = "You can find all available actions here:",
            desc = "warcraft.wiki.gg/wiki/BindingID",
            type = "input",
            width = 1.7,
            order = 5,
            get = function()
              return "warcraft.wiki.gg/wiki/BindingID"
            end
          }
        }
      }
    }
  }
end

---------------------------------------------------------------------------------------
--                                     ABOUT                                     --
---------------------------------------------------------------------------------------
local AboutOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    ---------------------------------------------------------------------------------------
    --                                   DEBUG & RESET                                   --
    ---------------------------------------------------------------------------------------
    resetButton = {
      type = "execute",
      name = "Default",
      desc = "Resets Combat Mode's settings to their default values.",
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfResetting Combat Mode's options to their default will force a |cffE52B50UI Reload|r.|r \n\n|cffffd700Proceed?|r",
      confirm = true,
      width = 0.7,
      func = function()
        CM:OnResetDB()
      end,
      order = 0
    },
    spacing = Spacing(2.2, 0.1),
    debugModeToggle = {
      type = "toggle",
      name = "Debug Mode",
      desc = "Enables the printing of state logs in the game chat to assist with development.",
      width = 0.7,
      set = function(_, value)
        CM.DB.global.debugMode = value
      end,
      get = function()
        return CM.DB.global.debugMode
      end,
      order = 0.2
    },
    ---------------------------------------------------------------------------------------
    --                                   LOGO & ABOUT                                    --
    ---------------------------------------------------------------------------------------
    header = Header("about", 1),
    spacing2 = Spacing("full", 1.1),
    logoImage = {
      type = "description",
      name = " ",
      width = 0.5,
      image = CM.Constants.Logo,
      imageWidth = 64,
      imageHeight = 64,
      imageCoords = {
        0,
        1,
        0,
        1
      },
      order = 1.2
    },
    aboutDescription = {
      type = "description",
      name = CM.METADATA["NOTES"],
      fontSize = "medium",
      width = 3.1,
      order = 1.3
    },
    spacing3 = Spacing("full", 1.4),
    ---------------------------------------------------------------------------------------
    --                                     FEATURES                                      --
    ---------------------------------------------------------------------------------------
    featuresHeader = {
      type = "description",
      name = "|cffffd700Features:|r",
      order = 2,
      fontSize = "medium"
    },
    featuresList = {
      type = "description",
      name = "|cff909090• |cffE52B50Mouse Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of |cffcfcfcf@mouseover|r and |cffcfcfcf@cursor|r macro decorators in combination with the |cff00FFFFCrosshair|r. \n• |cffB47EDEMouse Click Casting|r - When Mouse Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cff00FF7FCursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc.\n\n",
      order = 3
    },
    versionNumber = {
      type = "description",
      name = "|cffffffffVersion:|r " .. "|cff00ff00" .. CM.METADATA["VERSION"] .. "|r\n\n",
      order = 3.2
    },
    authorsList = {
      type = "description",
      name = "|cffffffffAuthors:|r " .. "|cffcfcfcf" .. CM.METADATA["AUTHOR"] .. "|r\n",
      order = 3.3
    },
    contributorsList = {
      type = "description",
      name = "|cffffffffContributors:|r " .. "|cffcfcfcf" .. CM.METADATA["X-CONTRIBUTORS"] .. "|r\n\n",
      order = 3.4
    },
    curse = {
      name = "Download From:",
      desc = CM.METADATA["X-CURSE"],
      type = "input",
      width = 2,
      order = 4,
      get = function()
        return CM.METADATA["X-CURSE"]
      end
    },
    spacing4 = Spacing(0.4, 4.1),
    discord = {
      name = "Feedback & Support:",
      desc = CM.METADATA["X-DISCORD"],
      type = "input",
      width = 1.1,
      order = 5,
      get = function()
        return CM.METADATA["X-DISCORD"]
      end
    },
    spacing5 = Spacing("full", 5.1)
  }
}

---------------------------------------------------------------------------------------
--                                    MOUSE LOOK                                     --
---------------------------------------------------------------------------------------
-- CAMERA FEATURES
local CameraFeatures = {
  type = "group",
  name = "Camera Features |cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r.|r",
  order = 8,
  inline = true,
  args = {
    actionCamera = {
      type = "toggle",
      name = "Load Combat Mode's |cffffd700Action Camera|r Preset |cffE37527•|r",
      desc = "Configures Blizzard's |cffffd700Action Camera|r feature to a curated preset that better matches Combat Mode's development environment. \n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r.|r \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 1,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to Combat Mode's |cffffd700Action Camera|r Preset.|r \n\n|cffffd700Proceed?|r",
      confirm = true,
      set = function(_, value)
        CM.DB.global.actionCamera = value
        if value then
          CM.ConfigActionCamera("combatmode")
        else
          CM.ConfigActionCamera("blizzard")
        end
        ReloadUI()
      end,
      get = function()
        return CM.DB.global.actionCamera
      end,
      disabled = function()
        return CM.DynamicCam
      end
    },
    spacing = Spacing("full", 1.1),
    shoulderOffset = {
      type = "range",
      name = "Camera Over Shoulder Offset |cff3B73FF©|r |cffE37527•|r",
      desc = "|cff3B73FF© Character-based option|r \n\nHorizontally offsets the camera to the left or right of your character while the |cffffd700Action Camera Preset|r is enabled. \n\n|cffE52B50Requires |cffffd700Motion Sickness|r under Acessibility options to be turned off.|r \n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cff00FF7F1.2|r",
      min = -2,
      max = 2,
      softMin = -2,
      softMax = 2,
      step = 0.1,
      width = 1.75,
      order = 2,
      set = function(_, value)
        CM.DB.char.shoulderOffset = value
        CM.SetShoulderOffset()
      end,
      get = function()
        return CM.DB.char.shoulderOffset
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end
    },
    spacing3 = Spacing(0.15, 2.1),
    mouseLookSpeed = {
      type = "range",
      name = "|cffE52B50Mouse Look|r Camera Turn Speed |cffE37527•|r",
      desc = "Adjusts the speed at which you turn the camera while |cffE52B50Mouse Look|r mode is active.\n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cff00FF7F120|r",
      min = 10,
      max = 180,
      softMin = 10,
      softMax = 180,
      step = 10,
      width = 1.75,
      order = 3,
      set = function(_, value)
        CM.DB.global.mouseLookSpeed = value
        CM.SetMouseLookSpeed()
      end,
      get = function()
        return CM.DB.global.mouseLookSpeed
      end,
      disabled = function()
        return CM.DynamicCam
      end
    }
  }
}

local FreeLookOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("freelook", 1),
    description = Description("freelook", 2),
    toggle = {
      type = "keybinding",
      name = "|cffffd700Toggle|r",
      desc = "Toggles the |cffE52B50Mouse Look|r camera ON or OFF.",
      width = 1.25,
      order = 3,
      set = function(_, key)
        local oldKey = (GetBindingKey("Combat Mode Toggle"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "Combat Mode Toggle")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("Combat Mode Toggle"))
      end
    },
    hold = {
      type = "keybinding",
      name = "|cffffd700Press & Hold|r",
      desc = "Hold to temporarily deactivate the |cffE52B50Mouse Look|r camera.",
      width = 1.25,
      order = 4,
      set = function(_, key)
        local oldKey = (GetBindingKey("(Hold) Switch Mode"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "(Hold) Switch Mode")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("(Hold) Switch Mode"))
      end
    },
    interact = {
      type = "keybinding",
      name = "|cffffd700Interact With Target|r",
      desc = "Press to interact with crosshair target when in range. \n\n|cff909090This particular targeting arc is intentionally wider to facilitate interaction with NPCs surrounded by players.|r",
      width = 1.25,
      order = 5,
      set = function(_, key)
        local oldKey = (GetBindingKey("INTERACTTARGET"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "INTERACTTARGET")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("INTERACTTARGET"))
      end
    },
    spacing = Spacing("full", 5.1),
    pulseCursor = {
      type = "toggle",
      name = "Pulse Cursor When Exiting |cffE52B50Mouse Look|r",
      desc = "Quickly pulses the location of the cursor when exiting |cffE52B50Mouse Look|r mode.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 6,
      set = function(_, value)
        CM.DB.global.pulseCursor = value
      end,
      get = function()
        return CM.DB.global.pulseCursor
      end
    },
    hideTooltip = {
      type = "toggle",
      name = "Hide Tooltip During |cffE52B50Mouse Look|r",
      desc = "Hides the tooltip generated by the |cff00FFFFCrosshair|r while |cffE52B50Mouse Look|r is active.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.5,
      order = 6.1,
      set = function(_, value)
        CM.DB.global.hideTooltip = value
      end,
      get = function()
        return CM.DB.global.hideTooltip
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    spacing2 = Spacing("full", 7.1),
    cameraFeatures = CameraFeatures,
    spacing4 = Spacing("full", 8.1),
    spacing5 = Spacing("full", 8.2),
    ---------------------------------------------------------------------------------------
    --                                   CURSOR UNLOCK                                   --
    ---------------------------------------------------------------------------------------
    header2 = Header("unlock", 10),
    description2 = Description("unlock", 11),
    cursorUnlock = {
      type = "toggle",
      name = "Enable |cff00FF7FAuto Cursor Unlock|r",
      desc = "Automatically disables |cffE52B50Mouse Look|r and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 12,
      set = function(_, value)
        CM.DB.global.frameWatching = value
      end,
      get = function()
        return CM.DB.global.frameWatching
      end
    },
    mountCheck = {
      type = "toggle",
      name = "Unlock While On |cffffd700Vendor Mount|r",
      desc = "Keeps the cursor unlocked while a vendor mounts is being used.\n\n|cffffd700Vendor Mounts:|r \n|cff909090Grand Expedition Yak\nTraveler's Tundra Mammoth\nMighty Caravan Brutosaur|r \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.5,
      order = 13,
      set = function(_, value)
        CM.DB.global.mountCheck = value
      end,
      get = function()
        return CM.DB.global.mountCheck
      end
    },
    spacing6 = Spacing("full", 13.1),
    watchlist = {
      name = "Frame Watchlist",
      desc = "Expand the list of Blizzard panels or |cffE37527AddOn|r frames that trigger a |cff00FF7FCursor Unlock.|r \n\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: |cffcfcfcfAddonName + Frame|r.|r \n\n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
      type = "input",
      multiline = true,
      width = "full",
      order = 14,
      disabled = function()
        return CM.DB.global.frameWatching ~= true
      end,
      set = function(_, input)
        CM.DB.global.watchlist = {}
        for value in string.gmatch(input, "[^,]+") do -- Split at the ", "
          value = value:gsub("^%s*(.-)%s*$", "%1") -- Trim spaces
          table.insert(CM.DB.global.watchlist, value)
        end
      end,
      get = function()
        local watchlist = CM.DB.global.watchlist or {}
        return table.concat(watchlist, ", ")
      end
    }
  }
}

---------------------------------------------------------------------------------------
--                                 RETICLE TARGETING                                 --
---------------------------------------------------------------------------------------
-- CROSSHAIR
local CrosshairGroup = {
  type = "group",
  name = "Crosshair",
  order = 7,
  inline = true,
  args = {
    crosshair = {
      type = "toggle",
      name = "Show Crosshair",
      desc = "Places a dynamic crosshair marker in the center of the screen to assist with |cff00FFFFReticle Targeting|r.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.04,
      order = 1,
      set = function(_, value)
        CM.DB.global.crosshair = value
        if value then
          CM.DisplayCrosshair(true)
        else
          CM.DisplayCrosshair(false)
        end
      end,
      get = function()
        return CM.DB.global.crosshair
      end
    },
    crosshairMounted = {
      type = "toggle",
      name = "Hide Crosshair While Mounted",
      desc = "Hides the crosshair while mounted.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.4,
      order = 2,
      set = function(_, value)
        CM.DB.global.crosshairMounted = value
      end,
      get = function()
        return CM.DB.global.crosshairMounted
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    stickyCrosshair = {
      type = "toggle",
      name = "Sticky Crosshair |cff3B73FF©|r |cffE37527•|r",
      desc = "|cff3B73FF© Character-based option|r\n\nMakes the crosshair stick to enemies slightly, making it harder to untarget them by accident.\n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 2.1,
      order = 3,
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
        return CM.DynamicCam or CM.DB.global.crosshair ~= true
      end
    },
    spacing2 = Spacing("full", 3.1),
    crosshairAppearance = {
      name = "Crosshair Appearance",
      desc = "Select the appearance of the crosshair texture.",
      type = "select",
      width = 1.4,
      order = 4,
      values = CM.Constants.CrosshairAppearanceSelectValues,
      set = function(_, value)
        CM.DB.global.crosshairAppearance = CM.Constants.CrosshairTextureObj[value]
        if value then
          CM.CreateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairAppearance.Name
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    spacing3 = Spacing(0.1, 4.1),
    crosshairPreview = {
      type = "description",
      order = 5,
      name = "",
      width = 0.25,
      image = function()
        return CM.DB.global.crosshairAppearance.Base
      end,
      imageWidth = 42,
      imageHeight = 42
    },
    spacing4 = Spacing(0.15, 5.1),
    crosshairSize = {
      type = "range",
      name = "Crosshair Size",
      desc = "Adjusts the size of the crosshair in 16-pixel increments. \n\n|cffffd700Default:|r |cff00FF7F64|r",
      min = 16,
      max = 128,
      softMin = 16,
      softMax = 128,
      step = 16,
      width = 1.75,
      order = 7,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairSize = value
        if value then
          CM.CreateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairSize
      end
    },
    spacing5 = Spacing("full", 6.1),
    crosshairAlpha = {
      type = "range",
      name = "Crosshair Opacity",
      desc = "Adjusts the opacity of the crosshair. \n\n|cffffd700Default:|r |cff00FF7F100|r",
      min = 0.1,
      max = 1.0,
      softMin = 0.1,
      softMax = 1.0,
      step = 0.1,
      width = 1.75,
      order = 8,
      isPercent = true,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairOpacity = value
        if value then
          CM.CreateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairOpacity
      end
    },
    spacing6 = Spacing(0.15, 7.1),
    crosshairY = {
      type = "range",
      name = "Crosshair Vertical Position",
      desc = "Adjusts the vertical position of the crosshair. \n\n|cffffd700Default:|r |cff00FF7F50|r",
      min = 0,
      max = 100,
      softMin = 0,
      softMax = 100,
      step = 10,
      width = 1.75,
      order = 6,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairY = value
        if value then
          CM.CreateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairY
      end
    }
  }
}

local ReticleTargetingOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("reticle", 1),
    description = Description("reticle", 2),
    reticleTargeting = {
      type = "toggle",
      name = "Enable |cff00FFFFReticle Targeting|r |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nConfigures Blizzard's |cffffd700Action Targeting|r feature to be more precise and responsive. \n\n|cffFF5050Be aware that this will override all CVar values related to SoftTarget.|r \n\n|cff909090Uncheck to reset them to their default values.|r\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 3,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
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
      end
    },
    friendlyTargeting = {
      type = "toggle",
      name = "Allow Reticle To Target Friendlies |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nAllows the reticle to target friendly NPCs or Players while |cffE52B50Mouse Look|r is active.\n\n|cff909090Disabled by default to avoid situations like the Fiery Brand bug.|r\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.5,
      order = 4,
      confirm = true,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfAllowing the reticle to target friendlies can, under certain conditions, cause a |cffE52B50Invalid Target|r bug. \n\n|cffffd700Proceed anyway?|r|r",
      set = function(_, value)
        CM.DB.char.friendlyTargeting = value
        if value then
          CM.SetFriendlyTargeting(true)
        else
          CM.SetFriendlyTargeting(false)
        end
      end,
      get = function()
        return CM.DB.char.friendlyTargeting
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    crosshairPriority = {
      type = "toggle",
      name = "Always Prioritize Target Under Reticle |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nGives the reticle the highest priority when determining which unit the spell will be cast on, |cffFF5050ignoring even manually selected (hard-locked) targets in favor of the unit you're aiming at.|r \n\n|cff909090Disabling this will prevent the crosshair from swapping off hard-locked targets.|r\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 5,
      set = function(_, value)
        CM.DB.char.crosshairPriority = value
        if value then
          CM.SetCrosshairPriority(true)
        else
          CM.SetCrosshairPriority(false)
        end
      end,
      get = function()
        return CM.DB.char.crosshairPriority
      end,
      disabled = function()
        return CM.DB.char.reticleTargeting ~= true or ON_RETAIL_CLIENT == false
      end
    },
    friendlyTargetingInCombat = {
      type = "toggle",
      name = "Disable Friendly Targeting In Combat |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nTemporaroly disables friendly targeting while |cffffd700in combat|r.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.5,
      order = 6,
      set = function(_, value)
        CM.DB.char.friendlyTargetingInCombat = value
      end,
      get = function()
        return CM.DB.char.friendlyTargetingInCombat
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting or not CM.DB.char.friendlyTargeting
      end
    },
    spacing = Spacing("full", 6.1),
    CrosshairGroup = CrosshairGroup,
    spacing3 = Spacing("full", 7.1),
    devnote = {
      type = "group",
      name = "|cffffd700Developer Note|r",
      order = 8,
      inline = true,
      args = {
        crosshairNote = {
          type = "description",
          name = "|cff909090While |cffE52B50Mouse Look|r is active, the |cffcfcfcfCursor|r will be moved to the position of the |cff00FFFFCrosshair|r and hidden, allowing it to reliably respond to |cffB47EDE@mouseover|r and |cffB47EDE@cursor|r macros.|r \n|cffcfcfcfExample macros have been added to your account-wide macros list (Esc > Macros) for users who'd like more control over target acquisition through either Soft-Locking or Hard-Locking Targeting.|r",
          order = 1
        }
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                MOUSE CLICK CASTING                                --
---------------------------------------------------------------------------------------
local ClickCastingOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  childGroups = "tab",
  args = {
    header = Header("clicks", 1),
    description = Description("clicks", 2),
    globalKeybind = {
      type = "toggle",
      name = "Use Account-Wide Click Bindings |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nUse your account-wide shared Combat Mode keybinds on this character.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 3,
      set = function(_, value)
        CM.DB.char.useGlobalBindings = value
        CM.OverrideDefaultButtons()
      end,
      get = function()
        return CM.DB.char.useGlobalBindings
      end
    },
    spacing = Spacing("full", 4),
    unmodifiedGroup = GetButtonOverrideGroup(nil, 5),
    shiftGroup = GetButtonOverrideGroup("shift", 6),
    ctrlGroup = GetButtonOverrideGroup("ctrl", 7),
    altGroup = GetButtonOverrideGroup("alt", 8)
  }
}

---------------------------------------------------------------------------------------
--                               ADVANCED CONFIG PANEL                               --
---------------------------------------------------------------------------------------
local AdvancedConfigOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("advanced", 1),
    description = Description("advanced", 2),
    customCondition = {
      type = "group",
      name = "",
      order = 3,
      inline = true,
      args = {
        customConditionCode = {
          type = "input",
          name = "Custom Condition:",
          order = 1,
          multiline = 6,
          width = "full",
          set = function(_, input)
            CM.DB.global.customCondition = input
          end,
          get = function()
            return CM.DB.global.customCondition
          end
        },
        spacing5 = Spacing("full", 2),
        devnote = {
          type = "group",
          name = "|cffffd700Developer Note|r",
          order = 3,
          inline = true,
          args = {
            crosshairNote = {
              type = "description",
              name = "|cff909090Knowing the basics of |cff69ccf0Lua|r and the |cffffd700WoW API|r is essential for using custom conditions.|r \n\n|cffFF5050Combat Mode's authors are not responsible for custom code issues and are not obligated to provide users any support for it.|r",
              order = 1
            },
            wowpediaApi = {
              name = "You can find all available functions and how to use them here:",
              desc = "warcraft.wiki.gg/wiki/World_of_Warcraft_API",
              type = "input",
              width = 2.2,
              order = 3,
              get = function()
                return "warcraft.wiki.gg/wiki/World_of_Warcraft_API"
              end
            }
          }
        }
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                              SETTINGS CATEGORY TREE                               --
---------------------------------------------------------------------------------------
-- Header
CM.Config.AboutOptions = AboutOptions

-- Options
CM.Config.OptionCategories = {
  {
    id = "CombatMode_FreeLook",
    name = "|cffE52B50 • Mouse Look|r",
    table = FreeLookOptions
  },
  {
    id = "CombatMode_ReticleTargeting",
    name = "|cff00FFFF • Reticle Targeting|r",
    table = ReticleTargetingOptions
  },
  {
    id = "CombatMode_ClickCasting",
    name = "|cffB47EDC • Click Casting|r",
    table = ClickCastingOptions
  },
  {
    id = "CombatMode_Advanced",
    name = "|cffffffff • Advanced|r",
    table = AdvancedConfigOptions
  }
}
