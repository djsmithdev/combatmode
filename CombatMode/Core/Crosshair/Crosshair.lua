---------------------------------------------------------------------------------------
--  Core/Crosshair/Crosshair.lua — CROSSHAIR — reticle frame, reaction, companion glue
---------------------------------------------------------------------------------------
--  What it does: Owns the CombatModeCrosshairFrame container/texture, reaction-state
--  tinting, Create/Display/ApplyPosition, CursorCenteredYPos sync from crosshairY, and
--  options preview that forces Interaction HUD + Assisted Highlight companions visible.
--  Inits InteractionHUD, AssistedHighlight, and Animations; routes cast terminals to
--  Animations (SUCCEEDED also notifies AssistedHighlight via EventRouter).
--  Architecture / how it works:
--    • DB.global.crosshair / appearance / crosshairScale / opacity / Y;
--      crosshairReactionColors optional overrides; CM.GetCrosshairReactionColor resolves
--      tints (mounted = defaults; focus → hostile).
--    • crosshairSituationalCondition — user Lua; when true, Animations uses X textures
--      while reaction tint/scale stay normal (mounted / Target Lock still override).
--    • IsCrosshairMounted — returns IsMounted() (always-on; no DB toggle). When mounted,
--      UpdateCrosshairReaction sets a static base appearance (inactive dot) unless
--      crosshairSituationalCondition is true (then full reaction + X texture).
--    • UpdateCrosshairReaction — hostile/friendly/dead/gameobject under mouse or soft
--      target; drives texture + Animations reaction scale. Presence via UnitExists;
--      reaction/booleans are secret-safe (issecretvalue / PublicBool — no UnitGUID
--      compares). While Target Lock shows a nameplate marker, center reticle is a
--      static base-colored Dot (FocusNameplateMarker / SetFocusLockReticleSuppressed);
--      Dot stays while focus exists (even with no nameplate); unlock restores.
--    • SetCrosshairOptionsPreview — tab onSelect/onDeselect; do not reuse mouselook
--      Show/Hide gates.
--    • OnCrosshairCastFeedbackEvent / FocusLock (lock/unlock SFX when Target Lock is
--      enabled via CM.IsTargetLockEnabled; nameplate transfer visual lives in
--      FocusNameplateMarker) / Uncategorized / Rematch hooks from EventRouter / Runtime.
--  Does not: Own SoftTarget CVar writes, assist FlipBook / cast feedback motion, or freelook lock.
--  Related: Core/Crosshair/Animations.lua, Core/Crosshair/InteractionHUD/HUD.lua
--  (and sibling Target/Visual), Core/Crosshair/AssistedHighlight/Assist.lua
--  (and sibling Keybinds/Motion/CastProgress/Feedback), Core/Crosshair/FocusNameplateMarker.lua,
--  Core/Runtime/CVarManager.lua, Core/Runtime/EventRouter.lua, Core/Runtime/UserLuaCondition.lua, UI/Options/Tabs/TabCrosshair.lua,
--  UI/Editors/CrosshairColorsEditor.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local UIParent = _G.UIParent
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitIsGameObject = _G.UnitIsGameObject
local UnitIsPlayer = _G.UnitIsPlayer
local UnitReaction = _G.UnitReaction
local PlaySound = _G.PlaySound
local SOUNDKIT = _G.SOUNDKIT

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local type = _G.type

-- Public boolean when not secret; nil when unknown/secret (cannot branch on it).
local function PublicBool(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  return value and true or false
end

-- Soft UI ticks on Master: character panel open/close for lock/unlock; option click for cycle.
local FOCUS_LOCK_SOUND = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN) or 839
local FOCUS_UNLOCK_SOUND = (SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE) or 840
local FOCUS_CYCLE_SOUND = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION) or 852
local hadFocusUnit = false

