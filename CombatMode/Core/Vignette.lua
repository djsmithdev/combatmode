---------------------------------------------------------------------------------------
--  Core/Vignette.lua — RUNTIME — Vignette screen edge darkening
---------------------------------------------------------------------------------------
--  What it does: Creates a full-screen vignette overlay (darkened edges) using
--  Blizzard's Artifacts-BG-Shadow atlas at BACKGROUND strata with 60% opacity.
--  Toggled on/off via CM.DB.global.vignette.
--  Architecture / how it works:
--    • Frame parented to UIParent at BACKGROUND strata, non-interactive.
--    • Resolves the atlas via C_Texture.GetAtlasInfo then applies via
--      SetTexture(FileID) + SetTexCoord — the canonical equivalent of SetAtlas
--      but with explicit control over the region and screen sizing.
--    • InitializeVignette() called from Bootstrap on startup.
--    • SetVignetteEnabled(value) toggles show/hide at runtime from options.
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

local VIGNETTE_ATLAS = "Artifacts-BG-Shadow"
local VIGNETTE_OPACITY = 0.6

local vignetteFrame

function CM.InitializeVignette()
  if vignetteFrame then
    return
  end

  vignetteFrame = CreateFrame("Frame", nil, UIParent)
  vignetteFrame:SetFrameStrata("BACKGROUND")
  vignetteFrame:SetAllPoints(UIParent)
  vignetteFrame:EnableMouse(false)

  local tex = vignetteFrame:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(vignetteFrame)

  local info = C_Texture.GetAtlasInfo(VIGNETTE_ATLAS)
  if info and info.file then
    tex:SetTexture(info.file)
    tex:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
  end
  tex:SetAlpha(VIGNETTE_OPACITY)

  if CM.DB.global.vignette then
    vignetteFrame:Show()
  end
end

function CM.SetVignetteEnabled(enabled)
  CM.DB.global.vignette = enabled == true
  if vignetteFrame then
    if CM.DB.global.vignette then
      vignetteFrame:Show()
    else
      vignetteFrame:Hide()
    end
  end
end
