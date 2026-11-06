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
L["Tap to interact with the unit chosen below. Hold on a player to open their context menu."] =
  "Toque para interagir com a unidade escolhida abaixo. Segure sobre um jogador para abrir o menu de contexto dele."
L["Players"] = "Jogadores"
L["Aim at a player for a second and the Assist HUD shows a prompt. Hold the key then to open their context menu."] =
  "Mire em um jogador por um segundo e o HUD de assistência mostra um aviso. Segure a tecla para abrir o menu de contexto dele."
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
L["Show an indicator while aiming at a player for one second. Holding the Interact Key opens their context menu."] =
  "Mostra um indicador ao mirar em um jogador por um segundo. Segurar a tecla de interação abre o menu de contexto dele."
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

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Rodas do menu radial"
L["Forever"] = "Forever"
L["Minimal"] = "Minimalista"
L["Clear Slice"] = "Limpar fatia"
L["UI Actions"] = "Ações da interface"
L["Emotes"] = "Emotes"
L["Commands"] = "Comandos"
L["Markers"] = "Marcadores"
L["Slice"] = "Fatia"
L["Choose an action"] = "Escolha uma ação"
L["Presets"] = "Predefinições"
L["New Wheel"] = "Nova roda"
L["Wheel"] = "Roda"
L["You can have up to %d wheels."] = "Você pode ter até %d rodas."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Isso não pode ir em uma roda. Use uma magia, item, brinquedo, montaria ou macro."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Arraste uma magia, item, brinquedo, montaria ou macro para cá, ou clique para mudar a ação."
L["Empty Slice"] = "Fatia vazia"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Arraste uma magia, item, brinquedo, montaria ou macro para cá, ou clique para definir uma ação. Fatias vazias ficam fora da roda."
L["A wheel needs at least one slice."] = "Uma roda precisa de pelo menos uma fatia."
L["Click to rename this wheel"] = "Clique para renomear esta roda"
L["Previous wheel"] = "Roda anterior"
L["Next wheel"] = "Próxima roda"
L["Click to select this wheel, drag to reorder"] =
  "Clique para selecionar esta roda, arraste para reordenar"
L["Add Slice"] = "Adicionar fatia"
L["A wheel holds up to %d slices."] = "Uma roda comporta até %d fatias."
L["Remove Wheel"] = "Remover roda"
L["Deletes this wheel and all of its slices."] = "Exclui esta roda e todas as suas fatias."
L["You need at least one wheel."] = "Você precisa de pelo menos uma roda."
L["Remove this wheel and all of its slices?"] = "Remover esta roda e todas as suas fatias?"
L["Add Wheel"] = "Adicionar roda"
L["Pick a preset wheel or a blank one."] = "Escolha uma roda predefinida ou uma em branco."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Clique em uma fatia para escolher sua ação, ou solte sobre ela uma magia, item, brinquedo, montaria ou macro.\nArraste uma fatia para reordená-la. Clique com o botão direito para removê-la."
L["RADIAL MENU"] = "MENU RADIAL"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Crie rodas de acesso rápido para magias, itens, macros, emotes e atalhos da interface."
L["Radial Menu Keybind"] = "Atalho do menu radial"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Segure para abrir o menu radial, mire em uma fatia e solte para ativá-la. Role o mouse para alternar entre rodas."
L["Radial Menu Style"] = "Estilo do menu radial"
L["Choose the appearance of the Radial Menu wheels."] =
  "Escolha a aparência das rodas do menu radial."
