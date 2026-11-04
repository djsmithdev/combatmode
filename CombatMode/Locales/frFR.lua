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

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Toute cible verrouillée"
L["Locked Target Only"] = "Cible verrouillée uniquement"
L["Soft Target (Blizzard)"] = "Cible souple (Blizzard)"
L["Hidden"] = "Masqué"
L["Toggle"] = "Basculer"
L["Switch Target"] = "Changer de cible"
L["A UI Reload is required when making this change. Proceed?"] =
  "Cette modification nécessite de recharger l'interface. Continuer ?"
L["Create New Macro"] = "Créer une nouvelle macro"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Écrivez une macro commençant par votre préligne de Ciblage par réticule."
L["Unavailable in combat."] = "Indisponible en combat."
L["Drag to a button on your action bars to use."] =
  "Faites-la glisser sur un bouton de vos barres d'action pour l'utiliser."
L["Right-click to edit"] = "Clic droit pour modifier"
L["+%d more in /macro"] = "+%d de plus dans /macro"
L["Reticle Targeting Macros"] = "Macros de ciblage par réticule"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "Les boutons d'action qui sont des macros n'héritent pas automatiquement de la logique du Ciblage par réticule. Pour qu'ils la respectent, créez-les avec l'outil Compositeur de macros, puis faites-les glisser sur vos barres."
L["Reticle Targeting"] = "Ciblage par réticule"
L["RETICLE TARGETING"] = "CIBLAGE PAR RÉTICULE"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Permet de cibler des unités en visant et de placer précisément les sorts au sol et les capacités de zone."
L["Enable Reticle Targeting"] = "Activer le ciblage par réticule"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Visez des unités avec le réticule pour choisir vos cibles au lieu du ciblage par tabulation."
L["Ignore Friendlies"] = "Ignorer les amis"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Ignore les PNJ et joueurs amicaux et ne cible que les unités hostiles."
L["Click Casting Only"] = "Lancement par clic uniquement"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "N'applique la logique de ciblage par réticule qu'aux raccourcis de lancement par clic."
L["Excluded Spells"] = "Sorts exclus"
L["Spells to skip the reticle targeting logic."] =
  "Sorts qui ignorent la logique de ciblage par réticule."
L["Cast at Crosshair"] = "Lancer au réticule"
L["Ground spells to cast at the crosshair location."] =
  "Sorts au sol à lancer à l'emplacement du réticule."
L["TARGET LOCK"] = "VERROUILLAGE DE CIBLE"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Verrouillez une cible pour éviter les changements accidentels et alternez entre les unités pour prioriser certains ennemis."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Attention : le Verrouillage de cible utilise votre cible focalisée. Tout ce qui modifie votre focus le perturbera."
L["Target Lock Keybind"] = "Touche de verrouillage de cible"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Verrouille le réticule sur une cible pour l'empêcher de changer."
L["Cycle Lock - Next"] = "Cycler le verrouillage – Suivant"
L["Move Target Lock to the next valid nearby target."] =
  "Déplace le verrouillage sur la prochaine cible valide à proximité."
L["Cycle Lock - Previous"] = "Cycler le verrouillage – Précédent"
L["Move Target Lock to the previous valid nearby target."] =
  "Déplace le verrouillage sur la cible valide précédente à proximité."
L["Target Lock Behavior"] = "Comportement du verrouillage de cible"
L["What the Target Lock key does when you press it."] =
  "Ce que fait la touche de verrouillage de cible lorsque vous l'appuyez."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Verrouille votre cible ou l'unité sous le réticule. Appuyez à nouveau pour déverrouiller."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Verrouille l'unité sous le réticule en remplaçant tout verrouillage actuel. Appuyez sans rien sous le réticule pour déverrouiller. Viser l'unité déjà verrouillée conserve le verrouillage."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Avec « Ignorer les amis » activé, une unité amicale ou morte sous le réticule est ignorée : le verrouillage reste en place."
L["Auto Target Lock"] = "Verrouillage de cible automatique"
L["Target Lock engages automatically when attacking units."] =
  "Le verrouillage de cible s'active automatiquement lorsque vous attaquez des unités."
