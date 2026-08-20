---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabGeneral.lua — OPTIONS TAB — Mouse Look / Interact / Target Lock
---------------------------------------------------------------------------------------
--  What it does: Wires General-tab controls to freelook and interact/focus binds:
--  Mouse Look keybind, pulseCursor, hideTooltip, turn speed, sheath weapons,
--  Interact keybind + interactUnit (mouseover vs soft target, with ALT+key on the
--  alternate command), Target Lock keybind, cycleFocusWithMouseWheel,
--  showTargetLockMarker.
--  Architecture / how it works:
--    • DB: global.pulseCursor, hideTooltip, mouseLookSpeed,
--      sheathWeaponsWithMouselook, interactUnit,
--      cycleFocusWithMouseWheel, showTargetLockMarker.
--    • Keybind sets go through TryApplyBindingChange + AssignNamedKeybind (clears Interact
--      orphans on the stolen key and refreshes Target Lock override). Cycle Lock with
--      Mouse Wheel also uses TryApplyBindingChange → UpdateFocusCycleWheelBindings.
--    • Interact rebind clears both INTERACTMOUSEOVER and INTERACTTARGET then assigns
--      primary + ALT alternate (skipped ALT dual-bind when the chosen key already has ALT-).
--  Does not: Own freelook state machine or click-cast slot table UI.
--  Related: Core/FreeLook/FreeLookController.lua,
--  Core/ClickCasting/BindingOverrides.lua, Core/Runtime/BindingQueue.lua,
--  Core/Crosshair/Crosshair.lua, UI/Options/OptionsPanel.lua
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
    ctx:Toggle({
      label = "Pulse Cursor on Unlock",
      desc = "Flash the cursor when Mouse Look ends.",
      get = function()
        return CM.DB.global.pulseCursor
      end,
      set = function(value)
        CM.DB.global.pulseCursor = value
      end,
    })
    ctx:Toggle({
      label = "Hide Tooltip in Mouse Look",
      desc = "Hide the crosshair tooltip while Mouse Look is on.",
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
      label = "Sheath Weapons with Mouse Look",
      desc = "Unsheath weapons when Mouse Look turns on. Sheath when it turns off.",
      get = function()
        return CM.DB.global.sheathWeaponsWithMouselook
      end,
      set = function(value)
        CM.DB.global.sheathWeaponsWithMouselook = value
      end,
    })
    ctx:Slider({
      label = "Mouse Look Turn Speed",
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

    ctx:Gap()
    ctx:Header("TARGET LOCK")

    ctx:Keybind({
      label = "Target Lock Keybind",
      desc = "Tap to lock your target, preventing the reticle from swapping it. Tap again to unlock.\nTarget Lock adheres to Reticle Targeting settings.",
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("target lock keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Toggle Focus Target", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Cycle Lock with Mouse Wheel",
      desc = "While a Target Lock is set, mouse wheel moves the lock to nearby targets, facilitating prioritization when units are stacked.",
      get = function()
        return CM.DB.global.cycleFocusWithMouseWheel ~= false
      end,
      set = function(value)
        CM.DB.global.cycleFocusWithMouseWheel = value
        CM.TryApplyBindingChange("focus cycle mouse wheel", function()
          CM.UpdateFocusCycleWheelBindings()
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Target Lock Nameplate Marker",
      desc = "Show a crosshair marker on the nameplate of the target-locked unit.",
      get = function()
        return CM.DB.global.showTargetLockMarker ~= false
      end,
      set = function(value)
        CM.DB.global.showTargetLockMarker = value
        if CM.ClearFocusNameplateMarker then
          CM.ClearFocusNameplateMarker()
        end
        if value and CM.UpdateFocusNameplateMarker then
          CM.UpdateFocusNameplateMarker()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
  end,
})
