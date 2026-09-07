---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabGeneral.lua — OPTIONS TAB — Mouse Look / Camera / Interact
---------------------------------------------------------------------------------------
--  What it does: Wires General-tab controls to freelook and interact binds:
--  Mouse Look keybind, pulseCursor, hideTooltip, turn speed, sheath weapons,
--  vignette; Camera Features (respectMotionSickness, dynamic pitch, shoulder offset,
--  disable offset with mouselook); Interact keybind + interactUnit.
--  Architecture / how it works:
--    • DB: global.pulseCursor, hideTooltip, mouseLookSpeed, dynamicPitch, vignette,
--      respectMotionSickness, shoulderFollowsMouseLook, sheathWeaponsWithMouselook,
--      interactUnit; char.shoulderOffset.
--    • Motion Sickness Protection disables ActionCam-owned Camera Features (pitch /
--      shoulder / focus). Disable Offset With Mouselook stays editable under DynamicCam.
--    • Keybind sets go through TryApplyBindingChange + AssignNamedKeybind (clears Interact
--      orphans on the stolen key and refreshes Target Lock / Cycle Lock override layers).
--    • Interact rebind clears both INTERACTMOUSEOVER and INTERACTTARGET then assigns
--      primary + ALT alternate (skip ALT dual-bind when the chosen key already has ALT-).
--  Does not: Own freelook state machine, Target Lock UI (TabReticleTargeting), or
--      click-cast slot table UI.
--  Related: Core/FreeLook/FreeLookController.lua, Core/Runtime/CVarManager.lua,
--  Core/Vignette.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/Runtime/BindingQueue.lua, Core/Crosshair/Crosshair.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/OptionsPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...
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

local UI = CM.UI

local INTERACT_MOUSEOVER = "INTERACTMOUSEOVER"
local INTERACT_TARGET = "INTERACTTARGET"

local INTERACT_UNIT_VALUES = {
  mouseover = "Crosshair Unit - More accurate",
  target = "Soft Targeted Unit - More forgiving",
}
local INTERACT_UNIT_ORDER = { "mouseover", "target" }

local function RespectMotionSicknessOn()
  return CM.DB.global.respectMotionSickness == true
end

--- Watermark when camera ActionCam controls are locked by DynamicCam or Respect MS.
local function CameraFeatureWatermark()
  if CM.DynamicCam then
    return "Control relinquished to DynamicCam"
  end
  if RespectMotionSicknessOn() then
    return "Disabled while Motion Sickness Protection is on"
  end
  return nil
end

local function CameraFeatureDisabled()
  return CM.DynamicCam or RespectMotionSicknessOn()
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
  CM.TryApplyBindingChange("reticle interact keybinding", function()
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
  label = "General",
  build = function(ctx)
    ctx:Header("MOUSE LOOK")

    ctx:Keybind({
      label = "Mouse Look Keybind",
      desc = "Tap to toggle Mouse Look. Hold to unlock the cursor temporarily.",
      get = function()
        return (GetBindingKey("Combat Mode - Mouse Look"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("mouse look keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Mouse Look", key)
        end)
      end,
    })
    -- macOS only: on other clients the stuck-cursor freeze does not occur, so this
    -- recovery keybind is hidden to avoid clutter.
    if IsMacClient() then
      ctx:Keybind({
        label = "Reset Mouse Look",
        desc = "Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background.",
        get = function()
          return (GetBindingKey("Combat Mode - Reset Mouse Look"))
        end,
        set = function(key)
          CM.TryApplyBindingChange("reset mouse look keybinding", function()
            CM.AssignNamedKeybind("Combat Mode - Reset Mouse Look", key)
          end)
        end,
      })
    end
    ctx:Slider({
      label = "Turn Speed",
      desc = "Controls how quickly the camera turns while using Mouse Look.",
      min = 10,
      max = 180,
      step = 10,
      watermarkWhenDisabled = "Control relinquished to DynamicCam",
      get = function()
        return CM.DB.global.mouseLookSpeed
      end,
      set = function(value)
        CM.DB.global.mouseLookSpeed = value
        CM.SetMouseLookSpeed()
      end,
      disabled = function()
        return CM.DynamicCam
      end,
    })
    ctx:Toggle({
      label = "Cursor Pulse",
      desc = "Flash the cursor when Mouse Look is turned off.",
      get = function()
        return CM.DB.global.pulseCursor
      end,
      set = function(value)
        CM.DB.global.pulseCursor = value
      end,
    })
    ctx:Toggle({
      label = "Vignette Effect",
      desc = "Darkens the edges of the screen while Mouse Look is on.",
      get = function()
        return CM.DB.global.vignette == true
      end,
      set = function(value)
        if CM.SetVignetteEnabled then
          CM.SetVignetteEnabled(value)
        else
          CM.DB.global.vignette = value
        end
      end,
    })
    ctx:Toggle({
      label = "Hide Tooltips",
      desc = "Hide tooltips while Mouse Look is on.",
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
    ctx:Toggle({
      label = "Auto Sheath",
      desc = "Sheath weapons automatically with Mouse Look.",
      get = function()
        return CM.DB.global.sheathWeaponsWithMouselook
      end,
      set = function(value)
        CM.DB.global.sheathWeaponsWithMouselook = value
      end,
    })

    ctx:Gap()
    ctx:Header("CAMERA FEATURES")

    ctx:Toggle({
      label = "Motion Sickness Protection",
      desc = "Prevents Combat Mode from overriding Blizzard's Motion Sickness settings.",
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
    ctx:Toggle({
      label = "Dynamic Pitch",
      desc = "Dynamically tilt the camera up and down as you move it.",
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
      label = "Shoulder Offset",
      desc = "Camera's horizontal position relative to the character.",
      charSpecific = true,
      min = -2,
      max = 2,
      step = 0.1,
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
      label = "Disable Offset With Mouselook",
      desc = "Shoulder Offset eases to 0 when disabling Mouse Look."
        .. "\nWhen off, Shoulder Offset stays constant at all times.",
      -- Still editable with DynamicCam (unlock→0 / restore path); only MS Protection locks it.
      watermarkWhenDisabled = function()
        if RespectMotionSicknessOn() then
          return "Disabled while Motion Sickness Protection is on"
        end
        return nil
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
      disabled = RespectMotionSicknessOn,
    })

    ctx:Gap()
    ctx:Header("INTERACT")

    ctx:Keybind({
      label = "Interact Keybind",
      desc = "Tap to interact with the unit chosen below.",
      get = function()
        return GetInteractBindingKey()
      end,
      set = function(key)
        ApplyInteractKeybind(key)
      end,
    })
    ctx:Dropdown({
      label = "Interact Unit",
      desc = "Which unit will be interacted with when the key is pressed.",
      values = INTERACT_UNIT_VALUES,
      order = INTERACT_UNIT_ORDER,
      get = function()
        return CM.DB.global.interactUnit or "mouseover"
      end,
      set = function(value)
        local key = GetInteractBindingKey()
        CM.DB.global.interactUnit = value
        if key then
          ApplyInteractKeybind(key)
        end
      end,
    })
  end,
})
