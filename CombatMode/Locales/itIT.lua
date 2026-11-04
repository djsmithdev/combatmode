---------------------------------------------------------------------------------------
--  Locales/itIT.lua — LOCALES — Italian strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the itIT client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "itIT", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "itIT" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Benvenuto in Action Combat Mode!"
L["The configuration panel will open after you close this message."] =
  "Il pannello di configurazione si aprirà dopo aver chiuso questo messaggio."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Puoi riaprirlo in qualsiasi momento con |cff69ccf0/acm|r o |cff69ccf0/actioncombatmode|r."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Per ripristinare le impostazioni precedenti, usa il pulsante |cffff5555Disinstalla|r nel pannello delle opzioni.|r"
L["Mouse Look"] = "Visuale con mouse"
L["Flip Camera"] = "Inverti telecamera"
L["Swap Shoulder"] = "Cambia spalla"
L["Reset Mouse Look"] = "Reimposta visuale con mouse"
L["Ally Cycle Next"] = "Ciclo alleati: successivo"
L["Ally Cycle Previous"] = "Ciclo alleati: precedente"
L["Toggle Focus Target"] = "Attiva/disattiva bersaglio focus"
L["Cycle Focus Next"] = "Ciclo focus: successivo"
L["Cycle Focus Previous"] = "Ciclo focus: precedente"
L["Radial Menu"] = "Menu radiale"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "modifica dell'assegnazione tasti"
L["deferred %s until combat ends."] = "%s rimandato fino alla fine del combattimento."
L["failed to apply %s: %s"] = "impossibile applicare %s: %s"
L["applied deferred binding updates."] =
  "applicati gli aggiornamenti rimandati delle assegnazioni tasti."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50%s rilevato!|r Cessione di velocità di rotazione, spalla e inclinazione dinamica."
L["Cannot uninstall while in combat."] = "Impossibile disinstallare in combattimento."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "ripristinate le tue impostazioni precedenti di telecamera/bersaglio e le assegnazioni predefinite della telecamera con mouse; addon disattivato."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Digita |cff69ccf0/acm|r o |cff69ccf0/actioncombatmode|r per aprire le impostazioni."
L["camera and targeting CVars restored."] = "CVar di telecamera e bersaglio ripristinate."
L["Cannot open settings while in combat."] = "Impossibile aprire le impostazioni in combattimento."
L["Cannot open this editor while in combat."] = "Impossibile aprire questo editor in combattimento."
L["Cannot open editor while in combat."] = "Impossibile aprire l'editor in combattimento."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "impossibile modificare le CVar del puntamento con mirino in combattimento."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "impossibile reimpostare le CVar del puntamento con mirino in combattimento."
L["MOVEANDSTEER unbind"] = "rimozione dell'assegnazione MOVEANDSTEER"
L["restore default mouse camera bindings"] =
  "ripristino delle assegnazioni predefinite della telecamera con mouse"
L["Minimum Zoom"] = "Zoom minimo"
L["ally cycle bindings"] = "assegnazioni del ciclo alleati"
L["radial menu"] = "menu radiale"
L["target lock keybinding"] = "assegnazione del blocco bersaglio"
L["cycle focus next keybinding"] = "assegnazione del ciclo focus: successivo"
L["cycle focus previous keybinding"] = "assegnazione del ciclo focus: precedente"
L["ally cycle next keybinding"] = "assegnazione del ciclo alleati: successivo"
L["ally cycle previous keybinding"] = "assegnazione del ciclo alleati: precedente"
L["radial menu keybinding"] = "assegnazione del menu radiale"
L["reticle interact keybinding"] = "assegnazione dell'interazione con il mirino"
L["mouse look keybinding"] = "assegnazione della visuale con mouse"
L["flip camera keybinding"] = "assegnazione di inverti telecamera"
L["reset mouse look keybinding"] = "assegnazione di reimposta visuale con mouse"
L["swap shoulder keybinding"] = "assegnazione di cambia spalla"

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "VISTA CON MOUSE"
L["CAMERA FEATURES"] = "FUNZIONI DELLA TELECAMERA"
L["ADDITIONAL FEATURES"] = "FUNZIONI AGGIUNTIVE"
L["Crosshair - More accurate"] = "Mirino - Più preciso"
L["Soft Target - More forgiving"] = "Bersaglio morbido - Più permissivo"
L["Mouse Look is on"] = "La vista con mouse è attiva"
L["In combat"] = "In combattimento"
L["Talking to an NPC"] = "Dialogo con un PNG"
L["Any checked"] = "Una qualsiasi selezionata"
L["All checked"] = "Tutte quelle selezionate"
L["Off"] = "Disattivato"
L["Control relinquished to %s"] = "Controllo ceduto a %s"
L["Disabled while Motion Sickness Protection is on"] =
  "Disattivato mentre la protezione dal mal di movimento è attiva"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Blocca il cursore sulla posizione del mirino e consente di orientarsi muovendo il mouse senza tenere premuto il tasto destro."