L["Party Wheel Spells"] = "Magias da roda de grupo"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Magias benéficas que abrem uma roda de alvos do grupo enquanto a tecla é mantida. Mova para um membro do grupo e solte para lançar nele, ou volte ao centro para lançar em você. Um toque rápido lança no seu alvo amigável, ou em você se não houver nenhum."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Edite as fatias de cada roda, renomeie rodas e adicione ou remova rodas."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "Superior"
L["Bottom"] = "Inferior"
L["Ally Cycle"] = "Ciclo de aliados"
L["ALLY CYCLE"] = "CICLO DE ALIADOS"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "Combate e suporte fluidos: magias benéficas têm como alvo os aliados, enquanto as nocivas continuam no inimigo sob a mira."
L["Ally Cycle - Next"] = "Ciclo de aliados – Próximo"
L["Target the next group member."] = "Seleciona o próximo membro do grupo."
L["Ally Cycle - Previous"] = "Ciclo de aliados – Anterior"
L["Target the previous group member."] = "Seleciona o membro anterior do grupo."
L["Skip Self"] = "Pular a si mesmo"
L["Skip yourself when cycling through group members."] =
  "Pula você ao alternar entre os membros do grupo."
L["Keep Ally After Harm"] = "Manter aliado após dano"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "Depois que uma magia nociva atinge o inimigo na mira, restaura o aliado anterior. Ativado por padrão para especializações de curandeiro até ser alterado."
L["Disabled while Auto Target Lock is on"] =
  "Desativado enquanto Travar alvo automático estiver ativo"
L["ALLY HUD"] = "HUD DE ALIADOS"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "Um HUD que mostra o membro do grupo selecionado pelo ciclo de aliados."
L["Ally HUD"] = "HUD de aliados"
L["Show a unit frame for the currently selected group member."] =
  "Mostra um quadro de unidade do membro do grupo selecionado."
L["Where the Ally HUD sits relative to the crosshair."] =
  "Onde o HUD de aliados fica em relação à mira."
L["Scales the size of the Ally HUD."] = "Ajusta o tamanho do HUD de aliados."
L["Distance between the Ally HUD and the crosshair."] =
  "Distância entre o HUD de aliados e a mira."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "Desbloqueio automático"
L["AUTO UNLOCK"] = "DESBLOQUEIO AUTOMÁTICO"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "Pausa automaticamente a visão pelo mouse quando janelas são abertas e a retoma quando são fechadas."
L["Release the cursor when UI panels open."] =
  "Libera o cursor quando painéis da interface são abertos."
L["Unlock Mounts"] = "Montarias que desbloqueiam"
L["Mounts that force a cursor unlock while mounted."] =
  "Montarias que liberam o cursor enquanto você está montado."
L["Extra Frames"] = "Quadros adicionais"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "Nomes de quadros adicionais que acionam o desbloqueio automático. Digite para buscar quadros da Blizzard e de addons, ou use o botão de inspeção para clicar em uma janela na tela."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "Avançado"
L["SOUNDS"] = "SONS"
L["Control the sound cues used by some of the other features."] =
  "Controle os sinais sonoros usados por alguns outros recursos."
L["Mouse Look Sounds"] = "Sons da visão pelo mouse"
L["Play a cue when Mouse Look turns on and off."] =
  "Toca um sinal quando a visão pelo mouse é ativada ou desativada."
L["Target Lock Sounds"] = "Sons de travar alvo"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "Toca sinais quando um alvo é travado, destravado ou alternado."
L["Radial Menu Sounds"] = "Sons do menu radial"
L["Play cues when interacting with Radial Menu wheels."] =
  "Toca sinais ao interagir com as rodas do menu radial."
L["Ally Cycle Sounds"] = "Sons do ciclo de aliados"
L["Play a cue when Ally Cycle moves to another ally."] =
  "Toca um sinal quando o ciclo de aliados passa para outro aliado."
