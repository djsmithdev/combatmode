---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Assist.lua — CROSSHAIR — Assisted Combat chrome
---------------------------------------------------------------------------------------
--  What it does: Owns IconMask chrome beside the crosshair (Left/Right via
--  assistedHighlightSide, default RIGHT; icon size 40): frame creation, shell layout,
--  visibility gates, and public Apply / Update / Init APIs. Wires Motion + Feedback.
--  One HUD, two modes: assist (hostile hard target / under crosshair: suggested spell +
--  keybinds) and interact (softinteract: cursor art, name, interact key; Interact.lua).
--  Architecture / how it works:
--    • EnsureAssistedHighlight creates chrome, Feedback.CreateTextures, ProcLoop,
--      then Motion.Attach + Feedback.Attach (Feedback attaches CastProgress).
--    • AnimDriver OnUpdate: Feedback.Tick then Motion.Tick.
--    • APIs: InitAssistedHighlight, ApplyCrosshairAssistedHighlightOptions,
--      UpdateCrosshairAssistedHighlight. Keybind cache / cast events live in siblings.
--    • Preview: IsCrosshairPreviewActive forces placeholder icon + keybind layout.
--    • Gap past reticle edge: assistedHighlightPadding (default CrosshairCompanionOffsetX).
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
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitIsDead = _G.UnitIsDead

local C_AssistedCombat = _G.C_AssistedCombat
local C_Spell = _G.C_Spell

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
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
local Interact = CM.AssistedHighlightInteract

-- Units whose hostility switches the HUD to its assist (spell) mode.
local HOSTILE_FOCUS_UNITS = { "target", "mouseover" }
-- Interaction mode: name label width cap, icon alpha by range.
local NAME_MAX_WIDTH = 280
-- Interaction mode draws the cursor art on its own, smaller texture: it is full-canvas art, so at the
-- spell icon size (and masked to the ring) it looks zoomed in.
local INTERACT_ICON_SIZE = 32
-- Proc FlipBook key for interaction mode (any value that is not a spell id).
local INTERACT_PROC_KEY = "interact"
local INTERACT_ICON_ALPHA_IN_RANGE = 0.9
local INTERACT_ICON_ALPHA_OUT_OF_RANGE = 0.5
-- Assist mode: whole-HUD opacity while the suggested spell is out of range.
local ASSIST_OUT_OF_RANGE_ALPHA = 0.4

local crosshairFrame
local crosshairTexture

local AssistedHighlightFrame
local AssistedHighlightVisual
local AssistedHighlightAnimDriver

-- Shell layout (IconMask)
local ICON_MASK_BASE_SIZE = 32
local ICON_MASK_BASE_EXPAND = 6
local ICON_SIZE = 40
local ASSIST_OFFSET_X = CM.Constants.CrosshairCompanionOffsetX

local lastAppliedSide
local lastShownSpellID
-- Range-dim alpha targets, eased toward by the AnimDriver (snapped while the HUD is hidden).
local ALPHA_LERP_SPEED = 12
local frameAlphaTarget = 1
local iconAlphaTarget = 1
local hudMode -- "assist" | "interact" | nil (what the chrome currently shows)

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

-- useAtlasSize=false: LayoutShellAroundIcon owns the size.
local function SetAtlasFixedSize(texture, atlasName)
  if not (texture and atlasName) then
    return
  end
  CM.SetAtlas(texture, atlasName, false)
end

local function CalculateShellExpand(iconSize)
  local expand = math.floor((iconSize / ICON_MASK_BASE_SIZE) * ICON_MASK_BASE_EXPAND + 0.5)
  if expand < 0 then
    expand = 0
  end
  return expand
end

-- Blizzard ring atlases fill their canvas edge to edge (the old art had padding), so they are
-- shrunk about the icon center. Tune this to resize them.
local ATLAS_SHELL_SCALE = 0.85
-- The glow is sized separately from the ring art; tune to resize it.
local GLOW_SHELL_SCALE = 0.9

