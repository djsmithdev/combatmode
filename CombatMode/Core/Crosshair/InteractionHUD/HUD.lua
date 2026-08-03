---------------------------------------------------------------------------------------
--  Core/Crosshair/InteractionHUD/HUD.lua — CROSSHAIR — soft-interact cluster chrome
---------------------------------------------------------------------------------------
--  What it does: Owns the Interaction HUD cluster beside the crosshair when a soft-interact
--  target exists: side via interactionHUDSide (default LEFT), fixed icon size 26, name
--  label + shadow, layout/resize, options preview sample, and public Apply / Refresh / Init.
--  Architecture / how it works:
--    • InitInteractionHUD({crosshairFrame, crosshairTexture}); ApplyInteractionHUDLayout
--      + RefreshInteractionHUD for side/gap (CrosshairCompanionOffsetX beyond reticle edge).
--    • SoftTarget CVars applied elsewhere via CVarManager.ConfigInteractionHUDSoftTarget.
--    • Visual.Attach + OnUpdate Visual.Tick; Target for identity / cursor dim.
--    • Retail 12.x: secret-string-safe UnitName / FontString sizing (no literal compares).
--    • Preview: IsCrosshairPreviewActive shows sample atlas + "Interactable" with no target.
--  Does not: Write SoftTarget CVars or own fade/range internals (Visual) / cursor resolve (Target).
--  Related: Core/Crosshair/InteractionHUD/{Target,Visual}.lua, Core/Crosshair/Crosshair.lua,
--  Core/Runtime/CVarManager.lua, Constants/Reticle.lua, Constants/CVars.lua,
--  UI/Options/Tabs/TabCrosshair.lua, Constants/DatabaseDefaults.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UnitIsGameObject = _G.UnitIsGameObject

-- Lua stdlib
local math = _G.math

local Target = CM.InteractionHUDTarget
local Visual = CM.InteractionHUDVisual

local crosshairFrame
local crosshairTexture

local InteractionHUDCluster
local InteractionHUDShadow
local InteractionHUDIcon
local InteractionHUDLabel
local interactionHUDNameRetry = 0
-- 12.0.0+: UnitName etc. may return secret strings; FontString widths/heights can be secret.
local ihInteractionHUDSecretIdentity = false

local IH_GAP = 7
local IH_LABEL_MAX_W = 280
local IH_TEXT_PAD = 4 -- shadow bleed past glyphs
local IH_ICON = (Target and Target.IH_ICON) or 26
local IH_FONT = 13 -- matches party radial slice name size
local IH_SHADOW_ATLAS = "PetJournal-BattleSlot-Shadow"
local IH_OFFSET_X = CM.Constants.CrosshairCompanionOffsetX

-- Options tab preview: render sample content with no soft-interact target.
local IH_PREVIEW_ATLAS = "mechagon-projects"
local IH_PREVIEW_NAME = "Interactable"

local function IsSecretValue(v)
  return Target and Target.IsSecretValue and Target.IsSecretValue(v) or false
end

local function IsInteractionHUDPreviewActive()
  return CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive()
end

local function BindVisual()
  if not (Visual and Visual.Attach) then
    return
  end
  Visual.Attach({
    getCluster = function()
      return InteractionHUDCluster
    end,
    getIcon = function()
      return InteractionHUDIcon
    end,
    getLabel = function()
      return InteractionHUDLabel
    end,
    getShadow = function()
      return InteractionHUDShadow
    end,
    isPreviewActive = IsInteractionHUDPreviewActive,
  })
end

local function HideInteractionHUD()
  ihInteractionHUDSecretIdentity = false
  if Visual and Visual.RequestHide then
    Visual.RequestHide()
  end
end

