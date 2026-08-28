---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/CastProgress.lua — CROSSHAIR — swipe + cast break
---------------------------------------------------------------------------------------
--  What it does: Owns dark Cooldown cast-progress swipe, cast-GUID cancel-vs-success
--  tracking (secret-safe under instance taint), and interrupt/cancel cast-break
--  shake/flash for Assisted Combat.
--  Architecture / how it works:
--    • CM.AssistedHighlightCastProgress.Attach binds host chrome + fade/spell bridges
--      and optional stopPress/stopPulse (from Feedback).
--    • CreateSwipeTexture / LayoutCastProgressSwipe / UpdateCastProgressSwipe /
--      IsBreakActive / TickBreak / StopAll.
--    • CM.OnAssistedHighlightCastProgress — EventRouter CAST_FEEDBACK path.
--    • CastGuidsCompatible skips == when either GUID is secret; pending cancel uses a
--      public token (not GUID ~=) so deferred STOP cannot taint-error.
--    • Cast-break hostile flash reads CM.GetCrosshairReactionColor at flash time.
--  Related: Core/Crosshair/AssistedHighlight/Feedback.lua,
--  Core/Runtime/EventRouter.lua, Constants/Assets.lua, Constants/Gameplay.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local C_Timer = _G.C_Timer
local issecretvalue = _G.issecretvalue

-- Lua stdlib
local math = _G.math
local pcall = _G.pcall
local select = _G.select
local random = _G.math.random

local CastProgress = {}
CM.AssistedHighlightCastProgress = CastProgress

-- Bound by Attach
local getFrame
local getVisual
local getAnimDriver
local getFadeMode
local setFadeMode
local getLastShownSpellID
local previewSpellID = -1
local stopProcEffect
local stopPress
local stopPulse

-- Dark cast-progress swipe
local CAST_SWIPE_R, CAST_SWIPE_G, CAST_SWIPE_B, CAST_SWIPE_A = 0, 0, 0, 0.44

-- Interrupt/cancel cast break (shake + flash) — shared with crosshair Animations.
local CastBreak = CM.Constants.CrosshairCastBreak
local CAST_BREAK_DURATION = CastBreak.duration
local CAST_BREAK_SHAKE_PX = CastBreak.shakePx
local CAST_BREAK_FLASH_HZ = CastBreak.flashHz
local CAST_BREAK_COLOR_GREY = CastBreak.grey

local breakActive = false
local breakElapsed = 0
local breakSavedIconColor
local breakSavedGlowColor
local breakSavedFrameColor
-- Cast tracking for interrupt/cancel break (swipe + STOP/SUCCEEDED ordering).
local assistCastActive = false
local assistCastIsChannel = false
local assistCastInterrupted = false
local assistCastGUID = nil
local assistCastHadSuccess = false
-- Public generation token for deferred STOP→cancel (never compare secret GUIDs).
local assistCastPendingCancelToken = 0

local BeginCastBreak

-- True when event/tracked GUID is absent, they match, or either is secret (cannot
-- compare under taint; prefer completing swipe/break for the in-flight assist cast).
local function CastGuidsCompatible(eventGUID, trackedGUID)
  if not eventGUID or not trackedGUID then
    return true
  end
  if issecretvalue and (issecretvalue(eventGUID) or issecretvalue(trackedGUID)) then
    return true
  end
  return eventGUID == trackedGUID
end

local function InvalidatePendingCancel()
  assistCastPendingCancelToken = assistCastPendingCancelToken + 1
end

local function HostFrame()
  return getFrame and getFrame() or nil
end

local function HostVisual()
  return getVisual and getVisual() or nil
end

local function HostAnimDriver()
  return getAnimDriver and getAnimDriver() or nil
end

local function FadeMode()
  return getFadeMode and getFadeMode() or "hidden"
end

local function SetFadeMode(mode)
  if setFadeMode then
    setFadeMode(mode)
  end
end

local function LastShownSpellID()
  return getLastShownSpellID and getLastShownSpellID() or nil
end

local function ResetVisualTransform()
  local visual = HostVisual()
  if visual then
    visual:SetScale(1)
  end
end

local function CenterAssistVisual()
  local visual = HostVisual()
  local frame = HostFrame()
  if visual and frame then
    visual:ClearAllPoints()
    visual:SetPoint("CENTER", frame, "CENTER", 0, 0)
  end
end

