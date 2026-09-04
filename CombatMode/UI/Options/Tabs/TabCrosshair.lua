---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCrosshair.lua — OPTIONS TAB — Crosshair + HUD + Assist
---------------------------------------------------------------------------------------
--  What it does: Wires crosshair enable/cast feedback/appearance/scale/Y,
--  situational condition + situational appearance, Interaction HUD enable + side + scale,
--  and Combat Assist enable + side + scale. Live preview via SetCrosshairOptionsPreview
--  onSelect/onDeselect; when HUD turns on without reticle targeting, applies
--  ConfigInteractionHUDSoftTarget.
--  Architecture / how it works:
--    • DB.global: crosshair*, crosshairScale, crosshairReactionColors,
--      crosshairSituationalCondition, crosshairSituationalAppearance,
--      interactionHUD / Side / Scale, assistedHighlightEnabled / Side / Scale.
--    • set() → DisplayCrosshair / CreateCrosshair / CancelCrosshairCastFeedback /
--      ApplyInteractionHUDLayout / RefreshInteractionHUD /
--      ApplyCrosshairAssistedHighlightOptions / UpdateCrosshairAssistedHighlight;
--      also PartyRadial.UpdateMainFramePosition when Y changes.
--  Does not: Own freelook state machine or click-cast slot table UI.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/InteractionHUD/HUD.lua,
--  Core/Crosshair/AssistedHighlight/Assist.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/CVarManager.lua, UI/Editors/CrosshairColorsEditor.lua,
--  Constants/Assets.lua, Constants/DatabaseDefaults.lua
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
    ctx:Slider({
      label = "Scale",
      desc = "Scales the size of the crosshair.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
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
    ctx:Dropdown({
      label = "Situational Appearance",
      desc = "Texture used while the Situational Condition returns true. Reaction colors still apply.",
      values = CM.Constants.CrosshairAppearanceSelectValues,
      order = appearanceOrder,
      get = function()
        return CM.DB.global.crosshairSituationalAppearance
            and CM.DB.global.crosshairSituationalAppearance.Name
          or "Arrows"
      end,
      set = function(value)
        CM.DB.global.crosshairSituationalAppearance = CM.Constants.CrosshairTextureObj[value]
        if CM.RefreshCrosshairAppearance then
          CM.RefreshCrosshairAppearance()
        else
          CM.CreateCrosshair()
        end
      end,
      disabled = CrosshairOff,
    })
    ctx:TextInput({
      label = "Situational Condition",
      desc = "Custom Lua code checked during Mouse Look. While returning true, forces the crosshair to use the Situational Appearance.",
      placeholder = [[
local isPlayerDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
local isPlayerStealthed = IsStealthed and IsStealthed()
if isPlayerDead or isPlayerStealthed then
  return true end
return false
]],
      multiline = 5,
      get = function()
        return CM.DB.global.crosshairSituationalCondition
          or CM.Constants.DatabaseDefaults.global.crosshairSituationalCondition
          or ""
      end,
      set = function(input)
        CM.DB.global.crosshairSituationalCondition = input
        if CM.RefreshCrosshairAppearance then
          CM.RefreshCrosshairAppearance()
        end
      end,
      disabled = CrosshairOff,
    })

    ctx:Gap()
    ctx:Header("INTERACTION HUD")
    ctx:Toggle({
      label = "Interaction HUD",
      desc = "Show a prompt outside of combat for nearby interactables.",
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
    ctx:Dropdown({
      label = "Position",
      desc = "Which side of the crosshair the Interaction HUD appears on.",
      values = {
        LEFT = "Left",
        RIGHT = "Right",
      },
      order = { "LEFT", "RIGHT" },
      get = function()
        return CM.DB.global.interactionHUDSide
          or CM.Constants.DatabaseDefaults.global.interactionHUDSide
      end,
      set = function(value)
        CM.DB.global.interactionHUDSide = value
        if CM.ApplyInteractionHUDLayout then
          CM.ApplyInteractionHUDLayout()
        end
        if CM.RefreshInteractionHUD then
          CM.RefreshInteractionHUD()
        end
      end,
      disabled = function()
        return CrosshairOff() or not CM.DB.global.interactionHUD
      end,
    })
    ctx:Slider({
      label = "Scale",
      desc = "Scales the size of the Interaction HUD.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
      get = function()
        return CM.DB.global.interactionHUDScale
          or CM.Constants.DatabaseDefaults.global.interactionHUDScale
          or 1
      end,
      set = function(value)
        CM.DB.global.interactionHUDScale = value
        if CM.ApplyInteractionHUDLayout then
          CM.ApplyInteractionHUDLayout()
        end
        if CM.RefreshInteractionHUD then
          CM.RefreshInteractionHUD()
        end
      end,
      disabled = function()
        return CrosshairOff() or not CM.DB.global.interactionHUD
      end,
    })

    ctx:Gap()
    ctx:Header("COMBAT ASSIST")
    ctx:Toggle({
      label = "Combat Assist",
      desc = "Show Blizzard's next-spell suggestion during combat.",
      get = function()
        return CM.DB.global.assistedHighlightEnabled
      end,
      set = function(value)
        CM.DB.global.assistedHighlightEnabled = value
        RefreshAssist()
      end,
      disabled = CrosshairOff,
    })
    ctx:Dropdown({
      label = "Position",
      desc = "Which side of the crosshair the Combat Assist icon appears on.",
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
      desc = "Scales the size of the Combat Assist.",
      min = 0.5,
      max = 1.5,
      step = 0.05,
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
  end,
})
