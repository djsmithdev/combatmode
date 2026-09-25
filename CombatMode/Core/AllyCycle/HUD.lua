---------------------------------------------------------------------------------------
--  Core/AllyCycle/HUD.lua — ALLYCYCLE — crosshair companion chrome
---------------------------------------------------------------------------------------
--  What it does: Owns the Ally HUD cluster beside the crosshair for a party/raid
--  hard target (or options preview). Self is shown only when Skip Self is off; name
--  reads "You". Wires Target, HealthBar, and Motion.
--  Architecture / how it works:
--    • DB.global.allyCycle (side / scale / padding); LAYOUT locals here. Padding
--      defaults to CrosshairCompanionOffsetX.
--    • InitAllyCycleHUD({crosshairFrame}); ApplyAllyCycleHUDLayout + RefreshAllyCycleHUD.
--    • Motion.Attach + OnUpdate Motion.Tick then HealthBar.TickGlow. Preview lerp
--      stays here. Range via UNIT_IN_RANGE_UPDATE → Motion.ApplyRange.
--    • Raid marker / name / role applied from AllyCycleTarget (frame-free data).
--    • OnUpdate is fade / slide / glow / preview only; AnchorCluster is dirty-checked.
--    • CM.Profile keys: AllyHUD:OnUpdate / Refresh / Layout (HealthBar profiles itself).
--  Does not: Own cycle bindings, targeting prelines, bar widget, or fade internals.
--  Related: Core/AllyCycle/{Target,HealthBar,Motion,Cycle,AllyCycle}.lua,
--  Core/Crosshair/Crosshair.lua, UI/Options/Tabs/TabAllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local math = _G.math
local tonumber = _G.tonumber
local type = _G.type

local Target = CM.AllyCycleTarget
local HealthBar = CM.AllyCycleHealthBar
local Motion = CM.AllyCycleMotion

local cluster
local nameFS
local indexFS
local cycleArrow
local healthBar
local roleIcon
local raidMarker
local raidMarkerFrame
local hudShadow
local crosshairFrame
local eventsRegistered = false
local previewActive = false
local lastAnchorSide, lastAnchorScale, lastAnchorGap, lastAnchorOy
local CONFIG_FALLBACK = { showHud = true, hudSide = "BOTTOM", scale = 1, padding = 24 }

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
  cycleArrowSize = 10,
  cycleArrowGap = 0,
  cycleArrowHold = 0.32,
  cycleArrowTravel = 5,
  cycleSlidePx = 3,
  cycleAnimSec = 0.14,
  cycleAnimFromAlpha = 0.75,
}

local function Layout()
  return LAYOUT
end

