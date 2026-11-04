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

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Cualquier objetivo fijo"
L["Locked Target Only"] = "Solo objetivo fijado"
L["Soft Target (Blizzard)"] = "Objetivo suave (Blizzard)"
L["Hidden"] = "Oculto"
L["Toggle"] = "Alternar"
L["Switch Target"] = "Cambiar objetivo"
L["A UI Reload is required when making this change. Proceed?"] =
  "Esta modificación requiere recargar la interfaz. ¿Continuar?"
L["Create New Macro"] = "Crear macro nueva"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Escribe una macro que empiece con tu prelínea de Selección por retícula."
L["Unavailable in combat."] = "No disponible en combate."
L["Drag to a button on your action bars to use."] =
  "Arrástrala a un botón de tus barras de acción para usarla."
L["Right-click to edit"] = "Clic derecho para editar"
L["+%d more in /macro"] = "+%d más en /macro"
L["Reticle Targeting Macros"] = "Macros de selección por retícula"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "Los botones de acción que son macros no heredan automáticamente la lógica de Selección por retícula. Para que la sigan, créalos con la herramienta Compositor de macros y luego arrástralos a tus barras."
L["Reticle Targeting"] = "Selección por retícula"
L["RETICLE TARGETING"] = "SELECCIÓN POR RETÍCULA"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Permite seleccionar unidades apuntando y colocar con precisión hechizos de suelo y habilidades de área."
L["Enable Reticle Targeting"] = "Activar selección por retícula"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Apunta la mira a las unidades para elegir objetivos en lugar de usar el tabulador."
L["Ignore Friendlies"] = "Ignorar amistosos"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Ignora PNJ y jugadores amistosos y selecciona solo unidades hostiles."
L["Click Casting Only"] = "Solo lanzamiento por clic"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "Aplica la lógica de selección por retícula solo a las asignaciones de lanzamiento por clic."
L["Excluded Spells"] = "Hechizos excluidos"
L["Spells to skip the reticle targeting logic."] =
  "Hechizos que omiten la lógica de selección por retícula."
L["Cast at Crosshair"] = "Lanzar en la mira"
L["Ground spells to cast at the crosshair location."] =
  "Hechizos de suelo que se lanzan en la posición de la mira."
L["TARGET LOCK"] = "FIJAR OBJETIVO"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Fija un objetivo para evitar cambios accidentales y alterna entre unidades para priorizar enemigos concretos."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Advertencia: Fijar objetivo usa tu objetivo en foco. Cualquier otra cosa que cambie tu foco interferirá con ella."
L["Target Lock Keybind"] = "Tecla de fijar objetivo"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Fija la mira en un objetivo e impide que cambie."
L["Cycle Lock - Next"] = "Alternar fijación: siguiente"
L["Move Target Lock to the next valid nearby target."] =
  "Mueve la fijación al siguiente objetivo válido cercano."
L["Cycle Lock - Previous"] = "Alternar fijación: anterior"
L["Move Target Lock to the previous valid nearby target."] =
  "Mueve la fijación al objetivo válido cercano anterior."
L["Target Lock Behavior"] = "Comportamiento de fijar objetivo"
L["What the Target Lock key does when you press it."] =
  "Qué hace la tecla de fijar objetivo al pulsarla."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Fija tu objetivo o la unidad bajo la mira. Vuelve a pulsar para soltarla."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Fija la unidad bajo la mira y sustituye cualquier fijación actual. Pulsa sin nada bajo la mira para soltarla. Apuntar a la unidad ya fijada mantiene la fijación."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Con «Ignorar amistosos» activado, se ignora una unidad amistosa o muerta bajo la mira: la fijación se queda donde está."
L["Auto Target Lock"] = "Fijar objetivo automáticamente"
L["Target Lock engages automatically when attacking units."] =
  "Fijar objetivo se activa automáticamente al atacar unidades."
