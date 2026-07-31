---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight.lua — CROSSHAIR — Assisted Combat icon + keybind
---------------------------------------------------------------------------------------
--  What it does: Renders Blizzard Assisted Combat's next-cast suggestion beside the
--  crosshair: Left/Right via assistedHighlightSide (default RIGHT), fixed icon size 40,
--  click-cast or keyboard keybind glyphs, and its own cast motion (FlipBook / explode /
--  break) — not Animations.lua. Visible in combat when enabled; options preview shows a
--  placeholder out of combat.
--  Architecture / how it works:
--    • IconMask chrome shell: Radial_Wheel_BG shadow → spell_icon background →
--      circular-masked spell art → cyan breath glow → dark frame; ProcLoop FlipBook
--      (UF-RogueCP-Slash-Blue, 18 frames) plays once in reverse when the suggestion
--      spell changes. Cast-success BurstFX FlipBook (dragonriding_sgvigor_burst_flipbook,
--      4x4 / 16 frames) plays near native speed and lingers slightly past the icon explode.
--    • Click-cast keybinds: modifier BLPs + mouse-button atlases
--      (newplayertutorial-icon-mouse-leftbutton / -rightbutton) via |T|/|A| markup on the
--      outer side of the icon. Keyboard binds: abbreviated FrizQT OUTLINE, top-right
--      offset on the icon. Style chosen from resolved binding for the suggested action.
--    • Recent-suggestion cache (TTL ~0.9s, max 4): GetNextCastSpell often advances before
--      UNIT_SPELLCAST_SUCCEEDED — cache keeps explode/break matching correct.
--    • APIs: InitAssistedHighlight({crosshairFrame, crosshairTexture}),
--      ApplyCrosshairAssistedHighlightOptions, UpdateCrosshairAssistedHighlight,
--      InvalidateAssistedHighlightKeybindCache, OnAssistedHighlightSpellCast,
--      OnAssistedHighlightAssistedActionCast (EventRouter).
--    • Preview: IsCrosshairPreviewActive forces placeholder icon + keybind layout.
--  Does not: Own reticle cast grow/explode/break (Animations) or SoftTarget CVars.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/EventRouter.lua, Constants/Assets.lua, Constants/Gameplay.lua,
--  UI/Options/Tabs/TabCrosshair.lua, Constants/DatabaseDefaults.lua,
--  Core/ClickCasting/BindingOverrides.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsMouselooking = _G.IsMouselooking
local UnitAffectingCombat = _G.UnitAffectingCombat

local C_AssistedCombat = _G.C_AssistedCombat
local C_ActionBar = _G.C_ActionBar
local C_Spell = _G.C_Spell

-- Lua stdlib
local math = _G.math
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local tonumber = _G.tonumber
local type = _G.type
local cos = _G.math.cos
local sin = _G.math.sin
local pi = _G.math.pi
local random = _G.math.random

local crosshairFrame
local crosshairTexture

local AssistedHighlightFrame
local AssistedHighlightVisual
local AssistedHighlightAnimDriver

-- Shell layout (IconMask)
local ICON_MASK_BASE_SIZE = 32
local ICON_MASK_BASE_EXPAND = 6
local SHADOW_SCALE = 1.3
local ICON_SIZE = 40
local ASSIST_OFFSET_X = 24 -- px beyond crosshair edge (matches Interaction HUD gap)

-- Keyboard keybind (Assisted Highlight defaults)
local KEYBOARD_KEYBIND_FONT = "Fonts\\FRIZQT__.TTF"
local KEYBOARD_KEYBIND_FONT_SIZE = 15
local KEYBOARD_KEYBIND_FONT_FLAGS = "OUTLINE"
local KEYBOARD_KEYBIND_OFFSET_X = 10
local KEYBOARD_KEYBIND_OFFSET_Y = 12

-- Glow breath (Assisted Highlight defaults)
local GLOW_ANIM_MIN_ALPHA = 0.45
local GLOW_ANIM_MAX_ALPHA = 1
local GLOW_CYCLE_DURATION = 2.6
local GLOW_STRENGTH = 0.85
local GLOW_COLOR_R, GLOW_COLOR_G, GLOW_COLOR_B = 0.44, 0.98, 1

-- Rogue combo-point slash FlipBook (Interface/HUD/UIRogueCombPoints).
-- Full sheet: 3x6 = 18 frames. Plays once in reverse when the suggested spell changes.
local PROC_ATLAS = "UF-RogueCP-Slash-Blue"
local PROC_FLIP_ROWS = 3
local PROC_FLIP_COLUMNS = 6
local PROC_FLIP_FRAMES = 18
-- Match Blizzard RogueComboPointBar SlashFB FlipBook duration (.57).
local PROC_PLAY_DURATION = 0.57
local PROC_PREVIEW_SPELL_ID = -1

-- Dragonriding vigor burst FlipBook (Interface/Widgets/DragonridingSGVigorWidget2x).
-- Full sheet: 4x4 = 16 frames. Near-native speed; lingers slightly past the icon explode.
local BURST_ATLAS = "dragonriding_sgvigor_burst_flipbook"
local BURST_FLIP_ROWS = 4
local BURST_FLIP_COLUMNS = 4
local BURST_FLIP_FRAMES = 16
-- Native vigor burst pace (~0.5s); longer than CAST_EXPLODE_DURATION so it lingers.
local BURST_PLAY_DURATION = 0.5
-- Burst is larger than the spell icon so the VFX reads clearly.
local BURST_SIZE_MULT = 2.25

-- Show/hide fade (Transition-style)
local FADE_IN_DURATION = 0.22
local FADE_OUT_DURATION = 0.36

-- Cast-success explode (icon shell); burst FlipBook uses BURST_PLAY_DURATION.
local CAST_EXPLODE_DURATION = 0.36
local CAST_EXPLODE_EXTRA_SCALE = 0.22
-- Wrong-suggestion cast break (mirrors Crosshair Animations cast break)
local CAST_BREAK_DURATION = 0.18
local CAST_BREAK_SHAKE_PX = 5
local CAST_BREAK_FLASH_HZ = 22
local CAST_BREAK_COLOR_RED = { 1, 0.2, 0.3, 1 }
local CAST_BREAK_COLOR_GREY = { 0.72, 0.72, 0.72, 1 }
-- Keep recently shown suggestions matchable: Assisted Combat often advances
-- GetNextCastSpell before UNIT_SPELLCAST_SUCCEEDED arrives.
local RECENT_SHOWN_TTL = 0.9
local RECENT_SHOWN_MAX = 4

local glowPhase = 0
local fadeMode = "hidden" -- "hidden" | "in" | "shown" | "out"
local fadeElapsed = 0
local fadeFromAlpha = 0
local glowColorAlpha = 1
local lastAppliedSide
local lastProcSpellID
local lastShownSpellID
local recentShownSpells = {}
local explodeActive = false
local explodeElapsed = 0
local explodeStartScale = 1
local explodeStartAlpha = 1
local breakActive = false
local breakElapsed = 0
local breakSavedIconColor
local breakSavedGlowColor
local breakSavedFrameColor

