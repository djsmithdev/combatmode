---------------------------------------------------------------------------------------
--  Locales/deDE.lua — LOCALES — German strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the deDE client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "deDE", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "deDE" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Willkommen bei Action Combat Mode!"
L["The configuration panel will open after you close this message."] =
  "Das Konfigurationsfenster öffnet sich, nachdem du diese Meldung geschlossen hast."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Du kannst es jederzeit mit |cff69ccf0/acm|r oder |cff69ccf0/actioncombatmode|r erneut öffnen."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Um deine vorherigen Einstellungen wiederherzustellen, nutze die Schaltfläche |cffff5555Deinstallieren|r im Optionsfenster.|r"
L["Mouse Look"] = "Mausblick"
L["Flip Camera"] = "Kamera spiegeln"
L["Swap Shoulder"] = "Schulter wechseln"
L["Reset Mouse Look"] = "Mausblick zurücksetzen"
L["Ally Cycle Next"] = "Verbündeten wechseln: Nächster"
L["Ally Cycle Previous"] = "Verbündeten wechseln: Vorheriger"
L["Toggle Focus Target"] = "Fokusziel umschalten"
L["Cycle Focus Next"] = "Fokus wechseln: Nächster"
L["Cycle Focus Previous"] = "Fokus wechseln: Vorheriger"
L["Radial Menu"] = "Radialmenü"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "Tastenbelegungsänderung"
L["deferred %s until combat ends."] = "%s bis zum Kampfende verschoben."
L["failed to apply %s: %s"] = "%s konnte nicht angewendet werden: %s"
L["applied deferred binding updates."] = "Verschobene Tastenbelegungen wurden angewendet."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50%s erkannt!|r Drehgeschwindigkeit, Schulter und dynamische Neigung werden übergeben."
L["Cannot uninstall while in combat."] = "Im Kampf kann nicht deinstalliert werden."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "Deine vorherigen Kamera-/Zielerfassungs-Einstellungen und die Standard-Mauskamerabelegung wurden wiederhergestellt, das Addon wurde deaktiviert."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Gib |cff69ccf0/acm|r oder |cff69ccf0/actioncombatmode|r für die Einstellungen ein."
L["camera and targeting CVars restored."] = "Kamera- und Zielerfassungs-CVars wiederhergestellt."
L["Cannot open settings while in combat."] =
  "Die Einstellungen können im Kampf nicht geöffnet werden."
L["Cannot open this editor while in combat."] =
  "Dieser Editor kann im Kampf nicht geöffnet werden."
L["Cannot open editor while in combat."] = "Der Editor kann im Kampf nicht geöffnet werden."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "Die CVars der Zielerfassung per Fadenkreuz können im Kampf nicht bearbeitet werden."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "Die CVars der Zielerfassung per Fadenkreuz können im Kampf nicht zurückgesetzt werden."
L["MOVEANDSTEER unbind"] = "MOVEANDSTEER-Belegung entfernen"
L["restore default mouse camera bindings"] = "Standard-Mauskamerabelegung wiederherstellen"
L["Minimum Zoom"] = "Minimaler Zoom"
L["ally cycle bindings"] = "Verbündeten-Wechsel-Belegungen"
L["radial menu"] = "Radialmenü"
L["target lock keybinding"] = "Belegung für Zielsperre"
L["cycle focus next keybinding"] = "Belegung für Fokus wechseln: Nächster"
L["cycle focus previous keybinding"] = "Belegung für Fokus wechseln: Vorheriger"
L["ally cycle next keybinding"] = "Belegung für Verbündeten wechseln: Nächster"
L["ally cycle previous keybinding"] = "Belegung für Verbündeten wechseln: Vorheriger"
L["radial menu keybinding"] = "Belegung für Radialmenü"
L["reticle interact keybinding"] = "Belegung für Fadenkreuz-Interaktion"
L["mouse look keybinding"] = "Belegung für Mausblick"
L["flip camera keybinding"] = "Belegung für Kamera spiegeln"
L["reset mouse look keybinding"] = "Belegung für Mausblick zurücksetzen"
L["swap shoulder keybinding"] = "Belegung für Schulter wechseln"

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "MAUSBLICK"
L["CAMERA FEATURES"] = "KAMERAFUNKTIONEN"
L["ADDITIONAL FEATURES"] = "ZUSÄTZLICHE FUNKTIONEN"
L["Crosshair - More accurate"] = "Fadenkreuz – Genauer"
L["Soft Target - More forgiving"] = "Weiches Ziel – Nachsichtiger"
L["Mouse Look is on"] = "Mausblick ist aktiv"
L["In combat"] = "Im Kampf"
L["Talking to an NPC"] = "Im Gespräch mit einem NPC"
L["Any checked"] = "Beliebige markierte"
L["All checked"] = "Alle markierten"
L["Off"] = "Aus"
L["Control relinquished to %s"] = "Kontrolle an %s abgegeben"
L["Disabled while Motion Sickness Protection is on"] =
  "Deaktiviert, solange der Reisekrankheitsschutz aktiv ist"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Sperrt den Cursor an der Position des Fadenkreuzes und steuert durch Mausbewegung, ohne die rechte Maustaste zu halten."
