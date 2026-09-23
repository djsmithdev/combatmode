---------------------------------------------------------------------------------------
--  Core/AllyCycle/HUD.lua — ALLYCYCLE — crosshair companion for friendly hard target
---------------------------------------------------------------------------------------
--  What it does: Ally HUD beside the crosshair for a friendly hard target (or options preview).
--  Self is shown only when Skip Self is off; name reads "You".
--  Architecture / how it works:
--    • DB.global.allyCycle (side / scale / padding); layout / bar / role atlases
--      are locals in this file. Padding defaults to CrosshairCompanionOffsetX.
--    • Index from GetAllyCycleIndex; slide via NotifyAllyCycleHUD.
--    • Fades with Mouse Look (same cluster lerp as Interaction HUD); options preview
--      stays visible with mouselook off.
--    • Range alpha may be secret — SetAlpha raw, never multiply by slide/fade alpha.
--      Live range is UNIT_IN_RANGE_UPDATE (no per-frame EvaluateColorFromBoolean).
--    • Raid marker index may be secret — issecretvalue is presence; no Lua math.
--    • UNIT_HEALTH / UNIT_MAXHEALTH only retint the bar (low-HP red glow); chrome refresh is
--      target/role/marker/flags. No threat/aggro glow.
--    • OnUpdate is fade / slide / glow only; AnchorCluster and spark points are dirty-checked.
--    • CM.Profile keys: AllyHUD:OnUpdate / Refresh / Layout / HealthBar.
--  Does not: Own cycle bindings or targeting prelines.
--  Related: Core/AllyCycle/{Cycle,AllyCycle}.lua, Core/Crosshair/Crosshair.lua,
--  UI/Options/Tabs/TabAllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateColor = _G.CreateColor
local CreateFrame = _G.CreateFrame
local GetClassColor = _G.GetClassColor
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitHealthPercent = _G.UnitHealthPercent
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsUnit = _G.UnitIsUnit
local UnitInRange = _G.UnitInRange
local UnitName = _G.UnitName
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack
local GetRaidTargetIndex = _G.GetRaidTargetIndex
local SetRaidTargetIconTexture = _G.SetRaidTargetIconTexture
local CreateColorCurve = _G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve
local EvaluateColorFromBoolean = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorFromBoolean
local StatusBarInterpolation = _G.Enum and _G.Enum.StatusBarInterpolation
local HB_VALUE_INTERP = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local math = _G.math
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

local cluster
local nameFS
local indexFS
local healthBar
local UpdateHealthBar
local roleIcon
local raidMarker
local raidMarkerFrame
local hudShadow
local crosshairFrame
local eventsRegistered = false
local previewActive = false
local glowPulsePhase = 0
local pendingCycleDir = nil
local cycleAnim = nil
local cycleSlideY = 0
local cycleSlideA = 1
local lastRangeAlpha = 1
local lastAppliedClusterA = nil
local lastAnchorSide, lastAnchorScale, lastAnchorGap, lastAnchorOy
local hudFade = 0
local hudFadeTarget = 0
local HUD_FADE_SPEED = 16
local CONFIG_FALLBACK = { showHud = true, hudSide = "BOTTOM", scale = 1, padding = 24 }
local cycleAnimState = { elapsed = 0, dur = 0.14, fromY = 0, fromA = 0.75 }

local PREVIEW_MAX = 100
local PREVIEW_TOTAL = 4
local PREVIEW_STAGES = {
  { pct = 1.0, dead = false, raid = nil, index = 1, dwell = 1.0 },
  { pct = 0.7, dead = false, raid = 1, index = 2, dwell = 1.4 },
  { pct = 0.2, dead = false, raid = 8, index = 3, dwell = 1.8 },
  { pct = 0.0, dead = true, raid = nil, index = 4, dwell = 1.2 },
}
local previewStageIndex = 1
local previewStageElapsed = 0
local previewDisplayPct = 1
local PREVIEW_LERP_SEC = 0.4
local previewDead = false
local previewRaidIndex = nil
local previewIndex = 1

local LAYOUT = {
  roleIconSize = 20,
  nameFontSize = 11,
  nameMaxWidth = 120,
  nameLift = 6,
  gap = 2,
  companionOffset = (CM.Constants and CM.Constants.CrosshairCompanionOffsetX) or 24,
  shadowAtlas = "PetJournal-BattleSlot-Shadow",
  shadowAlpha = 0.7,
  shadowPadL = 56,
  shadowPadR = 56,
  shadowPadT = 36,
  shadowPadB = 28,
  -- Negative = down (WoW UI Y is up-positive).
  shadowShiftY = -10,
  outOfRangeAlpha = 0.3,
  raidMarkerSize = 16,
  raidMarkerLift = 4,
  indexGap = 2,
  indexFontSize = 10,
  -- Reserve width so the bar stays centered as "1/4" becomes "40/40".
  indexMinWidth = 28,
  cycleSlidePx = 3,
  cycleAnimSec = 0.14,
  cycleAnimFromAlpha = 0.75,
}

local HEALTH_BAR = {
  width = 72,
  height = 10,
  lowPct = 0.25,
  glowR = 1,
  glowG = 0.12,
  glowB = 0.08,
  glowPulsePeriod = 1.15,
  glowPulseMin = 0.35,
  glowPulseMax = 1.0,
  fillWhiteAtlas = "widgetstatusbar-fill-white",
}

local ROLE_ATLASES = {
  TANK = "UI-Frame-TankIcon",
  HEALER = "UI-Frame-HealerIcon",
  DAMAGER = "UI-Frame-DpsIcon",
  NONE = "UI-Frame-DpsIcon",
}

local function Layout()
  return LAYOUT
end

local function HB()
  return HEALTH_BAR
end

local function RoleAtlases()
  return ROLE_ATLASES
end

