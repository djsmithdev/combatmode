---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Feedback.lua — CROSSHAIR — press/pulse + façade
---------------------------------------------------------------------------------------
--  What it does: Owns correct-cast press + outward pulse, recent-suggestion cache, and
--  a façade over CastProgress for swipe/break (CreateTextures / Tick / StopAll /
--  LayoutCastProgressSwipe / UpdateCastProgressSwipe / IsBreakActive).
--  Architecture / how it works:
--    • Attach binds host chrome + Motion fade bridges, then CastProgress.Attach
--      (same host + stopPress/stopPulse).
--    • CreateTextures = CastProgress swipe + successPulse.
--    • Tick = CastProgress.TickBreak when break active, else press/pulse.
--    • CM.OnAssistedHighlightSpellCast / OnAssistedHighlightAssistedActionCast.
--  Does not: Own chrome, ProcLoop/glow/fade, or swipe/break internals (siblings).
--  Related: Core/Crosshair/AssistedHighlight/CastProgress.lua,
--  Core/Crosshair/AssistedHighlight/Assist.lua, Core/Crosshair/AssistedHighlight/Motion.lua,
--  Core/Runtime/EventRouter.lua, Constants/Gameplay.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetTime = _G.GetTime
local C_Spell = _G.C_Spell

-- Lua stdlib
local pcall = _G.pcall
local table = _G.table
local tonumber = _G.tonumber
local sin = _G.math.sin
local pi = _G.math.pi

local CastProgress = CM.AssistedHighlightCastProgress

local Feedback = {}
CM.AssistedHighlightFeedback = Feedback

-- Bound by Attach (host chrome + main-owned fade/spell state).
local getFrame
local getVisual
local getAnimDriver
local getFadeMode
local getLastShownSpellID
local previewSpellID = -1

-- Correct-cast press (shrink → ease back) + outward pulse
local PRESS_DURATION = 0.14
local PRESS_MIN_SCALE = 0.86
local ASSIST_PULSE_ATLAS = "dragonflight-landingbutton-circleglow" -- same as cursor pulse
local ASSIST_PULSE_DURATION = 0.4
local ASSIST_PULSE_START_ALPHA = 0.55
local ASSIST_PULSE_START_SIZE = 28
local ASSIST_PULSE_END_SIZE = 64
local SUCCESS_FEEDBACK_COALESCE_SEC = ASSIST_PULSE_DURATION
local RECENT_SHOWN_TTL = 0.9
local RECENT_SHOWN_MAX = 4

local recentShownSpells = {}
local pressActive = false
local pressElapsed = 0
local assistPulseElapsed = -1
local lastSuccessFeedbackAt = 0

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

local function FadeMode()
  return getFadeMode and getFadeMode() or "hidden"
end

local function LastShownSpellID()
  return getLastShownSpellID and getLastShownSpellID() or nil
end

local function IsPreviewActive()
  return CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive()
end

---------------------------------------------------------------------------------------
--                      SUGGESTION MATCHING (RECENT SPELL CACHE)                     --
---------------------------------------------------------------------------------------
local function NormalizeSpellID(spellID)
  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 then
    return nil
  end
  if C_Spell and C_Spell.GetBaseSpell then
    local ok, base = pcall(C_Spell.GetBaseSpell, spellID)
    base = ok and tonumber(base) or nil
    if base and base > 0 then
      return base
    end
  end
  return spellID
end

local function PruneRecentShownSpells(now)
  now = now or GetTime()
  local write = 1
  for i = 1, #recentShownSpells do
    local entry = recentShownSpells[i]
    if entry and entry.expires > now then
      recentShownSpells[write] = entry
      write = write + 1
    end
  end
  for i = write, #recentShownSpells do
    recentShownSpells[i] = nil
  end
end

function Feedback.RememberShownSpell(spellID)
  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 or spellID == previewSpellID then
    return
  end
  local now = GetTime()
  local base = NormalizeSpellID(spellID) or spellID
  PruneRecentShownSpells(now)
  for i = 1, #recentShownSpells do
    local entry = recentShownSpells[i]
    if entry.spellID == spellID or entry.base == base then
      entry.spellID = spellID
      entry.base = base
      entry.expires = now + RECENT_SHOWN_TTL
      return
    end
  end
  recentShownSpells[#recentShownSpells + 1] = {
    spellID = spellID,
    base = base,
    expires = now + RECENT_SHOWN_TTL,
  }
  while #recentShownSpells > RECENT_SHOWN_MAX do
    table.remove(recentShownSpells, 1)
  end