L["Target Lock Marker"] = "Marcador de fijación"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Muestra una marca de mira en la placa de nombre del objetivo fijado."
L["Focus Locked Target"] = "Enfocar objetivo fijado"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Atrae la cámara hacia tu objetivo fijado para mantenerlo enfocado."
L["TARGETING INDICATORS"] = "INDICADORES DE OBJETIVO"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Indicadores visuales que resaltan los objetivos en el mundo para identificarlos mejor."
L["Target Outline"] = "Contorno del objetivo"
L["Show an outline effect on your target."] = "Muestra un efecto de contorno en tu objetivo."
L["Only available on Retail"] = "Solo disponible en Retail"
L["Selection Circle"] = "Círculo de selección"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "Qué objetivo recibe el círculo de selección de Blizzard bajo sus pies."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "El círculo bajo cualquier objetivo que tengas, enemigo o amistoso."
L["The circle only under your Target Lock."] = "El círculo solo bajo tu objetivo fijado."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Deja que Blizzard controle el comportamiento de ObjectSelectionCircle y UnitNameFocused."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "Blizzard elige el objetivo suave dentro de un arco frente al modelo de tu personaje. No tiene en cuenta la posición de la mira ni el desplazamiento de hombro."
L["No selection circle."] = "Sin círculo de selección."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Mira"
L["CROSSHAIR"] = "MIRA"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Una mira dinámica que reacciona a los objetivos y a los estados de combate, mejora la precisión y guía la selección por retícula."
L["Enable Crosshair"] = "Activar mira"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Muestra en pantalla una mira dinámica y reactiva mientras estés en vista con ratón."
L["Cast Feedback"] = "Respuesta al lanzar"
L["Crosshair provides visual feedback while casting."] =
  "La mira ofrece respuesta visual mientras lanzas."
L["Appearance"] = "Apariencia"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Texturas que usa la mira en cada estado. Haz clic en una para elegir su textura o parte de un preajuste."
L["Inactive"] = "Inactiva"
L["Active"] = "Activa"
L["Mounted"] = "Montado"
L["Disabled"] = "Desactivada"
L["Reaction Colors"] = "Colores de reacción"
L["Edit"] = "Editar"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Personaliza los colores que usa la mira al apuntar a distintos tipos de unidades."
L["Scale"] = "Escala"
L["Scales the size of the crosshair."] = "Escala el tamaño de la mira."
L["Vertical Position"] = "Posición vertical"
L["Move the crosshair up or down from screen center."] =
  "Mueve la mira hacia arriba o abajo desde el centro de la pantalla."
L["ASSIST HUD"] = "HUD DE ASISTENCIA"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "Un HUD que guía la rotación de hechizos al apuntar a enemigos y muestra avisos de interacción."
L["Next-cast Suggestion"] = "Sugerencia del próximo hechizo"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Muestra la sugerencia del próximo hechizo del resaltado asistido mientras apuntas a un objetivo."
L["Always"] = "Siempre"
L["Only In Combat"] = "Solo en combate"
L["Interactable Indicator"] = "Indicador de interacción"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Muestra un indicador mientras apuntas a una unidad u objeto con el que se puede interactuar."
L["Player Interaction Prompt"] = "Aviso de interacción con jugadores"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Muestra un indicador al apuntar a un jugador durante un segundo. Al pulsar la tecla de interacción se abre su menú contextual."
L["Position"] = "Posición"
L["Which side of the crosshair the HUD appears on."] = "En qué lado de la mira aparece el HUD."
L["Left"] = "Izquierda"
L["Right"] = "Derecha"
L["Scales the size of the HUD."] = "Escala el tamaño del HUD."
L["Distance"] = "Distancia"
L["Distance between the HUD and the crosshair."] = "Distancia entre el HUD y la mira."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Acciones de Blizzard modificadas"
L["Blizzard Actions"] = "Acciones de Blizzard"
L["Base"] = "Base"
L["Shift"] = "Mayús"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "Borrar objetivo"
L["Clear Focus"] = "Borrar foco"
L["Start Attack"] = "Iniciar ataque"
L["Pet Attack"] = "Ataque de mascota"
L["Toggle Focus Any"] = "Alternar foco (cualquiera)"
L["Toggle Focus Enemy"] = "Alternar foco (enemigo)"
L["Run MACRO"] = "Ejecutar MACRO"
L["— none —"] = "— ninguna —"
L["Override this click during Mouse Look."] = "Sustituye este clic durante la vista con ratón."
L["Action"] = "Acción"
L["Macro"] = "Macro"
L["Select a macro"] = "Selecciona una macro"
L["No targeting"] = "Sin selección"
L["Left Click"] = "Clic izquierdo"
L["Right Click"] = "Clic derecho"
L["Shift + Left Click"] = "Mayús + Clic izquierdo"
L["Shift + Right Click"] = "Mayús + Clic derecho"
L["Ctrl + Left Click"] = "Ctrl + Clic izquierdo"
L["Ctrl + Right Click"] = "Ctrl + Clic derecho"
L["Alt + Left Click"] = "Alt + Clic izquierdo"
L["Alt + Right Click"] = "Alt + Clic derecho"
L["Click Casting"] = "Lanzamiento por clic"
L["CLICK CASTING"] = "LANZAMIENTO POR CLIC"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Asigna acciones sustitutivas a los clics izquierdo y derecho que están activas durante la vista con ratón."
L["Account-Wide Binds"] = "Asignaciones de toda la cuenta"
L["Share Click Casting binds across all characters."] =
  "Comparte las asignaciones de lanzamiento por clic con todos los personajes."
