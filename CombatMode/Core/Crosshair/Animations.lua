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
--    • Cast GUID match is secret-safe (issecretvalue): cannot == under instance taint.
--    • ApplyCrosshairAppearanceToWidget uses CM.GetCrosshairReactionColor; scale tween on
--      base ↔ active; active ↔ active lerps RGBA over REACTION_COLOR_DURATION. Cast-break
--      hostile flash resolves at flash time. Situational condition swaps to
--      crosshairSituationalAppearance (default Arrows) while keeping reaction colors/scale.
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
local UIParent = _G.UIParent
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
local issecretvalue = _G.issecretvalue

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
  CM.Profile("Anim:PulseFrame", function()
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
  end)
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
local REACTION_COLOR_DURATION = 0.12

local lastReactionAppearanceState = nil
local reactionAnimToken = 0
local reactionColorToken = 0
local reactionColorCurrent = nil
local reactionColorTween = nil

local function Lerp(a, b, t)
  return a + (b - a) * t
end

local function Clamp01(value)
  return math.max(0, math.min(1, value))
end

local function EaseOutQuad(progress)
  local inv = 1 - progress
  return 1 - inv * inv
end

local function IsActiveReactionState(state)
  return state ~= nil and state ~= "base" and state ~= "mounted"
end

local function CancelReactionColorTween()
  reactionColorTween = nil
end

function CM.CancelCrosshairReactionColorTween()
  CancelReactionColorTween()
end

local function SetReactionVertexColor(texture, r, g, b, a)
  if not texture then
    return
  end
  texture:SetVertexColor(r, g, b, a)
  reactionColorCurrent = { r, g, b, a }
end

local function StartReactionColorTween(texture, toR, toG, toB, toA)
  if not texture then
    return
  end

  local from = reactionColorCurrent
  if not from and texture.GetVertexColor then
    local r, g, b, a = texture:GetVertexColor()
    from = { r, g, b, a or 1 }
  end
  from = from or { toR, toG, toB, toA }

  if
    math.abs(from[1] - toR) < 0.001
    and math.abs(from[2] - toG) < 0.001
    and math.abs(from[3] - toB) < 0.001
    and math.abs((from[4] or 1) - toA) < 0.001
  then
    SetReactionVertexColor(texture, toR, toG, toB, toA)
    return
  end

  reactionColorToken = reactionColorToken + 1
  reactionColorTween = {
    texture = texture,
    from = { from[1], from[2], from[3], from[4] or 1 },
    to = { toR, toG, toB, toA },
    elapsed = 0,
    token = reactionColorToken,
  }
end

local function UpdateReactionColorTween(elapsed)
  local tween = reactionColorTween
  if not tween then
    return
  end

  tween.elapsed = tween.elapsed + elapsed
  local t = Clamp01(tween.elapsed / REACTION_COLOR_DURATION)
  t = EaseOutQuad(t)

  local f = tween.from
  local to = tween.to
  local r = Lerp(f[1], to[1], t)
  local g = Lerp(f[2], to[2], t)
  local b = Lerp(f[3], to[3], t)
  local a = Lerp(f[4], to[4], t)

  tween.texture:SetVertexColor(r, g, b, a)
  reactionColorCurrent = { r, g, b, a }

  if t >= 1 then
    reactionColorTween = nil
    reactionColorCurrent = { to[1], to[2], to[3], to[4] }
  end
end

local function ApplyReactionScale(targetFrame, parent, state, verticalOffset)
  if state == "base" then
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
  else
    targetFrame:SetScale(ENDING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset / ENDING_SCALE)
  end
