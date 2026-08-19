---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Assist.lua — CROSSHAIR — Assisted Combat chrome
---------------------------------------------------------------------------------------
--  What it does: Owns IconMask chrome beside the crosshair (Left/Right via
--  assistedHighlightSide, default RIGHT; icon size 40): frame creation, shell layout,
--  visibility gates, and public Apply / Update / Init APIs. Wires Motion + Feedback.
--  Architecture / how it works:
--    • EnsureAssistedHighlight creates chrome, Feedback.CreateTextures, ProcLoop,
--      then Motion.Attach + Feedback.Attach (Feedback attaches CastProgress).
--    • AnimDriver OnUpdate: Feedback.Tick then Motion.Tick.
--    • APIs: InitAssistedHighlight, ApplyCrosshairAssistedHighlightOptions,
--      UpdateCrosshairAssistedHighlight. Keybind cache / cast events live in siblings.
--    • Preview: IsCrosshairPreviewActive forces placeholder icon + keybind layout.
--  Does not: Own keybind resolution (Keybinds), ProcLoop/glow/fade (Motion), swipe/
--  break (CastProgress), or press/pulse/cache (Feedback). Not Animations / SoftTarget.
--  Related: Core/Crosshair/AssistedHighlight/{Keybinds,Motion,CastProgress,Feedback}.lua,
--  Core/Crosshair/Crosshair.lua, Core/Runtime/EventRouter.lua, Constants/Assets.lua,
--  Constants/Gameplay.lua, UI/Options/Tabs/TabCrosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local IsMouselooking = _G.IsMouselooking
local UnitAffectingCombat = _G.UnitAffectingCombat

local C_AssistedCombat = _G.C_AssistedCombat
local C_Spell = _G.C_Spell

-- Lua stdlib
local math = _G.math
local pcall = _G.pcall
local tonumber = _G.tonumber
local GetTime = _G.GetTime

-- Suggested spell cache: avoids pcall(C_AssistedCombat.GetNextCastSpell) on every tick.
-- Invalidated by InvalidateSuggestedSpellCache() on ASSISTED_HIGHLIGHT_EVENTS.
local suggestedSpellID
local suggestedSpellCacheTime

local Keybinds = CM.AssistedHighlightKeybinds
local Motion = CM.AssistedHighlightMotion
local Feedback = CM.AssistedHighlightFeedback

local crosshairFrame
local crosshairTexture

local AssistedHighlightFrame
local AssistedHighlightVisual
local AssistedHighlightAnimDriver

-- Shell layout (IconMask)
local ICON_MASK_BASE_SIZE = 32
local ICON_MASK_BASE_EXPAND = 6
local SHADOW_SCALE = 1.5
local ICON_SIZE = 40
local ASSIST_OFFSET_X = CM.Constants.CrosshairCompanionOffsetX

local lastAppliedSide
local lastShownSpellID

---------------------------------------------------------------------------------------
--                         SHARED HELPERS (SHELL / TEXTURE)                          --
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

