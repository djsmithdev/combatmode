---------------------------------------------------------------------------------------
--  Core/Crosshair/Animations.lua — CROSSHAIR — cursor pulse + reticle cast feedback
---------------------------------------------------------------------------------------
--  What it does: Purely visual helpers for the reticle and cursor: unlock pulse, reaction
--  scale/appearance helpers, focus lock-in tween, and cast grow / explode / break gated
--  by crosshairCastFeedback. One outer OnUpdate drives reticle motion at a time.
--  Architecture / how it works:
--    • InitializeCursorPulse / ShowCursorPulse — Blizzard PulseAtlas at cursor after unlock.
--    • InitCrosshairAnimations registers visual frame/texture from Crosshair.
--    • StartCrosshairCastGrow / Explode / Break + NotifyCrosshairCastTerminal — EventRouter
--      CAST_FEEDBACK path; CancelCrosshairCastFeedback / CancelCrosshairLockIn.
--    • Shared scale animation constructors used by options preview appearance apply.
--  Does not: Own Assisted Combat ProcLoop FlipBook (AssistedHighlight/Motion.lua) /
--  interrupt cast break (AssistedHighlight/CastProgress.lua) or mouselook / CVar writes.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/AssistedHighlight/Assist.lua,
--  Core/Crosshair/AssistedHighlight/Motion.lua, Core/Crosshair/AssistedHighlight/Feedback.lua,
--  Core/FreeLook/FreeLookController.lua, Constants/Assets.lua,
--  UI/Options/Tabs/TabCrosshair.lua, Core/Runtime/EventRouter.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local GetTime = _G.GetTime
local IsMouselooking = _G.IsMouselooking
local UIParent = _G.UIParent
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo

-- Lua stdlib
local math = _G.math
local unpack = _G.unpack
local random = _G.math.random

---------------------------------------------------------------------------------------
--                                   CURSOR PULSE                                   --
---------------------------------------------------------------------------------------
local PULSE_ATLAS = "dragonflight-landingbutton-circleglow"
local PULSE_DURATION = 0.4
local PULSE_STARTING_ALPHA = 0.5
local PULSE_STARTING_SIZE = 256
local PULSE_TOTAL_ELAPSED = -1

local PulseFrame = CreateFrame("Frame", nil, UIParent)
local PulseTexture = PulseFrame:CreateTexture(nil, "BACKGROUND")

function CM.InitializeCursorPulse()
  PulseFrame:SetSize(0, 0)
  PulseFrame:Hide()
  PulseTexture:SetAtlas(PULSE_ATLAS, true)
  PulseTexture:SetVertexColor(1, 1, 1, 1)
  PulseTexture:SetAllPoints()
end

local function UpdatePulse(_, elapsed)
  if PULSE_TOTAL_ELAPSED == -1 then
    return
  end

  PULSE_TOTAL_ELAPSED = PULSE_TOTAL_ELAPSED + elapsed
  if PULSE_TOTAL_ELAPSED > PULSE_DURATION then
    PULSE_TOTAL_ELAPSED = -1
    PulseFrame:Hide()
    return
  end

  local progress = PULSE_TOTAL_ELAPSED / PULSE_DURATION
  local invertedProgress = 1 - progress * progress

  local alpha = invertedProgress * PULSE_STARTING_ALPHA
  PulseTexture:SetAlpha(alpha)

  local size = invertedProgress * PULSE_STARTING_SIZE
  PulseFrame:SetSize(size, size)

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  PulseFrame:SetPoint(
    "BOTTOMLEFT",
    UIParent,
    "BOTTOMLEFT",
    (cursorX / scale) - size / 2,
    (cursorY / scale) - size / 2
  )
end

function CM.ShowCursorPulse()
  PULSE_TOTAL_ELAPSED = 0
  PulseFrame:Show()
end

PulseFrame:SetScript("OnUpdate", UpdatePulse)

---------------------------------------------------------------------------------------
--                        CROSSHAIR REACTION (SCALE ANIM)                            --
---------------------------------------------------------------------------------------
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