L["Target Lock Marker"] = "Marqueur de verrouillage"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Affiche un marqueur de réticule sur la barre de nom de la cible verrouillée."
L["Focus Locked Target"] = "Focaliser la cible verrouillée"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Attire la caméra vers votre cible verrouillée pour la garder au centre."
L["TARGETING INDICATORS"] = "INDICATEURS DE CIBLE"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Indicateurs visuels qui mettent en évidence les cibles dans le monde pour les repérer plus facilement."
L["Target Outline"] = "Contour de la cible"
L["Show an outline effect on your target."] = "Affiche un effet de contour sur votre cible."
L["Only available on Retail"] = "Disponible uniquement sur Retail"
L["Selection Circle"] = "Cercle de sélection"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "Quelle cible reçoit le cercle de sélection de Blizzard sous ses pieds."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "Le cercle sous toute cible, ennemie ou amicale."
L["The circle only under your Target Lock."] = "Le cercle uniquement sous votre cible verrouillée."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Laisse Blizzard gérer le comportement de ObjectSelectionCircle et UnitNameFocused."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "Blizzard choisit la cible souple dans un arc devant le modèle de votre personnage. Elle ne tient compte ni de la position du réticule ni du décalage d'épaule."
L["No selection circle."] = "Aucun cercle de sélection."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Réticule"
L["CROSSHAIR"] = "RÉTICULE"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Un réticule dynamique qui réagit aux cibles et aux états de combat, améliore la précision et guide le ciblage par réticule."
L["Enable Crosshair"] = "Activer le réticule"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Affiche à l'écran un réticule dynamique et réactif pendant la vue à la souris."
L["Cast Feedback"] = "Retour visuel d'incantation"
L["Crosshair provides visual feedback while casting."] =
  "Le réticule fournit un retour visuel pendant l'incantation."
L["Appearance"] = "Apparence"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Textures utilisées par le réticule pour chaque état. Cliquez sur l'une pour choisir sa texture, ou partez d'un préréglage."
L["Inactive"] = "Inactif"
L["Active"] = "Actif"
L["Mounted"] = "Monté"
L["Disabled"] = "Désactivé"
L["Reaction Colors"] = "Couleurs de réaction"
L["Edit"] = "Modifier"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Personnalisez les couleurs utilisées par le réticule selon le type d'unité ciblée."
L["Scale"] = "Échelle"
L["Scales the size of the crosshair."] = "Modifie la taille du réticule."
L["Vertical Position"] = "Position verticale"
L["Move the crosshair up or down from screen center."] =
  "Déplace le réticule vers le haut ou le bas depuis le centre de l'écran."
L["ASSIST HUD"] = "ATH D'ASSISTANCE"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "Un ATH qui guide la rotation des sorts face aux ennemis et affiche les invites d'interaction."
L["Next-cast Suggestion"] = "Suggestion du prochain sort"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Affiche la suggestion du prochain sort de la mise en évidence assistée pendant que vous visez une cible."
L["Always"] = "Toujours"
L["Only In Combat"] = "En combat uniquement"
L["Interactable Indicator"] = "Indicateur d'interaction"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Affiche un indicateur lorsque vous visez une unité ou un objet avec lequel interagir."
L["Player Interaction Prompt"] = "Invite d'interaction avec les joueurs"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Affiche un indicateur lorsque vous visez un joueur pendant une seconde. Appuyer sur la touche d'interaction ouvre son menu contextuel."
L["Position"] = "Position"
L["Which side of the crosshair the HUD appears on."] =
  "De quel côté du réticule l'ATH apparaît."
L["Left"] = "Gauche"
L["Right"] = "Droite"
L["Scales the size of the HUD."] = "Modifie la taille de l'ATH."
L["Distance"] = "Distance"
L["Distance between the HUD and the crosshair."] = "Distance entre l'ATH et le réticule."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Actions Blizzard modifiées"
L["Blizzard Actions"] = "Actions Blizzard"
L["Base"] = "Base"
L["Shift"] = "Maj"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "Effacer la cible"
L["Clear Focus"] = "Effacer le focus"
L["Start Attack"] = "Lancer l'attaque"
L["Pet Attack"] = "Attaque du familier"
L["Toggle Focus Any"] = "Basculer le focus (tout)"
L["Toggle Focus Enemy"] = "Basculer le focus (ennemi)"
L["Run MACRO"] = "Exécuter MACRO"
L["— none —"] = "— aucune —"
L["Override this click during Mouse Look."] = "Remplace ce clic pendant la vue à la souris."
L["Action"] = "Action"
L["Macro"] = "Macro"
L["Select a macro"] = "Choisir une macro"
L["No targeting"] = "Pas de ciblage"
L["Left Click"] = "Clic gauche"
L["Right Click"] = "Clic droit"
L["Shift + Left Click"] = "Maj + Clic gauche"
L["Shift + Right Click"] = "Maj + Clic droit"
L["Ctrl + Left Click"] = "Ctrl + Clic gauche"
L["Ctrl + Right Click"] = "Ctrl + Clic droit"
L["Alt + Left Click"] = "Alt + Clic gauche"
L["Alt + Right Click"] = "Alt + Clic droit"
L["Click Casting"] = "Lancer par clic"
L["CLICK CASTING"] = "LANCER PAR CLIC"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Attribue des actions de remplacement aux clics gauche et droit, actives pendant la vue à la souris."
L["Account-Wide Binds"] = "Raccourcis communs au compte"
L["Share Click Casting binds across all characters."] =
  "Partage les raccourcis de lancer par clic entre tous les personnages."
