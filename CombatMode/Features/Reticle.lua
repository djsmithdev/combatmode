---------------------------------------------------------------------------------------
--  Features/Reticle.lua — RETICLE — action-targeting CVars, crosshair UI
---------------------------------------------------------------------------------------
--  Applies ConfigReticleTargeting / soft-target friend toggles, draws the on-screen
--  crosshair (container + inner visual for reaction scale animation and lock-in),
--  and tracks mouseover/soft-target state for appearance. LibEditMode registration,
--  Edit Mode settings, and the crosshair preview panel live in UI/CrosshairEditMode.lua.
--
--  Architecture:
--    • Core drives CreateCrosshair from BootstrapFeatureModules; RegisterCrosshairEditMode
--      runs from the same path after UI/CrosshairEditMode.lua loads. OnUpdate calls
--      CM.UpdateCrosshairReaction when reticle targeting is enabled.
--    • Cursor Y sync uses AdjustCenteredCursorYPos → CursorCenteredYPos when reticle
--      targeting is on; SetCursorFreelookCentering lives in Core.
--    • CM.ApplyCrosshairAppearanceToWidget / CM.CreateCrosshairScaleAnimation are exposed
--      for the Edit Mode preview; EditModeSystemDisplayName (Constants) avoids TOC |T|t in labels.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local IsMouselooking = _G.IsMouselooking
local SetCVar = _G.C_CVar.SetCVar
local UIParent = _G.UIParent
local UnitCanAttack = _G.UnitCanAttack
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitIsPlayer = _G.UnitIsPlayer
local UnitReaction = _G.UnitReaction
local math = _G.math
local unpack = _G.unpack

local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

---------------------------------------------------------------------------------------
--                        RETICLE TARGETING (ACTION TARGETING CVARS)                 --
---------------------------------------------------------------------------------------
function CM.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CM.Constants.ReticleTargetingCVarValues,
    BlizzValues = CM.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting"
  }

  CM.ApplyCVarConfig(info)
end

function CM.HandleSoftTargetFriend(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CM.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CM.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

---------------------------------------------------------------------------------------
--                           CROSSHAIR FRAME & ANIMATION                             --
---------------------------------------------------------------------------------------
-- Outer frame: registered with LibEditMode; sized to at least CrosshairEditModeMinHitSize for a larger Edit Mode click target.
-- Inner frame: actual crosshair art, reaction scale animation, and lock-in (container stays fixed size).
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)
local CrosshairVisualFrame = CreateFrame("Frame", nil, CrosshairFrame)
local CrosshairTexture = CrosshairVisualFrame:CreateTexture(nil, "OVERLAY")
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

local CrosshairAnimation = CrosshairVisualFrame:CreateAnimationGroup()
CreateCrosshairScaleAnimation(CrosshairAnimation)

function CM.HideCrosshairWhileMounted()
  return CM.DB.global.crosshairMounted and IsMounted()
end

local function AdjustCenteredCursorYPos()
  if not (CM.DB and CM.DB.char and CM.DB.char.reticleTargeting) then
    return
  end
  local _, cy = CrosshairFrame:GetCenter()
  local h = UIParent:GetHeight()
  if not (cy and h and h > 0) then
    return
  end
  local normalized = cy / h
  normalized = math.max(0.01, math.min(0.99, normalized))
  SetCVar("CursorCenteredYPos", normalized)
end

local function GetActiveLayoutNameSafe()
  if not ON_RETAIL_CLIENT then
    return nil
  end
  local LEM = LibStub("LibEditMode", true)
  if not LEM then
    return nil
  end
  return LEM:GetActiveLayoutName()
end

function CM.GetCrosshairPositionForLayout(layoutName)
  if not CM.DB or not CM.DB.global then
    return "CENTER", 0, 0
  end
  local g = CM.DB.global
  local tbl = g.crosshairLayoutPositions
  local defY = g.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  if layoutName and tbl and tbl[layoutName] and tbl[layoutName].y ~= nil then
    return "CENTER", 0, tbl[layoutName].y
  end
  return "CENTER", 0, defY
end