--- Apply crosshair texture, color, and scale animation to a frame (live reticle or edit preview).
--- @param verticalOffset number Y offset from parent center (world crosshair uses saved crosshairY; preview uses 0).
--- @param previewMode boolean If true, always show the texture for non-mounted states (no mouselook check).
local function ApplyCrosshairAppearanceToWidget(
  targetFrame,
  targetTexture,
  animGroup,
  state,
  verticalOffset,
  previewMode
)
  local CrosshairAppearance = CM.DB.global.crosshairAppearance
  if not CrosshairAppearance then
    return
  end

  local parent = targetFrame:GetParent()

  -- Target Lock idle Dot: Crosshair.lua owns texture/tint; skip all reaction changes.
  if CM.IsFocusLockReticleSuppressed and CM.IsFocusLockReticleSuppressed() then
    if animGroup and animGroup.Stop then
      animGroup:Stop()
    end
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
    return
  end

  local r, g, b, a = unpack(CM.Constants.CrosshairReactionColors[state])
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false

  targetTexture:SetTexture(textureToUse)
  targetTexture:SetVertexColor(r, g, b, a)
  if previewMode or (state ~= "mounted" and IsMouselooking()) then
    targetTexture:Show()
  end

  -- Cast feedback owns visual scale/offset; skip reaction Scale anim while active.
  if CM.IsCrosshairCastFeedbackActive and CM.IsCrosshairCastFeedbackActive() then
    return
  end

  animGroup:SetScript("OnFinished", function()
    if state ~= "base" then
      targetFrame:SetScale(ENDING_SCALE)
      targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset / ENDING_SCALE)
    end
  end)

  animGroup:Play(reverseAnimation)
  if state == "base" then
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
  end
end

CM.ApplyCrosshairAppearanceToWidget = ApplyCrosshairAppearanceToWidget

---------------------------------------------------------------------------------------
--                    CROSSHAIR MOTION (LOCK-IN + CAST FEEDBACK)                      --
---------------------------------------------------------------------------------------
local MOTION_IDLE = 0
local MOTION_LOCK_IN = 1
local MOTION_GROW = 2
local MOTION_EXPLODE = 3
local MOTION_BREAK = 4
local MOTION_RESTORE = 5

local LOCK_IN_DURATION = 0.25
local CAST_GROW_MAX_SCALE = 1.35
local CAST_EXPLODE_DURATION = 0.22
local CAST_EXPLODE_EXTRA_SCALE = 0.4 -- added on top of current grow scale
local CAST_RESTORE_DURATION = 0.16
local CAST_BREAK_DURATION = 0.18
local CAST_BREAK_SHAKE_PX = 5
local CAST_BREAK_FLASH_HZ = 22
local CAST_BASE_SCALE = 1.0
local CAST_SUCCESS_PROGRESS = 0.85 -- STOP / CHANNEL_STOP treated as success at/above this

local CAST_BREAK_COLOR_RED = { 1, 0.2, 0.3, 1 }
local CAST_BREAK_COLOR_GREY = { 0.72, 0.72, 0.72, 1 }

local motionState = MOTION_IDLE
local motionElapsed = 0
local motionStartScale = 1.0
local motionStartAlpha = 1.0
local motionExplodePeak = 1.4
local lockInStartScale = 1.3
local lockInStartAlpha = 0.0
local lockInTargetScale = 1.0
local lockInTargetAlpha = 1.0

local castGUID = nil
local castIsChannel = false
local castInterrupted = false
local castProgress = 0
local growStartMS = nil
local growEndMS = nil
local breakSavedVertexColor = nil

local crosshairOuterFrame
local crosshairVisualFrame
local crosshairTexture
local onCrosshairLockInComplete

local function Clamp01(value)
  return math.max(0, math.min(1, value))
end

local function EaseOutQuad(progress)
  local inv = 1 - progress
  return 1 - inv * inv
end

local function GetConfiguredOpacity()
  local defaults = CM.Constants.DatabaseDefaults.global
  local cfg = CM.DB.global or {}
  return cfg.crosshairOpacity or defaults.crosshairOpacity
end