-- Outer frame: positioning container. Inner frame: crosshair art, reaction scale, lock-in / cast feedback.
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)
local CrosshairVisualFrame = CreateFrame("Frame", nil, CrosshairFrame)
local CrosshairTexture = CrosshairVisualFrame:CreateTexture(nil, "OVERLAY")
local CrosshairAnimation = CrosshairVisualFrame:CreateAnimationGroup()
CM.CreateCrosshairScaleAnimation(CrosshairAnimation)
CM.InitInteractionHUD({ crosshairFrame = CrosshairFrame, crosshairTexture = CrosshairTexture })
if CM.InitAssistedHighlight then
  CM.InitAssistedHighlight({ crosshairFrame = CrosshairFrame, crosshairTexture = CrosshairTexture })
end

function CM.IsCrosshairMounted()
  return IsMounted()
end

-- SavedVariables may store 1/0; use this anywhere UI enablement must match "crosshair on"
-- (not strict `== true`).
function CM.IsCrosshairEnabled()
  local c = CM.DB and CM.DB.global and CM.DB.global.crosshair
  if c == nil then
    return CM.Constants.DatabaseDefaults.global.crosshair
  end
  return not not c
end

local function CopyColorArray(source)
  if type(source) ~= "table" then
    return nil
  end
  local r = source[1] or source.r
  local g = source[2] or source.g
  local b = source[3] or source.b
  local a = source[4] or source.a
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or type(a) ~= "number" then
    return nil
  end
  return { r, g, b, a }
end

--- Reaction tint for crosshair, Target Lock idle Dot, nameplate marker, and cast-break flash.
--- `mounted` always uses constants; `focus` resolves as hostile (no separate swatch).
function CM.GetCrosshairReactionColor(state)
  local constants = CM.Constants and CM.Constants.CrosshairReactionColors
  local effectiveState = state
  if state == "focus" then
    effectiveState = "hostile"
  end

  if effectiveState == "mounted" then
    return CopyColorArray(constants and constants.mounted) or { 1, 1, 1, 0 }
  end

  local overrides = CM.DB and CM.DB.global and CM.DB.global.crosshairReactionColors
  local override = overrides and overrides[effectiveState]
  local fromDb = CopyColorArray(override)
  if fromDb then
    return fromDb
  end

  return CopyColorArray(constants and constants[effectiveState]) or { 1, 1, 1, 1 }
end

local CROSSHAIR_BASE_SIZE = 64

local function ClampUserScale(scale)
  scale = tonumber(scale) or 1
  if scale < 0.5 then
    return 0.5
  end
  if scale > 1.5 then
    return 1.5
  end
  return scale
end

--- Pixel size of the reticle (base 64 × crosshairScale). Migrates legacy crosshairSize once.
function CM.GetCrosshairPixelSize()
  local g = CM.DB and CM.DB.global
  local d = CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global
  local scale
  if g then
    scale = g.crosshairScale
    if scale == nil and g.crosshairSize ~= nil then
      scale = (tonumber(g.crosshairSize) or CROSSHAIR_BASE_SIZE) / CROSSHAIR_BASE_SIZE
      g.crosshairScale = scale
    end
  end
  if scale == nil and d then
    scale = d.crosshairScale
  end
  return CROSSHAIR_BASE_SIZE * ClampUserScale(scale)
end

function CM.GetCrosshairScale()
  return CM.GetCrosshairPixelSize() / CROSSHAIR_BASE_SIZE
end

-- SavedVariables may store 1/0; match "Show Interaction HUD" / DatabaseDefaults.
function CM.IsInteractionHUDEnabled()
  local v = CM.DB and CM.DB.global and CM.DB.global.interactionHUD
  if v == nil then
    return CM.Constants.DatabaseDefaults.global.interactionHUD
  end
  return not not v
end

CM.IsCrosshairOptionsPreviewActive = false

-- While Target Lock is held: center reticle becomes a static base-colored Dot (unreactive).
-- Nameplate marker uses hostile reaction tint; assist/HUD stay on CrosshairFrame.
local focusLockReticleSuppressed = false
local lastKnownAppearanceState = nil
local lastKnownSituationalActive = nil
local situationalConditionCache = {}

function CM.IsCrosshairSituationalActive()
  local g = CM.DB and CM.DB.global
  if not g then
    return false
  end
  return CM.EvaluateUserLuaCondition(
    g.crosshairSituationalCondition,
    situationalConditionCache,
    "Crosshair situational condition"
  )
end