local function SetVisualAlpha(alpha)
  local visual = HostVisual()
  if visual then
    visual:SetAlpha(math.max(0, math.min(1, alpha)))
  end
end

local function LayoutShellAroundIcon(region, icon, expand)
  if not (region and icon) then
    return
  end
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", icon, "TOPLEFT", -expand, expand)
  region:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", expand, -expand)
end

local function IsPreviewActive()
  return CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive()
end

---------------------------------------------------------------------------------------
--                    BREAK COLORS / ASSIST VISIBILITY                               --
---------------------------------------------------------------------------------------
local function RestoreBreakColors()
  local frame = HostFrame()
  if breakSavedIconColor and frame and frame.icon then
    local c = breakSavedIconColor
    frame.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedIconColor = nil
  if breakSavedGlowColor and frame and frame.glow then
    local c = breakSavedGlowColor
    frame.glow:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedGlowColor = nil
  if breakSavedFrameColor and frame and frame.frame then
    local c = breakSavedFrameColor
    frame.frame:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedFrameColor = nil
end

local function SaveBreakColors()
  breakSavedIconColor = nil
  breakSavedGlowColor = nil
  breakSavedFrameColor = nil
  local frame = HostFrame()
  local icon = frame and frame.icon
  if icon and icon.GetVertexColor then
    local r, g, b, a = icon:GetVertexColor()
    breakSavedIconColor = { r, g, b, a }
  end
  local glow = frame and frame.glow
  if glow and glow.GetVertexColor then
    local r, g, b, a = glow:GetVertexColor()
    breakSavedGlowColor = { r, g, b, a }
  end
  local frameTex = frame and frame.frame
  if frameTex and frameTex.GetVertexColor then
    local r, g, b, a = frameTex:GetVertexColor()
    breakSavedFrameColor = { r, g, b, a }
  end
end

local function ApplyBreakFlashColor(color)
  local frame = HostFrame()
  if not color or not frame then
    return
  end
  if frame.icon then
    frame.icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
  if frame.glow then
    frame.glow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
  if frame.frame then
    frame.frame:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function ClearCastBreakVisualState()
  breakActive = false
  breakElapsed = 0
  RestoreBreakColors()
  CenterAssistVisual()
  ResetVisualTransform()
  local visual = HostVisual()
  if visual then
    visual:SetAlpha(1)
  end
end

local function CancelCastBreak()
  if not breakActive then
    return
  end
  ClearCastBreakVisualState()
end

local function FinishCastBreak()
  ClearCastBreakVisualState()
  SetFadeMode("shown")
end

local function IsAssistVisibleForCastFeedback()
  local frame = HostFrame()
  local visual = HostVisual()
  if not (frame and visual) then
    return false
  end
  local mode = FadeMode()
  if mode == "hidden" or mode == "out" then
    return false
  end
  local shown = LastShownSpellID()
  if not shown or shown == previewSpellID then
    return false
  end
  return true
end

CastProgress.IsAssistVisibleForCastFeedback = IsAssistVisibleForCastFeedback

---------------------------------------------------------------------------------------
--                              CAST PROGRESS SWIPE                                  --
---------------------------------------------------------------------------------------
local function ApplyCooldownMask()
  local frame = HostFrame()
  local cd = frame and frame.cooldown
  local mask = frame and frame.iconMask
  if not (cd and mask) or cd.cooldownMaskAttached then
    return
  end
  local maskedAny = false
  local regionCount = select("#", cd:GetRegions())
  for i = 1, regionCount do
    local region = select(i, cd:GetRegions())
    if
      region
      and region.GetObjectType
      and region:GetObjectType() == "Texture"
      and region.AddMaskTexture
    then
      local ok = pcall(region.AddMaskTexture, region, mask)
      if ok then
        maskedAny = true
      end
    end
  end
  if maskedAny then
    cd.cooldownMaskAttached = true
  end
end

local function ClearCastProgressSwipe()
  local frame = HostFrame()
  local cd = frame and frame.cooldown
  if not cd then
    return
  end
  -- Hide alone leaves the swipe animating; reset cooldown first.
  cd:SetCooldown(0, 0)
  cd:Hide()
end

local function ResetAssistCastTracking()
  assistCastActive = false
  assistCastIsChannel = false
  assistCastInterrupted = false
  assistCastGUID = nil
  assistCastHadSuccess = false
  InvalidatePendingCancel()
end

--- Interrupt/cancel break while assist is visible.
local function TryAssistCastInterruptBreak()
  if IsPreviewActive() then
    return
  end
  if not IsAssistVisibleForCastFeedback() then
    return
  end
  BeginCastBreak()
