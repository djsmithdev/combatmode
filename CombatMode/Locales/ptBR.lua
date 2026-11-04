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

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Qualquer alvo fixo"
L["Locked Target Only"] = "Apenas alvo travado"
L["Soft Target (Blizzard)"] = "Alvo suave (Blizzard)"
L["Hidden"] = "Oculto"
L["Toggle"] = "Alternar"
L["Switch Target"] = "Trocar alvo"
L["A UI Reload is required when making this change. Proceed?"] =
  "Esta alteração exige recarregar a interface. Continuar?"
L["Create New Macro"] = "Criar novo macro"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Escreva um macro que comece com a pré-linha de Mira de Alvo."
L["Unavailable in combat."] = "Indisponível em combate."
L["Drag to a button on your action bars to use."] =
  "Arraste para um botão das suas barras de ação para usar."
L["Right-click to edit"] = "Clique direito para editar"
L["+%d more in /macro"] = "+%d mais em /macro"
L["Reticle Targeting Macros"] = "Macros de mira de alvo"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "Botões de ação que são macros não herdam automaticamente a lógica da Mira de Alvo. Para que sigam essas regras, crie-os com a ferramenta Compositor de Macros e depois arraste-os para suas barras."
L["Reticle Targeting"] = "Mira de Alvo"
L["RETICLE TARGETING"] = "MIRA DE ALVO"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Permite selecionar unidades mirando e posicionar com precisão feitiços de solo e habilidades em área."
L["Enable Reticle Targeting"] = "Ativar Mira de Alvo"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Mire nas unidades com a mira para escolher alvos em vez de usar o tab."
L["Ignore Friendlies"] = "Ignorar aliados"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Ignora NPCs e jogadores aliados e mira apenas em unidades hostis."
L["Click Casting Only"] = "Apenas lançamento por clique"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "Aplica a lógica da Mira de Alvo apenas às teclas de lançamento por clique."
L["Excluded Spells"] = "Feitiços excluídos"
L["Spells to skip the reticle targeting logic."] =
  "Feitiços que ignoram a lógica da Mira de Alvo."
L["Cast at Crosshair"] = "Lançar na mira"
L["Ground spells to cast at the crosshair location."] =
  "Feitiços de solo para lançar na posição da mira."
L["TARGET LOCK"] = "TRAVAR ALVO"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Trave um alvo para evitar trocas acidentais e alterne entre unidades para priorizar inimigos específicos."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Aviso: Travar alvo usa o seu alvo de foco. Qualquer outra coisa que defina o foco interferirá."
L["Target Lock Keybind"] = "Tecla de travar alvo"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Trava a mira em um alvo, impedindo que ele troque."
L["Cycle Lock - Next"] = "Alternar trava – Próximo"
L["Move Target Lock to the next valid nearby target."] =
  "Move a trava para o próximo alvo válido por perto."
L["Cycle Lock - Previous"] = "Alternar trava – Anterior"
L["Move Target Lock to the previous valid nearby target."] =
  "Move a trava para o alvo válido anterior por perto."
L["Target Lock Behavior"] = "Comportamento de travar alvo"
L["What the Target Lock key does when you press it."] =
  "O que a tecla de travar alvo faz quando pressionada."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Trava o seu alvo ou a unidade sob a mira. Toque novamente para destravar."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Trava a unidade sob a mira, substituindo qualquer trava atual. Toque sem nada sob a mira para destravar. Mirar na unidade já travada mantém a trava."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Com “Ignorar aliados” ativado, uma unidade aliada ou morta sob a mira é ignorada: a trava permanece onde está."
L["Auto Target Lock"] = "Travar alvo automaticamente"
L["Target Lock engages automatically when attacking units."] =
  "Travar alvo é ativado automaticamente ao atacar unidades."
L["Target Lock Marker"] = "Marcador de trava de alvo"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Mostra um marcador de mira na placa de nome do alvo travado."
L["Focus Locked Target"] = "Focar no alvo travado"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Puxa a câmera em direção ao alvo travado, mantendo-o em foco."
L["TARGETING INDICATORS"] = "INDICADORES DE ALVO"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Indicadores visuais que destacam alvos no mundo para facilitar a identificação."
L["Target Outline"] = "Contorno do alvo"
L["Show an outline effect on your target."] = "Mostra um efeito de contorno no seu alvo."
L["Only available on Retail"] = "Disponível apenas no Retail"
L["Selection Circle"] = "Círculo de seleção"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "Qual alvo recebe o círculo de seleção da Blizzard sob os pés."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "O círculo sob qualquer alvo selecionado, inimigo ou aliado."
L["The circle only under your Target Lock."] = "O círculo apenas sob o seu alvo travado."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Deixa a Blizzard controlar o comportamento de ObjectSelectionCircle e UnitNameFocused."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "A Blizzard escolhe o alvo suave em um arco à frente do modelo do personagem. Não leva em conta a posição da mira nem o deslocamento de ombro."
L["No selection circle."] = "Sem círculo de seleção."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Mira"
L["CROSSHAIR"] = "MIRA"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Uma mira dinâmica que reage a alvos e estados de combate, aumenta a precisão e orienta a Mira de Alvo."
L["Enable Crosshair"] = "Ativar mira"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Durante a visão pelo mouse, exibe uma mira dinâmica e reativa na tela."
L["Cast Feedback"] = "Feedback de lançamento"
L["Crosshair provides visual feedback while casting."] =
  "A mira fornece feedback visual durante o lançamento."
