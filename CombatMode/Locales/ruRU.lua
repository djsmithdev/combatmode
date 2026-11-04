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

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "изменение привязки клавиш"
L["deferred %s until combat ends."] = "%s отложено до конца боя."
L["failed to apply %s: %s"] = "не удалось применить %s: %s"
L["applied deferred binding updates."] =
  "отложенные изменения привязок применены."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50Обнаружен %s!|r Скорость поворота, плечо и динамический наклон передаются ему."
L["Cannot uninstall while in combat."] = "Нельзя удалить во время боя."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "прежние настройки камеры и выбора цели и стандартные привязки камеры мыши восстановлены, аддон отключён."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "Введите |cff69ccf0/acm|r или |cff69ccf0/actioncombatmode|r, чтобы открыть настройки."
L["camera and targeting CVars restored."] =
  "переменные камеры и выбора цели восстановлены."
L["Cannot open settings while in combat."] =
  "Нельзя открыть настройки во время боя."
L["Cannot open this editor while in combat."] =
  "Нельзя открыть этот редактор во время боя."
L["Cannot open editor while in combat."] =
  "Нельзя открыть редактор во время боя."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "нельзя изменять переменные прицельного выбора цели во время боя."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "нельзя сбрасывать переменные прицельного выбора цели во время боя."
L["MOVEANDSTEER unbind"] = "снятие привязки MOVEANDSTEER"
L["restore default mouse camera bindings"] =
  "восстановление стандартных привязок камеры мыши"
L["Minimum Zoom"] = "Минимальное приближение"
L["ally cycle bindings"] = "привязки выбора союзника"
L["radial menu"] = "радиальное меню"
L["target lock keybinding"] = "привязка фиксации цели"
L["cycle focus next keybinding"] = "привязка смены фокуса: следующий"
L["cycle focus previous keybinding"] =
  "привязка смены фокуса: предыдущий"
L["ally cycle next keybinding"] =
  "привязка выбора союзника: следующий"
L["ally cycle previous keybinding"] =
  "привязка выбора союзника: предыдущий"
L["radial menu keybinding"] = "привязка радиального меню"
L["reticle interact keybinding"] =
  "привязка взаимодействия через прицел"
L["mouse look keybinding"] = "привязка обзора мышью"
L["flip camera keybinding"] = "привязка отражения камеры"
L["reset mouse look keybinding"] = "привязка сброса обзора мышью"
L["swap shoulder keybinding"] = "привязка смены плеча"