local function IsSecret(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
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
  lastAnchorSide = nil
  lastAnchorScale = nil
  lastAnchorGap = nil
  lastAnchorOy = nil
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

local function UpdateRoleIcon(unit)
  if not roleIcon then
    return
  end
  local atlas = Target and Target.GetRoleAtlas and Target.GetRoleAtlas(unit)
  if atlas and roleIcon.SetAtlas then
    roleIcon:SetAtlas(atlas)
    roleIcon:Show()
  else
    roleIcon:Hide()
  end
end

-- FontString has no SetDesaturated — grey name/index instead. Bar desaturate is HealthBar.
local function ApplyDeadChrome(dead)
  dead = dead and true or false
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
  if cycleArrow and cycleArrow.SetDesaturated then
    cycleArrow:SetDesaturated(dead)
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
  if unit and Target and Target.GetClassRGB then
    local r, g, b = Target.GetClassRGB(unit)
    nameFS:SetTextColor(r, g, b, 1)
  else
    nameFS:SetTextColor(1, 1, 1, 1)
  end
end

local function SetRaidMarkerShown(shown)
  if raidMarker then
    raidMarker:SetShown(shown)
  end
  if raidMarkerFrame then
    raidMarkerFrame:SetShown(shown)
  end
end

local function UpdateRaidMarker(unit)
  if not raidMarker or not Target then
    return
  end
  local idx
  if previewActive then
    idx = previewRaidIndex
  else
    idx = Target.GetRaidTargetIndex and Target.GetRaidTargetIndex(unit)
  end
  if Target.ApplyRaidMarker and Target.ApplyRaidMarker(raidMarker, idx) then
    SetRaidMarkerShown(true)
    return
  end
  SetRaidMarkerShown(false)
end

local function UpdateIndex(unit)
  if not indexFS then
    return
  end
  local current, total
  if previewActive then
    current = previewIndex or 1
    total = PREVIEW_TOTAL
  elseif Target and Target.GetIndex then
    current, total = Target.GetIndex(unit)
  end
  local text = Target and Target.FormatIndex and Target.FormatIndex(current, total)
  if not text then
    indexFS:SetText("")
    indexFS:Hide()
    if Motion and Motion.HideCycleArrow then
      Motion.HideCycleArrow()
    end
    return
  end
  indexFS:SetText(text)
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

local function TickPreviewHealth(elapsed)
  if not healthBar or not HealthBar then
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
  HealthBar.ApplyPreview(healthBar, previewDisplayPct, nowDead, ApplyDeadChrome)
  if nowDead ~= previewDead then
    previewDead = nowDead
    ApplyNameColor("player", previewDead)
  end
  previewDead = nowDead
  HealthBar.SyncGlow(healthBar, previewDead)

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
    if Motion and Motion.StartCycle then
      Motion.StartCycle("up")
    end
  end
end

local function OnHudUpdateImpl(_, elapsed)
  if Motion and Motion.Tick then
    Motion.Tick(elapsed)
  end
  if not cluster or not cluster:IsShown() then
    return
  end
  if previewActive then
    TickPreviewHealth(elapsed)
  end
  if healthBar and HealthBar and HealthBar.TickGlow then
    HealthBar.TickGlow(healthBar, elapsed)
  end
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
    if cluster and cluster:IsShown() and not previewActive and Motion and Motion.ApplyRange then
      Motion.ApplyRange("target", false)
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
    and HealthBar
    and HealthBar.Update
  then
    HealthBar.Update(healthBar, "target", ApplyDeadChrome)
  end
end

local function BindMotion()
  if not Motion or not Motion.Attach then
    return
  end
  Motion.Attach({
    getCluster = function()
      return cluster
    end,
    getArrow = function()
      return cycleArrow
    end,
    getIndexFS = function()
      return indexFS
    end,
    getHealthBar = function()
      return healthBar
    end,
    getLayout = Layout,
    applyAnchor = AnchorCluster,
    onHidden = InvalidateClusterLayout,
  })
end

local function EnsureFrames()
  if not crosshairFrame then
    return
  end
  local L = Layout()
  local barW, barH = 72, 10
  if HealthBar and HealthBar.GetSize then
    barW, barH = HealthBar.GetSize()
  end

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

    local arrowS = L.cycleArrowSize or 12
    cycleArrow = cluster:CreateTexture(nil, "OVERLAY")
    cycleArrow:SetSize(arrowS, arrowS)
    cycleArrow:Hide()

    if HealthBar and HealthBar.Create then
      healthBar = HealthBar.Create(cluster)
      healthBar:SetSize(barW, barH)
    end

    local markerS = L.raidMarkerSize or 14
    raidMarkerFrame = CreateFrame("Frame", nil, cluster)
    raidMarkerFrame:SetSize(markerS, markerS)
    if healthBar then
      raidMarkerFrame:SetFrameLevel(healthBar:GetFrameLevel() + 5)
    end
    raidMarker = raidMarkerFrame:CreateTexture(nil, "OVERLAY")
    raidMarker:SetAllPoints(raidMarkerFrame)
    local raidTex = Target and Target.RAID_TARGET_TEXTURE
      or [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
    raidMarker:SetTexture(raidTex)
    raidMarker:Hide()

    BindMotion()
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
  local gap = L.gap or 2
  local indexGap = L.indexGap
  if type(indexGap) ~= "number" then
    indexGap = gap * 2
  end
  local nameLift = L.nameLift or 6
  local iconS = L.roleIconSize or 20
  local markerS = L.raidMarkerSize or 14
  local barW, barH = 72, 10
  if HealthBar and HealthBar.GetSize then
    barW, barH = HealthBar.GetSize()
  end
  local nameH = (L.nameFontSize or 11) + 2
  local indexH = (L.indexFontSize or 10) + 2
  local indexW = MeasureIndexWidth()
  local arrowS = L.cycleArrowSize or 12
  local arrowGap = L.cycleArrowGap
  if type(arrowGap) ~= "number" then
    arrowGap = 1
  end
  local arrowReserve = (indexW > 0) and (arrowS + arrowGap) or 0
  local rowH = math.max(iconS, barH, indexH, arrowS)
  local sidePad = math.max(iconS + gap, indexW > 0 and (indexW + indexGap + arrowReserve) or 0)
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
  if cycleArrow then
    cycleArrow:SetSize(arrowS, arrowS)
    if Motion and Motion.PlaceCycleArrow then
      Motion.PlaceCycleArrow()
    end
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
  local slideY = (Motion and Motion.GetSlideY and Motion.GetSlideY()) or 0
  AnchorCluster(slideY)
end

function CM.ApplyAllyCycleHUDLayout()
  return CM.Profile("AllyHUD:Layout", ApplyAllyCycleHUDLayoutImpl)
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
      or (
        CM.IsAllyCycleEnabled
        and CM.IsAllyCycleEnabled()
        and CM.IsAllyCycleFriendlyHardTarget
        and CM.IsAllyCycleFriendlyHardTarget()
      )
    )

  if not show then
    if Motion and Motion.RequestHide then
      Motion.RequestHide()
    end
    return
  end

  local unit = preview and "player" or "target"
  local dead = preview and previewDead or (Target and Target.IsDead and Target.IsDead(unit))
  if nameFS and Target and Target.GetDisplayName then
    nameFS:SetText(Target.GetDisplayName(unit, preview))
  end
  ApplyNameColor(unit, dead)
  UpdateRoleIcon(unit)
  UpdateRaidMarker(unit)
  UpdateIndex(unit)
  CM.ApplyAllyCycleHUDLayout()

  if preview then
    if HealthBar and HealthBar.ApplyPreview then
      HealthBar.ApplyPreview(healthBar, previewDisplayPct, previewDead, ApplyDeadChrome)
    end
    ApplyDeadChrome(previewDead)
  elseif HealthBar and HealthBar.Update then
    HealthBar.Update(healthBar, unit, ApplyDeadChrome)
  end

  if HealthBar and HealthBar.SyncGlow then
    HealthBar.SyncGlow(healthBar, dead)
  end
  if Motion and Motion.ApplyRange then
    Motion.ApplyRange(unit, preview)
  end

  if Motion and Motion.RequestShow then
    Motion.RequestShow()
  end
  if Motion and Motion.ConsumePending then
    Motion.ConsumePending()
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
