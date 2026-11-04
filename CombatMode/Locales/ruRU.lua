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

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "Любая выбранная цель"
L["Locked Target Only"] = "Только захваченная цель"
L["Soft Target (Blizzard)"] = "Мягкая цель (Blizzard)"
L["Hidden"] = "Скрыто"
L["Toggle"] = "Переключить"
L["Switch Target"] = "Сменить цель"
L["A UI Reload is required when making this change. Proceed?"] =
  "Для этого изменения требуется перезагрузка интерфейса. Продолжить?"
L["Create New Macro"] = "Создать новый макрос"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "Напишите макрос, начинающийся с вашей преддиректории наведения по прицелу."
L["Unavailable in combat."] = "Недоступно в бою."
L["Drag to a button on your action bars to use."] =
  "Перетащите на кнопку панели команд, чтобы использовать."
L["Right-click to edit"] = "ПКМ — изменить"
L["+%d more in /macro"] = "Ещё %d в /macro"
L["Reticle Targeting Macros"] = "Макросы наведения по прицелу"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "Кнопки действий, являющиеся макросами, не наследуют логику наведения по прицелу автоматически. Чтобы они её соблюдали, создайте их в редакторе макросов и перетащите на панели."
L["Reticle Targeting"] = "Наведение по прицелу"
L["RETICLE TARGETING"] = "НАВЕДЕНИЕ ПО ПРИЦЕЛУ"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "Включает выбор целей наведением и точное размещение заклинаний по земле и массовых умений."
L["Enable Reticle Targeting"] = "Включить наведение по прицелу"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "Наводите прицел на цели, чтобы выбирать их вместо перебора клавишей Tab."
L["Ignore Friendlies"] = "Игнорировать союзников"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "Игнорирует дружественных NPC и игроков и выбирает только враждебные цели."
L["Click Casting Only"] = "Только Click Casting"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "Применять логику наведения по прицелу только к привязкам Click Casting."
L["Excluded Spells"] = "Исключённые заклинания"
L["Spells to skip the reticle targeting logic."] =
  "Заклинания, для которых логика наведения по прицелу не применяется."
L["Cast at Crosshair"] = "Применять в прицел"
L["Ground spells to cast at the crosshair location."] =
  "Заклинания по земле, применяемые в точку прицела."
L["TARGET LOCK"] = "ЗАХВАТ ЦЕЛИ"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "Захватывайте цель, чтобы случайно не сменить её, и переключайтесь между целями, чтобы выделять нужных врагов."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "Внимание: захват цели использует вашу цель фокуса. Всё, что меняет фокус, будет ему мешать."
L["Target Lock Keybind"] = "Клавиша захвата цели"
L["Lock the reticle to a target, preventing it from swapping."] =
  "Фиксирует прицел на цели, не позволяя ему переключаться."
L["Cycle Lock - Next"] = "Смена захвата — следующая"
L["Move Target Lock to the next valid nearby target."] =
  "Переносит захват на следующую подходящую цель поблизости."
L["Cycle Lock - Previous"] = "Смена захвата — предыдущая"
L["Move Target Lock to the previous valid nearby target."] =
  "Переносит захват на предыдущую подходящую цель поблизости."
L["Target Lock Behavior"] = "Поведение захвата цели"
L["What the Target Lock key does when you press it."] =
  "Что делает клавиша захвата цели при нажатии."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "Захватывает вашу цель или цель под прицелом. Повторное нажатие снимает захват."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "Захватывает цель под прицелом, заменяя текущий захват. Нажатие, когда под прицелом ничего нет, снимает захват. Если навести прицел на уже захваченную цель, захват сохраняется."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "Если включено «Игнорировать союзников», дружественная или мёртвая цель под прицелом игнорируется: захват остаётся на месте."
L["Auto Target Lock"] = "Автозахват цели"
L["Target Lock engages automatically when attacking units."] =
  "Захват цели включается автоматически при атаке юнитов."
L["Target Lock Marker"] = "Метка захвата цели"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "Показывает метку прицела на индикаторе имени захваченной цели."
L["Focus Locked Target"] = "Фокус на захваченной цели"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "Притягивает камеру к захваченной цели, удерживая её в фокусе."
L["TARGETING INDICATORS"] = "ИНДИКАТОРЫ ЦЕЛИ"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "Визуальные индикаторы, выделяющие цели в мире для лучшего распознавания."
L["Target Outline"] = "Контур цели"
L["Show an outline effect on your target."] =
  "Показывает контур вокруг вашей цели."
