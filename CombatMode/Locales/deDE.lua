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

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Geänderte Blizzard-Aktionen"
L["Blizzard Actions"] = "Blizzard-Aktionen"
L["Base"] = "Basis"
L["Shift"] = "Umschalt"
L["Ctrl"] = "Strg"
L["Alt"] = "Alt"
L["Clear Target"] = "Ziel löschen"
L["Clear Focus"] = "Fokus löschen"
L["Start Attack"] = "Angriff starten"
L["Pet Attack"] = "Begleiterangriff"
L["Toggle Focus Any"] = "Fokus umschalten (beliebig)"
L["Toggle Focus Enemy"] = "Fokus umschalten (Feind)"
L["Run MACRO"] = "MACRO ausführen"
L["— none —"] = "— keine —"
L["Override this click during Mouse Look."] = "Diesen Klick während des Mausblicks überschreiben."
L["Action"] = "Aktion"
L["Macro"] = "Makro"
L["Select a macro"] = "Makro auswählen"
L["No targeting"] = "Keine Zielerfassung"
L["Left Click"] = "Linksklick"
L["Right Click"] = "Rechtsklick"
L["Shift + Left Click"] = "Umschalt + Linksklick"
L["Shift + Right Click"] = "Umschalt + Rechtsklick"
L["Ctrl + Left Click"] = "Strg + Linksklick"
L["Ctrl + Right Click"] = "Strg + Rechtsklick"
L["Alt + Left Click"] = "Alt + Linksklick"
L["Alt + Right Click"] = "Alt + Rechtsklick"
L["Click Casting"] = "Klick-Zauberwirken"
L["CLICK CASTING"] = "KLICK-ZAUBERWIRKEN"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Weise dem Links- und Rechtsklick Aktionen zu, die während des Mausblicks aktiv sind."
L["Account-Wide Binds"] = "Accountweite Belegungen"
L["Share Click Casting binds across all characters."] =
  "Klick-Zauber-Belegungen für alle Charaktere teilen."
L["Click Binds"] = "Klick-Belegungen"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "Basis, Umschalt, Strg und Alt haben jeweils eigene Aktionen für Links- und Rechtsklick."

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Radialmenü-Räder"
L["Forever"] = "Forever"
L["Minimal"] = "Minimal"
L["Clear Slice"] = "Segment leeren"
L["UI Actions"] = "UI-Aktionen"
L["Emotes"] = "Emotes"
L["Commands"] = "Befehle"
L["Markers"] = "Markierungen"
L["Slice"] = "Segment"
L["Choose an action"] = "Aktion wählen"
L["Presets"] = "Vorlagen"
L["New Wheel"] = "Neues Rad"
L["Wheel"] = "Rad"
L["You can have up to %d wheels."] = "Du kannst bis zu %d Räder haben."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Das kann nicht auf ein Rad. Verwende einen Zauber, Gegenstand, ein Spielzeug, Reittier oder Makro."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Ziehe einen Zauber, Gegenstand, ein Spielzeug, Reittier oder Makro hierher oder klicke, um die Aktion zu ändern."
L["Empty Slice"] = "Leeres Segment"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Ziehe einen Zauber, Gegenstand, ein Spielzeug, Reittier oder Makro hierher oder klicke, um eine Aktion festzulegen. Leere Segmente werden im Rad weggelassen."
L["A wheel needs at least one slice."] = "Ein Rad braucht mindestens ein Segment."
L["Click to rename this wheel"] = "Klicken, um dieses Rad umzubenennen"
L["Previous wheel"] = "Vorheriges Rad"
L["Next wheel"] = "Nächstes Rad"
L["Click to select this wheel, drag to reorder"] =
  "Klicken, um dieses Rad auszuwählen; ziehen zum Umsortieren"