-- Caches
local assistedActionSlotSet
local actionSlotCommandMap

-- Forward declare: assigned below (FinishHide).
local FinishHide

---------------------------------------------------------------------------------------
--                         SHARED HELPERS (EASING / TRANSFORM)                       --
---------------------------------------------------------------------------------------
local function EaseOutSine(t)
  return sin((t * pi) * 0.5)
end

local function EaseOutQuad(t)
  local inv = 1 - t
  return 1 - inv * inv
end

local function ResetVisualTransform()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:SetScale(1)
  end
end

local function CenterAssistVisual()
  if AssistedHighlightVisual and AssistedHighlightFrame then
    AssistedHighlightVisual:ClearAllPoints()
    AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", 0, 0)
  end
end

---------------------------------------------------------------------------------------
--                    CAST FEEDBACK — BREAK COLOR / VISIBILITY STATE                 --
---------------------------------------------------------------------------------------
local function RestoreBreakColors()
  if breakSavedIconColor and AssistedHighlightFrame and AssistedHighlightFrame.icon then
    local c = breakSavedIconColor
    AssistedHighlightFrame.icon:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedIconColor = nil
  if breakSavedGlowColor and AssistedHighlightFrame and AssistedHighlightFrame.glow then
    local c = breakSavedGlowColor
    AssistedHighlightFrame.glow:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedGlowColor = nil
  if breakSavedFrameColor and AssistedHighlightFrame and AssistedHighlightFrame.frame then
    local c = breakSavedFrameColor
    AssistedHighlightFrame.frame:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end
  breakSavedFrameColor = nil
end

local function SaveBreakColors()
  breakSavedIconColor = nil
  breakSavedGlowColor = nil
  breakSavedFrameColor = nil
  local icon = AssistedHighlightFrame and AssistedHighlightFrame.icon
  if icon and icon.GetVertexColor then
    local r, g, b, a = icon:GetVertexColor()
    breakSavedIconColor = { r, g, b, a }
  end
  local glow = AssistedHighlightFrame and AssistedHighlightFrame.glow
  if glow and glow.GetVertexColor then
    local r, g, b, a = glow:GetVertexColor()
    breakSavedGlowColor = { r, g, b, a }
  end
  local frame = AssistedHighlightFrame and AssistedHighlightFrame.frame
  if frame and frame.GetVertexColor then
    local r, g, b, a = frame:GetVertexColor()
    breakSavedFrameColor = { r, g, b, a }
  end
end

local function ApplyBreakFlashColor(color)
  if not color then
    return
  end
  if AssistedHighlightFrame and AssistedHighlightFrame.icon then
    AssistedHighlightFrame.icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
  if AssistedHighlightFrame and AssistedHighlightFrame.glow then
    AssistedHighlightFrame.glow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
  if AssistedHighlightFrame and AssistedHighlightFrame.frame then
    AssistedHighlightFrame.frame:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
end

local function CancelCastBreak()
  if not breakActive then
    return
  end
  breakActive = false
  breakElapsed = 0
  RestoreBreakColors()
  CenterAssistVisual()
  ResetVisualTransform()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:SetAlpha(1)
  end
end

local function FinishCastBreak()
  breakActive = false
  breakElapsed = 0
  RestoreBreakColors()
  CenterAssistVisual()
  ResetVisualTransform()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:SetAlpha(1)
  end
  fadeMode = "shown"
  fadeElapsed = 0
end

local function IsAssistVisibleForCastFeedback()
  if not (AssistedHighlightFrame and AssistedHighlightVisual) then
    return false
  end
  if fadeMode == "hidden" or fadeMode == "out" then
    return false
  end
  if not lastShownSpellID or lastShownSpellID == PROC_PREVIEW_SPELL_ID then
    return false
  end
  return true
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

local function RememberShownSpell(spellID)
  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 or spellID == PROC_PREVIEW_SPELL_ID then
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
  if lastShownSpellID and lastShownSpellID ~= PROC_PREVIEW_SPELL_ID then
    if castSpellID == lastShownSpellID then
      return true
    end
    local shownBase = NormalizeSpellID(lastShownSpellID)
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
--                            SHELL / TEXTURE LAYOUT HELPERS                         --
---------------------------------------------------------------------------------------
local function SetTextureSmooth(texture, texturePath)
  if not (texture and texturePath) then
    return
  end
  local ok = pcall(texture.SetTexture, texture, texturePath, nil, nil, "TRILINEAR")
  if not ok then
    texture:SetTexture(texturePath)
  end
end

local function CalculateShellExpand(iconSize)
  local expand = math.floor((iconSize / ICON_MASK_BASE_SIZE) * ICON_MASK_BASE_EXPAND + 0.5)
  if expand < 0 then
    expand = 0
  end
  return expand
end

local function LayoutShellAroundIcon(region, icon, expand)
  if not (region and icon) then
    return
  end
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", icon, "TOPLEFT", -expand, expand)
  region:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", expand, -expand)
end

---------------------------------------------------------------------------------------
--              MOTION — PROC FLIPBOOK / GLOW / FADE / EXPLODE / BREAK               --
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

local function EnsureProcAnimations()
  if not AssistedHighlightVisual or not AssistedHighlightVisual.ProcLoop then
    return
  end
  if AssistedHighlightVisual.ProcLoopAnim then
    ApplyProcFlipSettings(AssistedHighlightVisual.ProcLoopFlip)
    return
  end

  local animGroup = AssistedHighlightVisual:CreateAnimationGroup()
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
    if AssistedHighlightVisual and AssistedHighlightVisual.ProcLoop then
      AssistedHighlightVisual.ProcLoop:Hide()
    end
  end)

  AssistedHighlightVisual.ProcLoopAnim = animGroup
  AssistedHighlightVisual.ProcLoopFlip = flipAnim
end

--- Plays the proc FlipBook once in reverse when `spellID` changes.
local function PlayProcEffectForSpell(spellID)
  if not (AssistedHighlightVisual and AssistedHighlightVisual.ProcLoop) then
    return
  end
  if not spellID or spellID == lastProcSpellID then
    return
  end
  lastProcSpellID = spellID

  EnsureProcAnimations()
  local anim = AssistedHighlightVisual.ProcLoopAnim
  ApplyProcFlipSettings(AssistedHighlightVisual.ProcLoopFlip)
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  AssistedHighlightVisual.ProcLoop:SetAtlas(PROC_ATLAS)
  AssistedHighlightVisual.ProcLoop:SetAlpha(1)
  AssistedHighlightVisual.ProcLoop:Show()
  if anim then
    anim:Play(true)
  end
end

local function StopProcEffect()
  lastProcSpellID = nil
  if not AssistedHighlightVisual then
    return
  end
  local anim = AssistedHighlightVisual.ProcLoopAnim
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  if AssistedHighlightVisual.ProcLoop then
    AssistedHighlightVisual.ProcLoop:Hide()
  end
end

