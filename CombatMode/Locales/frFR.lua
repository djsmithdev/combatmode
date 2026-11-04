---------------------------------------------------------------------------------------
--  Locales/frFR.lua — LOCALES — French strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the frFR client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "frFR", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "frFR" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Bienvenue dans Action Combat Mode !"
L["The configuration panel will open after you close this message."] =
  "Le panneau de configuration s'ouvrira après la fermeture de ce message."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Vous pouvez le rouvrir à tout moment avec |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Pour restaurer vos réglages précédents, utilisez le bouton |cffff5555Désinstaller|r du panneau d'options.|r"
L["Mouse Look"] = "Vue à la souris"
L["Flip Camera"] = "Inverser la caméra"
L["Swap Shoulder"] = "Changer d'épaule"
L["Reset Mouse Look"] = "Réinitialiser la vue à la souris"
L["Ally Cycle Next"] = "Cycle d'alliés : suivant"
L["Ally Cycle Previous"] = "Cycle d'alliés : précédent"
L["Toggle Focus Target"] = "Basculer la cible focalisée"
L["Cycle Focus Next"] = "Cycle de focalisation : suivant"
L["Cycle Focus Previous"] = "Cycle de focalisation : précédent"
L["Radial Menu"] = "Menu radial"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "changement de raccourci"
L["deferred %s until combat ends."] = "%s reporté jusqu'à la fin du combat."
L["failed to apply %s: %s"] = "échec de l'application de %s : %s"
L["applied deferred binding updates."] = "mises à jour de raccourcis reportées appliquées."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50%s détecté !|r Cession de la vitesse de rotation, de l'épaule et de l'inclinaison dynamique."
L["Cannot uninstall while in combat."] = "Impossible de désinstaller en combat."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "vos réglages précédents de caméra/ciblage et les raccourcis de caméra à la souris par défaut ont été restaurés, puis l'addon a été désactivé."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Tapez |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r pour ouvrir les réglages."
L["camera and targeting CVars restored."] = "CVars de caméra et de ciblage restaurées."
L["Cannot open settings while in combat."] = "Impossible d'ouvrir les réglages en combat."
L["Cannot open this editor while in combat."] = "Impossible d'ouvrir cet éditeur en combat."
L["Cannot open editor while in combat."] = "Impossible d'ouvrir l'éditeur en combat."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "impossible de modifier les CVars du ciblage par réticule en combat."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "impossible de réinitialiser les CVars du ciblage par réticule en combat."
L["MOVEANDSTEER unbind"] = "suppression du raccourci MOVEANDSTEER"
L["restore default mouse camera bindings"] =
  "restauration des raccourcis de caméra à la souris par défaut"
L["Minimum Zoom"] = "Zoom minimum"
L["ally cycle bindings"] = "raccourcis du cycle d'alliés"
L["radial menu"] = "menu radial"
L["target lock keybinding"] = "raccourci de verrouillage de cible"
L["cycle focus next keybinding"] = "raccourci du cycle de focalisation : suivant"
L["cycle focus previous keybinding"] = "raccourci du cycle de focalisation : précédent"
L["ally cycle next keybinding"] = "raccourci du cycle d'alliés : suivant"
L["ally cycle previous keybinding"] = "raccourci du cycle d'alliés : précédent"
L["radial menu keybinding"] = "raccourci du menu radial"
L["reticle interact keybinding"] = "raccourci d'interaction au réticule"
L["mouse look keybinding"] = "raccourci de la vue à la souris"
L["flip camera keybinding"] = "raccourci d'inversion de la caméra"
L["reset mouse look keybinding"] = "raccourci de réinitialisation de la vue à la souris"
L["swap shoulder keybinding"] = "raccourci de changement d'épaule"