end

local function SpellMatchesRecent(castSpellID)
  castSpellID = tonumber(castSpellID)
  if not castSpellID or castSpellID <= 0 then
    return false
  end
  local castBase = NormalizeSpellID(castSpellID) or castSpellID
  local shown = LastShownSpellID()
  if shown and shown ~= previewSpellID then
    if castSpellID == shown then
      return true
    end
    local shownBase = NormalizeSpellID(shown)
    if shownBase and shownBase == castBase then
      return true
    end
  end
  PruneRecentShownSpells()
  for i = 1, #recentShownSpells do
    local entry = recentShownSpells[i]
    if entry.spellID == castSpellID or entry.base == castBase then
      return true
    end
  end
  return false
end

---------------------------------------------------------------------------------------
--                    CORRECT-CAST FEEDBACK — PRESS + OUTWARD PULSE                  --
---------------------------------------------------------------------------------------
local function StopAssistPulse()
  assistPulseElapsed = -1
  local frame = HostFrame()
  if frame and frame.successPulse then
    frame.successPulse:Hide()
  end
end

local function StopAssistPress()
  pressActive = false
  pressElapsed = 0
  local visual = HostVisual()
  if
    visual and not (CastProgress and CastProgress.IsBreakActive and CastProgress.IsBreakActive())
  then
    visual:SetScale(1)
  end
end

local function BeginAssistPulse()
  local frame = HostFrame()
  if not (frame and frame.successPulse) then
    return
  end
  local pulse = frame.successPulse
  pulse:ClearAllPoints()
  pulse:SetPoint("CENTER", frame.icon or frame, "CENTER", 0, 0)
  pulse:SetAtlas(ASSIST_PULSE_ATLAS, true)
  pulse:SetSize(ASSIST_PULSE_START_SIZE, ASSIST_PULSE_START_SIZE)
  pulse:SetAlpha(ASSIST_PULSE_START_ALPHA)
  pulse:Show()
  assistPulseElapsed = 0
  local driver = HostAnimDriver()
  if driver then
    driver:Show()
  end
end

local function UpdateAssistPulse(elapsed)
  if assistPulseElapsed < 0 then
    return
  end
  local frame = HostFrame()
  local pulse = frame and frame.successPulse
  if not pulse then
    assistPulseElapsed = -1
    return
  end
  assistPulseElapsed = assistPulseElapsed + elapsed
  if assistPulseElapsed >= ASSIST_PULSE_DURATION then
    StopAssistPulse()
    return
  end
  local progress = assistPulseElapsed / ASSIST_PULSE_DURATION
  local eased = 1 - (1 - progress) * (1 - progress)
  local size = ASSIST_PULSE_START_SIZE + (ASSIST_PULSE_END_SIZE - ASSIST_PULSE_START_SIZE) * eased
  local alpha = ASSIST_PULSE_START_ALPHA * (1 - progress * progress)
  pulse:SetSize(size, size)
  pulse:SetAlpha(alpha)
end

local function BeginAssistPress()
  local visual = HostVisual()
  if not visual then
    return
  end
  pressActive = true
  pressElapsed = 0
  visual:SetScale(1)
  local driver = HostAnimDriver()
  if driver then
    driver:Show()
  end
end

local function UpdateAssistPress(elapsed)
  local visual = HostVisual()
  if not pressActive or not visual then
    return
  end
  pressElapsed = pressElapsed + elapsed
  if pressElapsed >= PRESS_DURATION then
    StopAssistPress()
    return
  end
  local progress = pressElapsed / PRESS_DURATION
  local scale
  if progress < 0.5 then
    local t = progress / 0.5
    scale = 1 + (PRESS_MIN_SCALE - 1) * t
  else
    local t = (progress - 0.5) / 0.5
    scale = PRESS_MIN_SCALE + (1 - PRESS_MIN_SCALE) * EaseOutSine(t)
  end
  visual:SetScale(scale)
end

--- Press + outward pulse when the suggested spell is cast.
local function BeginCorrectCastFeedback()
  if CastProgress and CastProgress.IsBreakActive and CastProgress.IsBreakActive() then
    return
  end
  local mode = FadeMode()
  if mode == "hidden" or mode == "out" then
    return
  end
  -- Coalesce Single-Button dual events / spam while press/pulse is active.
  if pressActive or assistPulseElapsed >= 0 then
    return
  end
  local now = GetTime()
  if (now - lastSuccessFeedbackAt) < SUCCESS_FEEDBACK_COALESCE_SEC then
    return
  end
  lastSuccessFeedbackAt = now
  BeginAssistPress()
  BeginAssistPulse()
