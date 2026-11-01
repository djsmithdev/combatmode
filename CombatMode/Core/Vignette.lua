---------------------------------------------------------------------------------------
--  Core/Vignette.lua — RUNTIME — Vignette screen edge darkening
---------------------------------------------------------------------------------------
--  What it does: Creates a full-screen vignette overlay (darkened edges) using
--  Blizzard's Artifacts-BG-Shadow atlas at BACKGROUND strata with 60% opacity.
--  Shown while the conditions picked in CM.DB.global.vignetteConditions (CSV of mouselook |
--  combat | interaction; empty = off) hold, combined by vignetteMatch ("any" | "all").
--    mouselook   = CM.IsMouseLookCameraChromeActive (visible while locked and through temp
--                  unlock; ends only on permanent unlock)
--    combat      = UnitAffectingCombat("player")
--    interaction = an NPC window is open (PLAYER_INTERACTION_MANAGER_FRAME_SHOW / _HIDE,
--                  routed by EventRouter into CM.OnVignetteInteractionEvent)
--  Fade duration shared with shoulder via Constants.MouseLookCameraFadeDuration.
--  Architecture / how it works:
--    • Frame parented to UIParent at BACKGROUND strata, non-interactive.
--    • Resolves the shipped atlas via CM.GetAtlasInfo then applies via
--      SetTexture(FileID) + SetTexCoord — the canonical equivalent of SetAtlas
--      but with explicit control over the region and screen sizing.
--    • InitializeVignette() called from Bootstrap on startup.
--    • ApplyVignette() re-evaluates vignette and reconfigures the OnUpdate script.
--      When enabled, the frame stays shown so OnUpdate fires every frame (WoW does
--      not run OnUpdate on hidden frames) and tweens alpha against camera chrome
--      — "faded out" is alpha 0, not Hide(). When disabled, the frame is hidden.
--    • SetVignetteConditions(csv) / SetVignetteMatch(mode) update DB and re-apply from options.
--  Does not: Own any UI chrome, options tab wiring, or event handlers.
--  Related: Core/Runtime/Bootstrap.lua, UI/Options/Tabs/TabGeneral.lua,
--  Constants/DatabaseDefaults.lua, Core/FreeLook/FreeLookController.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat
local C_PlayerInteractionManager = _G.C_PlayerInteractionManager

-- Lua stdlib
local math = _G.math
local min = math.min

local VIGNETTE_ATLAS = "Artifacts-BG-Shadow"
local VIGNETTE_OPACITY = 0.6

local function VignetteFadeDuration()
  return (CM.Constants and CM.Constants.MouseLookCameraFadeDuration) or 0.35
end

local vignetteFrame
local vignetteTexture
local vignetteEnabled = false
local chromeActive = false
local currentAlpha = 0
local fadeActive = false
local fadeFromAlpha = 0
local fadeToAlpha = 0
local fadeElapsed = 0

-- Open NPC windows by PLAYER_INTERACTION_MANAGER type (a set, so a repeated SHOW is harmless).
local openInteractions = {}

local CONDITION_TESTS = {
  mouselook = function()
    return CM.IsMouseLookCameraChromeActive and CM.IsMouseLookCameraChromeActive() == true
  end,
  combat = function()
    return UnitAffectingCombat("player") == true
  end,
  interaction = function()
    -- FRAME_HIDE doesn't reliably follow every FRAME_SHOW (replaced or never-hidden windows),
    -- so each tracked type is re-checked against the live state and dropped once it's gone.
    local manager = C_PlayerInteractionManager
    for interactionType in pairs(openInteractions) do
      if not (manager and manager.IsInteractingWithNpcOfType(interactionType)) then
        openInteractions[interactionType] = nil
      end
    end
    return next(openInteractions) ~= nil
  end,
}

-- Selected conditions as a list, re-parsed only when the saved CSV string changes.
local parsedCsv, parsedList = nil, {}

local function SelectedConditions()
  local csv = CM.DB.global.vignetteConditions
  if csv ~= parsedCsv then
    parsedCsv = csv
    parsedList = {}
    for key in (type(csv) == "string" and csv or ""):gmatch("[^,]+") do
      if CONDITION_TESTS[key] then
        parsedList[#parsedList + 1] = key
      end
    end
  end
  return parsedList
end

--- True when the vignette should be visible: nothing selected = never; "any" = at least one
--- selected condition holds; "all" = every selected condition holds.
local function IsChromeActive()
  local list = SelectedConditions()
  if #list == 0 then
    return false
  end
  local matchAll = CM.DB.global.vignetteMatch == "all"
  for i = 1, #list do
    local holds = CONDITION_TESTS[list[i]]()
    if matchAll and not holds then
      return false
    elseif not matchAll and holds then
      return true
    end
  end
  return matchAll
end

local function TargetAlpha()
  return chromeActive and VIGNETTE_OPACITY or 0
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
  -- React to permanent lock/unlock (chrome), not temp hold-to-unlock.
  local nowActive = IsChromeActive()
  if nowActive ~= chromeActive then
    chromeActive = nowActive
    StartFadeTo(TargetAlpha())
  end
  if not fadeActive then
    return
  end
  fadeElapsed = fadeElapsed + elapsed
  local t = min(1, fadeElapsed / VignetteFadeDuration())
  currentAlpha = fadeFromAlpha + (fadeToAlpha - fadeFromAlpha) * t
  vignetteTexture:SetAlpha(currentAlpha)
  if t >= 1 then
    fadeActive = false
  end
end

local function ApplyVignette()
  local g = CM.DB and CM.DB.global
  vignetteEnabled = g ~= nil and #SelectedConditions() > 0
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
  chromeActive = IsChromeActive()
  currentAlpha = TargetAlpha()
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

  local info = CM.GetAtlasInfo(VIGNETTE_ATLAS)
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

--- Tracks NPC windows for the "interaction" condition (routed by EventRouter).
function CM.OnVignetteInteractionEvent(event, interactionType)
  if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    if interactionType and interactionType ~= 0 then
      openInteractions[interactionType] = true
    end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if interactionType then
      openInteractions[interactionType] = nil
    end
  else
    openInteractions = {}
  end
end

--- Saves the selected conditions (CSV of mouselook | combat | interaction) and re-applies.
function CM.SetVignetteConditions(csv)
  CM.DB.global.vignetteConditions = csv or ""
  ApplyVignette()
end

--- Saves the match mode ("any" | "all") and re-applies.
function CM.SetVignetteMatch(mode)
  CM.DB.global.vignetteMatch = mode == "all" and "all" or "any"
  ApplyVignette()
end