local function BindCompanions()
  if Motion and Motion.Attach then
    Motion.Attach({
      getFrame = function()
        return AssistedHighlightFrame
      end,
      getVisual = function()
        return AssistedHighlightVisual
      end,
      getAnimDriver = function()
        return AssistedHighlightAnimDriver
      end,
      clearLastShownSpellID = function()
        lastShownSpellID = nil
      end,
      isBreakActive = function()
        return Feedback and Feedback.IsBreakActive and Feedback.IsBreakActive() or false
      end,
      stopAllFeedback = function()
        if Feedback and Feedback.StopAll then
          Feedback.StopAll()
        end
      end,
    })
  end

  if Feedback and Feedback.Attach then
    Feedback.Attach({
      getFrame = function()
        return AssistedHighlightFrame
      end,
      getVisual = function()
        return AssistedHighlightVisual
      end,
      getAnimDriver = function()
        return AssistedHighlightAnimDriver
      end,
      getFadeMode = function()
        return Motion and Motion.GetFadeMode and Motion.GetFadeMode() or "hidden"
      end,
      setFadeMode = function(mode)
        if Motion and Motion.SetFadeMode then
          Motion.SetFadeMode(mode)
        end
      end,
      getLastShownSpellID = function()
        return lastShownSpellID
      end,
      previewSpellID = Motion and Motion.PROC_PREVIEW_SPELL_ID or -1,
      stopProcEffect = function()
        if Motion and Motion.StopProcEffect then
          Motion.StopProcEffect()
        end
      end,
    })
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

  -- Backdrop shadow (same atlas as Party Radial role icons; larger so soft edge extends).
  AssistedHighlightFrame.shadow = AssistedHighlightVisual:CreateTexture(nil, "BACKGROUND")
  AssistedHighlightFrame.shadow:SetDrawLayer("BACKGROUND", -1)
  AssistedHighlightFrame.shadow:SetAtlas("Radial_Wheel_BG_Small")
  AssistedHighlightFrame.shadow:SetAlpha(1)

  -- BACKGROUND: dark beveled well
  AssistedHighlightFrame.background = AssistedHighlightVisual:CreateTexture(nil, "BACKGROUND")
  AssistedHighlightFrame.background:SetDrawLayer("BACKGROUND", 0)
  SetTextureSmooth(AssistedHighlightFrame.background, assets.AssistedSpellIconBackground)
  AssistedHighlightFrame.background:SetVertexColor(1, 1, 1, 1)

  -- ARTWORK: circular-masked spell icon
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

  -- Cooldown swipe + successPulse (Feedback) — between icon mask and glow, matching
  -- prior create order so swipe draws under the breath glow / frame chrome.
  if Feedback and Feedback.CreateTextures then
    Feedback.CreateTextures(AssistedHighlightFrame, AssistedHighlightVisual, assets)
  end

  local glowMin = (Motion and Motion.GLOW_ANIM_MIN_ALPHA) or 0.45
  local glowR = (Motion and Motion.GLOW_COLOR_R) or 0.44
  local glowG = (Motion and Motion.GLOW_COLOR_G) or 0.98
  local glowB = (Motion and Motion.GLOW_COLOR_B) or 1
  local procAtlas = (Motion and Motion.PROC_ATLAS) or "UF-RogueCP-Slash-Blue"

  -- ARTWORK+1: cyan breath glow
  AssistedHighlightFrame.glow = AssistedHighlightVisual:CreateTexture(nil, "ARTWORK")
  AssistedHighlightFrame.glow:SetDrawLayer("ARTWORK", 1)
  AssistedHighlightFrame.glow:SetBlendMode("BLEND")
  SetTextureSmooth(AssistedHighlightFrame.glow, assets.AssistedSpellIconGlow)
  AssistedHighlightFrame.glow:SetVertexColor(glowR, glowG, glowB, 1)
  AssistedHighlightFrame.glow:SetAlpha(glowMin)

  -- OVERLAY: dark frame
  AssistedHighlightFrame.frame = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightFrame.frame:SetDrawLayer("OVERLAY", 1)
  AssistedHighlightFrame.frame:SetBlendMode("BLEND")
  SetTextureSmooth(AssistedHighlightFrame.frame, assets.AssistedSpellIconFrame)
  AssistedHighlightFrame.frame:SetVertexColor(1, 1, 1, 1)

  -- OVERLAY+2: ProcLoop FlipBook
  AssistedHighlightVisual.ProcLoop = AssistedHighlightVisual:CreateTexture(nil, "OVERLAY")
  AssistedHighlightVisual.ProcLoop:SetDrawLayer("OVERLAY", 2)
  AssistedHighlightVisual.ProcLoop:SetBlendMode("ADD")
  AssistedHighlightVisual.ProcLoop:SetAtlas(procAtlas)
  AssistedHighlightVisual.ProcLoop:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)
  AssistedHighlightVisual.ProcLoop:Hide()

  BindCompanions()
  if Motion and Motion.EnsureProcAnimations then
    Motion.EnsureProcAnimations()
  end

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
  -- Font must be set before SetText (no inheritObject on CreateFontString).
  if Keybinds and Keybinds.ApplyKeyboardKeybindStyle then
    Keybinds.ApplyKeyboardKeybindStyle(AssistedHighlightFrame.cornerKeybindText)
  end
  AssistedHighlightFrame.cornerKeybindText:SetText("")
  AssistedHighlightFrame.cornerKeybindText:Hide()

  AssistedHighlightAnimDriver:SetScript("OnUpdate", function(_, elapsed)
    CM.Profile("Assist:AnimDriver", function()
      CM.ProfileEvent("Feedback.Tick")
      if Feedback and Feedback.Tick and Feedback.Tick(elapsed) then
        return
      end
      if Motion and Motion.Tick then
        CM.ProfileEvent("Motion.Tick")
        Motion.Tick(elapsed)
      end
    end)
  end)
end