end

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

  local appearance = CrosshairAppearance
  if CM.IsCrosshairSituationalActive and CM.IsCrosshairSituationalActive() then
    local situational = CM.DB.global.crosshairSituationalAppearance
    if type(situational) ~= "table" or not situational.Base then
      local name = (type(situational) == "table" and situational.Name)
        or (type(situational) == "string" and situational)
        or "Arrows"
      situational = CM.Constants.CrosshairTextureObj and CM.Constants.CrosshairTextureObj[name]
    end
    if not situational then
      situational = CM.Constants.CrosshairTextureObj and CM.Constants.CrosshairTextureObj.Arrows
    end
    if situational then
      appearance = situational
    end
  end

  local parent = targetFrame:GetParent()

  -- Target Lock idle Dot: Crosshair.lua owns texture/tint; skip all reaction changes.
  if CM.IsFocusLockReticleSuppressed and CM.IsFocusLockReticleSuppressed() then
    if animGroup and animGroup.Stop then
      animGroup:Stop()
    end
    CancelReactionColorTween()
    lastReactionAppearanceState = nil
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
    return
  end

  local color = CM.GetCrosshairReactionColor(state)
  local targetR, targetG, targetB, targetA = color[1], color[2], color[3], color[4]
  local textureToUse = state == "base" and appearance.Base or appearance.Active
  local reverseAnimation = state == "base" and true or false

  targetTexture:SetTexture(textureToUse)
  if previewMode or (state ~= "mounted" and CM.IsMouselooking()) then
    targetTexture:Show()
  end

  -- Cast feedback owns visual scale/offset; skip reaction Scale anim while active.
  if CM.IsCrosshairCastFeedbackActive and CM.IsCrosshairCastFeedbackActive() then
    CancelReactionColorTween()
    SetReactionVertexColor(targetTexture, targetR, targetG, targetB, targetA)
    lastReactionAppearanceState = state
    return
  end

  local prevState = lastReactionAppearanceState
  local activeToActive = IsActiveReactionState(state) and IsActiveReactionState(prevState)
  lastReactionAppearanceState = state

  if activeToActive then
    StartReactionColorTween(targetTexture, targetR, targetG, targetB, targetA)
  else
    CancelReactionColorTween()
    SetReactionVertexColor(targetTexture, targetR, targetG, targetB, targetA)
  end

  local playScaleAnim = not activeToActive
  reactionAnimToken = reactionAnimToken + 1
  local token = reactionAnimToken

  if not playScaleAnim then
    if animGroup and animGroup.Stop then
      animGroup:Stop()
    end
    ApplyReactionScale(targetFrame, parent, state, verticalOffset)
    return
  end

  if animGroup and animGroup.Stop then
    animGroup:Stop()
  end

  animGroup:SetScript("OnFinished", function()
    if token ~= reactionAnimToken then
      return
    end
    if state ~= "base" then
      ApplyReactionScale(targetFrame, parent, state, verticalOffset)
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
local CAST_BASE_SCALE = 1.0
local CAST_SUCCESS_PROGRESS = 0.85 -- STOP / CHANNEL_STOP treated as success at/above this

local CastBreak = CM.Constants.CrosshairCastBreak
local CAST_BREAK_DURATION = CastBreak.duration
local CAST_BREAK_SHAKE_PX = CastBreak.shakePx
local CAST_BREAK_FLASH_HZ = CastBreak.flashHz
local CAST_BREAK_COLOR_GREY = CastBreak.grey

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
  reactionColorCurrent = { c[1], c[2], c[3], c[4] }
  breakSavedVertexColor = nil
end

local function ResetVisualToBase()
  if not crosshairVisualFrame then
    return
  end
  crosshairVisualFrame:SetScale(CAST_BASE_SCALE)
  crosshairVisualFrame:SetAlpha(1)
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
  -- Nil on either side = no filter. Secret GUIDs cannot be compared under taint
  -- (instances); accept so grow/explode/break are not left stuck.
  if not eventGUID or not castGUID then
    return true
  end
  if issecretvalue and (issecretvalue(eventGUID) or issecretvalue(castGUID)) then
    return true
  end
  return eventGUID == castGUID
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
  CancelReactionColorTween()
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
  local opacity = 1
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
  local alpha = flicker * (0.65 + 0.35 * progress)
  if crosshairTexture then
    local hostile = CM.GetCrosshairReactionColor("hostile")
    local c = ((math.floor(motionElapsed * CAST_BREAK_FLASH_HZ) % 2) == 0) and hostile
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
  CM.Profile("Anim:CrosshairMotion", function()
    UpdateReactionColorTween(elapsed)
    local updater = motionUpdaters[motionState]
    if updater then
      updater(elapsed)
    end
  end)
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
  CancelReactionColorTween()
  crosshairTexture:Show()

  lockInStartScale = crosshairVisualFrame:GetScale() * 1.3
  lockInStartAlpha = 0.0
  lockInTargetScale = CAST_BASE_SCALE
  lockInTargetAlpha = 1

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
  CancelReactionColorTween()
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
  crosshairVisualFrame:SetAlpha(1)
end

local function BeginExplode(eventGUID)
  if motionState ~= MOTION_GROW or not CastGUIDMatches(eventGUID) or not crosshairVisualFrame then
    return false
  end
  motionStartScale = crosshairVisualFrame:GetScale() or CAST_GROW_MAX_SCALE
  motionStartAlpha = crosshairVisualFrame:GetAlpha() or 1
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
  CancelReactionColorTween()
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
