---------------------------------------------------------------------------------------
--  Locales/zhCN.lua — LOCALES — Chinese (Simplified) strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the zhCN client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "zhCN", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "zhCN" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "欢迎使用 Action Combat Mode！"
L["The configuration panel will open after you close this message."] =
  "关闭此消息后将打开设置面板。"
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "你可以随时使用 |cff69ccf0/acm|r 或 |cff69ccf0/actioncombatmode|r 重新打开。"
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090要恢复之前的设置，请使用选项面板中的|cffff5555卸载|r按钮。|r"
L["Mouse Look"] = "鼠标视角"
L["Flip Camera"] = "翻转镜头"
L["Swap Shoulder"] = "切换肩部视角"
L["Reset Mouse Look"] = "重置鼠标视角"
L["Ally Cycle Next"] = "友方循环：下一个"
L["Ally Cycle Previous"] = "友方循环：上一个"
L["Toggle Focus Target"] = "切换焦点目标"
L["Cycle Focus Next"] = "焦点循环：下一个"
L["Cycle Focus Previous"] = "焦点循环：上一个"
L["Radial Menu"] = "轮盘菜单"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "按键绑定更改"
L["deferred %s until combat ends."] = "%s已推迟到战斗结束后。"
L["failed to apply %s: %s"] = "应用%s失败：%s"
L["applied deferred binding updates."] = "已应用推迟的按键绑定更新。"
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50检测到 %s！|r 正在移交转向速度、肩部视角和动态俯仰。"
L["Cannot uninstall while in combat."] = "战斗中无法卸载。"
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "已恢复你之前的镜头/目标设置和默认的鼠标镜头按键绑定，并已禁用此插件。"
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "输入 |cff69ccf0/acm|r 或 |cff69ccf0/actioncombatmode|r 打开设置。"
L["camera and targeting CVars restored."] = "已恢复镜头和目标选择 CVar。"
L["Cannot open settings while in combat."] = "战斗中无法打开设置。"
L["Cannot open this editor while in combat."] = "战斗中无法打开此编辑器。"
L["Cannot open editor while in combat."] = "战斗中无法打开编辑器。"
L["cannot edit Reticle Targeting CVars while in combat."] =
  "战斗中无法编辑准星选目标的 CVar。"
L["cannot reset Reticle Targeting CVars while in combat."] =
  "战斗中无法重置准星选目标的 CVar。"
L["MOVEANDSTEER unbind"] = "解除 MOVEANDSTEER 绑定"
L["restore default mouse camera bindings"] = "恢复默认的鼠标镜头按键绑定"
L["Minimum Zoom"] = "最小缩放"
L["ally cycle bindings"] = "友方循环按键绑定"
L["radial menu"] = "轮盘菜单"
L["target lock keybinding"] = "锁定目标按键绑定"
L["cycle focus next keybinding"] = "焦点循环下一个按键绑定"
L["cycle focus previous keybinding"] = "焦点循环上一个按键绑定"
L["ally cycle next keybinding"] = "友方循环下一个按键绑定"
L["ally cycle previous keybinding"] = "友方循环上一个按键绑定"
L["radial menu keybinding"] = "轮盘菜单按键绑定"
L["reticle interact keybinding"] = "准星交互按键绑定"
L["mouse look keybinding"] = "鼠标视角按键绑定"
L["flip camera keybinding"] = "翻转镜头按键绑定"
L["reset mouse look keybinding"] = "重置鼠标视角按键绑定"
L["swap shoulder keybinding"] = "切换肩部视角按键绑定"

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "鼠标视角"
L["CAMERA FEATURES"] = "镜头功能"
L["ADDITIONAL FEATURES"] = "附加功能"
L["Crosshair - More accurate"] = "准星 - 更精确"
L["Soft Target - More forgiving"] = "软目标 - 更宽容"
L["Mouse Look is on"] = "鼠标视角已开启"
L["In combat"] = "战斗中"
L["Talking to an NPC"] = "与NPC对话中"
L["Any checked"] = "任一勾选项"
L["All checked"] = "所有勾选项"
L["Off"] = "关闭"
L["Control relinquished to %s"] = "已将控制权交给 %s"
L["Disabled while Motion Sickness Protection is on"] = "动态眩晕保护开启时不可用"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "将光标锁定在准星位置，移动鼠标即可转向，无需按住右键。"
L["Mouse Look Keybind"] = "鼠标视角按键"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "点按切换鼠标视角，按住可暂时解锁光标。"
L["Interact Keybind"] = "交互按键"
L["Tap to interact with a player or the unit chosen below."] =
  "点按可与玩家或下方所选单位交互。"