L["FORCE LOCK"] = "FORÇAR BLOQUEIO"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "Uma opção avançada que mantém a visão pelo mouse ativada enquanto uma condição Lua personalizada for verdadeira."
L["Custom Condition"] = "Condição personalizada"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "Código Lua personalizado que, enquanto for verdadeiro, mantém a visão pelo mouse travada."
L["Lock Once"] = "Travar uma vez"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "Trava a visão pelo mouse somente quando a condição se torna verdadeira pela primeira vez. Um destravamento manual permanece até a condição ficar falsa e depois verdadeira de novo."
L["FORCE UNLOCK"] = "FORÇAR DESBLOQUEIO"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "O oposto de Forçar bloqueio: mantém a visão pelo mouse desativada enquanto uma condição Lua personalizada for verdadeira."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "Código Lua personalizado que, enquanto for verdadeiro, mantém a visão pelo mouse destravada."
L["Unlock Once"] = "Destravar uma vez"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "Destrava a visão pelo mouse somente quando a condição se torna verdadeira pela primeira vez. Um travamento manual permanece até a condição ficar falsa e depois verdadeira de novo."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "Troca a aparência da mira enquanto uma condição Lua personalizada for verdadeira."
L["Situational Appearance"] = "Aparência situacional"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "Texturas usadas pela mira enquanto a condição situacional for verdadeira."
L["Situational Condition"] = "Condição situacional"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "Código Lua personalizado que, enquanto for verdadeiro, força a mira a usar sua aparência situacional."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Modifique as CVars padrão da Mira de Alvo e as prélinhas de macro de alvo do Action Combat Mode."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "Aviso: editar esses valores pode quebrar a Mira de Alvo e o travamento de alvo."
L["Reticle Targeting CVar Editor"] = "Editor de CVars da Mira de Alvo"
L["Targeting Macro Prelines Editor"] = "Editor de prélinhas de macro de alvo"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "Voltar"
L["Next"] = "Avançar"
L["Finish"] = "Concluir"
L["Skip tour"] = "Pular tour"
L["Assist HUD"] = "HUD de assistência"
L["Target Lock"] = "Travar alvo"
L["Party Wheel"] = "Roda do grupo"
L["Set a Mouse Look key"] = "Defina uma tecla de visão pelo mouse"
L["Set an Interact key"] = "Defina uma tecla de interação"
L["Set a Target Lock key"] = "Defina uma tecla de travar alvo"
L["Set a Cycle Lock - Next key"] = "Defina uma tecla de Ciclo de trava – Próximo"
L["Set a Cycle Lock - Previous key"] = "Defina uma tecla de Ciclo de trava – Anterior"
L["Set a Radial Menu key"] = "Defina uma tecla do menu radial"
L["Set an Ally Cycle - Next key"] = "Defina uma tecla de Ciclo de aliados – Próximo"
L["Set an Ally Cycle - Previous key"] = "Defina uma tecla de Ciclo de aliados – Anterior"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "Ativar ou desativar a Mira de Alvo recarrega a interface."
L["Needs Reticle Targeting."] = "Requer a Mira de Alvo."
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "Prenda o cursor no centro da tela e direcione movendo o mouse, sem segurar o clique direito.\n\nDefina uma {tecla para alternar} e {outra para interagir} com o que você estiver mirando."
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "Uma mira reativa e totalmente personalizável que se adapta ao seu alvo e ao estado de combate.\n\nEscolha {aparência}, {tamanho} e {posição}."
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "Mire em um inimigo e o HUD ao lado da mira sugere sua {próxima magia} e mostra a tecla dela.\n\nMire em algo com que possa interagir e ele mostra o {nome} e sua {tecla de interação}.\n\nAtive ou desative cada um e defina {lado}, {tamanho} e {distância} em relação à mira."
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "Selecione inimigos apenas mirando neles e lance magias de área e habilidades em massa exatamente onde a mira aponta, sem seleção com Tab.\n\n{Ignorar aliados} faz com que ela pule os aliados."
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "Magias de área que devem ser lançadas na posição da mira.\n\nDigite o {nome ou ID da magia} para adicioná-la."
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!Botões de ação que são macros não conseguem herdar a Mira de Alvo por conta própria.}\n\nPressione {+} para abrir o {Compositor de macros}, escreva sua macro ali e a lógica de alvo será adicionada para você.\n\nDepois arraste-a desta lista para suas barras de ação; {clique direito} em um ícone para editá-la."
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "Trave um alvo com um toque para a mira parar de trocar. Enquanto travado, as teclas de ciclo pulam para inimigos próximos.\n\n{Comportamento de travar alvo} decide se tocar de novo destrava ({Alternar}) ou move a trava para o que estiver sob a mira ({Trocar alvo}).\n\nDefina suas teclas."
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "Transforme seus cliques do mouse em ações durante a visão pelo mouse, como lançar magias da barra de ação com {clique esquerdo e direito}.\n\nEscolha o que cada clique faz, com ou sem {tecla modificadora}."
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "Uma roda com seus {feitiços, itens, macros e atalhos} que funciona em combate.\n\nSegure a tecla, mova o mouse em direção a uma fatia e solte para usá-la.\n\n{Role} para alternar entre rodas."
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "Segure a tecla de uma {magia benéfica} listada aqui para abrir uma roda com os membros do grupo. Mova em direção a um deles e solte para lançar nele, ou volte ao {centro} para lançar em você.\n\n{Toque} na tecla para lançar no seu alvo amigável, ou em você se não tiver nenhum.\n\nDigite o {nome ou ID da magia} para adicioná-la."
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "Alterne entre os membros do grupo na visão pelo mouse para que as {magias benéficas} vão para o aliado enquanto as {nocivas} continuam atingindo o inimigo.\n\nO {HUD de aliados} mostra quem está selecionado.\n\nDefina suas teclas de ciclo."
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "A visão pelo mouse pausa quando você abre {bolsas, o mapa ou outras janelas} e depois retoma.\n\nAdicione {montarias ou janelas extras} que também devem pausá-la."

