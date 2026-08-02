---------------------------------------------------------------------------------------
--  Core/Crosshair/InteractionHUD/Visual.lua — CROSSHAIR — cluster fade / range dim
---------------------------------------------------------------------------------------
--  What it does: Owns Interaction HUD cluster fade in/out and icon range dim lerp.
--  Architecture / how it works:
--    • CM.InteractionHUDVisual.Attach({ getCluster, getIcon, getLabel, getShadow,
--      isPreviewActive }) binds host chrome.
--    • RequestShow / RequestHide set fade target; Hide snaps range blend on next show.
--    • Tick(elapsed) = OnUpdate visual pass (calls Target.GetCursorDim when not preview).
--  Does not: Own softinteract identity, cluster layout, SoftTarget CVars.
--  Related: Core/Crosshair/InteractionHUD/{Target,HUD}.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local math = _G.math

local Target = CM.InteractionHUDTarget

local Visual = {}
CM.InteractionHUDVisual = Visual

-- Bound by Attach
local getCluster
local getIcon
local getLabel
local getShadow
local isPreviewActive

local ihRangeBlend -- 0 = out of range, 1 = in range (lerped)
local ihSnapRangeBlend = true -- snap on next HUD show after hide
local ihClusterFade = 0 -- parent alpha (fade in / fade out)
local ihClusterFadeTarget = 0 -- 0 = hidden, 1 = visible

local IH_NAME_COLOR = { 1, 204 / 255, 0 }
local IH_NAME_OPACITY = 0.8
local IH_SHADOW_ALPHA = 0.7 -- fixed; not tied to crosshair opacity
local IH_DIM_MIN = 0.5
local IH_DIM_MAX = 0.9
local IH_RANGE_LERP_SPEED = 14
local IH_CLUSTER_FADE_SPEED = 16

local function HostCluster()
  return getCluster and getCluster() or nil
end

local function HostIcon()
  return getIcon and getIcon() or nil
end

local function HostLabel()
  return getLabel and getLabel() or nil
end

local function HostShadow()
  return getShadow and getShadow() or nil
end

function Visual.Attach(opts)
  opts = opts or {}
  getCluster = opts.getCluster
  getIcon = opts.getIcon
  getLabel = opts.getLabel
  getShadow = opts.getShadow
  isPreviewActive = opts.isPreviewActive
end

function Visual.GetClusterFade()
  return ihClusterFade
end

function Visual.GetClusterFadeTarget()
  return ihClusterFadeTarget
end

function Visual.ResetFadeState()
  ihClusterFade = 0
  ihClusterFadeTarget = 0
end

function Visual.RequestShow()
  ihClusterFadeTarget = 1
end

function Visual.RequestHide()
  ihSnapRangeBlend = true
  local cluster = HostCluster()
  if not cluster then
    ihClusterFadeTarget = 0
    return
  end
  ihClusterFadeTarget = 0
  if not cluster:IsShown() then
    return
  end
  if ihClusterFade <= 0.001 then
    cluster:Hide()
  end
end

function Visual.Tick(elapsed)
  local cluster = HostCluster()
  if not cluster then
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
  cluster:SetAlpha(ihClusterFade)
  if ihClusterFadeTarget == 0 and ihClusterFade <= 0.001 then
    cluster:Hide()
    ihClusterFade = 0
    return
  end

  if not cluster:IsShown() then
    return
  end
  -- Fading out: do not call SetUnitCursorTexture — softinteract may already be cleared.
  if ihClusterFadeTarget == 0 then
    return
  end
  local g = CM.DB and CM.DB.global
  local icon = HostIcon()
  local label = HostLabel()
  local shadow = HostShadow()
  if not g or g.interactionHUD ~= true or not CM.IsCrosshairEnabled() or not icon or not label then
    return
  end
  -- Preview keeps the placeholder art: SetUnitCursorTexture would clear it without a target.
  local inRange = true
  local preview = isPreviewActive and isPreviewActive()
  if not preview and Target and Target.GetCursorDim then
    local _, cursorInRange = Target.GetCursorDim(icon)
    inRange = cursorInRange
  end
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
  -- Range dimming applies to the icon only; name/shadow use fixed alphas.
  label:SetTextColor(IH_NAME_COLOR[1], IH_NAME_COLOR[2], IH_NAME_COLOR[3], 1)
  if shadow then
    shadow:SetAlpha(IH_SHADOW_ALPHA)
  end
  icon:SetAlpha(dim)
  label:SetAlpha(IH_NAME_OPACITY)
end