L["Mouse Look Keybind"] = "Tasto vista con mouse"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Premi per attivare o disattivare la vista con mouse. Tieni premuto per sbloccare temporaneamente il cursore."
L["Interact Keybind"] = "Tasto interazione"
L["Tap to interact with a player or the unit chosen below."] =
  "Premi per interagire con un giocatore o con l'unità scelta qui sotto."
L["Players"] = "Giocatori"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Mira un giocatore per un secondo e l'HUD di assistenza mostrerà un suggerimento. Premi quindi il tasto per aprire il suo menu contestuale."
L["NPCs and objects"] = "PNG e oggetti"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Interagisce normalmente con l'unità scelta in «Unità di interazione»."
L["Interact Unit"] = "Unità di interazione"
L["Which unit will be interacted with when the key is pressed."] =
  "L'unità con cui si interagisce quando si preme il tasto."
L["Flip Camera Keybind"] = "Tasto inversione telecamera"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Premi per ruotare la telecamera di 180° attorno al personaggio. Tieni premuto per ruotarla solo finché il tasto è premuto."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Recupera un cursore bloccato dopo il cambio di finestra su macOS. Riacquisisce e rilascia la vista con mouse per eliminare una cattura rimasta bloccata dal gioco in background."
L["Curated camera adjustments for a more action-focused experience."] =
  "Regolazioni della telecamera selezionate per un'esperienza più orientata all'azione."
L["Motion Sickness Protection"] = "Protezione dal mal di movimento"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Impedisce ad Action Combat Mode di sovrascrivere le impostazioni di mal di movimento di Blizzard."
L["Turn Speed"] = "Velocità di rotazione"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Controlla la rapidità con cui la telecamera ruota usando la vista con mouse."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Impedisce alla telecamera di avvicinarsi più di questa distanza. 0 la disattiva."
L["Dynamic Pitch"] = "Inclinazione dinamica"
L["Dynamically tilt the camera up and down as you move it."] =
  "Inclina dinamicamente la telecamera verso l'alto e verso il basso mentre la muovi."
L["Pitch Strength"] = "Intensità di inclinazione"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Quanto l'inclinazione dinamica inclina la telecamera. Valori più bassi mantengono il personaggio più in alto sullo schermo. In volo l'inclinazione è maggiore e scala con questo valore."
L["Shoulder Offset"] = "Offset spalla"
L["Camera's horizontal position relative to the character."] =
  "Posizione orizzontale della telecamera rispetto al personaggio."
L["Disable Offset With Mouselook"] = "Disattiva offset con vista con mouse"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "L'offset spalla torna gradualmente a 0 quando disattivi la vista con mouse."
L["When off, Shoulder Offset stays constant at all times."] =
  "Se disattivato, l'offset spalla rimane sempre costante."
L["Swap Shoulder Keybind"] = "Tasto scambio spalla"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Premi per specchiare l'offset spalla sull'altro lato del personaggio."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Funzionalità aggiuntive legate al comportamento della vista con mouse."
L["Cursor Pulse"] = "Pulsazione del cursore"
L["Flash the cursor when Mouse Look is turned off."] =
  "Fa lampeggiare il cursore quando la vista con mouse viene disattivata."
