---------------------------------------------------------------------------------------
--  Core/AllyCycle/Motion.lua — ALLYCYCLE — cluster fade, slide, cycle arrow
---------------------------------------------------------------------------------------
--  What it does: Owns Ally HUD fade with Mouse Look, cycle slide-in, and the housing
--  floor arrow that travels beside the index (prev up / next down).
--  Architecture / how it works:
--    • CM.AllyCycleMotion.Attach({ getCluster, getArrow, getIndexFS, getHealthBar,
--      getLayout, applyAnchor, onHidden }) binds host chrome.
--    • RequestShow / RequestHide set fade target; Tick is the OnUpdate visual pass.
--    • CM.NotifyAllyCycleHUD latches direction; HUD Refresh calls ConsumePending.
--    • Range alpha from AllyCycleTarget — SetAlpha raw, never multiply by secret.
--    • Dirty cluster alpha; applyAnchor is HUD AnchorCluster (side / scale / padding).
--  Does not: Own frames, health-bar glow, or unit identity.
--  Related: Core/AllyCycle/{Target,HealthBar,HUD,Cycle}.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetAtlasInfo = _G.C_Texture and _G.C_Texture.GetAtlasInfo

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local math = _G.math
local type = _G.type

local Target = CM.AllyCycleTarget

local Motion = {}
CM.AllyCycleMotion = Motion

local getCluster
local getArrow
local getIndexFS
local getHealthBar
local getLayout
local applyAnchor
local onHidden

local pendingCycleDir = nil
local cycleAnim = nil
local cycleSlideY = 0
local cycleSlideA = 1
local lastRangeAlpha = 1
local lastAppliedClusterA = nil
local hudFade = 0
local hudFadeTarget = 0
local HUD_FADE_SPEED = 16
local cycleAnimState = { elapsed = 0, dur = 0.14, fromY = 0, fromA = 0.75 }
local cycleArrowHold = 0
local cycleArrowHoldMax = 0.32
local cycleArrowY = 0
local cycleArrowTravelSign = 0
local ARROW_UP = "housing-floor-arrow-up-default"
local ARROW_DOWN = "housing-floor-arrow-down-default"

