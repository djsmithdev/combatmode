---------------------------------------------------------------------------------------
--  Features/Reticle.lua — RETICLE — action-targeting CVars, crosshair UI
---------------------------------------------------------------------------------------
--  Applies ConfigReticleTargeting / soft-target friend toggles, draws the on-screen
--  crosshair (container + inner visual for reaction scale animation and lock-in),
--  and tracks mouseover/soft-target state for appearance. LibEditMode registration,
--  Edit Mode settings, and the crosshair preview panel live in UI/CrosshairEditMode.lua.
--
--  Architecture:
--    • Core drives CreateCrosshair from BootstrapFeatureModules; RegisterCrosshairEditMode
--      runs from the same path after UI/CrosshairEditMode.lua loads. OnUpdate calls
--      CM.UpdateCrosshairReaction when reticle targeting is enabled.
--    • Cursor Y sync uses AdjustCenteredCursorYPos → CursorCenteredYPos when reticle
--      targeting is on; SetCursorFreelookCentering lives in Core.
--    • CM.ApplyCrosshairAppearanceToWidget / CM.CreateCrosshairScaleAnimation are exposed
--      for the Edit Mode preview; EditModeSystemDisplayName (Constants) avoids TOC |T|t in labels.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local IsMouselooking = _G.IsMouselooking
local SetCVar = _G.C_CVar.SetCVar
local UIParent = _G.UIParent
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitIsPlayer = _G.UnitIsPlayer
local UnitReaction = _G.UnitReaction
local UnitName = _G.UnitName
local UnitNameUnmodified = _G.UnitNameUnmodified
local GetUnitName = _G.GetUnitName
local SetUnitCursorTexture = _G.SetUnitCursorTexture
local strfind = _G.string.find
local math = _G.math
local unpack = _G.unpack
local issecretvalue = _G.issecretvalue

local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

---------------------------------------------------------------------------------------
--                        RETICLE TARGETING (ACTION TARGETING CVARS)                 --
---------------------------------------------------------------------------------------
function CM.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ReticleTargetingCVarValues,
    BlizzValues = CM.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting"
  }

  CM.ApplyCVarConfig(info)
end

function CM.HandleSoftTargetFriend(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

---------------------------------------------------------------------------------------
--                           CROSSHAIR FRAME & ANIMATION                             --
---------------------------------------------------------------------------------------
-- Outer frame: registered with LibEditMode; sized to at least CrosshairEditModeMinHitSize for a larger Edit Mode click target.
-- Inner frame: actual crosshair art, reaction scale animation, and lock-in (container stays fixed size).
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)
local CrosshairVisualFrame = CreateFrame("Frame", nil, CrosshairFrame)
local CrosshairTexture = CrosshairVisualFrame:CreateTexture(nil, "OVERLAY")
local STARTING_SCALE = 1
local ENDING_SCALE = 0.9
local SCALE_DURATION = 0.15

local function CreateCrosshairScaleAnimation(animGroup)
  local scaleAnim = animGroup:CreateAnimation("Scale")
  scaleAnim:SetDuration(SCALE_DURATION)
  scaleAnim:SetScaleFrom(STARTING_SCALE, STARTING_SCALE)
  scaleAnim:SetScaleTo(ENDING_SCALE, ENDING_SCALE)
  scaleAnim:SetSmoothProgress(SCALE_DURATION)
  scaleAnim:SetSmoothing("IN_OUT")
end

CM.CreateCrosshairScaleAnimation = CreateCrosshairScaleAnimation

local CrosshairAnimation = CrosshairVisualFrame:CreateAnimationGroup()
CreateCrosshairScaleAnimation(CrosshairAnimation)

function CM.HideCrosshairWhileMounted()
  return CM.DB.global.crosshairMounted and IsMounted()
end