L["Hide Tooltips"] = "Nascondi i suggerimenti"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Nasconde i suggerimenti mentre la vista con mouse è attiva, a meno che il tasto sotto non sia premuto."
L["Show Tooltips With"] = "Mostra suggerimenti con"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Tieni premuto questo tasto per mostrare i suggerimenti mentre la vista con mouse è attiva."
L["Auto Sheath"] = "Rinfodera automaticamente"
L["Sheath weapons automatically with Mouse Look."] =
  "Rinfodera automaticamente le armi insieme alla vista con mouse."
L["Vignette Shows When"] = "La vignettatura appare quando"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Scurisce i bordi dello schermo finché le situazioni selezionate sono vere."
L["Vignette Match"] = "Corrispondenza vignettatura"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "Una qualsiasi: basta una situazione selezionata. Tutte: ogni situazione selezionata deve essere vera contemporaneamente."

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Qualsiasi bersaglio fisso"
L["Locked Target Only"] = "Solo bersaglio bloccato"
L["Soft Target (Blizzard)"] = "Bersaglio morbido (Blizzard)"
L["Hidden"] = "Nascosto"
L["Toggle"] = "Attiva/disattiva"
L["Switch Target"] = "Cambia bersaglio"
L["A UI Reload is required when making this change. Proceed?"] =
  "Questa modifica richiede il ricaricamento dell'interfaccia. Procedere?"
L["Create New Macro"] = "Crea nuova macro"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Scrivi una macro che inizia con la tua preriga di Puntamento a mirino."
L["Unavailable in combat."] = "Non disponibile in combattimento."
L["Drag to a button on your action bars to use."] =
  "Trascinala su un pulsante delle barre azioni per usarla."
L["Right-click to edit"] = "Clic destro per modificare"
L["+%d more in /macro"] = "+%d altre in /macro"
L["Reticle Targeting Macros"] = "Macro di puntamento a mirino"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "I pulsanti azione che sono macro non ereditano automaticamente la logica del Puntamento a mirino. Per farglielo rispettare, creali con lo strumento Compositore di macro, poi trascinali sulle tue barre."
L["Reticle Targeting"] = "Puntamento a mirino"
L["RETICLE TARGETING"] = "PUNTAMENTO A MIRINO"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Abilita la selezione delle unità mirando e il posizionamento preciso di incantesimi a terra e abilità ad area."
L["Enable Reticle Targeting"] = "Attiva puntamento a mirino"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Punta il mirino sulle unità per scegliere i bersagli invece di usare il tab."
L["Ignore Friendlies"] = "Ignora amichevoli"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Ignora PNG e giocatori amichevoli e seleziona solo unità ostili."
L["Click Casting Only"] = "Solo lancio con clic"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "Applica la logica del puntamento a mirino solo ai tasti di lancio con clic."
L["Excluded Spells"] = "Incantesimi esclusi"
L["Spells to skip the reticle targeting logic."] =
  "Incantesimi che saltano la logica del puntamento a mirino."
L["Cast at Crosshair"] = "Lancia sul mirino"
L["Ground spells to cast at the crosshair location."] =
  "Incantesimi a terra da lanciare nella posizione del mirino."
L["TARGET LOCK"] = "BLOCCO BERSAGLIO"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Blocca un bersaglio per evitare cambi accidentali e passa da un'unità all'altra per dare priorità a nemici specifici."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Attenzione: il Blocco bersaglio usa il tuo bersaglio focus. Qualsiasi altra cosa che imposta il focus interferirà."
L["Target Lock Keybind"] = "Tasto blocco bersaglio"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Blocca il mirino su un bersaglio impedendo che cambi."
L["Cycle Lock - Next"] = "Cicla blocco - Successivo"
L["Move Target Lock to the next valid nearby target."] =
  "Sposta il blocco sul successivo bersaglio valido nelle vicinanze."