L["Players"] = "玩家"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "瞄准玩家一秒后，辅助HUD会显示提示，此时按下该键即可打开其右键菜单。"
L["NPCs and objects"] = "NPC和物体"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "与“交互单位”中选择的单位正常交互。"
L["Interact Unit"] = "交互单位"
L["Which unit will be interacted with when the key is pressed."] =
  "按下按键时与哪个单位进行交互。"
L["Flip Camera Keybind"] = "翻转镜头按键"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "点按可将镜头绕角色翻转180°；按住则仅在按住期间保持翻转。"
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "修复在macOS上切换窗口后光标卡住的问题。重新捕获并释放鼠标视角，以清除游戏在后台运行时遗留的卡住的捕获。"
L["Curated camera adjustments for a more action-focused experience."] =
  "为更注重动作的体验精选的镜头调整。"
L["Motion Sickness Protection"] = "动态眩晕保护"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "防止 Action Combat Mode 覆盖暴雪的动态眩晕设置。"
L["Turn Speed"] = "转向速度"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "控制使用鼠标视角时镜头的转动速度。"
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "限制镜头拉近的最小距离。设为0则关闭。"
L["Dynamic Pitch"] = "动态俯仰"
L["Dynamically tilt the camera up and down as you move it."] =
  "移动镜头时动态地上下倾斜镜头。"
L["Pitch Strength"] = "俯仰强度"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "动态俯仰使镜头倾斜的幅度。数值越低，角色在屏幕上的位置越高。飞行时倾斜幅度更大，并随此值缩放。"
L["Shoulder Offset"] = "越肩偏移"
L["Camera's horizontal position relative to the character."] =
  "镜头相对于角色的水平位置。"
L["Disable Offset With Mouselook"] = "鼠标视角时禁用偏移"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "关闭鼠标视角时，越肩偏移会平滑过渡到0。"
L["When off, Shoulder Offset stays constant at all times."] =
  "关闭时，越肩偏移始终保持不变。"
L["Swap Shoulder Keybind"] = "切换肩膀按键"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "按下可将越肩偏移镜像到角色的另一侧。"
L["Extra functionalities tied to Mouse Look behaviour."] =
  "与鼠标视角行为相关的额外功能。"
L["Cursor Pulse"] = "光标脉冲"
L["Flash the cursor when Mouse Look is turned off."] = "关闭鼠标视角时让光标闪烁。"
L["Hide Tooltips"] = "隐藏提示"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "鼠标视角开启时隐藏提示，除非按住下方的按键。"
L["Show Tooltips With"] = "显示提示按键"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "鼠标视角开启时，按住此键可显示提示。"
L["Auto Sheath"] = "自动收起武器"
L["Sheath weapons automatically with Mouse Look."] = "随鼠标视角自动收起武器。"
L["Vignette Shows When"] = "暗角显示条件"
L["Darkens the edges of the screen while the checked situations are true."] =
  "当勾选的情形成立时，使屏幕边缘变暗。"
L["Vignette Match"] = "暗角匹配方式"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "任一：勾选的情形满足其一即可。全部：所有勾选的情形必须同时成立。"

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "任何硬目标"
L["Locked Target Only"] = "仅锁定的目标"
L["Soft Target (Blizzard)"] = "软目标（暴雪）"
L["Hidden"] = "隐藏"
L["Toggle"] = "切换"
L["Switch Target"] = "切换目标"
L["A UI Reload is required when making this change. Proceed?"] =
  "进行此更改需要重载界面。是否继续？"
L["Create New Macro"] = "创建新宏"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "编写一个以准星瞄准前置行开头的宏。"
L["Unavailable in combat."] = "战斗中不可用。"
L["Drag to a button on your action bars to use."] = "拖到动作条按钮上即可使用。"
L["Right-click to edit"] = "右键编辑"
L["+%d more in /macro"] = "/macro 中还有 %d 个"
L["Reticle Targeting Macros"] = "准星瞄准宏"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "作为宏的动作按钮不会自动继承准星瞄准逻辑。若要让它们遵循这些规则，请使用宏编写器创建，然后拖到动作条上。"
L["Reticle Targeting"] = "准星瞄准"
L["RETICLE TARGETING"] = "准星瞄准"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "启用基于瞄准的单位选取，并可精确放置地面法术和范围技能。"
L["Enable Reticle Targeting"] = "启用准星瞄准"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "将准星对准单位来选取目标，取代Tab选取。"
L["Ignore Friendlies"] = "忽略友方"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "忽略友方NPC和玩家，只选取敌对单位。"
L["Click Casting Only"] = "仅点击施法"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "仅对点击施法绑定应用准星瞄准逻辑。"
L["Excluded Spells"] = "排除的法术"
L["Spells to skip the reticle targeting logic."] = "跳过准星瞄准逻辑的法术。"
L["Cast at Crosshair"] = "在准星处施放"
L["Ground spells to cast at the crosshair location."] = "在准星位置施放的地面法术。"
L["TARGET LOCK"] = "目标锁定"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "锁定目标以防止误切换，并在单位间循环以优先处理特定敌人。"
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "警告：目标锁定会使用你的焦点目标。其他任何设置焦点的功能都会与之冲突。"
L["Target Lock Keybind"] = "目标锁定按键"
L["Lock the reticle to a target, preventing it from swapping."] =
  "将准星锁定在目标上，防止其切换。"
