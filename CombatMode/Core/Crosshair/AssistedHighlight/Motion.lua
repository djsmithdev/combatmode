---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Motion.lua — CROSSHAIR — ProcLoop / glow / fade
---------------------------------------------------------------------------------------
--  What it does: Owns Assisted Combat motion: ProcLoop FlipBook on suggestion change,
--  cyan glow breath, show/hide fade, and RequestShow / RequestHide / FinishHide visuals.
--  Architecture / how it works:
--    • CM.AssistedHighlightMotion.Attach({ getFrame, getVisual, getAnimDriver,
--      clearLastShownSpellID, isBreakActive, stopAllFeedback }) binds host chrome.
--    • fadeMode ("hidden"|"in"|"shown"|"out") owned here; GetFadeMode / SetFadeMode.
--    • Tick(elapsed) runs UpdateFade + UpdateGlowBreath (Assist AnimDriver after Feedback).
--    • ProcLoop: UF-RogueCP-Slash-Blue, 3x6=18 frames, 0.57s reverse once per spell change.
--  Does not: Own IconMask chrome creation, keybinds, cast swipe/press/break (siblings).
--  Related: Core/Crosshair/AssistedHighlight/Assist.lua,
--  Core/Crosshair/AssistedHighlight/Feedback.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local math = _G.math
local cos = _G.math.cos
local sin = _G.math.sin
local pi = _G.math.pi

local Motion = {}
CM.AssistedHighlightMotion = Motion

-- Bound by Attach
local getFrame
local getVisual
local getAnimDriver
local clearLastShownSpellID
local isBreakActive
local stopAllFeedback

-- Glow breath
local GLOW_ANIM_MIN_ALPHA = 0.45
local GLOW_ANIM_MAX_ALPHA = 1
local GLOW_CYCLE_DURATION = 2.6
local GLOW_STRENGTH = 0.85

-- Rogue combo-point slash FlipBook (Interface/HUD/UIRogueCombPoints).
-- Full sheet: 3x6 = 18 frames. Plays once in reverse when the suggested spell changes.
local PROC_ATLAS = "UF-RogueCP-Slash-Blue"
local PROC_FLIP_ROWS = 3
local PROC_FLIP_COLUMNS = 6
local PROC_FLIP_FRAMES = 18
-- Match Blizzard RogueComboPointBar SlashFB FlipBook duration (.57).
local PROC_PLAY_DURATION = 0.57

Motion.GLOW_COLOR_R = 0.44
Motion.GLOW_COLOR_G = 0.98
Motion.GLOW_COLOR_B = 1
Motion.GLOW_ANIM_MIN_ALPHA = GLOW_ANIM_MIN_ALPHA
Motion.PROC_ATLAS = PROC_ATLAS
Motion.PROC_PREVIEW_SPELL_ID = -1

-- Show/hide fade
local FADE_IN_DURATION = 0.22
local FADE_OUT_DURATION = 0.36

local glowPhase = 0
local fadeMode = "hidden" -- "hidden" | "in" | "shown" | "out"
local fadeElapsed = 0
local fadeFromAlpha = 0
local lastProcSpellID

local function EaseOutSine(t)
  return sin((t * pi) * 0.5)
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

local function IsBreakActive()
  return isBreakActive and isBreakActive() or false
end

---------------------------------------------------------------------------------------
--                            PROC FLIPBOOK / GLOW / FADE                            --
---------------------------------------------------------------------------------------
local function ApplyProcFlipSettings(flipAnim)
  if not flipAnim then
    return
  end
  flipAnim:SetDuration(PROC_PLAY_DURATION)
  flipAnim:SetFlipBookRows(PROC_FLIP_ROWS)
  flipAnim:SetFlipBookColumns(PROC_FLIP_COLUMNS)
  flipAnim:SetFlipBookFrames(PROC_FLIP_FRAMES)
  flipAnim:SetFlipBookFrameWidth(0)
  flipAnim:SetFlipBookFrameHeight(0)
end

function Motion.EnsureProcAnimations()
  local visual = HostVisual()
  if not visual or not visual.ProcLoop then
    return
  end
  if visual.ProcLoopAnim then
    ApplyProcFlipSettings(visual.ProcLoopFlip)
    return
  end

  local animGroup = visual:CreateAnimationGroup()
  animGroup:SetLooping("NONE")
  animGroup:SetToFinalAlpha(true)

  local alphaHold = animGroup:CreateAnimation("Alpha")
  alphaHold:SetChildKey("ProcLoop")
  alphaHold:SetFromAlpha(1)
  alphaHold:SetToAlpha(1)
  alphaHold:SetDuration(0.001)
  alphaHold:SetOrder(0)

  local flipAnim = animGroup:CreateAnimation("FlipBook")
  flipAnim:SetChildKey("ProcLoop")
  flipAnim:SetOrder(0)
  ApplyProcFlipSettings(flipAnim)

  animGroup:SetScript("OnFinished", function()
    local v = HostVisual()
    if v and v.ProcLoop then
      v.ProcLoop:Hide()
    end
  end)

  visual.ProcLoopAnim = animGroup
  visual.ProcLoopFlip = flipAnim
end

