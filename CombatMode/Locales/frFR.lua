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

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "VUE À LA SOURIS"
L["CAMERA FEATURES"] = "FONCTIONS DE CAMÉRA"
L["ADDITIONAL FEATURES"] = "FONCTIONS SUPPLÉMENTAIRES"
L["Crosshair - More accurate"] = "Réticule – Plus précis"
L["Soft Target - More forgiving"] = "Cible souple – Plus tolérant"
L["Mouse Look is on"] = "La vue à la souris est active"
L["In combat"] = "En combat"
L["Talking to an NPC"] = "En discussion avec un PNJ"
L["Any checked"] = "N'importe laquelle cochée"
L["All checked"] = "Toutes celles cochées"
L["Off"] = "Désactivé"
L["Control relinquished to %s"] = "Contrôle cédé à %s"
L["Disabled while Motion Sickness Protection is on"] =
  "Désactivé tant que la protection contre le mal des transports est active"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Verrouille le curseur sur la position du réticule et dirige en bougeant la souris, sans maintenir le clic droit."
L["Mouse Look Keybind"] = "Touche de vue à la souris"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Appuyez pour activer ou désactiver la vue à la souris. Maintenez pour libérer temporairement le curseur."
L["Interact Keybind"] = "Touche d'interaction"
L["Tap to interact with a player or the unit chosen below."] =
  "Appuyez pour interagir avec un joueur ou avec l'unité choisie ci-dessous."
L["Players"] = "Joueurs"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Visez un joueur pendant une seconde et l'ATH d'assistance affiche une invite. Appuyez alors sur la touche pour ouvrir son menu contextuel."
L["NPCs and objects"] = "PNJ et objets"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Interagit normalement avec l'unité choisie dans « Unité d'interaction »."
L["Interact Unit"] = "Unité d'interaction"
L["Which unit will be interacted with when the key is pressed."] =
  "L'unité avec laquelle on interagit lorsque la touche est pressée."
L["Flip Camera Keybind"] = "Touche de retournement de caméra"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Appuyez pour retourner la caméra à 180° autour de votre personnage. Maintenez pour ne la retourner que tant que la touche est maintenue."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Récupère un curseur bloqué après un changement de fenêtre sous macOS. Recapture puis relâche la vue à la souris pour supprimer une capture restée bloquée par le jeu en arrière-plan."
L["Curated camera adjustments for a more action-focused experience."] =
  "Réglages de caméra sélectionnés pour une expérience davantage axée sur l'action."
L["Motion Sickness Protection"] = "Protection contre le mal des transports"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Empêche Action Combat Mode de remplacer les réglages de mal des transports de Blizzard."
L["Turn Speed"] = "Vitesse de rotation"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Contrôle la vitesse de rotation de la caméra avec la vue à la souris."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Empêche la caméra de zoomer plus près que cette distance. 0 désactive l'option."
L["Dynamic Pitch"] = "Inclinaison dynamique"
L["Dynamically tilt the camera up and down as you move it."] =
  "Incline dynamiquement la caméra vers le haut et le bas lorsque vous la déplacez."
L["Pitch Strength"] = "Intensité d'inclinaison"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Degré d'inclinaison de la caméra par l'inclinaison dynamique. Des valeurs plus faibles gardent votre personnage plus haut à l'écran. En vol, l'inclinaison est plus forte et suit cette valeur."
L["Shoulder Offset"] = "Décalage d'épaule"
L["Camera's horizontal position relative to the character."] =
  "Position horizontale de la caméra par rapport au personnage."
L["Disable Offset With Mouselook"] = "Désactiver le décalage avec la vue à la souris"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "Le décalage d'épaule revient progressivement à 0 lors de la désactivation de la vue à la souris."
L["When off, Shoulder Offset stays constant at all times."] =
  "Désactivé, le décalage d'épaule reste constant en permanence."
L["Swap Shoulder Keybind"] = "Touche d'échange d'épaule"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Appuyez pour inverser le décalage d'épaule de l'autre côté de votre personnage."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Fonctions supplémentaires liées au comportement de la vue à la souris."
L["Cursor Pulse"] = "Pulsation du curseur"
L["Flash the cursor when Mouse Look is turned off."] =
  "Fait clignoter le curseur lorsque la vue à la souris est désactivée."
L["Hide Tooltips"] = "Masquer les infobulles"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Masque les infobulles lorsque la vue à la souris est active, sauf si la touche ci-dessous est maintenue."
L["Show Tooltips With"] = "Afficher les infobulles avec"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Maintenez cette touche pour afficher les infobulles lorsque la vue à la souris est active."
L["Auto Sheath"] = "Rengainer automatiquement"
L["Sheath weapons automatically with Mouse Look."] =
  "Rengaine automatiquement les armes avec la vue à la souris."
L["Vignette Shows When"] = "La vignette s'affiche quand"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Assombrit les bords de l'écran tant que les situations cochées sont vraies."
L["Vignette Match"] = "Condition de la vignette"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "N'importe laquelle : une seule situation cochée suffit. Toutes : chaque situation cochée doit être vraie en même temps."