L["Only available on Retail"] = "Доступно только в Retail"
L["Selection Circle"] = "Круг выделения"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "У какой цели под ногами отображается круг выделения Blizzard."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "Круг под любой выбранной целью, вражеской или дружественной."
L["The circle only under your Target Lock."] =
  "Круг только под вашей захваченной целью."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "Поведением ObjectSelectionCircle и UnitNameFocused управляет Blizzard."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "Blizzard выбирает мягкую цель из сектора перед моделью персонажа. Положение прицела и смещение через плечо не учитываются."
L["No selection circle."] = "Круг выделения не показывается."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "Прицел"
L["CROSSHAIR"] = "ПРИЦЕЛ"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "Динамический прицел, реагирующий на цели и состояния боя, повышает точность и направляет наведение по прицелу."
L["Enable Crosshair"] = "Включить прицел"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "Во время обзора мышью показывает на экране динамический реагирующий прицел."
L["Cast Feedback"] = "Отклик на применение"
L["Crosshair provides visual feedback while casting."] =
  "Прицел визуально отзывается во время применения заклинаний."
L["Appearance"] = "Внешний вид"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "Текстуры прицела для каждого состояния. Нажмите на одну, чтобы выбрать текстуру, или начните с шаблона."
L["Inactive"] = "Неактивен"
L["Active"] = "Активен"
L["Mounted"] = "На транспорте"
L["Disabled"] = "Отключён"
L["Reaction Colors"] = "Цвета реакции"
L["Edit"] = "Изменить"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "Настройте цвета прицела при наведении на разные типы целей."
L["Scale"] = "Масштаб"
L["Scales the size of the crosshair."] = "Масштабирует размер прицела."
L["Vertical Position"] = "Вертикальное положение"
L["Move the crosshair up or down from screen center."] =
  "Смещает прицел вверх или вниз от центра экрана."
L["ASSIST HUD"] = "HUD ПОМОЩИ"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "HUD, подсказывающий порядок заклинаний при наведении на врагов и показывающий подсказки взаимодействия."
L["Next-cast Suggestion"] = "Подсказка следующего заклинания"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "Показывает подсказку следующего заклинания от Помощника по боевым действиям при наведении на цель."
L["Always"] = "Всегда"
L["Only In Combat"] = "Только в бою"
L["Interactable Indicator"] = "Индикатор взаимодействия"
L["Show an indicator while aiming at an interactable unit or object."] =
  "Показывает индикатор при наведении на юнит или объект, с которым можно взаимодействовать."
L["Player Interaction Prompt"] = "Подсказка взаимодействия с игроком"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "Показывает индикатор, если навести прицел на игрока на секунду. Клавиша взаимодействия откроет его контекстное меню."
L["Position"] = "Положение"
L["Which side of the crosshair the HUD appears on."] =
  "С какой стороны от прицела появляется HUD."
L["Left"] = "Слева"
L["Right"] = "Справа"
L["Scales the size of the HUD."] = "Масштабирует размер HUD."
L["Distance"] = "Расстояние"
L["Distance between the HUD and the crosshair."] =
  "Расстояние между HUD и прицелом."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "Измененные действия Blizzard"
L["Blizzard Actions"] = "Действия Blizzard"
L["Base"] = "Базовый"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "Сбросить цель"
L["Clear Focus"] = "Сбросить фокус"
L["Start Attack"] = "Начать атаку"
L["Pet Attack"] = "Атака питомца"
L["Toggle Focus Any"] = "Переключить фокус (любая цель)"
L["Toggle Focus Enemy"] = "Переключить фокус (враг)"
L["Run MACRO"] = "Запустить MACRO"
L["— none —"] = "— нет —"
L["Override this click during Mouse Look."] =
  "Заменяет этот щелчок во время обзора мышью."
