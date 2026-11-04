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
