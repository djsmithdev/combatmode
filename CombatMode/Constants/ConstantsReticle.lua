---------------------------------------------------------------------------------------
--  Constants/ConstantsReticle.lua — constants module: reticle
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- Texture file IDs / paths for "unable" interact cursor (dim + grey name).
CM.Constants.InteractionHUDUnableCursor = {
  ["4675695"] = true,
  ["4675705"] = true,
  ["4675693"] = true,
  ["4675702"] = true,
  ["4675694"] = true,
  ["4675720"] = true,
  ["4675725"] = true,
  ["4675677"] = true
}
