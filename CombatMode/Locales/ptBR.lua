---------------------------------------------------------------------------------------
--  Locales/ptBR.lua — LOCALES — Portuguese (Brazil) strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the ptBR client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "ptBR", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "ptBR" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Bem-vindo ao Action Combat Mode!"
L["The configuration panel will open after you close this message."] =
  "O painel de configuração será aberto depois que você fechar esta mensagem."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Você pode reabri-lo a qualquer momento com |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Para restaurar suas configurações anteriores, use o botão |cffff5555Desinstalar|r no painel de opções.|r"
L["Mouse Look"] = "Visão pelo mouse"
L["Flip Camera"] = "Inverter câmera"
L["Swap Shoulder"] = "Trocar ombro"
L["Reset Mouse Look"] = "Redefinir visão pelo mouse"
L["Ally Cycle Next"] = "Alternar aliado: próximo"
L["Ally Cycle Previous"] = "Alternar aliado: anterior"
L["Toggle Focus Target"] = "Alternar alvo de foco"
L["Cycle Focus Next"] = "Alternar foco: próximo"
L["Cycle Focus Previous"] = "Alternar foco: anterior"
L["Radial Menu"] = "Menu radial"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "alteração de atalho"
L["deferred %s until combat ends."] = "%s adiado até o fim do combate."
L["failed to apply %s: %s"] = "falha ao aplicar %s: %s"
L["applied deferred binding updates."] = "atualizações de atalhos adiadas aplicadas."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50%s detectado!|r Repassando velocidade de giro, ombro e inclinação dinâmica."
L["Cannot uninstall while in combat."] = "Não é possível desinstalar em combate."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "suas configurações anteriores de câmera/mira e os atalhos padrão da câmera pelo mouse foram restaurados, e o addon foi desativado."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Digite |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r para abrir as configurações."
L["camera and targeting CVars restored."] = "CVars de câmera e mira restauradas."
L["Cannot open settings while in combat."] =
  "Não é possível abrir as configurações em combate."
L["Cannot open this editor while in combat."] = "Não é possível abrir este editor em combate."
L["Cannot open editor while in combat."] = "Não é possível abrir o editor em combate."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "não é possível editar as CVars da mira por retículo em combate."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "não é possível redefinir as CVars da mira por retículo em combate."
L["MOVEANDSTEER unbind"] = "remoção do atalho MOVEANDSTEER"
L["restore default mouse camera bindings"] =
  "restauração dos atalhos padrão da câmera pelo mouse"
L["Minimum Zoom"] = "Zoom mínimo"
L["ally cycle bindings"] = "atalhos de alternar aliado"
L["radial menu"] = "menu radial"
L["target lock keybinding"] = "atalho de travar alvo"
L["cycle focus next keybinding"] = "atalho de alternar foco: próximo"
L["cycle focus previous keybinding"] = "atalho de alternar foco: anterior"
L["ally cycle next keybinding"] = "atalho de alternar aliado: próximo"
L["ally cycle previous keybinding"] = "atalho de alternar aliado: anterior"
L["radial menu keybinding"] = "atalho do menu radial"
L["reticle interact keybinding"] = "atalho de interação com o retículo"
L["mouse look keybinding"] = "atalho de visão pelo mouse"
L["flip camera keybinding"] = "atalho de inverter câmera"
L["reset mouse look keybinding"] = "atalho de redefinir visão pelo mouse"
L["swap shoulder keybinding"] = "atalho de trocar ombro"

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "VISÃO PELO MOUSE"
L["CAMERA FEATURES"] = "RECURSOS DA CÂMERA"
L["ADDITIONAL FEATURES"] = "RECURSOS ADICIONAIS"
L["Crosshair - More accurate"] = "Mira – Mais preciso"
L["Soft Target - More forgiving"] = "Alvo suave – Mais tolerante"
L["Mouse Look is on"] = "A visão pelo mouse está ativa"
L["In combat"] = "Em combate"
L["Talking to an NPC"] = "Falando com um NPC"
L["Any checked"] = "Qualquer marcada"
L["All checked"] = "Todas as marcadas"
L["Off"] = "Desativado"
L["Control relinquished to %s"] = "Controle cedido a %s"
L["Disabled while Motion Sickness Protection is on"] =
  "Desativado enquanto a Proteção contra Enjoo de Movimento estiver ativa"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Trava o cursor na posição da mira e permite direcionar movendo o mouse sem segurar o botão direito."