local function LayoutProcEffect(icon, expand)
  if not (AssistedHighlightVisual and AssistedHighlightVisual.ProcLoop and icon) then
    return
  end
  LayoutShellAroundIcon(AssistedHighlightVisual.ProcLoop, icon, expand)
  AssistedHighlightVisual.ProcLoop:SetAtlas(PROC_ATLAS)
end

local function ApplyBurstFlipSettings(flipAnim)
  if not flipAnim then
    return
  end
  flipAnim:SetDuration(BURST_PLAY_DURATION)
  flipAnim:SetFlipBookRows(BURST_FLIP_ROWS)
  flipAnim:SetFlipBookColumns(BURST_FLIP_COLUMNS)
  flipAnim:SetFlipBookFrames(BURST_FLIP_FRAMES)
  flipAnim:SetFlipBookFrameWidth(0)
  flipAnim:SetFlipBookFrameHeight(0)
end

local function EnsureBurstAnimations()
  if not (AssistedHighlightFrame and AssistedHighlightFrame.BurstFX) then
    return
  end
  if AssistedHighlightFrame.BurstAnim then
    ApplyBurstFlipSettings(AssistedHighlightFrame.BurstFlip)
    return
  end

  -- Group lives on BurstFX so FlipBook targets this texture without SetChildKey.
  local animGroup = AssistedHighlightFrame.BurstFX:CreateAnimationGroup()
  animGroup:SetLooping("NONE")
  animGroup:SetToFinalAlpha(true)

  local flipAnim = animGroup:CreateAnimation("FlipBook")
  flipAnim:SetOrder(0)
  ApplyBurstFlipSettings(flipAnim)

  animGroup:SetScript("OnFinished", function()
    if AssistedHighlightFrame and AssistedHighlightFrame.BurstFX then
      AssistedHighlightFrame.BurstFX:Hide()
    end
  end)

  AssistedHighlightFrame.BurstAnim = animGroup
  AssistedHighlightFrame.BurstFlip = flipAnim
end

local function LayoutBurstEffect(icon)
  local burst = AssistedHighlightFrame and AssistedHighlightFrame.BurstFX
  if not (burst and icon) then
    return
  end
  local iconW = icon:GetWidth() or 40
  local size = iconW * BURST_SIZE_MULT
  burst:ClearAllPoints()
  burst:SetPoint("CENTER", icon, "CENTER", 0, 0)
  burst:SetSize(size, size)
  burst:SetAtlas(BURST_ATLAS)
end

local function StopCastBurst()
  if not AssistedHighlightFrame then
    return
  end
  local anim = AssistedHighlightFrame.BurstAnim
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  if AssistedHighlightFrame.BurstFX then
    AssistedHighlightFrame.BurstFX:Hide()
  end
end

local function SetBurstAlpha(alpha)
  local burst = AssistedHighlightFrame and AssistedHighlightFrame.BurstFX
  if burst and burst:IsShown() then
    burst:SetAlpha(math.max(0, math.min(1, alpha)))
  end
end

--- Plays the vigor burst FlipBook once when the suggested spell is cast successfully.
local function PlayCastBurst()
  if not (AssistedHighlightFrame and AssistedHighlightFrame.BurstFX) then
    return
  end
  EnsureBurstAnimations()
  local icon = AssistedHighlightFrame.icon
  if icon then
    LayoutBurstEffect(icon)
  end
  local anim = AssistedHighlightFrame.BurstAnim
  ApplyBurstFlipSettings(AssistedHighlightFrame.BurstFlip)
  if anim and anim:IsPlaying() then
    anim:Stop()
  end
  AssistedHighlightFrame.BurstFX:SetAtlas(BURST_ATLAS)
  AssistedHighlightFrame.BurstFX:SetAlpha(1)
  AssistedHighlightFrame.BurstFX:Show()
  if anim then
    anim:Play()
  end
end

local function UpdateGlowBreath(elapsed)
  local glow = AssistedHighlightFrame and AssistedHighlightFrame.glow
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
  local scaled = GLOW_ANIM_MIN_ALPHA + (range * waveWithStrength)
  glow:SetAlpha(scaled * glowColorAlpha)
end

local function SetVisualAlpha(alpha)
  if AssistedHighlightVisual then
    AssistedHighlightVisual:SetAlpha(math.max(0, math.min(1, alpha)))
  end
end

FinishHide = function()
  explodeActive = false
  explodeElapsed = 0
  if breakActive then
    CancelCastBreak()
  end
  lastShownSpellID = nil
  fadeMode = "hidden"
  fadeElapsed = 0
  StopProcEffect()
  StopCastBurst()
  ResetVisualTransform()
  CenterAssistVisual()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:Hide()
  end
  if AssistedHighlightFrame then
    AssistedHighlightFrame:Hide()
  end
  if AssistedHighlightAnimDriver then
    AssistedHighlightAnimDriver:Hide()
  end
end

--- Starts or restarts the cast-success explode. Safe during fade-out and mid-explode
--- so quick successive casts still get feedback.
local function BeginCastExplode()
  if not (AssistedHighlightFrame and AssistedHighlightVisual) then
    return
  end
  CancelCastBreak()
  StopProcEffect()
  AssistedHighlightFrame:Show()
  AssistedHighlightVisual:Show()
  if AssistedHighlightAnimDriver then
    AssistedHighlightAnimDriver:Show()
  end

  -- Burst first so the FlipBook is visible from the first explode frame.
  PlayCastBurst()

  -- Restart from a stable base so chained casts do not compound scale.
  ResetVisualTransform()
  CenterAssistVisual()
  local currentAlpha = AssistedHighlightVisual:GetAlpha() or 1
  if currentAlpha < 0.55 then
    currentAlpha = 0.85
  end
  SetVisualAlpha(currentAlpha)
  SetBurstAlpha(1)

  explodeActive = true
  explodeElapsed = 0
  explodeStartScale = 1
  explodeStartAlpha = currentAlpha
  fadeMode = "shown"
  fadeElapsed = 0
end

local function UpdateCastExplode(elapsed)
  if not AssistedHighlightVisual then
    explodeActive = false
    StopCastBurst()
    return
  end
  explodeElapsed = explodeElapsed + elapsed

  -- Icon shell: scale + fade over CAST_EXPLODE_DURATION (then stay hidden).
  local iconProgress = math.min(1, explodeElapsed / CAST_EXPLODE_DURATION)
  local eased = EaseOutQuad(iconProgress)
  local peak = explodeStartScale + CAST_EXPLODE_EXTRA_SCALE
  local scale = explodeStartScale + (peak - explodeStartScale) * eased
  local iconHoldEnd = 0.33
  local iconFadeT = 0
  if iconProgress > iconHoldEnd then
    iconFadeT = (iconProgress - iconHoldEnd) / (1 - iconHoldEnd)
  end
  local iconAlpha = explodeStartAlpha * (1 - iconFadeT * iconFadeT)
  AssistedHighlightVisual:SetScale(math.max(0.01, scale))
  SetVisualAlpha(iconAlpha)

  -- Burst: FlipBook at native pace; opacity holds longer then fades over BURST_PLAY_DURATION.
  local burstProgress = math.min(1, explodeElapsed / BURST_PLAY_DURATION)
  local burstHoldEnd = 0.45
  local burstFadeT = 0
  if burstProgress > burstHoldEnd then
    burstFadeT = (burstProgress - burstHoldEnd) / (1 - burstHoldEnd)
  end
  SetBurstAlpha(1 - burstFadeT * burstFadeT)

  if explodeElapsed >= BURST_PLAY_DURATION then
    SetVisualAlpha(0)
    SetBurstAlpha(0)
    FinishHide()
  end