function CM.IsFocusLockReticleSuppressed()
  return focusLockReticleSuppressed
end

local function GetFocusLockIdleTexturePath()
  local obj = CM.Constants
    and CM.Constants.CrosshairTextureObj
    and CM.Constants.CrosshairTextureObj.Dot
  if type(obj) == "table" and type(obj.Base) == "string" then
    return obj.Base
  end
  return "Interface\\AddOns\\CombatMode\\assets\\crosshairDot.blp"
end

local function GetFocusLockIdleColor()
  local c = CM.GetCrosshairReactionColor("base")
  if type(c) == "table" then
    return c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 0.5
  end
  return 1, 1, 1, 0.5
end

local function ApplyFocusLockIdleReticle()
  if CM.CancelCrosshairLockIn then
    CM.CancelCrosshairLockIn()
  end
  if CrosshairAnimation and CrosshairAnimation.Stop then
    CrosshairAnimation:Stop()
  end
  CrosshairVisualFrame:SetScale(1)
  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
  CrosshairFrame:SetAlpha(1)
  CrosshairVisualFrame:SetAlpha(crosshairOpacity)
  CrosshairTexture:SetTexture(GetFocusLockIdleTexturePath())
  local r, g, b, a = GetFocusLockIdleColor()
  CrosshairTexture:SetVertexColor(r, g, b, a)
  if CM.IsCrosshairEnabled() and (CM.IsMouselooking() or CM.IsCrosshairPreviewActive()) then
    CrosshairTexture:Show()
  end
end

function CM.SetFocusLockReticleSuppressed(suppressed)
  suppressed = suppressed and true or false
  if focusLockReticleSuppressed == suppressed then
    if suppressed then
      ApplyFocusLockIdleReticle()
    end
    return
  end
  focusLockReticleSuppressed = suppressed
  if suppressed then
    ApplyFocusLockIdleReticle()
    return
  end
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
  CrosshairVisualFrame:SetAlpha(crosshairOpacity)
  if CM.IsCrosshairEnabled() and CM.IsMouselooking() then
    CrosshairTexture:Show()
    lastKnownAppearanceState = nil
    CM.UpdateCrosshairReaction()
  end
end

function CM.RefreshCrosshairAppearance()
  lastKnownAppearanceState = nil
  if focusLockReticleSuppressed then
    ApplyFocusLockIdleReticle()
  elseif CM.IsCrosshairEnabled() then
    CM.UpdateCrosshairReaction()
  end
  if CM.UpdateFocusNameplateMarker then
    CM.UpdateFocusNameplateMarker()
  end
end

--- Clears the DB override for one reaction state; runtime falls back to constants.
function CM.ResetCrosshairReactionColor(state)
  if not (CM.DB and CM.DB.global and state) then
    return
  end
  local colors = CM.DB.global.crosshairReactionColors
  if not colors then
    return
  end
  colors[state] = nil
  CM.RefreshCrosshairAppearance()
end

-- True while the Crosshair options tab is open and forcing the reticle (and HUD /
-- Combat Assist companions) to render with mouselook off.
function CM.IsCrosshairPreviewActive()
  return CM.IsCrosshairOptionsPreviewActive and true or false
end

local function AdjustCenteredCursorYPos()
  if not CM.IsCrosshairEnabled() then
    return
  end
  local _, cy = CrosshairFrame:GetCenter()
  local h = UIParent:GetHeight()
  if not (cy and h and h > 0) then
    return
  end
  local normalized = cy / h
  CM.SetCursorCenteredYPos(normalized)
end

local function GetCrosshairY()
  if not CM.DB or not CM.DB.global then
    return CM.Constants.DatabaseDefaults.global.crosshairY
  end
  return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
end

local function ApplyCrosshairVertical(y)
  CrosshairFrame:ClearAllPoints()
  CrosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
end

function CM.ApplyCrosshairPosition()
  ApplyCrosshairVertical(GetCrosshairY())
  AdjustCenteredCursorYPos()
end

