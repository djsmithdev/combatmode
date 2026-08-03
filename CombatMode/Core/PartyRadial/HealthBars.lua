---------------------------------------------------------------------------------------
--  Core/PartyRadial/HealthBars.lua — PARTYRADIAL — slice health bar chrome + pulse
---------------------------------------------------------------------------------------
--  What it does: Owns widgetstatusbar L/C/R health bars, UnitHealthPercent color curves,
--  low-health glow breath, and the shared OnUpdate pulse that also drives role-icon glow
--  and mind-controlled DeclineMark fade.
--  Architecture / how it works:
--    • CM.PartyRadialHealthBars: CreateSliceHealthBar, UpdateSliceHealthBar,
--      UpdateAllHealthBarGlowPulses, ResetHealthBarAnimState; exports HB_* / glow
--      constants and ExtractColorRGBA for RoleIcons.
--    • Preview health fractions via PartyData.PREVIEW_HEALTH_BY_SLICE.
--    • Size/pulse thresholds from CM.Constants.PartyRadialHealthBar.
--  Does not: Own roster, secure attrs, role atlas resolve, or show/hide.
--  Related: Core/PartyRadial/PartyData.lua, RoleIcons.lua, Visual.lua, Lifecycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local CreateColor = _G.CreateColor
local CreateColorCurve = _G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve
local UnitHealthPercent = _G.UnitHealthPercent
local issecretvalue = _G.issecretvalue
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local StatusBarInterpolation = _G.Enum and _G.Enum.StatusBarInterpolation
local HB_VALUE_INTERP = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut

-- Lua stdlib
local math = _G.math
local type = _G.type

local HR = CM.PartyRadial
local PartyData = CM.PartyRadialPartyData
local HealthBars = {}
CM.PartyRadialHealthBars = HealthBars

local function GetState()
  return HR.GetState()
end

local PREVIEW_HEALTH_BY_SLICE = PartyData.PREVIEW_HEALTH_BY_SLICE

-- Party-slice health bar (widgetstatusbar kit), scaled from native 15px fill height.
local HB = CM.Constants.PartyRadialHealthBar
local HB_W, HB_H = HB.width, HB.height
local HB_SCALE = HB_H / 15
local HB_BORDER_X = math.floor(8 * HB_SCALE + 0.5)
local HB_BG_X = math.max(1, math.floor(2 * HB_SCALE + 0.5))
local HB_BORDER_H = math.floor(31 * HB_SCALE + 0.5)
local HB_BORDER_END_W = math.floor(35 * HB_SCALE + 0.5)
local HB_BG_H = math.floor(18 * HB_SCALE + 0.5)
local HB_BG_END_W = math.floor(29 * HB_SCALE + 0.5)
local HB_LOW_PCT = HB.lowPct
local HB_GLOW_R, HB_GLOW_G, HB_GLOW_B = HB.glowR, HB.glowG, HB.glowB
-- Continuous low-health glow breath (shared phase across slices).
local HB_GLOW_PULSE_PERIOD = HB.glowPulsePeriod
local HB_GLOW_PULSE_MIN = HB.glowPulseMin
local HB_GLOW_PULSE_MAX = HB.glowPulseMax
-- Mind-controlled DeclineMark X: full fade cycle (faster than bar/icon breath).
local CONTROLLED_OVERLAY_PULSE_PERIOD = HB.controlledOverlayPulsePeriod
local HB_FILL_WHITE = HB.fillWhiteAtlas
local COLOR_HB_CRIT = CreateColor(1, 0.22, 0.12, 1)
local COLOR_HB_DMG = CreateColor(1, 0.85, 0.15, 1)
local COLOR_HB_OK = CreateColor(0.2, 0.85, 0.25, 1)
local COLOR_HB_DEAD = CreateColor(0.45, 0.45, 0.45, 1)
local COLOR_HB_GLOW_ON = CreateColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
local COLOR_HB_GLOW_OFF = CreateColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 0)
local COLOR_HB_SPARK_ON = CreateColor(1, 1, 1, 1)
local COLOR_HB_SPARK_OFF = CreateColor(1, 1, 1, 0)