end

--- Shake/flash when the player casts something other than the shown suggestion.
local function BeginCastBreak()
  if not (AssistedHighlightFrame and AssistedHighlightVisual) then
    return
  end
  if fadeMode == "hidden" or fadeMode == "out" then
    return
  end
  if explodeActive then
    explodeActive = false
    explodeElapsed = 0
  end
  StopProcEffect()
  StopCastBurst()
  AssistedHighlightFrame:Show()
  AssistedHighlightVisual:Show()
  if AssistedHighlightAnimDriver then
    AssistedHighlightAnimDriver:Show()
  end

  if not breakActive then
    SaveBreakColors()
  end
  ResetVisualTransform()
  CenterAssistVisual()
  SetVisualAlpha(1)

  breakActive = true
  breakElapsed = 0
  fadeMode = "shown"
  fadeElapsed = 0
end

local function UpdateCastBreak(elapsed)
  if not AssistedHighlightVisual then
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
  local flash = ((math.floor(breakElapsed * CAST_BREAK_FLASH_HZ) % 2) == 0) and CAST_BREAK_COLOR_RED
    or CAST_BREAK_COLOR_GREY
  ApplyBreakFlashColor(flash)
  AssistedHighlightVisual:ClearAllPoints()
  AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", ox, oy)
  AssistedHighlightVisual:SetScale(1)
  SetVisualAlpha(alpha)
end

local function RequestShow()
  if not AssistedHighlightFrame or explodeActive or breakActive then
    return
  end
  ResetVisualTransform()
  CenterAssistVisual()
  AssistedHighlightFrame:Show()
  if AssistedHighlightVisual then
    AssistedHighlightVisual:Show()
  end
  if AssistedHighlightAnimDriver then
    AssistedHighlightAnimDriver:Show()
  end
  if fadeMode == "shown" or fadeMode == "in" then
    return
  end
  fadeFromAlpha = (AssistedHighlightVisual and AssistedHighlightVisual:GetAlpha()) or 0
  if fadeMode == "hidden" then
    fadeFromAlpha = 0
    SetVisualAlpha(0)
  end
  fadeMode = "in"
  fadeElapsed = 0
end

local function RequestHide()
  if explodeActive or breakActive then
    return
  end
  if not AssistedHighlightFrame or fadeMode == "hidden" then
    return
  end
  if fadeMode == "out" then
    return
  end
  fadeFromAlpha = (AssistedHighlightVisual and AssistedHighlightVisual:GetAlpha()) or 1
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
      FinishHide()
    end
  end
end

---------------------------------------------------------------------------------------
--                              FRAME CREATION / OnUpdate                            --
---------------------------------------------------------------------------------------
local function EnsureAssistedHighlight()
  if AssistedHighlightFrame then
    return
  end
  if not crosshairFrame then
    return
  end

  local assets = CM.Constants
  AssistedHighlightAnimDriver = CreateFrame("Frame", nil, crosshairFrame)
  AssistedHighlightAnimDriver:Hide()

  AssistedHighlightFrame = CreateFrame("Frame", nil, crosshairFrame)
  AssistedHighlightFrame:Hide()
  AssistedHighlightFrame:SetFrameStrata(crosshairFrame:GetFrameStrata())
  AssistedHighlightFrame:SetFrameLevel(crosshairFrame:GetFrameLevel() + 20)

  AssistedHighlightVisual = CreateFrame("Frame", nil, AssistedHighlightFrame)
  AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", 0, 0)
  AssistedHighlightVisual:Hide()

  AssistedHighlightFrame.shadow = AssistedHighlightVisual:CreateTexture(nil, "BACKGROUND")
  AssistedHighlightFrame.shadow:SetDrawLayer("BACKGROUND", -1)
  AssistedHighlightFrame.shadow:SetAtlas("Radial_Wheel_BG")
  AssistedHighlightFrame.shadow:SetAlpha(0.75)

  -- BACKGROUND: dark beveled well
  AssistedHighlightFrame.background = AssistedHighlightVisual:CreateTexture(nil, "BACKGROUND")
  AssistedHighlightFrame.background:SetDrawLayer("BACKGROUND", 0)
  SetTextureSmooth(AssistedHighlightFrame.background, assets.AssistedSpellIconBackground)
  AssistedHighlightFrame.background:SetVertexColor(1, 1, 1, 1)

  -- ARTWORK: spell icon (circular via mask)
  AssistedHighlightFrame.icon = AssistedHighlightVisual:CreateTexture(nil, "ARTWORK")
  AssistedHighlightFrame.icon:SetDrawLayer("ARTWORK", 0)
  AssistedHighlightFrame.icon:SetPoint("CENTER", AssistedHighlightVisual, "CENTER", 0, 0)
  AssistedHighlightFrame.icon:SetTexCoord(0, 1, 0, 1)

  AssistedHighlightFrame.iconMask = AssistedHighlightVisual:CreateMaskTexture()
  AssistedHighlightFrame.iconMask:SetTexture(
    assets.AssistedSpellIconMask,
    "CLAMPTOBLACKADDITIVE",
    "CLAMPTOBLACKADDITIVE"
  )
  AssistedHighlightFrame.icon:AddMaskTexture(AssistedHighlightFrame.iconMask)

  -- ARTWORK+1: cyan breath glow ring
  AssistedHighlightFrame.glow = AssistedHighlightVisual:CreateTexture(nil, "ARTWORK")
  AssistedHighlightFrame.glow:SetDrawLayer("ARTWORK", 1)
  AssistedHighlightFrame.glow:SetBlendMode("BLEND")
  SetTextureSmooth(AssistedHighlightFrame.glow, assets.AssistedSpellIconGlow)
  AssistedHighlightFrame.glow:SetVertexColor(GLOW_COLOR_R, GLOW_COLOR_G, GLOW_COLOR_B, 1)
  AssistedHighlightFrame.glow:SetAlpha(GLOW_ANIM_MIN_ALPHA)

  -- OVERLAY: dark metallic frame
  AssistedHighlightFrame.frame = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightFrame.frame:SetDrawLayer("OVERLAY", 1)
  AssistedHighlightFrame.frame:SetBlendMode("BLEND")
  SetTextureSmooth(AssistedHighlightFrame.frame, assets.AssistedSpellIconFrame)
  AssistedHighlightFrame.frame:SetVertexColor(1, 1, 1, 1)

  -- OVERLAY+2: Rogue CP slash FlipBook on top of the chrome border
  AssistedHighlightVisual.ProcLoop = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightVisual.ProcLoop:SetDrawLayer("OVERLAY", 2)
  AssistedHighlightVisual.ProcLoop:SetBlendMode("ADD")
  AssistedHighlightVisual.ProcLoop:SetAtlas(PROC_ATLAS)
  AssistedHighlightVisual.ProcLoop:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)
  AssistedHighlightVisual.ProcLoop:Hide()
  EnsureProcAnimations()

  -- OVERLAY+4 on frame (sibling of Visual): vigor burst FlipBook on suggested-spell cast.
  -- Parent is AssistedHighlightFrame so explode alpha on Visual does not wash out the burst.
  AssistedHighlightFrame.BurstFX = AssistedHighlightFrame:CreateTexture(nil, "OVERLAY")
  AssistedHighlightFrame.BurstFX:SetDrawLayer("OVERLAY", 4)
  AssistedHighlightFrame.BurstFX:SetBlendMode("ADD")
  AssistedHighlightFrame.BurstFX:SetAtlas(BURST_ATLAS)
  AssistedHighlightFrame.BurstFX:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)
  AssistedHighlightFrame.BurstFX:Hide()
  EnsureBurstAnimations()

  AssistedHighlightFrame.keybindText =
    AssistedHighlightVisual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  AssistedHighlightFrame.keybindText:SetDrawLayer("OVERLAY", 5)
  AssistedHighlightFrame.keybindText:SetJustifyH("LEFT")
  AssistedHighlightFrame.keybindText:SetText("")
  AssistedHighlightFrame.keybindText:SetShadowColor(0, 0, 0, 1)
  AssistedHighlightFrame.keybindText:SetShadowOffset(1, -1)
  AssistedHighlightFrame.keybindText:Hide()

  AssistedHighlightFrame.cornerKeybindText =
    AssistedHighlightVisual:CreateFontString(nil, "OVERLAY")
  AssistedHighlightFrame.cornerKeybindText:SetDrawLayer("OVERLAY", 6)
  AssistedHighlightFrame.cornerKeybindText:SetJustifyH("CENTER")
  AssistedHighlightFrame.cornerKeybindText:SetJustifyV("MIDDLE")
  AssistedHighlightFrame.cornerKeybindText:SetFont(
    KEYBOARD_KEYBIND_FONT,
    KEYBOARD_KEYBIND_FONT_SIZE,
    KEYBOARD_KEYBIND_FONT_FLAGS
  )
  AssistedHighlightFrame.cornerKeybindText:SetText("")
  AssistedHighlightFrame.cornerKeybindText:SetTextColor(1, 1, 1, 1)
  AssistedHighlightFrame.cornerKeybindText:SetShadowColor(0, 0, 0, 0)
  AssistedHighlightFrame.cornerKeybindText:SetShadowOffset(0, 0)
  AssistedHighlightFrame.cornerKeybindText:Hide()

  AssistedHighlightAnimDriver:SetScript("OnUpdate", function(_, elapsed)
    if breakActive then
      UpdateCastBreak(elapsed)
      return
    end
    if explodeActive then
      UpdateCastExplode(elapsed)
      return
    end
    if fadeMode == "hidden" then
      return
    end
    UpdateFade(elapsed)
    if fadeMode ~= "hidden" then
      UpdateGlowBreath(elapsed)
    end
  end)
