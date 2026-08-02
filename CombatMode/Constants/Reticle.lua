---------------------------------------------------------------------------------------
--  Constants/Reticle.lua — CONSTANTS — Interaction HUD unable-cursor texture ids
---------------------------------------------------------------------------------------
--  What it does: Sets InteractionHUDUnableCursor — file-id / path keys that mark the
--  soft-interact cursor as "unable" so Interaction HUD can dim the icon while keeping
--  the name label color.
--  Architecture / how it works:
--    • Lookup table keyed by texture file id strings (and path substring "Unable" is
--      also checked at runtime in InteractionHUD/Target.lua).
--  Does not: Own SoftTarget CVars, the HUD widget, or crosshair reaction state.
--  Related: Core/Crosshair/InteractionHUD/Target.lua, Constants/CVars.lua,
--  UI/Options/Tabs/TabCrosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...

-- Texture file IDs / paths for "unable" interact cursor (dim icon, label color unchanged).
CM.Constants.InteractionHUDUnableCursor = {
  ["4675695"] = true,
  ["4675705"] = true,
  ["4675693"] = true,
  ["4675702"] = true,
  ["4675694"] = true,
  ["4675720"] = true,
  ["4675725"] = true,
  ["4675677"] = true,
}
