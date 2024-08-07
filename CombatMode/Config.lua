---------------------------------------------------------------------------------------
--                                CONFIG/OPTIONS PANEL                               --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- CACHING GLOBAL VARIABLES
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetBindingKey = _G.GetBindingKey
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetCVar = _G.SetCVar
local SetModifiedClick = _G.SetModifiedClick

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

CM.Config = {}

---------------------------------------------------------------------------------------
--                           BUTTON OVERRIDE GROUP ASSEMBLER                         --
---------------------------------------------------------------------------------------
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
        name = "",
        width = 0.2,
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
      button1SidePadding = {
        type = "description",
        name = " ",
        width = 0.2,
        order = 1.2
      },
      button1macro = {
        name = "Custom Action",
        desc = "Enter the name of the action you wish to be ran here.",
        type = "input",
        width = 1.5,
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
        name = "",
        width = 0.2,
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
      button2SidePadding = {
        type = "description",
        name = " ",
        width = 0.2,
        order = 2.2
      },
      button2macro = {
        name = "Custom Action",
        desc = "Enter the name of the action you wish to be ran here.",
        type = "input",
        width = 1.5,
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
      spacing = {
        type = "description",
        name = " ",
        width = "full",
        order = 3
      },
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
            width = 1.5,
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
      confirmText = "Resetting Combat Mode options will force a UI Reload. Proceed?",
      width = 0.7,
      func = function()
        CM:OnResetDB()
      end,
      confirm = true,
      order = 0
    },
    resetDebugSpacing = {
      type = "description",
      name = " ",
      width = 2.2,
      order = 0.1
    },
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
    header = {
      type = "header",
      name = "|cffffffffABOUT|r",
      order = 1
    },
    aboutPaddingTop = {
      type = "description",
      name = " ",
      width = "full",
      order = 1.1
    },
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
    aboutPaddingBottom = {
      type = "description",
      name = " ",
      width = "full",
      order = 1.4
    },
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
      name = "|cff909090• |cffE52B50Free Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of |cffcfcfcf@mouseover|r and |cffcfcfcf@cursor|r macro decorators in combination with the |cff00FFFFCrosshair|r. \n• |cffB47EDEMouse Click Casting|r - When Free Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cff00FF7FCursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc.\n\n",
      order = 3
    },
    versionNumber = {
      type = "description",
      name = "|cffffffffVersion:|r " .. "|cff00ff00" .. CM.METADATA["VERSION"] .. "|r\n\n",
      order = 3.2
    },
    contributorsList = {
      type = "description",
      name = "|cffffffffCreated by:|r " .. "|cffcfcfcf" .. CM.METADATA["AUTHOR"] .. "|r\n\n",
      order = 3.3
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
    curseDiscordSpacing = {
      type = "description",
      name = " ",
      width = 0.4,
      order = 4.1
    },
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
    linksPaddingBottom = {
      type = "description",
      name = " ",
      width = "full",
      order = 5.1
    }
  }
}