end

---------------------------------------------------------------------------------------
--                    KEYBIND RESOLUTION (CLICK-CAST + KEYBOARD)                     --
---------------------------------------------------------------------------------------
local COMPACT_KEY_MAP = {
  ["CTRL"] = "Ctrl",
  ["SHIFT"] = "Shift",
  ["ALT"] = "Alt",
  ["META"] = "M",
  ["MOUSE1"] = "M1",
  ["MOUSE2"] = "M2",
  ["MOUSE3"] = "M3",
  ["MOUSE4"] = "M4",
  ["MOUSE5"] = "M5",
  ["LEFTBUTTON"] = "M1",
  ["RIGHTBUTTON"] = "M2",
  ["MIDDLEBUTTON"] = "M3",
  ["BUTTON1"] = "M1",
  ["BUTTON2"] = "M2",
  ["BUTTON3"] = "M3",
  ["BUTTON4"] = "M4",
  ["BUTTON5"] = "M5",
  ["MOUSEWHEELUP"] = "MwU",
  ["MOUSEWHEELDOWN"] = "MwD",
  ["NUMPAD0"] = "N0",
  ["NUMPAD1"] = "N1",
  ["NUMPAD2"] = "N2",
  ["NUMPAD3"] = "N3",
  ["NUMPAD4"] = "N4",
  ["NUMPAD5"] = "N5",
  ["NUMPAD6"] = "N6",
  ["NUMPAD7"] = "N7",
  ["NUMPAD8"] = "N8",
  ["NUMPAD9"] = "N9",
  ["NUMPADDECIMAL"] = "N.",
  ["NUMPADPLUS"] = "N+",
  ["NUMPADMINUS"] = "N-",
  ["NUMPADMULTIPLY"] = "N*",
  ["NUMPADDIVIDE"] = "N/",
  ["SPACE"] = "SpB",
  ["BACKSPACE"] = "BS",
  ["DELETE"] = "Del",
  ["INSERT"] = "Ins",
  ["HOME"] = "Hm",
  ["END"] = "End",
  ["PAGEUP"] = "PU",
  ["PAGEDOWN"] = "PD",
  ["ESCAPE"] = "Esc",
  ["CAPSLOCK"] = "Cap",
  ["NUMLOCK"] = "NL",
  ["PRINTSCREEN"] = "PrS",
  ["SCROLLLOCK"] = "SL",
  ["PAUSE"] = "Pau",
  ["TAB"] = "Tab",
}