L["Click Binds"] = "Raccourcis de clic"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "Base, Maj, Ctrl et Alt ont chacun leurs propres actions de clic gauche et droit."

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Roues du menu radial"
L["Forever"] = "Forever"
L["Minimal"] = "Minimal"
L["Clear Slice"] = "Vider la part"
L["UI Actions"] = "Actions d'interface"
L["Emotes"] = "Emotes"
L["Commands"] = "Commandes"
L["Markers"] = "Marqueurs"
L["Slice"] = "Part"
L["Choose an action"] = "Choisir une action"
L["Presets"] = "Préréglages"
L["New Wheel"] = "Nouvelle roue"
L["Wheel"] = "Roue"
L["You can have up to %d wheels."] = "Vous pouvez avoir jusqu'à %d roues."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Cela ne peut pas aller sur une roue. Utilisez un sort, un objet, un jouet, une monture ou une macro."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Faites glisser ici un sort, un objet, un jouet, une monture ou une macro, ou cliquez pour changer l'action."
L["Empty Slice"] = "Part vide"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Faites glisser ici un sort, un objet, un jouet, une monture ou une macro, ou cliquez pour définir une action. Les parts vides sont omises de la roue."
L["A wheel needs at least one slice."] = "Une roue a besoin d'au moins une part."
L["Click to rename this wheel"] = "Cliquez pour renommer cette roue"
L["Previous wheel"] = "Roue précédente"
L["Next wheel"] = "Roue suivante"
L["Click to select this wheel, drag to reorder"] =
  "Cliquez pour sélectionner cette roue, faites glisser pour réorganiser"
L["Add Slice"] = "Ajouter une part"
L["A wheel holds up to %d slices."] = "Une roue contient jusqu'à %d parts."
L["Remove Wheel"] = "Supprimer la roue"
L["Deletes this wheel and all of its slices."] = "Supprime cette roue et toutes ses parts."
L["You need at least one wheel."] = "Il faut au moins une roue."
L["Remove this wheel and all of its slices?"] = "Supprimer cette roue et toutes ses parts ?"
L["Add Wheel"] = "Ajouter une roue"
L["Pick a preset wheel or a blank one."] = "Choisissez une roue prédéfinie ou une roue vierge."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Cliquez sur une part pour choisir son action, ou déposez dessus un sort, un objet, un jouet, une monture ou une macro.\nFaites glisser une part pour la réorganiser. Clic droit pour la supprimer."
L["RADIAL MENU"] = "MENU RADIAL"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Créez des roues d'accès rapide pour vos sorts, objets, macros, emotes et raccourcis d'interface."
L["Radial Menu Keybind"] = "Raccourci du menu radial"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Maintenez pour ouvrir le menu radial, visez une part, puis relâchez pour l'activer. Utilisez la molette pour changer de roue."
L["Radial Menu Style"] = "Style du menu radial"
L["Choose the appearance of the Radial Menu wheels."] =
  "Choisissez l'apparence des roues du menu radial."
L["Party Wheel Spells"] = "Sorts de la roue de groupe"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Sorts bénéfiques qui ouvrent une roue de ciblage de groupe tant que leur touche est maintenue. Dirigez-vous vers un membre du groupe et relâchez pour le lancer sur lui, ou revenez au centre pour le lancer sur vous. Une simple pression le lance sur votre cible amie, ou sur vous si aucune n'est sélectionnée."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Modifiez les parts de chaque roue, renommez-les et ajoutez ou supprimez des roues."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "Haut"
L["Bottom"] = "Bas"
L["Ally Cycle"] = "Cycle d'alliés"
L["ALLY CYCLE"] = "CYCLE D'ALLIÉS"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "Combat et soutien fluides : les sorts bénéfiques ciblent les alliés, tandis que les sorts offensifs restent dirigés vers l'ennemi visé par le réticule."
L["Ally Cycle - Next"] = "Cycle d'alliés – Suivant"
L["Target the next group member."] = "Cible le membre de groupe suivant."
L["Ally Cycle - Previous"] = "Cycle d'alliés – Précédent"
L["Target the previous group member."] = "Cible le membre de groupe précédent."
L["Skip Self"] = "S'ignorer"
L["Skip yourself when cycling through group members."] =
  "Vous ignore lors du parcours des membres du groupe."