local function IsSecret(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end

local function PublicBool(v)
  if IsSecret(v) then
    return nil
  end
  if v == true then
    return true
  end
  if v == false then
    return false
  end
  return nil
end

local function PublicNumber(v, fallback)
  if v == nil or IsSecret(v) or type(v) ~= "number" then
    return fallback
  end
  return v
end

local function Config()
  local g = CM.DB and CM.DB.global and CM.DB.global.allyCycle
  local d = CM.Constants
    and CM.Constants.DatabaseDefaults
    and CM.Constants.DatabaseDefaults.global
    and CM.Constants.DatabaseDefaults.global.allyCycle
  return g or d or CONFIG_FALLBACK
end

local function InvalidateClusterLayout()
  lastAppliedClusterA = nil
  lastAnchorSide = nil
  lastAnchorScale = nil
  lastAnchorGap = nil
  lastAnchorOy = nil
end

local function ExtractColorRGBA(color)
  if not color then
    return nil
  end
  if color.GetRGBA then
    return color:GetRGBA()
  end
  if color.r then
    return color.r, color.g, color.b, color.a
  end
  return color[1], color[2], color[3], color[4]
end

local COLOR_HB_CRIT = CreateColor and CreateColor(1, 0.22, 0.12, 1)
local COLOR_HB_DMG = CreateColor and CreateColor(1, 0.85, 0.15, 1)
local COLOR_HB_OK = CreateColor and CreateColor(0.2, 0.85, 0.25, 1)
local COLOR_HB_DEAD = CreateColor and CreateColor(0.45, 0.45, 0.45, 1)

local HB_FILL_CURVE, HB_GLOW_CURVE, HB_SPARK_CURVE
do
  local cfg = HB()
  local lowPct = cfg.lowPct or 0.25
  if CreateColorCurve and COLOR_HB_CRIT then
    local stepType = _G.Enum and _G.Enum.LuaCurveType and _G.Enum.LuaCurveType.Step
    local yellowAt = lowPct + 1e-4
    local greenAt = 0.5 + 1e-4
    local glowOn = CreateColor(cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08, 1)
    local glowOff = CreateColor(cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08, 0)
    local sparkOn = CreateColor(1, 1, 1, 1)
    local sparkOff = CreateColor(1, 1, 1, 0)

    HB_FILL_CURVE = CreateColorCurve()
    if stepType then
      HB_FILL_CURVE:SetType(stepType)
    end
    HB_FILL_CURVE:AddPoint(0, COLOR_HB_CRIT)
    HB_FILL_CURVE:AddPoint(lowPct, COLOR_HB_CRIT)
    HB_FILL_CURVE:AddPoint(yellowAt, COLOR_HB_DMG)
    HB_FILL_CURVE:AddPoint(0.5, COLOR_HB_DMG)
    HB_FILL_CURVE:AddPoint(greenAt, COLOR_HB_OK)
    HB_FILL_CURVE:AddPoint(1, COLOR_HB_OK)

    HB_GLOW_CURVE = CreateColorCurve()
    if stepType then
      HB_GLOW_CURVE:SetType(stepType)
    end
    HB_GLOW_CURVE:AddPoint(0, glowOn)
    HB_GLOW_CURVE:AddPoint(lowPct, glowOn)
    HB_GLOW_CURVE:AddPoint(yellowAt, glowOff)
    HB_GLOW_CURVE:AddPoint(1, glowOff)

    HB_SPARK_CURVE = CreateColorCurve()
    if stepType then
      HB_SPARK_CURVE:SetType(stepType)
    end
    HB_SPARK_CURVE:AddPoint(0, sparkOff)
    HB_SPARK_CURVE:AddPoint(0.001, sparkOn)
    HB_SPARK_CURVE:AddPoint(0.999, sparkOn)
    HB_SPARK_CURVE:AddPoint(1, sparkOff)
  end
end

-- Encode range in ColorMixin alpha so secret UnitInRange never enters a Lua compare.
local COLOR_IN_RANGE = CreateColor and CreateColor(1, 1, 1, 1)
local COLOR_OUT_OF_RANGE = CreateColor and CreateColor(1, 1, 1, Layout().outOfRangeAlpha or 0.3)

local function ResetCycleAnim()
  pendingCycleDir = nil
  cycleAnim = nil
  cycleSlideY = 0
  cycleSlideA = 1
end

local function AnchorCluster(offsetY)
  if not cluster or not crosshairFrame then
    return
  end
  local cfg = Config()
  local side = cfg.hudSide or "BOTTOM"
  local L = Layout()
  local crosshairSize = (CM.GetCrosshairPixelSize and CM.GetCrosshairPixelSize()) or 64
  local pad = tonumber(cfg.padding)
  if pad == nil then
    pad = L.companionOffset or 24
  end
  if pad < 0 then
    pad = 0
  elseif pad > 128 then
    pad = 128
  end
  local gap = (crosshairSize / 2) + pad
  local scale = cfg.scale or 1
  local oy = offsetY or 0
  if
    side == lastAnchorSide
    and scale == lastAnchorScale
    and gap == lastAnchorGap
    and oy == lastAnchorOy
  then
    return
  end
  lastAnchorSide = side
  lastAnchorScale = scale
  lastAnchorGap = gap
  lastAnchorOy = oy
  cluster:SetScale(scale)
  cluster:ClearAllPoints()
  if side == "LEFT" then
    cluster:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, oy)
  elseif side == "RIGHT" then
    cluster:SetPoint("LEFT", crosshairFrame, "CENTER", gap, oy)
  elseif side == "BOTTOM" then
    cluster:SetPoint("TOP", crosshairFrame, "CENTER", 0, -gap + oy)
  else
    cluster:SetPoint("BOTTOM", crosshairFrame, "CENTER", 0, gap + oy)
  end
end

