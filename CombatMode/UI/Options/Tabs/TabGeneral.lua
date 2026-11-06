---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabGeneral.lua — OPTIONS TAB — Mouse Look / Camera / Interact
---------------------------------------------------------------------------------------
--  What it does: Wires Mouse Look tab controls (tab id "general") to freelook and interact binds:
--  Mouse Look keybind, Interact keybind + interactUnit, Flip Camera keybind,
--  Camera Features (respectMotionSickness, turn speed, minimum zoom, dynamic pitch,
--  shoulder offset, disable offset with mouselook); Additional Features (pulseCursor,
--  hideTooltip + tooltipModifier, sheath weapons, vignette conditions + match).
--  Architecture / how it works:
--    • DB: global.pulseCursor, hideTooltip, tooltipModifier, mouseLookSpeed, dynamicPitch,
--      dynamicPitchStrength, vignetteConditions (CSV), vignetteMatch,
--      respectMotionSickness, shoulderFollowsMouseLook, sheathWeaponsWithMouselook,
--      interactUnit; char.shoulderOffset.
--    • Motion Sickness Protection disables ActionCam-owned Camera Features (pitch /
--      shoulder / focus). Disable Offset With Mouselook stays editable under DynamicCam.
--    • Keybind sets go through TryApplyBindingChange + AssignNamedKeybind (clears Interact
--      orphans on the stolen key and refreshes Target Lock / Cycle Lock override layers).
--    • Interact rebind clears both INTERACTMOUSEOVER and INTERACTTARGET then assigns
--      primary + ALT alternate (skip ALT dual-bind when the chosen key already has ALT-).
--  Does not: Own freelook state machine, Target Lock UI (TabReticleTargeting),
--      click-cast slot table UI, or custom Lua conditions (TabAdvanced).
--  Related: Core/FreeLook/FreeLookController.lua, Core/Runtime/CVarManager.lua,
--  Core/Vignette.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/Runtime/BindingQueue.lua, Core/Crosshair/Crosshair.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/Tabs/TabAdvanced.lua,
--  UI/Options/OptionsPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local L = CM.L
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local IsMacClient = _G.IsMacClient
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

-- Lua stdlib
local ipairs = _G.ipairs
local strfind = _G.string.find
local string_format = _G.string.format

local UI = CM.UI

local INTERACT_MOUSEOVER = "INTERACTMOUSEOVER"
local INTERACT_TARGET = "INTERACTTARGET"

local INTERACT_UNIT_VALUES = {
  mouseover = L["Crosshair - More accurate"],
  target = L["Soft Target - More forgiving"],
}
local INTERACT_UNIT_ORDER = { "mouseover", "target" }

local TOOLTIP_MODIFIER_VALUES = {
  ALT = _G.ALT_KEY or "Alt",
  CTRL = _G.CTRL_KEY or "Ctrl",
  SHIFT = _G.SHIFT_KEY or "Shift",
}
local TOOLTIP_MODIFIER_ORDER = { "ALT", "CTRL", "SHIFT" }

--- Watermark for controls another camera addon owns (nil when Combat Mode owns them).
local VIGNETTE_CONDITION_VALUES = {
  mouselook = L["Mouse Look is on"],
  combat = L["In combat"],
  interaction = L["Talking to an NPC"],
}
local VIGNETTE_CONDITION_ORDER = { "mouselook", "combat", "interaction" }
local VIGNETTE_MATCH_VALUES = { any = L["Any checked"], all = L["All checked"] }
local VIGNETTE_MATCH_ORDER = { "any", "all" }

local function VignetteSelected()
  local set = {}
  for key in tostring(CM.DB.global.vignetteConditions or ""):gmatch("[^,]+") do
    set[key] = true
  end
  return set
end

local function VignetteConditionOn(id)
  return VignetteSelected()[id] == true
end