L["Mouse Look Keybind"] = "Taste für Mausblick"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Antippen schaltet den Mausblick um. Gedrückt halten gibt den Cursor vorübergehend frei."
L["Interact Keybind"] = "Taste für Interaktion"
L["Tap to interact with a player or the unit chosen below."] =
  "Antippen, um mit einem Spieler oder der unten gewählten Einheit zu interagieren."
L["Players"] = "Spieler"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Ziele eine Sekunde lang auf einen Spieler, dann zeigt das Assist-HUD einen Hinweis. Drücke dann die Taste, um sein Kontextmenü zu öffnen."
L["NPCs and objects"] = "NPCs und Objekte"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Interagiert wie gewohnt mit der unter „Interaktionsziel“ gewählten Einheit."
L["Interact Unit"] = "Interaktionsziel"
L["Which unit will be interacted with when the key is pressed."] =
  "Mit welcher Einheit beim Tastendruck interagiert wird."
L["Flip Camera Keybind"] = "Taste für Kamera drehen"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Antippen, um die Kamera um 180° um deinen Charakter zu drehen. Gedrückt halten, um sie nur zu drehen, solange die Taste gehalten wird."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Behebt einen hängenden Cursor nach dem Fensterwechsel unter macOS. Erfasst den Mausblick neu und gibt ihn frei, um eine vom Spiel im Hintergrund hängen gebliebene Erfassung zu lösen."
L["Curated camera adjustments for a more action-focused experience."] =
  "Ausgewählte Kameraanpassungen für ein actionreicheres Spielerlebnis."
L["Motion Sickness Protection"] = "Reisekrankheitsschutz"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Verhindert, dass Action Combat Mode die Reisekrankheitseinstellungen von Blizzard überschreibt."
L["Turn Speed"] = "Drehgeschwindigkeit"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Legt fest, wie schnell sich die Kamera beim Mausblick dreht."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Verhindert, dass die Kamera näher als diese Entfernung heranzoomt. 0 schaltet die Funktion aus."
L["Dynamic Pitch"] = "Dynamische Neigung"
L["Dynamically tilt the camera up and down as you move it."] =
  "Neigt die Kamera beim Bewegen dynamisch nach oben und unten."
L["Pitch Strength"] = "Neigungsstärke"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Wie stark die dynamische Neigung die Kamera kippt. Niedrigere Werte halten deinen Charakter weiter oben auf dem Bildschirm. Beim Fliegen ist die Neigung stärker und skaliert mit diesem Wert."
L["Shoulder Offset"] = "Schulterversatz"
L["Camera's horizontal position relative to the character."] =
  "Horizontale Position der Kamera relativ zum Charakter."
L["Disable Offset With Mouselook"] = "Versatz bei Mausblick deaktivieren"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "Der Schulterversatz geht beim Deaktivieren des Mausblicks sanft auf 0 zurück."
L["When off, Shoulder Offset stays constant at all times."] =
  "Wenn deaktiviert, bleibt der Schulterversatz immer konstant."
L["Swap Shoulder Keybind"] = "Taste für Schulterwechsel"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Drücken, um den Schulterversatz auf die andere Seite deines Charakters zu spiegeln."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Zusätzliche Funktionen, die mit dem Verhalten des Mausblicks verknüpft sind."
L["Cursor Pulse"] = "Cursor-Puls"
L["Flash the cursor when Mouse Look is turned off."] =
  "Lässt den Cursor aufblinken, wenn der Mausblick deaktiviert wird."
L["Hide Tooltips"] = "Tooltips ausblenden"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Blendet Tooltips aus, solange der Mausblick aktiv ist, außer die Taste unten wird gehalten."
L["Show Tooltips With"] = "Tooltips anzeigen mit"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Halte diese Taste gedrückt, um Tooltips bei aktivem Mausblick anzuzeigen."
L["Auto Sheath"] = "Automatisch wegstecken"
L["Sheath weapons automatically with Mouse Look."] =
  "Steckt Waffen automatisch mit dem Mausblick weg."