local function CenterVisual()
  if crosshairVisualFrame and crosshairOuterFrame then
    crosshairVisualFrame:SetPoint("CENTER", crosshairOuterFrame, "CENTER", 0, 0)
  end
end

local function RestoreBreakVertexColor()
  if not (breakSavedVertexColor and crosshairTexture) then
    return
  end
  local c = breakSavedVertexColor
  crosshairTexture:SetVertexColor(c[1], c[2], c[3], c[4])
  breakSavedVertexColor = nil
end

local function ResetVisualToBase()
  if not crosshairVisualFrame then
    return
  end
  crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
  crosshairVisualFrame:SetAlpha(GetConfiguredOpacity())
  CenterVisual()
  RestoreBreakVertexColor()
end

local function SetMotionIdle()
  motionState = MOTION_IDLE
  motionElapsed = 0
  castGUID = nil
  castIsChannel = false
  castInterrupted = false
  castProgress = 0
  growStartMS = nil
  growEndMS = nil
end

local function IsCastFeedbackMotion()
  return motionState == MOTION_GROW
    or motionState == MOTION_EXPLODE
    or motionState == MOTION_BREAK
    or motionState == MOTION_RESTORE
end

local function CastGUIDMatches(eventGUID)
  if eventGUID and castGUID and eventGUID ~= castGUID then
    return false
  end
  return true
end

function CM.IsCrosshairCastFeedbackActive()
  return IsCastFeedbackMotion()
end

function CM.CancelCrosshairCastFeedback()
  if not IsCastFeedbackMotion() then
    castGUID = nil
    castIsChannel = false
    return
  end
  SetMotionIdle()
  ResetVisualToBase()
end

function CM.CancelCrosshairLockIn()
  if motionState == MOTION_LOCK_IN then
    SetMotionIdle()
  end
end

local function ReadCastTiming(isChannel)
  local startTimeMS, endTimeMS
  if isChannel then
    local _
    _, _, _, startTimeMS, endTimeMS = UnitChannelInfo("player")
  else
    local _
    _, _, _, startTimeMS, endTimeMS = UnitCastingInfo("player")
  end
  if not startTimeMS or not endTimeMS or endTimeMS <= startTimeMS then
    return nil, nil
  end
  return startTimeMS, endTimeMS
end

local function ReadCastProgress()
  local startTimeMS, endTimeMS = ReadCastTiming(castIsChannel)
  if startTimeMS then
    growStartMS, growEndMS = startTimeMS, endTimeMS
  else
    startTimeMS, endTimeMS = growStartMS, growEndMS
  end
  if not startTimeMS or not endTimeMS or endTimeMS <= startTimeMS then
    return nil
  end
  return Clamp01((GetTime() * 1000 - startTimeMS) / (endTimeMS - startTimeMS))
end

local function UpdateLockIn(elapsed)
  motionElapsed = motionElapsed + elapsed
  if motionElapsed >= LOCK_IN_DURATION then
    SetMotionIdle()
    if crosshairVisualFrame then
      crosshairVisualFrame:SetScale(lockInTargetScale)
      crosshairVisualFrame:SetAlpha(lockInTargetAlpha)
      CenterVisual()
    end
    if onCrosshairLockInComplete then
      onCrosshairLockInComplete()
    end
    return
  end

  local t = EaseOutQuad(Clamp01(motionElapsed / LOCK_IN_DURATION))
  if crosshairVisualFrame then
    local scale = lockInStartScale + (lockInTargetScale - lockInStartScale) * t
    local alpha = lockInStartAlpha + (lockInTargetAlpha - lockInStartAlpha) * t
    crosshairVisualFrame:SetScale(math.max(0.01, scale))
    crosshairVisualFrame:SetAlpha(alpha)
  end
end

local function UpdateGrow()
  local progress = ReadCastProgress()
  if not progress then
    return -- hold until a terminal cast event
  end
  castProgress = progress
  -- Linear base + cubic end kick (keeps long casts moving; ramps near finish).
  local eased = 0.55 * progress + 0.45 * progress * progress * progress
  local scale = CAST_BASE_SCALE + (CAST_GROW_MAX_SCALE - CAST_BASE_SCALE) * eased
  if crosshairVisualFrame then
    crosshairVisualFrame:SetScale(math.max(0.01, scale))
  end