local function SetCrosshairAppearance(state)
  -- Visual is centered in CrosshairFrame; screen Y offset is on the container, so local offset is 0.
  -- Preview mode bypasses the CM.IsMouselooking() gate so the reticle stays visible while the
  -- Crosshair options tab is open.
  CM.ApplyCrosshairAppearanceToWidget(
    CrosshairVisualFrame,
    CrosshairTexture,
    CrosshairAnimation,
    state,
    0,
    CM.IsCrosshairPreviewActive()
  )
end

function CM.DisplayCrosshair(shouldShow)
  -- While previewing, ignore hide requests from the free-look/unlock paths so tweaking
  -- options with the cursor free still shows the reticle.
  if not shouldShow and CM.IsCrosshairPreviewActive() and CM.IsCrosshairEnabled() then
    shouldShow = true
  end
  if shouldShow then
    local DefaultConfig = CM.Constants.DatabaseDefaults.global
    local UserConfig = CM.DB.global or {}
    local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
    CrosshairFrame:SetAlpha(1)
    CrosshairVisualFrame:SetAlpha(crosshairOpacity)
    if focusLockReticleSuppressed then
      ApplyFocusLockIdleReticle()
    else
      CrosshairTexture:Show()
    end
  else
    if CM.CancelCrosshairCastFeedback then
      CM.CancelCrosshairCastFeedback()
    end
    CrosshairTexture:Hide()
  end
  -- Keep assisted highlight in sync even when Runtime returns early (e.g. cursor mode / UI panels).
  if CM.UpdateCrosshairAssistedHighlight then
    CM.UpdateCrosshairAssistedHighlight()
  end
  CM.RefreshInteractionHUD()
end