L["Vignette Shows When"] = "Vignette erscheint bei"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Dunkelt die Bildschirmränder ab, solange die markierten Situationen zutreffen."
L["Vignette Match"] = "Vignette-Bedingung"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "Beliebige: Eine markierte Situation genügt. Alle: Jede markierte Situation muss gleichzeitig zutreffen."

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Jedes feste Ziel"
L["Locked Target Only"] = "Nur gesperrtes Ziel"
L["Soft Target (Blizzard)"] = "Weiches Ziel (Blizzard)"
L["Hidden"] = "Ausgeblendet"
L["Toggle"] = "Umschalten"
L["Switch Target"] = "Ziel wechseln"
L["A UI Reload is required when making this change. Proceed?"] =
  "Für diese Änderung ist ein Neuladen der Benutzeroberfläche erforderlich. Fortfahren?"
L["Create New Macro"] = "Neues Makro erstellen"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Schreibe ein Makro, das mit deiner Fadenkreuz-Zielerfassungs-Vorzeile beginnt."
L["Unavailable in combat."] = "Im Kampf nicht verfügbar."
L["Drag to a button on your action bars to use."] =
  "Zum Verwenden auf eine Schaltfläche deiner Aktionsleisten ziehen."
L["Right-click to edit"] = "Rechtsklick zum Bearbeiten"
L["+%d more in /macro"] = "+%d weitere in /macro"
L["Reticle Targeting Macros"] = "Fadenkreuz-Zielerfassungs-Makros"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "Aktionsschaltflächen, die Makros sind, übernehmen die Fadenkreuz-Zielerfassung nicht automatisch. Damit sie diese Regeln befolgen, erstelle sie mit dem Makro-Editor und ziehe sie dann auf deine Leisten."
L["Reticle Targeting"] = "Fadenkreuz-Zielerfassung"
L["RETICLE TARGETING"] = "FADENKREUZ-ZIELERFASSUNG"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Ermöglicht zielgerichtete Einheitenauswahl per Fadenkreuz und präzises Platzieren von Bodenzaubern und Flächenfähigkeiten."
L["Enable Reticle Targeting"] = "Fadenkreuz-Zielerfassung aktivieren"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Ziele mit dem Fadenkreuz auf Einheiten, um Ziele statt per Tab-Auswahl zu wählen."
L["Ignore Friendlies"] = "Freundliche ignorieren"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Ignoriert freundliche NPCs und Spieler und wählt nur feindliche Einheiten."
L["Click Casting Only"] = "Nur Klick-Zauber"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "Wendet die Fadenkreuz-Zielerfassung nur auf Klick-Zauber-Belegungen an."
L["Excluded Spells"] = "Ausgeschlossene Zauber"
L["Spells to skip the reticle targeting logic."] =
  "Zauber, die die Fadenkreuz-Zielerfassung überspringen."
L["Cast at Crosshair"] = "Auf Fadenkreuz wirken"
L["Ground spells to cast at the crosshair location."] =
  "Bodenzauber, die an der Fadenkreuzposition gewirkt werden."
L["TARGET LOCK"] = "ZIELSPERRE"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Sperre ein Ziel, um versehentliches Wechseln zu verhindern, und wechsle zwischen Einheiten, um bestimmte Gegner zu priorisieren."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Warnung: Die Zielsperre nutzt dein Fokusziel. Alles andere, was deinen Fokus setzt, stört sie."
L["Target Lock Keybind"] = "Taste für Zielsperre"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Sperrt das Fadenkreuz auf ein Ziel, sodass es nicht wechselt."
L["Cycle Lock - Next"] = "Sperre wechseln – Nächstes"
L["Move Target Lock to the next valid nearby target."] =
  "Verschiebt die Zielsperre auf das nächste gültige Ziel in der Nähe."
L["Cycle Lock - Previous"] = "Sperre wechseln – Vorheriges"
L["Move Target Lock to the previous valid nearby target."] =
  "Verschiebt die Zielsperre auf das vorherige gültige Ziel in der Nähe."
L["Target Lock Behavior"] = "Verhalten der Zielsperre"
L["What the Target Lock key does when you press it."] =
  "Was die Taste für die Zielsperre beim Drücken bewirkt."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Sperrt dein Ziel oder die Einheit unter dem Fadenkreuz. Erneutes Antippen hebt die Sperre auf."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Sperrt die Einheit unter dem Fadenkreuz und ersetzt eine bestehende Sperre. Antippen ohne Einheit unter dem Fadenkreuz hebt die Sperre auf. Zielst du auf die bereits gesperrte Einheit, bleibt die Sperre bestehen."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Bei aktivem „Freundliche ignorieren“ wird eine freundliche oder tote Einheit unter dem Fadenkreuz ignoriert: Die Sperre bleibt bestehen."