L["Keep Ally After Harm"] = "Garder l'allié après une attaque"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "Après un sort offensif sur l'ennemi du réticule, rétablit l'allié précédent. Activé par défaut pour les spécialisations de soigneur jusqu'à modification."
L["Disabled while Auto Target Lock is on"] =
  "Désactivé tant que le Verrouillage de cible automatique est actif"
L["ALLY HUD"] = "HUD D'ALLIÉ"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "Un HUD affichant le membre du groupe sélectionné par le cycle d'alliés."
L["Ally HUD"] = "HUD d'allié"
L["Show a unit frame for the currently selected group member."] =
  "Affiche un cadre d'unité pour le membre du groupe actuellement sélectionné."
L["Where the Ally HUD sits relative to the crosshair."] =
  "Position du HUD d'allié par rapport au réticule."
L["Scales the size of the Ally HUD."] = "Ajuste la taille du HUD d'allié."
L["Distance between the Ally HUD and the crosshair."] =
  "Distance entre le HUD d'allié et le réticule."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "Déverrouillage auto"
L["AUTO UNLOCK"] = "DÉVERROUILLAGE AUTO"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "Met automatiquement la vue à la souris en pause à l'ouverture de fenêtres et la reprend à leur fermeture."
L["Release the cursor when UI panels open."] =
  "Libère le curseur à l'ouverture de panneaux d'interface."
L["Unlock Mounts"] = "Montures qui déverrouillent"
L["Mounts that force a cursor unlock while mounted."] =
  "Montures qui libèrent le curseur tant que vous êtes monté."
L["Extra Frames"] = "Cadres supplémentaires"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "Noms de cadres supplémentaires qui déclenchent le déverrouillage automatique. Tapez pour chercher parmi les cadres de Blizzard et des addons, ou utilisez le bouton d'inspection pour cliquer sur une fenêtre à l'écran."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "Avancé"
L["SOUNDS"] = "SONS"
L["Control the sound cues used by some of the other features."] =
  "Contrôlez les signaux sonores utilisés par certaines autres fonctions."
L["Mouse Look Sounds"] = "Sons de la vue à la souris"
L["Play a cue when Mouse Look turns on and off."] =
  "Joue un signal lorsque la vue à la souris s'active ou se désactive."
L["Target Lock Sounds"] = "Sons du verrouillage de cible"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "Joue des signaux lorsqu'un verrouillage de cible est posé, retiré ou changé."
L["Radial Menu Sounds"] = "Sons du menu radial"
L["Play cues when interacting with Radial Menu wheels."] =
  "Joue des signaux lors de l'interaction avec les roues du menu radial."
L["Ally Cycle Sounds"] = "Sons du cycle d'alliés"
L["Play a cue when Ally Cycle moves to another ally."] =
  "Joue un signal lorsque le cycle d'alliés passe à un autre allié."
L["FORCE LOCK"] = "FORCER LE VERROUILLAGE"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "Une option avancée qui garde la vue à la souris activée tant qu'une condition Lua personnalisée est vraie."
L["Custom Condition"] = "Condition personnalisée"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "Code Lua personnalisé qui, tant qu'il vaut vrai, maintient la vue à la souris verrouillée."
L["Lock Once"] = "Verrouiller une fois"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "Verrouille la vue à la souris uniquement lorsque la condition devient vraie pour la première fois. Un déverrouillage manuel reste en vigueur jusqu'à ce que la condition devienne fausse puis de nouveau vraie."
L["FORCE UNLOCK"] = "FORCER LE DÉVERROUILLAGE"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "L'opposé de Forcer le verrouillage : garde la vue à la souris désactivée tant qu'une condition Lua personnalisée est vraie."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "Code Lua personnalisé qui, tant qu'il vaut vrai, maintient la vue à la souris déverrouillée."
L["Unlock Once"] = "Déverrouiller une fois"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "Déverrouille la vue à la souris uniquement lorsque la condition devient vraie pour la première fois. Un verrouillage manuel reste en vigueur jusqu'à ce que la condition devienne fausse puis de nouveau vraie."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "Change l'apparence du réticule tant qu'une condition Lua personnalisée est vraie."
L["Situational Appearance"] = "Apparence situationnelle"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "Textures utilisées par le réticule tant que la condition situationnelle est vraie."
L["Situational Condition"] = "Condition situationnelle"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "Code Lua personnalisé qui, tant qu'il vaut vrai, force le réticule à utiliser son apparence situationnelle."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Modifiez les CVars par défaut du ciblage par réticule et les prélignes de macro de ciblage d'Action Combat Mode."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "Attention : modifier ces valeurs pourrait casser le ciblage par réticule et le verrouillage de cible."
L["Reticle Targeting CVar Editor"] = "Éditeur de CVars du ciblage par réticule"
L["Targeting Macro Prelines Editor"] = "Éditeur de prélignes de macro de ciblage"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "Retour"
L["Next"] = "Suivant"
L["Finish"] = "Terminer"
L["Skip tour"] = "Passer la visite"
L["Assist HUD"] = "HUD d'assistance"
L["Target Lock"] = "Verrouillage de cible"
L["Party Wheel"] = "Roue de groupe"
L["Set a Mouse Look key"] = "Définissez une touche de vue à la souris"
L["Set an Interact key"] = "Définissez une touche d'interaction"
L["Set a Target Lock key"] = "Définissez une touche de verrouillage de cible"
L["Set a Cycle Lock - Next key"] = "Définissez une touche Cycle de verrouillage – Suivant"
L["Set a Cycle Lock - Previous key"] =
  "Définissez une touche Cycle de verrouillage – Précédent"