-- SetAlpha accepts secret range alpha; Lua * does not.
local function ApplyClusterAlpha()
  if not cluster then
    return
  end
  local slideA = PublicNumber(cycleSlideA, 1)
  local fadeA = PublicNumber(hudFade, 1)
  if IsSecret(lastRangeAlpha) then
    lastAppliedClusterA = nil
    if fadeA >= 0.999 and slideA >= 0.999 then
      cluster:SetAlpha(lastRangeAlpha)
    else
      cluster:SetAlpha(fadeA * slideA)
    end
    return
  end
  local a = PublicNumber(lastRangeAlpha, 1) * slideA * fadeA
  if a == lastAppliedClusterA then
    return
  end
  lastAppliedClusterA = a
  cluster:SetAlpha(a)
end

local function ApplyClusterVisual()
  ApplyClusterAlpha()
  AnchorCluster(cycleSlideY)
end

local function TickHudFade(elapsed)
  if not cluster then
    return
  end
  if math.abs(hudFade - hudFadeTarget) <= 0.001 then
    hudFade = hudFadeTarget
    if hudFadeTarget == 0 and hudFade <= 0.001 and cluster:IsShown() then
      hudFade = 0
      ResetCycleAnim()
      lastRangeAlpha = 1
      InvalidateClusterLayout()
      cluster:Hide()
    end
    return
  end
  local dt = (elapsed and elapsed > 0) and elapsed or (1 / 60)
  local step = math.min(1, dt * HUD_FADE_SPEED)
  hudFade = hudFade + (hudFadeTarget - hudFade) * step
  if math.abs(hudFade - hudFadeTarget) < 0.01 then
    hudFade = hudFadeTarget
  end
  ApplyClusterVisual()
  if hudFadeTarget == 0 and hudFade <= 0.001 then
    hudFade = 0
    ResetCycleAnim()
    lastRangeAlpha = 1
    InvalidateClusterLayout()
    cluster:Hide()
  end
end

local function RequestHudHide()
  hudFadeTarget = 0
  if not cluster or not cluster:IsShown() then
    hudFade = 0
    ResetCycleAnim()
    lastRangeAlpha = 1
    InvalidateClusterLayout()
    if cluster then
      cluster:Hide()
    end
    return
  end
  if hudFade <= 0.001 then
    hudFade = 0
    ResetCycleAnim()
    lastRangeAlpha = 1
    InvalidateClusterLayout()
    cluster:Hide()
  end
end

local function RequestHudShow()
  hudFadeTarget = 1
  if cluster then
    cluster:Show()
  end
end

local function StartCycleAnim(dir)
  local L = Layout()
  local px = L.cycleSlidePx or 3
  cycleAnimState.elapsed = 0
  cycleAnimState.dur = L.cycleAnimSec or 0.14
  cycleAnimState.fromY = (dir == "down") and px or -px
  cycleAnimState.fromA = L.cycleAnimFromAlpha or 0.75
  cycleAnim = cycleAnimState
  cycleSlideY = cycleAnim.fromY
  cycleSlideA = cycleAnim.fromA
  ApplyClusterVisual()
end

local function TickCycleAnim(elapsed)
  if not cycleAnim then
    return
  end
  local dur = cycleAnim.dur
  if type(dur) ~= "number" or dur <= 0 then
    cycleAnim = nil
    cycleSlideY = 0
    cycleSlideA = 1
    ApplyClusterVisual()
    return
  end
  cycleAnim.elapsed = cycleAnim.elapsed + (elapsed or 0)
  local t = math.min(1, cycleAnim.elapsed / dur)
  local eased = 1 - (1 - t) * (1 - t)
  cycleSlideY = cycleAnim.fromY * (1 - eased)
  cycleSlideA = cycleAnim.fromA + (1 - cycleAnim.fromA) * eased
  ApplyClusterVisual()
  if t >= 1 then
    cycleAnim = nil
    cycleSlideY = 0
    cycleSlideA = 1
    ApplyClusterVisual()
  end
end

function CM.NotifyAllyCycleHUD(direction)
  if direction == "down" then
    pendingCycleDir = "down"
  else
    pendingCycleDir = "up"
  end
end

local function ApplyRangeAlpha(unit)
  if not cluster then
    return
  end
  local outA = (Layout().outOfRangeAlpha or 0.3)
  if previewActive or not unit or unit == "player" or not UnitExists(unit) then
    lastRangeAlpha = 1
    ApplyClusterAlpha()
    return
  end
  if not UnitInRange then
    lastRangeAlpha = 1
    ApplyClusterAlpha()
    return
  end
  local inRange = UnitInRange(unit)
  if IsSecret(inRange) then
    -- Secret boolean: encode in ColorMixin alpha; never Lua-compare the flag.
    if EvaluateColorFromBoolean and COLOR_IN_RANGE and COLOR_OUT_OF_RANGE then
      local rangeColor = EvaluateColorFromBoolean(inRange, COLOR_IN_RANGE, COLOR_OUT_OF_RANGE)
      if rangeColor and rangeColor.a ~= nil then
        lastRangeAlpha = rangeColor.a
        ApplyClusterAlpha()
        return
      end
    end
    lastRangeAlpha = 1
    ApplyClusterAlpha()
    return
  end
  lastRangeAlpha = (inRange == false) and outA or 1
  ApplyClusterAlpha()
end

function CM.IsAllyCycleFriendlyHardTarget()
  if not UnitExists("target") then
    return false
  end
  if UnitIsUnit and UnitIsUnit("target", "player") then
    if not CM.IsAllyCycleSkipPlayer or CM.IsAllyCycleSkipPlayer() then
      return false
    end
    return true
  end
  local attack = UnitCanAttack and UnitCanAttack("player", "target")
  local pubAttack = PublicBool(attack)
  if pubAttack == true then
    return false
  end
  local assist = UnitCanAssist and UnitCanAssist("player", "target")
  local pubAssist = PublicBool(assist)
  if pubAssist == false then
    return false
  end
  if pubAssist == true then
    return true
  end
  return false
end

function CM.IsAllyCycleOptionsPreviewActive()
  return previewActive
end

