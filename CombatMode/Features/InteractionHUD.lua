---------------------------------------------------------------------------------------
--  Features/InteractionHUD.lua — INTERACTION HUD — soft-interact icon + label UI
---------------------------------------------------------------------------------------
--  Owns the Interaction HUD widget displayed near the crosshair when a soft-interact
--  target is present. Includes:
--    • Frame creation and layout relative to the crosshair
--    • Secret-string-safe name handling (Retail 12.x)
--    • Fade-in/out and range-based dimming (OnUpdate)
--    • Soft-interact change event handling
--
--  The crosshair frame is owned by Reticle and is registered via CM.InitInteractionHUD.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local GetUnitName = _G.GetUnitName
local SetUnitCursorTexture = _G.SetUnitCursorTexture
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitName = _G.UnitName
local UnitNameUnmodified = _G.UnitNameUnmodified

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local math = _G.math
local strfind = _G.string.find
local tostring = _G.tostring
local type = _G.type

local crosshairFrame
local crosshairTexture

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
local IH_NAME_COLOR = { 1, 204 / 255, 0 }
local IH_NAME_OPACITY = 0.8
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

local IH_CURSOR_UNABLE = (CM.Constants and CM.Constants.InteractionHUDUnableCursor) or {}

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
  InteractionHUDLabel:SetPoint(
    "CENTER",
    InteractionHUDIcon,
    "CENTER",
    IH_ICON / 2 + IH_GAP + lw / 2,
    0
  )
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
  LayoutInteractionHUDChildren(sw)
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
  local x = (crosshairSize / 2) + IH_OFFSET_X
  InteractionHUDCluster:ClearAllPoints()
  InteractionHUDCluster:SetPoint("LEFT", crosshairFrame, "CENTER", x, 0)
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
  if
    not g
    or g.interactionHUD ~= true
    or not CM.IsCrosshairEnabled()
    or not InteractionHUDIcon
    or not InteractionHUDLabel
  then
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
  -- Range dimming applies to the icon only; name stays white (scaled by crosshair opacity).
  local iconAlpha = dim * crosshairOpacity
  InteractionHUDLabel:SetTextColor(IH_NAME_COLOR[1], IH_NAME_COLOR[2], IH_NAME_COLOR[3], 1)
  InteractionHUDShadow:SetAlpha(crosshairOpacity * IH_SHADOW_ALPHA)
  InteractionHUDIcon:SetAlpha(iconAlpha)
  InteractionHUDLabel:SetAlpha(crosshairOpacity * IH_NAME_OPACITY)
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

  ApplyInteractionHUDLabelFont()
  CM.ApplyInteractionHUDLayout()
  InteractionHUDCluster:SetAlpha(0)
  ihClusterFade = 0
  ihClusterFadeTarget = 0
  InteractionHUDCluster:SetScript("OnUpdate", function(_, elapsed)
    UpdateInteractionHUDVisual(elapsed)
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
  if not (crosshairTexture and crosshairTexture.IsShown and crosshairTexture:IsShown()) then
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