L["Set a Radial Menu key"] = "Définissez une touche du menu radial"
L["Set an Ally Cycle - Next key"] = "Définissez une touche Cycle d'alliés – Suivant"
L["Set an Ally Cycle - Previous key"] = "Définissez une touche Cycle d'alliés – Précédent"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "Activer ou désactiver le ciblage par réticule recharge l'interface."
L["Needs Reticle Targeting."] = "Nécessite le ciblage par réticule."
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "Verrouillez votre curseur au centre de l'écran et dirigez-vous en bougeant la souris, sans maintenir le clic droit.\n\nDéfinissez une {touche pour l'activer} et {une pour interagir} avec ce que vous visez."
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "Un réticule réactif et entièrement personnalisable qui s'adapte à votre cible et à l'état de combat.\n\nChoisissez son {apparence}, sa {taille} et sa {position}."
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "Visez un ennemi et le HUD à côté de votre réticule suggère votre {prochain sort} et affiche sa touche.\n\nVisez quelque chose avec quoi interagir et il affiche son {nom} et votre {touche d'interaction}.\n\nActivez ou désactivez chacun, et réglez son {côté}, sa {taille} et sa {distance} par rapport au réticule."
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "Ciblez les ennemis simplement en les visant et lancez sorts au sol et capacités de zone exactement là où pointe votre réticule, sans ciblage par tabulation.\n\n{Ignorer les amis} lui fait ignorer les alliés."
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "Sorts au sol qui doivent être lancés à l'emplacement du réticule.\n\nSaisissez un {nom ou ID de sort} pour l'ajouter."
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!Les boutons d'action qui sont des macros ne peuvent pas hériter seuls du ciblage par réticule.}\n\nAppuyez sur {+} pour ouvrir le {Compositeur de macros}, écrivez-y votre macro et la logique de ciblage sera ajoutée pour vous.\n\nFaites-la ensuite glisser depuis cette liste vers vos barres d'action ; {clic droit} sur une icône pour la modifier."
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "Verrouillez une cible d'une pression pour que le réticule cesse de changer. Une fois verrouillé, les touches de cycle passent aux ennemis proches.\n\n{Comportement du verrouillage de cible} décide si une nouvelle pression déverrouille ({Basculer}) ou déplace le verrou sur ce qui est sous le réticule ({Changer de cible}).\n\nDéfinissez vos touches."
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "Transformez vos clics de souris en actions pendant la vue à la souris, par exemple lancer les sorts de votre barre d'action avec {clic gauche et droit}.\n\nChoisissez ce que fait chaque clic, avec ou sans {touche de modification}."
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "Une roue de vos {sorts, objets, macros et raccourcis} utilisable en combat.\n\nMaintenez sa touche, déplacez la souris vers une part et relâchez pour l'utiliser.\n\n{Faites défiler} pour passer d'une roue à l'autre."
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "Maintenez la touche d'un {sort bénéfique} listé ici pour ouvrir une roue de vos membres de groupe. Déplacez-vous vers l'un d'eux et relâchez pour lancer le sort sur lui, ou revenez au {centre} pour le lancer sur vous.\n\n{Appuyez brièvement} sur la touche pour lancer sur votre cible amie, ou sur vous-même si vous n'en avez pas.\n\nSaisissez un {nom ou ID de sort} pour l'ajouter."
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "Parcourez les membres du groupe en vue à la souris pour que les {sorts bénéfiques} aillent à l'allié tandis que les {sorts offensifs} continuent de frapper votre ennemi.\n\nLe {HUD d'allié} indique qui est sélectionné.\n\nDéfinissez vos touches de cycle."
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "La vue à la souris se met en pause quand vous ouvrez {les sacs, la carte ou d'autres fenêtres}, puis reprend.\n\nAjoutez des {montures ou fenêtres supplémentaires} qui doivent aussi la mettre en pause."

