---------------------------------------------------------------------------------------
--  Locales/ruRU.lua — LOCALES — Russian strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the ruRU client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "ruRU", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "ruRU" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Добро пожаловать в Action Combat Mode!"
L["The configuration panel will open after you close this message."] =
  "Панель настроек откроется после закрытия этого сообщения."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "Вы можете открыть её снова в любой момент командой |cff69ccf0/acm|r или |cff69ccf0/actioncombatmode|r."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090Чтобы восстановить прежние настройки, нажмите кнопку |cffff5555Удалить|r на панели настроек.|r"
L["Mouse Look"] = "Обзор мышью"
L["Flip Camera"] = "Отразить камеру"
L["Swap Shoulder"] = "Сменить плечо"
L["Reset Mouse Look"] = "Сбросить обзор мышью"
L["Ally Cycle Next"] = "Выбор союзника: следующий"
L["Ally Cycle Previous"] = "Выбор союзника: предыдущий"
L["Toggle Focus Target"] = "Переключить цель фокуса"
L["Cycle Focus Next"] = "Смена фокуса: следующий"
L["Cycle Focus Previous"] = "Смена фокуса: предыдущий"
L["Radial Menu"] = "Радиальное меню"
