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

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "VISTA CON RATÓN"
L["CAMERA FEATURES"] = "FUNCIONES DE CÁMARA"
L["ADDITIONAL FEATURES"] = "FUNCIONES ADICIONALES"
L["Crosshair - More accurate"] = "Punto de mira: más preciso"
L["Soft Target - More forgiving"] = "Objetivo suave: más permisivo"
L["Mouse Look is on"] = "La vista con ratón está activa"
L["In combat"] = "En combate"
L["Talking to an NPC"] = "Hablando con un PNJ"
L["Any checked"] = "Cualquiera marcada"
L["All checked"] = "Todas las marcadas"
L["Off"] = "Desactivado"
L["Control relinquished to %s"] = "Control cedido a %s"
L["Disabled while Motion Sickness Protection is on"] =
  "Desactivado mientras la protección contra el mareo esté activada"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Fija el cursor en la posición de la mira y dirige moviendo el ratón sin mantener el clic derecho."
L["Mouse Look Keybind"] = "Tecla de vista con ratón"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Pulsa para alternar la vista con ratón. Mantén pulsado para liberar el cursor temporalmente."
L["Interact Keybind"] = "Tecla de interacción"
L["Tap to interact with a player or the unit chosen below."] =
  "Pulsa para interactuar con un jugador o con la unidad elegida abajo."
L["Players"] = "Jugadores"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Apunta a un jugador durante un segundo y el HUD de asistencia mostrará un aviso. Pulsa entonces la tecla para abrir su menú contextual."
L["NPCs and objects"] = "PNJ y objetos"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Interactúa como de costumbre con la unidad elegida en «Unidad de interacción»."
L["Interact Unit"] = "Unidad de interacción"
L["Which unit will be interacted with when the key is pressed."] =
  "Con qué unidad se interactuará al pulsar la tecla."
L["Flip Camera Keybind"] = "Tecla de girar cámara"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Pulsa para girar la cámara 180° alrededor de tu personaje. Mantén pulsado para girarla solo mientras se mantenga la tecla."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Recupera un cursor atascado tras cambiar de ventana en macOS. Vuelve a capturar y libera la vista con ratón para eliminar una captura que el juego dejó bloqueada en segundo plano."
L["Curated camera adjustments for a more action-focused experience."] =
  "Ajustes de cámara seleccionados para una experiencia más centrada en la acción."
L["Motion Sickness Protection"] = "Protección contra el mareo"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Evita que Action Combat Mode anule los ajustes de mareo de Blizzard."
L["Turn Speed"] = "Velocidad de giro"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Controla la rapidez con que gira la cámara al usar la vista con ratón."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Impide que la cámara se acerque más que esta distancia. 0 la desactiva."
L["Dynamic Pitch"] = "Inclinación dinámica"
L["Dynamically tilt the camera up and down as you move it."] =
  "Inclina la cámara dinámicamente hacia arriba y abajo al moverla."
L["Pitch Strength"] = "Intensidad de inclinación"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Cuánto inclina la cámara la inclinación dinámica. Los valores bajos mantienen a tu personaje más arriba en pantalla. Al volar se inclina más y escala con este valor."
L["Shoulder Offset"] = "Desplazamiento de hombro"
L["Camera's horizontal position relative to the character."] =
  "Posición horizontal de la cámara respecto al personaje."
L["Disable Offset With Mouselook"] = "Desactivar desplazamiento con vista con ratón"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "El desplazamiento de hombro vuelve suavemente a 0 al desactivar la vista con ratón."
L["When off, Shoulder Offset stays constant at all times."] =
  "Si está desactivado, el desplazamiento de hombro se mantiene constante en todo momento."
L["Swap Shoulder Keybind"] = "Tecla de cambio de hombro"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Pulsa para reflejar el desplazamiento de hombro al otro lado de tu personaje."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Funciones adicionales ligadas al comportamiento de la vista con ratón."
L["Cursor Pulse"] = "Pulso del cursor"
L["Flash the cursor when Mouse Look is turned off."] =
  "Hace parpadear el cursor al desactivar la vista con ratón."
L["Hide Tooltips"] = "Ocultar descripciones emergentes"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Oculta las descripciones emergentes mientras la vista con ratón esté activa, salvo que se mantenga la tecla de abajo."
L["Show Tooltips With"] = "Mostrar descripciones con"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Mantén esta tecla para mostrar las descripciones emergentes mientras la vista con ratón esté activa."
L["Auto Sheath"] = "Envainar automáticamente"
L["Sheath weapons automatically with Mouse Look."] =
  "Envaina las armas automáticamente junto con la vista con ratón."
L["Vignette Shows When"] = "La viñeta se muestra cuando"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Oscurece los bordes de la pantalla mientras se cumplan las situaciones marcadas."
L["Vignette Match"] = "Coincidencia de viñeta"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "Cualquiera: basta con una situación marcada. Todas: deben cumplirse a la vez todas las situaciones marcadas."