local function LayoutAtlasShellAroundIcon(region, icon, expand, scale)
  if not (region and icon) then
    return
  end
  local shell = (icon:GetWidth() + expand * 2) * scale
  region:ClearAllPoints()
  region:SetPoint("CENTER", icon, "CENTER", 0, 0)
  region:SetSize(shell, shell)
end

-- spell-frame.tga is 84x74: a ring (56px across, centered 5px left of the canvas center) with a
-- pointer on the right. The ring is sized to the shell and the pointer faces the crosshair, i.e.
-- mirrored when the icon sits on the crosshair's right.
local FRAME_TEX_W = 84
local FRAME_TEX_H = 74
local FRAME_RING_DIAMETER = 56
local FRAME_RING_OFFSET_X = 5
-- Ring size relative to the icon + shell (the bg/mask sit at ATLAS_SHELL_SCALE); tune to resize.
local FRAME_SHELL_SCALE = 0.76

local function LayoutPointerFrame(region, icon, expand, side)
  if not (region and icon) then
    return
  end
  local k = (icon:GetWidth() + expand * 2) * FRAME_SHELL_SCALE / FRAME_RING_DIAMETER
  local faceLeft = side ~= "LEFT"
  region:ClearAllPoints()
  region:SetSize(FRAME_TEX_W * k, FRAME_TEX_H * k)
  region:SetPoint("CENTER", icon, "CENTER", (faceLeft and -1 or 1) * FRAME_RING_OFFSET_X * k, 0)
  if faceLeft then
    region:SetTexCoord(1, 0, 0, 1)
  else
    region:SetTexCoord(0, 1, 0, 1)
  end
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
local function EaseAlpha(region, target, step)
  local current = region:GetAlpha()
  if math.abs(current - target) < 0.01 then
    if current ~= target then
      region:SetAlpha(target)
    end
    return
  end
  region:SetAlpha(current + (target - current) * step)
end

--- Sets the range-dim targets; snaps when the HUD is not visible yet so it fades in dimmed.
local function SetAlphaTargets(frameAlpha, iconAlpha)
  frameAlphaTarget = frameAlpha
  iconAlphaTarget = iconAlpha
  local frame = AssistedHighlightFrame
  if Motion and Motion.GetFadeMode and Motion.GetFadeMode() == "hidden" then
    frame:SetAlpha(frameAlpha)
    frame.icon:SetAlpha(iconAlpha)
    frame.interactIcon:SetAlpha(iconAlpha)
  end
end

local function TickHudAlpha(elapsed)
  local frame = AssistedHighlightFrame
  if not frame then
    return
  end
  local step = math.min(1, elapsed * ALPHA_LERP_SPEED)
  EaseAlpha(frame, frameAlphaTarget, step)
  EaseAlpha(frame.icon, iconAlphaTarget, step)
  EaseAlpha(frame.interactIcon, iconAlphaTarget, step)