function CM.SetAllyCycleOptionsPreview(enabled)
  enabled = enabled and true or false
  if previewActive == enabled then
    return
  end
  previewActive = enabled
  if enabled then
    previewStageIndex = 1
    previewStageElapsed = 0
    previewDisplayPct = PREVIEW_STAGES[1].pct
    previewDead = false
    previewRaidIndex = nil
    previewIndex = PREVIEW_STAGES[1].index or 1
  end
  if CM.SetCrosshairOptionsPreview then
    CM.SetCrosshairOptionsPreview(enabled)
  end
  CM.RefreshAllyCycleHUD()
end

local function ResolveRoleAtlas(unit)
  local atlases = RoleAtlases()
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
  if IsSecret(role) or type(role) ~= "string" or role == "" then
    role = "NONE"
  end
  return atlases[role] or atlases.DAMAGER or atlases.NONE
end

local function UpdateRoleIcon(unit)
  if not roleIcon then
    return
  end
  local atlas = ResolveRoleAtlas(unit)
  if atlas and roleIcon.SetAtlas then
    roleIcon:SetAtlas(atlas)
    roleIcon:Show()
  else
    roleIcon:Hide()
  end
end

local function ClassRGB(unit)
  local _, classFile = UnitClass(unit)
  if IsSecret(classFile) or type(classFile) ~= "string" then
    return 1, 1, 1
  end
  if GetClassColor then
    local r, g, b = GetClassColor(classFile)
    if r then
      return r, g, b
    end
  end
  return 1, 1, 1
end

-- FontString has no SetDesaturated — grey name/index instead.
local function ApplyDeadChrome(dead)
  dead = dead and true or false
  if healthBar then
    if healthBar.SetStatusBarDesaturated then
      healthBar:SetStatusBarDesaturated(dead)
    end
    local fillTex = healthBar:GetStatusBarTexture()
    if fillTex and fillTex.SetDesaturated then
      fillTex:SetDesaturated(dead)
    end
  end
  if roleIcon and roleIcon.SetDesaturated then
    roleIcon:SetDesaturated(dead)
  end
  if raidMarker and raidMarker.SetDesaturated then
    raidMarker:SetDesaturated(dead)
  end
  if indexFS then
    if dead then
      indexFS:SetTextColor(0.55, 0.55, 0.55, 1)
    else
      indexFS:SetTextColor(0.85, 0.85, 0.85, 1)
    end
  end
end

local function ApplyNameColor(unit, dead)
  if not nameFS then
    return
  end
  if dead then
    nameFS:SetTextColor(0.55, 0.55, 0.55, 1)
    return
  end
  if unit then
    local r, g, b = ClassRGB(unit)
    nameFS:SetTextColor(r, g, b, 1)
  else
    nameFS:SetTextColor(1, 1, 1, 1)
  end
end

-- Blizzard UI-RaidTargetingIcons sheet (4×4). SetRaidTargetIconTexture accepts secret indices.
local RAID_TARGET_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
local RAID_TARGET_TEXTURE_ROWS = 4
local RAID_TARGET_TEXTURE_COLUMNS = 4

local function SetRaidMarkerShown(shown)
  if raidMarker then
    raidMarker:SetShown(shown)
  end
  if raidMarkerFrame then
    raidMarkerFrame:SetShown(shown)
  end
end

local function UpdateRaidMarker(unit)
  if not raidMarker then
    return
  end
  local idx
  if previewActive then
    idx = previewRaidIndex
  elseif unit and UnitExists(unit) and GetRaidTargetIndex then
    idx = GetRaidTargetIndex(unit)
  end

  -- Under taint, a present marker is a *secret* number (issecretvalue = presence).
  -- Never truth-test / compare / arithmetic the index in Lua.
  local hasMarker = IsSecret(idx) or (type(idx) == "number" and idx >= 1 and idx <= 8)
  if not hasMarker then
    SetRaidMarkerShown(false)
    return
  end

  raidMarker:SetTexture(RAID_TARGET_TEXTURE)
  if SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(raidMarker, idx)
  elseif raidMarker.SetSpriteSheetCell then
    raidMarker:SetSpriteSheetCell(idx, RAID_TARGET_TEXTURE_ROWS, RAID_TARGET_TEXTURE_COLUMNS)
  else
    SetRaidMarkerShown(false)
    return
  end
  SetRaidMarkerShown(true)
end

local function UpdateIndex(unit)
  if not indexFS then
    return
  end
  local current, total
  if previewActive then
    current = previewIndex or 1
    total = PREVIEW_TOTAL
  elseif CM.GetAllyCycleIndex then
    current, total = CM.GetAllyCycleIndex(unit)
  end
  if type(total) ~= "number" or total < 1 then
    indexFS:SetText("")
    indexFS:Hide()
    return
  end
  local curText = "?"
  if type(current) == "number" and current >= 1 then
    curText = tostring(current)
  end
  indexFS:SetText(curText .. "/" .. tostring(total))
  indexFS:Show()
end

local function LayoutShadowTexture(tex, L)
  if not tex then
    return
  end
  local padL = L.shadowPadL or 56
  local padR = L.shadowPadR or 56
  local padT = L.shadowPadT or 36
  local padB = L.shadowPadB or 28
  local shiftY = L.shadowShiftY or -10
  tex:ClearAllPoints()
  tex:SetPoint("TOPLEFT", cluster, "TOPLEFT", -padL, padT + shiftY)
  tex:SetPoint("BOTTOMRIGHT", cluster, "BOTTOMRIGHT", padR, -padB + shiftY)
end

local function SyncBarGlow(unit)
  if not healthBar then
    return
  end
  local dead = previewActive and previewDead
    or (unit and UnitIsDeadOrGhost and PublicBool(UnitIsDeadOrGhost(unit)) == true)
  if dead then
    healthBar.glowBaseA = 0
  else
    healthBar.glowBaseA = healthBar.healthGlowA or 0
  end
end

