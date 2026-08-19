---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCamera.lua — OPTIONS TAB — Action Camera / sticky / speeds
---------------------------------------------------------------------------------------
--  What it does: Wires Action Camera preset toggle (reload), actionCamMouselookDisable,
--  stickyCrosshair, shoulderOffset, mouseLookSpeed, and the Additional Features section
--  (vignette toggle). The vignette always fades with Mouse Look. Shows a DynamicCam
--  watermark / disable when that addon is present.
--  Architecture / how it works:
--    • DB: global.actionCamera, actionCamMouselookDisable, mouseLookSpeed,
--      vignette; char.shoulderOffset, stickyCrosshair.
--    • set() → ConfigActionCamera / ConfigStickyCrosshair / SetShoulderOffset /
--      SetMouseLookSpeed (CVarManager).
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
      charSpecific = true,
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

    -- Additional Features section (always visible, independent from DynamicCam).
    ctx:Gap(4)
    ctx:Header("ADDITIONAL FEATURES")
    ctx:Toggle({
      label = "Vignette Effect",
      desc = "Darkens the edges of the screen to reduce visual distractions.",
      get = function()
        return CM.DB.global.vignette
      end,
      set = function(value)
        CM.SetVignetteEnabled(value)
      end,
    })
    ctx:Toggle({
      label = "Vignette Tied To Mouse Look",
      desc = "Vignette fades out when Mouse Look is off and fades in when engaged.",
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
