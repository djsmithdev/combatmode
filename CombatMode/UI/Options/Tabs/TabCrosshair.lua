---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCrosshair.lua — OPTIONS TAB — Crosshair
---------------------------------------------------------------------------------------
--  Registers the "Crosshair" tab: enable/appearance/size/opacity, vertical position,
--  Interaction HUD, and Combat Assist. While this tab is open it turns on the live
--  preview (CM.SetCrosshairOptionsPreview) so the real crosshair, Interaction HUD, and
--  Combat Assist icon render at screen center with mouselook off. The options window
--  itself always docks left on open (see Options.DockWindowLeft). Feature APIs unchanged
--  (CM.CreateCrosshair, CM.DisplayCrosshair, CM.ApplyCrosshairPosition).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

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

local function UpdateHealingRadialAnchor()
  if CM.HealingRadial and CM.HealingRadial.UpdateMainFramePosition then
    CM.HealingRadial.UpdateMainFramePosition()
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
    ctx:Description(
      "The crosshair, Interaction HUD, and Combat Assist icon stay visible while this tab is open, so changes preview live on screen."
    )

    ctx:Toggle({
      label = "Show Crosshair",
      desc = "Shows the Combat Mode crosshair while Mouse Look is active.",
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
      label = "Hide Crosshair While Mounted",
      desc = "Hides the crosshair while you are mounted.",
      get = function()
        return CM.DB.global.crosshairMounted
      end,
      set = function(value)
        CM.DB.global.crosshairMounted = value
      end,
      disabled = CrosshairOff,
    })
    ctx:Dropdown({
      label = "Crosshair Appearance",
      desc = "Texture style used for the crosshair.",
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
      label = "Crosshair Size",
      desc = "Pixel size of the crosshair graphic.",
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
      label = "Crosshair Opacity",
      desc = "Transparency of the crosshair (0.1 = nearly invisible, 1 = solid).",
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
      label = "Crosshair Vertical Position",
      desc = "Moves the crosshair up or down from screen center.",
      min = -400,
      max = 400,
      step = 1,
      get = function()
        return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
      end,
      set = function(value)
        CM.DB.global.crosshairY = value
        CM.CreateCrosshair()
        UpdateHealingRadialAnchor()
      end,
      disabled = CrosshairOff,
    })

    ctx:Gap()
    ctx:Header("INTERACTION HUD")
    ctx:Toggle({
      label = "Show Interaction HUD",
      desc = "Display a HUD for interactable NPCs or objects to the right of the crosshair. Bind Interact - Reticle Target under General to interact when in range.",
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
      label = "Show Combat Assist Spell",
      desc = "Show the Blizzard Assisted Combat suggested spell icon near the crosshair (in combat).",
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
      label = "Combat Assist Icon Size",
      desc = "Size of the Assisted Combat spell icon.",
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
      label = "Combat Assist X Offset",
      desc = "Horizontal offset of the Assisted Combat icon from the crosshair.",
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
      label = "Combat Assist Y Offset",
      desc = "Vertical offset of the Assisted Combat icon from the crosshair.",
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
      label = "Show Combat Assist Keybind",
      desc = "Shows the keybind text next to the Assisted Combat icon.",
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
      label = "Combat Assist Keybind Anchor",
      desc = "Which side of the Assisted Combat icon shows the keybind text.",
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