L["Click Binds"] = "Asignaciones de clic"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "Base, Mayús, Ctrl y Alt tienen cada uno sus propias acciones de clic izquierdo y derecho."

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Ruedas del menú radial"
L["Forever"] = "Forever"
L["Minimal"] = "Minimalista"
L["Clear Slice"] = "Vaciar sector"
L["UI Actions"] = "Acciones de interfaz"
L["Emotes"] = "Emociones"
L["Commands"] = "Comandos"
L["Markers"] = "Marcadores"
L["Slice"] = "Sector"
L["Choose an action"] = "Elige una acción"
L["Presets"] = "Preajustes"
L["New Wheel"] = "Nueva rueda"
L["Wheel"] = "Rueda"
L["You can have up to %d wheels."] = "Puedes tener hasta %d ruedas."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Eso no puede ir en una rueda. Usa un hechizo, objeto, juguete, montura o macro."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Arrastra aquí un hechizo, objeto, juguete, montura o macro, o haz clic para cambiar la acción."
L["Empty Slice"] = "Sector vacío"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Arrastra aquí un hechizo, objeto, juguete, montura o macro, o haz clic para establecer una acción. Los sectores vacíos no aparecen en la rueda."
L["A wheel needs at least one slice."] = "Una rueda necesita al menos un sector."
L["Click to rename this wheel"] = "Haz clic para renombrar esta rueda"
L["Previous wheel"] = "Rueda anterior"
L["Next wheel"] = "Rueda siguiente"
L["Click to select this wheel, drag to reorder"] =
  "Haz clic para seleccionar esta rueda; arrastra para reordenar"
L["Add Slice"] = "Añadir sector"
L["A wheel holds up to %d slices."] = "Una rueda admite hasta %d sectores."
L["Remove Wheel"] = "Quitar rueda"
L["Deletes this wheel and all of its slices."] = "Elimina esta rueda y todos sus sectores."
L["You need at least one wheel."] = "Necesitas al menos una rueda."
L["Remove this wheel and all of its slices?"] = "¿Quitar esta rueda y todos sus sectores?"
L["Add Wheel"] = "Añadir rueda"
L["Pick a preset wheel or a blank one."] = "Elige una rueda predefinida o una en blanco."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Haz clic en un sector para elegir su acción, o suelta sobre él un hechizo, objeto, juguete, montura o macro.\nArrastra un sector para reordenarlo. Clic derecho para quitarlo."
L["RADIAL MENU"] = "MENÚ RADIAL"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Crea ruedas de acceso rápido para hechizos, objetos, macros, emociones y atajos de la interfaz."
L["Radial Menu Keybind"] = "Atajo del menú radial"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Mantén pulsado para abrir el menú radial, apunta a un sector y suelta para activarlo. Usa la rueda del ratón para cambiar de rueda."
L["Radial Menu Style"] = "Estilo del menú radial"
L["Choose the appearance of the Radial Menu wheels."] =
  "Elige el aspecto de las ruedas del menú radial."
L["Party Wheel Spells"] = "Hechizos de la rueda de grupo"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Hechizos beneficiosos que abren una rueda de objetivos de grupo mientras se mantiene su tecla. Desliza hacia un miembro del grupo y suelta para lanzarle el hechizo, o vuelve al centro para lanzártelo a ti. Una pulsación breve lo lanza a tu objetivo amistoso, o a ti si no hay ninguno."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Edita los sectores de cada rueda, renómbralas y añade o quita ruedas."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "Arriba"
L["Bottom"] = "Abajo"
L["Ally Cycle"] = "Ciclo de aliados"
L["ALLY CYCLE"] = "CICLO DE ALIADOS"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "Combate y apoyo fluidos: los hechizos beneficiosos apuntan a los aliados, mientras que los dañinos siguen dirigidos al enemigo bajo la mira."
L["Ally Cycle - Next"] = "Ciclo de aliados: siguiente"
L["Target the next group member."] = "Selecciona al siguiente miembro del grupo."
L["Ally Cycle - Previous"] = "Ciclo de aliados: anterior"
L["Target the previous group member."] = "Selecciona al miembro anterior del grupo."
L["Skip Self"] = "Omitirte a ti mismo"
L["Skip yourself when cycling through group members."] =
  "Te omite al recorrer los miembros del grupo."