end

function CastProgress.UpdateCastProgressSwipe()
  local frame = HostFrame()
  local cd = frame and frame.cooldown
  if not cd then
    return false
  end
  local mode = FadeMode()
  if mode == "hidden" or mode == "out" then
    ClearCastProgressSwipe()
    return false
  end

  local _, _, _, startMS, endMS = UnitCastingInfo("player")
  if not startMS then
    _, _, _, startMS, endMS = UnitChannelInfo("player")
  end
  if not (startMS and endMS) then
    ClearCastProgressSwipe()
    return false
  end

  local duration = (endMS - startMS) / 1000
  if duration <= 0 then
    ClearCastProgressSwipe()
    return false
  end

  if cd.SetSwipeColor then
    cd:SetSwipeColor(CAST_SWIPE_R, CAST_SWIPE_G, CAST_SWIPE_B, CAST_SWIPE_A)
  end
  cd:SetCooldown(startMS / 1000, duration)
  ApplyCooldownMask()
  cd:Show()
  return true
end

function CastProgress.LayoutCastProgressSwipe(icon, expand)
  local frame = HostFrame()
  local cd = frame and frame.cooldown
  if not (cd and icon) then
    return
  end
  LayoutShellAroundIcon(cd, icon, expand)
  ApplyCooldownMask()
end

function CastProgress.CreateSwipeTexture(frame, visual, assets)
  if not (frame and visual) then
    return
  end
  if frame.cooldown then
    return
  end
  local cooldown = CreateFrame("Cooldown", nil, visual, "CooldownFrameTemplate")
  cooldown:SetDrawEdge(false)
  cooldown:SetHideCountdownNumbers(true)
  if cooldown.SetDrawBling then
    cooldown:SetDrawBling(false)
  end
  if cooldown.SetUseCircularEdge then
    cooldown:SetUseCircularEdge(true)
  end
  local swipePath = assets and assets.AssistedSpellIconCooldownSwipe
  if swipePath and cooldown.SetSwipeTexture then
    pcall(cooldown.SetSwipeTexture, cooldown, swipePath)
  end
  if cooldown.SetSwipeColor then
    cooldown:SetSwipeColor(CAST_SWIPE_R, CAST_SWIPE_G, CAST_SWIPE_B, CAST_SWIPE_A)
  end
  cooldown:Hide()
  frame.cooldown = cooldown
end

---------------------------------------------------------------------------------------
--                              CAST BREAK (SHAKE / FLASH)                           --
---------------------------------------------------------------------------------------
BeginCastBreak = function()
  local frame = HostFrame()
  local visual = HostVisual()
  if not (frame and visual) then
    return
  end
  local mode = FadeMode()
  if mode == "hidden" or mode == "out" then
    return
  end
  ClearCastProgressSwipe()
  if stopPress then
    stopPress()
  end
  if stopPulse then
    stopPulse()
  end
  if stopProcEffect then
    stopProcEffect()
  end
  frame:Show()
  visual:Show()
  local driver = HostAnimDriver()
  if driver then
    driver:Show()
  end

  if not breakActive then
    SaveBreakColors()
  end
  ResetVisualTransform()
  CenterAssistVisual()
  SetVisualAlpha(1)

  breakActive = true
  breakElapsed = 0
  SetFadeMode("shown")
end

function CastProgress.TickBreak(elapsed)
  local visual = HostVisual()
  local frame = HostFrame()
  if not visual then
    breakActive = false
    return
  end
  breakElapsed = breakElapsed + elapsed
  if breakElapsed >= CAST_BREAK_DURATION then
    FinishCastBreak()
    return
  end
  local progress = math.min(1, breakElapsed / CAST_BREAK_DURATION)
  local decay = 1 - progress
  local ox = (random() * 2 - 1) * CAST_BREAK_SHAKE_PX * decay
  local oy = (random() * 2 - 1) * CAST_BREAK_SHAKE_PX * decay
  local flicker = (math.floor(breakElapsed * 40) % 2 == 0) and 1 or 0.55
  local alpha = flicker * (0.65 + 0.35 * progress)
  local hostile = CM.GetCrosshairReactionColor("hostile")
  local flash = ((math.floor(breakElapsed * CAST_BREAK_FLASH_HZ) % 2) == 0) and hostile
    or CAST_BREAK_COLOR_GREY
  ApplyBreakFlashColor(flash)
  visual:ClearAllPoints()
  visual:SetPoint("CENTER", frame, "CENTER", ox, oy)
  visual:SetScale(1)
  SetVisualAlpha(alpha)
