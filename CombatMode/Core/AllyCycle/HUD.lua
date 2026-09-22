---------------------------------------------------------------------------------------
--  Core/AllyCycle/HUD.lua — ALLYCYCLE — crosshair companion for friendly hard target
---------------------------------------------------------------------------------------
--  What it does: Compact Ally HUD (class-colored name, UI-Frame role icon, widgetstatusbar
--  HP, raid marker) beside the crosshair while Ally Cycle is enabled and the hard target
--  is a friendly (non-self) unit — or while the Ally Cycle options tab preview is active.
--  Architecture / how it works:
--    • DB.global.allyCycle: showHud, hudSide (default TOP), scale.
--    • Layout: name above; role left of bar; raid marker right (raidMarkerGap).
--      Dead → desaturate bar/role/marker, grey name.
--      Low HP → red pulsing bar glow; aggro (threat ≥ 2) → same glow, yellow tint.
--      Raid marker via SetRaidTargetIconTexture (secret index safe under taint).
--      PetJournal-BattleSlot-Shadow backdrop; UnitInRange dims via EvaluateColorFromBoolean.
--    • RefreshAllyCycleHUD / ApplyAllyCycleHUDLayout; InitAllyCycleHUD from Crosshair.
--    • SetAllyCycleOptionsPreview — tab onSelect/onDeselect (crosshair + sample HUD).
--  Does not: Own cycle bindings or targeting prelines.
--  Related: Core/AllyCycle/{Cycle,AllyCycle}.lua, Core/Crosshair/Crosshair.lua,
--  Constants/AllyCycle.lua, UI/Options/Tabs/TabAllyCycle.lua
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
local UnitThreatSituation = _G.UnitThreatSituation
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
local type = _G.type

local cluster
local nameFS
local healthBar
local roleIcon
local raidMarker
local raidMarkerFrame
local hudShadow
local crosshairFrame
local eventsRegistered = false
local previewActive = false
local glowPulsePhase = 0

-- Options preview: living / low / aggro+marker / dead.
local PREVIEW_MAX = 100
local PREVIEW_STAGES = {
  { pct = 1.0, dead = false, aggro = false, raid = nil, dwell = 1.0 },
  { pct = 0.7, dead = false, aggro = false, raid = 1, dwell = 1.4 },
  { pct = 0.55, dead = false, aggro = true, raid = 8, dwell = 1.8 },
  { pct = 0.0, dead = true, aggro = false, raid = nil, dwell = 1.2 },
}
local previewStageIndex = 1
local previewStageElapsed = 0
local previewDisplayPct = 1
local PREVIEW_LERP_SEC = 0.4
local previewDead = false
local previewAggro = false
local previewRaidIndex = nil

local function Layout()
  return (CM.Constants and CM.Constants.AllyCycleLayout) or {}
end

local function HB()
  return (CM.Constants and CM.Constants.AllyCycleHealthBar) or {}
end

local function RoleAtlases()
  return (CM.Constants and CM.Constants.AllyCycleRoleAtlases) or {}
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

local function Config()
  local g = CM.DB and CM.DB.global and CM.DB.global.allyCycle
  local d = CM.Constants
    and CM.Constants.DatabaseDefaults
    and CM.Constants.DatabaseDefaults.global
    and CM.Constants.DatabaseDefaults.global.allyCycle
  return g or d or { showHud = true, hudSide = "TOP", scale = 1 }
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

-- Health fill colors (green / yellow / crit — not class tint).
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

local function ApplyRangeAlpha(unit)
  if not cluster then
    return
  end
  local L = Layout()
  local outA = L.outOfRangeAlpha or 0.3
  if previewActive or not unit or unit == "player" then
    cluster:SetAlpha(1)
    return
  end
  if not UnitExists(unit) then
    cluster:SetAlpha(1)
    return
  end
  if EvaluateColorFromBoolean and UnitInRange and COLOR_IN_RANGE and COLOR_OUT_OF_RANGE then
    local inRange = UnitInRange(unit)
    local rangeColor = EvaluateColorFromBoolean(inRange, COLOR_IN_RANGE, COLOR_OUT_OF_RANGE)
    if rangeColor and rangeColor.a ~= nil then
      cluster:SetAlpha(rangeColor.a)
      return
    end
  end
  -- Pre-12 / no curve util: PublicBool only (never truth-test a secret).
  if UnitInRange then
    local pub = PublicBool(UnitInRange(unit))
    if pub == false then
      cluster:SetAlpha(outA)
      return
    end
  end
  cluster:SetAlpha(1)