-- Options UI: widgets, panel, search, pickers
L["What's New"] = "Novidades"
L["See what's new in this version"] = "Veja o que há de novo nesta versão"
L["Link"] = "link"
L["Copy the %s link (Ctrl+C), then paste it in your browser."] =
  "Copie o link de %s (Ctrl+C) e cole no seu navegador."
L["Character-specific option."] = "Opção específica do personagem."
L["NEW"] = "NOVO"
L["ON"] = "LIG"
L["OFF"] = "DESL"
L["Are you sure?"] = "Tem certeza?"
L["> Press key (ESC clears) <"] = "> Pressione uma tecla (ESC limpa) <"
L["WoW API Documentation"] = "Documentação da API do WoW"
L["Pick a frame on screen"] = "Escolher um quadro na tela"
L["Pick a frame"] = "Escolher um quadro"
L["Silence Alerts"] = "Silenciar alertas"
L["Debug Mode"] = "Modo de depuração"
L["Reset to Defaults"] = "Restaurar padrões"
L["Reset all Action Combat Mode settings to defaults and reload?"] =
  "Restaurar todas as configurações do Action Combat Mode e recarregar?"
L["Uninstall"] = "Desinstalar"
L["Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload."] =
  "Desinstalar o Action Combat Mode?\n\nIsso restaurará suas configurações anteriores de câmera e de alvo, desativará o addon e recarregará a interface."
L["View the changelog"] = "Ver o registro de alterações"
L["Run the setup wizard again?"] = "Executar o assistente de configuração novamente?"
L["Run the setup wizard"] = "Executar o assistente de configuração"
L["GitHub Repository"] = "Repositório do GitHub"
L["Discord Server"] = "Servidor do Discord"
L["%s · Section"] = "%s · Seção"
L["Sidebar"] = "Barra lateral"
L["Search options..."] = "Pesquisar opções..."
L["No matching options"] = "Nenhuma opção correspondente"
L["Section"] = "Seção"
L["Tab"] = "Aba"
L["Color"] = "Cor"
L["Type spell name or ID…"] = "Digite o nome ou ID da magia…"
L["Type mount name or spell ID…"] = "Digite o nome da montaria ou o ID da magia…"
L["Type a frame name…"] = "Digite o nome de um quadro…"
L["Blizzard"] = "Blizzard"
L["Addon"] = "Addon"
L["open"] = "aberto"
L["Click a frame to add it to the list. Right-click or press Esc to cancel."] =
  "Clique em um quadro para adicioná-lo à lista. Clique direito ou Esc para cancelar."