-- Options UI: widgets, panel, search, pickers
L["What's New"] = "Nouveautés"
L["See what's new in this version"] = "Découvrez les nouveautés de cette version"
L["Link"] = "lien"
L["Copy the %s link (Ctrl+C), then paste it in your browser."] =
  "Copiez le lien vers %s (Ctrl+C), puis collez-le dans votre navigateur."
L["Character-specific option."] = "Option propre au personnage."
L["NEW"] = "NOUVEAU"
L["ON"] = "OUI"
L["OFF"] = "NON"
L["Are you sure?"] = "Êtes-vous sûr ?"
L["> Press key (ESC clears) <"] = "> Appuyez sur une touche (Échap efface) <"
L["WoW API Documentation"] = "Documentation de l'API WoW"
L["Pick a frame on screen"] = "Choisir un cadre à l'écran"
L["Pick a frame"] = "Choisir un cadre"
L["Silence Alerts"] = "Désactiver les alertes"
L["Debug Mode"] = "Mode débogage"
L["Reset to Defaults"] = "Rétablir les valeurs par défaut"
L["Reset all Action Combat Mode settings to defaults and reload?"] =
  "Rétablir tous les réglages d'Action Combat Mode et recharger ?"
L["Uninstall"] = "Désinstaller"
L["Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload."] =
  "Désinstaller Action Combat Mode ?\n\nCela rétablira vos anciens réglages de caméra et de ciblage, désactivera l'addon et rechargera l'interface."
L["View the changelog"] = "Voir le journal des modifications"
L["Run the setup wizard again?"] = "Relancer l'assistant de configuration ?"
L["Run the setup wizard"] = "Lancer l'assistant de configuration"
L["GitHub Repository"] = "Dépôt GitHub"
L["Discord Server"] = "Serveur Discord"
L["%s · Section"] = "%s · Section"
L["Sidebar"] = "Barre latérale"
L["Search options..."] = "Rechercher des options..."
L["No matching options"] = "Aucune option correspondante"
L["Section"] = "Section"
L["Tab"] = "Onglet"
L["Color"] = "Couleur"
L["Type spell name or ID…"] = "Saisissez le nom ou l'ID du sort…"
L["Type mount name or spell ID…"] = "Saisissez le nom de la monture ou l'ID du sort…"
L["Type a frame name…"] = "Saisissez un nom de cadre…"
L["Blizzard"] = "Blizzard"
L["Addon"] = "Addon"
L["open"] = "ouvert"
L["Click a frame to add it to the list. Right-click or press Esc to cancel."] =
  "Cliquez sur un cadre pour l'ajouter à la liste. Clic droit ou Échap pour annuler."
L["Line %d: %s"] = "Ligne %d : %s"
L["Unknown API: %s - did you mean %s?"] = "API inconnue : %s – vouliez-vous dire %s ?"
L["Unknown API: %s"] = "API inconnue : %s"
L["%s (+%d more)"] = "%s (+%d de plus)"
L["Version: %s"] = "Version : %s"
L["Use the button below to open Action Combat Mode options."] =
  "Utilisez le bouton ci-dessous pour ouvrir les options d'Action Combat Mode."
L["You can also type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r in chat."] =
  "Vous pouvez aussi saisir |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r dans le chat."
L["Open Options"] = "Ouvrir les options"

-- Editors: macro composer, prelines, crosshair colors and textures, CVar editor
L["%d / %d characters"] = "%d / %d caractères"
L["%s (over the macro limit)"] = "%s (au-dessus de la limite de la macro)"
L["Ignore Friendlies: %s"] = "Ignorer les amis : %s"
L["Auto Target Lock: %s"] = "Verrouillage de cible automatique : %s"
L["Preline: Ignore Friendlies + No Auto Lock"] =
  "Préligne : Ignorer les amis + sans verrouillage auto"
L["Preline: Ignore Friendlies + Auto Lock"] = "Préligne : Ignorer les amis + verrouillage auto"
L["Preline: Target Any Unit + No Auto Lock"] =
  "Préligne : Cibler n'importe quelle unité + sans verrouillage auto"
L["Preline: Target Any Unit + Auto Lock"] =
  "Préligne : Cibler n'importe quelle unité + verrouillage auto"
L["Macro Composer"] = "Compositeur de macros"
L["The targeting logic preline matching your current Reticle Targeting settings is added automatically before your lines, as the highlighted portion of the macro. To modify it, use the Prelines Editor under %s."] =
  "La préligne de ciblage correspondant à vos réglages actuels de ciblage par réticule est ajoutée automatiquement avant vos lignes, comme partie surlignée de la macro. Pour la modifier, utilisez l'éditeur de prélignes dans %s."