-- Secret-safe health → color (same pattern as Platynator / EQOL: UnitHealthPercent + color curve).
-- Step curves hold a point's color until the next point, so green/glow-off must start
-- immediately after their thresholds (not only at 1.0).
local HB_FILL_CURVE, HB_GLOW_CURVE, HB_SPARK_CURVE
if CreateColorCurve then
  local stepType = _G.Enum and _G.Enum.LuaCurveType and _G.Enum.LuaCurveType.Step
  local yellowAt = HB_LOW_PCT + 1e-4
  local greenAt = 0.5 + 1e-4

  HB_FILL_CURVE = CreateColorCurve()
  if stepType then
    HB_FILL_CURVE:SetType(stepType)
  end
  HB_FILL_CURVE:AddPoint(0, COLOR_HB_CRIT)
  HB_FILL_CURVE:AddPoint(HB_LOW_PCT, COLOR_HB_CRIT)
  HB_FILL_CURVE:AddPoint(yellowAt, COLOR_HB_DMG)
  HB_FILL_CURVE:AddPoint(0.5, COLOR_HB_DMG)
  HB_FILL_CURVE:AddPoint(greenAt, COLOR_HB_OK)
  HB_FILL_CURVE:AddPoint(1, COLOR_HB_OK)

  HB_GLOW_CURVE = CreateColorCurve()
  if stepType then
    HB_GLOW_CURVE:SetType(stepType)
  end
  HB_GLOW_CURVE:AddPoint(0, COLOR_HB_GLOW_ON)
  HB_GLOW_CURVE:AddPoint(HB_LOW_PCT, COLOR_HB_GLOW_ON)
  HB_GLOW_CURVE:AddPoint(yellowAt, COLOR_HB_GLOW_OFF)
  HB_GLOW_CURVE:AddPoint(1, COLOR_HB_GLOW_OFF)

  HB_SPARK_CURVE = CreateColorCurve()
  if stepType then
    HB_SPARK_CURVE:SetType(stepType)
  end
  -- Visible for any partial health; off at empty/full.
  HB_SPARK_CURVE:AddPoint(0, COLOR_HB_SPARK_OFF)
  HB_SPARK_CURVE:AddPoint(0.001, COLOR_HB_SPARK_ON)
  HB_SPARK_CURVE:AddPoint(0.999, COLOR_HB_SPARK_ON)
  HB_SPARK_CURVE:AddPoint(1, COLOR_HB_SPARK_OFF)
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

local function SetHealthBarGlowShown(bar, shown)
  bar.glowLeft:SetShown(shown)
  bar.glowCenter:SetShown(shown)
  bar.glowRight:SetShown(shown)
end

-- Low-health gate stays on vertex alpha; pulse is glowFrame:SetAlpha only.
-- Texture:SetAlpha would override vertex alpha and light every bar.
local function ApplyHealthBarGlowPulse(bar, pulseA)
  local baseA = bar.glowBaseA
  local glowFrame = bar.glowFrame
  if not glowFrame or baseA == nil then
    if glowFrame then
      glowFrame:Hide()
    end
    return
  end
  if not (issecretvalue and issecretvalue(baseA)) and type(baseA) == "number" and baseA <= 0 then
    glowFrame:Hide()
    return
  end
  bar.glowLeft:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, baseA)
  bar.glowCenter:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, baseA)
  bar.glowRight:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, baseA)
  glowFrame:SetAlpha(pulseA)
  SetHealthBarGlowShown(bar, true)
  glowFrame:Show()
end

local function UpdateAllHealthBarGlowPulses(elapsed)
  GetState().hbGlowPulsePhase = (GetState().hbGlowPulsePhase or 0) + elapsed / HB_GLOW_PULSE_PERIOD
  if GetState().hbGlowPulsePhase >= 1 then
    GetState().hbGlowPulsePhase = GetState().hbGlowPulsePhase
      - math.floor(GetState().hbGlowPulsePhase)
  end
  local wave = 0.5 - 0.5 * math.cos(GetState().hbGlowPulsePhase * math.pi * 2)
  local pulseA = HB_GLOW_PULSE_MIN + (HB_GLOW_PULSE_MAX - HB_GLOW_PULSE_MIN) * wave

  GetState().controlledOverlayPulsePhase = (GetState().controlledOverlayPulsePhase or 0)
    + elapsed / CONTROLLED_OVERLAY_PULSE_PERIOD
  if GetState().controlledOverlayPulsePhase >= 1 then
    GetState().controlledOverlayPulsePhase = GetState().controlledOverlayPulsePhase
      - math.floor(GetState().controlledOverlayPulsePhase)
  end
  local controlledWave = 0.5 - 0.5 * math.cos(GetState().controlledOverlayPulsePhase * math.pi * 2)

  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    local bar = slice and slice.healthBar
    if bar and bar:IsShown() then
      ApplyHealthBarGlowPulse(bar, pulseA)
      -- Keep spark on the interpolating fill edge between slice refreshes.
      local fillTex = bar:GetStatusBarTexture()
      if fillTex and bar.spark then
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
      end
    end

    -- Role icon low-health glow: same breath as the bar (vertex gate + frame pulse).
    local iconGlow = slice and slice.roleIconGlow
    local iconGlowFrame = slice and slice.roleIconGlowFrame
    if iconGlow and iconGlowFrame then
      local iconBaseA = slice.roleIconGlowBaseA
      if
        not (issecretvalue and issecretvalue(iconBaseA))
        and (type(iconBaseA) ~= "number" or iconBaseA <= 0)
      then
        iconGlowFrame:Hide()
      else
        iconGlow:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, iconBaseA)
        iconGlowFrame:SetAlpha(pulseA)
        iconGlowFrame:Show()
      end
    end

    -- Mind-controlled DeclineMark: fade fully in/out over the role icon.
    local controlled = slice and slice.roleIconControlled
    if controlled and slice.roleIconControlledActive then
      controlled:SetAlpha(controlledWave)
      controlled:Show()
    elseif controlled then
      controlled:Hide()
    end
  end