L["Cycle Lock - Previous"] = "Cicla blocco - Precedente"
L["Move Target Lock to the previous valid nearby target."] =
  "Sposta il blocco sul precedente bersaglio valido nelle vicinanze."
L["Target Lock Behavior"] = "Comportamento blocco bersaglio"
L["What the Target Lock key does when you press it."] =
  "Cosa fa il tasto di blocco bersaglio quando lo premi."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Blocca il tuo bersaglio o l'unità sotto il mirino. Premi di nuovo per sbloccare."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Blocca l'unità sotto il mirino sostituendo qualsiasi blocco attuale. Premi senza nulla sotto il mirino per sbloccare. Mirare l'unità già bloccata mantiene il blocco."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Con «Ignora amichevoli» attivo, un'unità amichevole o morta sotto il mirino viene ignorata: il blocco resta dov'è."
L["Auto Target Lock"] = "Blocco bersaglio automatico"
L["Target Lock engages automatically when attacking units."] =
  "Il blocco bersaglio si attiva automaticamente quando attacchi le unità."
L["Target Lock Marker"] = "Indicatore di blocco bersaglio"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Mostra un indicatore a mirino sulla targhetta del bersaglio bloccato."
L["Focus Locked Target"] = "Metti a fuoco il bersaglio bloccato"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Attira la telecamera verso il bersaglio bloccato, mantenendolo a fuoco."
L["TARGETING INDICATORS"] = "INDICATORI DEL BERSAGLIO"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Indicatori visivi che evidenziano i bersagli nel mondo per riconoscerli più facilmente."
L["Target Outline"] = "Contorno del bersaglio"
L["Show an outline effect on your target."] = "Mostra un effetto contorno sul tuo bersaglio."
L["Only available on Retail"] = "Disponibile solo su Retail"
L["Selection Circle"] = "Cerchio di selezione"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "Quale bersaglio riceve il cerchio di selezione di Blizzard sotto i piedi."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "Il cerchio sotto qualsiasi bersaglio selezionato, nemico o amichevole."
L["The circle only under your Target Lock."] = "Il cerchio solo sotto il tuo bersaglio bloccato."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Lascia che Blizzard controlli il comportamento di ObjectSelectionCircle e UnitNameFocused."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "Blizzard sceglie il bersaglio morbido da un arco davanti al modello del personaggio. Non tiene conto della posizione del mirino né dell'offset spalla."
L["No selection circle."] = "Nessun cerchio di selezione."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Mirino"
L["CROSSHAIR"] = "MIRINO"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Un mirino dinamico che reagisce a bersagli e stati di combattimento, migliora la precisione e guida il puntamento a mirino."
L["Enable Crosshair"] = "Attiva mirino"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Mostra sul display un mirino dinamico e reattivo durante la vista con mouse."
L["Cast Feedback"] = "Feedback di lancio"
L["Crosshair provides visual feedback while casting."] =
  "Il mirino fornisce un feedback visivo durante il lancio."
L["Appearance"] = "Aspetto"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Texture usate dal mirino per ogni stato. Fai clic su una per sceglierne la texture, oppure parti da un preset."
L["Inactive"] = "Inattivo"
L["Active"] = "Attivo"
L["Mounted"] = "In sella"
L["Disabled"] = "Disattivato"
L["Reaction Colors"] = "Colori di reazione"
L["Edit"] = "Modifica"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Personalizza i colori usati dal mirino quando punti diversi tipi di unità."
L["Scale"] = "Scala"
L["Scales the size of the crosshair."] = "Ridimensiona il mirino."
L["Vertical Position"] = "Posizione verticale"
L["Move the crosshair up or down from screen center."] =
  "Sposta il mirino in alto o in basso rispetto al centro dello schermo."