L["Macro Name"] = "Nom de la macro"
L["Enter a macro name"] = "Saisissez un nom de macro"
L["Saved to your general macros."] = "Enregistrée dans vos macros générales."
L["Saved to your character macros."] = "Enregistrée dans les macros de votre personnage."
L["Macro Text"] = "Texte de la macro"
L["Delete Macro"] = "Supprimer la macro"
L["Delete this macro? Any action bar button using it will be emptied."] =
  "Supprimer cette macro ? Tout bouton de barre d'action qui l'utilise sera vidé."
L["Save Macro"] = "Enregistrer la macro"
L["Preline must be %d characters or fewer (room for /click under the 255 macro limit)."] =
  "La préligne doit faire %d caractères ou moins (de la place pour /click sous la limite de 255 de la macro)."
L["Inactive — Auto Target Lock is OFF"] =
  "Inactif — Le verrouillage de cible automatique est DÉSACTIVÉ"
L["Inactive — Auto Target Lock is ON"] =
  "Inactif — Le verrouillage de cible automatique est ACTIVÉ"
L["Inactive — Ignore Friendlies is OFF"] = "Inactif — Ignorer les amis est DÉSACTIVÉ"
L["Inactive — Ignore Friendlies is ON"] = "Inactif — Ignorer les amis est ACTIVÉ"
L["Customize the targeting prelines injected before each ability when Reticle Targeting is enabled.\n\n• Only the preline matching your current %s X %s settings is active.\n• Max %s characters per preline — SecureActionButton macros are capped at %s; the rest is reserved for the trailing %s line.\n• Use %s to reload and pick up edits."] =
  "Personnalisez les prélignes de ciblage injectées avant chaque capacité lorsque le ciblage par réticule est activé.\n\n• Seule la préligne correspondant à vos réglages actuels %s X %s est active.\n• Maximum de %s caractères par préligne — les macros SecureActionButton sont limitées à %s ; le reste est réservé à la ligne finale %s.\n• Utilisez %s pour recharger et appliquer les modifications."
L["Apply Changes"] = "Appliquer les modifications"
L["Hostile"] = "Hostile"
L["NPC"] = "PNJ"
L["Player"] = "Joueur"
L["Object"] = "Objet"
L["Select a tab to customize the color and alpha of the crosshair when targeting different types of units.\n\n• %s and %s animations use the Hostile color.\n• Inactive crosshair states use the Base style."] =
  "Sélectionnez un onglet pour personnaliser la couleur et l'opacité du réticule selon le type d'unité ciblé.\n\n• Les animations de %s et de %s utilisent la couleur Hostile.\n• Les états inactifs du réticule utilisent le style Base."
L["Reset to Default"] = "Rétablir par défaut"
L["Show the inactive crosshair"] = "Afficher le réticule inactif"
L["Show the active crosshair"] = "Afficher le réticule actif"
L["Show the mounted crosshair"] = "Afficher le réticule en monture"
L["Show the disabled crosshair"] = "Afficher le réticule désactivé"
L["Hide the inactive crosshair"] = "Masquer le réticule inactif"
L["Hide the active crosshair"] = "Masquer le réticule actif"
L["Hide the mounted crosshair"] = "Masquer le réticule en monture"
L["Hide the disabled crosshair"] = "Masquer le réticule désactivé"
L["Nothing is drawn while you are not aiming at anything."] =
  "Rien n'est affiché tant que vous ne visez rien."
L["Nothing is drawn while you are aiming at a unit or object."] =
  "Rien n'est affiché tant que vous visez une unité ou un objet."
L["Nothing is drawn while you are mounted."] = "Rien n'est affiché lorsque vous êtes en monture."
L["Nothing is drawn while Target Lock holds the reticle."] =
  "Rien n'est affiché tant que le verrouillage de cible retient le réticule."
L["Not aiming at anything"] = "Ne vise rien"
L["Aiming at a unit or object"] = "Vise une unité ou un objet"
L["While you are mounted"] = "Lorsque vous êtes en monture"
L["While Target Lock holds"] = "Tant que le verrouillage de cible est actif"
L["Brings back the texture you had before hiding it."] =
  "Rétablit la texture que vous aviez avant de la masquer."
L["Crosshair Textures"] = "Textures du réticule"
L["Select a state, then pick a texture below, or apply a preset for a curated appearance."] =
  "Sélectionnez un état, puis choisissez une texture ci-dessous, ou appliquez un préréglage pour un rendu soigné."
L["INACTIVE"] = "INACTIF"
L["ACTIVE"] = "ACTIF"
L["MOUNTED"] = "EN MONTURE"
L["DISABLED"] = "DÉSACTIVÉ"
L["PRESETS"] = "PRÉRÉGLAGES"
L["ALL TEXTURES"] = "TOUTES LES TEXTURES"
L["Action Combat Mode (Reticle CVar Editor)"] =
  "Action Combat Mode (éditeur de CVars du réticule)"