---------------------------------------------------------------------------------------
--                         VISIBILITY GATE                                           --
---------------------------------------------------------------------------------------
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
  -- Cache the result for ~1 second since the suggested spell doesn't change every
  -- throttle tick (0.15s). The cache is invalidated on ASSISTED_HIGHLIGHT_EVENTS
  -- via InvalidateSuggestedSpellCache. This avoids a pcall + GetNextCastSpell
  -- on every tick (the largest single cost in UpdateCrosshairAssistedHighlight).
  local now = GetTime()
  if
    suggestedSpellCacheTime
    and now - suggestedSpellCacheTime < 1.0
    and suggestedSpellID ~= nil
  then
    return suggestedSpellID
  end
  suggestedSpellCacheTime = now
  local ok, spellID = pcall(C_AssistedCombat.GetNextCastSpell)
  spellID = ok and spellID or nil
  spellID = spellID and tonumber(spellID) or nil
  if not spellID or spellID <= 0 then
    suggestedSpellID = nil
    return nil
  end
  suggestedSpellID = spellID
  return spellID
end

--- Invalidate the suggested spell cache so the next call re-queries the game API.
--- Fired from ASSISTED_HIGHLIGHT_EVENTS when the assisted combat rotation changes.
function CM.InvalidateSuggestedSpellCache()
  suggestedSpellCacheTime = nil
  suggestedSpellID = nil
end

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
  if not CM.IsCrosshairEnabled() or CM.IsCrosshairMounted() then
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

  local crosshairSize = (CM.GetCrosshairPixelSize and CM.GetCrosshairPixelSize())
    or tonumber(g.crosshairSize or d.crosshairSize)
    or 64
  local gap = (crosshairSize / 2) + ASSIST_OFFSET_X

  local layoutChanged = lastAppliedSide ~= side

  AssistedHighlightFrame:ClearAllPoints()
  if side == "LEFT" then
    AssistedHighlightFrame:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, 0)
  else
    AssistedHighlightFrame:SetPoint("LEFT", crosshairFrame, "CENTER", gap, 0)
  end
  AssistedHighlightFrame:SetAlpha(1)
  local assistScale = tonumber(g.assistedHighlightScale) or d.assistedHighlightScale or 1
  if assistScale < 0.5 then
    assistScale = 0.5
  elseif assistScale > 1.5 then
    assistScale = 1.5
  end
  AssistedHighlightFrame:SetScale(assistScale)

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
      local ox = (Keybinds and Keybinds.KEYBOARD_OFFSET_X) or 10
      local oy = (Keybinds and Keybinds.KEYBOARD_OFFSET_Y) or 12
      keyboardLabel:ClearAllPoints()
      keyboardLabel:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", ox, oy)
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

    local shadowSize = size * SHADOW_SCALE
    AssistedHighlightFrame.shadow:ClearAllPoints()
    AssistedHighlightFrame.shadow:SetSize(shadowSize, shadowSize)
    AssistedHighlightFrame.shadow:SetPoint("CENTER", AssistedHighlightFrame.icon, "CENTER", 0, 0)

    LayoutShellAroundIcon(AssistedHighlightFrame.iconMask, AssistedHighlightFrame.icon, expand)
    LayoutShellAroundIcon(AssistedHighlightFrame.background, AssistedHighlightFrame.icon, expand)
    if Feedback and Feedback.LayoutCastProgressSwipe then
      Feedback.LayoutCastProgressSwipe(AssistedHighlightFrame.icon, expand)
    end
    LayoutShellAroundIcon(AssistedHighlightFrame.glow, AssistedHighlightFrame.icon, expand)
    LayoutShellAroundIcon(AssistedHighlightFrame.frame, AssistedHighlightFrame.icon, expand)
    if Motion and Motion.LayoutProcEffect then
      Motion.LayoutProcEffect(AssistedHighlightFrame.icon, expand)
    end

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
    local glowR = (Motion and Motion.GLOW_COLOR_R) or 0.44
    local glowG = (Motion and Motion.GLOW_COLOR_G) or 0.98
    local glowB = (Motion and Motion.GLOW_COLOR_B) or 1
    AssistedHighlightFrame.glow:SetVertexColor(glowR, glowG, glowB, 1)
    -- Do not set glow alpha here — breath OnUpdate owns it.
    -- Do not restart the one-shot proc FlipBook on layout changes.

    CM.SetFontStringFromTemplate(
      AssistedHighlightFrame.keybindText,
      fontSize,
      _G.GameFontNormalSmall
    )
    if Keybinds then
      Keybinds.ApplyClickCastKeybindStyle(AssistedHighlightFrame.keybindText)
      Keybinds.ApplyKeyboardKeybindStyle(AssistedHighlightFrame.cornerKeybindText)
    end
  end
end