local function IsSecret(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end

local function PublicNumber(v, fallback)
  if v == nil or IsSecret(v) or type(v) ~= "number" then
    return fallback
  end
  return v
end

local function HostCluster()
  return getCluster and getCluster() or nil
end

local function HostArrow()
  return getArrow and getArrow() or nil
end

local function HostIndexFS()
  return getIndexFS and getIndexFS() or nil
end

local function HostHealthBar()
  return getHealthBar and getHealthBar() or nil
end

local function HostLayout()
  return getLayout and getLayout() or nil
end

function Motion.Attach(opts)
  opts = opts or {}
  getCluster = opts.getCluster
  getArrow = opts.getArrow
  getIndexFS = opts.getIndexFS
  getHealthBar = opts.getHealthBar
  getLayout = opts.getLayout
  applyAnchor = opts.applyAnchor
  onHidden = opts.onHidden
end

function Motion.GetSlideY()
  return cycleSlideY
end

local function PlaceCycleArrow()
  local cycleArrow = HostArrow()
  if not cycleArrow then
    return
  end
  local L = HostLayout() or {}
  local arrowGap = L.cycleArrowGap
  if type(arrowGap) ~= "number" then
    arrowGap = 0
  end
  cycleArrow:ClearAllPoints()
  local indexFS = HostIndexFS()
  local healthBar = HostHealthBar()
  if indexFS then
    cycleArrow:SetPoint("LEFT", indexFS, "RIGHT", arrowGap, cycleArrowY)
  elseif healthBar then
    cycleArrow:SetPoint("LEFT", healthBar, "RIGHT", L.indexGap or 2, cycleArrowY)
  end
end

function Motion.PlaceCycleArrow()
  PlaceCycleArrow()
end

local function HideCycleArrow()
  cycleArrowHold = 0
  cycleArrowY = 0
  cycleArrowTravelSign = 0
  local cycleArrow = HostArrow()
  if cycleArrow then
    cycleArrow:SetAlpha(1)
    cycleArrow:Hide()
  end
end

local function ResetCycleAnim()
  pendingCycleDir = nil
  cycleAnim = nil
  cycleSlideY = 0
  cycleSlideA = 1
  HideCycleArrow()
end

function Motion.HideCycleArrow()
  HideCycleArrow()
end

-- SetAlpha accepts secret range alpha; Lua * does not.
local function ApplyClusterAlpha()
  local cluster = HostCluster()
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
  if applyAnchor then
    applyAnchor(cycleSlideY)
  end
end

local function NotifyHidden()
  lastRangeAlpha = 1
  lastAppliedClusterA = nil
  if onHidden then
    onHidden()
  end
end

function Motion.RequestHide()
  hudFadeTarget = 0
  local cluster = HostCluster()
  if not cluster or not cluster:IsShown() then
    hudFade = 0
    ResetCycleAnim()
    NotifyHidden()
    if cluster then
      cluster:Hide()
    end
    return
  end
  if hudFade <= 0.001 then
    hudFade = 0
    ResetCycleAnim()
    NotifyHidden()
    cluster:Hide()
  end
end

function Motion.RequestShow()
  hudFadeTarget = 1
  local cluster = HostCluster()
  if cluster then
    cluster:Show()
  end
end

local function ShowCycleArrow(dir)
  local cycleArrow = HostArrow()
  if not cycleArrow or not cycleArrow.SetAtlas then
    return
  end
  -- Next is roster "up" → down arrow traveling down. Previous is "down" → up arrow traveling up.
  local atlas = (dir == "down") and ARROW_UP or ARROW_DOWN
  if GetAtlasInfo and not GetAtlasInfo(atlas) then
    HideCycleArrow()
    return
  end
  local L = HostLayout() or {}
  cycleArrow:SetAtlas(atlas, false)
  cycleArrow:SetAlpha(1)
  cycleArrow:Show()
  cycleArrowTravelSign = (dir == "down") and 1 or -1
  cycleArrowY = 0
  cycleArrowHoldMax = L.cycleArrowHold or 0.32
  cycleArrowHold = cycleArrowHoldMax
  PlaceCycleArrow()
end

local function TickCycleArrow(elapsed)
  if cycleArrowHold <= 0 then
    return
  end
  cycleArrowHold = cycleArrowHold - (elapsed or 0)
  local maxHold = cycleArrowHoldMax
  if type(maxHold) ~= "number" or maxHold <= 0 then
    HideCycleArrow()
    return
  end
  local t = 1 - math.max(0, cycleArrowHold) / maxHold
  if t < 0 then
    t = 0
  elseif t > 1 then
    t = 1
  end
  local eased = t * t * (3 - 2 * t)
  local L = HostLayout() or {}
  local travel = L.cycleArrowTravel or 5
  cycleArrowY = cycleArrowTravelSign * travel * eased
  local cycleArrow = HostArrow()
  if cycleArrow then
    cycleArrow:SetAlpha(1 - t)
  end
  PlaceCycleArrow()
  if cycleArrowHold <= 0 then
    HideCycleArrow()
  end
end

function Motion.StartCycle(dir)
  local L = HostLayout() or {}
  local px = L.cycleSlidePx or 3
  cycleAnimState.elapsed = 0
  cycleAnimState.dur = L.cycleAnimSec or 0.14
  cycleAnimState.fromY = (dir == "down") and px or -px
  cycleAnimState.fromA = L.cycleAnimFromAlpha or 0.75
  cycleAnim = cycleAnimState
  cycleSlideY = cycleAnim.fromY
  cycleSlideA = cycleAnim.fromA
  ShowCycleArrow(dir)
  ApplyClusterVisual()
end

function Motion.Notify(direction)
  if direction == "down" then
    pendingCycleDir = "down"
  else
    pendingCycleDir = "up"
  end
end

function CM.NotifyAllyCycleHUD(direction)
  Motion.Notify(direction)
end

function Motion.ConsumePending()
  if not pendingCycleDir then
    return
  end
  local dir = pendingCycleDir
  pendingCycleDir = nil
  Motion.StartCycle(dir)
end

function Motion.ApplyRange(unit, preview)
  local L = HostLayout() or {}
  local outA = L.outOfRangeAlpha or 0.3
  if Target and Target.GetRangeAlpha then
    lastRangeAlpha = Target.GetRangeAlpha(unit, preview, outA)
  else
    lastRangeAlpha = 1
  end
  ApplyClusterAlpha()
end

local function TickHudFade(elapsed)
  local cluster = HostCluster()
  if not cluster then
    return
  end
  if math.abs(hudFade - hudFadeTarget) <= 0.001 then
    hudFade = hudFadeTarget
    if hudFadeTarget == 0 and hudFade <= 0.001 and cluster:IsShown() then
      hudFade = 0
      ResetCycleAnim()
      NotifyHidden()
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
    NotifyHidden()
    cluster:Hide()
  end
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

function Motion.Tick(elapsed)
  TickHudFade(elapsed)
  local cluster = HostCluster()
  if not cluster or not cluster:IsShown() then
    return
  end
  TickCycleAnim(elapsed)
  TickCycleArrow(elapsed)
end
