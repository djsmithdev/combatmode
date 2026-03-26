---------------------------------------------------------------------------------------
--  Features/Animations.lua — USER-FACING ANIMATIONS — cursor pulse, crosshair motion
---------------------------------------------------------------------------------------
--  Consolidates short, purely visual animations that are triggered by other systems:
--    • Cursor pulse: brief atlas pulse at the cursor after unlocking mouselook.
--    • Crosshair reaction: scale animation and appearance application (shared with Edit Mode preview).
--    • Crosshair lock-in: short scale/alpha tween when acquiring focus target.
--
--  Animation targets (frames/textures) are registered by their owning feature modules.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local IsMouselooking = _G.IsMouselooking
local UIParent = _G.UIParent

-- Lua stdlib
local math = _G.math
local unpack = _G.unpack

---------------------------------------------------------------------------------------
--                                   CURSOR PULSE                                   --
---------------------------------------------------------------------------------------
local PULSE_DURATION = 0.4
local PULSE_STARTING_ALPHA = 0.5
local PULSE_STARTING_SIZE = 256
local PULSE_TOTAL_ELAPSED = -1

local PulseFrame = CreateFrame("Frame", nil, UIParent)
local PulseTexture = PulseFrame:CreateTexture(nil, "BACKGROUND")

function CM.InitializeCursorPulse()
  PulseFrame:SetSize(0, 0)
  PulseFrame:Hide()
  PulseTexture:SetAtlas(CM.Constants.PulseAtlas, true)
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
  if previewMode or (state ~= "mounted" and IsMouselooking()) then
    targetTexture:Show()
  end
  animGroup:Play(reverseAnimation)
  if state == "base" then
    targetFrame:SetScale(STARTING_SCALE)
    targetFrame:SetPoint("CENTER", parent, "CENTER", 0, verticalOffset)
  end
end

CM.ApplyCrosshairAppearanceToWidget = ApplyCrosshairAppearanceToWidget

---------------------------------------------------------------------------------------
--                            CROSSHAIR LOCK-IN ANIMATION                             --
---------------------------------------------------------------------------------------
local LOCK_IN_DURATION = 0.25
local LOCK_IN_STARTING_SCALE = 1.3
local LOCK_IN_STARTING_ALPHA = 0.0
local LOCK_IN_TOTAL_ELAPSED = -1
local LOCK_IN_TARGET_SCALE = 1.0
local LOCK_IN_TARGET_ALPHA = 1.0

local crosshairOuterFrame
local crosshairVisualFrame
local crosshairTexture
local onCrosshairLockInComplete

function CM.InitCrosshairAnimations(opts)
  if not opts then
    return
  end

  crosshairOuterFrame = opts.outerFrame
  crosshairVisualFrame = opts.visualFrame
  crosshairTexture = opts.texture
  onCrosshairLockInComplete = opts.onLockInComplete

  if crosshairOuterFrame and crosshairOuterFrame.SetScript then
    crosshairOuterFrame:SetScript("OnUpdate", function(_, elapsed)
      if LOCK_IN_TOTAL_ELAPSED == -1 then
        return
      end

      LOCK_IN_TOTAL_ELAPSED = LOCK_IN_TOTAL_ELAPSED + elapsed

      if LOCK_IN_TOTAL_ELAPSED >= LOCK_IN_DURATION then
        LOCK_IN_TOTAL_ELAPSED = -1
        if crosshairVisualFrame then
          crosshairVisualFrame:SetScale(LOCK_IN_TARGET_SCALE)
          crosshairVisualFrame:SetAlpha(LOCK_IN_TARGET_ALPHA)
          crosshairVisualFrame:SetPoint("CENTER", crosshairOuterFrame, "CENTER", 0, 0)
        end
        if onCrosshairLockInComplete then
          onCrosshairLockInComplete()
        end
        return
      end

      local progress = LOCK_IN_TOTAL_ELAPSED / LOCK_IN_DURATION
      progress = math.max(0, math.min(1, progress))
      local easedProgress = 1 - (1 - progress) * (1 - progress)

      local currentScale = LOCK_IN_STARTING_SCALE
        + (LOCK_IN_TARGET_SCALE - LOCK_IN_STARTING_SCALE) * easedProgress
      currentScale = math.max(0.01, currentScale)
      if crosshairVisualFrame then
        crosshairVisualFrame:SetScale(currentScale)
      end

      local currentAlpha = LOCK_IN_STARTING_ALPHA
        + (LOCK_IN_TARGET_ALPHA - LOCK_IN_STARTING_ALPHA) * easedProgress
      if crosshairVisualFrame then
        crosshairVisualFrame:SetAlpha(currentAlpha)
      end
    end)
  end
end

function CM.CancelCrosshairLockIn()
  LOCK_IN_TOTAL_ELAPSED = -1
end

function CM.ShowCrosshairLockIn()
  if not (CM.IsCrosshairEnabled and CM.IsCrosshairEnabled()) then
    return
  end
  if not (crosshairOuterFrame and crosshairVisualFrame and crosshairTexture) then
    return
  end

  crosshairTexture:Show()
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global or {}
  local configuredOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  local currentScale = crosshairVisualFrame:GetScale()
  LOCK_IN_STARTING_SCALE = currentScale * 1.3
  LOCK_IN_STARTING_ALPHA = 0.0
  LOCK_IN_TARGET_SCALE = 1.0
  LOCK_IN_TARGET_ALPHA = configuredOpacity

  crosshairVisualFrame:SetPoint("CENTER", crosshairOuterFrame, "CENTER", 0, 0)
  crosshairVisualFrame:SetScale(LOCK_IN_STARTING_SCALE)
  crosshairVisualFrame:SetAlpha(LOCK_IN_STARTING_ALPHA)

  LOCK_IN_TOTAL_ELAPSED = 0
end