--- Plays the proc FlipBook once in reverse when `spellID` changes.
function Motion.PlayProcEffectForSpell(spellID)
  local visual = HostVisual()
  if not (visual and visual.ProcLoop) then
    return
  end
  if not spellID or spellID == lastProcSpellID then
    return
  end
  lastProcSpellID = spellID

  Motion.EnsureProcAnimations()
  local anim = visual.ProcLoopAnim
  ApplyProcFlipSettings(visual.ProcLoopFlip)
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  visual.ProcLoop:SetAtlas(PROC_ATLAS)
  visual.ProcLoop:SetAlpha(1)
  visual.ProcLoop:Show()
  if anim then
    anim:Play(true)
  end
end

function Motion.StopProcEffect()
  lastProcSpellID = nil
  local visual = HostVisual()
  if not visual then
    return
  end
  local anim = visual.ProcLoopAnim
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  if visual.ProcLoop then
    visual.ProcLoop:Hide()
  end
end

function Motion.LayoutProcEffect(icon, expand)
  local visual = HostVisual()
  if not (visual and visual.ProcLoop and icon) then
    return
  end
  LayoutShellAroundIcon(visual.ProcLoop, icon, expand)
  visual.ProcLoop:SetAtlas(PROC_ATLAS)
end

local function UpdateGlowBreath(elapsed)
  local frame = HostFrame()
  local glow = frame and frame.glow
  if not glow or not glow:IsShown() then
    return
  end
  local duration = GLOW_CYCLE_DURATION
  glowPhase = glowPhase + (elapsed / duration)
  if glowPhase >= 1 then
    glowPhase = glowPhase - math.floor(glowPhase)
  end
  local wave = 0.5 - 0.5 * cos(glowPhase * pi * 2)
  local waveWithStrength = ((1 - GLOW_STRENGTH) * 0.5) + (GLOW_STRENGTH * wave)
  local range = GLOW_ANIM_MAX_ALPHA - GLOW_ANIM_MIN_ALPHA
  glow:SetAlpha(GLOW_ANIM_MIN_ALPHA + (range * waveWithStrength))
end

function Motion.GetFadeMode()
  return fadeMode
end

function Motion.SetFadeMode(mode)
  fadeMode = mode
  if mode == "shown" then
    fadeElapsed = 0
  end
end

function Motion.FinishHide()
  if clearLastShownSpellID then
    clearLastShownSpellID()
  end
  fadeMode = "hidden"
  fadeElapsed = 0
  Motion.StopProcEffect()
  if stopAllFeedback then
    stopAllFeedback()
  end
  ResetVisualTransform()
  CenterAssistVisual()
  local visual = HostVisual()
  if visual then
    visual:Hide()
  end
  local frame = HostFrame()
  if frame then
    frame:Hide()
  end
  local driver = HostAnimDriver()
  if driver then
    driver:Hide()
  end
end

function Motion.RequestShow()
  local frame = HostFrame()
  if not frame then
    return
  end
  if IsBreakActive() then
    return
  end
  ResetVisualTransform()
  CenterAssistVisual()
  frame:Show()
  local visual = HostVisual()
  if visual then
    visual:Show()
  end
  local driver = HostAnimDriver()
  if driver then
    driver:Show()
  end
  if fadeMode == "shown" or fadeMode == "in" then
    return
  end
  fadeFromAlpha = (visual and visual:GetAlpha()) or 0
  if fadeMode == "hidden" then
    fadeFromAlpha = 0
    SetVisualAlpha(0)
  end
  fadeMode = "in"
  fadeElapsed = 0
end

function Motion.RequestHide()
  if IsBreakActive() then
    return
  end
  local frame = HostFrame()
  if not frame or fadeMode == "hidden" then
    return
  end
  if fadeMode == "out" then
    return
  end
  local visual = HostVisual()
  fadeFromAlpha = (visual and visual:GetAlpha()) or 1
  fadeMode = "out"
  fadeElapsed = 0
end

local function UpdateFade(elapsed)
  if fadeMode == "in" then
    fadeElapsed = fadeElapsed + elapsed
    local t = math.min(1, fadeElapsed / FADE_IN_DURATION)
    local eased = EaseOutSine(t)
    SetVisualAlpha(fadeFromAlpha + (1 - fadeFromAlpha) * eased)
    if t >= 1 then
      fadeMode = "shown"
      SetVisualAlpha(1)
    end
  elseif fadeMode == "out" then
    fadeElapsed = fadeElapsed + elapsed
    local t = math.min(1, fadeElapsed / FADE_OUT_DURATION)
    local eased = EaseOutSine(t)
    SetVisualAlpha(fadeFromAlpha * (1 - eased))
    if t >= 1 then
      Motion.FinishHide()
    end
  end
end

--- AnimDriver tick for fade + glow (called when Feedback.Tick returns false).
function Motion.Tick(elapsed)
  if fadeMode == "hidden" then
    return
  end
  UpdateFade(elapsed)
  if fadeMode ~= "hidden" then
    UpdateGlowBreath(elapsed)
  end
end

function Motion.Attach(opts)
  opts = opts or {}
  getFrame = opts.getFrame
  getVisual = opts.getVisual
  getAnimDriver = opts.getAnimDriver
  clearLastShownSpellID = opts.clearLastShownSpellID
  isBreakActive = opts.isBreakActive
  stopAllFeedback = opts.stopAllFeedback
end
