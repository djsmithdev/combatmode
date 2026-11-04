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
