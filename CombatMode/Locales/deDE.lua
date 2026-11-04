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
