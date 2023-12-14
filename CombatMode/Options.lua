local CM = _G.GetGlobalStore()

CM.Options = {}

function CM.GetBindingsLocation()
  if CM.DB.profile.useGlobalBindings then
    return "global"
  else
    return "profile"
  end
end

local function GetDefaultBindings()
  return {
    button1 = {
      enabled = true,
      key = "BUTTON1",
      value = "ACTIONBUTTON1",
      customAction = ""
    },
    button2 = {
      enabled = true,
      key = "BUTTON2",
      value = "ACTIONBUTTON2",
      customAction = ""
    },
    shiftbutton1 = {
      enabled = true,
      key = "SHIFT-BUTTON1",
      value = "ACTIONBUTTON3",
      customAction = ""
    },
    shiftbutton2 = {
      enabled = true,
      key = "SHIFT-BUTTON2",
      value = "ACTIONBUTTON4",
      customAction = ""
    },
    ctrlbutton1 = {
      enabled = true,
      key = "CTRL-BUTTON1",
      value = "ACTIONBUTTON5",
      customAction = ""
    },
    ctrlbutton2 = {
      enabled = true,
      key = "CTRL-BUTTON2",
      value = "ACTIONBUTTON6",
      customAction = ""
    },
    altbutton1 = {
      enabled = true,
      key = "ALT-BUTTON1",
      value = "ACTIONBUTTON7",
      customAction = ""
    },
    altbutton2 = {
      enabled = true,
      key = "ALT-BUTTON2",
      value = "ACTIONBUTTON8",
      customAction = ""
    },
    toggle = {
      key = "Combat Mode Toggle",
      value = "BUTTON3"
    },
    hold = {
      key = "(Hold) Switch Mode",
      value = "BUTTON4"
    }
  }
end

CM.Options.DatabaseDefaults = {
  global = {
    frameWatching = true,
    watchlist = {
      "PawnUIFrame",
      "SortedPrimaryFrame",
      "WeakAurasOptions"
    },
    customCondition = "",
    reticleTargeting = true,
    crosshair = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Triangle,
    crosshairSize = 64,
    crosshairOpacity = 1.0,
    crosshairY = 100,
    debugMode = false,
    bindings = GetDefaultBindings()
  },
  profile = {
    useGlobalBindings = false,
    bindings = GetDefaultBindings()
  }
}

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

