---------------------------------------------------------------------------------------
--                                CONFIG/OPTIONS PANEL                               --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- CACHING GLOBAL VARIABLES
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local strtrim = _G.strtrim

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
      name = "|cffffd700AUTO CURSOR UNLOCK|r",
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
    radial = {
      type = "header",
      name = "|cff00FF7FHEALING RADIAL|r",
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
    radial = {
      type = "description",
      name = "\nA radial menu for quickly casting helpful spells at party members. While |cffE52B50Mouse Look|r is active and you're in a party, hold a mouse button to display the radial, flick toward your target, and release to cast.\n\n",
      fontSize = "medium",
      order = order
    },
    advanced = {
      type = "description",
      name = "\nCreate your own custom condition that forces a |cffffd700Cursor Unlock|r by entering a chunk of Lua code that at the end evaluates to |cff00FF7FTrue|r if the cursor should be freed, |cffE52B50False|r otherwise.\n\n|cff909090For example, this would unlock the cursor while standing still but not while mounted: \n\n|cff69ccf0local isStill = GetUnitSpeed('player') == 0 \nlocal onMount = IsMounted()\nreturn not onMount and isStill|r\n\n",
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
        desc = "Enables the use of the " .. button1Name .. " casting override while in |cffE52B50Mouse Look|r mode.",
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
          return not CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].enabled or
                   CM.DB[CM.GetBindingsLocation()].bindings[button1Settings].value ~= "MACRO"
        end,
        validate = function(_, value)
          if not CM.MacroExists(value) then
            CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName = ""
            return CM.METADATA["TITLE"] .. "\n\n|cffcfcfcfNo macro found with that name.|r"
          else
            return true
          end
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
        desc = "Enable the use of the " .. button2Name .. " casting override while in |cffE52B50Mouse Look|r mode.",
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
          return not CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].enabled or
                   CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].value ~= "MACRO"
        end,
        validate = function(_, value)
          if not CM.MacroExists(value) then
            CM.DB[CM.GetBindingsLocation()].bindings[button2Settings].macroName = ""
            return CM.METADATA["TITLE"] .. "\n\n|cffcfcfcfNo macro found with that name.|r"
          else
            return true
          end
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
            name = "|cff909090To directly assign a |cffcfcfcfMacro|r as a |cffB47EDEClick Casting Action|r, select |cff69ccf0Run MACRO|r from the drop-down list and type its name in the input.|r",
            order = 4
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
    spacing = Spacing(1.6, 0.1),
    silenceAlertsToggle = {
      type = "toggle",
      name = "Silence Alerts",
      desc = "Stops Combat Mode from printing alert messages in the chat window after loading screens.",
      width = 0.7,
      set = function(_, value)
        CM.DB.global.silenceAlerts = value
      end,
      get = function()
        return CM.DB.global.silenceAlerts
      end,
      order = 0.2
    },
    debugModeToggle = {
      type = "toggle",
      name = "Debug Mode",
      desc = "Enables the printing of state logs in the chat window to assist with development.",
      width = 0.7,
      set = function(_, value)
        CM.DB.global.debugMode = value
      end,
      get = function()
        return CM.DB.global.debugMode
      end,
      order = 0.3
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
      name = "|cff909090• |cffE52B50Mouse Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of |cffcfcfcf@mouseover|r and |cffcfcfcf@cursor|r macro decorators in combination with the |cff00FFFFCrosshair|r. \n• |cffB47EDEMouse Click Casting|r - When Mouse Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cffffd700Cursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc. \n• |cff00FF7FHealing Radial|r - Radial menu for quickly casting helpful spells at party members.\n\n",
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
      width = 2,
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
    actionCamMouselookDisable = {
      type = "toggle",
      name = "Disable |cffffd700Action Camera|r with |cffE52B50Mouse Look|r",
      desc = "Disable |cffffd700Action Camera|r features when toggling |cffE52B50Mouse Look|r off. \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.6,
      order = 1.1,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to Combat Mode's |cffffd700Action Camera|r Preset.|r \n\n|cffffd700Proceed?|r",
      confirm = true,
      set = function(_, value)
        CM.DB.global.actionCamMouselookDisable = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.global.actionCamMouselookDisable
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end
    },
    spacing = Spacing("full", 1.2),
    shoulderOffset = {
      type = "range",
      name = "Camera Over Shoulder Offset |cff3B73FF©|r |cffE37527•|r",
      desc = "|cff3B73FF© Character-based option|r \n\nHorizontally offsets the camera to the left or right of your character while the |cffffd700Action Camera Preset|r is enabled. \n\n|cffE52B50Requires |cffffd700Motion Sickness|r under Acessibility options to be turned off.|r \n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cff00FF7F1.0|r",
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
      name = "|cffffd700Toggle / Hold - |cffE52B50Mouse Look|r|r",
      desc = "Tap to toggle the |cffE52B50Mouse Look|r camera |cff00FF7FOn|r or |cffE52B50Off|r.\n\nHold to temporarily deactivate it — releasing re-engages it.",
      width = 1.15,
      order = 3,
      set = function(_, key)
        local oldKey = (GetBindingKey("Combat Mode - Mouse Look"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "Combat Mode - Mouse Look")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("Combat Mode - Mouse Look"))
      end
    },
    spacing0 = Spacing(0.1, 3.1),
    toggleFocusTarget = {
      type = "keybinding",
      name = "|cffffd700Toggle - |cffcc00ffTarget Lock|r|r",
      desc = "Tap to |cffcc00ffTarget Lock|r (Focus) your current target. Tap again to unlock it.\n\nWhile |cffcc00ffTarget Lock|r is active, |cff00FFFFReticle Targeting|r will be stopped from swapping off your current target.\n\n|cff909090Control of which type of unit can be locked is determined by the |cff00FFFFReticle Targeting|r settings.|r",
      width = 1.15,
      order = 4,
      set = function(_, key)
        local oldKey = (GetBindingKey("Combat Mode - Toggle Focus Target"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "Combat Mode - Toggle Focus Target")
        SaveBindings(GetCurrentBindingSet())
        -- Apply override binding to click secure button
        CM.ApplyToggleFocusTargetBinding()
      end,
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end
    },
    spacing1 = Spacing(0.1, 4.1),
    interact = {
      type = "keybinding",
      name = "|cffffd700Interact With Target|r",
      desc = "Press to interact with crosshair target when in range. \n\n|cff909090This particular targeting arc is intentionally wider to facilitate interaction with NPCs surrounded by players.|r",
      width = 1.15,
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
      desc = "Hides the tooltip generated by the crosshair while |cffE52B50Mouse Look|r is active.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
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
      name = "Enable |cffffd700Auto Cursor Unlock|r",
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
      desc = "Keeps the cursor unlocked while a vendor mounts is being used.\n\n|cffffd700Vendor Mounts:|r \n|cff909090Grand Expedition Yak\nTraveler's Tundra Mammoth\nMighty Caravan Brutosaur\nTrader's Gilded Brutosaur\nGrizzly Hills Packmaster|r \n\n|cffffd700Default:|r |cffE52B50Off|r",
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
      desc = "Expand the list of Blizzard panels or |cffE37527AddOn|r frames that trigger a |cffffd700Cursor Unlock.|r \n\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: |cffcfcfcfAddonName + Frame|r.\nEx: LootFrame|r\n\n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
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
  order = 8,
  inline = true,
  args = {
    crosshair = {
      type = "toggle",
      name = "Show Crosshair",
      desc = "Places a dynamic crosshair marker in the center of the screen to assist with |cff00FFFFReticle Targeting|r.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.75,
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
    spacing = Spacing(0.15, 1.1),
    crosshairMounted = {
      type = "toggle",
      name = "Hide Crosshair While Mounted",
      desc = "Hides the crosshair while mounted.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
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
      width = 1.75,
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
    spacing1 = Spacing(0.15, 3.1),
    spacingTemp = Spacing(1.75, 3.2),
    crosshairAppearance = {
      name = "Crosshair Appearance",
      desc = "Select the appearance of the crosshair texture.",
      type = "select",
      width = 1.4,
      order = 5,
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
    spacing3 = Spacing(0.1, 5.1),
    crosshairPreview = {
      type = "description",
      order = 6,
      name = "",
      width = 0.25,
      image = function()
        return CM.DB.global.crosshairAppearance.Base
      end,
      imageWidth = 42,
      imageHeight = 42
    },
    spacing4 = Spacing(0.15, 6.1),
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
    spacing5 = Spacing("full", 7.1),
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
    spacing6 = Spacing(0.15, 8.1),
    crosshairY = {
      type = "range",
      name = "Crosshair Vertical Position",
      desc = "Adjusts the vertical position of the crosshair. \n\n|cffffd700Default:|r |cff00FF7F100|r",
      min = -200,
      max = 200,
      softMin = -200,
      softMax = 200,
      step = 10,
      width = 1.75,
      order = 9,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairY = value
        if value then
          CM.CreateCrosshair()
        end
        -- Update healing radial position so it stays aligned with crosshair without reload
        if CM.HealingRadial and CM.HealingRadial.UpdateMainFramePosition then
          CM.HealingRadial.UpdateMainFramePosition()
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
      desc = "|cff3B73FF© Character-based option|r\n\nConfigures Blizzard's |cffffd700Action Targeting|r feature to be more precise and responsive. \n\nWraps actions with |cffB47EDEtargeting macro conditionals|r that select the unit under the crosshair when using an ability. \n\n|cffFF5050Be aware that this will override all CVar values related to SoftTarget.|r \n\n|cff909090Uncheck to reset them to their default values.|r\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.75,
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
    spacing0 = Spacing(0.25, 3.1),
    reticleTargetingEnemyOnly = {
      type = "toggle",
      name = "Only Allow Reticle To Target Enemies |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nOnly allow |cff00FFFFReticle Targeting|r to select hostile units, ignoring friendly NPCs and Players.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.75,
      order = 4,
      confirm = true,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.reticleTargetingEnemyOnly = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.reticleTargetingEnemyOnly
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    macroInjectionClickCastOnly = {
      type = "toggle",
      name = "Limit Reticle Targeting To |cffB47EDEClick Casting|r Actions |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nWhen enabled, the reticle unit targeting and ground-targeted macro injection apply only to |cffB47EDEClick Casting|r bindings. All other action bar slots will not have the targeting macro injection applied.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
      order = 5,
      confirm = true,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.macroInjectionClickCastOnly = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.macroInjectionClickCastOnly
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    spacing1= Spacing(0.25, 5.1),
    focusCurrentTargetNotCrosshair = {
      type = "toggle",
      name = "|cffcc00ffTarget Lock|r Selected Target |cffE52B50Not|r The Crosshair |cff3B73FF©|r",
      desc = "|cff3B73FF© Character-based option|r\n\nWhen enabled, |cffcc00ffTarget Lock|r will lock onto your currently selected target rather than the unit under your crosshair.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.75,
      order = 5.2,
      confirm = true,
      confirmText = CM.METADATA["TITLE"] ..
        "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
      set = function(_, value)
        CM.DB.char.focusCurrentTargetNotCrosshair = value
        ReloadUI()
      end,
      get = function()
        return CM.DB.char.focusCurrentTargetNotCrosshair
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    spacing = Spacing("full", 5.3),
    excludeFromTargetingSpells = {
      name = "Spells to |cffE52B50exclude|r from |cff00FFFFReticle Targeting|r:",
      desc = "Spells that you |cffE52B50DON'T|r want the |cffB47EDEtargeting macro conditionals|r applied to, thus not being able to select the crosshair unit.\n\n|cff909090Ex: Shield Wall, Ice Block, Divine Shield.|r\n\n|cffffd700Separate names with commas.|r\n|cffffd700Names are case insensitive.|r",
      type = "input",
      multiline = 6,
      width = 1.75,
      order = 6,
      set = function(_, value)
        CM.DB.char.excludeFromTargetingSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then CM.RefreshClickCastMacros() end
      end,
      get = function()
        return CM.DB.char.excludeFromTargetingSpells or ""
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    spacing2 = Spacing(0.25, 6.1),
    castAtCursorSpells = {
      name = "|cff00ff00Ground-targeted|r spells to be cast at the |cff00FFFFReticle|r:",
      desc = "|cff00ff00Ground-targeted|r abilities that you want cast with the |cffB47EDE@cursor|r modifier directly at the position of the crosshair without requiring the |cff00ff00green circle|r to be placed.\n\n|cff909090Ex: Heroic Leap, Shift, Blizzard.|r\n\n|cffffd700Separate names with commas.|r \n|cffffd700Names are case insensitive.|r",
      type = "input",
      multiline = 6,
      width = 1.75,
      order = 7,
      set = function(_, value)
        CM.DB.char.castAtCursorSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then CM.RefreshClickCastMacros() end
      end,
      get = function()
        return CM.DB.char.castAtCursorSpells or ""
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end
    },
    spacing3 = Spacing("full", 7.1),
    CrosshairGroup = CrosshairGroup,
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
--                               HEALING RADIAL CONFIG                               --
---------------------------------------------------------------------------------------
local HealingRadialOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("radial", 1),
    description = Description("radial", 2),
    enabled = {
      type = "toggle",
      name = "Enable |cff00FF7FHealing Radial|r",
      desc = "Enables a radial menu for quickly casting helpful spells at party members. While |cffE52B50Mouse Look|r is active and you're in a party, hold a mouse button to display the radial, flick toward your target, and release to cast.\n\n|cffffd700Default:|r |cffE52B50Off|r",
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
      end,
    },
    keybind = {
      type = "keybinding",
      name = "|cffffd700Toggle / Hold - Radial|r",
      desc = "Tap to toggle the |cff00FF7FHealing Radial|r menu |cff00FF7FOn|r or |cffE52B50Off|r.\n\nHold to temporarily display it — releasing closes it.",
      width = 1.25,
      order = 4,
      set = function(_, key)
        local oldKey = (GetBindingKey("Combat Mode - Healing Radial"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "Combat Mode - Healing Radial")
        SaveBindings(GetCurrentBindingSet())
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
            if CM.HealingRadial and CM.HealingRadial.UpdateSlicePositionsAndSizes then
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
          desc = "Scale factor for slice elements (role icon, name, health bar). Hover increases by 10%.\n\n|cffffd700Default:|r |cff00FF7F1.0|r (100%)",
          min = 0.5,
          max = 1.5,
          step = 0.1,
          width = 1.75,
          order = 2,
          set = function(_, value)
            CM.DB.global.healingRadial.sliceSize = value
            if CM.HealingRadial and CM.HealingRadial.UpdateSlicePositionsAndSizes then
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
        },
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
          name = "|cff909090Party members are automatically positioned by role:|r\n\n|cffcfcfcf• |cff00d1ffTank|r at 12 o'clock (top)\n• |cff00ff00Healer|r at 7 o'clock (bottom-left)\n• |cffff6060DPS|r fill remaining positions\n\nYour character is included in the radial at your role's position.|r",
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
          name = "|cff909090The |cff00FF7FHealing Radial|r uses the same spell assignments as |cffB47EDCClick Casting|r. Configure which spells are bound to each mouse button in the Click Casting tab.|r\n\n|cffFF5050Note:|r Party assignments can only be updated outside of combat due to WoW API restrictions.",
          order = 1
        }
      }
    }
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
          multiline = 10,
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
              name = "You can find the documentation for the WoW API here:",
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
    id = "CombatMode_HealingRadial",
    name = "|cff00FF7F • Healing Radial|r",
    table = HealingRadialOptions
  },
  {
    id = "CombatMode_Advanced",
    name = "|cffffffff • Advanced|r",
    table = AdvancedConfigOptions
  }
}