L["Action"] = "Действие"
L["Macro"] = "Макрос"
L["Select a macro"] = "Выберите макрос"
L["No targeting"] = "Без наведения"
L["Left Click"] = "Левый щелчок"
L["Right Click"] = "Правый щелчок"
L["Shift + Left Click"] = "Shift + Левый щелчок"
L["Shift + Right Click"] = "Shift + Правый щелчок"
L["Ctrl + Left Click"] = "Ctrl + Левый щелчок"
L["Ctrl + Right Click"] = "Ctrl + Правый щелчок"
L["Alt + Left Click"] = "Alt + Левый щелчок"
L["Alt + Right Click"] = "Alt + Правый щелчок"
L["Click Casting"] = "Применение по щелчку"
L["CLICK CASTING"] = "ПРИМЕНЕНИЕ ПО ЩЕЛЧКУ"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "Назначьте действия-замены на левый и правый щелчок, действующие во время обзора мышью."
L["Account-Wide Binds"] = "Привязки для всей учетной записи"
L["Share Click Casting binds across all characters."] =
  "Общие привязки применения по щелчку для всех персонажей."
L["Click Binds"] = "Привязки щелчков"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "У базового режима, Shift, Ctrl и Alt есть свои действия для левого и правого щелчка."

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "Колеса радиального меню"
L["Forever"] = "Forever"
L["Minimal"] = "Минимализм"
L["Clear Slice"] = "Очистить сектор"
L["UI Actions"] = "Действия интерфейса"
L["Emotes"] = "Эмоции"
L["Commands"] = "Команды"
L["Markers"] = "Метки"
L["Slice"] = "Сектор"
L["Choose an action"] = "Выберите действие"
L["Presets"] = "Шаблоны"
L["New Wheel"] = "Новое колесо"
L["Wheel"] = "Колесо"
L["You can have up to %d wheels."] = "Можно создать не более %d колес."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "Это нельзя поместить на колесо. Используйте заклинание, предмет, игрушку, средство передвижения или макрос."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "Перетащите сюда заклинание, предмет, игрушку, средство передвижения или макрос либо щелкните, чтобы сменить действие."
L["Empty Slice"] = "Пустой сектор"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "Перетащите сюда заклинание, предмет, игрушку, средство передвижения или макрос либо щелкните, чтобы задать действие. Пустые секторы в колесо не попадают."
L["A wheel needs at least one slice."] =
  "Колесо должно содержать хотя бы один сектор."
L["Click to rename this wheel"] =
  "Щелкните, чтобы переименовать колесо"
L["Previous wheel"] = "Предыдущее колесо"
L["Next wheel"] = "Следующее колесо"
L["Click to select this wheel, drag to reorder"] =
  "Щелчок выбирает колесо, перетаскивание меняет порядок"
L["Add Slice"] = "Добавить сектор"
L["A wheel holds up to %d slices."] =
  "На колесе может быть не более %d секторов."
L["Remove Wheel"] = "Удалить колесо"
L["Deletes this wheel and all of its slices."] =
  "Удаляет это колесо и все его секторы."
L["You need at least one wheel."] = "Нужно хотя бы одно колесо."
L["Remove this wheel and all of its slices?"] =
  "Удалить это колесо и все его секторы?"
L["Add Wheel"] = "Добавить колесо"
L["Pick a preset wheel or a blank one."] =
  "Выберите готовое колесо или пустое."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "Щелкните сектор, чтобы выбрать действие, или перетащите на него заклинание, предмет, игрушку, средство передвижения или макрос.\nПеретащите сектор, чтобы изменить порядок. Правый щелчок удаляет его."
L["RADIAL MENU"] = "РАДИАЛЬНОЕ МЕНЮ"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "Создавайте колеса быстрого доступа для заклинаний, предметов, макросов, эмоций и ярлыков интерфейса."
L["Radial Menu Keybind"] = "Клавиша радиального меню"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "Удерживайте, чтобы открыть радиальное меню, наведитесь на сектор и отпустите для активации. Колесо мыши переключает колеса."
L["Radial Menu Style"] = "Стиль радиального меню"
L["Choose the appearance of the Radial Menu wheels."] =
  "Выберите внешний вид колес радиального меню."
L["Party Wheel Spells"] = "Заклинания колеса группы"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "Полезные заклинания, открывающие колесо выбора цели из группы, пока удерживается их клавиша. Сдвиньте курсор к участнику группы и отпустите, чтобы применить на него, или вернитесь в центр, чтобы применить на себя. Короткое нажатие применяет на дружественную цель, а если ее нет, то на вас."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "Редактируйте секторы каждого колеса, переименовывайте колеса, добавляйте и удаляйте их."