function CM.CreateCrosshair()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairSize = CM.GetCrosshairPixelSize()
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  CrosshairTexture:SetAllPoints(CrosshairVisualFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetSize(crosshairSize, crosshairSize)
  CrosshairFrame:SetAlpha(1)
  CrosshairVisualFrame:SetSize(crosshairSize, crosshairSize)
  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  CrosshairVisualFrame:SetAlpha(crosshairOpacity)

  CM.InitCrosshairAnimations({
    outerFrame = CrosshairFrame,
    visualFrame = CrosshairVisualFrame,
    texture = CrosshairTexture,
    onLockInComplete = AdjustCenteredCursorYPos,
  })

  CM.ApplyCrosshairPosition()
  SetCrosshairAppearance("base")
  CM.ApplyCrosshairAssistedHighlightOptions()
  CM.UpdateCrosshairAssistedHighlight()
  CM.ApplyInteractionHUDLayout()
  CM.RefreshInteractionHUD()
end

local DebugCrosshairFrame = CreateFrame("Frame", "CombatModeDebugCrosshairFrame", UIParent)
DebugCrosshairFrame:SetFrameStrata("DIALOG")
DebugCrosshairFrame:SetFrameLevel(0)
local DebugCrosshairTexture = DebugCrosshairFrame:CreateTexture(nil, "OVERLAY")
DebugCrosshairTexture:SetTexture("Interface\\AddOns\\CombatMode\\assets\\crosshairX.blp")
DebugCrosshairTexture:SetAllPoints(DebugCrosshairFrame)
DebugCrosshairTexture:SetBlendMode("BLEND")
DebugCrosshairTexture:SetVertexColor(0, 1, 0, 1)
DebugCrosshairFrame:SetAlpha(0.8)
DebugCrosshairFrame:Hide()

local DebugCrosshairUpdater = CreateFrame("Frame", nil, UIParent)
DebugCrosshairUpdater:SetScript("OnUpdate", function()
  if not (CM.DB.global and CM.DB.global.debugMode) then
    DebugCrosshairFrame:Hide()
    return
  end
  if CM.IsMouselooking() then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    DebugCrosshairFrame:ClearAllPoints()
    DebugCrosshairFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    local size = CM.GetCrosshairPixelSize and CM.GetCrosshairPixelSize() or 64
    DebugCrosshairFrame:SetSize(size, size)
    DebugCrosshairFrame:Show()
  else
    DebugCrosshairFrame:Hide()
  end
end)

local function GetUnitReactionType(unitID)
  if not unitID then
    return "base"
  end
  -- Prefer UnitExists; do not truth-test / compare UnitGUID under instance taint.
  if not UnitExists(unitID) then
    return "base"
  end
  local isTargetObject = PublicBool(UnitIsGameObject(unitID))
  if isTargetObject then
    return "object"
  end
  local reaction = UnitReaction("player", unitID)
  -- Secret reaction numbers cannot be compared; keep base appearance.
  if issecretvalue and issecretvalue(reaction) then
    return "base"
  end
  if not reaction then
    return "base"
  end
  local isPlayer = PublicBool(UnitIsPlayer(unitID))
  if isPlayer then
    local canAttack = PublicBool(UnitCanAttack("player", unitID))
    if canAttack == nil then
      return "base"
    end
    if canAttack then
      return "hostile"
    end
    return "friendly_player"
  elseif reaction <= 4 then
    return "hostile"
  elseif reaction >= 5 then
    return "friendly_npc"
  else
    return "neutral"
  end
end

local function IsEnemyOnlyReticleInCombat()
  return CM.DB
    and CM.DB.char
    and CM.DB.char.reticleTargeting
    and CM.DB.char.reticleTargetingEnemyOnly
    and InCombatLockdown()
end

local function GetUnitUnderCursor()
  local isTargetObject = PublicBool(UnitIsGameObject("softinteract"))
  if isTargetObject then
    return "softinteract", "object"
  end
  -- UnitExists only — do not truth-test UnitGUID under taint.
  if UnitExists("mouseover") then
    local reactionType = GetUnitReactionType("mouseover")
    local enemyOnlyInCombat = IsEnemyOnlyReticleInCombat()

    if not enemyOnlyInCombat or reactionType == "hostile" then
      CM.DebugPrintThrottled(
        "reticleTarget",
        "Found mouseover unit (reaction: " .. reactionType .. ")"
      )
      return "mouseover", reactionType
    end

    local isFriendlyMouseover = reactionType == "friendly_player" or reactionType == "friendly_npc"
    if isFriendlyMouseover then
      local fallbackUnitID = "softenemy"
      if UnitExists(fallbackUnitID) then
        local fallbackReactionType = GetUnitReactionType(fallbackUnitID)
        if fallbackReactionType == "hostile" then
          CM.DebugPrintThrottled(
            "reticleTarget",
            "Mouseover friendly; fallback hostile unit: " .. fallbackUnitID
          )
          return fallbackUnitID, fallbackReactionType
        end
      end
    end

    CM.DebugPrintThrottled(
      "reticleTarget",
      "Mouseover non-hostile in enemy-only combat mode; setting base appearance"
    )
    return nil, nil
  end

  CM.DebugPrintThrottled("reticleTarget", "No unit under cursor, setting base appearance")
  return nil, nil
end

function CM.UpdateCrosshairReaction()
  if not CM.IsCrosshairEnabled() then
    return
  end

  local situationalActive = CM.IsCrosshairSituationalActive()

  -- Inactive Dot while mounted unless situational condition overrides (full reaction).
  if CM.IsCrosshairMounted() and not situationalActive then
    if lastKnownAppearanceState ~= "mounted" or lastKnownSituationalActive then
      lastKnownAppearanceState = "mounted"
      lastKnownSituationalActive = false
      ApplyFocusLockIdleReticle()
    end
    return
  end

  -- Static base-colored Dot while Target Lock is held — do not react to mouseover.
  if focusLockReticleSuppressed then
    return
  end

  -- Target Lock marker lives on FocusNameplateMarker (plate arrive); center is idle Dot.
  local currentUnit, currentReaction = GetUnitUnderCursor()
  local appearanceState = currentUnit and (currentReaction or "base") or "base"

  if
    appearanceState ~= lastKnownAppearanceState
    or situationalActive ~= lastKnownSituationalActive
  then
    lastKnownAppearanceState = appearanceState
    lastKnownSituationalActive = situationalActive
    SetCrosshairAppearance(appearanceState)
  end
end

---------------------------------------------------------------------------------------
--              CORE HOOKS (REMATCH / EVENTS / DISABLE)                              --
---------------------------------------------------------------------------------------
function CM.OnRematchCrosshair()
  if CM.IsCrosshairEnabled() then
    CM.CancelCrosshairLockIn()
    CM.CancelCrosshairCastFeedback()
    CM.CreateCrosshair()
    CM.UpdateCrosshairReaction()

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
    CM.DisplayCrosshair(CM.IsMouselooking())
  else
    CM.DisplayCrosshair(false)
  end
end

function CM.OnCrosshairUncategorizedEvent()
  lastKnownAppearanceState = nil
  lastKnownSituationalActive = nil
  CM.UpdateCrosshairReaction()
  if CM.IsMouselooking() then
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    else
      CM.DisplayCrosshair(false)
    end
  end
end

local function PlayFocusLockSounds(hasFocus)
  if CM.IsTargetLockEnabled and not CM.IsTargetLockEnabled() then
    return
  end
  local g = CM.DB and CM.DB.global
  if not g then
    return
  end
  if not PlaySound then
    return
  end
  -- Do not compare UnitGUID here — GUIDs are secret under instance taint.
  -- PLAYER_FOCUS_CHANGED + UnitExists covers lock / unlock / A→B cycle.
  if hasFocus and not hadFocusUnit then
    PlaySound(FOCUS_LOCK_SOUND, "Master", true)
  elseif not hasFocus and hadFocusUnit then
    PlaySound(FOCUS_UNLOCK_SOUND, "Master", true)
  elseif hasFocus and hadFocusUnit then
    -- Focus A → B (e.g. mouse-wheel cycle).
    PlaySound(FOCUS_CYCLE_SOUND, "Master", true)
  end
end

function CM.OnCrosshairFocusLockEvent(event)
  if event == "PLAYER_FOCUS_CHANGED" then
    local hasFocus = UnitExists("focus")
    PlayFocusLockSounds(hasFocus)
    -- Suppress/restore of the center reticle is owned by FocusNameplateMarker
    -- (Dot stays while focus exists, including waitingForPlate / A→B cycle).
    hadFocusUnit = hasFocus and true or false
    CM.UpdateCrosshairReaction()
  end
end

local function CastFeedbackAllowed()
  return CM.DB
    and CM.DB.global
    and CM.DB.global.crosshairCastFeedback
    and CM.IsCrosshairEnabled()
    and (CM.IsMouselooking() or CM.IsCrosshairPreviewActive())
end

--- Player cast/channel events → grow / explode / break (see Animations.lua).
function CM.OnCrosshairCastFeedbackEvent(event, unitTarget, eventGUID)
  if unitTarget ~= "player" or not CastFeedbackAllowed() then
    return
  end

  if event == "UNIT_SPELLCAST_START" then
    CM.StartCrosshairCastGrow(eventGUID, false)
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    CM.StartCrosshairCastGrow(eventGUID, true)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    CM.NotifyCrosshairCastTerminal(eventGUID, "succeeded")
  elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
    CM.NotifyCrosshairCastTerminal(eventGUID, "failed")
  elseif event == "UNIT_SPELLCAST_STOP" then
    CM.NotifyCrosshairCastTerminal(eventGUID, "stopped")
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    CM.NotifyCrosshairCastTerminal(eventGUID, "channel_stop")
  end
end

--- Enables/disables the options-window live preview: forces the crosshair, Interaction
--- HUD, and Combat Assist icon to render with mouselook off so the Crosshair tab shows
--- changes on the real reticle. Disabling restores the normal mouselook-driven state.
function CM.SetCrosshairOptionsPreview(enabled)
  enabled = enabled and true or false
  if CM.IsCrosshairOptionsPreviewActive == enabled then
    return
  end
  CM.IsCrosshairOptionsPreviewActive = enabled

  if enabled then
    lastKnownAppearanceState = nil
    lastKnownSituationalActive = nil
    CM.CreateCrosshair()
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    end
    return
  end

  CM.CancelCrosshairLockIn()
  CM.CancelCrosshairCastFeedback()
  lastKnownAppearanceState = nil
  lastKnownSituationalActive = nil
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(CM.IsMouselooking())
  else
    CM.DisplayCrosshair(false)
  end
end

function CM.HideCrosshairFrame()
  CrosshairFrame:Hide()
end