L["Auto Target Lock"] = "Automatische Zielsperre"
L["Target Lock engages automatically when attacking units."] =
  "Die Zielsperre greift automatisch, wenn du Einheiten angreifst."
L["Target Lock Marker"] = "Zielsperren-Markierung"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Zeigt eine Fadenkreuz-Markierung auf der Namensplakette des gesperrten Ziels."
L["Focus Locked Target"] = "Gesperrtes Ziel fokussieren"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Zieht die Kamera zum gesperrten Ziel und hält es im Fokus."
L["TARGETING INDICATORS"] = "ZIELANZEIGEN"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Visuelle Anzeigen, die Ziele in der Welt hervorheben, damit sie leichter zu erkennen sind."
L["Target Outline"] = "Zielumriss"
L["Show an outline effect on your target."] = "Zeigt einen Umrisseffekt um dein Ziel."
L["Only available on Retail"] = "Nur auf Retail verfügbar"
L["Selection Circle"] = "Auswahlkreis"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "Welches Ziel Blizzards Auswahlkreis unter den Füßen erhält."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "Der Kreis unter allem, was du anvisiert hast, ob Feind oder Freund."
L["The circle only under your Target Lock."] = "Der Kreis nur unter deiner Zielsperre."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Blizzard steuert das Verhalten von ObjectSelectionCircle und UnitNameFocused."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "Blizzard wählt das weiche Ziel aus einem Bogen vor deinem Charaktermodell. Fadenkreuzposition und Schulterversatz werden dabei nicht berücksichtigt."
L["No selection circle."] = "Kein Auswahlkreis."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Fadenkreuz"
L["CROSSHAIR"] = "FADENKREUZ"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Ein dynamisches Fadenkreuz, das auf Ziele und Kampfzustände reagiert, die Präzision erhöht und die Fadenkreuz-Zielerfassung leitet."
L["Enable Crosshair"] = "Fadenkreuz aktivieren"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Zeigt im Mausblick ein dynamisches, reaktives Fadenkreuz auf dem Bildschirm an."
L["Cast Feedback"] = "Zauber-Rückmeldung"
L["Crosshair provides visual feedback while casting."] =
  "Das Fadenkreuz gibt beim Zaubern visuelles Feedback."
L["Appearance"] = "Aussehen"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Vom Fadenkreuz für jeden Zustand verwendete Texturen. Klicke auf eine, um ihre Textur zu wählen, oder beginne mit einer Vorlage."
L["Inactive"] = "Inaktiv"
L["Active"] = "Aktiv"
L["Mounted"] = "Beritten"
L["Disabled"] = "Deaktiviert"
L["Reaction Colors"] = "Reaktionsfarben"
L["Edit"] = "Bearbeiten"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Passe die Farben an, die das Fadenkreuz bei verschiedenen Einheitentypen verwendet."
L["Scale"] = "Skalierung"
L["Scales the size of the crosshair."] = "Skaliert die Größe des Fadenkreuzes."
L["Vertical Position"] = "Vertikale Position"
L["Move the crosshair up or down from screen center."] =
  "Verschiebt das Fadenkreuz von der Bildschirmmitte nach oben oder unten."
L["ASSIST HUD"] = "ASSIST-HUD"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "Ein HUD, das die Zauberrotation beim Anvisieren von Gegnern leitet und Interaktionshinweise anzeigt."
L["Next-cast Suggestion"] = "Vorschlag für den nächsten Zauber"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Zeigt den Vorschlag der Hervorhebungshilfe für den nächsten Zauber, während du ein Ziel anvisierst."
L["Always"] = "Immer"
L["Only In Combat"] = "Nur im Kampf"
L["Interactable Indicator"] = "Interaktionsanzeige"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Zeigt eine Anzeige, während du eine interagierbare Einheit oder ein Objekt anvisierst."
L["Player Interaction Prompt"] = "Spielerinteraktions-Hinweis"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Zeigt eine Anzeige, wenn du eine Sekunde lang auf einen Spieler zielst. Die Interaktionstaste öffnet dann sein Kontextmenü."
L["Position"] = "Position"
L["Which side of the crosshair the HUD appears on."] =
  "Auf welcher Seite des Fadenkreuzes das HUD erscheint."
L["Left"] = "Links"
L["Right"] = "Rechts"
L["Scales the size of the HUD."] = "Skaliert die Größe des HUDs."
L["Distance"] = "Abstand"
L["Distance between the HUD and the crosshair."] = "Abstand zwischen HUD und Fadenkreuz."
