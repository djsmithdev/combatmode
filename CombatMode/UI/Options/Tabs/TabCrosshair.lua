---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCrosshair.lua — OPTIONS TAB — Crosshair + HUD + Assist
---------------------------------------------------------------------------------------
--  What it does: Wires crosshair enable/cast feedback/appearance/scale/Y,
--  the single Assist HUD (Next-cast Suggestion + Interactable Indicator, shared side + scale +
--  distance). Situational appearance and its Lua condition are
--  edited on Advanced. Live preview via SetCrosshairOptionsPreview onSelect/onDeselect;
--  when HUD turns on without reticle targeting, applies ConfigInteractionHUDSoftTarget.
--  Architecture / how it works:
--    • DB.global: crosshair*, crosshairScale, crosshairReactionColors,
--      crosshairSituationalCondition, crosshairSituationalAppearance,
--      interactionHUD, assistedHighlightMode / Side / Scale / Padding
--      (Padding slider labeled Distance).
--    • set() → DisplayCrosshair / CreateCrosshair / CancelCrosshairCastFeedback /
--      ApplyCrosshairAssistedHighlightOptions / UpdateCrosshairAssistedHighlight.
--  Does not: Own freelook state machine or click-cast slot table UI.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/AssistedHighlight/Assist.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/CVarManager.lua, UI/Editors/CrosshairColorsEditor.lua,
--  UI/Options/Tabs/TabAdvanced.lua, Constants/Assets.lua, Constants/DatabaseDefaults.lua
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
  return CrosshairOff()
    or not (CM.GetAssistedHighlightMode() ~= "hidden" or CM.DB.global.interactionHUD)
end

local function RefreshAssist()
  if CM.ApplyCrosshairAssistedHighlightOptions then
    CM.ApplyCrosshairAssistedHighlightOptions()
  end
  if CM.UpdateCrosshairAssistedHighlight then
    CM.UpdateCrosshairAssistedHighlight()
  end
end

UI.Options.AddTab({
  id = "crosshair",
  label = "Crosshair",
  newFeatureFlag = true,
  onSelect = function()
    CM.SetCrosshairOptionsPreview(true)
  end,
  onDeselect = function()
    CM.SetCrosshairOptionsPreview(false)
  end,
  build = function(ctx)
    ctx:Header("CROSSHAIR")

    ctx:Toggle({
      label = "Enable Crosshair",
      desc = "While in Mouse Look, display a dynamic & reactive crosshair on your screen.",
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
      label = "Cast Feedback",
      desc = "Crosshair provides visual feedback while casting.",
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
      desc = "Texture utilized by the crosshair. For most options, there's an active and inactive variant.",
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
    ctx:Button({
      layout = "row",
      label = "Reaction Colors",
      buttonLabel = "Edit",
      desc = "Customize the colors used by the crosshair when targeting different types of units.",
      disabled = CrosshairOff,
      func = function()
        CM.OpenCrosshairColorsEditor()
      end,
    })
    ctx:Slider({
      label = "Scale",
      desc = "Scales the size of the crosshair.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
      default = 1,
      get = function()
        return CM.GetCrosshairScale and CM.GetCrosshairScale() or CM.DB.global.crosshairScale or 1
      end,
      set = function(value)
        CM.DB.global.crosshairScale = value
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
      default = 100,
      get = function()
        return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
      end,
      set = function(value)
        CM.DB.global.crosshairY = value
        CM.CreateCrosshair()
      end,
      disabled = CrosshairOff,
    })

    ctx:Gap()
    ctx:Header({ text = "ASSIST HUD", newFeatureFlag = true })
    ctx:Dropdown({
      label = "Next-cast Suggestion",
      desc = "Show the Assisted Highlight's next-cast suggestion while aiming at a target.",
      values = {
        always = "Always",
        combat = "Only In Combat",
        hidden = "Hidden",
      },
      order = { "always", "combat", "hidden" },
      get = function()
        return CM.GetAssistedHighlightMode()
      end,
      set = function(value)
        CM.DB.global.assistedHighlightMode = value
        RefreshAssist()
      end,
      disabled = CrosshairOff,
    })
    ctx:Toggle({
      label = "Interactable Indicator",
      desc = "Show an indicator while aiming at an interactable unit or object.",
      get = function()
        return CM.DB.global.interactionHUD
      end,
      set = function(value)
        CM.DB.global.interactionHUD = value
        if value and CM.IsCrosshairEnabled() and not CM.DB.char.reticleTargeting then
          CM.ConfigInteractionHUDSoftTarget()
        end
        RefreshAssist()
      end,
      disabled = CrosshairOff,
    })
    ctx:Dropdown({
      label = "Position",
      desc = "Which side of the crosshair the HUD appears on.",
      values = {
        LEFT = "Left",
        RIGHT = "Right",
      },
      order = { "LEFT", "RIGHT" },
      get = function()
        return CM.DB.global.assistedHighlightSide
          or CM.Constants.DatabaseDefaults.global.assistedHighlightSide
      end,
      set = function(value)
        CM.DB.global.assistedHighlightSide = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Slider({
      label = "Scale",
      desc = "Scales the size of the HUD.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
      default = 1,
      get = function()
        return CM.DB.global.assistedHighlightScale
          or CM.Constants.DatabaseDefaults.global.assistedHighlightScale
          or 1
      end,
      set = function(value)
        CM.DB.global.assistedHighlightScale = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
    ctx:Slider({
      label = "Distance",
      desc = "Distance between the HUD and the crosshair.",
      min = 0,
      max = 128,
      step = 1,
      default = 24,
      get = function()
        local v = CM.DB.global.assistedHighlightPadding
        if v == nil then
          v = CM.Constants.DatabaseDefaults.global.assistedHighlightPadding
        end
        return v or 24
      end,
      set = function(value)
        CM.DB.global.assistedHighlightPadding = value
        RefreshAssist()
      end,
      disabled = AssistOff,
    })
  end,
})