local function LayoutInteractionHUDShadow()
  if not InteractionHUDShadow or not InteractionHUDCluster then
    return
  end
  local cw = InteractionHUDCluster:GetWidth()
  if IsSecretValue(cw) then
    return
  end
  if not cw or cw < 1 then
    return
  end
  InteractionHUDShadow:ClearAllPoints()
  local padL, padT, padR, padB = 88, 22, 48, 14
  local shiftX, shiftY = 22, -3
  InteractionHUDShadow:SetPoint(
    "TOPLEFT",
    InteractionHUDCluster,
    "TOPLEFT",
    -padL + shiftX,
    padT + shiftY
  )
  InteractionHUDShadow:SetPoint(
    "BOTTOMRIGHT",
    InteractionHUDCluster,
    "BOTTOMRIGHT",
    padR + shiftX,
    -padB + shiftY
  )
end

local function GetInteractionHUDSide()
  local defaults = CM.Constants
    and CM.Constants.DatabaseDefaults
    and CM.Constants.DatabaseDefaults.global
  local g = CM.DB and CM.DB.global or {}
  local side = g.interactionHUDSide or (defaults and defaults.interactionHUDSide) or "LEFT"
  if side == "RIGHT" then
    return "RIGHT"
  end
  return "LEFT"
end

local function LayoutInteractionHUDChildren()
  if not InteractionHUDCluster or not InteractionHUDIcon or not InteractionHUDLabel then
    return
  end
  local side = GetInteractionHUDSide()
  InteractionHUDIcon:ClearAllPoints()
  InteractionHUDIcon:SetSize(IH_ICON, IH_ICON)
  InteractionHUDLabel:ClearAllPoints()
  InteractionHUDLabel:SetJustifyV("MIDDLE")
  -- Edge-to-edge anchors share the same vertical midpoint so cursor art and text
  -- stay aligned (avoids the old CENTER+1px hack that only suited some cursors).
  if side == "LEFT" then
    InteractionHUDIcon:SetPoint("RIGHT", InteractionHUDCluster, "RIGHT", 0, 0)
    InteractionHUDLabel:SetJustifyH("RIGHT")
    InteractionHUDLabel:SetPoint("RIGHT", InteractionHUDIcon, "LEFT", -IH_GAP, 0)
  else
    InteractionHUDIcon:SetPoint("LEFT", InteractionHUDCluster, "LEFT", 0, 0)
    InteractionHUDLabel:SetJustifyH("LEFT")
    InteractionHUDLabel:SetPoint("LEFT", InteractionHUDIcon, "RIGHT", IH_GAP, 0)
  end
end

local function ResizeInteractionHUDCluster()
  if not InteractionHUDCluster or not InteractionHUDLabel then
    return
  end
  -- Secret identity: fixed width, no string/width measurements; drop shadow hidden.
  if ihInteractionHUDSecretIdentity then
    InteractionHUDLabel:SetWidth(IH_LABEL_MAX_W)
    InteractionHUDLabel:SetWordWrap(true)
    local sw = IH_LABEL_MAX_W
    local sh = IH_FONT
    local w = IH_ICON + IH_GAP + sw + IH_TEXT_PAD
    local h = math.max(IH_ICON, sh)
    InteractionHUDCluster:SetSize(w, h)
    LayoutInteractionHUDChildren()
    if InteractionHUDShadow then
      InteractionHUDShadow:Hide()
    end
    return
  end
  InteractionHUDLabel:SetWidth(0)
  local sw = InteractionHUDLabel.GetUnboundedStringWidth
      and InteractionHUDLabel:GetUnboundedStringWidth()
    or InteractionHUDLabel:GetStringWidth()
  if IsSecretValue(sw) then
    ihInteractionHUDSecretIdentity = true
    ResizeInteractionHUDCluster()
    return
  end
  if not sw or sw < 1 then
    sw = 1
  end
  if sw > IH_LABEL_MAX_W then
    InteractionHUDLabel:SetWidth(IH_LABEL_MAX_W)
    InteractionHUDLabel:SetWordWrap(true)
    sw = IH_LABEL_MAX_W
  else
    InteractionHUDLabel:SetWordWrap(false)
  end
  local sh = InteractionHUDLabel:GetHeight()
  if IsSecretValue(sh) then
    sh = IH_FONT
  elseif not sh or sh < 1 then
    sh = InteractionHUDLabel:GetStringHeight()
    if IsSecretValue(sh) or not sh or sh < 1 then
      sh = IH_FONT
    end
  end
  local w = IH_ICON + IH_GAP + sw + IH_TEXT_PAD
  local h = math.max(IH_ICON, sh)
  InteractionHUDCluster:SetSize(w, h)
  LayoutInteractionHUDChildren()
  LayoutInteractionHUDShadow()