L["Add Slice"] = "Segment hinzufügen"
L["A wheel holds up to %d slices."] = "Ein Rad fasst bis zu %d Segmente."
L["Remove Wheel"] = "Rad entfernen"
L["Deletes this wheel and all of its slices."] = "Löscht dieses Rad und alle seine Segmente."
L["You need at least one wheel."] = "Du brauchst mindestens ein Rad."
L["Remove this wheel and all of its slices?"] = "Dieses Rad und alle seine Segmente entfernen?"
L["Add Wheel"] = "Rad hinzufügen"
L["Pick a preset wheel or a blank one."] = "Wähle ein vorgefertigtes oder ein leeres Rad."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Klicke auf ein Segment, um seine Aktion zu wählen, oder lege einen Zauber, Gegenstand, ein Spielzeug, Reittier oder Makro darauf ab.\nZiehe ein Segment, um es umzusortieren. Rechtsklick entfernt es."
L["RADIAL MENU"] = "RADIALMENÜ"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Erstelle Schnellzugriffsräder für Zauber, Gegenstände, Makros, Emotes und Oberflächenkürzel."
L["Radial Menu Keybind"] = "Radialmenü-Tastenbelegung"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Halten, um das Radialmenü zu öffnen, ein Segment anvisieren und zum Aktivieren loslassen. Mit dem Mausrad zwischen den Rädern wechseln."
L["Radial Menu Style"] = "Radialmenü-Stil"
L["Choose the appearance of the Radial Menu wheels."] =
  "Wähle das Aussehen der Radialmenü-Räder."
L["Party Wheel Spells"] = "Gruppenrad-Zauber"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Hilfreiche Zauber, die bei gehaltener Taste ein Gruppen-Zielrad öffnen. Wische zu einem Gruppenmitglied und lasse los, um ihn darauf zu wirken, oder kehre zur Mitte zurück, um dich selbst zu zielen. Kurz tippen wirkt auf dein freundliches Ziel, oder auf dich, wenn keins gewählt ist."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Bearbeite die Segmente jedes Rads, benenne Räder um und füge Räder hinzu oder entferne sie."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "Oben"
L["Bottom"] = "Unten"
L["Ally Cycle"] = "Verbündetenwechsel"
L["ALLY CYCLE"] = "VERBÜNDETENWECHSEL"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "Nahtloser Kampf und Support: Hilfreiche Zauber zielen auf Verbündete, schädliche Zauber bleiben auf das feindliche Ziel im Fadenkreuz gerichtet."
L["Ally Cycle - Next"] = "Verbündetenwechsel – Nächster"
L["Target the next group member."] = "Nächstes Gruppenmitglied anvisieren."
L["Ally Cycle - Previous"] = "Verbündetenwechsel – Vorheriger"
L["Target the previous group member."] = "Vorheriges Gruppenmitglied anvisieren."
L["Skip Self"] = "Sich selbst überspringen"
L["Skip yourself when cycling through group members."] =
  "Überspringt dich selbst beim Durchwechseln der Gruppenmitglieder."
L["Keep Ally After Harm"] = "Verbündeten nach Schaden behalten"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "Nachdem ein schädlicher Zauber den Feind im Fadenkreuz getroffen hat, wird der vorherige Verbündete wiederhergestellt. Für Heilerspezialisierungen standardmäßig aktiv, bis es geändert wird."
L["Disabled while Auto Target Lock is on"] =
  "Deaktiviert, solange Automatische Zielsperre aktiv ist"
L["ALLY HUD"] = "VERBÜNDETEN-HUD"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "Ein HUD, das das vom Verbündetenwechsel gewählte Gruppenmitglied anzeigt."
L["Ally HUD"] = "Verbündeten-HUD"
L["Show a unit frame for the currently selected group member."] =
  "Zeigt einen Einheitenrahmen für das aktuell gewählte Gruppenmitglied."
L["Where the Ally HUD sits relative to the crosshair."] =
  "Wo das Verbündeten-HUD relativ zum Fadenkreuz sitzt."
L["Scales the size of the Ally HUD."] = "Skaliert die Größe des Verbündeten-HUD."
L["Distance between the Ally HUD and the crosshair."] =
  "Abstand zwischen Verbündeten-HUD und Fadenkreuz."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "Auto-Entsperren"
L["AUTO UNLOCK"] = "AUTO-ENTSPERREN"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "Pausiert den Mausblick automatisch, wenn Fenster geöffnet werden, und setzt ihn fort, wenn sie geschlossen werden."
L["Release the cursor when UI panels open."] =
  "Gibt den Cursor frei, wenn Oberflächenfenster geöffnet werden."