local function ToggleVignetteCondition(id)
  local set = VignetteSelected()
  set[id] = not set[id] or nil
  local keys = {}
  for _, key in ipairs(VIGNETTE_CONDITION_ORDER) do
    if set[key] then
      keys[#keys + 1] = key
    end
  end
  CM.SetVignetteConditions(table.concat(keys, ","))
end

local function VignetteConditionsSummary()
  local set = VignetteSelected()
  local names = {}
  for _, key in ipairs(VIGNETTE_CONDITION_ORDER) do
    if set[key] then
      names[#names + 1] = VIGNETTE_CONDITION_VALUES[key]
    end
  end
  return #names > 0 and table.concat(names, ", ") or L["Off"]
end

local function CameraOwnerWatermark()
  if not CM.CameraOwner then
    return nil
  end

  return string_format(L["Control relinquished to %s"], CM.CameraOwner)
end

local function RespectMotionSicknessOn()
  if CM.MotionSicknessProtectionOn then
    return CM.MotionSicknessProtectionOn() == true -- SteadyCam's when delegated
  end

  return CM.DB.global.respectMotionSickness == true
end

-- Watermark when camera ActionCam controls are locked by DynamicCam or Respect MS.
local function CameraFeatureWatermark()
  return CameraOwnerWatermark()
    or (RespectMotionSicknessOn() and L["Disabled while Motion Sickness Protection is on"])
    or nil
end

local function CameraFeatureDisabled()
  return CM.CameraOwner ~= nil or RespectMotionSicknessOn()
end

--- Primary + alternate interact binding commands from CM.DB.global.interactUnit.
local function GetInteractCommands()
  if CM.DB.global.interactUnit == "target" then
    return INTERACT_TARGET, INTERACT_MOUSEOVER
  end
  return INTERACT_MOUSEOVER, INTERACT_TARGET
end

--- Clears every key currently assigned to INTERACTMOUSEOVER / INTERACTTARGET.
local function ClearInteractBindings()
  for _, cmd in ipairs({ INTERACT_MOUSEOVER, INTERACT_TARGET }) do
    local key = GetBindingKey(cmd)
    while key do
      SetBinding(key)
      key = GetBindingKey(cmd)
    end
  end
end

--- Physical key currently used for Interact (primary, or alternate if mid-migration).
local function GetInteractBindingKey()
  local primary, alternate = GetInteractCommands()
  return GetBindingKey(primary) or GetBindingKey(alternate)
end

--- Binds `key` to the selected interact command and ALT-key to the other, then saves.
--- When `key` already starts with ALT- (e.g. ALT-BUTTON3), skip the dual-bind so we do
--- not create ALT-ALT-BUTTON3.
local function ApplyInteractKeybind(key)
  CM.TryApplyBindingChange(L["reticle interact keybinding"], function()
    ClearInteractBindings()
    if key and key ~= "" then
      local primary, alternate = GetInteractCommands()
      SetBinding(key, primary)
      if not strfind(key, "^ALT%-") then
        SetBinding("ALT-" .. key, alternate)
      end
    end
    SaveBindings(GetCurrentBindingSet())
    -- Interact may have stolen a Target Lock key; refresh the override layer.
    if CM.ApplyToggleFocusTargetBinding then
      CM.ApplyToggleFocusTargetBinding()
    end
  end)
end

UI.Options.AddTab({
  id = "general",
  label = L["Mouse Look"],
  newFeatureFlag = true,
  build = function(ctx)
    ctx:Header(L["MOUSE LOOK"])
    ctx:Description(
      L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."]
    )

    ctx:Keybind({
      label = L["Mouse Look Keybind"],
      desc = L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."],
      get = function()
        return (GetBindingKey("Combat Mode - Mouse Look"))
      end,
      set = function(key)
        CM.TryApplyBindingChange(L["mouse look keybinding"], function()
          CM.AssignNamedKeybind("Combat Mode - Mouse Look", key)
        end)
      end,
    })
    ctx:Keybind({
      label = L["Interact Keybind"],
      newFeatureFlag = true,
      desc = L["Tap to interact with the unit chosen below. Hold on a player to open their context menu."],
      helpTooltip = {
        title = L["Interact Keybind"],
        stacked = true,
        lines = {
          {
            label = L["Players"],
            value = L["Aim at a player for a second and the Assist HUD shows a prompt. Hold the key then to open their context menu."],
          },
          {
            label = L["NPCs and objects"],
            value = L["Interacts as normal with the unit chosen in Interact Unit."],
          },
        },
      },
      get = function()
        return GetInteractBindingKey()
      end,
      set = function(key)
        ApplyInteractKeybind(key)
      end,
    })
    ctx:Dropdown({
      label = L["Interact Unit"],
      desc = L["Which unit will be interacted with when the key is pressed."],
      values = INTERACT_UNIT_VALUES,
      order = INTERACT_UNIT_ORDER,
      get = function()
        return CM.DB.global.interactUnit or "target"
      end,
      set = function(value)
        local key = GetInteractBindingKey()
        CM.DB.global.interactUnit = value
        if key then
          ApplyInteractKeybind(key)
        end
      end,
    })
    ctx:Toggle({
      label = L["Disable Player Interaction"],
      newFeatureFlag = true,
      desc = L["Disables interaction with players from the Interact Key."],
      get = function()
        return not CM.IsPlayerMenuEnabled()
      end,
      set = function(value)
        CM.DB.global.disablePlayerInteract = value
        if value then
          CM.DisarmPlayerMenu()
        end
        if CM.ApplyCrosshairAssistedHighlightOptions then
          CM.ApplyCrosshairAssistedHighlightOptions()
        end
      end,
    })
    ctx:Keybind({
      label = L["Flip Camera Keybind"],
      desc = L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."],
      get = function()
        return (GetBindingKey("Combat Mode - Flip Camera"))
      end,
      set = function(key)
        CM.TryApplyBindingChange(L["flip camera keybinding"], function()
          CM.AssignNamedKeybind("Combat Mode - Flip Camera", key)
        end)
      end,
    })
    -- macOS only: on other clients the stuck-cursor freeze does not occur, so this
    -- recovery keybind is hidden to avoid clutter.
    if IsMacClient() then
      ctx:Keybind({
        label = L["Reset Mouse Look"],
        desc = L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."],
        get = function()
          return (GetBindingKey("Combat Mode - Reset Mouse Look"))
        end,
        set = function(key)
          CM.TryApplyBindingChange(L["reset mouse look keybinding"], function()
            CM.AssignNamedKeybind("Combat Mode - Reset Mouse Look", key)
          end)
        end,
      })
    end

    ctx:Gap()
    ctx:Header(L["CAMERA FEATURES"])
    ctx:Description(L["Curated camera adjustments for a more action-focused experience."])

    ctx:Toggle({
      label = L["Motion Sickness Protection"],
      desc = L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."],
      -- Delegated with the rest of the camera: SteadyCam has the same option.
      watermarkWhenDisabled = CameraFeatureWatermark,
      disabled = function()
        return CM.SteadyCam
      end,
      get = function()
        return RespectMotionSicknessOn()
      end,
      set = function(value)
        CM.DB.global.respectMotionSickness = value
        if CM.ApplyMotionSicknessProtectionState then
          CM.ApplyMotionSicknessProtectionState()
        end
      end,
    })
    ctx:Slider({
      label = L["Turn Speed"],
      desc = L["Controls how quickly the camera turns while using Mouse Look."],
      min = 10,
      max = 180,
      step = 10,
      default = 100,
      watermarkWhenDisabled = CameraFeatureWatermark,
      get = function()
        return CM.DB.global.mouseLookSpeed
      end,
      set = function(value)
        CM.DB.global.mouseLookSpeed = value
        CM.SetMouseLookSpeed()
      end,
      disabled = function()
        return CM.CameraOwner ~= nil
      end,
    })
    ctx:Slider({
      label = L["Minimum Zoom"],
      desc = L["Stops the camera from zooming in closer than this distance. 0 turns it off."],
      min = 0,
      max = 10,
      step = 0.5,
      default = 3,
      newFeatureFlag = true,
      get = function()
        return CM.DB.global.minCameraZoom or 3
      end,
      set = function(value)
        CM.DB.global.minCameraZoom = value
        CM.ApplyMinCameraZoom()
      end,
    })
    ctx:Toggle({
      label = L["Dynamic Pitch"],
      desc = L["Dynamically tilt the camera up and down as you move it."],
      watermarkWhenDisabled = CameraFeatureWatermark,
      get = function()
        return CM.DB.global.dynamicPitch ~= false
      end,
      set = function(value)
        CM.DB.global.dynamicPitch = value
        if CM.SetDynamicPitch then
          CM.SetDynamicPitch()
        end
      end,
      disabled = CameraFeatureDisabled,
    })
    ctx:Slider({
      label = L["Pitch Strength"],
      desc = L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."],
      min = CM.Constants.MouseLookCameraPitchStrengthMin,
      max = CM.Constants.MouseLookCameraPitchStrengthMax,
      step = 0.05,
      default = CM.Constants.MouseLookCameraPitchDefault,
      watermarkWhenDisabled = CameraFeatureWatermark,
      get = function()
        local value = CM.DB.global.dynamicPitchStrength
        if type(value) ~= "number" then
          return CM.Constants.MouseLookCameraPitchDefault
        end
        return value
      end,
      set = function(value)
        CM.DB.global.dynamicPitchStrength = value
        if CM.SetDynamicPitch then
          CM.SetDynamicPitch()
        end
      end,
      disabled = CameraFeatureDisabled,
    })
    ctx:Slider({
      label = L["Shoulder Offset"],
      desc = L["Camera's horizontal position relative to the character."],
      charSpecific = true,
      min = -15,
      max = 15,
      step = 0.1,
      default = 1.2,
      watermarkWhenDisabled = CameraFeatureWatermark,
      get = function()
        return CM.DB.char.shoulderOffset or 1.2
      end,
      set = function(value)
        CM.DB.char.shoulderOffset = value
        if CM.SetShoulderOffset then
          CM.SetShoulderOffset()
        end
      end,
      disabled = CameraFeatureDisabled,
    })
    ctx:Toggle({
      label = L["Disable Offset With Mouselook"],
      desc = L["Shoulder Offset eases to 0 when disabling Mouse Look."]
        .. "\n"
        .. L["When off, Shoulder Offset stays constant at all times."],
      -- Still editable with DynamicCam (unlock→0 / restore path); SteadyCam and MS
      -- Protection lock it.
      watermarkWhenDisabled = function()
        if RespectMotionSicknessOn() then
          return L["Disabled while Motion Sickness Protection is on"]
        end
        return CameraOwnerWatermark()
      end,
      get = function()
        return CM.DB.global.shoulderFollowsMouseLook == true
      end,
      set = function(value)
        CM.DB.global.shoulderFollowsMouseLook = value
        if CM.SetShoulderOffset then
          CM.SetShoulderOffset()
        end
      end,
      disabled = function()
        return CM.SteadyCam or RespectMotionSicknessOn()
      end,
    })
    ctx:Keybind({
      label = L["Swap Shoulder Keybind"],
      desc = L["Press to mirror Shoulder Offset to the other side of your character."],
      get = function()
        return (GetBindingKey("Combat Mode - Swap Shoulder"))
      end,
      set = function(key)
        CM.TryApplyBindingChange(L["swap shoulder keybinding"], function()
          CM.AssignNamedKeybind("Combat Mode - Swap Shoulder", key)
        end)
      end,
    })

    ctx:Gap()
    ctx:Header(L["ADDITIONAL FEATURES"])
    ctx:Description(L["Extra functionalities tied to Mouse Look behaviour."])

    ctx:Toggle({
      label = L["Cursor Pulse"],
      desc = L["Flash the cursor when Mouse Look is turned off."],
      get = function()
        return CM.DB.global.pulseCursor
      end,
      set = function(value)
        CM.DB.global.pulseCursor = value
      end,
    })
    ctx:Toggle({
      label = L["Hide Tooltips"],
      desc = L["Hide tooltips while Mouse Look is on, unless the key below is held."],
      get = function()
        return CM.DB.global.hideTooltip
      end,
      set = function(value)
        CM.DB.global.hideTooltip = value
      end,
      disabled = function()
        return not CM.IsCrosshairEnabled()
      end,
    })
    ctx:Dropdown({
      label = L["Show Tooltips With"],
      newFeatureFlag = true,
      desc = L["Hold this key to show tooltips while Mouse Look is on."],
      values = TOOLTIP_MODIFIER_VALUES,
      order = TOOLTIP_MODIFIER_ORDER,
      get = function()
        return CM.DB.global.tooltipModifier or "ALT"
      end,
      set = function(value)
        CM.DB.global.tooltipModifier = value
      end,
      disabled = function()
        return not CM.DB.global.hideTooltip or not CM.IsCrosshairEnabled()
      end,
    })
    ctx:Toggle({
      label = L["Auto Sheath"],
      desc = L["Sheath weapons automatically with Mouse Look."],
      get = function()
        return CM.DB.global.sheathWeaponsWithMouselook
      end,
      set = function(value)
        CM.DB.global.sheathWeaponsWithMouselook = value
      end,
    })
    ctx:Dropdown({
      label = L["Vignette Shows When"],
      desc = L["Darkens the edges of the screen while the checked situations are true."],
      multi = true,
      newFeatureFlag = true,
      values = VIGNETTE_CONDITION_VALUES,
      order = VIGNETTE_CONDITION_ORDER,
      isOn = VignetteConditionOn,
      toggle = ToggleVignetteCondition,
      summary = VignetteConditionsSummary,
      get = VignetteConditionsSummary,
    })
    ctx:Dropdown({
      label = L["Vignette Match"],
      desc = L["Any: one checked situation is enough. All: every checked situation must be true at once."],
      newFeatureFlag = true,
      values = VIGNETTE_MATCH_VALUES,
      order = VIGNETTE_MATCH_ORDER,
      get = function()
        return CM.DB.global.vignetteMatch == "all" and "all" or "any"
      end,
      set = function(value)
        CM.SetVignetteMatch(value)
      end,
    })
  end,
})