end

function CM.ApplyInteractionHUDLayout()
  if not InteractionHUDCluster then
    return
  end
  if not crosshairFrame then
    return
  end
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB and CM.DB.global or {}
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local gap = (crosshairSize / 2) + IH_OFFSET_X
  local side = GetInteractionHUDSide()
  InteractionHUDCluster:ClearAllPoints()
  if side == "LEFT" then
    InteractionHUDCluster:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, 0)
  else
    InteractionHUDCluster:SetPoint("LEFT", crosshairFrame, "CENTER", gap, 0)
  end
  ResizeInteractionHUDCluster()
end

-- Localized UI font + drop shadow; visuals updated in Visual.Tick.
local function ApplyInteractionHUDLabelFont()
  if not InteractionHUDLabel then
    return
  end
  CM.SetFontStringFromTemplate(InteractionHUDLabel, IH_FONT, _G.GameFontNormalSmall)
  InteractionHUDLabel:SetShadowColor(0, 0, 0, 1)
  InteractionHUDLabel:SetShadowOffset(1, -1)
end

local function EnsureInteractionHUD()
  if InteractionHUDCluster then
    return
  end
  if not crosshairFrame then
    return
  end
  InteractionHUDCluster = CreateFrame("Frame", "CombatModeInteractionHUD", crosshairFrame)
  InteractionHUDCluster:SetFrameStrata(crosshairFrame:GetFrameStrata())
  InteractionHUDCluster:SetFrameLevel(crosshairFrame:GetFrameLevel() + 1)
  InteractionHUDCluster:Hide()

  InteractionHUDShadow = InteractionHUDCluster:CreateTexture(nil, "BACKGROUND")
  InteractionHUDShadow:SetAtlas(IH_SHADOW_ATLAS)
  InteractionHUDShadow:SetBlendMode("BLEND")
  InteractionHUDShadow:SetVertexColor(0, 0, 0, 1)
  InteractionHUDShadow:Hide()

  InteractionHUDIcon = InteractionHUDCluster:CreateTexture(nil, "OVERLAY")
  InteractionHUDIcon:SetSize(IH_ICON, IH_ICON)
  InteractionHUDIcon:SetTexCoord(0, 1, 0, 1)
  InteractionHUDIcon:Hide()

  InteractionHUDLabel =
    InteractionHUDCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  InteractionHUDLabel:SetJustifyH("LEFT")
  InteractionHUDLabel:Hide()

  BindVisual()
  ApplyInteractionHUDLabelFont()
  CM.ApplyInteractionHUDLayout()
  InteractionHUDCluster:SetAlpha(0)
  if Visual and Visual.ResetFadeState then
    Visual.ResetFadeState()
  end
  InteractionHUDCluster:SetScript("OnUpdate", function(_, elapsed)
    if Visual and Visual.Tick then
      Visual.Tick(elapsed)
    end
  end)
end