end

local function ResetHealthBarAnimState()
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    local bar = slice and slice.healthBar
    if bar then
      bar._hbHasValue = nil
    end
  end
end

-- Public (preview) health fraction → fill/glow/spark.
local function ApplyHealthBarPublicAppearance(bar, pct, fillTex)
  if type(pct) ~= "number" then
    bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    bar.glowBaseA = 0
    bar.spark:Hide()
    return
  end

  if pct <= HB_LOW_PCT then
    bar:SetStatusBarColor(COLOR_HB_CRIT:GetRGBA())
    bar.glowBaseA = 1
  elseif pct <= 0.5 then
    bar:SetStatusBarColor(COLOR_HB_DMG:GetRGBA())
    bar.glowBaseA = 0
  else
    bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    bar.glowBaseA = 0
  end

  if fillTex then
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
  end
  bar.spark:SetVertexColor(1, 1, 1, 1)
  bar.spark:SetShown(pct > 0 and pct < 1)
end

-- Dead/ghost: greyed fill, no low-health glow or spark.
local function ApplyHealthBarDeadAppearance(bar)
  bar:SetStatusBarColor(COLOR_HB_DEAD:GetRGBA())
  bar.glowBaseA = 0
  if bar.glowFrame then
    bar.glowFrame:Hide()
  end
  SetHealthBarGlowShown(bar, false)
  if bar.spark then
    bar.spark:Hide()
  end
end

-- Live unit: UnitHealthPercent + color curves (secret/taint safe; Platynator/EQOL pattern).
local function ApplyHealthBarUnitAppearance(bar, unit, fillTex)
  if not (UnitHealthPercent and HB_FILL_CURVE) then
    return false
  end

  local fillColor = UnitHealthPercent(unit, true, HB_FILL_CURVE)
  local fr, fg, fb, fa = ExtractColorRGBA(fillColor)
  if not fr then
    return false
  end
  bar:SetStatusBarColor(fr, fg, fb, fa)

  local glowColor = UnitHealthPercent(unit, true, HB_GLOW_CURVE)
  local _, _, _, glowA = ExtractColorRGBA(glowColor)
  -- May be secret 0/1; vertex alpha gates the pulse without a public boolean test.
  bar.glowBaseA = glowA or 0

  if fillTex then
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
  end
  local sparkColor = UnitHealthPercent(unit, true, HB_SPARK_CURVE)
  local _, _, _, sparkA = ExtractColorRGBA(sparkColor)
  bar.spark:SetVertexColor(1, 1, 1, 1)
  bar.spark:SetAlpha(sparkA or 0)
  bar.spark:Show()
  return true
end

-- L/C/R chrome for widgetstatusbar (bg / border). Ends size to endW x height; center stretches.
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

