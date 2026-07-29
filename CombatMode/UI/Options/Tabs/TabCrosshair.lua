---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCrosshair.lua — OPTIONS TAB — Crosshair
---------------------------------------------------------------------------------------
--  Registers the "Crosshair" tab: enable/appearance/size/opacity, cast feedback,
--  vertical position, Interaction HUD, and Combat Assist. While this tab is open it
--  turns on the live preview (CM.SetCrosshairOptionsPreview) so the real crosshair,
--  Interaction HUD, and Combat Assist icon render at screen center with mouselook off.
--  The options window itself docks left-of-center on open so the preview stays visible
--  (see Options.DockWindowLeft). Feature APIs unchanged (CM.CreateCrosshair,
--  CM.DisplayCrosshair, CM.ApplyCrosshairPosition).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local pairs = _G.pairs
local tsort = _G.table.sort

local UI = CM.UI

local appearanceOrder = {}
for name in pairs(CM.Constants.CrosshairAppearanceSelectValues) do
  appearanceOrder[#appearanceOrder + 1] = name
end
tsort(appearanceOrder)

local function CrosshairOff()
  return not CM.IsCrosshairEnabled()
end

local function AssistOff()
  return CrosshairOff() or not CM.DB.global.assistedHighlightEnabled
end

local function RefreshAssist()
  if CM.ApplyCrosshairAssistedHighlightOptions then
    CM.ApplyCrosshairAssistedHighlightOptions()
  end
  if CM.UpdateCrosshairAssistedHighlight then
    CM.UpdateCrosshairAssistedHighlight()
  end
end

local function UpdatePartyRadialAnchor()
  if CM.PartyRadial and CM.PartyRadial.UpdateMainFramePosition then
    CM.PartyRadial.UpdateMainFramePosition()
  end
end

UI.Options.AddTab({
  id = "crosshair",
  label = "Crosshair",
  onSelect = function()
    CM.SetCrosshairOptionsPreview(true)
  end,
  onDeselect = function()
    CM.SetCrosshairOptionsPreview(false)
  end,
  build = function(ctx)
    ctx:Header("CROSSHAIR")

    ctx:Toggle({
      label = "Show Crosshair",
      desc = "Show the crosshair during Mouse Look.",
      get = function()
        return CM.DB.global.crosshair
      end,
      set = function(value)
        CM.DB.global.crosshair = value
        CM.DisplayCrosshair(value)
        CM.CreateCrosshair()
      end,
    })
    ctx:Toggle({
      label = "Hide While Mounted",
      desc = "Hide the crosshair while mounted.",
      get = function()
        return CM.DB.global.crosshairMounted
      end,
      set = function(value)
        CM.DB.global.crosshairMounted = value
      end,
      disabled = CrosshairOff,
    })
    ctx:Toggle({
      label = "Cast Feedback",
      desc = "Crosshair provides visual feedback for casting spells.",
      get = function()
        return CM.DB.global.crosshairCastFeedback
      end,
      set = function(value)
        CM.DB.global.crosshairCastFeedback = value
        if not value and CM.CancelCrosshairCastFeedback then
          CM.CancelCrosshairCastFeedback()
        end
      end,
      disabled = CrosshairOff,
    })
    ctx:Dropdown({
      label = "Appearance",
      desc = "Crosshair texture.",
      values = CM.Constants.CrosshairAppearanceSelectValues,
      order = appearanceOrder,
      get = function()
        return CM.DB.global.crosshairAppearance and CM.DB.global.crosshairAppearance.Name
          or "Default"
      end,
      set = function(value)
        CM.DB.global.crosshairAppearance = CM.Constants.CrosshairTextureObj[value]
        CM.CreateCrosshair()
      end,
      disabled = CrosshairOff,
    })
    ctx:Slider({
      label = "Size",
      desc = "Crosshair size.",
      min = 16,
      max = 128,
      step = 16,
      get = function()
        return CM.DB.global.crosshairSize
      end,
      set = function(value)
        CM.DB.global.crosshairSize = value
        CM.CreateCrosshair()
      end,
      disabled = CrosshairOff,
    })
    ctx:Slider({
      label = "Opacity",
      desc = "Crosshair transparency.",
      min = 0.1,
      max = 1,
      step = 0.1,
      get = function()
        return CM.DB.global.crosshairOpacity
      end,
      set = function(value)
        CM.DB.global.crosshairOpacity = value
        CM.CreateCrosshair()
      end,
      disabled = CrosshairOff,
    })
    ctx:Slider({
      label = "Vertical Position",
      desc = "Move the crosshair up or down from screen center.",
      min = -400,
      max = 400,
      step = 1,
      get = function()
        return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
      end,
      set = function(value)
        CM.DB.global.crosshairY = value
        CM.CreateCrosshair()
        UpdatePartyRadialAnchor()
      end,
      disabled = CrosshairOff,
    })

    ctx:Gap()
    ctx:Header("INTERACTION HUD")
    ctx:Toggle({
      label = "Show Interaction HUD",
      desc = "Show a prompt next to the crosshair for nearby interactables.",
      get = function()
        return CM.DB.global.interactionHUD
      end,
      set = function(value)
        CM.DB.global.interactionHUD = value
        if value and CM.IsCrosshairEnabled() and not CM.DB.char.reticleTargeting then
          CM.ConfigInteractionHUDSoftTarget()
        end
        if CM.RefreshInteractionHUD then
          CM.RefreshInteractionHUD()
        end
      end,
      disabled = CrosshairOff,
    })

    ctx:Gap()
    ctx:Header("COMBAT ASSIST")
    ctx:Toggle({
      label = "Show Combat Assist",
      desc = "Show Blizzard's next-spell suggestion next to the crosshair.",
      get = function()
        return CM.DB.global.assistedHighlightEnabled
      end,
      set = function(value)
        CM.DB.global.assistedHighlightEnabled = value
        RefreshAssist()
      end,
      disabled = CrosshairOff,
    })
    ctx:Slider({
      label = "Icon Size",
      desc = "Assist icon size.",
      min = 28,
      max = 52,
      step = 1,
      get = function()
        return CM.DB.global.assistedHighlightSize
      end,
      set = function(value)
        CM.DB.global.assistedHighlightSize = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Slider({
      label = "X Offset",
      desc = "Horizontal offset from the crosshair.",
      min = -200,
      max = 200,
      step = 1,
      get = function()
        return CM.DB.global.assistedHighlightOffsetX
      end,
      set = function(value)
        CM.DB.global.assistedHighlightOffsetX = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Slider({
      label = "Y Offset",
      desc = "Vertical offset from the crosshair.",
      min = -200,
      max = 200,
      step = 1,
      get = function()
        return CM.DB.global.assistedHighlightOffsetY
      end,
      set = function(value)
        CM.DB.global.assistedHighlightOffsetY = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Toggle({
      label = "Show Keybind",
      desc = "Show the keybind next to the assist icon.",
      get = function()
        return CM.DB.global.assistedHighlightShowKeybind
      end,
      set = function(value)
        CM.DB.global.assistedHighlightShowKeybind = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Dropdown({
      label = "Keybind Position",
      desc = "Where the keybind text appears.",
      values = {
        RIGHT = "Right",
        LEFT = "Left",
        TOP = "Top",
        BOTTOM = "Bottom",
      },
      order = { "RIGHT", "LEFT", "TOP", "BOTTOM" },
      get = function()
        return CM.DB.global.assistedHighlightKeybindAnchor
      end,
      set = function(value)
        CM.DB.global.assistedHighlightKeybindAnchor = value
        RefreshAssist()
      end,
      disabled = function()
        return AssistOff() or not CM.DB.global.assistedHighlightShowKeybind
      end,
    })
  end,
})
