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

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "ОБЗОР МЫШЬЮ"
L["CAMERA FEATURES"] = "ФУНКЦИИ КАМЕРЫ"
L["ADDITIONAL FEATURES"] = "ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ"
L["Crosshair - More accurate"] = "Прицел — точнее"
L["Soft Target - More forgiving"] = "Мягкая цель — снисходительнее"
L["Mouse Look is on"] = "Обзор мышью включён"
L["In combat"] = "В бою"
L["Talking to an NPC"] = "Разговор с NPC"
L["Any checked"] = "Любое из отмеченных"
L["All checked"] = "Все отмеченные"
L["Off"] = "Выкл."
L["Control relinquished to %s"] = "Управление передано: %s"
L["Disabled while Motion Sickness Protection is on"] =
  "Отключено, пока включена защита от укачивания"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "Фиксирует курсор в позиции прицела и позволяет поворачивать камеру движением мыши без удержания правой кнопки."
L["Mouse Look Keybind"] = "Клавиша обзора мышью"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "Нажмите, чтобы включить или выключить обзор мышью. Удерживайте, чтобы временно освободить курсор."
L["Interact Keybind"] = "Клавиша взаимодействия"
L["Tap to interact with a player or the unit chosen below."] =
  "Нажмите, чтобы взаимодействовать с игроком или с целью, выбранной ниже."
L["Players"] = "Игроки"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "Наведите прицел на игрока на секунду — HUD помощи покажет подсказку. Затем нажмите клавишу, чтобы открыть его контекстное меню."
L["NPCs and objects"] = "NPC и объекты"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "Взаимодействует как обычно с целью, выбранной в пункте «Цель взаимодействия»."
L["Interact Unit"] = "Цель взаимодействия"
L["Which unit will be interacted with when the key is pressed."] =
  "С какой целью будет происходить взаимодействие при нажатии клавиши."
L["Flip Camera Keybind"] = "Клавиша разворота камеры"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "Нажмите, чтобы развернуть камеру на 180° вокруг персонажа. Удерживайте, чтобы камера была развёрнута, только пока клавиша зажата."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "Восстанавливает зависший курсор после переключения окон в macOS. Заново захватывает и отпускает обзор мышью, чтобы снять захват, оставшийся после работы игры в фоне."
L["Curated camera adjustments for a more action-focused experience."] =
  "Подобранные настройки камеры для более динамичной игры."
L["Motion Sickness Protection"] = "Защита от укачивания"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Не позволяет Action Combat Mode переопределять настройки защиты от укачивания Blizzard."
L["Turn Speed"] = "Скорость поворота"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "Определяет, как быстро поворачивается камера при обзоре мышью."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "Не даёт камере приближаться ближе этого расстояния. 0 отключает ограничение."
L["Dynamic Pitch"] = "Динамический наклон"
L["Dynamically tilt the camera up and down as you move it."] =
  "Динамически наклоняет камеру вверх и вниз при её перемещении."
L["Pitch Strength"] = "Сила наклона"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "Насколько сильно динамический наклон отклоняет камеру. Меньшие значения удерживают персонажа выше на экране. При полёте наклон больше и зависит от этого значения."
L["Shoulder Offset"] = "Смещение через плечо"
L["Camera's horizontal position relative to the character."] =
  "Горизонтальное положение камеры относительно персонажа."
L["Disable Offset With Mouselook"] =
  "Отключать смещение при обзоре мышью"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "При выключении обзора мышью смещение через плечо плавно возвращается к 0."
L["When off, Shoulder Offset stays constant at all times."] =
  "Если выключено, смещение через плечо всегда остаётся постоянным."
L["Swap Shoulder Keybind"] = "Клавиша смены плеча"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "Нажмите, чтобы отразить смещение через плечо на другую сторону персонажа."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "Дополнительные функции, связанные с поведением обзора мышью."
L["Cursor Pulse"] = "Пульсация курсора"
L["Flash the cursor when Mouse Look is turned off."] =
  "Мигает курсором при выключении обзора мышью."
L["Hide Tooltips"] = "Скрывать подсказки"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "Скрывает подсказки, пока включён обзор мышью, если не удерживается клавиша ниже."
L["Show Tooltips With"] = "Показывать подсказки по"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "Удерживайте эту клавишу, чтобы показывать подсказки при включённом обзоре мышью."
L["Auto Sheath"] = "Автоматически убирать оружие"
L["Sheath weapons automatically with Mouse Look."] =
  "Автоматически убирает оружие вместе с обзором мышью."
L["Vignette Shows When"] = "Виньетка появляется, когда"
L["Darkens the edges of the screen while the checked situations are true."] =
  "Затемняет края экрана, пока выполняются отмеченные условия."
L["Vignette Match"] = "Условие виньетки"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "Любое: достаточно одного отмеченного условия. Все: все отмеченные условия должны выполняться одновременно."
