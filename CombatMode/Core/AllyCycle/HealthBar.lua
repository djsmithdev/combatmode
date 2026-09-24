---------------------------------------------------------------------------------------
--  Core/AllyCycle/HealthBar.lua — ALLYCYCLE — widgetstatusbar + low-HP glow
---------------------------------------------------------------------------------------
--  What it does: Creates and tints the Ally HUD health bar (widgetstatusbar fill,
--  border, spark, low-HP red glow pulse). Live UNIT_HEALTH updates and options-preview
--  appearance share the same fill/glow curves.
--  Architecture / how it works:
--    • CM.AllyCycleHealthBar: Create, Update, ApplyPreview, SyncGlow, TickGlow, GetSize.
--    • UnitHealthPercent + color curves; never compare raw secret health fractions.
--    • Glow pulse is OnUpdate-only; UNIT_HEALTH / MAXHEALTH only retint the bar.
--    • CM.Profile key: AllyHUD:HealthBar (Update).
--  Does not: Own cluster layout, fade/slide, or unit identity.
--  Related: Core/AllyCycle/{Target,Motion,HUD}.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateColor = _G.CreateColor
local CreateFrame = _G.CreateFrame
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitHealthPercent = _G.UnitHealthPercent
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local CreateColorCurve = _G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve
local StatusBarInterpolation = _G.Enum and _G.Enum.StatusBarInterpolation
local HB_VALUE_INTERP = StatusBarInterpolation and StatusBarInterpolation.ExponentialEaseOut

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local math = _G.math
local type = _G.type

local HealthBar = {}
CM.AllyCycleHealthBar = HealthBar

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

local PREVIEW_MAX = 100
local glowPulsePhase = 0

local function HB()
  return HEALTH_BAR
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

local function SetBarDesaturated(bar, dead)
  if not bar then
    return
  end
  if bar.SetStatusBarDesaturated then
    bar:SetStatusBarDesaturated(dead)
  end
  local fillTex = bar:GetStatusBarTexture()
  if fillTex and fillTex.SetDesaturated then
    fillTex:SetDesaturated(dead)
  end
end

local function PinSparkToFill(bar)
  local fillTex = bar and (bar._fillTex or bar:GetStatusBarTexture())
  if fillTex and bar.spark then
    bar._fillTex = fillTex
    if not bar._sparkPinned then
      bar.spark:ClearAllPoints()
      bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
      bar._sparkPinned = true
    end
  end
end

function HealthBar.GetSize()
  local cfg = HB()
  return cfg.width or 72, cfg.height or 10
end

function HealthBar.Create(parent)
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

function HealthBar.SyncGlow(bar, dead)
  if not bar then
    return
  end
  if dead then
    bar.glowBaseA = 0
  else
    bar.glowBaseA = bar.healthGlowA or 0
  end
end

function HealthBar.TickGlow(bar, elapsed)
  if not bar or not bar.glowFrame then
    return
  end
  local cfg = HB()
  local period = cfg.glowPulsePeriod or 1.15
  glowPulsePhase = glowPulsePhase + (elapsed or 0) / period
  if glowPulsePhase >= 1 then
    glowPulsePhase = glowPulsePhase - math.floor(glowPulsePhase)
  end
  local wave = 0.5 - 0.5 * math.cos(glowPulsePhase * math.pi * 2)
  local pulseA = (cfg.glowPulseMin or 0.35)
    + ((cfg.glowPulseMax or 1) - (cfg.glowPulseMin or 0.35)) * wave

  local baseA = bar.glowBaseA
  if not (issecretvalue and issecretvalue(baseA)) and type(baseA) == "number" and baseA <= 0 then
    bar.glowFrame:Hide()
    return
  end
  local r, g, b = cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08
  bar.glowLeft:SetVertexColor(r, g, b, baseA)
  bar.glowCenter:SetVertexColor(r, g, b, baseA)
  bar.glowRight:SetVertexColor(r, g, b, baseA)
  bar.glowFrame:SetAlpha(pulseA)
  SetHealthBarGlowShown(bar, true)
  bar.glowFrame:Show()
end