end

--- True when hard target is a friendly we should show / route heals to.
function CM.IsAllyCycleFriendlyHardTarget()
  if not UnitExists("target") then
    return false
  end
  if UnitIsUnit and UnitIsUnit("target", "player") then
    return false
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

--- Options-tab live preview: force crosshair + Ally HUD sample with mouselook off.
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
    previewAggro = false
    previewRaidIndex = nil
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

--- Dead: desaturate fill + role + marker; grey the name (FontString has no SetDesaturated).
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

-- Threat status ≥ 2 = tanking (has aggro). Secret threat → no aggro (fail soft).
local function UnitHasAggro(unit)
  if previewActive then
    return previewAggro
  end
  if not unit or not UnitThreatSituation or not UnitExists(unit) then
    return false
  end
  local status = UnitThreatSituation(unit)
  if IsSecret(status) or type(status) ~= "number" then
    return false
  end
  return status >= 2
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

-- healthGlowA = HP-curve baseline; aggro forces full glow + yellow tint.
local function SyncBarGlow(unit)
  if not healthBar then
    return
  end
  local dead = previewActive and previewDead
    or (unit and UnitIsDeadOrGhost and PublicBool(UnitIsDeadOrGhost(unit)) == true)
  local fromHealth = healthBar.healthGlowA or 0
  local aggro = not dead and UnitHasAggro(unit)
  healthBar.glowFromAggro = aggro
  if dead then
    healthBar.glowBaseA = 0
  elseif aggro then
    healthBar.glowBaseA = 1
  else
    healthBar.glowBaseA = fromHealth
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
  ApplyHealthBarFill(bar, fillAtlas)
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
  bar.glowFromAggro = false
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
  local r, g, b
  if bar.glowFromAggro then
    r, g, b = cfg.aggroGlowR or 1, cfg.aggroGlowG or 0.85, cfg.aggroGlowB or 0.12
  else
    r, g, b = cfg.glowR or 1, cfg.glowG or 0.12, cfg.glowB or 0.08
  end
  bar.glowLeft:SetVertexColor(r, g, b, baseA)
  bar.glowCenter:SetVertexColor(r, g, b, baseA)
  bar.glowRight:SetVertexColor(r, g, b, baseA)
  bar.glowFrame:SetAlpha(pulseA)
  SetHealthBarGlowShown(bar, true)
  bar.glowFrame:Show()
end

local function ApplyPublicHealthAppearance(pct, dead)
  if not healthBar then
    return
  end
  local cfg = HB()
  local lowPct = cfg.lowPct or 0.25
  local fillTex = healthBar:GetStatusBarTexture()

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

  if healthBar.spark then
    if fillTex then
      healthBar.spark:ClearAllPoints()
      healthBar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
    end
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

  ApplyPublicHealthAppearance(
    previewDisplayPct,
    stage.dead and previewStageElapsed > PREVIEW_LERP_SEC
  )
  previewDead = stage.dead and previewStageElapsed > PREVIEW_LERP_SEC
  previewAggro = stage.aggro == true and not previewDead
  previewRaidIndex = stage.raid
  ApplyDeadChrome(previewDead)
  ApplyNameColor("player", previewDead)
  UpdateRaidMarker("player")
  SyncBarGlow("player")

  if previewStageElapsed >= stage.dwell then
    previewStageElapsed = 0
    healthBar._previewStartPct = previewDisplayPct
    previewStageIndex = previewStageIndex + 1
    if previewStageIndex > #PREVIEW_STAGES then
      previewStageIndex = 1
    end
  end