end

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

  -- BACKGROUND: dark beveled well
  AssistedHighlightFrame.background = AssistedHighlightVisual:CreateTexture(nil, "BACKGROUND")
  AssistedHighlightFrame.background:SetDrawLayer("BACKGROUND", 0)
  SetAtlasFixedSize(AssistedHighlightFrame.background, assets.AssistedSpellIconBackground)
  AssistedHighlightFrame.background:SetVertexColor(1, 1, 1, 1)

  -- ARTWORK: circular-masked spell icon
  AssistedHighlightFrame.icon = AssistedHighlightVisual:CreateTexture(nil, "ARTWORK")
  AssistedHighlightFrame.icon:SetDrawLayer("ARTWORK", 0)
  AssistedHighlightFrame.icon:SetPoint("CENTER", AssistedHighlightVisual, "CENTER", 0, 0)
  AssistedHighlightFrame.icon:SetTexCoord(0, 1, 0, 1)

  AssistedHighlightFrame.iconMask = AssistedHighlightVisual:CreateMaskTexture()
  CM.SetAtlasMask(AssistedHighlightFrame.iconMask, assets.AssistedSpellIconMask)
  AssistedHighlightFrame.icon:AddMaskTexture(AssistedHighlightFrame.iconMask)

  -- Interaction mode icon (cursor art): smaller than the spell icon and unmasked, so it is not zoomed.
  AssistedHighlightFrame.interactIcon = AssistedHighlightVisual:CreateTexture(nil, "ARTWORK")
  AssistedHighlightFrame.interactIcon:SetDrawLayer("ARTWORK", 0)
  AssistedHighlightFrame.interactIcon:SetSize(INTERACT_ICON_SIZE, INTERACT_ICON_SIZE)
  AssistedHighlightFrame.interactIcon:SetPoint(
    "CENTER",
    AssistedHighlightFrame.icon,
    "CENTER",
    0,
    0
  )
  AssistedHighlightFrame.interactIcon:Hide()

  -- Cooldown swipe + successPulse (Feedback) — between icon mask and glow, matching
  -- prior create order so swipe draws under the breath glow / frame chrome.
  if Feedback and Feedback.CreateTextures then
    Feedback.CreateTextures(AssistedHighlightFrame, AssistedHighlightVisual, assets)
  end

  local glowMin = (Motion and Motion.GLOW_ANIM_MIN_ALPHA) or 0.45
  local glowR = (Motion and Motion.GLOW_COLOR_R) or 0.816
  local glowG = (Motion and Motion.GLOW_COLOR_G) or 0.541
  local glowB = (Motion and Motion.GLOW_COLOR_B) or 0.322
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
  CM.SetAtlas(AssistedHighlightVisual.ProcLoop, procAtlas)
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

  -- The interactable's name gets its own label (outline + slug) so the click-cast icon label
  -- is never restyled: inline |T / |A icons vanish when their FontString's font is churned.
  AssistedHighlightFrame.nameText =
    AssistedHighlightVisual:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  AssistedHighlightFrame.nameText:SetDrawLayer("OVERLAY", 5)
  AssistedHighlightFrame.nameText:SetWordWrap(false)
  AssistedHighlightFrame.nameText:SetText("")
  AssistedHighlightFrame.nameText:Hide()

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
      TickHudAlpha(elapsed)
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

local function PublicBool(v)
  if issecretvalue and issecretvalue(v) then
    return false
  end
  return v and true or false
end

--- Crosshair visible, unmounted and mouselooking: shared by both HUD modes.
local function PassesCrosshairGate()
  if not CM.IsCrosshairEnabled() or CM.IsCrosshairMounted() then
    return false
  end
  if not (crosshairTexture and crosshairTexture.IsShown and crosshairTexture:IsShown()) then
    return false
  end
  return CM.IsMouselooking()
end

--- Hostile hard target or hostile under the crosshair: the assist mode owns the HUD.
--- Returns the unit token so the range check can use it.
local function GetHostileFocusUnit()
  for _, unit in ipairs(HOSTILE_FOCUS_UNITS) do
    if
      UnitExists(unit)
      and PublicBool(UnitCanAttack("player", unit))
      and not PublicBool(UnitIsDead(unit))
    then
      return unit
    end
  end
  return nil
end

--- False only when the game says the spell is out of range of `unit` (nil = no range / unknown;
--- secret results count as in range).
local function IsSuggestedSpellInRange(spellID, unit)
  if not (C_Spell and C_Spell.IsSpellInRange and spellID and unit) then
    return true
  end
  local ok, inRange = pcall(C_Spell.IsSpellInRange, spellID, unit)
  if not ok or (issecretvalue and issecretvalue(inRange)) then
    return true
  end
  return inRange ~= false
end