end

function CastProgress.IsBreakActive()
  return breakActive
end

function CastProgress.StopAll()
  if breakActive then
    CancelCastBreak()
  end
  ClearCastProgressSwipe()
  ResetAssistCastTracking()
end

function CastProgress.Attach(opts)
  opts = opts or {}
  getFrame = opts.getFrame
  getVisual = opts.getVisual
  getAnimDriver = opts.getAnimDriver
  getFadeMode = opts.getFadeMode
  setFadeMode = opts.setFadeMode
  getLastShownSpellID = opts.getLastShownSpellID
  previewSpellID = opts.previewSpellID or -1
  stopProcEffect = opts.stopProcEffect
  stopPress = opts.stopPress
  stopPulse = opts.stopPulse
end

---------------------------------------------------------------------------------------
--                         EVENT HANDLERS (EventRouter)                              --
---------------------------------------------------------------------------------------
--- Cast/channel events → dark swipe; cancel/interrupt → cast break while visible.
function CM.OnAssistedHighlightCastProgress(event, castGUID)
  if IsPreviewActive() then
    return
  end

  if event == "UNIT_SPELLCAST_START" then
    assistCastGUID = castGUID
    assistCastIsChannel = false
    assistCastInterrupted = false
    assistCastHadSuccess = false
    InvalidatePendingCancel()
    CastProgress.UpdateCastProgressSwipe()
    -- Track even if swipe is not shown yet (cancel break while assist is up).
    assistCastActive = IsAssistVisibleForCastFeedback()
    return
  end

  if event == "UNIT_SPELLCAST_CHANNEL_START" then
    assistCastGUID = castGUID
    assistCastIsChannel = true
    assistCastInterrupted = false
    assistCastHadSuccess = false
    InvalidatePendingCancel()
    CastProgress.UpdateCastProgressSwipe()
    assistCastActive = IsAssistVisibleForCastFeedback()
    return
  end

  if event == "UNIT_SPELLCAST_DELAYED" then
    if assistCastActive then
      CastProgress.UpdateCastProgressSwipe()
    end
    return
  end

  if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    local matched = assistCastActive and CastGuidsCompatible(castGUID, assistCastGUID)
    assistCastInterrupted = true
    if matched then
      assistCastActive = false
      InvalidatePendingCancel()
      TryAssistCastInterruptBreak()
    else
      ClearCastProgressSwipe()
    end
    return
  end

  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    -- Channel ticks fire SUCCEEDED; latch cast-time success so STOP does not break.
    if not assistCastIsChannel and CastGuidsCompatible(castGUID, assistCastGUID) then
      assistCastHadSuccess = true
      InvalidatePendingCancel()
      ClearCastProgressSwipe()
    end
    return
  end

  if event == "UNIT_SPELLCAST_STOP" then
    ClearCastProgressSwipe()
    local matched = assistCastActive
      and not assistCastIsChannel
      and CastGuidsCompatible(castGUID, assistCastGUID)
    local shouldBreak = matched and not assistCastHadSuccess and not assistCastInterrupted
    assistCastActive = false
    if shouldBreak then
      -- STOP can arrive before SUCCEEDED; defer one frame (public token, not GUID ~=).
      assistCastPendingCancelToken = assistCastPendingCancelToken + 1
      local token = assistCastPendingCancelToken
      C_Timer.After(0, function()
        if assistCastPendingCancelToken ~= token then
          return
        end
        InvalidatePendingCancel()
        if assistCastHadSuccess then
          assistCastGUID = nil
          assistCastHadSuccess = false
          return
        end
        assistCastGUID = nil
        assistCastHadSuccess = false
        TryAssistCastInterruptBreak()
      end)
    else
      assistCastGUID = nil
      assistCastHadSuccess = false
    end
    return
  end

  if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    ClearCastProgressSwipe()
    -- Natural channel end has no INTERRUPTED; break only if cut short.
    local shouldBreak = assistCastActive and assistCastInterrupted
    assistCastActive = false
    assistCastIsChannel = false
    assistCastInterrupted = false
    assistCastGUID = nil
    assistCastHadSuccess = false
    InvalidatePendingCancel()
    if shouldBreak then
      TryAssistCastInterruptBreak()
    end
  end
end
