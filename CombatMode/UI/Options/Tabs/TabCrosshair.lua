---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCrosshair.lua — OPTIONS TAB — Crosshair + HUD + Assist
---------------------------------------------------------------------------------------
--  What it does: Wires crosshair enable/cast feedback/appearance (a row with texture
--  two clickable texture tiles opening CM.OpenCrosshairTextureEditor)/scale/Y,
--  the single Assist HUD (Next-cast Suggestion + Interactable Indicator, shared side + scale +
--  distance). Situational appearance and its Lua condition are
--  edited on Advanced. Live preview via SetCrosshairOptionsPreview onSelect/onDeselect;
--  when HUD turns on without reticle targeting, applies ConfigInteractionHUDSoftTarget.
--  Architecture / how it works:
--    • DB.global: crosshair*, crosshairScale, crosshairReactionColors,
--      crosshairSituationalCondition, crosshairSituationalAppearance,
--      interactionHUD, interactionHUDPlayers, assistedHighlightMode / Side / Scale / Padding
--      (Padding slider labeled Distance).
--    • set() → DisplayCrosshair / CreateCrosshair / CancelCrosshairCastFeedback /
--      ApplyCrosshairAssistedHighlightOptions / UpdateCrosshairAssistedHighlight.
--  Does not: Own freelook state machine or click-cast slot table UI.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/AssistedHighlight/Assist.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/CVarManager.lua, UI/Editors/CrosshairColorsEditor.lua, UI/Editors/CrosshairTextureEditor.lua,
--  UI/Options/Tabs/TabAdvanced.lua, Constants/Assets.lua, Constants/DatabaseDefaults.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib

local UI = CM.UI

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
    ctx:Description(
      "A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."
    )

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
    ctx:Button({
      layout = "row",
      label = "Appearance",
      desc = "Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset.",
      tiles = {
        { slot = "base", caption = "Inactive", tint = "base" },
        { slot = "active", caption = "Active", tint = "hostile" },
        { slot = "mounted", caption = "Mounted", tint = "base" },
        { slot = "lock", caption = "Disabled", tint = "base" },
      },
      previews = function()
        local appearance = CM.Constants.NormalizeCrosshairAppearance(
          CM.DB.global.crosshairAppearance
        ) or CM.Constants.CrosshairTextureObj.Default
        local byId = CM.Constants.CrosshairTextureById
        local default = byId[CM.Constants.CrosshairIdleDefaultId]
        return {
          base = appearance.Base,
          active = appearance.Active,
          mounted = (byId[CM.DB.global.crosshairMountedId] or default).path,
          lock = (byId[CM.DB.global.crosshairTargetLockId] or default).path,
        }
      end,
      func = function(slot)
        CM.OpenCrosshairTextureEditor("main", slot)
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
    ctx:Header({ text = "ASSIST HUD" })
    ctx:Description(
      "A HUD that guides spell rotation when targeting enemies and displays interaction prompts for objects and NPCs."
    )
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
      disabled = function()
        return CrosshairOff() or not CM.IsRetailClient
      end,
      watermarkWhenDisabled = function()
        if not CM.IsRetailClient then
          return "Only available on Retail"
        end
        return nil
      end,
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
    ctx:Toggle({
      label = "Player Interaction Prompt",
      newFeatureFlag = true,
      desc = "Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu.",
      get = function()
        return CM.IsInteractionHUDPlayersEnabled()
      end,
      set = function(value)
        CM.DB.global.interactionHUDPlayers = value
        RefreshAssist()
      end,
      disabled = function()
        return CrosshairOff() or not CM.IsInteractionHUDEnabled()
      end,
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