L["Unlock Mounts"] = "Entsperrende Reittiere"
L["Mounts that force a cursor unlock while mounted."] =
  "Reittiere, die den Cursor freigeben, solange du sie nutzt."
L["Extra Frames"] = "Zusätzliche Fenster"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "Zusätzliche Fensternamen, die ein automatisches Entsperren auslösen. Tippe, um Blizzard- und Addon-Fenster zu suchen, oder klicke mit der Inspektionsschaltfläche ein Fenster auf dem Bildschirm an."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "Erweitert"
L["SOUNDS"] = "TÖNE"
L["Control the sound cues used by some of the other features."] =
  "Steuere die Tonsignale, die von einigen anderen Funktionen verwendet werden."
L["Mouse Look Sounds"] = "Mausblick-Töne"
L["Play a cue when Mouse Look turns on and off."] =
  "Spielt ein Signal, wenn der Mausblick ein- und ausgeschaltet wird."
L["Target Lock Sounds"] = "Zielsperre-Töne"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "Spielt Signale, wenn eine Zielsperre gesetzt, aufgehoben oder gewechselt wird."
L["Radial Menu Sounds"] = "Radialmenü-Töne"
L["Play cues when interacting with Radial Menu wheels."] =
  "Spielt Signale bei der Interaktion mit den Rädern des Radialmenüs."
L["Ally Cycle Sounds"] = "Verbündetenwechsel-Töne"
L["Play a cue when Ally Cycle moves to another ally."] =
  "Spielt ein Signal, wenn der Verbündetenwechsel zu einem anderen Verbündeten springt."
