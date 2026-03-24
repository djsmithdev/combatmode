---------------------------------------------------------------------------------------
--  Config/ConfigMouseLook.lua — Mouse Look (bindings, camera, cursor unlock)
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

-- CAMERA FEATURES
local CameraFeatures = {
  type = "group",
  name =
  "Camera Features |cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r.|r",
  order = 8,
  inline = true,
  args = {
    actionCamera = {
      type = "toggle",
      name = "Load Combat Mode's |cffffd700Action Camera|r Preset |cffE37527•|r",
      desc =
      "Configures Blizzard's |cffffd700Action Camera|r feature to a curated preset that better matches Combat Mode's development environment. \n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r.|r \n\n|cffffd700Default:|r |cffE52B50Off|r",
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
      get = function() return CM.DB.global.actionCamera end,
      disabled = function() return CM.DynamicCam end
    },
    actionCamMouselookDisable = {
      type = "toggle",
      name = "Disable |cffffd700Action Camera|r with |cffE52B50Mouse Look|r",
      desc =
      "Disable |cffffd700Action Camera|r features when toggling |cffE52B50Mouse Look|r off. \n\n|cffffd700Default:|r |cffE52B50Off|r",
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
      desc =
      "|cff3B73FF© Character-based option|r \n\nHorizontally offsets the camera to the left or right of your character while the |cffffd700Action Camera Preset|r is enabled. \n\n|cffE52B50Requires |cffffd700Motion Sickness|r under Acessibility options to be turned off.|r \n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cff00FF7F1.0|r",
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
      get = function() return CM.DB.char.shoulderOffset end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end
    },
    spacing3 = Spacing(0.15, 2.1),
    mouseLookSpeed = {
      type = "range",
      name = "|cffE52B50Mouse Look|r Camera Turn Speed |cffE37527•|r",
      desc =
      "Adjusts the speed at which you turn the camera while |cffE52B50Mouse Look|r mode is active.\n\n|cffE37527•|r |cff909090If detected, control of this feature will be relinquished to |cffE37527DynamicCam|r. \n\n|cffffd700Default:|r |cff00FF7F120|r",
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
      get = function() return CM.DB.global.mouseLookSpeed end,
      disabled = function() return CM.DynamicCam end
    }
  }
}

CM.Config.MouseLookOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("freelook", 1),
    description = Description("freelook", 2),
    toggle = {
      type = "keybinding",
      name = "|cffffd700Toggle / Hold - |cffE52B50Mouse Look|r|r",
      desc =
      "Tap to toggle the |cffE52B50Mouse Look|r camera |cff00FF7FOn|r or |cffE52B50Off|r.\n\nHold to temporarily deactivate it — releasing re-engages it.",
      width = 1.15,
      order = 3,
      set = function(_, key)
        CM.TryApplyBindingChange("mouse look keybinding", function()
          local oldKey = (GetBindingKey("Combat Mode - Mouse Look"))
          if oldKey then SetBinding(oldKey) end
          SetBinding(key, "Combat Mode - Mouse Look")
          SaveBindings(GetCurrentBindingSet())
        end)
      end,
      get = function()
        return (GetBindingKey("Combat Mode - Mouse Look"))
      end
    },
    spacing0 = Spacing(0.1, 3.1),
    toggleFocusTarget = {
      type = "keybinding",
      name = "|cffffd700Toggle - |cffcc00ffTarget Lock|r|r",
      desc =
      "Tap to |cffcc00ffTarget Lock|r (Focus) your current target. Tap again to unlock it.\n\nWhile |cffcc00ffTarget Lock|r is active, |cff00FFFFReticle Targeting|r will be stopped from swapping off your current target.\n\n|cff909090Control of which type of unit can be locked is determined by the |cff00FFFFReticle Targeting|r settings.|r",
      width = 1.15,
      order = 4,
      set = function(_, key)
        CM.TryApplyBindingChange("target lock keybinding", function()
          local oldKey = (GetBindingKey(
            "Combat Mode - Toggle Focus Target"))
          if oldKey then SetBinding(oldKey) end
          SetBinding(key, "Combat Mode - Toggle Focus Target")
          SaveBindings(GetCurrentBindingSet())
          -- Apply override binding to click secure button
          CM.ApplyToggleFocusTargetBinding()
        end)
      end,
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end
    },
    spacing1 = Spacing(0.1, 4.1),
    interact = {
      type = "keybinding",
      name = "|cffffd700Interact - |cff00FFFFReticle Target|r|r",
      desc = "Press to interact with the unit or world object under the crosshair when in range.|r",
      width = 1.15,
      order = 5,
      set = function(_, key)
        CM.TryApplyBindingChange("reticle interact keybinding",
          function()
            local oldKey = (GetBindingKey("INTERACTMOUSEOVER"))
            if oldKey then SetBinding(oldKey) end
            SetBinding(key, "INTERACTMOUSEOVER")
            SetBinding("ALT-" .. key, "INTERACTTARGET")
            SaveBindings(GetCurrentBindingSet())
          end)
      end,
      get = function()
        return (GetBindingKey("INTERACTMOUSEOVER"))
      end
    },
    spacing = Spacing("full", 5.1),
    pulseCursor = {
      type = "toggle",
      name = "Pulse Cursor When Exiting |cffE52B50Mouse Look|r",
      desc =
      "Quickly pulses the location of the cursor when exiting |cffE52B50Mouse Look|r mode.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 6,
      set = function(_, value) CM.DB.global.pulseCursor = value end,
      get = function() return CM.DB.global.pulseCursor end
    },
    hideTooltip = {
      type = "toggle",
      name = "Hide Tooltip During |cffE52B50Mouse Look|r",
      desc =
      "Hides the tooltip generated by the crosshair while |cffE52B50Mouse Look|r is active.\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 1.5,
      order = 6.1,
      set = function(_, value) CM.DB.global.hideTooltip = value end,
      get = function() return CM.DB.global.hideTooltip end,
      disabled = function() return not CM.IsCrosshairEnabled() end
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
      desc =
      "Automatically disables |cffE52B50Mouse Look|r and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).\n\n|cffffd700Default:|r |cff00FF7FOn|r",
      width = 2.1,
      order = 12,
      set = function(_, value)
        CM.DB.global.frameWatching = value
      end,
      get = function() return CM.DB.global.frameWatching end
    },
    mountCheck = {
      type = "toggle",
      name = "Unlock While On |cffffd700Vendor Mount|r",
      desc =
      "Keeps the cursor unlocked while a vendor mounts is being used.\n\n|cffffd700Vendor Mounts:|r \n|cff909090Grand Expedition Yak\nTraveler's Tundra Mammoth\nMighty Caravan Brutosaur\nTrader's Gilded Brutosaur\nGrizzly Hills Packmaster|r \n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = 1.5,
      order = 13,
      set = function(_, value) CM.DB.global.mountCheck = value end,
      get = function() return CM.DB.global.mountCheck end
    },
    spacing6 = Spacing("full", 13.1),
    watchlist = {
      name = "Frame Watchlist",
      desc =
      "Expand the list of Blizzard panels or |cffE37527AddOn|r frames that trigger a |cffffd700Cursor Unlock.|r \n\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: |cffcfcfcfAddonName + Frame|r.\nEx: LootFrame|r\n\n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
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
          value = value:gsub("^%s*(.-)%s*$", "%1")    -- Trim spaces
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
