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