--- "always" | "combat" | "hidden" (global.assistedHighlightMode; unknown values read as default).
function CM.GetAssistedHighlightMode()
  local mode = CM.DB and CM.DB.global and CM.DB.global.assistedHighlightMode
  if mode == "always" or mode == "combat" or mode == "hidden" then
    return mode
  end
  return CM.Constants.DatabaseDefaults.global.assistedHighlightMode
end

local function ShouldShowAssistedHighlightIcon()
  if not (CM.DB and CM.DB.global) then
    return false
  end
  local mode = CM.GetAssistedHighlightMode()
  if mode == "hidden" then
    return false
  end
  if CM.IsCrosshairPreviewActive and CM.IsCrosshairPreviewActive() then
    return true
  end
  if not PassesCrosshairGate() then
    return false
  end
  if mode == "combat" and not (UnitAffectingCombat and UnitAffectingCombat("player")) then
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
  local pad = tonumber(g.assistedHighlightPadding)
  if pad == nil then
    pad = ASSIST_OFFSET_X or 24
  end
  if pad < 0 then
    pad = 0
  elseif pad > 128 then
    pad = 128
  end
  local gap = (crosshairSize / 2) + pad

  local layoutChanged = lastAppliedSide ~= side

  AssistedHighlightFrame:ClearAllPoints()
  if side == "LEFT" then
    AssistedHighlightFrame:SetPoint("RIGHT", crosshairFrame, "CENTER", -gap, 0)
  else
    AssistedHighlightFrame:SetPoint("LEFT", crosshairFrame, "CENTER", gap, 0)
  end
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
    for _, clickLabel in ipairs({
      AssistedHighlightFrame.keybindText,
      AssistedHighlightFrame.nameText,
    }) do
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
      local ox = (Keybinds and Keybinds.KEYBOARD_OFFSET_X) or 13
      local oy = (Keybinds and Keybinds.KEYBOARD_OFFSET_Y) or 15
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

    LayoutAtlasShellAroundIcon(
      AssistedHighlightFrame.iconMask,
      AssistedHighlightFrame.icon,
      expand,
      ATLAS_SHELL_SCALE
    )
    LayoutAtlasShellAroundIcon(
      AssistedHighlightFrame.background,
      AssistedHighlightFrame.icon,
      expand,
      ATLAS_SHELL_SCALE
    )
    if Feedback and Feedback.LayoutCastProgressSwipe then
      Feedback.LayoutCastProgressSwipe(AssistedHighlightFrame.icon, expand)
    end
    LayoutAtlasShellAroundIcon(
      AssistedHighlightFrame.glow,
      AssistedHighlightFrame.icon,
      expand,
      GLOW_SHELL_SCALE
    )
    LayoutPointerFrame(AssistedHighlightFrame.frame, AssistedHighlightFrame.icon, expand, side)
    if Motion and Motion.LayoutProcEffect then
      Motion.LayoutProcEffect(AssistedHighlightFrame.icon, expand)
    end

    -- Re-apply textures when layout changes (ApplyOptions path).
    local assets = CM.Constants
    SetAtlasFixedSize(AssistedHighlightFrame.background, assets.AssistedSpellIconBackground)
    SetTextureSmooth(AssistedHighlightFrame.glow, assets.AssistedSpellIconGlow)
    SetTextureSmooth(AssistedHighlightFrame.frame, assets.AssistedSpellIconFrame)
    CM.SetAtlasMask(AssistedHighlightFrame.iconMask, assets.AssistedSpellIconMask)

    AssistedHighlightFrame.background:SetAlpha(1)
    AssistedHighlightFrame.frame:SetAlpha(1)
    local glowR, glowG, glowB = 0.816, 0.541, 0.322
    if Motion then
      if hudMode == "interact" then
        glowR, glowG, glowB = Motion.GLOW_COLOR_R, Motion.GLOW_COLOR_G, Motion.GLOW_COLOR_B
      else
        glowR, glowG, glowB = Motion.ASSIST_COLOR_R, Motion.ASSIST_COLOR_G, Motion.ASSIST_COLOR_B
      end
    end
    AssistedHighlightFrame.glow:SetVertexColor(glowR, glowG, glowB, 1)
    -- Do not set glow alpha here — breath OnUpdate owns it.
    -- Do not restart the one-shot proc FlipBook on layout changes.

    CM.SetFontStringFromTemplate(
      AssistedHighlightFrame.keybindText,
      fontSize,
      _G.GameFontNormalSmall
    )
    CM.SetFontStringFromTemplate(AssistedHighlightFrame.nameText, fontSize, _G.GameFontNormalSmall)
    if Keybinds then
      Keybinds.ApplyClickCastKeybindStyle(AssistedHighlightFrame.keybindText)
      Keybinds.ApplyNameStyle(AssistedHighlightFrame.nameText)
      Keybinds.ApplyKeyboardKeybindStyle(AssistedHighlightFrame.cornerKeybindText)
    end
  end
