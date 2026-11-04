---------------------------------------------------------------------------------------
--  Locales/esMX.lua — LOCALES — Spanish (Mexico) strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the esMX client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "esMX", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "esMX" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "¡Bienvenido a Action Combat Mode!"
L["The configuration panel will open after you close this message."] =
  "El panel de configuración se abrirá cuando cierres este mensaje."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Puedes volver a abrirlo en cualquier momento con |cff69ccf0/acm|r o |cff69ccf0/actioncombatmode|r."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Para restaurar tu configuración anterior, usa el botón |cffff5555Desinstalar|r del panel de opciones.|r"
L["Mouse Look"] = "Vista con mouse"
L["Flip Camera"] = "Invertir cámara"
L["Swap Shoulder"] = "Cambiar hombro"
L["Reset Mouse Look"] = "Restablecer vista con mouse"
L["Ally Cycle Next"] = "Ciclo de aliados: siguiente"
L["Ally Cycle Previous"] = "Ciclo de aliados: anterior"
L["Toggle Focus Target"] = "Alternar objetivo de foco"
L["Cycle Focus Next"] = "Ciclo de foco: siguiente"
L["Cycle Focus Previous"] = "Ciclo de foco: anterior"
L["Radial Menu"] = "Menú radial"