local function CreateHealthBarLCR(
  bar,
  drawLayer,
  subLevel,
  leftAtlas,
  centerAtlas,
  rightAtlas,
  endW,
  height,
  xOff
)
  local left = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  left:SetAtlas(leftAtlas, false)
  left:SetSize(endW, height)
  left:SetPoint("LEFT", bar, "LEFT", -xOff, 0)

  local right = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  right:SetAtlas(rightAtlas, false)
  right:SetSize(endW, height)
  right:SetPoint("RIGHT", bar, "RIGHT", xOff, 0)

  local center = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  center:SetAtlas(centerAtlas, false)
  center:SetHeight(height)
  center:SetPoint("LEFT", left, "RIGHT")
  center:SetPoint("RIGHT", right, "LEFT")

  return left, center, right
end

local function ApplyHealthBarFill(bar, atlas)
  bar:SetStatusBarTexture(atlas)
  local fillTex = bar:GetStatusBarTexture()
  if fillTex then
    if fillTex.SetAtlas then
      fillTex:SetAtlas(atlas, false)
    end
    fillTex:SetHorizTile(true)
  end
  return fillTex
end

local function CreateAllyHealthBar(parent)
  local cfg = HB()
  local barW = cfg.width or 72
  local barH = cfg.height or 10
  local scale = barH / 15
  local borderX = math.floor(8 * scale + 0.5)
  local bgX = math.max(1, math.floor(2 * scale + 0.5))
  local borderH = math.floor(31 * scale + 0.5)
  local borderEndW = math.floor(35 * scale + 0.5)
  local bgH = math.floor(18 * scale + 0.5)
  local bgEndW = math.floor(29 * scale + 0.5)
  local fillAtlas = cfg.fillWhiteAtlas or "widgetstatusbar-fill-white"
  local glowR, glowG, glowB = cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08

  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(barW, barH)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar._fillTex = ApplyHealthBarFill(bar, fillAtlas)
  if COLOR_HB_OK then
    bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
  end

  CreateHealthBarLCR(
    bar,
    "BACKGROUND",
    0,
    "widgetstatusbar-bgleft",
    "widgetstatusbar-bgcenter",
    "widgetstatusbar-bgright",
    bgEndW,
    bgH,
    bgX
  )
  local borderLeft, _, borderRight = CreateHealthBarLCR(
    bar,
    "OVERLAY",
    1,
    "widgetstatusbar-borderleft",
    "widgetstatusbar-bordercenter",
    "widgetstatusbar-borderright",
    borderEndW,
    borderH,
    borderX
  )

  local glowFrame = CreateFrame("Frame", nil, bar)
  glowFrame:SetAllPoints(bar)
  glowFrame:Hide()
  bar.glowFrame = glowFrame

  local function MakeGlow(atlas, point, relative)
    local tex = glowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    tex:SetAtlas(atlas, false)
    tex:SetSize(borderEndW, borderH)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(glowR, glowG, glowB, 1)
    tex:SetPoint(point, relative)
    tex:Hide()
    return tex
  end
  local glowLeft = MakeGlow("widgetstatusbar-glowleft", "LEFT", borderLeft)
  local glowRight = MakeGlow("widgetstatusbar-glowright", "RIGHT", borderRight)
  local glowCenter = glowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
  glowCenter:SetAtlas("widgetstatusbar-glowcenter", false)
  glowCenter:SetBlendMode("ADD")
  glowCenter:SetVertexColor(glowR, glowG, glowB, 1)
  glowCenter:SetHeight(borderH)
  glowCenter:SetPoint("LEFT", glowLeft, "RIGHT")
  glowCenter:SetPoint("RIGHT", glowRight, "LEFT")
  glowCenter:Hide()
  bar.glowLeft = glowLeft
  bar.glowCenter = glowCenter
  bar.glowRight = glowRight

  local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
  spark:SetAtlas("widgetstatusbar-spark", false)
  spark:SetSize(6, barH + 4)
  spark:SetBlendMode("ADD")
  spark:Hide()
  bar.spark = spark

  return bar
end

local function SetHealthBarGlowShown(bar, shown)
  if not bar then
    return
  end
  if bar.glowLeft then
    bar.glowLeft:SetShown(shown)
  end
  if bar.glowCenter then
    bar.glowCenter:SetShown(shown)
  end
  if bar.glowRight then
    bar.glowRight:SetShown(shown)
  end
end

local function HideBarGlow(bar)
  if not bar then
    return
  end
  bar.healthGlowA = 0
  bar.glowBaseA = 0
  if bar.glowFrame then
    bar.glowFrame:Hide()
  end
  SetHealthBarGlowShown(bar, false)
end

local function ApplyGlowPulse(bar, pulseA)
  if not bar or not bar.glowFrame then
    return
  end
  local baseA = bar.glowBaseA
  if not (issecretvalue and issecretvalue(baseA)) and type(baseA) == "number" and baseA <= 0 then
    bar.glowFrame:Hide()
    return
  end
  local cfg = HB()
  local r, g, b = cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08
  bar.glowLeft:SetVertexColor(r, g, b, baseA)
  bar.glowCenter:SetVertexColor(r, g, b, baseA)
  bar.glowRight:SetVertexColor(r, g, b, baseA)
  bar.glowFrame:SetAlpha(pulseA)
  SetHealthBarGlowShown(bar, true)
  bar.glowFrame:Show()
end

local function PinSparkToFill()
  local fillTex = healthBar and (healthBar._fillTex or healthBar:GetStatusBarTexture())
  if fillTex and healthBar.spark then
    healthBar._fillTex = fillTex
    if not healthBar._sparkPinned then
      healthBar.spark:ClearAllPoints()
      healthBar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
      healthBar._sparkPinned = true
    end
  end
end