end

---------------------------------------------------------------------------------------
--                         ATTACH / CREATE / PUBLIC HELPERS                          --
---------------------------------------------------------------------------------------
function Feedback.Attach(opts)
  opts = opts or {}
  getFrame = opts.getFrame
  getVisual = opts.getVisual
  getAnimDriver = opts.getAnimDriver
  getFadeMode = opts.getFadeMode
  getLastShownSpellID = opts.getLastShownSpellID
  previewSpellID = opts.previewSpellID or -1

  if CastProgress and CastProgress.Attach then
    CastProgress.Attach({
      getFrame = opts.getFrame,
      getVisual = opts.getVisual,
      getAnimDriver = opts.getAnimDriver,
      getFadeMode = opts.getFadeMode,
      setFadeMode = opts.setFadeMode,
      getLastShownSpellID = opts.getLastShownSpellID,
      previewSpellID = previewSpellID,
      stopProcEffect = opts.stopProcEffect,
      stopPress = StopAssistPress,
      stopPulse = StopAssistPulse,
    })
  end
end

--- Creates Cooldown swipe + successPulse on an already-built assist frame/visual.
function Feedback.CreateTextures(frame, visual, assets)
  if not (frame and visual) then
    return
  end
  if CastProgress and CastProgress.CreateSwipeTexture then
    CastProgress.CreateSwipeTexture(frame, visual, assets)
  end

  if not frame.successPulse then
    frame.successPulse = frame:CreateTexture(nil, "BACKGROUND")
    frame.successPulse:SetDrawLayer("BACKGROUND", -2)
    frame.successPulse:SetBlendMode("ADD")
    frame.successPulse:SetAtlas(ASSIST_PULSE_ATLAS, true)
    frame.successPulse:SetPoint("CENTER", frame.icon or frame, "CENTER", 0, 0)
    frame.successPulse:Hide()
  end
end

function Feedback.IsBreakActive()
  return CastProgress and CastProgress.IsBreakActive and CastProgress.IsBreakActive() or false
end

function Feedback.LayoutCastProgressSwipe(icon, expand)
  if CastProgress and CastProgress.LayoutCastProgressSwipe then
    CastProgress.LayoutCastProgressSwipe(icon, expand)
  end
end

function Feedback.UpdateCastProgressSwipe()
  if CastProgress and CastProgress.UpdateCastProgressSwipe then
    return CastProgress.UpdateCastProgressSwipe()
  end
  return false
end

--- Stop press/pulse/swipe/break + reset cast tracking (FinishHide path).
function Feedback.StopAll()
  if CastProgress and CastProgress.StopAll then
    CastProgress.StopAll()
  end
  StopAssistPress()
  StopAssistPulse()
end

--- AnimDriver tick. Returns true when break owns the frame (skip fade/glow).
function Feedback.Tick(elapsed)
  if CastProgress and CastProgress.IsBreakActive and CastProgress.IsBreakActive() then
    CastProgress.TickBreak(elapsed)
    return true
  end
  UpdateAssistPress(elapsed)
  UpdateAssistPulse(elapsed)
  return false
end

---------------------------------------------------------------------------------------
--                         EVENT HANDLERS (EventRouter)                              --
---------------------------------------------------------------------------------------
local function IsAssistVisibleForCastFeedback()
  if CastProgress and CastProgress.IsAssistVisibleForCastFeedback then
    return CastProgress.IsAssistVisibleForCastFeedback()
  end
  return false
end

--- Correct-cast press/pulse on recent-suggestion match, then refresh icon.
function CM.OnAssistedHighlightSpellCast(spellID)
  if IsPreviewActive() then
    return
  end
  if not IsAssistVisibleForCastFeedback() then
    return
  end
  if SpellMatchesRecent(spellID) then
    BeginCorrectCastFeedback()
  end
  if CM.UpdateCrosshairAssistedHighlight then
    CM.UpdateCrosshairAssistedHighlight()
  end
end

--- Single-Button Assistant always casts the suggestion — press/pulse + refresh.
function CM.OnAssistedHighlightAssistedActionCast()
  if IsPreviewActive() then
    return
  end
  if not IsAssistVisibleForCastFeedback() then
    return
  end
  BeginCorrectCastFeedback()
  if CM.UpdateCrosshairAssistedHighlight then
    CM.UpdateCrosshairAssistedHighlight()
  end
end