CM.Options.ConfigOptions = {
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
      name = "|cff909090• |cffE52B50Free Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Utilizes SoftTarget methods from DF enabling users to target units by simply aiming at them. \n• Optional adjustable dynamic |cff00FFFFCrosshair|r marker to assist with Reticle Targeting. \n• |cffB47EDEMouse Button Keybinds|r - When Free Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cff00FF7FCursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc.",
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
          width = 0.5,
          order = 2.2
        },
        toggle = {
          type = "keybinding",
          name = "|cffffd700Toggle|r",
          desc = "Toggles the Free Look camera ON or OFF.",
          width = 1,
          order = 3,
          set = function(_, key)
            local oldKey = (_G.GetBindingKey("Combat Mode Toggle"))
            if oldKey then
              _G.SetBinding(oldKey)
            end
            _G.SetBinding(key, "Combat Mode Toggle")
            _G.SaveBindings(_G.GetCurrentBindingSet())
          end,
          get = function()
            return (_G.GetBindingKey("Combat Mode Toggle"))
          end
        },
        holdLeftPadding = {
          type = "description",
          name = " ",
          width = 0.5,
          order = 3.1
        },
        hold = {
          type = "keybinding",
          name = "|cffffd700Press & Hold|r",
          desc = "Hold to temporarily deactivate the Free Look camera.",
          width = 1,
          order = 4,
          set = function(_, key)
            local oldKey = (_G.GetBindingKey("(Hold) Switch Mode"))
            if oldKey then
              _G.SetBinding(oldKey)
            end
            _G.SetBinding(key, "(Hold) Switch Mode")
            _G.SaveBindings(_G.GetCurrentBindingSet())
          end,
          get = function()
            return (_G.GetBindingKey("(Hold) Switch Mode"))
          end
        },
        holdBottomPadding = {
          type = "description",
          name = " ",
          width = "full",
          order = 4.1
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
          desc = "Use your account-wide shared keybinds on this character.",
          width = "full",
          order = 1.5,
          set = function(_, value)
            CM.DB.profile.useGlobalBindings = value
            CM.OverrideDefaultButtons()
          end,
          get = function()
            return CM.DB.profile.useGlobalBindings
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
          desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).",
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
          name = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable with predictable behavior.",
          fontSize = "medium",
          order = 2
        },
        reticleTargetingWarning = {
          type = "description",
          name = "\n|cffFF5050This will override all Cvar values related to SoftTarget. Uncheck to reset them to the default values.|r",
          order = 3
        },
        reticleTargeting = {
          type = "toggle",
          name = "Reticle Targeting",
          desc = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable w/ predictable behavior.",
          width = "full",
          order = 4,
          set = function(_, value)
            CM.DB.global.reticleTargeting = value
            if value then
              CM.LoadReticleTargetCVars()
            else
              CM.LoadBlizzardDefaultCVars()
            end
          end,
          get = function()
            return CM.DB.global.reticleTargeting
          end
        },
        devNoteDescription1 = {
          type = "description",
          name = "|cffffd700Developer Note:|r \n|cff909090Please note that due to an oversight on Blizzard's part, some spells have baked-in |cffFF5050hard target locking|r, and |cffcfcfcfSoftTargeting|r for some reason does not overrule that when enabled. This causes the occasional need to manually clear the target by pressing esc/tab.|r",
          order = 5.1
        },
        devNoteDescription2 = {
          type = "description",
          name = "|cff909090We can circumvent this by creating macros with |cffcfcfcf/cleartarget|r and placing them in the action bar slots that your mouse clicks are assigned to under |cffB47EDEMouse Button Keybinds|r. Below you'll find a base template you can use when creating your macros. Replace |cffcfcfcfSPELL_NAME|r with the spell you're macroing.|r",
          order = 5.2
        },
        devNoteWarning = {
          type = "description",
          name = "\n|cffFF5050This is an optional configuration step. Only a few spells force target locks, and some classes have none of those. So if this issue doesn't affect you or you're already manually clearing targets, then there's no need to do this.|r",
          order = 5.3
        },
        devNoteCodeBlock = {
          name = "Example:",
          desc = "#showtooltip SPELL_NAME\n/cast [@anyenemy,harm,nodead] SPELL_NAME\n/cleartarget [exists]",
          type = "input",
          multiline = true,
          width = "full",
          order = 5.4,
          get = function()
            return "#showtooltip SPELL_NAME\n/cast [@anyenemy,harm,nodead] SPELL_NAME\n/cleartarget [exists]"
          end
        },
        reticleTargetingNotePaddingBottom = {
          type = "description",
          name = " ",
          width = "full",
          order = 5.5
        },
        -- CROSSHAIR
        crosshairGroup = {
          type = "group",
          name = "|cff00FFFFCrosshair|r",
          order = 6,
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
              name = "|cffffd700Developer Note:|r \n|cff909090The crosshair has been programed with CombatMode's |cff00FFFFReticle Targeting|r in mind. Utilizing the Crosshair without it could lead to unintended behavior like unpredicatable targeting and improper crosshair reactivity.|r",
              order = 1.2
            },
            crosshair = {
              type = "toggle",
              name = "Crosshair",
              desc = "Places a dynamic crosshair marker in the center of the screen to assist with Reticle Targeting.",
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
            crosshairSpacing = {
              type = "description",
              name = " ",
              width = 1.4,
              order = 2.1
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

CM.Options.AdvancedConfigOptions = {
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