end

local function OnHudUpdate(_, elapsed)
  if previewActive and cluster and cluster:IsShown() then
    TickPreviewHealth(elapsed)
  elseif cluster and cluster:IsShown() and not previewActive then
    ApplyRangeAlpha("target")
    SyncBarGlow("target")
  end
  if not healthBar or not healthBar:IsShown() then
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

  local fillTex = healthBar:GetStatusBarTexture()
  if fillTex and healthBar.spark and healthBar.spark:IsShown() then
    healthBar.spark:ClearAllPoints()
    healthBar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
  end
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
  if event == "UNIT_THREAT_SITUATION_UPDATE" and (unit == "target" or unit == "player") then
    if cluster and cluster:IsShown() then
      SyncBarGlow(previewActive and "player" or "target")
    end
    return
  end
  if
    (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_FLAGS")
    and (unit == "target" or unit == "player")
  then
    CM.RefreshAllyCycleHUD()
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

    healthBar = CreateAllyHealthBar(cluster)
    healthBar:SetSize(cfg.width or 72, cfg.height or 10)

    -- Overlay frame above StatusBar chrome so the marker is never covered.
    local markerS = L.raidMarkerSize or 14
    raidMarkerFrame = CreateFrame("Frame", nil, cluster)
    raidMarkerFrame:SetSize(markerS, markerS)
    raidMarkerFrame:SetFrameLevel(healthBar:GetFrameLevel() + 5)
    raidMarker = raidMarkerFrame:CreateTexture(nil, "OVERLAY")
    raidMarker:SetAllPoints(raidMarkerFrame)
    raidMarker:SetTexture(RAID_TARGET_TEXTURE)
    raidMarker:Hide()
  elseif cluster and not raidMarkerFrame and healthBar then
    -- Upgrade path if cluster was created before raid-marker chrome existed.
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
    cluster:RegisterUnitEvent("UNIT_THREAT_SITUATION_UPDATE", "target", "player")
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
  -- Natural width; clamp so long names ellipsis later than the bar width.
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

local function LayoutChildren()
  if not cluster or not nameFS or not healthBar or not roleIcon or not raidMarkerFrame then
    return
  end
  local L = Layout()
  local cfg = HB()
  local gap = L.gap or 2
  local markerGap = L.raidMarkerGap
  if type(markerGap) ~= "number" then
    markerGap = gap * 2
  end
  local nameLift = L.nameLift or 6
  local iconS = L.roleIconSize or 20
  local markerS = L.raidMarkerSize or 14
  local barW = cfg.width or 72
  local barH = cfg.height or 10
  local nameH = (L.nameFontSize or 11) + 2
  local rowH = math.max(iconS, markerS, barH)
  -- Equal side pads so name + bar stay centered (use the farther side extent).
  local sidePad = math.max(iconS + gap, markerS + markerGap)
  local nameW = MeasureNameWidth()
  nameFS:SetWidth(nameW)
  nameFS:SetHeight(nameH)

  roleIcon:ClearAllPoints()
  raidMarkerFrame:ClearAllPoints()
  nameFS:ClearAllPoints()
  healthBar:ClearAllPoints()

  roleIcon:SetSize(iconS, iconS)
  raidMarkerFrame:SetSize(markerS, markerS)
  raidMarkerFrame:SetFrameLevel(healthBar:GetFrameLevel() + 5)
  healthBar:SetSize(barW, barH)

  local totalW = math.max(nameW, barW + sidePad * 2)
  local totalH = nameH + nameLift + gap + rowH
  cluster:SetSize(totalW, totalH)

  nameFS:SetPoint("TOP", cluster, "TOP", 0, 0)
  healthBar:SetPoint("TOP", nameFS, "BOTTOM", 0, -(nameLift + gap))
  roleIcon:SetPoint("RIGHT", healthBar, "LEFT", -gap, 0)
  raidMarkerFrame:SetPoint("LEFT", healthBar, "RIGHT", markerGap, 0)

  LayoutShadowTexture(hudShadow, L)
  if hudShadow then
    hudShadow:SetAlpha(L.shadowAlpha or 0.7)
    hudShadow:Show()
  end
end

function CM.ApplyAllyCycleHUDLayout()
  EnsureFrames()
  if not cluster or not crosshairFrame then
    return
  end
  LayoutChildren()
  local cfg = Config()
  local side = cfg.hudSide or "TOP"
  local L = Layout()
  local crosshairSize = (CM.GetCrosshairPixelSize and CM.GetCrosshairPixelSize()) or 64
  -- Anchor to outer crosshair frame CENTER (not the animating texture) so cast scale
  -- feedback does not drag the companion — same pattern as Interaction HUD / Assist.
  local gap = (crosshairSize / 2) + (L.companionOffset or 24)
  local scale = cfg.scale or 1
  cluster:SetScale(scale)
  cluster:ClearAllPoints()

  if side == "LEFT" then
    cluster:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, 0)
  elseif side == "RIGHT" then
    cluster:SetPoint("LEFT", crosshairFrame, "CENTER", gap, 0)
  elseif side == "BOTTOM" then
    cluster:SetPoint("TOP", crosshairFrame, "CENTER", 0, -gap)
  else
    cluster:SetPoint("BOTTOM", crosshairFrame, "CENTER", 0, gap)
  end