L["FORCE LOCK"] = "SPERRE ERZWINGEN"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "Eine erweiterte Option, die den Mausblick aktiv hält, solange eine eigene Lua-Bedingung wahr ist."
L["Custom Condition"] = "Eigene Bedingung"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "Eigener Lua-Code, der den Mausblick gesperrt hält, solange er wahr ergibt."
L["Lock Once"] = "Einmal sperren"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "Sperrt den Mausblick nur, wenn die Bedingung erstmals wahr wird. Ein manuelles Entsperren bleibt bestehen, bis die Bedingung falsch und dann wieder wahr wird."
L["FORCE UNLOCK"] = "ENTSPERREN ERZWINGEN"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "Das Gegenteil von „Sperre erzwingen“: hält den Mausblick aus, solange eine eigene Lua-Bedingung wahr ist."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "Eigener Lua-Code, der den Mausblick entsperrt hält, solange er wahr ergibt."
L["Unlock Once"] = "Einmal entsperren"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "Entsperrt den Mausblick nur, wenn die Bedingung erstmals wahr wird. Eine manuelle Sperre bleibt bestehen, bis die Bedingung falsch und dann wieder wahr wird."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "Tauscht das Aussehen des Fadenkreuzes aus, solange eine eigene Lua-Bedingung wahr ist."
L["Situational Appearance"] = "Situationsabhängiges Aussehen"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "Texturen, die das Fadenkreuz verwendet, solange die situative Bedingung wahr ist."
L["Situational Condition"] = "Situative Bedingung"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "Eigener Lua-Code, der das Fadenkreuz sein situatives Aussehen verwenden lässt, solange er wahr ergibt."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Ändere die Standard-CVars der Fadenkreuz-Zielerfassung und die Zielerfassungs-Makro-Prelines von Action Combat Mode."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "Warnung: Das Ändern dieser Werte kann die Fadenkreuz-Zielerfassung und die Zielsperre beeinträchtigen."
L["Reticle Targeting CVar Editor"] = "Fadenkreuz-Zielerfassung: CVar-Editor"
L["Targeting Macro Prelines Editor"] = "Editor für Zielerfassungs-Makro-Prelines"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "Zurück"
L["Next"] = "Weiter"
L["Finish"] = "Fertig"
L["Skip tour"] = "Tour überspringen"
L["Assist HUD"] = "Assistenz-HUD"
L["Target Lock"] = "Zielsperre"
L["Party Wheel"] = "Gruppenrad"
L["Set a Mouse Look key"] = "Mausblick-Taste festlegen"
L["Set an Interact key"] = "Interaktionstaste festlegen"
L["Set a Target Lock key"] = "Zielsperre-Taste festlegen"
L["Set a Cycle Lock - Next key"] = "Taste „Sperre wechseln – Nächster“ festlegen"
L["Set a Cycle Lock - Previous key"] = "Taste „Sperre wechseln – Vorheriger“ festlegen"
L["Set a Radial Menu key"] = "Radialmenü-Taste festlegen"
L["Set an Ally Cycle - Next key"] = "Taste „Verbündetenwechsel – Nächster“ festlegen"
L["Set an Ally Cycle - Previous key"] = "Taste „Verbündetenwechsel – Vorheriger“ festlegen"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "Das Ein- oder Ausschalten der Fadenkreuz-Zielerfassung lädt die Benutzeroberfläche neu."
L["Needs Reticle Targeting."] = "Benötigt die Fadenkreuz-Zielerfassung."
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "Fixiere deinen Cursor in der Bildschirmmitte und steuere durch Mausbewegung, ohne die rechte Maustaste zu halten.\n\nLege eine {Taste zum Umschalten} fest und eine {zum Interagieren} mit dem, worauf du zielst."
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "Ein reaktives, vollständig anpassbares Fadenkreuz, das sich an dein Ziel und den Kampfstatus anpasst.\n\nWähle {Aussehen}, {Größe} und {Position}."
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "Ziele auf einen Feind, und das HUD neben deinem Fadenkreuz schlägt deinen {nächsten Zauber} vor und zeigt dessen Taste.\n\nZiele auf etwas, mit dem du interagieren kannst, und es zeigt stattdessen dessen {Namen} und deine {Interaktionstaste}.\n\nSchalte beides ein oder aus und lege {Seite}, {Größe} und {Abstand} zum Fadenkreuz fest."
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "Erfasse Feinde allein durch Zielen und platziere Bodenzauber und Flächenfähigkeiten genau dort, wohin dein Fadenkreuz zeigt, ganz ohne Tab-Zielwahl.\n\n{Freundliche ignorieren} lässt Verbündete aus."
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "Bodenzauber, die an der Position des Fadenkreuzes gewirkt werden sollen.\n\nGib einen {Zaubernamen oder eine ID} ein, um ihn hinzuzufügen."
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!Aktionsschaltflächen, die Makros sind, können die Fadenkreuz-Zielerfassung nicht von selbst übernehmen.}\n\nDrücke {+}, um den {Makro-Composer} zu öffnen. Schreibe dort dein Makro, und die Zielerfassungslogik wird automatisch ergänzt.\n\nZiehe es dann aus dieser Liste auf deine Aktionsleisten; per {Rechtsklick} auf ein Symbol bearbeitest du es."
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "Fixiere mit einem Tastendruck ein Ziel, damit das Fadenkreuz nicht mehr wechselt. Solange gesperrt, springen die Wechseltasten zu Feinden in der Nähe.\n\n{Verhalten der Zielsperre} legt fest, ob erneutes Drücken entsperrt ({Umschalten}) oder die Sperre auf das verschiebt, was unter dem Fadenkreuz liegt ({Ziel wechseln}).\n\nLege deine Tasten fest."
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "Verwandle deine Mausklicks im Mausblick in Aktionen, etwa um Zauber deiner Aktionsleiste per {Links- und Rechtsklick} zu wirken.\n\nWähle, was jeder Klick bewirkt, mit oder ohne {Zusatztaste}."
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "Ein Rad mit deinen {Zaubern, Gegenständen, Makros und Kürzeln}, das auch im Kampf funktioniert.\n\nHalte die Taste, bewege die Maus zu einem Segment und lasse los, um es zu nutzen.\n\n{Scrolle}, um zwischen Rädern zu wechseln."
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "Halte die Taste eines hier aufgelisteten {hilfreichen Zaubers}, um ein Rad deiner Gruppenmitglieder zu öffnen. Bewege dich zu einem und lasse los, um ihn zu wirken, oder kehre in die {Mitte} zurück, um auf dich selbst zu wirken.\n\n{Tippe} die Taste kurz an, um auf dein freundliches Ziel zu wirken, oder auf dich selbst, wenn du keines hast.\n\nGib einen {Zaubernamen oder eine ID} ein, um ihn hinzuzufügen."
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "Wechsle im Mausblick durch Gruppenmitglieder, sodass {hilfreiche Zauber} den Verbündeten treffen, während {schädliche} weiter deinen Feind treffen.\n\nDas {Verbündeten-HUD} zeigt, wer ausgewählt ist.\n\nLege deine Wechseltasten fest."
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "Der Mausblick pausiert, wenn du {Taschen, die Karte oder andere Fenster} öffnest, und läuft danach weiter.\n\nFüge {Reittiere oder zusätzliche Fenster} hinzu, die ihn ebenfalls pausieren sollen."