end

local function BeginRestoreFromExplode()
  if not crosshairVisualFrame then
    SetMotionIdle()
    ResetVisualToBase()
    return
  end
  CenterVisual()
  crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
  crosshairVisualFrame:SetAlpha(0)
  motionState = MOTION_RESTORE
  motionElapsed = 0
  castGUID = nil
end

local function UpdateExplode(elapsed)
  motionElapsed = motionElapsed + elapsed
  if motionElapsed >= CAST_EXPLODE_DURATION then
    BeginRestoreFromExplode()
    return
  end
  local progress = Clamp01(motionElapsed / CAST_EXPLODE_DURATION)
  local scale = motionStartScale + (motionExplodePeak - motionStartScale) * EaseOutQuad(progress)
  local alpha = motionStartAlpha * (1 - progress * (2 - progress))
  if crosshairVisualFrame then
    crosshairVisualFrame:SetScale(math.max(0.01, scale))
    crosshairVisualFrame:SetAlpha(math.max(0, alpha))
  end
end

local function UpdateRestore(elapsed)
  motionElapsed = motionElapsed + elapsed
  local opacity = GetConfiguredOpacity()
  if motionElapsed >= CAST_RESTORE_DURATION then
    SetMotionIdle()
    if crosshairVisualFrame then
      crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
      crosshairVisualFrame:SetAlpha(opacity)
      CenterVisual()
    end
    return
  end
  local t = EaseOutQuad(Clamp01(motionElapsed / CAST_RESTORE_DURATION))
  if crosshairVisualFrame then
    crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
    crosshairVisualFrame:SetAlpha(opacity * t)
  end
end

local function UpdateBreak(elapsed)
  motionElapsed = motionElapsed + elapsed
  if motionElapsed >= CAST_BREAK_DURATION then
    SetMotionIdle()
    ResetVisualToBase()
    return
  end
  local progress = Clamp01(motionElapsed / CAST_BREAK_DURATION)
  local decay = 1 - progress
  local ox = (random() * 2 - 1) * CAST_BREAK_SHAKE_PX * decay
  local oy = (random() * 2 - 1) * CAST_BREAK_SHAKE_PX * decay
  local scale = motionStartScale + (CAST_BASE_SCALE - motionStartScale) * progress
  local flicker = (math.floor(motionElapsed * 40) % 2 == 0) and 1 or 0.55
  local alpha = GetConfiguredOpacity() * flicker * (0.65 + 0.35 * progress)
  if crosshairTexture then
    local c = ((math.floor(motionElapsed * CAST_BREAK_FLASH_HZ) % 2) == 0) and CAST_BREAK_COLOR_RED
      or CAST_BREAK_COLOR_GREY
    crosshairTexture:SetVertexColor(c[1], c[2], c[3], c[4])
  end
  if crosshairVisualFrame and crosshairOuterFrame then
    crosshairVisualFrame:SetPoint("CENTER", crosshairOuterFrame, "CENTER", ox, oy)
    crosshairVisualFrame:SetScale(math.max(0.01, scale))
    crosshairVisualFrame:SetAlpha(alpha)
  end
end

local motionUpdaters = {
  [MOTION_LOCK_IN] = UpdateLockIn,
  [MOTION_GROW] = function()
    UpdateGrow()
  end,
  [MOTION_EXPLODE] = UpdateExplode,
  [MOTION_BREAK] = UpdateBreak,
  [MOTION_RESTORE] = UpdateRestore,
}

local function OnCrosshairMotionUpdate(_, elapsed)
  local updater = motionUpdaters[motionState]
  if updater then
    updater(elapsed)
  end
end

function CM.InitCrosshairAnimations(opts)
  if not opts then
    return
  end
  crosshairOuterFrame = opts.outerFrame
  crosshairVisualFrame = opts.visualFrame
  crosshairTexture = opts.texture
  onCrosshairLockInComplete = opts.onLockInComplete
  if crosshairOuterFrame and crosshairOuterFrame.SetScript then
    crosshairOuterFrame:SetScript("OnUpdate", OnCrosshairMotionUpdate)
  end
