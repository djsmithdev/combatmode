---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCamera.lua — OPTIONS TAB — Action Camera
---------------------------------------------------------------------------------------
--  Registers the "Action Camera" tab: Action Camera preset, shoulder offset, mouse-
--  look turn speed, and sticky targeting. When DynamicCam is loaded these controls are
--  watermarked as relinquished. Feature APIs unchanged (CM.ConfigActionCamera,
--  CM.SetShoulderOffset, CM.SetMouseLookSpeed, CM.ConfigStickyCrosshair).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local ReloadUI = _G.ReloadUI

local UI = CM.UI

local RELOAD_CONFIRM =
  "A UI Reload is required when making changes to Combat Mode's Action Camera Preset.\nProceed?"

UI.Options.AddTab({
  id = "camera",
  label = "Action Camera",
  build = function(ctx)
    ctx:Header("CAMERA FEATURES")
    ctx:Description(
      "Configure Combat Mode's Action Camera preset, shoulder offset, turn speed, and sticky targeting."
    )

    local cameraCard = ctx:Card(nil, function(card)
      card:Toggle({
        label = "Load Combat Mode's Action Camera Preset",
        desc = "Configures Blizzard's Action Camera to a curated preset.",
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
      card:Toggle({
        label = "Disable Action Camera with Mouse Look",
        desc = "Disable Action Camera features when toggling Mouse Look off.",
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
      card:Toggle({
        label = "Sticky Targeting",
        desc = "Makes Reticle Targeting stick to enemies slightly, making it harder to untarget them by accident.",
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
      card:Slider({
        label = "Camera Over Shoulder Offset",
        desc = "Horizontally offsets the camera while the Action Camera Preset is enabled.",
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
      card:Slider({
        label = "Mouse Look Camera Turn Speed",
        desc = "Adjusts the speed at which you turn the camera while Mouse Look mode is active.",
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
    end)

    -- When DynamicCam is loaded it owns these camera CVars, so stamp the whole block.
    if CM.DynamicCam then
      UI.CreateWatermark(cameraCard, "Control relinquished to DynamicCam"):Show()
    end
  end,
})
