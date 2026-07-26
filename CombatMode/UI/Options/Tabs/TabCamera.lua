---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCamera.lua — OPTIONS TAB — Action Camera
---------------------------------------------------------------------------------------
--  Registers the "Action Camera" tab: Action Camera preset, shoulder offset, mouse-
--  look turn speed, and sticky targeting. When DynamicCam is loaded these controls are
--  watermarked as relinquished. Feature APIs unchanged (CM.ConfigActionCamera,
--  CM.SetShoulderOffset, CM.SetMouseLookSpeed, CM.ConfigStickyCrosshair).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local ReloadUI = _G.ReloadUI

local UI = CM.UI

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

UI.Options.AddTab({
  id = "camera",
  label = "Action Camera",
  build = function(ctx)
    ctx:Header("ACTION CAMERA")

    -- Plain host (no card chrome) so DynamicCam can still stamp the whole option block.
    local host = CreateFrame("Frame", nil, ctx.content)
    host:SetWidth(ctx.width)
    local layout = UI.NewLayout(host, ctx.width)
    layout.y = 0

    layout:Toggle({
      label = "Enable Preset",
      desc = "Apply Combat Mode's Action Camera preset.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.global.actionCamera
      end,
      set = function(value)
        CM.DB.global.actionCamera = value
        if value then
          CM.ConfigActionCamera("combatmode")
        else
          CM.ConfigActionCamera("blizzard")
        end
        ReloadUI()
      end,
      disabled = function()
        return CM.DynamicCam
      end,
    })
    layout:Toggle({
      label = "Disable with Mouse Look",
      desc = "Turn Action Camera off when Mouse Look is off.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.global.actionCamMouselookDisable
      end,
      set = function(value)
        CM.DB.global.actionCamMouselookDisable = value
        ReloadUI()
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })
    layout:Toggle({
      label = "Sticky Targeting",
      desc = "Reticle slightly sticks to enemies so they're harder to lose by accident.",
      get = function()
        return CM.DB.char.stickyCrosshair
      end,
      set = function(value)
        CM.DB.char.stickyCrosshair = value
        if value then
          CM.ConfigStickyCrosshair("combatmode")
        else
          CM.ConfigStickyCrosshair("blizzard")
        end
      end,
      disabled = function()
        return CM.DynamicCam or not CM.IsCrosshairEnabled()
      end,
    })
    layout:Slider({
      label = "Shoulder Offset",
      desc = "Horizontal camera offset with the Action Camera preset.",
      min = -2,
      max = 2,
      step = 0.1,
      get = function()
        return CM.DB.char.shoulderOffset
      end,
      set = function(value)
        CM.DB.char.shoulderOffset = value
        CM.SetShoulderOffset()
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })
    layout:Slider({
      label = "Turn Speed",
      desc = "Camera turn speed during Mouse Look.",
      min = 10,
      max = 180,
      step = 10,
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

    local hostH = -layout.y
    host:SetHeight(hostH)
    ctx:PlaceFrame(host, hostH)

    -- When DynamicCam is loaded it owns these camera CVars, so stamp the whole block.
    if CM.DynamicCam then
      UI.CreateWatermark(host, "Control relinquished to DynamicCam"):Show()
    end
  end,
})