end

local function UpdateHealthBar(unit)
  if not healthBar then
    return
  end
  local fillTex = healthBar:GetStatusBarTexture()

  local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
  if PublicBool(dead) == true then
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
    ApplyDeadChrome(true)
    return
  end

  ApplyDeadChrome(false)

  local health = UnitHealth and UnitHealth(unit, true)
  local maxHealth = UnitHealthMax and UnitHealthMax(unit)
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
    if fillTex and healthBar.spark then
      healthBar.spark:ClearAllPoints()
      healthBar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
    end
    if HB_SPARK_CURVE and healthBar.spark then
      local sparkColor = UnitHealthPercent(unit, true, HB_SPARK_CURVE)
      local _, _, _, sparkA = ExtractColorRGBA(sparkColor)
      healthBar.spark:SetVertexColor(1, 1, 1, 1)
      healthBar.spark:SetAlpha(sparkA or 0)
      healthBar.spark:Show()
    end
  end
end

function CM.RefreshAllyCycleHUD()
  EnsureFrames()
  if not cluster then
    return
  end
  local cfg = Config()
  local preview = previewActive
  local show = cfg.showHud ~= false
    and CM.IsCrosshairEnabled
    and CM.IsCrosshairEnabled()
    and (
      preview
      or (CM.IsAllyCycleEnabled and CM.IsAllyCycleEnabled() and CM.IsAllyCycleFriendlyHardTarget())
    )

  if not show then
    cluster:Hide()
    return
  end

  local unit = preview and "player" or "target"
  local dead = preview and previewDead
    or (UnitIsDeadOrGhost and PublicBool(UnitIsDeadOrGhost(unit)) == true)
  local name = UnitName and UnitName(unit)
  if IsSecret(name) or type(name) ~= "string" or name == "" then
    nameFS:SetText(preview and "Ally" or "…")
  else
    nameFS:SetText(name)
  end
  ApplyNameColor(unit, dead)

  -- Layout after SetText so name width / ellipsis clamp use the live string.
  CM.ApplyAllyCycleHUDLayout()

  if preview then
    -- Health stages are driven by OnUpdate (TickPreviewHealth).
    ApplyPublicHealthAppearance(previewDisplayPct, previewDead)
    ApplyDeadChrome(previewDead)
  else
    UpdateHealthBar(unit)
  end

  UpdateRoleIcon(unit)
  UpdateRaidMarker(unit)
  SyncBarGlow(unit)
  ApplyRangeAlpha(unit)

  cluster:Show()
end

function CM.InitAllyCycleHUD(opts)
  opts = opts or {}
  crosshairFrame = opts.crosshairFrame
  EnsureFrames()
  CM.ApplyAllyCycleHUDLayout()
  CM.RefreshAllyCycleHUD()
end