L["ASSIST HUD"] = "HUD DI ASSISTENZA"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "Un HUD che guida la rotazione degli incantesimi quando punti i nemici e mostra suggerimenti di interazione."
L["Next-cast Suggestion"] = "Suggerimento del prossimo incantesimo"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Mostra il suggerimento del prossimo incantesimo dell'evidenziazione assistita mentre punti un bersaglio."
L["Always"] = "Sempre"
L["Only In Combat"] = "Solo in combattimento"
L["Interactable Indicator"] = "Indicatore di interazione"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Mostra un indicatore mentre punti un'unità o un oggetto con cui si può interagire."
L["Player Interaction Prompt"] = "Suggerimento di interazione con i giocatori"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Mostra un indicatore quando miri un giocatore per un secondo. Premendo il tasto di interazione si apre il suo menu contestuale."
L["Position"] = "Posizione"
L["Which side of the crosshair the HUD appears on."] = "Su quale lato del mirino compare l'HUD."
L["Left"] = "Sinistra"
L["Right"] = "Destra"
L["Scales the size of the HUD."] = "Ridimensiona l'HUD."
L["Distance"] = "Distanza"
L["Distance between the HUD and the crosshair."] = "Distanza tra l'HUD e il mirino."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Azioni Blizzard modificate"
L["Blizzard Actions"] = "Azioni Blizzard"
L["Base"] = "Base"
L["Shift"] = "Maiusc"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "Cancella bersaglio"
L["Clear Focus"] = "Cancella focus"
L["Start Attack"] = "Inizia attacco"
L["Pet Attack"] = "Attacco del famiglio"
L["Toggle Focus Any"] = "Attiva/disattiva focus (qualsiasi)"
L["Toggle Focus Enemy"] = "Attiva/disattiva focus (nemico)"
L["Run MACRO"] = "Esegui MACRO"
L["— none —"] = "— nessuna —"
L["Override this click during Mouse Look."] = "Sostituisce questo clic durante la vista con mouse."
L["Action"] = "Azione"
L["Macro"] = "Macro"
L["Select a macro"] = "Seleziona una macro"
L["No targeting"] = "Nessun puntamento"
L["Left Click"] = "Clic sinistro"
L["Right Click"] = "Clic destro"
L["Shift + Left Click"] = "Maiusc + Clic sinistro"
L["Shift + Right Click"] = "Maiusc + Clic destro"
L["Ctrl + Left Click"] = "Ctrl + Clic sinistro"
L["Ctrl + Right Click"] = "Ctrl + Clic destro"
L["Alt + Left Click"] = "Alt + Clic sinistro"
L["Alt + Right Click"] = "Alt + Clic destro"
L["Click Casting"] = "Lancio con clic"
L["CLICK CASTING"] = "LANCIO CON CLIC"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Assegna azioni sostitutive ai clic sinistro e destro, attive durante la vista con mouse."
L["Account-Wide Binds"] = "Assegnazioni per tutto l'account"
L["Share Click Casting binds across all characters."] =
  "Condivide le assegnazioni di lancio con clic tra tutti i personaggi."
L["Click Binds"] = "Assegnazioni dei clic"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "Base, Maiusc, Ctrl e Alt hanno ciascuno le proprie azioni di clic sinistro e destro."

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Ruote del menu radiale"
L["Forever"] = "Forever"
L["Minimal"] = "Minimale"
L["Clear Slice"] = "Svuota spicchio"
L["UI Actions"] = "Azioni dell'interfaccia"
L["Emotes"] = "Emote"
L["Commands"] = "Comandi"
L["Markers"] = "Segnalini"
L["Slice"] = "Spicchio"
L["Choose an action"] = "Scegli un'azione"
L["Presets"] = "Preimpostazioni"
L["New Wheel"] = "Nuova ruota"
L["Wheel"] = "Ruota"
L["You can have up to %d wheels."] = "Puoi avere fino a %d ruote."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Non può andare su una ruota. Usa un incantesimo, un oggetto, un giocattolo, una cavalcatura o una macro."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Trascina qui un incantesimo, un oggetto, un giocattolo, una cavalcatura o una macro, oppure clicca per cambiare l'azione."
L["Empty Slice"] = "Spicchio vuoto"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Trascina qui un incantesimo, un oggetto, un giocattolo, una cavalcatura o una macro, oppure clicca per impostare un'azione. Gli spicchi vuoti vengono omessi dalla ruota."
L["A wheel needs at least one slice."] = "Una ruota ha bisogno di almeno uno spicchio."
L["Click to rename this wheel"] = "Clicca per rinominare questa ruota"
L["Previous wheel"] = "Ruota precedente"
L["Next wheel"] = "Ruota successiva"
L["Click to select this wheel, drag to reorder"] =
  "Clicca per selezionare questa ruota, trascina per riordinare"