L["Line %d: %s"] = "Linha %d: %s"
L["Unknown API: %s - did you mean %s?"] = "API desconhecida: %s – você quis dizer %s?"
L["Unknown API: %s"] = "API desconhecida: %s"
L["%s (+%d more)"] = "%s (+%d mais)"
L["Version: %s"] = "Versão: %s"
L["Use the button below to open Action Combat Mode options."] =
  "Use o botão abaixo para abrir as opções do Action Combat Mode."
L["You can also type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r in chat."] =
  "Você também pode digitar |cff69ccf0/acm|r ou |cff69ccf0/actioncombatmode|r no chat."
L["Open Options"] = "Abrir opções"

-- Editors: macro composer, prelines, crosshair colors and textures, CVar editor
L["%d / %d characters"] = "%d / %d caracteres"
L["%s (over the macro limit)"] = "%s (acima do limite da macro)"
L["Ignore Friendlies: %s"] = "Ignorar aliados: %s"
L["Auto Target Lock: %s"] = "Travar alvo automaticamente: %s"
L["Preline: Ignore Friendlies + No Auto Lock"] =
  "Pré-linha: Ignorar aliados + sem trava automática"
L["Preline: Ignore Friendlies + Auto Lock"] = "Pré-linha: Ignorar aliados + trava automática"
L["Preline: Target Any Unit + No Auto Lock"] =
  "Pré-linha: Alvo em qualquer unidade + sem trava automática"
L["Preline: Target Any Unit + Auto Lock"] =
  "Pré-linha: Alvo em qualquer unidade + trava automática"
L["Macro Composer"] = "Compositor de macros"
L["The targeting logic preline matching your current Reticle Targeting settings is added automatically before your lines, as the highlighted portion of the macro. To modify it, use the Prelines Editor under %s."] =
  "A pré-linha de alvo correspondente às suas configurações atuais de Mira de Alvo é adicionada automaticamente antes das suas linhas, como a parte destacada da macro. Para modificá-la, use o editor de pré-linhas em %s."
L["Macro Name"] = "Nome da macro"
L["Enter a macro name"] = "Digite um nome para a macro"
L["Saved to your general macros."] = "Salva nas suas macros gerais."
L["Saved to your character macros."] = "Salva nas macros do seu personagem."
L["Macro Text"] = "Texto da macro"
L["Delete Macro"] = "Excluir macro"
L["Delete this macro? Any action bar button using it will be emptied."] =
  "Excluir esta macro? Qualquer botão da barra de ação que a utilize ficará vazio."
L["Save Macro"] = "Salvar macro"
L["Preline must be %d characters or fewer (room for /click under the 255 macro limit)."] =
  "A pré-linha deve ter no máximo %d caracteres (espaço para /click dentro do limite de 255 da macro)."
L["Inactive — Auto Target Lock is OFF"] =
  "Inativa — A trava automática de alvo está DESLIGADA"
L["Inactive — Auto Target Lock is ON"] = "Inativa — A trava automática de alvo está LIGADA"
L["Inactive — Ignore Friendlies is OFF"] = "Inativa — Ignorar aliados está DESLIGADO"
L["Inactive — Ignore Friendlies is ON"] = "Inativa — Ignorar aliados está LIGADO"
L["Customize the targeting prelines injected before each ability when Reticle Targeting is enabled.\n\n• Only the preline matching your current %s X %s settings is active.\n• Max %s characters per preline — SecureActionButton macros are capped at %s; the rest is reserved for the trailing %s line.\n• Use %s to reload and pick up edits."] =
  "Personalize as pré-linhas de alvo inseridas antes de cada habilidade quando a Mira de Alvo está ativada.\n\n• Somente a pré-linha correspondente às suas configurações atuais de %s X %s está ativa.\n• Máximo de %s caracteres por pré-linha — macros SecureActionButton são limitadas a %s; o restante é reservado para a linha final %s.\n• Use %s para recarregar e aplicar as alterações."
L["Apply Changes"] = "Aplicar alterações"
L["Hostile"] = "Hostil"
L["NPC"] = "NPC"
L["Player"] = "Jogador"
L["Object"] = "Objeto"
L["Select a tab to customize the color and alpha of the crosshair when targeting different types of units.\n\n• %s and %s animations use the Hostile color.\n• Inactive crosshair states use the Base style."] =
  "Selecione uma aba para personalizar a cor e a opacidade da mira ao mirar em diferentes tipos de unidades.\n\n• As animações de %s e %s usam a cor Hostil.\n• Os estados inativos da mira usam o estilo Base."