L["Appearance"] = "Aparência"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Texturas usadas pela mira em cada estado. Clique em uma para escolher a textura ou comece por uma predefinição."
L["Inactive"] = "Inativa"
L["Active"] = "Ativa"
L["Mounted"] = "Montado"
L["Disabled"] = "Desativada"
L["Reaction Colors"] = "Cores de reação"
L["Edit"] = "Editar"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Personalize as cores usadas pela mira ao mirar em diferentes tipos de unidades."
L["Scale"] = "Escala"
L["Scales the size of the crosshair."] = "Ajusta o tamanho da mira."
L["Vertical Position"] = "Posição vertical"
L["Move the crosshair up or down from screen center."] =
  "Move a mira para cima ou para baixo a partir do centro da tela."
L["ASSIST HUD"] = "HUD DE ASSISTÊNCIA"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "Um HUD que orienta a rotação de feitiços ao mirar em inimigos e exibe avisos de interação."
L["Next-cast Suggestion"] = "Sugestão do próximo feitiço"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Mostra a sugestão do próximo feitiço do Destaque Assistido enquanto você mira em um alvo."
L["Always"] = "Sempre"
L["Only In Combat"] = "Apenas em combate"
L["Interactable Indicator"] = "Indicador de interação"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Mostra um indicador ao mirar em uma unidade ou objeto interagível."
L["Player Interaction Prompt"] = "Aviso de interação com jogadores"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Mostra um indicador ao mirar em um jogador por um segundo. Pressionar a tecla de interação abre o menu de contexto dele."
L["Position"] = "Posição"
L["Which side of the crosshair the HUD appears on."] = "Em qual lado da mira o HUD aparece."
L["Left"] = "Esquerda"
L["Right"] = "Direita"
L["Scales the size of the HUD."] = "Ajusta o tamanho do HUD."
L["Distance"] = "Distância"
L["Distance between the HUD and the crosshair."] = "Distância entre o HUD e a mira."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Ações da Blizzard modificadas"
L["Blizzard Actions"] = "Ações da Blizzard"
L["Base"] = "Base"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "Limpar alvo"
L["Clear Focus"] = "Limpar foco"
L["Start Attack"] = "Iniciar ataque"
L["Pet Attack"] = "Ataque do ajudante"
L["Toggle Focus Any"] = "Alternar foco (qualquer)"
L["Toggle Focus Enemy"] = "Alternar foco (inimigo)"
L["Run MACRO"] = "Executar MACRO"
L["— none —"] = "— nenhuma —"
L["Override this click during Mouse Look."] = "Substitui este clique durante a visão pelo mouse."
L["Action"] = "Ação"
L["Macro"] = "Macro"
L["Select a macro"] = "Selecione uma macro"
L["No targeting"] = "Sem mira"
L["Left Click"] = "Clique esquerdo"
L["Right Click"] = "Clique direito"
L["Shift + Left Click"] = "Shift + Clique esquerdo"
L["Shift + Right Click"] = "Shift + Clique direito"
L["Ctrl + Left Click"] = "Ctrl + Clique esquerdo"
L["Ctrl + Right Click"] = "Ctrl + Clique direito"
L["Alt + Left Click"] = "Alt + Clique esquerdo"
L["Alt + Right Click"] = "Alt + Clique direito"
L["Click Casting"] = "Lançamento por clique"
L["CLICK CASTING"] = "LANÇAMENTO POR CLIQUE"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Atribui ações substitutas aos cliques esquerdo e direito, ativas durante a visão pelo mouse."
L["Account-Wide Binds"] = "Atalhos para toda a conta"
L["Share Click Casting binds across all characters."] =
  "Compartilha os atalhos de lançamento por clique com todos os personagens."
L["Click Binds"] = "Atalhos de clique"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "Base, Shift, Ctrl e Alt têm, cada um, as próprias ações de clique esquerdo e direito."
