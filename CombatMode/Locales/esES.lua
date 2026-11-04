---------------------------------------------------------------------------------------
--  Locales/esES.lua — LOCALES — Spanish (Spain) strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the esES client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "esES", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "esES" then
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
  "|cff909090Para restaurar tus ajustes anteriores, usa el botón |cffff5555Desinstalar|r del panel de opciones.|r"
L["Mouse Look"] = "Vista con ratón"
L["Flip Camera"] = "Invertir cámara"
L["Swap Shoulder"] = "Cambiar hombro"
L["Reset Mouse Look"] = "Restablecer vista con ratón"
L["Ally Cycle Next"] = "Ciclo de aliados: siguiente"
L["Ally Cycle Previous"] = "Ciclo de aliados: anterior"
L["Toggle Focus Target"] = "Alternar objetivo de foco"
L["Cycle Focus Next"] = "Ciclo de foco: siguiente"
L["Cycle Focus Previous"] = "Ciclo de foco: anterior"
L["Radial Menu"] = "Menú radial"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "cambio de asignación de teclas"
L["deferred %s until combat ends."] = "%s aplazado hasta que termine el combate."
L["failed to apply %s: %s"] = "no se pudo aplicar %s: %s"
L["applied deferred binding updates."] = "se aplicaron las asignaciones de teclas aplazadas."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50¡%s detectado!|r Se le cede la velocidad de giro, el hombro y la inclinación dinámica."
L["Cannot uninstall while in combat."] = "No se puede desinstalar en combate."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "se restauraron tus ajustes anteriores de cámara y selección de objetivo y las asignaciones predeterminadas de la cámara con ratón; el addon se ha desactivado."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Escribe |cff69ccf0/acm|r o |cff69ccf0/actioncombatmode|r para abrir los ajustes."
L["camera and targeting CVars restored."] =
  "se restauraron las CVars de cámara y selección de objetivo."
L["Cannot open settings while in combat."] = "No se puede abrir la configuración en combate."
L["Cannot open this editor while in combat."] = "No se puede abrir este editor en combate."
L["Cannot open editor while in combat."] = "No se puede abrir el editor en combate."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "no se pueden editar las CVars de la selección de objetivo con retícula en combate."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "no se pueden restablecer las CVars de la selección de objetivo con retícula en combate."
L["MOVEANDSTEER unbind"] = "desasignar MOVEANDSTEER"
L["restore default mouse camera bindings"] =
  "restaurar las asignaciones predeterminadas de la cámara con ratón"
L["Minimum Zoom"] = "Zoom mínimo"
L["ally cycle bindings"] = "asignaciones del ciclo de aliados"
L["radial menu"] = "menú radial"
L["target lock keybinding"] = "asignación de fijar objetivo"
L["cycle focus next keybinding"] = "asignación de ciclo de foco: siguiente"
L["cycle focus previous keybinding"] = "asignación de ciclo de foco: anterior"
L["ally cycle next keybinding"] = "asignación de ciclo de aliados: siguiente"
L["ally cycle previous keybinding"] = "asignación de ciclo de aliados: anterior"
L["radial menu keybinding"] = "asignación del menú radial"
L["reticle interact keybinding"] = "asignación de interacción con retícula"
L["mouse look keybinding"] = "asignación de vista con ratón"
L["flip camera keybinding"] = "asignación de invertir cámara"
L["reset mouse look keybinding"] = "asignación de restablecer vista con ratón"
L["swap shoulder keybinding"] = "asignación de cambiar hombro"
