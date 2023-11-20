local _, Addon = ...

-- LIBRARIES
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")
local AceConfig = _G.LibStub("AceConfig-3.0")
local AceConfigDialog = _G.LibStub("AceConfigDialog-3.0")
local AceConfigCmd = _G.LibStub("AceConfigCmd-3.0")

-- INSTANTIATING ADDON & CREATING FRAME
local CM = AceAddon:NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")
local CrosshairFrame = _G.CreateFrame("Frame", "CombatModeCrosshairFrame", _G.UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")

-- INITIAL STATE VARIABLES
local isCursorFreeState = false
local isCursorLockedState = false
local didPreviousStateChange = false

local debugMode = false

-- UTILITY FUNCTIONS
local function DebugPrint(statement)
  if debugMode then
    print("|cffff0000Combat Mode:|r " .. statement)
  end
end

-- CROSSHAIR STATE HANDLING FUNCTIONS
local function BaseCrosshairState()
  local crossBase = "Interface\\AddOns\\CombatMode\\assets\\crosshair.tga"
  CrosshairTexture:SetTexture(crossBase)
  CrosshairTexture:SetVertexColor(1, 1, 1, .5)
end

local function HostileCrosshairState()
  local crossHit = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"
  CrosshairTexture:SetTexture(crossHit)
  CrosshairTexture:SetVertexColor(1, .2, 0.3, 1)
end

local function FriendlyCrosshairState()
  local crossHit = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"
  CrosshairTexture:SetTexture(crossHit)
  CrosshairTexture:SetVertexColor(0, 1, 0.3, .8)
end

local function ShowCrosshair()
  CrosshairTexture:Show()
end

local function HideCrosshair()
  CrosshairTexture:Hide()
end

local function CreateCrosshair()
  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or 100)
  CrosshairFrame:SetSize(CM.DB.global.crosshairSize or 64, CM.DB.global.crosshairSize or 64)
  CrosshairFrame:SetAlpha(CM.DB.global.crosshairOpacity or 1.0)
  BaseCrosshairState()

  if CM.DB.global.crosshair then
    ShowCrosshair()
  else
    HideCrosshair()
  end
end

local function UpdateCrosshair()
  if CM.DB.global.crosshairY then
    CrosshairFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY)
  end

  if CM.DB.global.crosshairSize then
    CrosshairFrame:SetSize(CM.DB.global.crosshairSize, CM.DB.global.crosshairSize)
  end

  if CM.DB.global.crosshairOpacity then
    CrosshairFrame:SetAlpha(CM.DB.global.crosshairOpacity)
  end
end

local function CrosshairReactToTarget(target, isHostile)
  local isTargetVisible = _G.UnitIsVisible(target)
  local isTarget = _G.UnitReaction("player", target) and _G.UnitReaction("player", target) <= 4

  if isTargetVisible and isTarget == isHostile then
    if isHostile then
      HostileCrosshairState()
    else
      FriendlyCrosshairState()
    end
  else
    BaseCrosshairState()
  end
end

-- FRAME WATCHING
local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CM.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G.getglobal(frameName)
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      DebugPrint(frameName .. " is visible, enabling cursor")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for _, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) == true then
      return true
    end
  end
end

local function SuspendingCursorLock()
  return (
		CursorUnlockFrameVisible(Addon.Constants.FramesToCheck)
		or CursorUnlockFrameVisible(CM.DB.global.watchlist)
		or CursorUnlockFrameGroupVisible(Addon.Constants.wildcardFramesToCheck)
		or _G.SpellIsTargeting()
	)
end