L["Cycle Lock - Next"] = "循环锁定 - 下一个"
L["Move Target Lock to the next valid nearby target."] =
  "将目标锁定移至附近下一个有效目标。"
L["Cycle Lock - Previous"] = "循环锁定 - 上一个"
L["Move Target Lock to the previous valid nearby target."] =
  "将目标锁定移至附近上一个有效目标。"
L["Target Lock Behavior"] = "目标锁定行为"
L["What the Target Lock key does when you press it."] = "按下目标锁定键时的行为。"
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "锁定你的目标或准星下的单位。再次点按可解除锁定。"
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "锁定准星下的单位，并替换当前的锁定。准星下没有目标时点按可解除锁定。瞄准已锁定的单位则保持锁定。"
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "开启“忽略友方”后，准星下的友方或已死亡单位会被忽略：锁定保持不变。"
L["Auto Target Lock"] = "自动目标锁定"
L["Target Lock engages automatically when attacking units."] =
  "攻击单位时自动启用目标锁定。"
L["Target Lock Marker"] = "目标锁定标记"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "在被锁定目标的姓名板上显示准星标记。"
L["Focus Locked Target"] = "聚焦锁定目标"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "将镜头拉向被锁定的目标，使其保持在焦点中。"
L["TARGETING INDICATORS"] = "目标指示"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "在世界中高亮显示目标的视觉指示，便于辨认。"
L["Target Outline"] = "目标轮廓"
L["Show an outline effect on your target."] = "在你的目标上显示轮廓效果。"
L["Only available on Retail"] = "仅在正式服可用"
L["Selection Circle"] = "选择圈"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "决定哪个目标脚下显示暴雪的选择圈。"
L["The circle under whatever you have targeted, enemy or friendly."] =
  "显示在你选中的任何目标（无论敌友）脚下的圈。"
L["The circle only under your Target Lock."] = "仅显示在你的锁定目标脚下。"
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "由暴雪控制 ObjectSelectionCircle 和 UnitNameFocused 的行为。"
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "暴雪会从角色模型前方的扇形区域中选取软目标，不会考虑准星位置或越肩偏移。"
L["No selection circle."] = "不显示选择圈。"

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "准星"
L["CROSSHAIR"] = "准星"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "会对目标和战斗状态做出反应的动态准星，可提升精度并引导准星瞄准。"
L["Enable Crosshair"] = "启用准星"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "处于鼠标视角时，在屏幕上显示动态且有反馈的准星。"
L["Cast Feedback"] = "施法反馈"
L["Crosshair provides visual feedback while casting."] = "施法时准星会提供视觉反馈。"
L["Appearance"] = "外观"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "准星在各状态下使用的纹理。点击其一可选择纹理，也可从预设开始。"
L["Inactive"] = "未激活"
L["Active"] = "已激活"
L["Mounted"] = "骑乘中"
L["Disabled"] = "已禁用"
L["Reaction Colors"] = "反应颜色"
L["Edit"] = "编辑"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "自定义准星瞄准不同类型单位时使用的颜色。"
L["Scale"] = "缩放"
L["Scales the size of the crosshair."] = "缩放准星的大小。"
L["Vertical Position"] = "垂直位置"
L["Move the crosshair up or down from screen center."] =
  "将准星从屏幕中心上移或下移。"
L["ASSIST HUD"] = "辅助HUD"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "瞄准敌人时引导技能循环，并显示交互提示的HUD。"
L["Next-cast Suggestion"] = "下一个施法建议"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "瞄准目标时显示辅助高亮的下一个施法建议。"
L["Always"] = "始终"
L["Only In Combat"] = "仅战斗中"
L["Interactable Indicator"] = "可交互指示"
L["Show an indicator while aiming at an interactable unit or object."] =
  "瞄准可交互的单位或物体时显示指示。"
