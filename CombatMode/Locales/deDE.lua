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
