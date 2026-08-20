---------------------------------------------------------------------------------------
--  Core/Vignette.lua — RUNTIME — Vignette screen edge darkening
---------------------------------------------------------------------------------------
--  What it does: Creates a full-screen vignette overlay (darkened edges) using
--  Blizzard's Artifacts-BG-Shadow atlas at BACKGROUND strata with 60% opacity.
--  Toggled on/off via CM.DB.global.vignette. When vignetteFadeWithMouselook is ON
--  (default), the vignette fades in/out with CM's mouselook state. When OFF, the
--  vignette stays at full opacity at all times.
--  Architecture / how it works:
--    • Frame parented to UIParent at BACKGROUND strata, non-interactive.
--    • Resolves the atlas via C_Texture.GetAtlasInfo then applies via
--      SetTexture(FileID) + SetTexCoord — the canonical equivalent of SetAtlas
--      but with explicit control over the region and screen sizing.
--    • InitializeVignette() called from Bootstrap on startup.
--    • ApplyVignette() re-evaluates the enabled flag and reconfigures the
--      OnUpdate script. When enabled, the frame stays shown at all times so
--      OnUpdate fires every frame (WoW does not run OnUpdate on hidden frames)
--      and tweens alpha against CM.IsMouselooking() state (CM's own intentional
--      mouselook, not Blizzard's raw IsMouselooking which also fires on right-click-drag
--      camera turn) — "faded out" is alpha 0, not Hide(). When disabled, the frame is
--      hidden with no script.
--    • SetVignetteEnabled(value) updates DB and re-applies from options.
--  Does not: Own any UI chrome, options tab wiring, or event handlers.
--  Related: Core/Runtime/Bootstrap.lua, UI/Options/Tabs/TabCamera.lua,
--  Constants/DatabaseDefaults.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Texture = _G.C_Texture
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent

-- Lua stdlib
local math = _G.math
local min = math.min

local VIGNETTE_ATLAS = "Artifacts-BG-Shadow"
local VIGNETTE_OPACITY = 0.6
local VIGNETTE_FADE_DURATION = 0.35

local vignetteFrame
local vignetteTexture
local vignetteEnabled = false
local mouselooking = false
local currentAlpha = 0
local fadeActive = false
local fadeFromAlpha = 0
local fadeToAlpha = 0
local fadeElapsed = 0

local function TargetAlpha()
  if not CM.DB.global.vignetteFadeWithMouselook then
    return VIGNETTE_OPACITY
  end
  return mouselooking and VIGNETTE_OPACITY or 0
end

local function StartFadeTo(target)
  if currentAlpha == target then
    fadeActive = false
    return
  end
  fadeFromAlpha = currentAlpha
  fadeToAlpha = target
  fadeElapsed = 0
  fadeActive = true
end

local function VignetteOnUpdate(_, elapsed)
  -- React to Mouse Look toggles.
  local nowLooking = CM.IsMouselooking()
  if nowLooking ~= mouselooking then
    mouselooking = nowLooking
    StartFadeTo(TargetAlpha())
  end
  if not fadeActive then
    return
  end
  fadeElapsed = fadeElapsed + elapsed
  local t = min(1, fadeElapsed / VIGNETTE_FADE_DURATION)
  currentAlpha = fadeFromAlpha + (fadeToAlpha - fadeFromAlpha) * t
  vignetteTexture:SetAlpha(currentAlpha)
  if t >= 1 then
    fadeActive = false
  end
end

local function ApplyVignette()
  vignetteEnabled = CM.DB.global.vignette == true
  if not vignetteFrame then
    return
  end
  if not vignetteEnabled then
    vignetteFrame:SetScript("OnUpdate", nil)
    vignetteFrame:Hide()
    currentAlpha = 0
    fadeActive = false
    return
  end
  -- Keep the frame shown so OnUpdate fires every frame (WoW does not run OnUpdate
  -- on hidden frames); "faded out" is expressed as alpha 0.
  mouselooking = CM.IsMouselooking()
  currentAlpha = mouselooking and VIGNETTE_OPACITY or 0
  -- When fade is disabled, show full opacity regardless of mouselook.
  if not CM.DB.global.vignetteFadeWithMouselook then
    currentAlpha = VIGNETTE_OPACITY
  end
  vignetteTexture:SetAlpha(currentAlpha)
  fadeActive = false
  vignetteFrame:Show()
  vignetteFrame:SetScript("OnUpdate", VignetteOnUpdate)
end

function CM.InitializeVignette()
  if vignetteFrame then
    return
  end

  vignetteFrame = CreateFrame("Frame", "CombatModeVignetteFrame", UIParent)
  vignetteFrame:SetFrameStrata("BACKGROUND")
  vignetteFrame:SetAllPoints(UIParent)
  vignetteFrame:EnableMouse(false)

  vignetteTexture = vignetteFrame:CreateTexture(nil, "ARTWORK")
  vignetteTexture:SetAllPoints(vignetteFrame)

  local info = C_Texture.GetAtlasInfo(VIGNETTE_ATLAS)
  if info and info.file then
    vignetteTexture:SetTexture(info.file)
    vignetteTexture:SetTexCoord(
      info.leftTexCoord,
      info.rightTexCoord,
      info.topTexCoord,
      info.bottomTexCoord
    )
  end

  ApplyVignette()
end

function CM.SetVignetteEnabled(enabled)
  CM.DB.global.vignette = enabled == true
  ApplyVignette()
end