-- SavedVariables may store 1/0; LibEditMode uses `not not value` for checkboxes. Use this
-- anywhere UI enablement must match "crosshair on" (not strict `== true`).
function CM.IsCrosshairEnabled()
  local c = CM.DB and CM.DB.global and CM.DB.global.crosshair
  if c == nil then
    return CM.Constants.DatabaseDefaults.global.crosshair
  end
  return not not c
end

---------------------------------------------------------------------------------------
--                                   INTERACTION HUD                                 --
---------------------------------------------------------------------------------------
local InteractionHUDCluster
local InteractionHUDShadow
local InteractionHUDIcon
local InteractionHUDLabel
local interactionHUDNameRetry = 0
-- 12.0.0+: UnitName etc. may return secret strings; FontString widths/heights can be secret — no compares with literals.
local ihInteractionHUDSecretIdentity = false

local function IsSecretValue(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end
local ihRangeBlend -- 0 = out of range, 1 = in range (lerped)
local ihSnapRangeBlend = true -- snap on next HUD show after hide
local ihClusterFade = 0 -- parent alpha (fade in / fade out)
local ihClusterFadeTarget = 0 -- 0 = hidden, 1 = visible

local IH_GAP = 7
local IH_LABEL_MAX_W = 280
local IH_TEXT_PAD = 4 -- shadow bleed past glyphs
local IH_ICON = 22
local IH_FONT = 13 -- matches healing radial slice name size
local IH_NAME_GOLD = { 1, 204 / 255, 0 }
local IH_NAME_GREY = { 0.62, 0.62, 0.62 }
local IH_SHADOW_ATLAS = "PetJournal-BattleSlot-Shadow"
local IH_SHADOW_ALPHA = 0.7 -- × crosshair opacity only (not dimmed when out of range)
local IH_OFFSET_X = 24 -- px right of crosshair center (LEFT anchor)
local IH_DIM_MIN = 0.5 -- GetInteractionHUDCursorDim when unable
local IH_DIM_MAX = 0.9 -- when able
local IH_RANGE_LERP_SPEED = 14
local IH_CLUSTER_FADE_SPEED = 16

local function HasInteractionHUDTarget()
  return UnitGUID("softinteract") ~= nil
    or UnitExists("softinteract")
    or UnitIsGameObject("softinteract")
end

local function GetInteractionHUDUnitName()
  local name = UnitName("softinteract")
  if name then
    if IsSecretValue(name) then
      return name
    end
    if name ~= "" then
      return name
    end
  end
  if UnitNameUnmodified then
    name = UnitNameUnmodified("softinteract")
    if name then
      if IsSecretValue(name) then
        return name
      end
      if name ~= "" then
        return name
      end
    end
  end
  if GetUnitName then
    name = GetUnitName("softinteract", false)
    if name then
      if IsSecretValue(name) then
        return name
      end
      if name ~= "" then
        return name
      end
    end
  end
end

-- Texture file IDs / paths for "unable" interact cursor (dim + grey name).
local IH_CURSOR_UNABLE = {
  ["4675695"] = true,
  ["4675705"] = true,
  ["4675693"] = true,
  ["4675702"] = true,
  ["4675694"] = true,
  ["4675720"] = true,
  ["4675725"] = true,
  ["4675677"] = true
}

local function HideInteractionHUD()
  ihInteractionHUDSecretIdentity = false
  ihSnapRangeBlend = true
  if not InteractionHUDCluster then
    return
  end
  ihClusterFadeTarget = 0
  if not InteractionHUDCluster:IsShown() then
    return
  end
  if ihClusterFade <= 0.001 then
    InteractionHUDCluster:Hide()
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
  InteractionHUDShadow:SetPoint("TOPLEFT", InteractionHUDCluster, "TOPLEFT", -padL + shiftX, padT + shiftY)
  InteractionHUDShadow:SetPoint("BOTTOMRIGHT", InteractionHUDCluster, "BOTTOMRIGHT", padR + shiftX, -padB + shiftY)
end

local function LayoutInteractionHUDChildren(sw)
  if not InteractionHUDCluster or not InteractionHUDIcon or not InteractionHUDLabel then
    return
  end
  local lw = sw
  if not ihInteractionHUDSecretIdentity then
    local measured = InteractionHUDLabel:GetWidth()
    if measured and not IsSecretValue(measured) then
      if measured >= 1 then
        lw = measured
      end
    end
  end
  InteractionHUDIcon:ClearAllPoints()
  InteractionHUDIcon:SetPoint("CENTER", InteractionHUDCluster, "LEFT", IH_ICON / 2, 1)
  InteractionHUDLabel:ClearAllPoints()
  InteractionHUDLabel:SetJustifyH("LEFT")
  InteractionHUDLabel:SetPoint("CENTER", InteractionHUDIcon, "CENTER", IH_ICON / 2 + IH_GAP + lw / 2, 0)
end

local function ResizeInteractionHUDCluster()
  if not InteractionHUDCluster or not InteractionHUDLabel then
    return
  end
  -- Secret identity: fixed width, no string/width measurements (avoids secret number compares); drop shadow hidden.
  if ihInteractionHUDSecretIdentity then
    InteractionHUDLabel:SetWidth(IH_LABEL_MAX_W)
    InteractionHUDLabel:SetWordWrap(true)
    local sw = IH_LABEL_MAX_W
    local sh = IH_FONT
    local w = IH_ICON + IH_GAP + sw + IH_TEXT_PAD
    local h = math.max(IH_ICON, sh)
    InteractionHUDCluster:SetSize(w, h)
    LayoutInteractionHUDChildren(sw)
    if InteractionHUDShadow then
      InteractionHUDShadow:Hide()
    end
    return
  end
  InteractionHUDLabel:SetWidth(0)
  local sw = InteractionHUDLabel.GetUnboundedStringWidth and InteractionHUDLabel:GetUnboundedStringWidth()
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
  LayoutInteractionHUDChildren(sw)
  LayoutInteractionHUDShadow()
end

local function ApplyInteractionHUDLayout()
  if not InteractionHUDCluster then
    return
  end
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB and CM.DB.global or {}
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local x = (crosshairSize / 2) + IH_OFFSET_X
  InteractionHUDCluster:ClearAllPoints()
  InteractionHUDCluster:SetPoint("LEFT", CrosshairFrame, "CENTER", x, 0)
  ResizeInteractionHUDCluster()
end

-- Localized UI font + drop shadow; visuals updated in UpdateInteractionHUDVisual.
local function ApplyInteractionHUDLabelFont()
  if not InteractionHUDLabel then
    return
  end
  CM.SetFontStringFromTemplate(InteractionHUDLabel, IH_FONT, _G.GameFontNormalSmall)
  InteractionHUDLabel:SetShadowColor(0, 0, 0, 1)
  InteractionHUDLabel:SetShadowOffset(1, -1)
end

-- SetUnitCursorTexture("softinteract") → file id/path; dim when "unable" art.
local function GetInteractionHUDCursorDim()
  if not InteractionHUDIcon then
    return 0.9, true
  end
  if not SetUnitCursorTexture(InteractionHUDIcon, "softinteract") then
    InteractionHUDIcon:SetAtlas("mechagon-projects")
  end
  local filePath = InteractionHUDIcon:GetTextureFilePath()
  if type(filePath) ~= "string" or (filePath and strfind(filePath, "FileData")) then
    filePath = tostring(InteractionHUDIcon:GetTextureFileID())
  end
  if not filePath then
    return 0.9, true
  end
  if IH_CURSOR_UNABLE[filePath] or (type(filePath) == "string" and strfind(filePath, "Unable")) then
    return 0.5, false
  end
  return 0.9, true
end

local function UpdateInteractionHUDVisual(elapsed)
  if not InteractionHUDCluster then
    return
  end
  local dt = (elapsed and elapsed > 0) and elapsed or (1 / 60)

  if math.abs(ihClusterFade - ihClusterFadeTarget) > 0.001 then
    local step = math.min(1, dt * IH_CLUSTER_FADE_SPEED)
    ihClusterFade = ihClusterFade + (ihClusterFadeTarget - ihClusterFade) * step
    if math.abs(ihClusterFade - ihClusterFadeTarget) < 0.01 then
      ihClusterFade = ihClusterFadeTarget
    end
  else
    ihClusterFade = ihClusterFadeTarget
  end
  InteractionHUDCluster:SetAlpha(ihClusterFade)
  if ihClusterFadeTarget == 0 and ihClusterFade <= 0.001 then
    InteractionHUDCluster:Hide()
    ihClusterFade = 0
    return
  end

  if not InteractionHUDCluster:IsShown() then
    return
  end
  -- Fading out: do not call SetUnitCursorTexture — softinteract may already be cleared (fallback gear).
  if ihClusterFadeTarget == 0 then
    return
  end
  local g = CM.DB and CM.DB.global
  if not g or g.interactionHUD ~= true or not g.crosshair or not InteractionHUDIcon or not InteractionHUDLabel then
    return
  end
  local _, inRange = GetInteractionHUDCursorDim()
  local target = inRange and 1 or 0
  if ihRangeBlend == nil or ihSnapRangeBlend then
    ihRangeBlend = target
    ihSnapRangeBlend = false
  else
    local step = math.min(1, dt * IH_RANGE_LERP_SPEED)
    ihRangeBlend = ihRangeBlend + (target - ihRangeBlend) * step
    if math.abs(ihRangeBlend - target) < 0.002 then
      ihRangeBlend = target
    end
  end
  local dim = IH_DIM_MIN + (IH_DIM_MAX - IH_DIM_MIN) * ihRangeBlend
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local crosshairOpacity = g.crosshairOpacity or DefaultConfig.crosshairOpacity
  local contentAlpha = dim * crosshairOpacity
  local t = ihRangeBlend
  local r = IH_NAME_GREY[1] + (IH_NAME_GOLD[1] - IH_NAME_GREY[1]) * t
  local gg = IH_NAME_GREY[2] + (IH_NAME_GOLD[2] - IH_NAME_GREY[2]) * t
  local b = IH_NAME_GREY[3] + (IH_NAME_GOLD[3] - IH_NAME_GREY[3]) * t
  InteractionHUDLabel:SetTextColor(r, gg, b, 1)
  InteractionHUDShadow:SetAlpha(crosshairOpacity * IH_SHADOW_ALPHA)
  InteractionHUDIcon:SetAlpha(contentAlpha)
  InteractionHUDLabel:SetAlpha(contentAlpha)
end

local function EnsureInteractionHUD()
  if InteractionHUDCluster then
    return
  end
  InteractionHUDCluster = CreateFrame("Frame", "CombatModeInteractionHUD", CrosshairFrame)
  InteractionHUDCluster:SetFrameStrata(CrosshairFrame:GetFrameStrata())
  InteractionHUDCluster:SetFrameLevel(CrosshairFrame:GetFrameLevel() + 1)
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

  InteractionHUDLabel = InteractionHUDCluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  InteractionHUDLabel:SetJustifyH("LEFT")
  InteractionHUDLabel:Hide()

  ApplyInteractionHUDLabelFont()
  ApplyInteractionHUDLayout()
  InteractionHUDCluster:SetAlpha(0)
  ihClusterFade = 0
  ihClusterFadeTarget = 0
  InteractionHUDCluster:SetScript("OnUpdate", function(_, elapsed)
    UpdateInteractionHUDVisual(elapsed)
  end)
end

local function RefreshInteractionHUD()
  EnsureInteractionHUD()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local g = CM.DB and CM.DB.global
  if not g or g.interactionHUD ~= true then
    HideInteractionHUD()
    return
  end
  if not g.crosshair or CM.HideCrosshairWhileMounted() then
    HideInteractionHUD()
    return
  end
  if not CrosshairTexture:IsShown() then
    interactionHUDNameRetry = 0
    HideInteractionHUD()
    return
  end
  if not HasInteractionHUDTarget() then
    interactionHUDNameRetry = 0
    HideInteractionHUD()
    return
  end
  local name = GetInteractionHUDUnitName()
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
    if UnitIsGameObject("softinteract") and interactionHUDNameRetry < 1 then
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
  ihClusterFadeTarget = 1
  if not ihInteractionHUDSecretIdentity and InteractionHUDShadow then
    InteractionHUDShadow:Show()
  end
  InteractionHUDIcon:Show()
  InteractionHUDLabel:Show()
  InteractionHUDCluster:Show()
  UpdateInteractionHUDVisual(0)
end

CM.RefreshInteractionHUD = RefreshInteractionHUD

local function AdjustCenteredCursorYPos()
  if not (CM.DB and CM.DB.char and CM.DB.char.reticleTargeting) then
    return
  end
  local _, cy = CrosshairFrame:GetCenter()
  local h = UIParent:GetHeight()
  if not (cy and h and h > 0) then
    return
  end
  local normalized = cy / h
  normalized = math.max(0.01, math.min(0.99, normalized))
  SetCVar("CursorCenteredYPos", normalized)
end

local function GetActiveLayoutNameSafe()
  if not ON_RETAIL_CLIENT then
    return nil
  end
  local LEM = LibStub("LibEditMode", true)
  if not LEM then
    return nil
  end
  return LEM:GetActiveLayoutName()
end

function CM.GetCrosshairPositionForLayout(layoutName)
  if not CM.DB or not CM.DB.global then
    return "CENTER", 0, 0
  end
  local g = CM.DB.global
  local tbl = g.crosshairLayoutPositions
  local defY = g.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  if layoutName and tbl and tbl[layoutName] and tbl[layoutName].y ~= nil then
    return "CENTER", 0, tbl[layoutName].y
  end
  return "CENTER", 0, defY
end

local function SyncCrosshairYFromFrame()
  if not CM.DB or not CM.DB.global then
    return CM.Constants.DatabaseDefaults.global.crosshairY
  end
  local cx, cy = CrosshairFrame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if cx and cy and ux and uy then
    CM.DB.global.crosshairY = cy - uy
  end
  return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
end

local function ApplyCrosshairVertical(y)
  CrosshairFrame:ClearAllPoints()
  CrosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
end

function CM.ApplyCrosshairPositionForLayout(layoutName)
  if not CM.DB or not CM.DB.global then
    return
  end
  local _, _, y = CM.GetCrosshairPositionForLayout(layoutName)
  ApplyCrosshairVertical(y)
  SyncCrosshairYFromFrame()
  AdjustCenteredCursorYPos()
end

function CM.SyncCrosshairLayoutPositionFromAce()
  if not CM.DB or not CM.DB.global then
    return
  end
  local LEM = LibStub("LibEditMode", true)
  if not LEM or not ON_RETAIL_CLIENT then
    return
  end
  local name = LEM:GetActiveLayoutName()
  if not name then
    return
  end
  if not CM.DB.global.crosshairLayoutPositions then
    CM.DB.global.crosshairLayoutPositions = {}
  end
  local y = CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  CM.DB.global.crosshairLayoutPositions[name] = { point = "CENTER", x = 0, y = y }
end

--- Apply crosshair texture, color, and scale animation to a frame (live reticle or edit preview).
--- @param verticalOffset number Y offset from parent center (world crosshair uses saved crosshairY; preview uses 0).
--- @param previewMode boolean If true, always show the texture for non-mounted states (no mouselook check).
local function ApplyCrosshairAppearanceToWidget(targetFrame, targetTexture, animGroup, state, verticalOffset, previewMode)
  local CrosshairAppearance = CM.DB.global.crosshairAppearance
  if not CrosshairAppearance then
    return
  end
  local r, g, b, a = unpack(CM.Constants.CrosshairReactionColors[state])
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false
  local parent = targetFrame:GetParent()

  animGroup:SetScript("OnFinished", function()
    if state ~= "base" then
      targetFrame:SetScale(ENDING_SCALE)
      targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset / ENDING_SCALE)
    end
  end)

  targetTexture:SetTexture(textureToUse)
  targetTexture:SetVertexColor(r, g, b, a)
  if previewMode then
    targetTexture:Show()
  elseif state ~= "mounted" and IsMouselooking() then
    targetTexture:Show()
  end
  animGroup:Play(reverseAnimation)
  if state == "base" then
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
  end