local function SyncCrosshairYFromFrame()
  if not CM.DB or not CM.DB.global then
    return CM.Constants.DatabaseDefaults.global.crosshairY
  end
  local cx, cy = CrosshairFrame:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if cx and cy and ux and uy then
    CM.DB.global.crosshairY = cy - uy
  end
  return CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
end

local function ApplyCrosshairVertical(y)
  CrosshairFrame:ClearAllPoints()
  CrosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, y)
end

function CM.ApplyCrosshairPositionForLayout(layoutName)
  if not CM.DB or not CM.DB.global then
    return
  end
  local _, _, y = CM.GetCrosshairPositionForLayout(layoutName)
  ApplyCrosshairVertical(y)
  SyncCrosshairYFromFrame()
  AdjustCenteredCursorYPos()
end

function CM.SyncCrosshairLayoutPositionFromAce()
  if not CM.DB or not CM.DB.global then
    return
  end
  local LEM = LibStub("LibEditMode", true)
  if not LEM or not ON_RETAIL_CLIENT then
    return
  end
  local name = LEM:GetActiveLayoutName()
  if not name then
    return
  end
  if not CM.DB.global.crosshairLayoutPositions then
    CM.DB.global.crosshairLayoutPositions = {}
  end
  local y = CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY
  CM.DB.global.crosshairLayoutPositions[name] = { point = "CENTER", x = 0, y = y }
end

--- Apply crosshair texture, color, and scale animation to a frame (live reticle or edit preview).
--- @param verticalOffset number Y offset from parent center (world crosshair uses saved crosshairY; preview uses 0).
--- @param previewMode boolean If true, always show the texture for non-mounted states (no mouselook check).
local function ApplyCrosshairAppearanceToWidget(targetFrame, targetTexture, animGroup, state, verticalOffset, previewMode)
  local CrosshairAppearance = CM.DB.global.crosshairAppearance
  if not CrosshairAppearance then
    return
  end
  local r, g, b, a = unpack(CM.Constants.CrosshairReactionColors[state])
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false
  local parent = targetFrame:GetParent()

  animGroup:SetScript("OnFinished", function()
    if state ~= "base" then
      targetFrame:SetScale(ENDING_SCALE)
      targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset / ENDING_SCALE)
    end
  end)

  targetTexture:SetTexture(textureToUse)
  targetTexture:SetVertexColor(r, g, b, a)
  if previewMode then
    targetTexture:Show()
  elseif state ~= "mounted" and IsMouselooking() then
    targetTexture:Show()
  end
  animGroup:Play(reverseAnimation)
  if state == "base" then
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
  end
end

CM.ApplyCrosshairAppearanceToWidget = ApplyCrosshairAppearanceToWidget

local function SetCrosshairAppearance(state)
  -- Visual is centered in CrosshairFrame; screen Y offset is on the container, so local offset is 0.
  ApplyCrosshairAppearanceToWidget(CrosshairVisualFrame, CrosshairTexture, CrosshairAnimation, state, 0, false)
end

function CM.DisplayCrosshair(shouldShow)
  if shouldShow then
    CrosshairTexture:Show()
    local DefaultConfig = CM.Constants.DatabaseDefaults.global
    local UserConfig = CM.DB.global or {}
    local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
    CrosshairFrame:SetAlpha(1)
    CrosshairVisualFrame:SetAlpha(crosshairOpacity)
  else
    CrosshairTexture:Hide()
  end
end

function CM.CreateCrosshair()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity
  local minHit = CM.Constants.CrosshairEditModeMinHitSize or 128
  local hitSize = math.max(crosshairSize, minHit)

  CrosshairTexture:SetAllPoints(CrosshairVisualFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetSize(hitSize, hitSize)
  CrosshairFrame:SetAlpha(1)
  CrosshairVisualFrame:SetSize(crosshairSize, crosshairSize)
  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  CrosshairVisualFrame:SetAlpha(crosshairOpacity)

  CM.ApplyCrosshairPositionForLayout(GetActiveLayoutNameSafe())
  SetCrosshairAppearance("base")
  CM.RefreshCrosshairEditPreview()
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
  if IsMouselooking() then
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    DebugCrosshairFrame:ClearAllPoints()
    DebugCrosshairFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    local size = (CM.DB.global.crosshairSize) or (CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global and CM.Constants.DatabaseDefaults.global.crosshairSize) or 64
    DebugCrosshairFrame:SetSize(size, size)
    DebugCrosshairFrame:Show()
  else
    DebugCrosshairFrame:Hide()
  end
end)