local function AbbreviateKey(raw)
  if not raw or raw == "" then
    return nil
  end
  local parts = {}
  for token in raw:gmatch("[^%-]+") do
    local upper = token:upper()
    local mapped = COMPACT_KEY_MAP[upper]
    parts[#parts + 1] = mapped or token
  end
  return table.concat(parts, "+")
end

local function FormatKeybindText(bindingKey)
  return AbbreviateKey(bindingKey) or bindingKey
end

-- Native mouse atlases are 52x69 (Interface/HelpFrame/NewPlayerExperienceParts).
-- |A:atlas:height:width| must keep that aspect; modifier BLPs stay square.
local CLICK_MOD_ICON_SIZE = 28
local CLICK_MOUSE_ICON_HEIGHT = 28
local CLICK_MOUSE_ICON_WIDTH = math.floor(CLICK_MOUSE_ICON_HEIGHT * 52 / 69 + 0.5) -- 21
local CLICK_ICON_LEFT = "|A:newplayertutorial-icon-mouse-leftbutton:"
  .. CLICK_MOUSE_ICON_HEIGHT
  .. ":"
  .. CLICK_MOUSE_ICON_WIDTH
  .. "|a"
local CLICK_ICON_RIGHT = "|A:newplayertutorial-icon-mouse-rightbutton:"
  .. CLICK_MOUSE_ICON_HEIGHT
  .. ":"
  .. CLICK_MOUSE_ICON_WIDTH
  .. "|a"

local function ModifierTextureMarkup(path)
  if not path or path == "" then
    return nil
  end
  return "|T" .. path .. ":" .. CLICK_MOD_ICON_SIZE .. ":" .. CLICK_MOD_ICON_SIZE .. "|t"
end

local MOD_ICON_SHIFT = ModifierTextureMarkup(CM.Constants.ModifierKeyShift)
local MOD_ICON_CTRL = ModifierTextureMarkup(CM.Constants.ModifierKeyCtrl)
local MOD_ICON_ALT = ModifierTextureMarkup(CM.Constants.ModifierKeyAlt)

local CLICKCAST_BINDING_ORDER = {
  { dbKey = "button1", mod = nil, icon = CLICK_ICON_LEFT },
  { dbKey = "button2", mod = nil, icon = CLICK_ICON_RIGHT },
  { dbKey = "shiftbutton1", mod = MOD_ICON_SHIFT, icon = CLICK_ICON_LEFT },
  { dbKey = "shiftbutton2", mod = MOD_ICON_SHIFT, icon = CLICK_ICON_RIGHT },
  { dbKey = "ctrlbutton1", mod = MOD_ICON_CTRL, icon = CLICK_ICON_LEFT },
  { dbKey = "ctrlbutton2", mod = MOD_ICON_CTRL, icon = CLICK_ICON_RIGHT },
  { dbKey = "altbutton1", mod = MOD_ICON_ALT, icon = CLICK_ICON_LEFT },
  { dbKey = "altbutton2", mod = MOD_ICON_ALT, icon = CLICK_ICON_RIGHT },
}

local KEYBIND_STYLE_CLICKCAST = "clickcast"
local KEYBIND_STYLE_KEYBOARD = "keyboard"

local function IsAssistedCombatHighlightCVarEnabled()
  if _G.GetCVarBool then
    return _G.GetCVarBool("assistedCombatHighlight") == true
  end
  if _G.C_CVar and _G.C_CVar.GetCVar then
    return _G.C_CVar.GetCVar("assistedCombatHighlight") == "1"
  end
  if _G.GetCVar then
    return _G.GetCVar("assistedCombatHighlight") == "1"
  end
  return false
end

local function GetSuggestedAssistedSpellID()
  if not (C_AssistedCombat and C_AssistedCombat.GetNextCastSpell) then
    return nil
  end
  local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell)
  spellID = ok and spellID or nil
  spellID = spellID and tonumber(spellID) or nil
  if not spellID or spellID <= 0 then
    return nil
  end
  return spellID
end

local function BuildActionSlotCommandMap()
  local map = {}
  local actionButtonUtil = _G.ActionButtonUtil
  local buttonNames = (actionButtonUtil and actionButtonUtil.ActionBarButtonNames)
    or _G.DEFAULT_ACTION_BUTTON_NAMES
  local buttonCount = tonumber(_G.NUM_ACTIONBAR_BUTTONS) or 12

  if type(buttonNames) == "table" then
    for _, prefix in ipairs(buttonNames) do
      for index = 1, buttonCount do
        local button = _G[prefix .. index]
        if button then
          local slotID = tonumber(button.action)
          if not slotID and button.GetAttribute then
            slotID = tonumber(button:GetAttribute("action"))
          end
          if slotID and slotID > 0 and not map[slotID] then
            local command = button.commandName or button.keyBoundTarget
            if not command and button.GetName then
              local name = button:GetName()
              if name and name ~= "" then
                command = "CLICK " .. name .. ":LeftButton"
              end
            end
            if command and command ~= "" then
              map[slotID] = command
            end
          end
        end
      end
    end
  end

  return map
end

function CM.InvalidateAssistedHighlightKeybindCache()
  actionSlotCommandMap = nil
  assistedActionSlotSet = nil
end

local function BuildAssistedActionSlotSet()
  if assistedActionSlotSet then
    return assistedActionSlotSet
  end
  local set = {}
  if
    C_ActionBar
    and C_ActionBar.HasAssistedCombatActionButtons
    and C_ActionBar.FindAssistedCombatActionButtons
    and C_ActionBar.HasAssistedCombatActionButtons()
  then
    local ok, slots = pcall(C_ActionBar.FindAssistedCombatActionButtons)
    slots = ok and slots or nil
    if type(slots) == "table" then
      for _, value in ipairs(slots) do
        local slot = tonumber(value)
        if slot and slot > 0 then
          set[slot] = true
        end
      end
      for key, value in pairs(slots) do
        local slot
        if type(value) == "number" then
          slot = value
        elseif value == true and type(key) == "number" then
          slot = key
        end
        if slot and slot > 0 then
          set[slot] = true
        end
      end
    end
  end
  assistedActionSlotSet = set
  return assistedActionSlotSet
end

local function GetFirstActionSlotForSpell(spellID)
  if not (spellID and C_ActionBar and C_ActionBar.FindSpellActionButtons) then
    return nil
  end
  local ok, slots = pcall(C_ActionBar.FindSpellActionButtons, spellID)
  slots = ok and slots or nil
  if type(slots) ~= "table" then
    return nil
  end

  local assistedSlots = BuildAssistedActionSlotSet()
  local firstSlot
  local firstSlotIncludingAssisted
  for _, value in ipairs(slots) do
    local slot = tonumber(value)
    if slot and slot > 0 then
      if not firstSlotIncludingAssisted or slot < firstSlotIncludingAssisted then
        firstSlotIncludingAssisted = slot
      end
      if not assistedSlots[slot] and (not firstSlot or slot < firstSlot) then
        firstSlot = slot
      end
    end
  end
  for key, value in pairs(slots) do
    local slot
    if type(value) == "number" then
      slot = value
    elseif value == true and type(key) == "number" then
      slot = key
    end
    if slot and slot > 0 then
      if not firstSlotIncludingAssisted or slot < firstSlotIncludingAssisted then
        firstSlotIncludingAssisted = slot
      end
      if not assistedSlots[slot] and (not firstSlot or slot < firstSlot) then
        firstSlot = slot
      end
    end
  end
  return firstSlot or firstSlotIncludingAssisted
end

local function ActionSlotToBindingName(actionSlot)
  local slot = tonumber(actionSlot)
  if not slot or slot < 1 then
    return nil
  end
  local index = ((slot - 1) % 12) + 1
  local group = math.floor((slot - 1) / 12)
  if group == 0 then
    return "ACTIONBUTTON" .. index
  elseif group == 1 then
    return "MULTIACTIONBAR1BUTTON" .. index
  elseif group == 2 then
    return "MULTIACTIONBAR2BUTTON" .. index
  elseif group == 3 then
    return "MULTIACTIONBAR3BUTTON" .. index
  elseif group == 4 then
    return "MULTIACTIONBAR4BUTTON" .. index
  end
  return nil
end

