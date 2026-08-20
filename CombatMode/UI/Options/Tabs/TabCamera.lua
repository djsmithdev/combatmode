---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCamera.lua — OPTIONS TAB — Action Camera + additional features
---------------------------------------------------------------------------------------
--  What it does: Wires Action Camera preset toggle (reload), actionCamMouselookDisable,
--  shoulderOffset, and the Additional Features section (vignette toggle). Also exposes
--  four adjustable Action Camera CVars (FOV, max zoom, zoom scroll speed, head tracking
--  strength) via immediate-apply sliders.
--  Architecture / how it works:
--    • DB: global.actionCamera, actionCamMouselookDisable,
--      actionCamera{Fov,MaxZoom,ZoomSpeed,HeadTracking},
--      vignette; char.shoulderOffset.
--    • set() → ConfigActionCamera / SetShoulderOffset /
--      SetActionCamera{Fov,MaxZoom,ZoomSpeed,HeadTracking} (CVarManager).
--  Does not: Own CVar preset tables (Constants/CVars) or freelook lock.
--  Related: Core/Runtime/CVarManager.lua, Constants/CVars.lua,
--  Core/Crosshair/Crosshair.lua, Constants/DatabaseDefaults.lua,
--  Core/Vignette.lua
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
      desc = "Use Combat Mode's Action Camera settings for a more dynamic, immersive camera.",
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
      desc = "Automatically disable the Action Camera preset when Mouse Look is off.",
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
    layout:Slider({
      label = "Shoulder Offset",
      desc = "Adjusts how far the camera sits to the left or right of your character.",
      charSpecific = true,
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
      label = "Field of View",
      desc = "Sets how wide your view is while using the Action Camera.",
      min = 50,
      max = 90,
      step = 1,
      get = function()
        return CM.DB.global.actionCameraFov
      end,
      set = function(value)
        CM.SetActionCameraFov(value)
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })
    layout:Slider({
      label = "Max Zoom Distance",
      desc = "Sets how far you can zoom the camera away from your character.",
      min = 15,
      max = 39,
      step = 1,
      get = function()
        return CM.DB.global.actionCameraMaxZoom
      end,
      set = function(value)
        CM.SetActionCameraMaxZoom(value)
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })
    layout:Slider({
      label = "Zoom Scroll Speed",
      desc = "Controls how quickly the camera zooms when scrolling the mouse wheel.",
      min = 1,
      max = 50,
      step = 1,
      get = function()
        return CM.DB.global.actionCameraZoomSpeed
      end,
      set = function(value)
        CM.SetActionCameraZoomSpeed(value)
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })
    layout:Slider({
      label = "Head Tracking Strength",
      desc = "Controls how strongly the camera follows your character's head movement.",
      min = 0,
      max = 2,
      step = 0.1,
      get = function()
        return CM.DB.global.actionCameraHeadTracking
      end,
      set = function(value)
        CM.SetActionCameraHeadTracking(value)
      end,
      disabled = function()
        return CM.DynamicCam or CM.DB.global.actionCamera ~= true
      end,
    })

    local hostH = -layout.y
    host:SetHeight(hostH)
    ctx:PlaceFrame(host, hostH)

    -- When DynamicCam is loaded it owns these camera CVars, so stamp the whole block.
    if CM.DynamicCam then
      UI.CreateWatermark(host, "Control relinquished to DynamicCam"):Show()
    end

    -- Additional Features section (always visible, independent from DynamicCam).
    ctx:Gap(4)
    ctx:Header("ADDITIONAL FEATURES")
    ctx:Toggle({
      label = "Vignette Effect",
      desc = "Darkens the edges of the screen for a more focused, cinematic view.",
      get = function()
        return CM.DB.global.vignette
      end,
      set = function(value)
        CM.SetVignetteEnabled(value)
      end,
    })
    ctx:Toggle({
      label = "Vignette Tied To Mouse Look",
      desc = "Fades the vignette out when Mouse Look is off and back in when it's on.",
      get = function()
        return CM.DB.global.vignetteFadeWithMouselook
      end,
      set = function(value)
        CM.DB.global.vignetteFadeWithMouselook = value
        CM.SetVignetteEnabled(CM.DB.global.vignette) -- Re-apply to pick up new setting
      end,
      disabled = function()
        return CM.DB.global.vignette ~= true
      end,
    })
  end,
})