L["Add Slice"] = "Aggiungi spicchio"
L["A wheel holds up to %d slices."] = "Una ruota contiene fino a %d spicchi."
L["Remove Wheel"] = "Rimuovi ruota"
L["Deletes this wheel and all of its slices."] = "Elimina questa ruota e tutti i suoi spicchi."
L["You need at least one wheel."] = "Serve almeno una ruota."
L["Remove this wheel and all of its slices?"] = "Rimuovere questa ruota e tutti i suoi spicchi?"
L["Add Wheel"] = "Aggiungi ruota"
L["Pick a preset wheel or a blank one."] = "Scegli una ruota predefinita o una vuota."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Clicca su uno spicchio per scegliere la sua azione, oppure rilascia su di esso un incantesimo, un oggetto, un giocattolo, una cavalcatura o una macro.\nTrascina uno spicchio per riordinarlo. Clic destro per rimuoverlo."
L["RADIAL MENU"] = "MENU RADIALE"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Crea ruote di accesso rapido per incantesimi, oggetti, macro, emote e scorciatoie dell'interfaccia."
L["Radial Menu Keybind"] = "Tasto del menu radiale"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Tieni premuto per aprire il menu radiale, punta uno spicchio e rilascia per attivarlo. Usa la rotellina per cambiare ruota."
L["Radial Menu Style"] = "Stile del menu radiale"
L["Choose the appearance of the Radial Menu wheels."] =
  "Scegli l'aspetto delle ruote del menu radiale."
L["Party Wheel Spells"] = "Incantesimi della ruota di gruppo"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Incantesimi benefici che aprono una ruota di bersagli del gruppo finché il tasto è premuto. Spostati verso un membro del gruppo e rilascia per lanciarlo su di lui, oppure torna al centro per lanciarlo su di te. Un tocco lo lancia sul tuo bersaglio amico, o su di te se non ne hai uno."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Modifica gli spicchi di ogni ruota, rinomina le ruote e aggiungi o rimuovi ruote."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "Alto"
L["Bottom"] = "Basso"
L["Ally Cycle"] = "Ciclo alleati"
L["ALLY CYCLE"] = "CICLO ALLEATI"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "Combattimento e supporto fluidi: gli incantesimi benefici bersagliano gli alleati, mentre quelli dannosi restano sul nemico sotto il mirino."
L["Ally Cycle - Next"] = "Ciclo alleati – Successivo"
L["Target the next group member."] = "Bersaglia il membro del gruppo successivo."
L["Ally Cycle - Previous"] = "Ciclo alleati – Precedente"
L["Target the previous group member."] = "Bersaglia il membro del gruppo precedente."
L["Skip Self"] = "Salta te stesso"
L["Skip yourself when cycling through group members."] =
  "Ti salta quando scorri i membri del gruppo."
L["Keep Ally After Harm"] = "Mantieni alleato dopo danno"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "Dopo un incantesimo dannoso sul nemico nel mirino, ripristina l'alleato precedente. Attivo di default per le specializzazioni da guaritore finché non viene cambiato."
L["Disabled while Auto Target Lock is on"] =
  "Disattivato finché il Blocco bersaglio automatico è attivo"
L["ALLY HUD"] = "HUD ALLEATO"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "Un HUD che mostra il membro del gruppo selezionato dal ciclo alleati."
L["Ally HUD"] = "HUD alleato"
L["Show a unit frame for the currently selected group member."] =
  "Mostra un riquadro unità per il membro del gruppo selezionato."
