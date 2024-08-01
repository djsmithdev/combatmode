-- CONFIGURATION/OPTIONS PANEL
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- CACHING GLOBAL VARIABLES
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetBindingKey = _G.GetBindingKey
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetCVar = _G.SetCVar

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

CM.Config = {}

local function GetButtonOverrideGroup(modifier, groupOrder)
  local button1Settings, button2Settings, groupName, button1Name, button2Name
  if modifier then
    button1Settings = modifier .. "button1"
    button2Settings = modifier .. "button2"

    local capitalisedModifier = (modifier:gsub("^%l", string.upper))
    groupName = capitalisedModifier .. "-modified Clicks"
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
    name = "|cffB47EDE" .. groupName .. "|r",
    inline = true,
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
        desc = button1Name,
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
        name = button1Name .. " Custom Action",
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
        desc = button2Name,
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
        name = button2Name .. " Custom Action",
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
      }
    }
  }
end

-- BASE CONFIG PANEL
CM.Config.ConfigOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    resetButton = {
      type = "execute",
      name = "Default",
      desc = "Resets Combat Mode settings to its default values.",
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
    -- LOGO & ABOUT
    aboutHeader = {
      type = "header",
      name = "",
      order = 1
    },
    logoPaddingTop = {
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
    aboutDescriptionPaddingBottom = {
      type = "description",
      name = " ",
      width = "full",
      order = 1.4
    },
    -- FEATURES
    featuresHeader = {
      type = "description",
      name = "|cffffd700Features:|r",
      order = 2,
      fontSize = "medium"
    },
    featuresList = {
      type = "description",
      name = "|cff909090• |cffE52B50Free Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of |cffcfcfcf@mouseover|r and |cffcfcfcf@cursor|r macro decorators in combination with the crosshairs. \n• Optional adjustable dynamic |cff00FFFFCrosshair|r marker to assist with Reticle Targeting. \n• |cffB47EDEMouse Button Keybinds|r - When Free Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cff00FF7FCursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc.",
      order = 3
    },
    featuresListPaddingBottom = {
      type = "description",
      name = " ",
      width = "full",
      order = 3.1
    },
    versionNumber = {
      type = "description",
      name = "|cffffffffVersion:|r " .. "|cff00ff00" .. CM.METADATA["VERSION"] .. "|r",
      order = 3.2
    },
    contributorsList = {
      type = "description",
      name = "|cffffffffCreated by:|r " .. "|cffcfcfcf" .. CM.METADATA["AUTHOR"] .. "|r",
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
      width = 0.25,
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
    },
    -- CONFIGURATION
    configurationHeaderPaddingTop = {
      type = "description",
      name = " ",
      width = "full",
      order = 5.2
    },
    configurationHeader = {
      type = "header",
      name = "|cffffffffCONFIGURATION|r",
      order = 6
    },
    -- FREELOOK CAMERA
    freeLookCameraGroup = {
      type = "group",
      name = " ",
      inline = true,
      order = 7,
      args = {
        freelookKeybindHeader = {
          type = "header",
          name = "|cffE52B50Free Look Camera|r",
          order = 1
        },
        freelookKeybindHeaderPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 1.1
        },
        freelookKeybindDescription = {
          type = "description",
          name = "Set keybinds for the Free Look camera. You can use Toggle and Press & Hold together by binding them to separate keys.",
          fontSize = "medium",
          order = 2
        },
        freelookKeybindDescriptionBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 2.1
        },
        toggleLeftPadding = {
          type = "description",
          name = " ",
          width = 0.2,
          order = 2.2
        },
        toggle = {
          type = "keybinding",
          name = "|cffffd700Toggle|r",
          desc = "Toggles the Free Look camera ON or OFF.",
          width = 1,
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
        holdLeftPadding = {
          type = "description",
          name = " ",
          width = 0.1,
          order = 3.1
        },
        hold = {
          type = "keybinding",
          name = "|cffffd700Press & Hold|r",
          desc = "Hold to temporarily deactivate the Free Look camera.",
          width = 1,
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
        interactLeftPadding = {
          type = "description",
          name = " ",
          width = 0.1,
          order = 4.1
        },
        interact = {
          type = "keybinding",
          name = "|cffffd700Interact With Target|r",
          desc = "Press to interact with crosshair target when in range.",
          width = 1,
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
        interactRightPadding = {
          type = "description",
          name = " ",
          width = 0.2,
          order = 5.1
        }
      }
    },
    -- MOUSE BUTTON
    mouseButtonGroup = {
      type = "group",
      name = " ",
      inline = true,
      order = 8,
      args = {
        keybindHeader = {
          type = "header",
          name = "|cffB47EDEMouse Button Keybinds|r",
          order = 1
        },
        keybindHeaderPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 1.1
        },
        keybindGlobalOption = {
          type = "toggle",
          name = "Use Global Keybinds",
          desc = "Use your account-wide shared keybinds on this character.\n|cffffd700Default:|r |cffE52B50Off|r",
          width = "full",
          order = 1.5,
          set = function(_, value)
            CM.DB.char.useGlobalBindings = value
            CM.OverrideDefaultButtons()
          end,
          get = function()
            return CM.DB.char.useGlobalBindings
          end
        },
        keybindGlobalOptionPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 1.6
        },
        keybindDescription = {
          type = "description",
          name = "Select which actions are fired when Left and Right clicking as well as their respective Shift, CTRL and ALT modified presses.",
          fontSize = "medium",
          order = 2
        },
        keybindNote = {
          type = "description",
          name = "\n|cff909090To use an action not listed on the dropdown menu, select |cff69ccf0Custom Action|r and then type the exact name of the action you'd like to cast. \nTo use a macro as your |cff69ccf0Custom Action|r, type |cffcfcfcfMACRO My_Macro|r into the input, where |cffcfcfcfMy_Macro|r is the name of the macro you want to assign to that mouse click.|r",
          order = 3
        },
        wowwiki = {
          name = "You can find all available actions here:",
          desc = "warcraft.wiki.gg/wiki/BindingID",
          type = "input",
          width = 1.5,
          order = 3.1,
          get = function()
            return "warcraft.wiki.gg/wiki/BindingID"
          end
        },
        keybindDescriptionBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 3.2
        },
        unmodifiedGroup = GetButtonOverrideGroup(nil, 4),
        unmodifiedGroupBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 4.1
        },
        shiftGroup = GetButtonOverrideGroup("shift", 5),
        shiftGroupBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 5.1
        },
        ctrlGroup = GetButtonOverrideGroup("ctrl", 6),
        ctrlGroupBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 6.1
        },
        altGroup = GetButtonOverrideGroup("alt", 7)
      }
    },
    -- CURSOR UNLOCK
    cursorUnlockGroup = {
      type = "group",
      name = " ",
      order = 9,
      inline = true,
      args = {
        cursorUnlockHeader = {
          type = "header",
          name = "|cff00FF7FAutomatic Cursor Unlock|r",
          order = 1
        },
        cursorUnlockHeaderPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 1.1
        },
        cursorUnlockDescription = {
          type = "description",
          name = "Select whether Combat Mode should automatically disable Free Look and release the cursor when specific frames are visible (Bag, Map, Quest, etc), and re-enable upon closing them.",
          fontSize = "medium",
          order = 2
        },
        cursorUnlockWarning = {
          type = "description",
          name = "\n|cffFF5050Disabling this will also disable the Frame Watchlist.|r",
          order = 3
        },
        cursorUnlock = {
          type = "toggle",
          name = "Automatic Cursor Unlock",
          desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).\n|cffffd700Default:|r |cff00FF7FOn|r",
          width = "full",
          order = 4,
          set = function(_, value)
            CM.DB.global.frameWatching = value
          end,
          get = function()
            return CM.DB.global.frameWatching
          end
        },
        frameWatchingHeaderPaddingTop = {
          type = "description",
          name = " ",
          width = "full",
          order = 4.1
        },
        -- FRAME WATCHLIST
        watchlistInputGroup = {
          type = "group",
          name = "|cff00FF7FFrame Watchlist|r",
          order = 5,
          args = {
            watchlistDescription = {
              type = "description",
              name = "Additional Blizzard frames or other AddOns that you'd like Combat Mode to watch for.",
              fontSize = "medium",
              order = 1
            },
            watchlist = {
              name = "Frame Watchlist",
              desc = "Use command |cff69ccf0/fstack|r in chat to check frame names. \n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
              type = "input",
              multiline = true,
              width = "full",
              order = 2,
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
            },
            watchlistNote = {
              type = "description",
              name = "\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: |cffcfcfcfAddonName + Frame. Ex: PawnUIFrame|r.|r",
              order = 3
            }
          }
        }
      }
    },
    -- RETICLE TARGETING
    reticleTargetingGroup = {
      type = "group",
      name = " ",
      order = 10,
      inline = true,
      args = {
        reticleTargetingHeader = {
          type = "header",
          name = "|cff00FFFFReticle Targeting|r",
          order = 1
        },
        reticleTargetingHeaderPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 1.1
        },
        reticleTargetingDescription = {
          type = "description",
          name = "Configures Blizzard's Action Targeting feature from the default dynamic & tab targeting hybrid to something truly action-oriented, where the crosshair dictates target selection.",
          fontSize = "medium",
          order = 2
        },
        reticleTargetingDescriptionPaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 2.1
        },
        reticleTargeting = {
          type = "toggle",
          name = "Reticle Targeting",
          desc = "Configures Blizzard's Action Targeting feature to something action-oriented and responsive. \n|cffFF5050Be aware that this will override all CVar values related to SoftTarget.|r \n|cffcfcfcfUncheck to reset them to their default values.|r\n|cffffd700Default:|r |cff00FF7FOn|r",
          width = 1.0,
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
          name = "Always Prioritize Crosshair Target",
          desc = "Gives the |cff00FFFFCrosshair|r the highest priority when determining which unit the spell will be cast on, |cffFF5050ignoring even manually selected targets in favor of the unit at your crosshair.|r \n|cffcfcfcfDisabling this will prevent the crosshair from swapping off hard-locked targets.|r\n|cffffd700Default:|r |cff00FF7FOn|r",
          width = 1.4,
          order = 4,
          set = function(_, value)
            CM.DB.char.crosshairPriority = value
            if value then
              SetCVar("enableMouseoverCast", 1)
            else
              SetCVar("enableMouseoverCast", 0)
            end
          end,
          get = function()
            return CM.DB.char.crosshairPriority
          end
        },
        devNoteDescription = {
          type = "description",
          name = "|cffffd700Developer Note:|r \n|cff909090When |cffcfcfcfPrioritize Crosshair Target|r is enabled, Combat Mode will activate the |cffffd700Mouseover Cast|r option found in the interface menu, allowing spells to be cast directly on the unit under the |cff00FFFFCrosshair|r without needing to target it first.|r",
          order = 4.1
        },
        devNoteWarning = {
          type = "description",
          name = "\n|cffFF5050Make sure your |cffffd700Mouseover Cast|r hotkey modifier is set to |cffffd700None|r in the interface menu |cffcfcfcf(Options > Gameplay > Combat)|r otherwise |cffcfcfcfPrioritize Crosshair Target|r will only work while the selected key is being pressed.|r",
          order = 4.2
        },
        reticleTargetingNotePaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 4.3
        },
        -- CROSSHAIR
        crosshairGroup = {
          type = "group",
          name = "|cff00FFFFCrosshair|r",
          order = 5,
          args = {
            crosshairDescription = {
              type = "description",
              name = "Places a dynamic crosshair marker in the center of the screen to assist with Reticle Targeting.",
              fontSize = "medium",
              order = 1
            },
            crosshairDescriptionPaddingBottom = {
              type = "description",
              name = " ",
              width = "full",
              order = 1.1
            },
            crosshairNote = {
              type = "description",
              name = "|cffffd700Developer Note:|r \n|cff909090When |cffcfcfcfReticle Targeting|r is enabled, the |cff00FFFFCrosshair|r acts as a cursor, thus allowing it to be reliably used in combination with |cffB47EDE@mouseover|r and |cffB47EDE@cursor|r macros if you'd like a more fine-grained target selection.|r \n \n|cffcfcfcfExample macros have been added to your account-wide macros list (Esc > Macros) for users who prefer either Soft-Locking or Hard-Locking Targeting.|r \n \n|cffFF5050This feature has been programed with CombatMode's |cffcfcfcfReticle Targeting|r configuration in mind. Utilizing the |cff00FFFFCrosshair|r without it could lead to unintended behavior like unpredicatable targeting and improper crosshair reactivity.|r",
              order = 1.2
            },
            crosshair = {
              type = "toggle",
              name = "Show Crosshair",
              desc = "Places a dynamic crosshair marker in the center of the screen to assist with Reticle Targeting.\n|cffffd700Default:|r |cff00FF7FOn|r",
              width = 1.0,
              order = 2,
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
              name = "Hide While Mounted",
              desc = "Hides the crosshair while mounted.\n|cffffd700Default:|r |cff00FF7FOn|r",
              width = 1.4,
              order = 2.1,
              set = function(_, value)
                CM.DB.global.crosshairMounted = value
              end,
              get = function()
                return CM.DB.global.crosshairMounted
              end
            },
            crosshairAppearance = {
              name = "Crosshair Appearance",
              desc = "Select the appearance of the crosshair texture.",
              type = "select",
              width = 1.0,
              order = 2.2,
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
            crosshairAppearancePaddingBottom = {
              type = "description",
              name = " ",
              width = "full",
              order = 2.3
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
              order = 4,
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
            crosshairSizePaddingBottom = {
              type = "description",
              name = " ",
              width = "full",
              order = 4.1
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
              order = 5,
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
            crosshairAlphaPaddingBottom = {
              type = "description",
              name = " ",
              width = "full",
              order = 5.1
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
              order = 6,
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
            }
          }
        }
      }
    }
  }
}

-- ADVANCED CONFIG TAB
CM.Config.AdvancedConfigOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    resetButton = {
      type = "execute",
      name = "Default",
      desc = "Resets Combat Mode settings to its default values.",
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
    header = {
      type = "header",
      name = "Custom Condition",
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
          name = "Create your own conditions for the |cff00FF7FAutomatic Cursor Unlock|r here by entering a chunk of Lua code that returns true if the cursor should be unlocked, false otherwise. If your condition isn't working, toggle on Debug Mode to get error messages printed in the chat for easier troubleshooting.",
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