local function ApplyPublicHealthAppearance(pct, dead)
  if not healthBar then
    return
  end
  local cfg = HB()
  local lowPct = cfg.lowPct or 0.25

  if dead or pct <= 0 then
    healthBar:SetMinMaxValues(0, PREVIEW_MAX)
    healthBar:SetValue(0)
    if COLOR_HB_DEAD then
      healthBar:SetStatusBarColor(COLOR_HB_DEAD:GetRGBA())
    end
    HideBarGlow(healthBar)
    if healthBar.spark then
      healthBar.spark:Hide()
    end
    healthBar._hbHasValue = true
    ApplyDeadChrome(true)
    return
  end

  ApplyDeadChrome(false)

  local health = PREVIEW_MAX * pct
  if HB_VALUE_INTERP and healthBar._hbHasValue then
    healthBar:SetMinMaxValues(0, PREVIEW_MAX, HB_VALUE_INTERP)
    healthBar:SetValue(health, HB_VALUE_INTERP)
  else
    healthBar:SetMinMaxValues(0, PREVIEW_MAX)
    healthBar:SetValue(health)
  end
  healthBar._hbHasValue = true

  if pct <= lowPct then
    if COLOR_HB_CRIT then
      healthBar:SetStatusBarColor(COLOR_HB_CRIT:GetRGBA())
    end
    healthBar.healthGlowA = 1
  elseif pct <= 0.5 then
    if COLOR_HB_DMG then
      healthBar:SetStatusBarColor(COLOR_HB_DMG:GetRGBA())
    end
    healthBar.healthGlowA = 0
  else
    if COLOR_HB_OK then
      healthBar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    end
    healthBar.healthGlowA = 0
  end
  healthBar.glowBaseA = healthBar.healthGlowA

  if healthBar.glowBaseA == 0 and healthBar.glowFrame then
    healthBar.glowFrame:Hide()
    SetHealthBarGlowShown(healthBar, false)
  end

  PinSparkToFill()
  if healthBar.spark then
    healthBar.spark:SetVertexColor(1, 1, 1, 1)
    healthBar.spark:SetAlpha(1)
    healthBar.spark:SetShown(pct > 0 and pct < 1)
  end
end

local function TickPreviewHealth(elapsed)
  if not healthBar then
    return
  end
  local stage = PREVIEW_STAGES[previewStageIndex] or PREVIEW_STAGES[1]
  previewStageElapsed = previewStageElapsed + elapsed

  local targetPct = stage.pct
  local t = math.min(1, previewStageElapsed / PREVIEW_LERP_SEC)
  t = t * t * (3 - 2 * t) -- smoothstep
  if previewStageElapsed <= PREVIEW_LERP_SEC then
    local startPct = healthBar._previewStartPct
    if startPct == nil then
      startPct = previewDisplayPct
      healthBar._previewStartPct = startPct
    end
    previewDisplayPct = startPct + (targetPct - startPct) * t
  else
    previewDisplayPct = targetPct
    healthBar._previewStartPct = nil
  end

  local nowDead = stage.dead and previewStageElapsed > PREVIEW_LERP_SEC
  ApplyPublicHealthAppearance(previewDisplayPct, nowDead)
  if nowDead ~= previewDead then
    previewDead = nowDead
    ApplyNameColor("player", previewDead)
  end
  previewDead = nowDead
  SyncBarGlow("player")

  if previewStageElapsed >= stage.dwell then
    previewStageElapsed = 0
    healthBar._previewStartPct = previewDisplayPct
    previewStageIndex = previewStageIndex + 1
    if previewStageIndex > #PREVIEW_STAGES then
      previewStageIndex = 1
    end
    local nextStage = PREVIEW_STAGES[previewStageIndex] or PREVIEW_STAGES[1]
    previewIndex = nextStage.index or 1
    previewRaidIndex = nextStage.raid
    UpdateIndex("player")
    UpdateRaidMarker("player")
    StartCycleAnim("up")
  end
end

local function OnHudUpdateImpl(_, elapsed)
  TickHudFade(elapsed)
  if not cluster or not cluster:IsShown() then
    return
  end
  TickCycleAnim(elapsed)
  if previewActive then
    TickPreviewHealth(elapsed)
  end
  if not healthBar then
    return
  end
  local cfg = HB()
  local period = cfg.glowPulsePeriod or 1.15
  glowPulsePhase = glowPulsePhase + elapsed / period
  if glowPulsePhase >= 1 then
    glowPulsePhase = glowPulsePhase - math.floor(glowPulsePhase)
  end
  local wave = 0.5 - 0.5 * math.cos(glowPulsePhase * math.pi * 2)
  local pulseA = (cfg.glowPulseMin or 0.35)
    + ((cfg.glowPulseMax or 1) - (cfg.glowPulseMin or 0.35)) * wave
  ApplyGlowPulse(healthBar, pulseA)
end

local function OnHudUpdate(self, elapsed)
  CM.Profile("AllyHUD:OnUpdate", OnHudUpdateImpl, self, elapsed)
end