end

function CM.ShowCrosshairLockIn()
  if CM.IsFocusLockReticleSuppressed and CM.IsFocusLockReticleSuppressed() then
    return
  end
  if not (CM.IsCrosshairEnabled and CM.IsCrosshairEnabled()) then
    return
  end
  if not (crosshairOuterFrame and crosshairVisualFrame and crosshairTexture) then
    return
  end

  CM.CancelCrosshairCastFeedback()
  crosshairTexture:Show()

  lockInStartScale = crosshairVisualFrame:GetScale() * 1.3
  lockInStartAlpha = 0.0
  lockInTargetScale = CAST_BASE_SCALE
  lockInTargetAlpha = GetConfiguredOpacity()

  CenterVisual()
  crosshairVisualFrame:SetScale(lockInStartScale)
  crosshairVisualFrame:SetAlpha(lockInStartAlpha)
  motionState = MOTION_LOCK_IN
  motionElapsed = 0
end

function CM.StartCrosshairCastGrow(eventGUID, isChannel)
  if not (crosshairOuterFrame and crosshairVisualFrame and crosshairTexture) then
    return
  end

  CM.CancelCrosshairLockIn()
  if
    motionState == MOTION_EXPLODE
    or motionState == MOTION_BREAK
    or motionState == MOTION_RESTORE
  then
    ResetVisualToBase()
  end

  castGUID = eventGUID
  castIsChannel = isChannel and true or false
  castInterrupted = false
  castProgress = 0
  growStartMS, growEndMS = ReadCastTiming(castIsChannel)
  motionState = MOTION_GROW
  motionElapsed = 0

  CenterVisual()
  crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
  crosshairVisualFrame:SetAlpha(GetConfiguredOpacity())
end

local function BeginExplode(eventGUID)
  if motionState ~= MOTION_GROW or not CastGUIDMatches(eventGUID) or not crosshairVisualFrame then
    return false
  end
  motionStartScale = crosshairVisualFrame:GetScale() or CAST_GROW_MAX_SCALE
  motionStartAlpha = crosshairVisualFrame:GetAlpha() or GetConfiguredOpacity()
  motionExplodePeak = motionStartScale + CAST_EXPLODE_EXTRA_SCALE
  motionState = MOTION_EXPLODE
  motionElapsed = 0
  castGUID = nil
  return true
end

local function BeginBreak(eventGUID)
  if motionState ~= MOTION_GROW or not CastGUIDMatches(eventGUID) or not crosshairVisualFrame then
    return false
  end
  if crosshairTexture and crosshairTexture.GetVertexColor then
    local r, g, b, a = crosshairTexture:GetVertexColor()
    breakSavedVertexColor = { r, g, b, a }
  end
  motionStartScale = crosshairVisualFrame:GetScale() or CAST_BASE_SCALE
  motionState = MOTION_BREAK
  motionElapsed = 0
  castGUID = nil
  return true
end

function CM.StartCrosshairCastExplode(eventGUID)
  BeginExplode(eventGUID)
end

function CM.StartCrosshairCastBreak(eventGUID)
  BeginBreak(eventGUID)
end

--- Terminal cast/channel resolution from Crosshair event handler.
--- reason: "succeeded" | "stopped" | "failed" | "channel_stop"
function CM.NotifyCrosshairCastTerminal(eventGUID, reason)
  if reason == "failed" then
    castInterrupted = true
    BeginBreak(eventGUID)
    return
  end
  if reason == "succeeded" then
    if castIsChannel then
      return -- channel ticks also fire SUCCEEDED
    end
    BeginExplode(eventGUID)
    return
  end
  if reason == "stopped" then
    if castProgress >= CAST_SUCCESS_PROGRESS then
      BeginExplode(eventGUID)
    else
      BeginBreak(eventGUID)
    end
    return
  end
  if reason == "channel_stop" then
    if castInterrupted or castProgress < CAST_SUCCESS_PROGRESS then
      BeginBreak(eventGUID)
    else
      BeginExplode(eventGUID)
    end
    castInterrupted = false
  end
end