-- FRAME WATCHING FOR SERIALIZED FRAMES (Ex: Opie rings)
local function InitializeWildcardFrameTracking(frameArr)
  DebugPrint("Looking for wildcard frames...")

  -- Initialise the table by going through ALL available globals once and keeping the ones that match
  for _, frameNameToFind in pairs(frameArr) do
    Addon.Constants.wildcardFramesToCheck[frameNameToFind] = {}

    for frameName in pairs(_G) do
      if string.match(frameName, frameNameToFind) then
        DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
        local frameGroup = Addon.Constants.wildcardFramesToCheck[frameNameToFind]
        frameGroup[#frameGroup + 1] = frameName
      end
    end
  end

  DebugPrint("Wildcard frames initialized")
end

-- OVERRIDE BUTTON BUTTONS
local function BindBindingOverride(buttonSettings)
  local valueToUse
  if buttonSettings.value == Addon.Constants.overrideActions.MACRO then
    valueToUse = "MACRO " .. buttonSettings.macro
  else
    valueToUse = buttonSettings.value
  end
  _G.SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

local function BindBindingOverrides()
  for _, button in pairs(Addon.Constants.buttonsToOverride) do
    BindBindingOverride(CM.DB.profile.bindings[button])
  end
end

local function ResetBindingOverride(buttonSettings)
  _G.SetMouselookOverrideBinding(buttonSettings.key, nil)
  DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

local function GetButtonOverrideGroup(modifier, groupOrder)
  local button1Settings, button2Settings, groupName, button1Name, button1MacroName, button2Name, button2MacroName
  if modifier then
    button1Settings = modifier .. "button1"
    button2Settings = modifier .. "button2"

    local capitalisedModifier = (modifier:gsub("^%l", string.upper))
    groupName = capitalisedModifier .. "-modified Clicks"
    button1Name = capitalisedModifier .. " + Left Click"
    button1MacroName = capitalisedModifier .. " + Left Click Macro"
    button2Name = capitalisedModifier .. " + Right Click"
    button2MacroName = capitalisedModifier .. " + Right Click Macro"
  else
    button1Settings = "button1"
    button2Settings = "button2"

    groupName = "Base Clicks"
    button1Name = "Left Click"
    button1MacroName = "Left Click Macro"
    button2Name = "Right Click"
    button2MacroName = "Right Click Macro"
  end

  return {
    type = "group",
    name = "|cff97a2ff" .. groupName .. "|r",
    inline = true,
    order = groupOrder,
    args = {
      overrideButton1Toggle = {
        type = "toggle",
        name = "",
        width = 0.2,
        order = 1,
        set = function(_, value)
          CM.DB.profile.bindings[button1Settings].enabled = value
          if value then
            BindBindingOverride(CM.DB.profile.bindings[button1Settings])
          else
            ResetBindingOverride(CM.DB.profile.bindings[button1Settings])
          end
        end,
        get = function()
          return CM.DB.profile.bindings[button1Settings].enabled
        end,
        disabled = modifier == nil,
      },
      button1 = {
        name = button1Name,
        desc = button1Name,
        type = "select",
        width = 1.5,
        order = 1.1,
        values = Addon.Constants.overrideActions,
        set = function(_, value)
          CM.DB.profile.bindings[button1Settings].value = value
          BindBindingOverride(CM.DB.profile.bindings[button1Settings])
        end,
        get = function()
          return CM.DB.profile.bindings[button1Settings].value
        end,
        disabled = function()
          return not CM.DB.profile.bindings[button1Settings].enabled
        end
      },
      button1SidePadding = {
        type = "description",
        name = " ",
        width = 0.2,
        order = 1.2
      },
      button1macro = {
        name = button1MacroName,
        desc = Addon.Constants.macroFieldDescription,
        type = "input",
        width = 1.5,
        order = 1.3,
        set = function(_, value)
          CM.DB.profile.bindings[button1Settings].macro = value
          BindBindingOverride(CM.DB.profile.bindings[button1Settings])
        end,
        get = function()
          return CM.DB.profile.bindings[button1Settings].macro
        end,
        disabled = function()
          return not CM.DB.profile.bindings[button1Settings].enabled or CM.DB.profile.bindings[button1Settings].value ~=
                   Addon.Constants.overrideActions.MACRO
        end
      },
      overrideButton2Toggle = {
        type = "toggle",
        name = "",
        width = 0.2,
        order = 2,
        set = function(_, value)
          CM.DB.profile.bindings[button2Settings].enabled = value
          if value then
            BindBindingOverride(CM.DB.profile.bindings[button2Settings])
          else
            ResetBindingOverride(CM.DB.profile.bindings[button2Settings])
          end
        end,
        get = function()
          return CM.DB.profile.bindings[button2Settings].enabled
        end,
        disabled = modifier == nil,
      },
      button2 = {
        name = button2Name,
        desc = button2Name,
        type = "select",
        width = 1.5,
        order = 2.1,
        values = Addon.Constants.overrideActions,
        set = function(_, value)
          CM.DB.profile.bindings[button2Settings].value = value
          BindBindingOverride(CM.DB.profile.bindings[button2Settings])
        end,
        get = function()
          return CM.DB.profile.bindings[button2Settings].value
        end,
        disabled = function()
          return not CM.DB.profile.bindings[button2Settings].enabled
        end
      },
      button2SidePadding = {
        type = "description",
        name = " ",
        width = 0.2,
        order = 2.2
      },
      button2macro = {
        name = button2MacroName,
        desc = Addon.Constants.macroFieldDescription,
        type = "input",
        width = 1.5,
        order = 2.3,
        set = function(_, value)
          CM.DB.profile.bindings[button2Settings].macro = value
          BindBindingOverride(CM.DB.profile.bindings[button2Settings])
        end,
        get = function()
          return CM.DB.profile.bindings[button2Settings].macro
        end,
        disabled = function()
          return not CM.DB.profile.bindings[button2Settings].enabled or CM.DB.profile.bindings[button2Settings].value ~=
                   Addon.Constants.overrideActions.MACRO
        end
      }
    }
  }
end

-- FREE LOOK STATE HANDLING
local function LockFreeLook()
  if isCursorFreeState or not SuspendingCursorLock() then
    isCursorFreeState = false
    _G.MouselookStart()

    if CM.DB.global.crosshair then
      ShowCrosshair()
    end

    DebugPrint("Free Look Enabled")
  -- else
  --   DebugPrint("Tried to lock but the state prevented it")
  --   isCursorFreeState = true
  --   _G.MouselookStop()
  end
end

local function UnlockFreeLook()
  if not isCursorFreeState then
    isCursorFreeState = true
    _G.MouselookStop()

    if CM.DB.global.crosshair then
      HideCrosshair()
    end

    DebugPrint("Free Look Disabled")
  end
end

local function ToggleFreeLook()
  if not _G.IsMouselooking() then
    LockFreeLook()
    isCursorLockedState = true
  elseif _G.IsMouselooking() then
    UnlockFreeLook()
    isCursorLockedState = false
  end

  DebugPrint("__________________NEW STATE___________________")
  DebugPrint("didPreviousStateChange:" .. tostring(didPreviousStateChange))
  DebugPrint("isCursorLockedState:" .. tostring(isCursorLockedState))
  DebugPrint("isCursorFreeState:" .. tostring(isCursorFreeState))
end

-- Relocking Free Look & setting CVars after reload/portal
local function Rematch()
  local isReticleTargetingActive = CM.DB.global.reticleTargeting
  if isReticleTargetingActive then
    Addon.Constants.loadReticleTargetCvars()
  end
  ToggleFreeLook()
end

-- UpdateState will be fired when changes in game state happen
-- Responsible for unlocking Free Look when opening frames
local lastStateUpdateTime = 0 -- Sets delay for when OnUpdate is allowed to update state vars

local function UpdateState()
  local currentTime = _G.GetTime()
  if currentTime - lastStateUpdateTime < 0.1 then
    return
  end
  lastStateUpdateTime = currentTime

  if SuspendingCursorLock() then
    UnlockFreeLook()
    didPreviousStateChange = false
  elseif not didPreviousStateChange then
      LockFreeLook()
      didPreviousStateChange = true
  end
end

-- CREATING /CM CHAT COMMAND
function CM:OpenConfigCMD(input)
  ToggleFreeLook()
  if not input or input:trim() == "" then
    AceConfigDialog:Open("Combat Mode")
  else
    AceConfigCmd.HandleCommand(self, "mychat", "Combat Mode", input)
  end
end

-- INITIALIZING DEFAULT CONFIG
function CM:OnInitialize()
  local databaseDefaults = {
    global = {
      version = "1.0.0",
      frameWatching = true,
      watchlist = {
        "SortedPrimaryFrame",
        "WeakAurasOptions"
      },
      reticleTargeting = true,
      crosshair = true,
      crosshairSize = 64,
      crosshairOpacity = 1.0,
      crosshairY = 100
    },
    profile = {
      bindings = {
        button1 = {
          enabled = true,
          key = "BUTTON1",
          value = "ACTIONBUTTON1",
          macro = ""
        },
        button2 = {
          enabled = true,
          key = "BUTTON2",
          value = "ACTIONBUTTON2",
          macro = ""
        },
        shiftbutton1 = {
          enabled = true,
          key = "SHIFT-BUTTON1",
          value = "ACTIONBUTTON3",
          macro = ""
        },
        shiftbutton2 = {
          enabled = true,
          key = "SHIFT-BUTTON2",
          value = "ACTIONBUTTON4",
          macro = ""
        },
        ctrlbutton1 = {
          enabled = true,
          key = "CTRL-BUTTON1",
          value = "ACTIONBUTTON5",
          macro = ""
        },
        ctrlbutton2 = {
          enabled = true,
          key = "CTRL-BUTTON2",
          value = "ACTIONBUTTON6",
          macro = ""
        },
        altbutton1 = {
          enabled = true,
          key = "ALT-BUTTON1",
          value = "ACTIONBUTTON7",
          macro = ""
        },
        altbutton2 = {
          enabled = true,
          key = "ALT-BUTTON2",
          value = "ACTIONBUTTON8",
          macro = ""
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
    }
  }

  local configOptions = {
    name = "|cffff0000Combat Mode|r",
    handler = CM,
    type = "group",
    args = {
      -- ABOUT
      aboutHeader = {
        type = "header",
        name = "|cffffffffABOUT|r",
        order = 0
      },
      aboutHeaderPaddingBottom = {
        type = "description",
        name = " ",
        width = "full",
        order = 0.1
      },
      aboutDescription = {
        type = "description",
        name = "Combat Mode adds Action Combat to World of Warcraft for a more dynamic combat experience.",
        order = 1,
        fontSize = "medium"
      },
      aboutDescriptionPaddingBottom = {
        type = "description",
        name = " ",
        width = "full",
        order = 1.1
      },
      featuresHeader = {
        type = "description",
        name = "|cffffd700Features:|r",
        order = 2,
        fontSize = "medium"
      },
      featuresList = {
        type = "description",
        name = "|cff909090• Free Look - Move your camera without having to perpetually hold right mouse button. \n• Reticle Targeting - Makes use of the SoftTarget Cvars added with Dragonflight to allow the user to target units by aiming at them. \n• Ability casting w/ mouse click - When Combat Mode is enabled, frees your left and right mouse click so you can cast abilities with them. \n• Automatically toggles Free Look when opening interface panels like bags, map, character panel, etc. \n• Ability to add any custom frame - 3rd party AddOns or otherwise - to a watchlist to expand on the default selection. \n• Optional adjustable Crosshair texture to assist with Reticle Targeting.|r",
        order = 3,
        fontSize = "small"
      },
      featuresListPaddingBottom = {
        type = "description",
        name = " ",
        width = "full",
        order = 3.1
      },
      curse = {
        name = "Download From:",
        desc = "curseforge.com/wow/addons/combat-mode",
        type = "input",
        width = 2,
        order = 4,
        get = function()
          return "curseforge.com/wow/addons/combat-mode"
        end
      },
      gitDiscordSpacing = {
        type = "description",
        name = " ",
        width = 0.25,
        order = 4.1
      },
      discord = {
        name = "Feedback & Support:",
        desc = "discord.gg/5mwBSmz",
        type = "input",
        width = 1.1,
        order = 5,
        get = function()
          return "discord.gg/5mwBSmz"
        end
      },
      -- CONFIGURATION
      configurationHeaderPaddingTop = {
        type = "description",
        name = " ",
        width = "full",
        order = 5.1
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
          keybindDescription = {
            type = "description",
            name = "Select which actions are fired when Left and Right clicking as well as their respective Shift, CTRL and ALT modified presses.",
            order = 2
          },
          keybindNote = {
            type = "description",
            name = "\n|cff909090To use a macro when clicking, select |cff69ccf0MACRO|r as the action and then type the exact name of the macro you'd like to cast.|r",
            order = 3
          },
          keybindDescriptionBottomPadding = {
            type = "description",
            name = " ",
            width = "full",
            order = 3.1
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
      -- WATCHLIST
      watchlistGroup = {
        type = "group",
        name = " ",
        order = 9,
        inline = true,
        args = {
          frameWatchingHeader = {
            type = "header",
            name = "|cff00FF7FCursor Unlock|r",
            order = 1
          },
          frameWatchingHeaderPaddingBottom = {
            type = "description",
            name = " ",
            width = "full",
            order = 1.1
          },
          frameWatchingDescription = {
            type = "description",
            name = "Select whether Combat Mode should automatically disable Free Look and release the cursor when specific frames are visible (Bag, Map, Quest, etc).",
            order = 2
          },
          frameWatchingWarning = {
            type = "description",
            name = "\n|cffff0000Disabling this will also disable the Frame Watchlist.|r",
            fontSize = "medium",
            order = 3
          },
          frameWatching = {
            type = "toggle",
            name = "Enable Cursor Unlock",
            desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).",
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
          -- WATCHLIST INPUT
          watchlistInputGroup = {
            type = "group",
            name = "|cff69ccf0Frame Watchlist|r",
            order = 5,
            args = {
              watchlistDescription = {
                type = "description",
                name = "Additional frames - 3rd party AddOns or otherwise - that you'd like Combat Mode to watch for, freeing the cursor automatically when they become visible.",
                order = 1
              },
              watchlist = {
                name = "Frame Watchlist",
                desc = "Use command |cff69ccf0/fstack|r in chat to check frame names. \n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
                type = "input",
                width = "full",
                order = 2,
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
                name = "\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: AddonName + Frame. Ex: WeakAurasFrame.|r",
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
            order = 2
          },
          reticleTargetingWarning = {
            type = "description",
            name = "\n|cffff0000This will override all Cvar values related to SoftTarget. Uncheck to reset them to the default values.|r",
            fontSize = "medium",
            order = 3
          },
          reticleTargeting = {
            type = "toggle",
            name = "Enable Reticle Targeting",
            desc = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable w/ predictable behavior.",
            order = 4,
            set = function(_, value)
              CM.DB.global.reticleTargeting = value
              if value then
                Addon.Constants.loadReticleTargetCvars()
              else
                Addon.Constants.loadDefaultCvars()
              end
            end,
            get = function()
              return CM.DB.global.reticleTargeting
            end
          },
          reticleTargetingNote = {
            type = "description",
            name = "\n|cff909090Please note that manually changing Cvars w/ AddOns like Advanced Interface Options will override Combat Mode values. This is intended so you can tweak things if you want. Although it's highly advised that you don't as the values set by Combat Mode were meticuously tested to provide the most accurate representation of Reticle Targeting possible with the available Cvars.|r",
            order = 5
          },
          reticleTargetingNotePaddingBottom = {
            type = "description",
            name = " ",
            width = "full",
            order = 5.1
          },
          -- CROSSHAIR
          crosshairGroup = {
            type = "group",
            name = "|cff69ccf0Crosshair|r",
            order = 6,
            args = {
              crosshairDescription = {
                type = "description",
                name = "Places a crosshair texture in the center of the screen to assist with Reticle Targeting.",
                order = 1
              },
              crosshair = {
                type = "toggle",
                name = "Enable Crosshair",
                desc = "Places a crosshair texture in the center of the screen to assist with Reticle Targeting.",
                width = "full",
                order = 2,
                set = function(_, value)
                  CM.DB.global.crosshair = value
                  if value then
                    ShowCrosshair()
                  else
                    HideCrosshair()
                  end
                end,
                get = function()
                  return CM.DB.global.crosshair
                end
              },
              crosshairNote = {
                type = "description",
                name = "\n|cff909090The crosshair has been programed with CombatMode's |cff00FFFFReticle Targeting|r in mind. Utilizing the Crosshair without it could lead to unintended behavior.|r",
                order = 3
              },
              crosshairPaddingBottom = {
                type = "description",
                name = " ",
                width = "full",
                order = 3.1
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
                width = 1.6,
                order = 4,
                disabled = function()
                  return CM.DB.global.crosshair ~= true
                end,
                set = function(_, value)
                  CM.DB.global.crosshairSize = value
                  if value then
                    UpdateCrosshair()
                  end
                end,
                get = function()
                  return CM.DB.global.crosshairSize
                end
              },
              crosshairSlidersSpacing = {
                type = "description",
                name = " ",
                width = 0.2,
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
                width = 1.6,
                order = 5,
                isPercent = true,
                disabled = function()
                  return CM.DB.global.crosshair ~= true
                end,
                set = function(_, value)
                  CM.DB.global.crosshairOpacity = value
                  if value then
                    UpdateCrosshair()
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
                    UpdateCrosshair()
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

  self.DB = AceDB:New("CombatModeDB")
  AceConfig:RegisterOptionsTable("Combat Mode", configOptions)
  self.OPTIONS = AceConfigDialog:AddToBlizOptions("Combat Mode", "Combat Mode")
  self:RegisterChatCommand("cm", "OpenConfigCMD")
  self:RegisterChatCommand("combatmode", "OpenConfigCMD")
  self.DB = AceDB:New("CombatModeDB", databaseDefaults, true)
end

-- LOADING ADDON IN
function CM:OnEnable()
  BindBindingOverrides()
  InitializeWildcardFrameTracking(Addon.Constants.wildcardFramesToMatch)
  CreateCrosshair()

  -- Registering Blizzard Events from Constants.lua
  for _, event in pairs(Addon.Constants.BLIZZARD_EVENTS) do
    self:RegisterEvent(event, _G.CombatMode_OnEvent)
  end
end

-- UNLOADING ADDON OUT
-- function CM:OnDisable()
-- 	DebugPrint("ADDON DISABLED")
-- end

-- FIRES WHEN SPECIFIC EVENTS HAPPEN IN GAME
function _G.CombatMode_OnEvent(event)
  if not isCursorFreeState and not SuspendingCursorLock() then
    if event == "PLAYER_SOFT_ENEMY_CHANGED" then
      CrosshairReactToTarget("target", true)
    end

    if event == "PLAYER_SOFT_INTERACT_CHANGED" then
      CrosshairReactToTarget("softInteract", false)
    end
  end

  if event == "PLAYER_ENTERING_WORLD" then
    Rematch()
    print("|cffff0000Combat Mode:|r |cff909090 Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings |r")
  end
end

-- FIRES WHEN GAME STATE CHANGES HAPPEN
function _G.CombatMode_OnUpdate()
  if isCursorLockedState then
    UpdateState()
  end
end

-- FIRES WHEN ADDON IS LOADED
function _G.CombatMode_OnLoad()
  DebugPrint("ADDON LOADED")
end

-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CombatModeToggleKey()
  ToggleFreeLook()
end

function _G.CombatModeHoldKey(keystate)
  if keystate == "down" then
    UnlockFreeLook()
  else
    LockFreeLook()
  end
end
