---------------------------------------------------------------------------------------
--  Core/FreeLook/FlipCamera.lua — FREELOOK — Flip Camera keybind (tap to toggle, hold to peek)
---------------------------------------------------------------------------------------
--  What it does: Handler for the "Combat Mode - Flip Camera" binding (Bindings.xml, runOnUp).
--  Like the Mouse Look key, it works both ways: a tap flips the camera 180° around your
--  character and leaves it there (press again to flip back); holding the key flips it only while
--  held and flips back on release.
--  Architecture / how it works:
--    • CombatMode_FlipCameraKey("down") records the press time and calls FlipCameraYaw(180);
--      "up" flips back only when the key was held past the hold threshold (0.3s, same as the
--      Mouse Look key).
--    • FlipCameraYaw is Blizzard's own camera call (what the default Flip Camera binding runs);
--      it is wrapped in pcall so a client without it just does nothing.
--  Does not: Own the options control (UI/Options/Tabs/TabGeneral.lua), Mouse Look state, or any
--  camera CVar.
--  Related: Bindings.xml, Core/FreeLook/FreeLookController.lua, UI/Options/Tabs/TabGeneral.lua
---------------------------------------------------------------------------------------
local _, _ = ...
local _G = _G

-- WoW API
local FlipCameraYaw = _G.FlipCameraYaw
local GetTime = _G.GetTime

-- Lua stdlib
local pcall = _G.pcall

local HOLD_THRESHOLD = 0.3 -- seconds; matches CURSOR_MODE_HOLD_THRESHOLD in FreeLookController
local FLIP_DEGREES = 180

local pressedAt

local function Flip()
  if FlipCameraYaw then
    pcall(FlipCameraYaw, FLIP_DEGREES)
  end
end

function _G.CombatMode_FlipCameraKey(keystate)
  if keystate == "down" then
    pressedAt = GetTime()
    Flip()
  elseif keystate == "up" then
    if not pressedAt then
      return
    end
    local held = GetTime() - pressedAt
    pressedAt = nil
    if held >= HOLD_THRESHOLD then
      -- Hold: the flip was only for as long as the key was down.
      Flip()
    end
  end
end