local function GetClickCastDisplayForSpell(spellID)
  if not (CM.DB and CM.DB.global and CM.DB.char) then
    return nil
  end
  local actionSlot = GetFirstActionSlotForSpell(spellID)
  if not actionSlot then
    return nil
  end
  local bindingName = ActionSlotToBindingName(actionSlot)
  if not bindingName then
    return nil
  end

  local location = CM.GetBindingsLocation and CM.GetBindingsLocation() or "char"
  local bindingsRoot = CM.DB[location]
  local bindings = bindingsRoot and bindingsRoot.bindings
  if type(bindings) ~= "table" then
    return nil
  end

  for _, entry in ipairs(CLICKCAST_BINDING_ORDER) do
    local setting = bindings[entry.dbKey]
    if setting and setting.enabled and setting.value == bindingName then
      if entry.mod then
        return entry.mod .. entry.icon, KEYBIND_STYLE_CLICKCAST
      end
      return entry.icon, KEYBIND_STYLE_CLICKCAST
    end
  end

  return nil
end

local function GetBindingCommandForActionSlot(slot)
  local actionSlot = tonumber(slot)
  if not actionSlot or actionSlot < 1 then
    return nil
  end

  if not actionSlotCommandMap then
    actionSlotCommandMap = BuildActionSlotCommandMap()
  end
  if actionSlotCommandMap and actionSlotCommandMap[actionSlot] then
    return actionSlotCommandMap[actionSlot]
  end

  local index = ((actionSlot - 1) % 12) + 1
  local group = math.floor((actionSlot - 1) / 12)
  if group == 0 then
    return "ACTIONBUTTON" .. index
  elseif group == 1 then
    return "MULTIACTIONBAR1BUTTON" .. index
  elseif group == 2 then
    return "MULTIACTIONBAR2BUTTON" .. index
  elseif group == 3 then
    return "MULTIACTIONBAR3BUTTON" .. index
  elseif group == 4 then
    return "MULTIACTIONBAR4BUTTON" .. index
  end

  return nil
end

local function GetFirstBindingKeyForSpell(spellID)
  local slot = GetFirstActionSlotForSpell(spellID)
  if not slot then
    return nil
  end
  local command = GetBindingCommandForActionSlot(slot)
  if not command or not _G.GetBindingKey then
    return nil
  end
  local key1, key2 = _G.GetBindingKey(command)
  return key1 or key2
end

---------------------------------------------------------------------------------------
--                         VISIBILITY GATE + KEYBIND STYLE                           --
---------------------------------------------------------------------------------------
local function ShouldShowAssistedHighlightIcon()
  if not (CM.DB and CM.DB.global) then
    return false
  end
  local enabled = CM.DB.global.assistedHighlightEnabled
  if enabled == nil then
    enabled = CM.Constants.DatabaseDefaults.global.assistedHighlightEnabled
  end
  if not enabled then
    return false
  end
  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    return true
  end
  if not CM.IsCrosshairEnabled() or CM.HideCrosshairWhileMounted() then
    return false
  end
  if not (crosshairTexture and crosshairTexture.IsShown and crosshairTexture:IsShown()) then
    return false
  end
  if not IsMouselooking() then
    return false
  end
  if not (UnitAffectingCombat and UnitAffectingCombat("player")) then
    return false
  end
  if not IsAssistedCombatHighlightCVarEnabled() then
    return false
  end
  if C_AssistedCombat and C_AssistedCombat.IsAvailable then
    local ok, isAvailable = pcall(C_AssistedCombat.IsAvailable)
    if ok and isAvailable == false then
      return false
    end
  end
  return true
end

local function ApplyClickCastKeybindStyle()
  local label = AssistedHighlightFrame and AssistedHighlightFrame.keybindText
  if not label then
    return
  end
  label:SetTextColor(1, 1, 1, 1)
  label:SetShadowColor(0, 0, 0, 1)
  label:SetShadowOffset(1, -1)
end

local function ApplyKeyboardKeybindStyle()
  local label = AssistedHighlightFrame and AssistedHighlightFrame.cornerKeybindText
  if not label then
    return
  end
  label:SetFont(KEYBOARD_KEYBIND_FONT, KEYBOARD_KEYBIND_FONT_SIZE, KEYBOARD_KEYBIND_FONT_FLAGS)
  label:SetTextColor(1, 1, 1, 1)
  label:SetShadowColor(0, 0, 0, 0)
  label:SetShadowOffset(0, 0)
end

