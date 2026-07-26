---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabGeneral.lua — OPTIONS TAB — General
---------------------------------------------------------------------------------------
--  Registers the "General" tab: Mouse Look / Interact / Target Lock keybinds, the
--  Target Lock focus-target toggle (confirm + ReloadUI), and the pulse/tooltip toggles.
--  Auto Unlock lives in TabAutoCursorUnlock.lua; Action Camera in TabCamera.lua.
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

UI.Options.AddTab({
  id = "general",
  label = "General",
  build = function(ctx)
    ctx:Header("GENERAL")

    ctx:Keybind({
      label = "Mouse Look",
      desc = "Tap to toggle. Hold to unlock the cursor temporarily.",
      get = function()
        return (GetBindingKey("Combat Mode - Mouse Look"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("mouse look keybinding", function()
          local oldKey = (GetBindingKey("Combat Mode - Mouse Look"))
          if oldKey then
            SetBinding(oldKey)
          end
          if key ~= "" then
            SetBinding(key, "Combat Mode - Mouse Look")
          end
          SaveBindings(GetCurrentBindingSet())
        end)
      end,
    })
    ctx:Keybind({
      label = "Interact",
      desc = "Interact with the unit or object under the crosshair.",
      get = function()
        return (GetBindingKey("INTERACTMOUSEOVER"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("reticle interact keybinding", function()
          local oldKey = (GetBindingKey("INTERACTMOUSEOVER"))
          if oldKey then
            SetBinding(oldKey)
          end
          if key ~= "" then
            SetBinding(key, "INTERACTMOUSEOVER")
            SetBinding("ALT-" .. key, "INTERACTTARGET")
          end
          SaveBindings(GetCurrentBindingSet())
        end)
      end,
    })
    ctx:Keybind({
      label = "Target Lock",
      desc = "Lock onto your target, preventing Reticle Targeting from swapping it.",
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("target lock keybinding", function()
          local oldKey = (GetBindingKey("Combat Mode - Toggle Focus Target"))
          if oldKey then
            SetBinding(oldKey)
          end
          if key ~= "" then
            SetBinding(key, "Combat Mode - Toggle Focus Target")
          end
          SaveBindings(GetCurrentBindingSet())
          CM.ApplyToggleFocusTargetBinding()
        end)
      end,
    })
    ctx:Toggle({
      label = "Lock Selected Target",
      desc = "Lock your selected target instead of the unit under the crosshair.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.char.focusCurrentTargetNotCrosshair
      end,
      set = function(value)
        CM.DB.char.focusCurrentTargetNotCrosshair = value
        ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })

    ctx:Gap()
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
  end,
})