L["Player Interaction Prompt"] = "玩家交互提示"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "瞄准玩家一秒后显示指示。按下交互键即可打开其右键菜单。"
L["Position"] = "位置"
L["Which side of the crosshair the HUD appears on."] = "HUD显示在准星的哪一侧。"
L["Left"] = "左"
L["Right"] = "右"
L["Scales the size of the HUD."] = "缩放HUD的大小。"
L["Distance"] = "距离"
L["Distance between the HUD and the crosshair."] = "HUD与准星之间的距离。"

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "已修改的暴雪动作"
L["Blizzard Actions"] = "暴雪动作"
L["Base"] = "基础"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "清除目标"
L["Clear Focus"] = "清除焦点"
L["Start Attack"] = "开始攻击"
L["Pet Attack"] = "宠物攻击"
L["Toggle Focus Any"] = "切换焦点（任意）"
L["Toggle Focus Enemy"] = "切换焦点（敌人）"
L["Run MACRO"] = "运行 MACRO"
L["— none —"] = "— 无 —"
L["Override this click during Mouse Look."] = "在鼠标视角期间覆盖此次点击。"
L["Action"] = "动作"
L["Macro"] = "宏"
L["Select a macro"] = "选择宏"
L["No targeting"] = "无瞄准"
L["Left Click"] = "左键点击"
L["Right Click"] = "右键点击"
L["Shift + Left Click"] = "Shift + 左键点击"
L["Shift + Right Click"] = "Shift + 右键点击"
L["Ctrl + Left Click"] = "Ctrl + 左键点击"
L["Ctrl + Right Click"] = "Ctrl + 右键点击"
L["Alt + Left Click"] = "Alt + 左键点击"
L["Alt + Right Click"] = "Alt + 右键点击"
L["Click Casting"] = "点击施法"
L["CLICK CASTING"] = "点击施法"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "为左键和右键点击指定在鼠标视角期间生效的覆盖动作。"
L["Account-Wide Binds"] = "账号通用绑定"
L["Share Click Casting binds across all characters."] =
  "在所有角色之间共享点击施法绑定。"
L["Click Binds"] = "点击绑定"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "基础、Shift、Ctrl 和 Alt 各自拥有独立的左键和右键点击动作。"

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "轮盘菜单的轮盘"
L["Forever"] = "Forever"
L["Minimal"] = "极简"
L["Clear Slice"] = "清空扇区"
L["UI Actions"] = "界面动作"
L["Emotes"] = "表情"
L["Commands"] = "命令"
L["Markers"] = "标记"
L["Slice"] = "扇区"
L["Choose an action"] = "选择动作"
L["Presets"] = "预设"
L["New Wheel"] = "新轮盘"
L["Wheel"] = "轮盘"
L["You can have up to %d wheels."] = "最多可以有 %d 个轮盘。"
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "无法放入轮盘。请使用法术、物品、玩具、坐骑或宏。"
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "将法术、物品、玩具、坐骑或宏拖到此处，或点击以更改动作。"
L["Empty Slice"] = "空扇区"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "将法术、物品、玩具、坐骑或宏拖到此处，或点击以设置动作。空扇区不会出现在轮盘中。"
L["A wheel needs at least one slice."] = "轮盘至少需要一个扇区。"
L["Click to rename this wheel"] = "点击重命名此轮盘"
L["Previous wheel"] = "上一个轮盘"
L["Next wheel"] = "下一个轮盘"
L["Click to select this wheel, drag to reorder"] = "点击选择此轮盘，拖动可重新排序"
L["Add Slice"] = "添加扇区"
L["A wheel holds up to %d slices."] = "一个轮盘最多有 %d 个扇区。"
L["Remove Wheel"] = "移除轮盘"
L["Deletes this wheel and all of its slices."] = "删除此轮盘及其所有扇区。"
L["You need at least one wheel."] = "至少需要一个轮盘。"
L["Remove this wheel and all of its slices?"] = "要移除此轮盘及其所有扇区吗？"
L["Add Wheel"] = "添加轮盘"
L["Pick a preset wheel or a blank one."] = "选择预设轮盘或空白轮盘。"
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "点击扇区选择其动作，或将法术、物品、玩具、坐骑或宏拖放到其上。\n拖动扇区可重新排序，右键点击可移除。"
L["RADIAL MENU"] = "轮盘菜单"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "为法术、物品、宏、表情和界面快捷方式创建快速访问轮盘。"
L["Radial Menu Keybind"] = "轮盘菜单按键"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "按住以打开轮盘菜单，瞄准一个扇区后松开即可触发。滚动鼠标滚轮可切换轮盘。"
L["Radial Menu Style"] = "轮盘菜单样式"
L["Choose the appearance of the Radial Menu wheels."] = "选择轮盘菜单的外观。"
L["Party Wheel Spells"] = "队伍轮盘法术"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "按住按键时会打开队伍选取轮盘的增益法术。向队友方向滑动并松开即可对其施法，回到中心则对自己施法。轻按则对友方目标施法，未选择目标时对自己施法。"
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "编辑每个轮盘的扇区，重命名轮盘，以及添加或移除轮盘。"