function HealthBar.ApplyPreview(bar, pct, dead, applyDeadChrome)
  if not bar then
    return
  end
  local cfg = HB()
  local lowPct = cfg.lowPct or 0.25

  if dead or pct <= 0 then
    bar:SetMinMaxValues(0, PREVIEW_MAX)
    bar:SetValue(0)
    if COLOR_HB_DEAD then
      bar:SetStatusBarColor(COLOR_HB_DEAD:GetRGBA())
    end
    HideBarGlow(bar)
    if bar.spark then
      bar.spark:Hide()
    end
    bar._hbHasValue = true
    SetBarDesaturated(bar, true)
    if applyDeadChrome then
      applyDeadChrome(true)
    end
    return
  end

  SetBarDesaturated(bar, false)
  if applyDeadChrome then
    applyDeadChrome(false)
  end

  local health = PREVIEW_MAX * pct
  if HB_VALUE_INTERP and bar._hbHasValue then
    bar:SetMinMaxValues(0, PREVIEW_MAX, HB_VALUE_INTERP)
    bar:SetValue(health, HB_VALUE_INTERP)
  else
    bar:SetMinMaxValues(0, PREVIEW_MAX)
    bar:SetValue(health)
  end
  bar._hbHasValue = true

  if pct <= lowPct then
    if COLOR_HB_CRIT then
      bar:SetStatusBarColor(COLOR_HB_CRIT:GetRGBA())
    end
    bar.healthGlowA = 1
  elseif pct <= 0.5 then
    if COLOR_HB_DMG then
      bar:SetStatusBarColor(COLOR_HB_DMG:GetRGBA())
    end
    bar.healthGlowA = 0
  else
    if COLOR_HB_OK then
      bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    end
    bar.healthGlowA = 0
  end
  bar.glowBaseA = bar.healthGlowA

  if bar.glowBaseA == 0 and bar.glowFrame then
    bar.glowFrame:Hide()
    SetHealthBarGlowShown(bar, false)
  end

  PinSparkToFill(bar)
  if bar.spark then
    bar.spark:SetVertexColor(1, 1, 1, 1)
    bar.spark:SetAlpha(1)
    bar.spark:SetShown(pct > 0 and pct < 1)
  end
end

local function UpdateImpl(bar, unit, applyDeadChrome)
  if not bar then
    return
  end

  local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
  local pubDead = PublicBool(dead)
  if pubDead == true then
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    if COLOR_HB_DEAD then
      bar:SetStatusBarColor(COLOR_HB_DEAD:GetRGBA())
    end
    HideBarGlow(bar)
    if bar.spark then
      bar.spark:Hide()
    end
    bar._hbHasValue = true
    bar._lastH = nil
    bar._lastM = nil
    SetBarDesaturated(bar, true)
    if applyDeadChrome then
      applyDeadChrome(true)
    end
    return
  end

  SetBarDesaturated(bar, false)
  if applyDeadChrome then
    applyDeadChrome(false)
  end

  local health = UnitHealth and UnitHealth(unit, true)
  local maxHealth = UnitHealthMax and UnitHealthMax(unit)
  local pubH = PublicNumber(health, nil)
  local pubM = PublicNumber(maxHealth, nil)
  if pubH and pubM and pubH == bar._lastH and pubM == bar._lastM then
    return
  end
  if pubH then
    bar._lastH = pubH
  end
  if pubM then
    bar._lastM = pubM
  end

  if health ~= nil and maxHealth ~= nil then
    if HB_VALUE_INTERP and bar._hbHasValue then
      bar:SetMinMaxValues(0, maxHealth, HB_VALUE_INTERP)
      bar:SetValue(health, HB_VALUE_INTERP)
    else
      bar:SetMinMaxValues(0, maxHealth)
      bar:SetValue(health)
    end
    bar._hbHasValue = true
  end

  if UnitHealthPercent and HB_FILL_CURVE then
    local fillColor = UnitHealthPercent(unit, true, HB_FILL_CURVE)
    local fr, fg, fb, fa = ExtractColorRGBA(fillColor)
    if fr then
      bar:SetStatusBarColor(fr, fg, fb, fa)
    end
    local glowColor = UnitHealthPercent(unit, true, HB_GLOW_CURVE)
    local _, _, _, glowA = ExtractColorRGBA(glowColor)
    bar.healthGlowA = glowA or 0
    bar.glowBaseA = bar.healthGlowA
    PinSparkToFill(bar)
    if HB_SPARK_CURVE and bar.spark then
      local sparkColor = UnitHealthPercent(unit, true, HB_SPARK_CURVE)
      local _, _, _, sparkA = ExtractColorRGBA(sparkColor)
      bar.spark:SetVertexColor(1, 1, 1, 1)
      bar.spark:SetAlpha(sparkA or 0)
      bar.spark:Show()
    end
  end
end

function HealthBar.Update(bar, unit, applyDeadChrome)
  return CM.Profile("AllyHUD:HealthBar", UpdateImpl, bar, unit, applyDeadChrome)
end