local lastKnownAppearanceState = nil

local function GetUnitReactionType(unitID)
  if not unitID then
    return "base"
  end
  if not UnitExists(unitID) or not UnitGUID(unitID) then
    return "base"
  end
  local isTargetObject = UnitIsGameObject(unitID)
  if isTargetObject then
    return "object"
  end
  local reaction = UnitReaction("player", unitID)
  if not reaction then
    return "base"
  end
  if UnitIsPlayer(unitID) then
    if UnitCanAttack("player", unitID) then
      return "hostile"
    else
      return "friendly_player"
    end
  elseif reaction <= 4 then
    return "hostile"
  elseif reaction >= 5 then
    return "friendly_npc"
  else
    return "neutral"
  end
end

local function IsEnemyOnlyReticleInCombat()
  return CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly and InCombatLockdown()
end

local function GetUnitUnderCursor()
  local isTargetObject = UnitIsGameObject("softinteract")
  if isTargetObject then
    return "softinteract", "object"
  end
  if UnitExists("mouseover") and UnitGUID("mouseover") then
    local reactionType = GetUnitReactionType("mouseover")
    local enemyOnlyInCombat = IsEnemyOnlyReticleInCombat()

    if not enemyOnlyInCombat or reactionType == "hostile" then
      CM.DebugPrintThrottled("reticleTarget", "Found mouseover unit (reaction: " .. reactionType .. ")")
      return "mouseover", reactionType
    end

    local isFriendlyMouseover = reactionType == "friendly_player" or reactionType == "friendly_npc"
    if isFriendlyMouseover then
      local fallbackUnitID = "softenemy"
      if UnitExists(fallbackUnitID) and UnitGUID(fallbackUnitID) then
        local fallbackReactionType = GetUnitReactionType(fallbackUnitID)
        if fallbackReactionType == "hostile" then
          CM.DebugPrintThrottled("reticleTarget", "Mouseover friendly; fallback hostile unit: " .. fallbackUnitID)
          return fallbackUnitID, fallbackReactionType
        end
      end
    end

    CM.DebugPrintThrottled("reticleTarget", "Mouseover non-hostile in enemy-only combat mode; setting base appearance")
    return nil, nil
  end

  CM.DebugPrintThrottled("reticleTarget", "No unit under cursor, setting base appearance")
  return nil, nil
end

function CM.UpdateCrosshairReaction()
  if not CM.DB.char.reticleTargeting then
    return
  end
  if not CM.DB.global.crosshair or CM.HideCrosshairWhileMounted() then
    return
  end

  local hasFocus = UnitExists("focus")
  local currentUnit, currentReaction = GetUnitUnderCursor()

  local appearanceState
  if hasFocus then
    appearanceState = "focus"
  elseif currentUnit then
    appearanceState = currentReaction or "base"
  else
    appearanceState = "base"
  end

  if appearanceState ~= lastKnownAppearanceState then
    lastKnownAppearanceState = appearanceState
    SetCrosshairAppearance(appearanceState)
  end
end

---------------------------------------------------------------------------------------
--                            CROSSHAIR LOCK-IN ANIMATION                             --
---------------------------------------------------------------------------------------
local LOCK_IN_DURATION = 0.25
local LOCK_IN_STARTING_SCALE = 1.3
local LOCK_IN_STARTING_ALPHA = 0.0
local LOCK_IN_TOTAL_ELAPSED = -1
local LOCK_IN_TARGET_SCALE = 1.0
local LOCK_IN_TARGET_ALPHA = 1.0