---------------------------------------------------------------------------------------
--                                     FREE LOOK                                     --
---------------------------------------------------------------------------------------
local FreeLookOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = {
      type = "header",
      name = "|cffE52B50FREE LOOK|r",
      order = 1
    },
    description = {
      type = "description",
      name = "\nSet keybinds for the Free Look camera. You can use Toggle and Press & Hold together by binding them to separate keys.\n\n",
      fontSize = "medium",
      order = 2
    },
    toggle = {
      type = "keybinding",
      name = "|cffffd700Toggle|r",
      desc = "Toggles the Free Look camera ON or OFF.",
      width = 1.25,
      order = 3,
      set = function(_, key)
        local oldKey = (GetBindingKey("Combat Mode Toggle"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "Combat Mode Toggle")
        SetBinding("MOVEANDSTEER")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("Combat Mode Toggle"))
      end
    },
    hold = {
      type = "keybinding",
      name = "|cffffd700Press & Hold|r",
      desc = "Hold to temporarily deactivate the Free Look camera.",
      width = 1.25,
      order = 4,
      set = function(_, key)
        local oldKey = (GetBindingKey("(Hold) Switch Mode"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "(Hold) Switch Mode")
        SetBinding("MOVEANDSTEER")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("(Hold) Switch Mode"))
      end
    },
    interact = {
      type = "keybinding",
      name = "|cffffd700Interact With Target|r",
      desc = "Press to interact with crosshair target when in range.",
      width = 1.25,
      order = 5,
      set = function(_, key)
        local oldKey = (GetBindingKey("INTERACTMOUSEOVER"))
        if oldKey then
          SetBinding(oldKey)
        end
        SetBinding(key, "INTERACTMOUSEOVER")
        SaveBindings(GetCurrentBindingSet())
      end,
      get = function()
        return (GetBindingKey("INTERACTMOUSEOVER"))
      end
    },
    spacing = {
      type = "description",
      name = " ",
      width = "full",
      order = 5.1
    },
    spacing2 = {
      type = "description",
      name = " ",
      width = "full",
      order = 5.2
    },
    ---------------------------------------------------------------------------------------
    --                                   CURSOR UNLOCK                                   --
    ---------------------------------------------------------------------------------------
    header2 = {
      type = "header",
      name = "|cff00FF7FCURSOR UNLOCK|r",
      order = 6
    },
    description2 = {
      type = "description",
      name = "\nSelect whether Combat Mode should automatically disable Free Look and release the cursor when specific frames are visible (Bag, Map, Quest, etc), and re-enable upon closing them.\n\n",
      fontSize = "medium",
      order = 7
    },
    cursorUnlock = {
      type = "toggle",
      name = "Automatic Cursor Unlock",
      desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = "full",
      order = 8,
      set = function(_, value)
        CM.DB.global.frameWatching = value
      end,
      get = function()
        return CM.DB.global.frameWatching
      end
    },
    mountCheck = {
      type = "toggle",
      name = "Unlock While On Vendor Mount",
      desc = "Keeps the cursor unlocked while a vendor mounts is being used.\n|cffffd700Mounts:|r \n|cffcfcfcfGrand Expedition Yak\nTraveler's Tundra Mammoth\nMighty Caravan Brutosaur|r \n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 9,
      set = function(_, value)
        CM.DB.global.mountCheck = value
      end,
      get = function()
        return CM.DB.global.mountCheck
      end
    },
    spacing3 = {
      type = "description",
      name = " ",
      width = "full",
      order = 9.1
    },
    watchlist = {
      name = "Frame Watchlist",
      desc = "Additional Blizzard frames or other AddOns that you'd like Combat Mode to watch for.\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: |cffcfcfcfAddonName + Frame|r.|r \n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
      type = "input",
      multiline = true,
      width = "full",
      order = 10,
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
local ReticleTargetingOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = {
      type = "header",
      name = "|cff00FFFFRETICLE TARGETING|r",
      order = 1
    },
    description = {
      type = "description",
      name = "\nConfigures Blizzard's Action Targeting feature from the default dynamic & tab targeting hybrid to something truly action-oriented, where the crosshair dictates target selection.\n\n",
      fontSize = "medium",
      order = 2
    },
    reticleTargeting = {
      type = "toggle",
      name = "Configure Reticle Targeting |cff3B73FF(c)|r",
      desc = "|cff3B73FFCharacter-based option|r\nConfigures Blizzard's Action Targeting feature to be more action-oriented and responsive. \n|cffFF5050Be aware that this will override all CVar values related to SoftTarget.|r \n|cffcfcfcfUncheck to reset them to their default values.|r\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = "full",
      order = 3,
      set = function(_, value)
        CM.DB.char.reticleTargeting = value
        if value then
          CM.LoadCVars("combatmode")
        else
          CM.LoadCVars("blizzard")
        end
      end,
      get = function()
        return CM.DB.char.reticleTargeting
      end
    },
    crosshairPriority = {
      type = "toggle",
      name = "Always Prioritize Crosshair Target |cff3B73FF(c)|r",
      desc = "|cff3B73FFCharacter-based option|r\nGives the |cff00FFFFCrosshair|r the highest priority when determining which unit the spell will be cast on, |cffFF5050ignoring even manually selected targets in favor of the unit at your crosshair.|r \n|cffcfcfcfDisabling this will prevent the crosshair from swapping off hard-locked targets.|r\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = "full",
      order = 4,
      set = function(_, value)
        CM.DB.char.crosshairPriority = value
        if value then
          SetCVar("enableMouseoverCast", 1)
          SetModifiedClick("MOUSEOVERCAST", "NONE")
          SaveBindings(GetCurrentBindingSet())
        else
          SetCVar("enableMouseoverCast", 0)
        end
      end,
      get = function()
        return CM.DB.char.crosshairPriority
      end
    },
    crosshair = {
      type = "toggle",
      name = "Show Crosshair",
      desc = "Places a dynamic crosshair marker in the center of the screen to assist with Reticle Targeting.\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = "full",
      order = 5,
      set = function(_, value)
        CM.DB.global.crosshair = value
        if value then
          CM.ShowCrosshair()
        else
          CM.HideCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshair
      end
    },
    crosshairMounted = {
      type = "toggle",
      name = "Hide Crosshair While Mounted",
      desc = "Hides the crosshair while mounted.\n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 6,
      set = function(_, value)
        CM.DB.global.crosshairMounted = value
      end,
      get = function()
        return CM.DB.global.crosshairMounted
      end
    },
    spacing = {
      type = "description",
      name = " ",
      width = "full",
      order = 6.1
    },
    crosshairAppearance = {
      name = "Crosshair Appearance",
      desc = "Select the appearance of the crosshair texture.",
      type = "select",
      width = "full",
      order = 7,
      values = CM.Constants.CrosshairAppearanceSelectValues,
      set = function(_, value)
        CM.DB.global.crosshairAppearance = CM.Constants.CrosshairTextureObj[value]
        if value then
          CM.UpdateCrosshair()
          CM.ShowCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairAppearance.Name
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    spacing2 = {
      type = "description",
      name = " ",
      width = "full",
      order = 8
    },
    crosshairSize = {
      type = "range",
      name = "Crosshair Size",
      desc = "Adjusts the size of the crosshair in 16-pixel increments.",
      min = 16,
      max = 128,
      softMin = 16,
      softMax = 128,
      step = 16,
      width = "full",
      order = 9,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairSize = value
        if value then
          CM.UpdateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairSize
      end
    },
    spacing3 = {
      type = "description",
      name = " ",
      width = "full",
      order = 10
    },
    crosshairAlpha = {
      type = "range",
      name = "Crosshair Opacity",
      desc = "Adjusts the opacity of the crosshair.",
      min = 0.1,
      max = 1.0,
      softMin = 0.1,
      softMax = 1.0,
      step = 0.1,
      width = "full",
      order = 11,
      isPercent = true,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairOpacity = value
        if value then
          CM.UpdateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairOpacity
      end
    },
    spacing4 = {
      type = "description",
      name = " ",
      width = "full",
      order = 12
    },
    crosshairY = {
      type = "range",
      name = "Crosshair Vertical Position",
      desc = "Adjusts the vertical position of the crosshair.",
      min = -500,
      max = 500,
      softMin = -500,
      softMax = 500,
      step = 10,
      width = "full",
      order = 13,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end,
      set = function(_, value)
        CM.DB.global.crosshairY = value
        if value then
          CM.UpdateCrosshair()
        end
      end,
      get = function()
        return CM.DB.global.crosshairY
      end
    },
    spacing5 = {
      type = "description",
      name = " ",
      width = "full",
      order = 14
    },
    devnote = {
      type = "group",
      name = "|cffffd700Developer Note|r",
      order = 15,
      inline = true,
      args = {
        crosshairNote = {
          type = "description",
          name = "|cff909090When |cffcfcfcfReticle Targeting|r is enabled, your cursor will be moved to the position of the |cff00FFFFCrosshair|r and hidden, thus allowing it to be used in combination with |cffB47EDE@mouseover|r and |cffB47EDE@cursor|r macros.|r \n|cffcfcfcfExample macros have been added to your account-wide macros list (Esc > Macros) for users who'd like more control over target acquisition through either Soft-Locking or Hard-Locking Targeting.|r",
          order = 15
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
    header = {
      type = "header",
      name = "|cffB47EDCCLICK CASTING|r",
      order = 1
    },
    description = {
      type = "description",
      name = "\nSelect which actions are fired when Left and Right clicking as well as their respective Shift, CTRL and ALT modified presses.\n\n",
      fontSize = "medium",
      order = 2
    },
    globalKeybind = {
      type = "toggle",
      name = "Use Account-Wide Click Bindings |cff3B73FF(c)|r",
      desc = "|cff3B73FFCharacter-based option|r\nUse your account-wide shared keybinds on this character.\n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 6,
      set = function(_, value)
        CM.DB.char.useGlobalBindings = value
        CM.OverrideDefaultButtons()
      end,
      get = function()
        return CM.DB.char.useGlobalBindings
      end
    },
    spacing = {
      type = "description",
      name = " ",
      width = "full",
      order = 6.1
    },
    unmodifiedGroup = GetButtonOverrideGroup(nil, 7),
    shiftGroup = GetButtonOverrideGroup("shift", 8),
    ctrlGroup = GetButtonOverrideGroup("ctrl", 9),
    altGroup = GetButtonOverrideGroup("alt", 10)
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
    header = {
      type = "header",
      name = "|cffffffffADVANCED|r",
      order = 0.9
    },
    customCondition = {
      type = "group",
      name = "",
      order = 1,
      inline = true,
      args = {
        customConditionDescription = {
          type = "description",
          name = "\nCreate your own conditions for the |cff00FF7FAutomatic Cursor Unlock|r here by entering a chunk of Lua code that returns true if the cursor should be unlocked, false otherwise. If your condition isn't working, toggle on Debug Mode to get error messages printed in the chat for easier troubleshooting.\n\n",
          order = 1
        },
        customConditionExample = {
          type = "description",
          name = "For example if you wish to unlock the cursor when the player is standing still, enter:\n|cffcfcfcfreturn GetUnitSpeed(\"player\") == 0|r",
          order = 2
        },
        customConditionWarning = {
          type = "description",
          name = "\n|cffFF5050Knowing the basics of Lua and the WoW API is essential for using custom conditions. Combat Mode's authors are not responsible for custom code issues and are not obligated to provide users any support for it.|r",
          order = 3
        },
        customConditionCode = {
          type = "input",
          name = "Enter your Lua code here:",
          order = 4,
          multiline = 10,
          width = "full",
          set = function(_, input)
            CM.DB.global.customCondition = input
          end,
          get = function()
            return CM.DB.global.customCondition
          end
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
    name = "|cffE52B50Free Look|r",
    table = FreeLookOptions
  },
  {
    id = "CombatMode_ReticleTargeting",
    name = "|cff00FFFFReticle Targeting|r",
    table = ReticleTargetingOptions
  },
  {
    id = "CombatMode_ClickCasting",
    name = "|cffB47EDCClick Casting|r",
    table = ClickCastingOptions
  },
  {
    id = "CombatMode_Advanced",
    name = "|cffffffffAdvanced|r",
    table = AdvancedConfigOptions
  }
}