local function OnHudEvent(_, event, unit)
  if
    event == "PLAYER_TARGET_CHANGED"
    or event == "PLAYER_ROLES_ASSIGNED"
    or event == "RAID_TARGET_UPDATE"
  then
    CM.RefreshAllyCycleHUD()
    return
  end
  if event == "UNIT_IN_RANGE_UPDATE" and unit == "target" then
    if cluster and cluster:IsShown() and not previewActive then
      ApplyRangeAlpha("target")
    end
    return
  end
  if event == "UNIT_FLAGS" and (unit == "target" or unit == "player") then
    CM.RefreshAllyCycleHUD()
    return
  end
  if
    (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH")
    and unit == "target"
    and cluster
    and cluster:IsShown()
    and not previewActive
  then
    UpdateHealthBar("target")
  end
end

local function EnsureFrames()
  if not crosshairFrame then
    return
  end
  local L = Layout()
  local cfg = HB()

  if not cluster then
    cluster = CreateFrame("Frame", "CombatModeAllyCycleHUD", crosshairFrame)
    cluster:SetFrameStrata(crosshairFrame:GetFrameStrata())
    cluster:SetFrameLevel(crosshairFrame:GetFrameLevel() + 2)
    cluster:Hide()

    hudShadow = cluster:CreateTexture(nil, "BACKGROUND")
    hudShadow:SetDrawLayer("BACKGROUND", -1)
    hudShadow:SetAtlas(L.shadowAtlas or "PetJournal-BattleSlot-Shadow")
    hudShadow:SetBlendMode("BLEND")
    hudShadow:SetVertexColor(0, 0, 0, 1)
    hudShadow:SetAlpha(L.shadowAlpha or 0.7)

    local iconS = L.roleIconSize or 20
    roleIcon = cluster:CreateTexture(nil, "OVERLAY")
    roleIcon:SetDrawLayer("OVERLAY", 0)
    roleIcon:SetSize(iconS, iconS)

    nameFS = cluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetJustifyH("CENTER")
    nameFS:SetWordWrap(false)
    if CM.SetFontStringFromTemplate then
      CM.SetFontStringFromTemplate(nameFS, L.nameFontSize or 11, _G.GameFontNormalSmall)
    end
    nameFS:SetShadowColor(0, 0, 0, 1)
    nameFS:SetShadowOffset(1, -1)

    indexFS = cluster:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    indexFS:SetJustifyH("CENTER")
    indexFS:SetWordWrap(false)
    if CM.SetFontStringFromTemplate then
      CM.SetFontStringFromTemplate(indexFS, L.indexFontSize or 10, _G.GameFontNormalSmall)
    end
    indexFS:SetShadowColor(0, 0, 0, 1)
    indexFS:SetShadowOffset(1, -1)
    indexFS:SetTextColor(0.85, 0.85, 0.85, 1)

    healthBar = CreateAllyHealthBar(cluster)
    healthBar:SetSize(cfg.width or 72, cfg.height or 10)

    local markerS = L.raidMarkerSize or 14
    raidMarkerFrame = CreateFrame("Frame", nil, cluster)
    raidMarkerFrame:SetSize(markerS, markerS)
    raidMarkerFrame:SetFrameLevel(healthBar:GetFrameLevel() + 5)
    raidMarker = raidMarkerFrame:CreateTexture(nil, "OVERLAY")
    raidMarker:SetAllPoints(raidMarkerFrame)
    raidMarker:SetTexture(RAID_TARGET_TEXTURE)
    raidMarker:Hide()
  end

  if not eventsRegistered and cluster then
    eventsRegistered = true
    cluster:RegisterEvent("PLAYER_TARGET_CHANGED")
    cluster:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    cluster:RegisterEvent("RAID_TARGET_UPDATE")
    cluster:RegisterUnitEvent("UNIT_HEALTH", "target", "player")
    cluster:RegisterUnitEvent("UNIT_MAXHEALTH", "target", "player")
    cluster:RegisterUnitEvent("UNIT_FLAGS", "target", "player")
    cluster:RegisterUnitEvent("UNIT_IN_RANGE_UPDATE", "target")
    cluster:SetScript("OnEvent", OnHudEvent)
    cluster:SetScript("OnUpdate", OnHudUpdate)
  end
end

local function MeasureNameWidth()
  local L = Layout()
  local nameMaxW = L.nameMaxWidth or 120
  if not nameFS then
    return nameMaxW
  end
  nameFS:SetWidth(0)
  local sw = nameFS.GetUnboundedStringWidth and nameFS:GetUnboundedStringWidth()
    or nameFS:GetStringWidth()
  if IsSecret(sw) or type(sw) ~= "number" or sw < 1 then
    return nameMaxW
  end
  if sw > nameMaxW then
    return nameMaxW
  end
  return sw
end

local function MeasureIndexWidth()
  local L = Layout()
  local minW = L.indexMinWidth or 28
  if not indexFS or not indexFS:IsShown() then
    return 0
  end
  indexFS:SetWidth(0)
  local sw = indexFS.GetUnboundedStringWidth and indexFS:GetUnboundedStringWidth()
    or indexFS:GetStringWidth()
  if IsSecret(sw) or type(sw) ~= "number" or sw < 1 then
    return minW
  end
  if sw < minW then
    return minW
  end
  return sw
end

local function LayoutChildren()
  if not cluster or not nameFS or not healthBar or not roleIcon or not raidMarkerFrame then
    return
  end
  local L = Layout()
  local cfg = HB()
  local gap = L.gap or 2
  local indexGap = L.indexGap
  if type(indexGap) ~= "number" then
    indexGap = gap * 2
  end
  local nameLift = L.nameLift or 6
  local iconS = L.roleIconSize or 20
  local markerS = L.raidMarkerSize or 14
  local barW = cfg.width or 72
  local barH = cfg.height or 10
  local nameH = (L.nameFontSize or 11) + 2
  local indexH = (L.indexFontSize or 10) + 2
  local indexW = MeasureIndexWidth()
  local rowH = math.max(iconS, barH, indexH)
  local sidePad = math.max(iconS + gap, indexW > 0 and (indexW + indexGap) or 0)
  local nameW = MeasureNameWidth()
  nameFS:SetWidth(nameW)
  nameFS:SetHeight(nameH)

  roleIcon:ClearAllPoints()
  raidMarkerFrame:ClearAllPoints()
  nameFS:ClearAllPoints()
  healthBar:ClearAllPoints()
  if indexFS then
    indexFS:ClearAllPoints()
    indexFS:SetWidth(indexW > 0 and indexW or (L.indexMinWidth or 28))
    indexFS:SetHeight(indexH)
  end

  roleIcon:SetSize(iconS, iconS)
  raidMarkerFrame:SetSize(markerS, markerS)
  raidMarkerFrame:SetFrameLevel(cluster:GetFrameLevel() + 6)
  healthBar:SetSize(barW, barH)

  local totalW = math.max(nameW, barW + sidePad * 2)
  local totalH = nameH + nameLift + gap + rowH
  cluster:SetSize(totalW, totalH)

  nameFS:SetPoint("TOP", cluster, "TOP", 0, 0)
  local markerLift = L.raidMarkerLift
  if type(markerLift) ~= "number" then
    markerLift = 4
  end
  raidMarkerFrame:SetPoint("BOTTOM", nameFS, "TOP", 0, markerLift)
  healthBar:SetPoint("TOP", nameFS, "BOTTOM", 0, -(nameLift + gap))
  roleIcon:SetPoint("RIGHT", healthBar, "LEFT", -gap, 0)
  if indexFS then
    indexFS:SetPoint("LEFT", healthBar, "RIGHT", indexGap, 0)
  end

  LayoutShadowTexture(hudShadow, L)
  if hudShadow then
    hudShadow:SetAlpha(L.shadowAlpha or 0.7)
    hudShadow:Show()
  end
end

local function ApplyAllyCycleHUDLayoutImpl()
  EnsureFrames()
  if not cluster or not crosshairFrame then
    return
  end
  LayoutChildren()
  AnchorCluster(cycleSlideY)
end

function CM.ApplyAllyCycleHUDLayout()
  return CM.Profile("AllyHUD:Layout", ApplyAllyCycleHUDLayoutImpl)
end

local function UpdateHealthBarImpl(unit)
  if not healthBar then
    return
  end

  local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
  local pubDead = PublicBool(dead)
  if pubDead == true then
    healthBar:SetMinMaxValues(0, 1)
    healthBar:SetValue(0)
    if COLOR_HB_DEAD then
      healthBar:SetStatusBarColor(COLOR_HB_DEAD:GetRGBA())
    end
    HideBarGlow(healthBar)
    if healthBar.spark then
      healthBar.spark:Hide()
    end
    healthBar._hbHasValue = true
    healthBar._lastH = nil
    healthBar._lastM = nil
    ApplyDeadChrome(true)
    return
  end

  ApplyDeadChrome(false)

  local health = UnitHealth and UnitHealth(unit, true)
  local maxHealth = UnitHealthMax and UnitHealthMax(unit)
  local pubH = PublicNumber(health, nil)
  local pubM = PublicNumber(maxHealth, nil)
  if pubH and pubM and pubH == healthBar._lastH and pubM == healthBar._lastM then
    return
  end
  if pubH then
    healthBar._lastH = pubH
  end
  if pubM then
    healthBar._lastM = pubM
  end

  if health ~= nil and maxHealth ~= nil then
    if HB_VALUE_INTERP and healthBar._hbHasValue then
      healthBar:SetMinMaxValues(0, maxHealth, HB_VALUE_INTERP)
      healthBar:SetValue(health, HB_VALUE_INTERP)
    else
      healthBar:SetMinMaxValues(0, maxHealth)
      healthBar:SetValue(health)
    end
    healthBar._hbHasValue = true
  end

  if UnitHealthPercent and HB_FILL_CURVE then
    local fillColor = UnitHealthPercent(unit, true, HB_FILL_CURVE)
    local fr, fg, fb, fa = ExtractColorRGBA(fillColor)
    if fr then
      healthBar:SetStatusBarColor(fr, fg, fb, fa)
    end
    local glowColor = UnitHealthPercent(unit, true, HB_GLOW_CURVE)
    local _, _, _, glowA = ExtractColorRGBA(glowColor)
    healthBar.healthGlowA = glowA or 0
    healthBar.glowBaseA = healthBar.healthGlowA
    PinSparkToFill()
    if HB_SPARK_CURVE and healthBar.spark then
      local sparkColor = UnitHealthPercent(unit, true, HB_SPARK_CURVE)
      local _, _, _, sparkA = ExtractColorRGBA(sparkColor)
      healthBar.spark:SetVertexColor(1, 1, 1, 1)
      healthBar.spark:SetAlpha(sparkA or 0)
      healthBar.spark:Show()
    end
  end
end

UpdateHealthBar = function(unit)
  CM.Profile("AllyHUD:HealthBar", UpdateHealthBarImpl, unit)
end

local function RefreshAllyCycleHUDImpl()
  EnsureFrames()
  if not cluster then
    return
  end
  local cfg = Config()
  local preview = previewActive
  local looking = preview or (CM.IsMouselooking and CM.IsMouselooking())
  local show = cfg.showHud ~= false
    and CM.IsCrosshairEnabled
    and CM.IsCrosshairEnabled()
    and looking
    and (
      preview
      or (CM.IsAllyCycleEnabled and CM.IsAllyCycleEnabled() and CM.IsAllyCycleFriendlyHardTarget())
    )

  if not show then
    RequestHudHide()
    return
  end

  local unit = preview and "player" or "target"
  local dead = preview and previewDead
    or (UnitIsDeadOrGhost and PublicBool(UnitIsDeadOrGhost(unit)) == true)
  local name = UnitName and UnitName(unit)
  if not preview and PublicBool(UnitIsUnit and UnitIsUnit(unit, "player")) == true then
    nameFS:SetText("You")
  elseif IsSecret(name) or type(name) ~= "string" or name == "" then
    nameFS:SetText(preview and "Ally" or "…")
  else
    nameFS:SetText(name)
  end
  ApplyNameColor(unit, dead)
  UpdateRoleIcon(unit)
  UpdateRaidMarker(unit)
  UpdateIndex(unit)
  CM.ApplyAllyCycleHUDLayout()

  if preview then
    ApplyPublicHealthAppearance(previewDisplayPct, previewDead)
    ApplyDeadChrome(previewDead)
  else
    UpdateHealthBar(unit)
  end

  SyncBarGlow(unit)
  ApplyRangeAlpha(unit)

  RequestHudShow()
  if pendingCycleDir then
    StartCycleAnim(pendingCycleDir)
    pendingCycleDir = nil
  end
end

function CM.RefreshAllyCycleHUD()
  return CM.Profile("AllyHUD:Refresh", RefreshAllyCycleHUDImpl)
end

function CM.InitAllyCycleHUD(opts)
  opts = opts or {}
  crosshairFrame = opts.crosshairFrame
  EnsureFrames()
  CM.ApplyAllyCycleHUDLayout()
  CM.RefreshAllyCycleHUD()
end