end

CM.ApplyCrosshairAppearanceToWidget = ApplyCrosshairAppearanceToWidget

local function SetCrosshairAppearance(state)
  -- Visual is centered in CrosshairFrame; screen Y offset is on the container, so local offset is 0.
  ApplyCrosshairAppearanceToWidget(CrosshairVisualFrame, CrosshairTexture, CrosshairAnimation, state, 0, false)
end

function CM.DisplayCrosshair(shouldShow)
  if shouldShow then
    CrosshairTexture:Show()
    local DefaultConfig = CM.Constants.DatabaseDefaults.global
    local UserConfig = CM.DB.global or {}
    local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
    CrosshairFrame:SetAlpha(1)
    CrosshairVisualFrame:SetAlpha(crosshairOpacity)
  else
    CrosshairTexture:Hide()
  end
  RefreshInteractionHUD()
end

function CM.CreateCrosshair()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
  local minHit = CM.Constants.CrosshairEditModeMinHitSize or 128
  local hitSize = math.max(crosshairSize, minHit)

  CrosshairTexture:SetAllPoints(CrosshairVisualFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetSize(hitSize, hitSize)
  CrosshairFrame:SetAlpha(1)
  CrosshairVisualFrame:SetSize(crosshairSize, crosshairSize)
  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  CrosshairVisualFrame:SetAlpha(crosshairOpacity)

  CM.ApplyCrosshairPositionForLayout(GetActiveLayoutNameSafe())
  SetCrosshairAppearance("base")
  CM.RefreshCrosshairEditPreview()
  ApplyInteractionHUDLayout()
  RefreshInteractionHUD()
end

local DebugCrosshairFrame = CreateFrame("Frame", "CombatModeDebugCrosshairFrame", UIParent)
DebugCrosshairFrame:SetFrameStrata("DIALOG")
DebugCrosshairFrame:SetFrameLevel(0)
local DebugCrosshairTexture = DebugCrosshairFrame:CreateTexture(nil, "OVERLAY")
DebugCrosshairTexture:SetTexture("Interface\\AddOns\\CombatMode\\assets\\crosshairX.blp")
DebugCrosshairTexture:SetAllPoints(DebugCrosshairFrame)
DebugCrosshairTexture:SetBlendMode("BLEND")
DebugCrosshairTexture:SetVertexColor(0, 1, 0, 1)
DebugCrosshairFrame:SetAlpha(0.8)
DebugCrosshairFrame:Hide()

local DebugCrosshairUpdater = CreateFrame("Frame", nil, UIParent)
DebugCrosshairUpdater:SetScript("OnUpdate", function()
  if not (CM.DB.global and CM.DB.global.debugMode) then
    DebugCrosshairFrame:Hide()
    return
  end
  if IsMouselooking() then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    DebugCrosshairFrame:ClearAllPoints()
    DebugCrosshairFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    local size = (CM.DB.global.crosshairSize) or (CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global and CM.Constants.DatabaseDefaults.global.crosshairSize) or 64
    DebugCrosshairFrame:SetSize(size, size)
    DebugCrosshairFrame:Show()
  else
    DebugCrosshairFrame:Hide()
  end
end)

local lastKnownAppearanceState = nil

local function GetUnitReactionType(unitID)
  if not unitID then
    return "base"
  end
  if not UnitExists(unitID) or not UnitGUID(unitID) then
    return "base"
  end
  local isTargetObject = UnitIsGameObject(unitID)
  if isTargetObject then
    return "object"
  end
  local reaction = UnitReaction("player", unitID)
  if not reaction then
    return "base"
  end
  if UnitIsPlayer(unitID) then
    if UnitCanAttack("player", unitID) then
      return "hostile"
    else
      return "friendly_player"
    end
  elseif reaction <= 4 then
    return "hostile"
  elseif reaction >= 5 then
    return "friendly_npc"
  else
    return "neutral"
  end
end

local function IsEnemyOnlyReticleInCombat()
  return CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly and InCombatLockdown()
end

local function GetUnitUnderCursor()
  local isTargetObject = UnitIsGameObject("softinteract")
  if isTargetObject then
    return "softinteract", "object"
  end
  if UnitExists("mouseover") and UnitGUID("mouseover") then
    local reactionType = GetUnitReactionType("mouseover")
    local enemyOnlyInCombat = IsEnemyOnlyReticleInCombat()

    if not enemyOnlyInCombat or reactionType == "hostile" then
      CM.DebugPrintThrottled("reticleTarget", "Found mouseover unit (reaction: " .. reactionType .. ")")
      return "mouseover", reactionType
    end

    local isFriendlyMouseover = reactionType == "friendly_player" or reactionType == "friendly_npc"
    if isFriendlyMouseover then
      local fallbackUnitID = "softenemy"
      if UnitExists(fallbackUnitID) and UnitGUID(fallbackUnitID) then
        local fallbackReactionType = GetUnitReactionType(fallbackUnitID)
        if fallbackReactionType == "hostile" then
          CM.DebugPrintThrottled("reticleTarget", "Mouseover friendly; fallback hostile unit: " .. fallbackUnitID)
          return fallbackUnitID, fallbackReactionType
        end
      end
    end

    CM.DebugPrintThrottled("reticleTarget", "Mouseover non-hostile in enemy-only combat mode; setting base appearance")
    return nil, nil
  end

  CM.DebugPrintThrottled("reticleTarget", "No unit under cursor, setting base appearance")
  return nil, nil
end

function CM.UpdateCrosshairReaction()
  if not CM.DB.char.reticleTargeting then
    return
  end
  if not CM.DB.global.crosshair or CM.HideCrosshairWhileMounted() then
    return
  end

  local hasFocus = UnitExists("focus")
  local currentUnit, currentReaction = GetUnitUnderCursor()

  local appearanceState
  if hasFocus then
    appearanceState = "focus"
  elseif currentUnit then
    appearanceState = currentReaction or "base"
  else
    appearanceState = "base"
  end

  if appearanceState ~= lastKnownAppearanceState then
    lastKnownAppearanceState = appearanceState
    SetCrosshairAppearance(appearanceState)
  end
end

---------------------------------------------------------------------------------------
--                            CROSSHAIR LOCK-IN ANIMATION                             --
---------------------------------------------------------------------------------------
local LOCK_IN_DURATION = 0.25
local LOCK_IN_STARTING_SCALE = 1.3
local LOCK_IN_STARTING_ALPHA = 0.0
local LOCK_IN_TOTAL_ELAPSED = -1
local LOCK_IN_TARGET_SCALE = 1.0
local LOCK_IN_TARGET_ALPHA = 1.0

local function UpdateCrosshairLockIn(_, elapsed)
  if LOCK_IN_TOTAL_ELAPSED == -1 then
    return
  end

  LOCK_IN_TOTAL_ELAPSED = LOCK_IN_TOTAL_ELAPSED + elapsed

  if LOCK_IN_TOTAL_ELAPSED >= LOCK_IN_DURATION then
    LOCK_IN_TOTAL_ELAPSED = -1
    CrosshairVisualFrame:SetScale(LOCK_IN_TARGET_SCALE)
    CrosshairVisualFrame:SetAlpha(LOCK_IN_TARGET_ALPHA)
    CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
    AdjustCenteredCursorYPos()
    return
  end

  local progress = LOCK_IN_TOTAL_ELAPSED / LOCK_IN_DURATION
  progress = math.max(0, math.min(1, progress))
  local easedProgress = 1 - (1 - progress) * (1 - progress)

  local currentScale = LOCK_IN_STARTING_SCALE + (LOCK_IN_TARGET_SCALE - LOCK_IN_STARTING_SCALE) * easedProgress
  currentScale = math.max(0.01, currentScale)
  CrosshairVisualFrame:SetScale(currentScale)

  local currentAlpha = LOCK_IN_STARTING_ALPHA + (LOCK_IN_TARGET_ALPHA - LOCK_IN_STARTING_ALPHA) * easedProgress
  CrosshairVisualFrame:SetAlpha(currentAlpha)
end

function CM.ShowCrosshairLockIn()
  if not CM.DB.global.crosshair or not CM.DB.char.reticleTargeting then
    return
  end

  CrosshairTexture:Show()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local configuredOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  local currentScale = CrosshairVisualFrame:GetScale()
  LOCK_IN_STARTING_SCALE = currentScale * 1.3
  LOCK_IN_STARTING_ALPHA = 0.0
  LOCK_IN_TARGET_SCALE = 1.0
  LOCK_IN_TARGET_ALPHA = configuredOpacity

  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  CrosshairVisualFrame:SetScale(LOCK_IN_STARTING_SCALE)
  CrosshairVisualFrame:SetAlpha(LOCK_IN_STARTING_ALPHA)

  LOCK_IN_TOTAL_ELAPSED = 0
end

CrosshairFrame:SetScript("OnEvent", function(_, event, _, newTarget)
  if event == "PLAYER_SOFT_INTERACT_CHANGED" then
    if newTarget then
      RefreshInteractionHUD()
    else
      HideInteractionHUD()
    end
  end
end)
CrosshairFrame:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
CrosshairFrame:SetScript("OnUpdate", function(self, elapsed)
  UpdateCrosshairLockIn(self, elapsed)
end)

---------------------------------------------------------------------------------------
--              CORE HOOKS (REMATCH / EVENTS / DISABLE)                              --
---------------------------------------------------------------------------------------
function CM.OnRematchCrosshair()
  if CM.DB.global.crosshair then
    LOCK_IN_TOTAL_ELAPSED = -1
    CM.CreateCrosshair()
    if CM.HideCrosshairWhileMounted() then
      SetCrosshairAppearance("mounted")
    else
      CM.UpdateCrosshairReaction()
    end

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
    CM.DisplayCrosshair(IsMouselooking())
  elseif CM.DB.global.crosshair == false then
    CM.DisplayCrosshair(false)
  end
end

function CM.OnCrosshairUncategorizedEvent()
  if CM.HideCrosshairWhileMounted() then
    SetCrosshairAppearance("mounted")
    lastKnownAppearanceState = "mounted"
    if IsMouselooking() then
      CM.DisplayCrosshair(false)
    end
  else
    lastKnownAppearanceState = nil
    CM.UpdateCrosshairReaction()
    if IsMouselooking() then
      if CM.DB.global.crosshair then
        CM.DisplayCrosshair(true)
      else
        CM.DisplayCrosshair(false)
      end
    end
  end
end

function CM.OnCrosshairFocusLockEvent(event)
  if event == "PLAYER_FOCUS_CHANGED" then
    if UnitExists("focus") and IsMouselooking() then
      CM.ShowCrosshairLockIn()
    end
    CM.UpdateCrosshairReaction()
  end
end

function CM.HideCrosshairFrame()
  CrosshairFrame:Hide()
end
