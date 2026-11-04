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