end

local function HasText(text)
  if text == nil then
    return false
  end
  return (issecretvalue and issecretvalue(text)) or text ~= ""
end

local function IsSecret(v)
  return issecretvalue and issecretvalue(v)
end

--- clickText: click-cast icons beside the icon. nameText: the interactable's name, same spot.
--- cornerText: keyboard badge on the icon (spell key, or the interact key).
local function SetHudLabels(clickText, cornerText, nameText)
  local frame = AssistedHighlightFrame
  if HasText(clickText) then
    frame.keybindText:SetText(clickText)
    if Keybinds then
      Keybinds.ApplyClickCastKeybindStyle(frame.keybindText)
    end
    frame.keybindText:Show()
  else
    frame.keybindText:SetText("")
    frame.keybindText:Hide()
  end
  if HasText(nameText) then
    frame.nameText:SetText(nameText)
    if Keybinds then
      Keybinds.ApplyNameStyle(frame.nameText)
    end
    -- Names can be long (or secret and unmeasurable): cap the width and truncate.
    local width = NAME_MAX_WIDTH
    if not IsSecret(nameText) then
      width = math.min(width, frame.nameText:GetUnboundedStringWidth())
    end
    frame.nameText:SetWidth(width)
    frame.nameText:Show()
  else
    frame.nameText:SetText("")
    frame.nameText:Hide()
  end
  if HasText(cornerText) then
    if Keybinds then
      Keybinds.ApplyKeyboardKeybindStyle(frame.cornerKeybindText)
    end
    frame.cornerKeybindText:SetText(cornerText)
    frame.cornerKeybindText:Show()
  else
    frame.cornerKeybindText:SetText("")
    frame.cornerKeybindText:Hide()
  end
end

local function ShowAssistedHighlightContent(texture, keybindText, keybindStyle, spellID, inRange)
  lastShownSpellID = spellID
  if Feedback and Feedback.RememberShownSpell then
    Feedback.RememberShownSpell(spellID)
  end
  SetAlphaTargets(inRange == false and ASSIST_OUT_OF_RANGE_ALPHA or 1, 1)
  if hudMode ~= "assist" then
    hudMode = "assist"
    if Motion and Motion.SetEffectTint then
      -- Assist keeps the FlipBook's original blue art (no desaturate); glow is cyan.
      Motion.SetEffectTint(
        Motion.ASSIST_COLOR_R,
        Motion.ASSIST_COLOR_G,
        Motion.ASSIST_COLOR_B,
        false
      )
    end
  end
  AssistedHighlightFrame.icon:SetTexture(texture)
  AssistedHighlightFrame.icon:Show()
  AssistedHighlightFrame.interactIcon:Hide()
  AssistedHighlightFrame.background:Show()
  AssistedHighlightFrame.glow:Show()
  AssistedHighlightFrame.frame:Show()
  if Motion and Motion.PlayProcEffectForSpell then
    Motion.PlayProcEffectForSpell(spellID)
  end

  local styleClick = Keybinds and Keybinds.STYLE_CLICKCAST or "clickcast"
  if keybindStyle == styleClick then
    SetHudLabels(keybindText, nil, nil)
  else
    SetHudLabels(nil, keybindText, nil)
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