local function ShowAssistedHighlightContent(texture, keybindText, keybindStyle, spellID)
  lastShownSpellID = spellID
  if Feedback and Feedback.RememberShownSpell then
    Feedback.RememberShownSpell(spellID)
  end
  AssistedHighlightFrame.icon:SetTexture(texture)
  AssistedHighlightFrame.icon:Show()
  AssistedHighlightFrame.shadow:Show()
  AssistedHighlightFrame.background:Show()
  AssistedHighlightFrame.glow:Show()
  AssistedHighlightFrame.frame:Show()
  if Motion and Motion.PlayProcEffectForSpell then
    Motion.PlayProcEffectForSpell(spellID)
  end

  local styleClick = Keybinds and Keybinds.STYLE_CLICKCAST or "clickcast"
  if keybindText and keybindText ~= "" then
    if keybindStyle == styleClick then
      AssistedHighlightFrame.keybindText:SetText(keybindText)
      AssistedHighlightFrame.cornerKeybindText:SetText("")
      AssistedHighlightFrame.cornerKeybindText:Hide()
      if Keybinds then
        Keybinds.ApplyClickCastKeybindStyle(AssistedHighlightFrame.keybindText)
      end
      AssistedHighlightFrame.keybindText:Show()
    else
      AssistedHighlightFrame.cornerKeybindText:SetText(keybindText)
      AssistedHighlightFrame.keybindText:SetText("")
      AssistedHighlightFrame.keybindText:Hide()
      if Keybinds then
        Keybinds.ApplyKeyboardKeybindStyle(AssistedHighlightFrame.cornerKeybindText)
      end
      AssistedHighlightFrame.cornerKeybindText:Show()
    end
  else
    AssistedHighlightFrame.keybindText:Hide()
    AssistedHighlightFrame.cornerKeybindText:Hide()
  end

  if Motion and Motion.RequestShow then
    Motion.RequestShow()
  end
  -- Sync swipe if already casting; do not reset cast-tracking (mid-cast suggestion
  -- changes would falsely treat a normal finish as a cancel).
  if Feedback and Feedback.UpdateCastProgressSwipe then
    Feedback.UpdateCastProgressSwipe()
  end
end

function CM.UpdateCrosshairAssistedHighlight()
  EnsureAssistedHighlight()
  if not AssistedHighlightFrame then
    return
  end
  if Feedback and Feedback.IsBreakActive and Feedback.IsBreakActive() then
    return
  end

  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    if not ShouldShowAssistedHighlightIcon() then
      if Motion and Motion.RequestHide then
        Motion.RequestHide()
      end
      return
    end
    CM.ApplyCrosshairAssistedHighlightOptions()
    local modShift = (Keybinds and Keybinds.MOD_ICON_SHIFT) or "Shift+"
    local clickLeft = (Keybinds and Keybinds.CLICK_ICON_LEFT) or ""
    local previewID = (Motion and Motion.PROC_PREVIEW_SPELL_ID) or -1
    ShowAssistedHighlightContent(
      134400,
      modShift .. clickLeft,
      Keybinds and Keybinds.STYLE_CLICKCAST or "clickcast",
      previewID
    )
    return
  end

  if not ShouldShowAssistedHighlightIcon() then
    if Motion and Motion.RequestHide then
      Motion.RequestHide()
    end
    return
  end

  local spellID = GetSuggestedAssistedSpellID()
  if not spellID then
    if Motion and Motion.RequestHide then
      Motion.RequestHide()
    end
    return
  end

  if not (C_Spell and C_Spell.GetSpellInfo) then
    if Motion and Motion.RequestHide then
      Motion.RequestHide()
    end
    return
  end
  local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
  info = ok and info or nil
  local texture = info and info.iconID
  if not texture then
    if Motion and Motion.RequestHide then
      Motion.RequestHide()
    end
    return
  end

  CM.ApplyCrosshairAssistedHighlightOptions()

  local keybindText, keybindStyle
  if Keybinds and Keybinds.GetClickCastDisplayForSpell then
    keybindText, keybindStyle = Keybinds.GetClickCastDisplayForSpell(spellID)
  end
  if not keybindText and Keybinds then
    keybindText = Keybinds.FormatKeybindText(Keybinds.GetFirstBindingKeyForSpell(spellID))
    keybindStyle = keybindText and Keybinds.STYLE_KEYBOARD or nil
  end

  ShowAssistedHighlightContent(texture, keybindText, keybindStyle, spellID)
end

function CM.InitAssistedHighlight(opts)
  crosshairFrame = opts and opts.crosshairFrame or crosshairFrame
  crosshairTexture = opts and opts.crosshairTexture or crosshairTexture
end