-- Options UI: widgets, panel, search, pickers
L["What's New"] = "Neuigkeiten"
L["See what's new in this version"] = "Sieh dir an, was in dieser Version neu ist"
L["Link"] = "Link"
L["Copy the %s link (Ctrl+C), then paste it in your browser."] =
  "Kopiere den Link zu %s (Strg+C) und füge ihn in deinen Browser ein."
L["Character-specific option."] = "Charakterspezifische Option."
L["NEW"] = "NEU"
L["ON"] = "AN"
L["OFF"] = "AUS"
L["Are you sure?"] = "Bist du sicher?"
L["> Press key (ESC clears) <"] = "> Taste drücken (ESC löscht) <"
L["WoW API Documentation"] = "WoW-API-Dokumentation"
L["Pick a frame on screen"] = "Ein Fenster auf dem Bildschirm auswählen"
L["Pick a frame"] = "Fenster auswählen"
L["Silence Alerts"] = "Hinweise stummschalten"
L["Debug Mode"] = "Debug-Modus"
L["Reset to Defaults"] = "Auf Standard zurücksetzen"
L["Reset all Action Combat Mode settings to defaults and reload?"] =
  "Alle Einstellungen von Action Combat Mode auf Standard zurücksetzen und neu laden?"
L["Uninstall"] = "Deinstallieren"
L["Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload."] =
  "Action Combat Mode deinstallieren?\n\nDadurch werden deine vorherigen Kamera- und Zieleinstellungen wiederhergestellt, das Addon deaktiviert und die Oberfläche neu geladen."
L["View the changelog"] = "Änderungsprotokoll ansehen"
L["Run the setup wizard again?"] = "Den Einrichtungsassistenten erneut starten?"
L["Run the setup wizard"] = "Einrichtungsassistenten starten"
L["GitHub Repository"] = "GitHub-Repository"
L["Discord Server"] = "Discord-Server"
L["%s · Section"] = "%s · Abschnitt"
L["Sidebar"] = "Seitenleiste"
L["Search options..."] = "Optionen durchsuchen ..."
L["No matching options"] = "Keine passenden Optionen"
L["Section"] = "Abschnitt"
L["Tab"] = "Reiter"
L["Color"] = "Farbe"
L["Type spell name or ID…"] = "Zaubernamen oder ID eingeben …"
L["Type mount name or spell ID…"] = "Reittiernamen oder Zauber-ID eingeben …"
L["Type a frame name…"] = "Fensternamen eingeben …"
L["Blizzard"] = "Blizzard"
L["Addon"] = "Addon"
L["open"] = "geöffnet"
L["Click a frame to add it to the list. Right-click or press Esc to cancel."] =
  "Klicke auf ein Fenster, um es zur Liste hinzuzufügen. Rechtsklick oder Esc bricht ab."
L["Line %d: %s"] = "Zeile %d: %s"
L["Unknown API: %s - did you mean %s?"] = "Unbekannte API: %s – meintest du %s?"
L["Unknown API: %s"] = "Unbekannte API: %s"
L["%s (+%d more)"] = "%s (+%d weitere)"
L["Version: %s"] = "Version: %s"
L["Use the button below to open Action Combat Mode options."] =
  "Verwende die Schaltfläche unten, um die Optionen von Action Combat Mode zu öffnen."
L["You can also type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r in chat."] =
  "Du kannst auch |cff69ccf0/acm|r oder |cff69ccf0/actioncombatmode|r im Chat eingeben."
L["Open Options"] = "Optionen öffnen"
