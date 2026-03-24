---------------------------------------------------------------------------------------
--  Features/Pulse.lua — PULSE — brief cursor highlight after unlocking mouselook
---------------------------------------------------------------------------------------
--  When the player leaves free look (temporary or permanent unlock), optionally
--  plays a short atlas-based pulse at the cursor so the mouse position is easy to
--  spot. Invoked from Core.UnlockFreeLook paths when CM.DB.global.pulseCursor is on.
--
--  Architecture:
--    • CM.InitializeCursorPulse() from Core bootstrap; CM.ShowCursorPulse() called
--      from Core only (no Ace events in this file).
--    • Self-contained frame + OnUpdate; does not touch bindings or CVars.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local UIParent = _G.UIParent

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
  if PULSE_TOTAL_ELAPSED == -1 then return end

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
  PulseFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
    (cursorX / scale) - size / 2,
    (cursorY / scale) - size / 2)
end

function CM.ShowCursorPulse()
  PULSE_TOTAL_ELAPSED = 0
  PulseFrame:Show()
end

PulseFrame:SetScript("OnUpdate", UpdatePulse)