L["Keep Ally After Harm"] = "Mantener aliado tras daño"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "Tras un hechizo dañino sobre el enemigo de la mira, se restaura al aliado anterior. Activado por defecto en especializaciones de sanador hasta que se cambie."
L["Disabled while Auto Target Lock is on"] =
  "Desactivado mientras Fijar objetivo automático esté activo"
L["ALLY HUD"] = "HUD DE ALIADOS"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "Un HUD que muestra al miembro del grupo seleccionado por el ciclo de aliados."
L["Ally HUD"] = "HUD de aliados"
L["Show a unit frame for the currently selected group member."] =
  "Muestra un marco de unidad del miembro del grupo seleccionado."
L["Where the Ally HUD sits relative to the crosshair."] =
  "Dónde se sitúa el HUD de aliados respecto a la mira."
L["Scales the size of the Ally HUD."] = "Escala el tamaño del HUD de aliados."
L["Distance between the Ally HUD and the crosshair."] =
  "Distancia entre el HUD de aliados y la mira."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "Desbloqueo automático"
L["AUTO UNLOCK"] = "DESBLOQUEO AUTOMÁTICO"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "Pausa automáticamente la vista con ratón cuando se abren ventanas y la reanuda al cerrarlas."
L["Release the cursor when UI panels open."] =
  "Libera el cursor cuando se abren paneles de la interfaz."
L["Unlock Mounts"] = "Monturas que desbloquean"
L["Mounts that force a cursor unlock while mounted."] =
  "Monturas que liberan el cursor mientras estás montado."
L["Extra Frames"] = "Marcos adicionales"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "Nombres de marcos adicionales que activan el desbloqueo automático. Escribe para buscar marcos de Blizzard y de addons, o usa el botón de inspección para hacer clic en una ventana de la pantalla."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "Avanzado"
L["SOUNDS"] = "SONIDOS"
L["Control the sound cues used by some of the other features."] =
  "Controla las señales sonoras que usan otras funciones."
L["Mouse Look Sounds"] = "Sonidos de vista con ratón"
L["Play a cue when Mouse Look turns on and off."] =
  "Reproduce una señal al activar y desactivar la vista con ratón."
L["Target Lock Sounds"] = "Sonidos de fijar objetivo"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "Reproduce señales al fijar, quitar o cambiar un objetivo fijado."
L["Radial Menu Sounds"] = "Sonidos del menú radial"
L["Play cues when interacting with Radial Menu wheels."] =
  "Reproduce señales al interactuar con las ruedas del menú radial."
L["Ally Cycle Sounds"] = "Sonidos del ciclo de aliados"
L["Play a cue when Ally Cycle moves to another ally."] =
  "Reproduce una señal cuando el ciclo de aliados pasa a otro aliado."
L["FORCE LOCK"] = "FORZAR BLOQUEO"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "Una opción avanzada que mantiene activa la vista con ratón mientras una condición Lua personalizada sea verdadera."
L["Custom Condition"] = "Condición personalizada"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "Código Lua personalizado que, mientras se evalúe como verdadero, mantiene bloqueada la vista con ratón."
L["Lock Once"] = "Bloquear una vez"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "Bloquea la vista con ratón solo cuando la condición pasa a ser verdadera por primera vez. Un desbloqueo manual se mantiene hasta que la condición sea falsa y luego verdadera de nuevo."
L["FORCE UNLOCK"] = "FORZAR DESBLOQUEO"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "Lo contrario de Forzar bloqueo: mantiene desactivada la vista con ratón mientras una condición Lua personalizada sea verdadera."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "Código Lua personalizado que, mientras se evalúe como verdadero, mantiene desbloqueada la vista con ratón."
L["Unlock Once"] = "Desbloquear una vez"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "Desbloquea la vista con ratón solo cuando la condición pasa a ser verdadera por primera vez. Un bloqueo manual se mantiene hasta que la condición sea falsa y luego verdadera de nuevo."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "Cambia el aspecto de la mira mientras una condición Lua personalizada sea verdadera."
L["Situational Appearance"] = "Aspecto situacional"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "Texturas que usa la mira mientras la condición situacional sea verdadera."
L["Situational Condition"] = "Condición situacional"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "Código Lua personalizado que, mientras se evalúe como verdadero, obliga a la mira a usar su aspecto situacional."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Modifica las CVars predeterminadas de la selección por retícula y las prelíneas de macro de selección de Action Combat Mode."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "Advertencia: editar estos valores podría romper la selección por retícula y fijar objetivo."
L["Reticle Targeting CVar Editor"] = "Editor de CVars de selección por retícula"
L["Targeting Macro Prelines Editor"] = "Editor de prelíneas de macro de selección"