--- Interaction mode: same chrome, the softinteract cursor art as the icon, the interactable's
--- name beside it and the interact key in the corner badge. Gold glow + proc FlipBook (plays
--- once when the HUD appears, not on every refresh); no spell or swipe.
local function ShowInteractContent()
  local frame = AssistedHighlightFrame
  if hudMode ~= "interact" then
    hudMode = "interact"
    lastShownSpellID = nil
    if Feedback and Feedback.StopAll then
      Feedback.StopAll()
    end
    if Motion and Motion.StopProcEffect then
      Motion.StopProcEffect()
    end
    if Motion and Motion.SetEffectTint then
      Motion.SetEffectTint(Motion.GLOW_COLOR_R, Motion.GLOW_COLOR_G, Motion.GLOW_COLOR_B, true)
    end
  end
  local inRange = Interact.ApplyCursorTexture(frame.interactIcon)
  -- Out of range reads as the game's greyed "unable" art: the shipped icon is the in-range art.
  frame.interactIcon:SetDesaturated(not inRange)
  SetAlphaTargets(1, inRange and INTERACT_ICON_ALPHA_IN_RANGE or INTERACT_ICON_ALPHA_OUT_OF_RANGE)
  frame.icon:Hide()
  frame.interactIcon:Show()
  frame.background:Show()
  frame.glow:Show()
  frame.frame:Show()
  if Motion and Motion.PlayProcEffectForSpell then
    Motion.PlayProcEffectForSpell(INTERACT_PROC_KEY)
  end
  SetHudLabels(nil, Interact.GetInteractKeyText(), Interact.GetUnitName())
  if Motion and Motion.RequestShow then
    Motion.RequestShow()
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

  -- Assist mode wins whenever a hostile is the hard target or under the crosshair.
  local hostileUnit = ShouldShowAssistedHighlightIcon() and GetHostileFocusUnit()
  if hostileUnit then
    local spellID = GetSuggestedAssistedSpellID()
    local texture
    if spellID and C_Spell and C_Spell.GetSpellInfo then
      local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
      texture = ok and info and info.iconID or nil
    end
    if texture then
      CM.ApplyCrosshairAssistedHighlightOptions()

      local keybindText, keybindStyle
      if Keybinds and Keybinds.GetClickCastDisplayForSpell then
        keybindText, keybindStyle = Keybinds.GetClickCastDisplayForSpell(spellID)
      end
      if not keybindText and Keybinds then
        keybindText = Keybinds.FormatKeybindText(Keybinds.GetFirstBindingKeyForSpell(spellID))
        keybindStyle = keybindText and Keybinds.STYLE_KEYBOARD or nil
      end

      ShowAssistedHighlightContent(
        texture,
        keybindText,
        keybindStyle,
        spellID,
        IsSuggestedSpellInRange(spellID, hostileUnit)
      )
      return
    end
  end

  if CM.IsInteractionHUDEnabled() and PassesCrosshairGate() and Interact.HasTarget() then
    CM.ApplyCrosshairAssistedHighlightOptions()
    ShowInteractContent()
    return
  end

  if Motion and Motion.RequestHide then
    Motion.RequestHide()
  end
end

--- The chrome frame (nil until first shown); the setup wizard outlines it during the preview.
function CM.GetAssistedHighlightFrame()
  return AssistedHighlightFrame
end

function CM.InitAssistedHighlight(opts)
  crosshairFrame = opts and opts.crosshairFrame or crosshairFrame
  crosshairTexture = opts and opts.crosshairTexture or crosshairTexture
end