---------------------------------------------------------------------------------------
--                    LAYOUT APPLY + PUBLIC API (OPTIONS / UPDATE)                   --
---------------------------------------------------------------------------------------
function CM.ApplyCrosshairAssistedHighlightOptions()
  EnsureAssistedHighlight()
  if not AssistedHighlightFrame then
    return
  end
  if not (CM.DB and CM.DB.global) then
    return
  end
  AssistedHighlightFrame:SetFrameStrata(crosshairFrame:GetFrameStrata())
  AssistedHighlightFrame:SetFrameLevel(crosshairFrame:GetFrameLevel() + 20)

  local g = CM.DB.global
  local d = CM.Constants.DatabaseDefaults.global
  local size = ICON_SIZE
  local side = g.assistedHighlightSide or d.assistedHighlightSide or "RIGHT"
  if side ~= "LEFT" then
    side = "RIGHT"
  end
  local fontSize = 14
  local expand = CalculateShellExpand(size)
  local outer = size + expand * 2
  glowColorAlpha = 1

  local crosshairSize = tonumber(g.crosshairSize or d.crosshairSize) or 64
  local gap = (crosshairSize / 2) + ASSIST_OFFSET_X

  local layoutChanged = lastAppliedSide ~= side

  AssistedHighlightFrame:ClearAllPoints()
  if side == "LEFT" then
    AssistedHighlightFrame:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, 0)
  else
    AssistedHighlightFrame:SetPoint("LEFT", crosshairFrame, "CENTER", gap, 0)
  end
  AssistedHighlightFrame:SetAlpha(1)

  -- Click-cast keybind flips with cluster side; keyboard stays top-right on the icon.
  do
    local keyGap = expand
    local clickLabel = AssistedHighlightFrame.keybindText
    if clickLabel then
      clickLabel:ClearAllPoints()
      if side == "LEFT" then
        clickLabel:SetPoint("RIGHT", AssistedHighlightFrame.icon, "LEFT", -keyGap, 0)
        clickLabel:SetJustifyH("RIGHT")
      else
        clickLabel:SetPoint("LEFT", AssistedHighlightFrame.icon, "RIGHT", keyGap, 0)
        clickLabel:SetJustifyH("LEFT")
      end
    end
    local keyboardLabel = AssistedHighlightFrame.cornerKeybindText
    if keyboardLabel then
      keyboardLabel:ClearAllPoints()
      keyboardLabel:SetPoint(
        "CENTER",
        AssistedHighlightFrame.icon,
        "CENTER",
        KEYBOARD_KEYBIND_OFFSET_X,
        KEYBOARD_KEYBIND_OFFSET_Y
      )
      keyboardLabel:SetJustifyH("CENTER")
    end
  end

  if layoutChanged then
    lastAppliedSide = side

    -- Outer size fits the expanded shell (icon is `size`; chrome extends by expand).
    AssistedHighlightFrame:SetSize(outer, outer)
    if AssistedHighlightVisual then
      AssistedHighlightVisual:SetSize(outer, outer)
      AssistedHighlightVisual:SetPoint("CENTER", AssistedHighlightFrame, "CENTER", 0, 0)
    end

    AssistedHighlightFrame.icon:SetSize(size, size)
    AssistedHighlightFrame.icon:ClearAllPoints()
    AssistedHighlightFrame.icon:SetPoint("CENTER", AssistedHighlightVisual, "CENTER", 0, 0)

    local shadowPad = math.floor((size * (SHADOW_SCALE - 1)) * 0.5 + 0.5)
    AssistedHighlightFrame.shadow:ClearAllPoints()
    AssistedHighlightFrame.shadow:SetPoint(
      "TOPLEFT",
      AssistedHighlightFrame.icon,
      "TOPLEFT",
      -shadowPad,
      shadowPad
    )
    AssistedHighlightFrame.shadow:SetPoint(
      "BOTTOMRIGHT",
      AssistedHighlightFrame.icon,
      "BOTTOMRIGHT",
      shadowPad,
      -shadowPad
    )

    LayoutShellAroundIcon(AssistedHighlightFrame.iconMask, AssistedHighlightFrame.icon, expand)
    LayoutShellAroundIcon(AssistedHighlightFrame.background, AssistedHighlightFrame.icon, expand)
    LayoutShellAroundIcon(AssistedHighlightFrame.glow, AssistedHighlightFrame.icon, expand)
    LayoutShellAroundIcon(AssistedHighlightFrame.frame, AssistedHighlightFrame.icon, expand)
    LayoutProcEffect(AssistedHighlightFrame.icon, expand)
    LayoutBurstEffect(AssistedHighlightFrame.icon)

    -- Re-apply textures when layout changes (ApplyOptions path).
    local assets = CM.Constants
    SetTextureSmooth(AssistedHighlightFrame.background, assets.AssistedSpellIconBackground)
    SetTextureSmooth(AssistedHighlightFrame.glow, assets.AssistedSpellIconGlow)
    SetTextureSmooth(AssistedHighlightFrame.frame, assets.AssistedSpellIconFrame)
    AssistedHighlightFrame.iconMask:SetTexture(
      assets.AssistedSpellIconMask,
      "CLAMPTOBLACKADDITIVE",
      "CLAMPTOBLACKADDITIVE"
    )

    AssistedHighlightFrame.background:SetAlpha(1)
    AssistedHighlightFrame.frame:SetAlpha(1)
    AssistedHighlightFrame.glow:SetVertexColor(GLOW_COLOR_R, GLOW_COLOR_G, GLOW_COLOR_B, 1)
    -- Do not set glow alpha here — breath OnUpdate owns it.
    -- Do not restart the one-shot proc FlipBook on layout changes.

    CM.SetFontStringFromTemplate(
      AssistedHighlightFrame.keybindText,
      fontSize,
      _G.GameFontNormalSmall
    )
    ApplyClickCastKeybindStyle()
    ApplyKeyboardKeybindStyle()
  end
end

local function ShowAssistedHighlightContent(texture, keybindText, keybindStyle, spellID)
  lastShownSpellID = spellID
  RememberShownSpell(spellID)
  AssistedHighlightFrame.icon:SetTexture(texture)
  AssistedHighlightFrame.icon:Show()
  AssistedHighlightFrame.shadow:Show()
  AssistedHighlightFrame.background:Show()
  AssistedHighlightFrame.glow:Show()
  AssistedHighlightFrame.frame:Show()
  PlayProcEffectForSpell(spellID)

  if keybindText and keybindText ~= "" then
    if keybindStyle == KEYBIND_STYLE_CLICKCAST then
      AssistedHighlightFrame.keybindText:SetText(keybindText)
      AssistedHighlightFrame.cornerKeybindText:SetText("")
      AssistedHighlightFrame.cornerKeybindText:Hide()
      ApplyClickCastKeybindStyle()
      AssistedHighlightFrame.keybindText:Show()
    else
      AssistedHighlightFrame.cornerKeybindText:SetText(keybindText)
      AssistedHighlightFrame.keybindText:SetText("")
      AssistedHighlightFrame.keybindText:Hide()
      ApplyKeyboardKeybindStyle()
      AssistedHighlightFrame.cornerKeybindText:Show()
    end
  else
    AssistedHighlightFrame.keybindText:Hide()
    AssistedHighlightFrame.cornerKeybindText:Hide()
  end

  RequestShow()
end

function CM.UpdateCrosshairAssistedHighlight()
  EnsureAssistedHighlight()
  if not AssistedHighlightFrame then
    return
  end
  if explodeActive or breakActive then
    return
  end

  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    if not ShouldShowAssistedHighlightIcon() then
      RequestHide()
      return
    end
    CM.ApplyCrosshairAssistedHighlightOptions()
    ShowAssistedHighlightContent(
      134400,
      (MOD_ICON_SHIFT or "Shift+") .. CLICK_ICON_LEFT,
      KEYBIND_STYLE_CLICKCAST,
      PROC_PREVIEW_SPELL_ID
    )
    return
  end

  if not ShouldShowAssistedHighlightIcon() then
    RequestHide()
    return
  end

  local spellID = GetSuggestedAssistedSpellID()
  if not spellID then
    RequestHide()
    return
  end

  if not (C_Spell and C_Spell.GetSpellInfo) then
    RequestHide()
    return
  end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  info = ok and info or nil
  local texture = info and info.iconID
  if not texture then
    RequestHide()
    return
  end

  CM.ApplyCrosshairAssistedHighlightOptions()

  local keybindText, keybindStyle = GetClickCastDisplayForSpell(spellID)
  if not keybindText then
    keybindText = FormatKeybindText(GetFirstBindingKeyForSpell(spellID))
    keybindStyle = keybindText and KEYBIND_STYLE_KEYBOARD or nil
  end

  ShowAssistedHighlightContent(texture, keybindText, keybindStyle, spellID)
end

--- Explode on suggested-spell cast; shake/flash break on any other successful cast
--- while the assist icon is visible.
function CM.OnAssistedHighlightSpellCast(spellID)
  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    return
  end
  if not IsAssistVisibleForCastFeedback() then
    return
  end
  if SpellMatchesRecent(spellID) then
    BeginCastExplode()
  else
    BeginCastBreak()
  end
end

--- Explode when the Assisted Combat action button is used (no spellID payload).
function CM.OnAssistedHighlightAssistedActionCast()
  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    return
  end
  if not IsAssistVisibleForCastFeedback() then
    return
  end
  BeginCastExplode()
end

function CM.InitAssistedHighlight(opts)
  crosshairFrame = opts and opts.crosshairFrame or crosshairFrame
  crosshairTexture = opts and opts.crosshairTexture or crosshairTexture
end