local function CreateSliceHealthBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(HB_W, HB_H)
  bar:SetPoint("BOTTOM", parent, "BOTTOM", 0, 4)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  ApplyHealthBarFill(bar, HB_FILL_WHITE)
  bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())

  CreateHealthBarLCR(
    bar,
    "BACKGROUND",
    0,
    "widgetstatusbar-bgleft",
    "widgetstatusbar-bgcenter",
    "widgetstatusbar-bgright",
    HB_BG_END_W,
    HB_BG_H,
    HB_BG_X
  )

  local borderLeft, _, borderRight = CreateHealthBarLCR(
    bar,
    "OVERLAY",
    1,
    "widgetstatusbar-borderleft",
    "widgetstatusbar-bordercenter",
    "widgetstatusbar-borderright",
    HB_BORDER_END_W,
    HB_BORDER_H,
    HB_BORDER_X
  )

  -- Low-health glow above border/spark (ADD). Pulse via glowFrame alpha so vertex
  -- alpha can still gate visibility by health without Texture:SetAlpha overriding it.
  local glowFrame = CreateFrame("Frame", nil, bar)
  glowFrame:SetAllPoints(bar)
  glowFrame:Hide()
  bar.glowFrame = glowFrame

  local function MakeGlow(atlas, point, relative)
    local tex = glowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    tex:SetAtlas(atlas, false)
    tex:SetSize(HB_BORDER_END_W, HB_BORDER_H)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
    tex:SetPoint(point, relative)
    tex:Hide()
    return tex
  end
  local glowLeft = MakeGlow("widgetstatusbar-glowleft", "LEFT", borderLeft)
  local glowRight = MakeGlow("widgetstatusbar-glowright", "RIGHT", borderRight)
  local glowCenter = glowFrame:CreateTexture(nil, "OVERLAY", nil, 3)
  glowCenter:SetAtlas("widgetstatusbar-glowcenter", false)
  glowCenter:SetBlendMode("ADD")
  glowCenter:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  glowCenter:SetHeight(HB_BORDER_H)
  glowCenter:SetPoint("LEFT", glowLeft, "RIGHT")
  glowCenter:SetPoint("RIGHT", glowRight, "LEFT")
  glowCenter:Hide()
  bar.glowLeft = glowLeft
  bar.glowCenter = glowCenter
  bar.glowRight = glowRight

  local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
  spark:SetAtlas("widgetstatusbar-spark", false)
  spark:SetSize(6, HB_H + 4)
  spark:SetBlendMode("ADD")
  spark:Hide()
  bar.spark = spark

  return bar
end

local function UpdateSliceHealthBar(slice, config, memberData, sliceIndex, isPlaceholder)
  local bar = slice.healthBar
  if not bar then
    return
  end

  bar:ClearAllPoints()
  bar:SetPoint("TOP", slice.nameText, "BOTTOM", 0, -4)

  if not config.showHealthBars then
    bar._hbHasValue = nil
    bar.glowBaseA = nil
    if bar.glowFrame then
      bar.glowFrame:Hide()
    end
    SetHealthBarGlowShown(bar, false)
    bar:Hide()
    return
  end

  local health, maxHealth, pct, unitId
  if GetState().optionsPreviewActive then
    maxHealth = 100
    pct = PREVIEW_HEALTH_BY_SLICE[sliceIndex] or 0.75
    health = maxHealth * pct
  elseif isPlaceholder then
    maxHealth = 100
    pct = memberData.previewHealthPct or 0.75
    health = maxHealth * pct
  else
    unitId = memberData.unitId
    -- Predicted health; StatusBar accepts secret values. Color via UnitHealthPercent curves.
    health = UnitHealth(unitId, true)
    maxHealth = UnitHealthMax(unitId)
  end

  -- Snap first value after show/create; ease subsequent updates.
  if HB_VALUE_INTERP and bar._hbHasValue then
    bar:SetMinMaxValues(0, maxHealth, HB_VALUE_INTERP)
    bar:SetValue(health, HB_VALUE_INTERP)
  else
    bar:SetMinMaxValues(0, maxHealth)
    bar:SetValue(health)
    bar._hbHasValue = true
  end

  local fillTex = ApplyHealthBarFill(bar, HB_FILL_WHITE)

  local isDead = false
  if memberData and memberData.previewDead then
    isDead = true
  elseif unitId and UnitIsDeadOrGhost then
    local deadOrGhost = UnitIsDeadOrGhost(unitId)
    if deadOrGhost and not (issecretvalue and issecretvalue(deadOrGhost)) then
      isDead = true
    end
  end

  if isDead then
    ApplyHealthBarDeadAppearance(bar)
  elseif unitId then
    if not ApplyHealthBarUnitAppearance(bar, unitId, fillTex) and pct ~= nil then
      ApplyHealthBarPublicAppearance(bar, pct, fillTex)
    end
  else
    ApplyHealthBarPublicAppearance(bar, pct, fillTex)
  end

  bar:Show()
end

HealthBars.HB_LOW_PCT = HB_LOW_PCT
HealthBars.HB_GLOW_R = HB_GLOW_R
HealthBars.HB_GLOW_G = HB_GLOW_G
HealthBars.HB_GLOW_B = HB_GLOW_B
HealthBars.HB_GLOW_CURVE = HB_GLOW_CURVE
HealthBars.ExtractColorRGBA = ExtractColorRGBA
HealthBars.CreateSliceHealthBar = CreateSliceHealthBar
HealthBars.UpdateSliceHealthBar = UpdateSliceHealthBar
HealthBars.UpdateAllHealthBarGlowPulses = UpdateAllHealthBarGlowPulses
HealthBars.ResetHealthBarAnimState = ResetHealthBarAnimState