L["Reset to Default"] = "Restaurar padrão"
L["Show the inactive crosshair"] = "Mostrar a mira inativa"
L["Show the active crosshair"] = "Mostrar a mira ativa"
L["Show the mounted crosshair"] = "Mostrar a mira de montaria"
L["Show the disabled crosshair"] = "Mostrar a mira desativada"
L["Hide the inactive crosshair"] = "Ocultar a mira inativa"
L["Hide the active crosshair"] = "Ocultar a mira ativa"
L["Hide the mounted crosshair"] = "Ocultar a mira de montaria"
L["Hide the disabled crosshair"] = "Ocultar a mira desativada"
L["Nothing is drawn while you are not aiming at anything."] =
  "Nada é desenhado enquanto você não estiver mirando em nada."
L["Nothing is drawn while you are aiming at a unit or object."] =
  "Nada é desenhado enquanto você estiver mirando em uma unidade ou objeto."
L["Nothing is drawn while you are mounted."] = "Nada é desenhado enquanto você estiver montado."
L["Nothing is drawn while Target Lock holds the reticle."] =
  "Nada é desenhado enquanto a trava de alvo prender a mira."
L["Not aiming at anything"] = "Sem mirar em nada"
L["Aiming at a unit or object"] = "Mirando em uma unidade ou objeto"
L["While you are mounted"] = "Enquanto você estiver montado"
L["While Target Lock holds"] = "Enquanto a trava de alvo estiver ativa"
L["Brings back the texture you had before hiding it."] =
  "Restaura a textura que você tinha antes de ocultá-la."
L["Crosshair Textures"] = "Texturas da mira"
L["Select a state, then pick a texture below, or apply a preset for a curated appearance."] =
  "Selecione um estado e escolha uma textura abaixo, ou aplique uma predefinição para um visual cuidado."
L["INACTIVE"] = "INATIVA"
L["ACTIVE"] = "ATIVA"
L["MOUNTED"] = "MONTADO"
L["DISABLED"] = "DESATIVADA"
L["PRESETS"] = "PREDEFINIÇÕES"
L["ALL TEXTURES"] = "TODAS AS TEXTURAS"
L["Action Combat Mode (Reticle CVar Editor)"] = "Action Combat Mode (editor de CVars da mira)"
L["External change (CVAR_UPDATE)"] = "Alteração externa (CVAR_UPDATE)"
L["Description"] = "Descrição"
L["Value"] = "Valor"
L["Default Value:"] = "Valor padrão:"
L["Last Modified By:"] = "Última modificação por:"
L["Double-click a row to edit. Overrides are account-wide and replace CombatMode defaults."] =
  "Clique duas vezes em uma linha para editar. As substituições valem para toda a conta e substituem os padrões do CombatMode."