local function RefreshInteractionHUD()
  EnsureInteractionHUD()
  local g = CM.DB and CM.DB.global
  if not g or g.interactionHUD ~= true then
    HideInteractionHUD()
    return
  end
  if not CM.IsCrosshairEnabled() or CM.HideCrosshairWhileMounted() then
    HideInteractionHUD()
    return
  end
  -- Preview (options tab): sample icon + name, no soft-interact target needed.
  if IsInteractionHUDPreviewActive() and InteractionHUDCluster then
    interactionHUDNameRetry = 0
    ihInteractionHUDSecretIdentity = false
    ApplyInteractionHUDLabelFont()
    InteractionHUDIcon:SetAtlas(IH_PREVIEW_ATLAS)
    InteractionHUDIcon:SetSize(IH_ICON, IH_ICON)
    InteractionHUDLabel:SetText(IH_PREVIEW_NAME)
    ResizeInteractionHUDCluster()
    if Visual and Visual.RequestShow then
      Visual.RequestShow()
    end
    InteractionHUDShadow:Show()
    InteractionHUDIcon:Show()
    InteractionHUDLabel:Show()
    InteractionHUDCluster:Show()
    if Visual and Visual.Tick then
      Visual.Tick(0)
    end
    return
  end
  if not (crosshairTexture and crosshairTexture.IsShown and crosshairTexture:IsShown()) then
    interactionHUDNameRetry = 0
    HideInteractionHUD()
    return
  end
  if not (Target and Target.HasTarget and Target.HasTarget()) then
    interactionHUDNameRetry = 0
    HideInteractionHUD()
    return
  end
  local name = Target.GetUnitName and Target.GetUnitName() or nil
  local hasName = false
  if name ~= nil then
    if IsSecretValue(name) then
      hasName = true
      ihInteractionHUDSecretIdentity = true
    else
      ihInteractionHUDSecretIdentity = false
      hasName = (name ~= "")
    end
  else
    ihInteractionHUDSecretIdentity = false
  end
  if not hasName then
    -- PublicBool-style: do not truth-test secret UnitIsGameObject under taint.
    local isObj = UnitIsGameObject and UnitIsGameObject("softinteract")
    local isObjPublic = nil
    if isObj ~= nil and not IsSecretValue(isObj) then
      isObjPublic = isObj and true or false
    end
    if isObjPublic == true and interactionHUDNameRetry < 1 then
      interactionHUDNameRetry = interactionHUDNameRetry + 1
      local C_Timer = _G.C_Timer
      if C_Timer and C_Timer.After then
        C_Timer.After(0, RefreshInteractionHUD)
      end
      return
    end
    interactionHUDNameRetry = 0
    HideInteractionHUD()
    return
  end
  interactionHUDNameRetry = 0
  ApplyInteractionHUDLabelFont()
  InteractionHUDLabel:SetText(name)
  ResizeInteractionHUDCluster()
  local C_Timer = _G.C_Timer
  if C_Timer and C_Timer.After then
    C_Timer.After(0, ResizeInteractionHUDCluster)
  end
  if Visual and Visual.RequestShow then
    Visual.RequestShow()
  end
  if not ihInteractionHUDSecretIdentity and InteractionHUDShadow then
    InteractionHUDShadow:Show()
  end
  InteractionHUDIcon:Show()
  InteractionHUDLabel:Show()
  InteractionHUDCluster:Show()
  if Visual and Visual.Tick then
    Visual.Tick(0)
  end
end

CM.RefreshInteractionHUD = RefreshInteractionHUD

function CM.InitInteractionHUD(opts)
  crosshairFrame = opts and opts.crosshairFrame or crosshairFrame
  crosshairTexture = opts and opts.crosshairTexture or crosshairTexture

  if crosshairFrame and crosshairFrame.RegisterEvent and crosshairFrame.SetScript then
    crosshairFrame:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
    crosshairFrame:SetScript("OnEvent", function(_, event, _, newTarget)
      if event == "PLAYER_SOFT_INTERACT_CHANGED" then
        if newTarget then
          CM.RefreshInteractionHUD()
        else
          HideInteractionHUD()
        end
      end
    end)
  end
end