local function UpdateCrosshairLockIn(_, elapsed)
  if LOCK_IN_TOTAL_ELAPSED == -1 then
    return
  end

  LOCK_IN_TOTAL_ELAPSED = LOCK_IN_TOTAL_ELAPSED + elapsed

  if LOCK_IN_TOTAL_ELAPSED >= LOCK_IN_DURATION then
    LOCK_IN_TOTAL_ELAPSED = -1
    CrosshairVisualFrame:SetScale(LOCK_IN_TARGET_SCALE)
    CrosshairVisualFrame:SetAlpha(LOCK_IN_TARGET_ALPHA)
    CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
    AdjustCenteredCursorYPos()
    return
  end

  local progress = LOCK_IN_TOTAL_ELAPSED / LOCK_IN_DURATION
  progress = math.max(0, math.min(1, progress))
  local easedProgress = 1 - (1 - progress) * (1 - progress)

  local currentScale = LOCK_IN_STARTING_SCALE + (LOCK_IN_TARGET_SCALE - LOCK_IN_STARTING_SCALE) * easedProgress
  currentScale = math.max(0.01, currentScale)
  CrosshairVisualFrame:SetScale(currentScale)

  local currentAlpha = LOCK_IN_STARTING_ALPHA + (LOCK_IN_TARGET_ALPHA - LOCK_IN_STARTING_ALPHA) * easedProgress
  CrosshairVisualFrame:SetAlpha(currentAlpha)
end

function CM.ShowCrosshairLockIn()
  if not CM.DB.global.crosshair or not CM.DB.char.reticleTargeting then
    return
  end

  CrosshairTexture:Show()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local configuredOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  local currentScale = CrosshairVisualFrame:GetScale()
  LOCK_IN_STARTING_SCALE = currentScale * 1.3
  LOCK_IN_STARTING_ALPHA = 0.0
  LOCK_IN_TARGET_SCALE = 1.0
  LOCK_IN_TARGET_ALPHA = configuredOpacity

  CrosshairVisualFrame:SetPoint("CENTER", CrosshairFrame, "CENTER", 0, 0)
  CrosshairVisualFrame:SetScale(LOCK_IN_STARTING_SCALE)
  CrosshairVisualFrame:SetAlpha(LOCK_IN_STARTING_ALPHA)

  LOCK_IN_TOTAL_ELAPSED = 0
end

CrosshairFrame:SetScript("OnUpdate", function(self, elapsed)
  UpdateCrosshairLockIn(self, elapsed)
end)

---------------------------------------------------------------------------------------
--              CORE HOOKS (REMATCH / EVENTS / DISABLE)                              --
---------------------------------------------------------------------------------------
function CM.OnRematchCrosshair()
  if CM.DB.global.crosshair then
    LOCK_IN_TOTAL_ELAPSED = -1
    CM.CreateCrosshair()
    if CM.HideCrosshairWhileMounted() then
      SetCrosshairAppearance("mounted")
    else
      CM.UpdateCrosshairReaction()
    end

    if CM.DB.char.stickyCrosshair then
      CM.ConfigStickyCrosshair("combatmode")
    end
    CM.DisplayCrosshair(IsMouselooking())
  elseif CM.DB.global.crosshair == false then
    CM.DisplayCrosshair(false)
  end
end

function CM.OnCrosshairUncategorizedEvent()
  if CM.HideCrosshairWhileMounted() then
    SetCrosshairAppearance("mounted")
    lastKnownAppearanceState = "mounted"
    if IsMouselooking() then
      CM.DisplayCrosshair(false)
    end
  else
    lastKnownAppearanceState = nil
    CM.UpdateCrosshairReaction()
    if IsMouselooking() then
      if CM.DB.global.crosshair then
        CM.DisplayCrosshair(true)
      else
        CM.DisplayCrosshair(false)
      end
    end
  end
end

function CM.OnCrosshairFocusLockEvent(event)
  if event == "PLAYER_FOCUS_CHANGED" then
    if UnitExists("focus") and IsMouselooking() then
      CM.ShowCrosshairLockIn()
    end
    CM.UpdateCrosshairReaction()
  end
end

function CM.HideCrosshairFrame()
  CrosshairFrame:Hide()
end