L["Mouse Look Keybind"] = "Tecla de visão pelo mouse"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Toque para alternar a visão pelo mouse. Segure para liberar o cursor temporariamente."
L["Interact Keybind"] = "Tecla de interação"
L["Tap to interact with a player or the unit chosen below."] =
  "Toque para interagir com um jogador ou com a unidade escolhida abaixo."
L["Players"] = "Jogadores"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Mire em um jogador por um segundo e o HUD de assistência mostrará um aviso. Pressione a tecla então para abrir o menu de contexto dele."
L["NPCs and objects"] = "NPCs e objetos"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Interage normalmente com a unidade escolhida em “Unidade de interação”."
L["Interact Unit"] = "Unidade de interação"
L["Which unit will be interacted with when the key is pressed."] =
  "Com qual unidade será feita a interação ao pressionar a tecla."
L["Flip Camera Keybind"] = "Tecla de girar câmera"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Toque para girar a câmera 180° ao redor do personagem. Segure para girá-la apenas enquanto a tecla estiver pressionada."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Recupera um cursor travado após trocar de janela no macOS. Recaptura e libera a visão pelo mouse para limpar uma captura que o jogo deixou presa em segundo plano."
L["Curated camera adjustments for a more action-focused experience."] =
  "Ajustes de câmera selecionados para uma experiência mais focada na ação."
L["Motion Sickness Protection"] = "Proteção contra Enjoo de Movimento"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Impede que o Action Combat Mode substitua as configurações de enjoo de movimento da Blizzard."
L["Turn Speed"] = "Velocidade de giro"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Controla a rapidez com que a câmera gira ao usar a visão pelo mouse."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Impede que a câmera se aproxime mais do que esta distância. 0 desativa."
L["Dynamic Pitch"] = "Inclinação dinâmica"
L["Dynamically tilt the camera up and down as you move it."] =
  "Inclina dinamicamente a câmera para cima e para baixo ao movê-la."
L["Pitch Strength"] = "Intensidade da inclinação"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Quanto a inclinação dinâmica inclina a câmera. Valores menores mantêm seu personagem mais alto na tela. Ao voar, inclina mais e escala com este valor."
L["Shoulder Offset"] = "Deslocamento de ombro"
L["Camera's horizontal position relative to the character."] =
  "Posição horizontal da câmera em relação ao personagem."
L["Disable Offset With Mouselook"] = "Desativar deslocamento com visão pelo mouse"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "O deslocamento de ombro volta suavemente a 0 ao desativar a visão pelo mouse."
L["When off, Shoulder Offset stays constant at all times."] =
  "Quando desativado, o deslocamento de ombro permanece constante o tempo todo."
L["Swap Shoulder Keybind"] = "Tecla de trocar ombro"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Pressione para espelhar o deslocamento de ombro para o outro lado do personagem."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Funcionalidades extras ligadas ao comportamento da visão pelo mouse."
L["Cursor Pulse"] = "Pulso do cursor"
L["Flash the cursor when Mouse Look is turned off."] =
  "Faz o cursor piscar quando a visão pelo mouse é desativada."
L["Hide Tooltips"] = "Ocultar dicas"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Oculta as dicas enquanto a visão pelo mouse estiver ativa, a menos que a tecla abaixo seja mantida."
L["Show Tooltips With"] = "Mostrar dicas com"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Segure esta tecla para mostrar as dicas enquanto a visão pelo mouse estiver ativa."
L["Auto Sheath"] = "Embainhar automaticamente"
L["Sheath weapons automatically with Mouse Look."] =
  "Embainha as armas automaticamente junto com a visão pelo mouse."
L["Vignette Shows When"] = "A vinheta aparece quando"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Escurece as bordas da tela enquanto as situações marcadas forem verdadeiras."
L["Vignette Match"] = "Correspondência da vinheta"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "Qualquer: basta uma situação marcada. Todas: todas as situações marcadas devem ser verdadeiras ao mesmo tempo."