L["Where the Ally HUD sits relative to the crosshair."] =
  "Dove si trova l'HUD alleato rispetto al mirino."
L["Scales the size of the Ally HUD."] = "Scala le dimensioni dell'HUD alleato."
L["Distance between the Ally HUD and the crosshair."] = "Distanza tra l'HUD alleato e il mirino."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "Sblocco automatico"
L["AUTO UNLOCK"] = "SBLOCCO AUTOMATICO"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "Mette automaticamente in pausa la vista con mouse quando si aprono finestre e la riprende quando si chiudono."
L["Release the cursor when UI panels open."] =
  "Libera il cursore quando si aprono pannelli dell'interfaccia."
L["Unlock Mounts"] = "Cavalcature che sbloccano"
L["Mounts that force a cursor unlock while mounted."] =
  "Cavalcature che liberano il cursore finché sei in sella."
L["Extra Frames"] = "Frame aggiuntivi"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "Nomi di frame aggiuntivi che attivano lo sblocco automatico. Digita per cercare tra i frame di Blizzard e degli addon, oppure usa il pulsante di ispezione per cliccare una finestra sullo schermo."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "Avanzate"
L["SOUNDS"] = "SUONI"
L["Control the sound cues used by some of the other features."] =
  "Controlla i segnali sonori usati da alcune altre funzioni."
L["Mouse Look Sounds"] = "Suoni della vista con mouse"
L["Play a cue when Mouse Look turns on and off."] =
  "Riproduce un segnale quando la vista con mouse si attiva e si disattiva."
L["Target Lock Sounds"] = "Suoni del blocco bersaglio"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "Riproduce segnali quando un blocco bersaglio viene impostato, rimosso o cambiato."
L["Radial Menu Sounds"] = "Suoni del menu radiale"
L["Play cues when interacting with Radial Menu wheels."] =
  "Riproduce segnali quando interagisci con le ruote del menu radiale."
L["Ally Cycle Sounds"] = "Suoni del ciclo alleati"
L["Play a cue when Ally Cycle moves to another ally."] =
  "Riproduce un segnale quando il ciclo alleati passa a un altro alleato."
L["FORCE LOCK"] = "FORZA BLOCCO"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "Un'opzione avanzata che mantiene attiva la vista con mouse finché una condizione Lua personalizzata è vera."
L["Custom Condition"] = "Condizione personalizzata"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "Codice Lua personalizzato che, finché risulta vero, mantiene bloccata la vista con mouse."
L["Lock Once"] = "Blocca una volta"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "Blocca la vista con mouse solo quando la condizione diventa vera per la prima volta. Uno sblocco manuale resta valido finché la condizione non diventa falsa e poi di nuovo vera."
L["FORCE UNLOCK"] = "FORZA SBLOCCO"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "L'opposto di Forza blocco: mantiene disattivata la vista con mouse finché una condizione Lua personalizzata è vera."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "Codice Lua personalizzato che, finché risulta vero, mantiene sbloccata la vista con mouse."
L["Unlock Once"] = "Sblocca una volta"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "Sblocca la vista con mouse solo quando la condizione diventa vera per la prima volta. Un blocco manuale resta valido finché la condizione non diventa falsa e poi di nuovo vera."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "Cambia l'aspetto del mirino finché una condizione Lua personalizzata è vera."
L["Situational Appearance"] = "Aspetto situazionale"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "Texture usate dal mirino finché la condizione situazionale è vera."
L["Situational Condition"] = "Condizione situazionale"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "Codice Lua personalizzato che, finché risulta vero, obbliga il mirino a usare il suo aspetto situazionale."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Modifica le CVar predefinite del puntamento a mirino e le prelinee delle macro di puntamento di Action Combat Mode."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "Attenzione: modificare questi valori potrebbe compromettere il puntamento a mirino e il blocco bersaglio."
L["Reticle Targeting CVar Editor"] = "Editor CVar del puntamento a mirino"
L["Targeting Macro Prelines Editor"] = "Editor delle prelinee delle macro di puntamento"