-- Radial Menu: actions and preset wheels
L["Character Info"] = "Personagem"
L["Spellbook & Talents"] = "Grimório e talentos"
L["Spellbook"] = "Grimório"
L["Legacy"] = "Legado"
L["Talents"] = "Talentos"
L["World Map"] = "Mapa-múndi"
L["All Bags"] = "Todas as bolsas"
L["Professions"] = "Profissões"
L["Achievements"] = "Conquistas"
L["Quest Log"] = "Registro de missões"
L["Guild & Communities"] = "Guilda e comunidades"
L["Group Finder"] = "Localizador de grupos"
L["Warband Collection"] = "Coleção do bando de guerra"
L["Housing Dashboard"] = "Painel de moradia"
L["Adventure Guide"] = "Guia de aventura"
L["Calendar"] = "Calendário"
L["Friends & Social"] = "Amigos e social"
L["Game Menu"] = "Menu do jogo"
L["ACM Options"] = "Opções do ACM"
L["Wave"] = "Acenar"
L["Dance"] = "Dançar"
L["Cheer"] = "Comemorar"
L["Bow"] = "Reverência"
L["Salute"] = "Continência"
L["Laugh"] = "Rir"
L["Flex"] = "Mostrar músculos"
L["Roar"] = "Rugir"
L["Thank"] = "Agradecer"
L["Clap"] = "Bater palmas"
L["Point"] = "Apontar"
L["Cry"] = "Chorar"
L["Sit"] = "Sentar"
L["Kneel"] = "Ajoelhar"
L["Reputation"] = "Reputação"
L["Currency"] = "Moeda"
L["Great Vault"] = "Grande Cofre"
L["Mount Journal"] = "Diário de montarias"
L["Pet Journal"] = "Diário de mascotes"
L["Toy Box"] = "Caixa de brinquedos"
L["Macros"] = "Macros"
L["Hello"] = "Olá"
L["Bye"] = "Tchau"
L["Applaud"] = "Aplaudir"
L["Shrug"] = "Dar de ombros"
L["Yes"] = "Sim"
L["No"] = "Não"
L["Kiss"] = "Beijar"
L["Flirt"] = "Flertar"
L["Rude"] = "Rude"
L["Ready"] = "Pronto"
L["Victory"] = "Vitória"
L["Ready Check"] = "Verificação de prontidão"
L["Roll (1-100)"] = "Rolar dados (1-100)"
L["Reload UI"] = "Recarregar interface"
L["Leave Party"] = "Sair do grupo"
L["Reset Instances"] = "Reiniciar instâncias"
L["Pull Countdown (10s)"] = "Contagem do pull (10 s)"
L["Role Check"] = "Verificação de função"
L["Convert to Raid"] = "Converter em raide"
L["Summon Random Mount"] = "Invocar montaria aleatória"
L["Take Screenshot"] = "Tirar captura de tela"
L["Sheathe / Unsheathe Weapons"] = "Guardar / sacar armas"
L["Loot Spec: Current Spec"] = "Saque: especialização atual"
L["Invite Target"] = "Convidar alvo"
L["Focus Target"] = "Definir foco"
L["Cancel Form"] = "Cancelar forma"
L["Follow Target"] = "Seguir alvo"
L["Duel Target"] = "Desafiar para duelo"
L["Inspect Target"] = "Inspecionar alvo"
L["Toggle AFK"] = "Alternar AFK"
L["Toggle Do Not Disturb"] = "Alternar Não perturbe"
L["Camp (Log Out)"] = "Acampar (sair)"
L["Dismount"] = "Desmontar"
L["Leave Vehicle"] = "Sair do veículo"
L["Mark Target: %s"] = "Marcar alvo: %s"
L["Clear Target Mark"] = "Remover marca do alvo"
L["World Marker: %s"] = "Marcador de mundo: %s"
L["Clear World Markers"] = "Remover marcadores de mundo"
L["Interface"] = "Interface"
L["Misc"] = "Diversos"
L["Wheel %d"] = "Roda %d"

-- Runtime: composed macro messages, changelog tooltip
L["Your character macro list is full."] = "Sua lista de macros do personagem está cheia."
L["Your general macro list is full."] = "Sua lista de macros gerais está cheia."
L["Cannot delete a macro while in combat."] = "Não é possível excluir uma macro em combate."
L["Cannot save a macro while in combat."] = "Não é possível salvar uma macro em combate."
L["Enter a macro name."] = "Digite um nome para a macro."
L["Macro names are limited to %d characters."] = "Os nomes de macro são limitados a %d caracteres."
L["Enter the macro text to run after the targeting preline."] =
  "Digite o texto da macro a executar após a pré-linha de alvo."
L["Macro is %d characters over the %d limit."] = "A macro excede em %d caracteres o limite de %d."
L["Macro “%s” no longer fits with the current preline; edit it from Reticle Targeting Macros."] =
  "A macro “%s” não cabe mais com a pré-linha atual; edite-a em Macros de Mira de Alvo."
L["Click to print URL to chat"] = "Clique para exibir a URL no chat"