L["External change (CVAR_UPDATE)"] = "Modification externe (CVAR_UPDATE)"
L["Description"] = "Description"
L["Value"] = "Valeur"
L["Default Value:"] = "Valeur par défaut :"
L["Last Modified By:"] = "Dernière modification par :"
L["Double-click a row to edit. Overrides are account-wide and replace CombatMode defaults."] =
  "Double-cliquez sur une ligne pour la modifier. Les remplacements s'appliquent à tout le compte et remplacent les valeurs par défaut de CombatMode."

-- Radial Menu: actions and preset wheels
L["Character Info"] = "Personnage"
L["Spellbook & Talents"] = "Grimoire et talents"
L["Talents"] = "Talents"
L["World Map"] = "Carte du monde"
L["All Bags"] = "Tous les sacs"
L["Professions"] = "Métiers"
L["Achievements"] = "Hauts faits"
L["Quest Log"] = "Journal de quêtes"
L["Guild & Communities"] = "Guilde et communautés"
L["Group Finder"] = "Recherche de groupe"
L["Warband Collection"] = "Collection de bande guerrière"
L["Housing Dashboard"] = "Tableau de bord du logement"
L["Adventure Guide"] = "Guide de l'aventure"
L["Calendar"] = "Calendrier"
L["Friends & Social"] = "Amis et social"
L["Game Menu"] = "Menu du jeu"
L["ACM Options"] = "Options d'ACM"
L["Wave"] = "Saluer"
L["Dance"] = "Danser"
L["Cheer"] = "Acclamer"
L["Bow"] = "Saluer d'une révérence"
L["Salute"] = "Salut militaire"
L["Laugh"] = "Rire"
L["Flex"] = "Bomber le torse"
L["Roar"] = "Rugir"
L["Thank"] = "Remercier"
L["Clap"] = "Applaudir"
L["Point"] = "Pointer"
L["Cry"] = "Pleurer"
L["Sit"] = "S'asseoir"
L["Kneel"] = "S'agenouiller"
L["Reputation"] = "Réputation"
L["Currency"] = "Monnaie"
L["Great Vault"] = "Grande chambre forte"
L["Mount Journal"] = "Journal des montures"
L["Pet Journal"] = "Journal des mascottes"
L["Toy Box"] = "Coffre à jouets"
L["Macros"] = "Macros"
L["Hello"] = "Bonjour"
L["Bye"] = "Au revoir"
L["Applaud"] = "Applaudir fort"
L["Shrug"] = "Hausser les épaules"
L["Yes"] = "Oui"
L["No"] = "Non"
L["Kiss"] = "Embrasser"
L["Flirt"] = "Flirter"
L["Rude"] = "Grossier"
L["Ready"] = "Prêt"
L["Victory"] = "Victoire"
L["Ready Check"] = "Appel de préparation"
L["Roll (1-100)"] = "Jet de dés (1-100)"
L["Reload UI"] = "Recharger l'interface"
L["Leave Party"] = "Quitter le groupe"
L["Reset Instances"] = "Réinitialiser les instances"
L["Pull Countdown (10s)"] = "Compte à rebours de pull (10 s)"
L["Role Check"] = "Vérification des rôles"
L["Convert to Raid"] = "Convertir en raid"
L["Summon Random Mount"] = "Invoquer une monture aléatoire"
L["Take Screenshot"] = "Capture d'écran"
L["Sheathe / Unsheathe Weapons"] = "Rengainer / dégainer les armes"
L["Loot Spec: Current Spec"] = "Butin : spécialisation actuelle"
L["Invite Target"] = "Inviter la cible"
L["Focus Target"] = "Définir le focus"
L["Cancel Form"] = "Annuler la forme"
L["Follow Target"] = "Suivre la cible"
L["Duel Target"] = "Défier en duel"
L["Inspect Target"] = "Inspecter la cible"
L["Toggle AFK"] = "Basculer AFK"
L["Toggle Do Not Disturb"] = "Basculer Ne pas déranger"
L["Camp (Log Out)"] = "Camper (se déconnecter)"
L["Dismount"] = "Descendre de monture"
L["Leave Vehicle"] = "Quitter le véhicule"
L["Mark Target: %s"] = "Marquer la cible : %s"
L["Clear Target Mark"] = "Retirer la marque de la cible"
L["World Marker: %s"] = "Marqueur au sol : %s"
L["Clear World Markers"] = "Retirer les marqueurs au sol"
L["Interface"] = "Interface"
L["Misc"] = "Divers"
L["Wheel %d"] = "Roue %d"
