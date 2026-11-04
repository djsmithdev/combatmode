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

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "顶部"
L["Bottom"] = "底部"
L["Ally Cycle"] = "友方循环"
L["ALLY CYCLE"] = "友方循环"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "战斗与辅助无缝衔接：增益法术以友方为目标，而伤害法术仍锁定准星下的敌方目标。"
L["Ally Cycle - Next"] = "友方循环 - 下一个"
L["Target the next group member."] = "选定下一位队伍成员。"
L["Ally Cycle - Previous"] = "友方循环 - 上一个"
L["Target the previous group member."] = "选定上一位队伍成员。"
L["Skip Self"] = "跳过自己"
L["Skip yourself when cycling through group members."] =
  "在循环切换队伍成员时跳过自己。"
L["Keep Ally After Harm"] = "攻击后保留友方"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "有害法术作用于准星下的敌人后，恢复之前的友方目标。治疗专精默认开启，直到被更改。"
L["Disabled while Auto Target Lock is on"] = "自动目标锁定开启时已禁用"
L["ALLY HUD"] = "友方 HUD"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "显示友方循环所选队伍成员的 HUD。"
L["Ally HUD"] = "友方 HUD"
L["Show a unit frame for the currently selected group member."] =
  "为当前选定的队伍成员显示单位框体。"
L["Where the Ally HUD sits relative to the crosshair."] = "友方 HUD 相对于准星的位置。"
L["Scales the size of the Ally HUD."] = "缩放友方 HUD 的大小。"
L["Distance between the Ally HUD and the crosshair."] = "友方 HUD 与准星之间的距离。"

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "自动解锁"
L["AUTO UNLOCK"] = "自动解锁"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "打开窗口时自动暂停鼠标视角，关闭后恢复。"
L["Release the cursor when UI panels open."] = "打开界面面板时释放光标。"
L["Unlock Mounts"] = "解锁坐骑"
L["Mounts that force a cursor unlock while mounted."] = "骑乘时会强制释放光标的坐骑。"
L["Extra Frames"] = "额外框体"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "触发自动解锁的额外框体名称。输入以搜索暴雪和插件框体，或使用检查按钮点击屏幕上的窗口。"

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "高级"
L["SOUNDS"] = "音效"
L["Control the sound cues used by some of the other features."] =
  "控制其他一些功能所使用的提示音。"
L["Mouse Look Sounds"] = "鼠标视角音效"
L["Play a cue when Mouse Look turns on and off."] =
  "鼠标视角开启或关闭时播放提示音。"
L["Target Lock Sounds"] = "目标锁定音效"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "设置、清除或切换目标锁定时播放提示音。"
L["Radial Menu Sounds"] = "轮盘菜单音效"
L["Play cues when interacting with Radial Menu wheels."] =
  "与轮盘菜单的轮盘交互时播放提示音。"
L["Ally Cycle Sounds"] = "友方循环音效"
L["Play a cue when Ally Cycle moves to another ally."] =
  "友方循环切换到另一名友方时播放提示音。"
L["FORCE LOCK"] = "强制锁定"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "高级选项：只要自定义 Lua 条件为真，就保持鼠标视角开启。"
L["Custom Condition"] = "自定义条件"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "自定义 Lua 代码，求值为真时会使鼠标视角保持锁定。"
L["Lock Once"] = "仅锁定一次"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "仅在条件首次变为真时锁定鼠标视角。手动解锁会一直生效，直到条件变为假后再次变为真。"
L["FORCE UNLOCK"] = "强制解锁"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "与“强制锁定”相反：只要自定义 Lua 条件为真，就保持鼠标视角关闭。"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "自定义 Lua 代码，求值为真时会使鼠标视角保持解锁。"
L["Unlock Once"] = "仅解锁一次"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "仅在条件首次变为真时解锁鼠标视角。手动锁定会一直生效，直到条件变为假后再次变为真。"
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "只要自定义 Lua 条件为真，就更换准星外观。"
L["Situational Appearance"] = "情境外观"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "情境条件为真时准星使用的纹理。"
L["Situational Condition"] = "情境条件"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "自定义 Lua 代码，求值为真时会强制准星使用其情境外观。"
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "修改 Action Combat Mode 默认的准星瞄准 CVar 和瞄准宏前置行。"
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "警告：编辑这些值可能会导致准星瞄准和目标锁定失效。"
L["Reticle Targeting CVar Editor"] = "准星瞄准 CVar 编辑器"
L["Targeting Macro Prelines Editor"] = "瞄准宏前置行编辑器"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "上一步"
L["Next"] = "下一步"
L["Finish"] = "完成"
L["Skip tour"] = "跳过引导"
L["Assist HUD"] = "辅助 HUD"
L["Target Lock"] = "目标锁定"
L["Party Wheel"] = "队伍轮盘"
L["Set a Mouse Look key"] = "设置鼠标视角按键"
L["Set an Interact key"] = "设置交互按键"
L["Set a Target Lock key"] = "设置目标锁定按键"
L["Set a Cycle Lock - Next key"] = "设置“循环锁定 - 下一个”按键"
L["Set a Cycle Lock - Previous key"] = "设置“循环锁定 - 上一个”按键"
L["Set a Radial Menu key"] = "设置轮盘菜单按键"
L["Set an Ally Cycle - Next key"] = "设置“友方循环 - 下一个”按键"
L["Set an Ally Cycle - Previous key"] = "设置“友方循环 - 上一个”按键"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "开启或关闭准星瞄准会重新加载界面。"
L["Needs Reticle Targeting."] = "需要准星瞄准。"
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "将光标锁定在屏幕中央，通过移动鼠标来转向，无需再按住右键。\n\n设置一个{切换按键}，以及一个与瞄准目标{交互的按键}。"
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "可根据目标和战斗状态自动变化、完全可自定义的准星。\n\n选择它的{外观}、{大小}和{位置}。"
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "瞄准敌人时，准星旁的 HUD 会建议你的{下一个法术}并显示其按键。\n\n瞄准可交互的目标时，则显示其{名称}和你的{交互按键}。\n\n可分别开启或关闭，并设置它相对准星的{方位}、{大小}和{距离}。"
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "只需瞄准即可选定敌人，并将指向性法术和范围技能直接释放在准星所指之处，无需 Tab 选目标。\n\n{忽略友方}会让它跳过友方。"
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "应在准星位置释放的指向性法术。\n\n输入{法术名称或 ID}即可添加。"
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!作为宏的动作按钮无法自行继承准星瞄准。}\n\n点击 {+} 打开{宏编辑器}，在其中编写宏，系统会自动为其添加瞄准逻辑。\n\n然后将它从此列表拖到你的动作条上；{右键点击}图标可进行编辑。"
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "一键锁定目标，让准星不再切换。锁定期间，循环按键会跳到附近的敌人。\n\n{目标锁定行为}决定再次按键是解除锁定（{切换}），还是将锁定转移到准星下的目标（{切换目标}）。\n\n设置你的按键。"
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "在鼠标视角下将鼠标点击变为动作，例如用{左键和右键}施放动作条上的法术。\n\n选择每次点击的功能，可搭配或不搭配{修饰键}。"
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "在战斗中也可使用的{法术、物品、宏和快捷方式}轮盘。\n\n按住按键，将鼠标移向某个扇区，松开即可使用。\n\n{滚动滚轮}可切换轮盘。"
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "按住此处列出的{增益法术}的按键，打开队伍成员轮盘。移向某位成员并松开即可对其施放，回到{中心}则对自己施放。\n\n{轻按}按键则对你的友方目标施放，没有目标时对自己施放。\n\n输入{法术名称或 ID}即可添加。"
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "在鼠标视角下循环切换队伍成员，让{增益法术}作用于友方，而{伤害法术}仍打向敌人。\n\n{友方 HUD}会显示当前选中的成员。\n\n设置你的循环按键。"
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "打开{背包、地图或其他窗口}时鼠标视角会暂停，关闭后恢复。\n\n添加同样需要使其暂停的{坐骑或额外框体}。"

-- Options UI: widgets, panel, search, pickers
L["What's New"] = "新增内容"
L["See what's new in this version"] = "查看此版本的新增内容"
L["Link"] = "链接"
L["Copy the %s link (Ctrl+C), then paste it in your browser."] =
  "复制 %s 的链接（Ctrl+C），然后粘贴到浏览器中。"
L["Character-specific option."] = "角色专属选项。"
L["NEW"] = "新"
L["ON"] = "开"
L["OFF"] = "关"
L["Are you sure?"] = "确定吗？"
L["> Press key (ESC clears) <"] = "> 请按键（ESC 清除）<"
L["WoW API Documentation"] = "WoW API 文档"
L["Pick a frame on screen"] = "在屏幕上选取框体"
L["Pick a frame"] = "选取框体"
L["Silence Alerts"] = "静默提示"
L["Debug Mode"] = "调试模式"
L["Reset to Defaults"] = "恢复默认设置"
L["Reset all Action Combat Mode settings to defaults and reload?"] =
  "将 Action Combat Mode 的所有设置恢复为默认值并重新加载吗？"
L["Uninstall"] = "卸载"
L["Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload."] =
  "要卸载 Action Combat Mode 吗？\n\n这将恢复你之前的镜头和目标设置，禁用此插件并重新加载。"
L["View the changelog"] = "查看更新日志"
L["Run the setup wizard again?"] = "要重新运行设置向导吗？"
L["Run the setup wizard"] = "运行设置向导"
L["GitHub Repository"] = "GitHub 仓库"
L["Discord Server"] = "Discord 服务器"
L["%s · Section"] = "%s · 分区"
L["Sidebar"] = "侧边栏"
L["Search options..."] = "搜索选项..."
L["No matching options"] = "没有匹配的选项"
L["Section"] = "分区"
L["Tab"] = "标签页"
L["Color"] = "颜色"
L["Type spell name or ID…"] = "输入法术名称或 ID…"
L["Type mount name or spell ID…"] = "输入坐骑名称或法术 ID…"
L["Type a frame name…"] = "输入框体名称…"
L["Blizzard"] = "暴雪"
L["Addon"] = "插件"
L["open"] = "已打开"
L["Click a frame to add it to the list. Right-click or press Esc to cancel."] =
  "点击一个框体即可将其添加到列表。右键点击或按 Esc 取消。"
L["Line %d: %s"] = "第 %d 行：%s"
L["Unknown API: %s - did you mean %s?"] = "未知 API：%s，你是想输入 %s 吗？"
L["Unknown API: %s"] = "未知 API：%s"
L["%s (+%d more)"] = "%s（另有 %d 个）"
L["Version: %s"] = "版本：%s"
L["Use the button below to open Action Combat Mode options."] =
  "使用下方按钮打开 Action Combat Mode 选项。"
L["You can also type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r in chat."] =
  "你也可以在聊天框中输入 |cff69ccf0/acm|r 或 |cff69ccf0/actioncombatmode|r。"
L["Open Options"] = "打开选项"

-- Editors: macro composer, prelines, crosshair colors and textures, CVar editor
L["%d / %d characters"] = "%d / %d 个字符"
L["%s (over the macro limit)"] = "%s（超出宏长度限制）"
L["Ignore Friendlies: %s"] = "忽略友方：%s"
L["Auto Target Lock: %s"] = "自动目标锁定：%s"
L["Preline: Ignore Friendlies + No Auto Lock"] = "前置行：忽略友方 + 无自动锁定"
L["Preline: Ignore Friendlies + Auto Lock"] = "前置行：忽略友方 + 自动锁定"
L["Preline: Target Any Unit + No Auto Lock"] = "前置行：选中任意单位 + 无自动锁定"
L["Preline: Target Any Unit + Auto Lock"] = "前置行：选中任意单位 + 自动锁定"
L["Macro Composer"] = "宏编辑器"
L["The targeting logic preline matching your current Reticle Targeting settings is added automatically before your lines, as the highlighted portion of the macro. To modify it, use the Prelines Editor under %s."] =
  "与你当前准星瞄准设置相匹配的瞄准前置行会自动添加到你的行之前，作为宏中的高亮部分。如需修改，请使用“%s”下的前置行编辑器。"
L["Macro Name"] = "宏名称"
L["Enter a macro name"] = "输入宏名称"
L["Saved to your general macros."] = "将保存到你的通用宏中。"
L["Saved to your character macros."] = "将保存到你的角色宏中。"
L["Macro Text"] = "宏内容"
L["Delete Macro"] = "删除宏"
L["Delete this macro? Any action bar button using it will be emptied."] =
  "删除此宏？使用它的所有动作条按钮都会被清空。"
L["Save Macro"] = "保存宏"
L["Preline must be %d characters or fewer (room for /click under the 255 macro limit)."] =
  "前置行不得超过 %d 个字符（需在宏的 255 字符上限内为 /click 留出空间）。"
L["Inactive — Auto Target Lock is OFF"] = "未激活 — 自动目标锁定已关闭"
L["Inactive — Auto Target Lock is ON"] = "未激活 — 自动目标锁定已开启"
L["Inactive — Ignore Friendlies is OFF"] = "未激活 — 忽略友方已关闭"
L["Inactive — Ignore Friendlies is ON"] = "未激活 — 忽略友方已开启"
L["Customize the targeting prelines injected before each ability when Reticle Targeting is enabled.\n\n• Only the preline matching your current %s X %s settings is active.\n• Max %s characters per preline — SecureActionButton macros are capped at %s; the rest is reserved for the trailing %s line.\n• Use %s to reload and pick up edits."] =
  "自定义启用准星瞄准时在每个技能前注入的瞄准前置行。\n\n• 只有与你当前 %s X %s 设置相匹配的前置行处于激活状态。\n• 每条前置行最多 %s 个字符——SecureActionButton 宏上限为 %s，其余部分保留给末尾的 %s 行。\n• 使用 %s 重新加载并应用修改。"
L["Apply Changes"] = "应用更改"
L["Hostile"] = "敌对"
L["NPC"] = "NPC"
L["Player"] = "玩家"
L["Object"] = "物体"
L["Select a tab to customize the color and alpha of the crosshair when targeting different types of units.\n\n• %s and %s animations use the Hostile color.\n• Inactive crosshair states use the Base style."] =
  "选择一个标签页，自定义准星在瞄准不同类型单位时的颜色和透明度。\n\n• %s和%s动画使用敌对颜色。\n• 未激活的准星状态使用基础样式。"
L["Reset to Default"] = "恢复默认"
L["Show the inactive crosshair"] = "显示未激活的准星"
L["Show the active crosshair"] = "显示激活的准星"
L["Show the mounted crosshair"] = "显示骑乘时的准星"
L["Show the disabled crosshair"] = "显示已禁用的准星"
L["Hide the inactive crosshair"] = "隐藏未激活的准星"
L["Hide the active crosshair"] = "隐藏激活的准星"
L["Hide the mounted crosshair"] = "隐藏骑乘时的准星"
L["Hide the disabled crosshair"] = "隐藏已禁用的准星"
L["Nothing is drawn while you are not aiming at anything."] =
  "未瞄准任何目标时不显示任何内容。"
L["Nothing is drawn while you are aiming at a unit or object."] =
  "瞄准单位或物体时不显示任何内容。"
L["Nothing is drawn while you are mounted."] = "骑乘时不显示任何内容。"
L["Nothing is drawn while Target Lock holds the reticle."] =
  "目标锁定持有准星期间不显示任何内容。"
L["Not aiming at anything"] = "未瞄准任何目标"
L["Aiming at a unit or object"] = "正在瞄准单位或物体"
L["While you are mounted"] = "骑乘时"
L["While Target Lock holds"] = "目标锁定期间"
L["Brings back the texture you had before hiding it."] = "恢复隐藏之前使用的纹理。"
L["Crosshair Textures"] = "准星纹理"
L["Select a state, then pick a texture below, or apply a preset for a curated appearance."] =
  "选择一个状态，然后在下方选择纹理，或应用预设以获得精心搭配的外观。"
L["INACTIVE"] = "未激活"
L["ACTIVE"] = "激活"
L["MOUNTED"] = "骑乘中"
L["DISABLED"] = "已禁用"
L["PRESETS"] = "预设"
L["ALL TEXTURES"] = "所有纹理"
L["Action Combat Mode (Reticle CVar Editor)"] = "Action Combat Mode（准星 CVar 编辑器）"
L["External change (CVAR_UPDATE)"] = "外部更改（CVAR_UPDATE）"
L["Description"] = "描述"
L["Value"] = "数值"
L["Default Value:"] = "默认值："
L["Last Modified By:"] = "最后修改者："
L["Double-click a row to edit. Overrides are account-wide and replace CombatMode defaults."] =
  "双击某一行进行编辑。覆盖设置对整个账号生效，并会替换 CombatMode 的默认值。"

-- Radial Menu: actions and preset wheels
L["Character Info"] = "角色信息"
L["Spellbook & Talents"] = "法术书和天赋"
L["Talents"] = "天赋"
L["World Map"] = "世界地图"
L["All Bags"] = "所有背包"
L["Professions"] = "专业技能"
L["Achievements"] = "成就"
L["Quest Log"] = "任务日志"
L["Guild & Communities"] = "公会与社区"
L["Group Finder"] = "队伍查找器"
L["Warband Collection"] = "战团收藏"
L["Housing Dashboard"] = "住宅面板"
L["Adventure Guide"] = "冒险指南"
L["Calendar"] = "日历"
L["Friends & Social"] = "好友与社交"
L["Game Menu"] = "游戏菜单"
L["ACM Options"] = "ACM 选项"
L["Wave"] = "挥手"
L["Dance"] = "跳舞"
L["Cheer"] = "欢呼"
L["Bow"] = "鞠躬"
L["Salute"] = "敬礼"
L["Laugh"] = "大笑"
L["Flex"] = "炫耀肌肉"
L["Roar"] = "咆哮"
L["Thank"] = "感谢"
L["Clap"] = "鼓掌"
L["Point"] = "指向"
L["Cry"] = "哭泣"
L["Sit"] = "坐下"
L["Kneel"] = "跪下"
L["Reputation"] = "声望"
L["Currency"] = "货币"
L["Great Vault"] = "宏伟宝库"
L["Mount Journal"] = "坐骑日志"
L["Pet Journal"] = "宠物日志"
L["Toy Box"] = "玩具箱"
L["Macros"] = "宏"
L["Hello"] = "你好"
L["Bye"] = "再见"
L["Applaud"] = "喝彩"
L["Shrug"] = "耸肩"
L["Yes"] = "是"
L["No"] = "否"
L["Kiss"] = "飞吻"
L["Flirt"] = "调情"
L["Rude"] = "无礼"
L["Ready"] = "准备好"
L["Victory"] = "胜利"
L["Ready Check"] = "就位确认"
L["Roll (1-100)"] = "掷骰子（1-100）"
L["Reload UI"] = "重新加载界面"
L["Leave Party"] = "离开队伍"
L["Reset Instances"] = "重置副本"
L["Pull Countdown (10s)"] = "开怪倒计时（10 秒）"
L["Role Check"] = "职责确认"
L["Convert to Raid"] = "转换为团队"
L["Summon Random Mount"] = "召唤随机坐骑"
L["Take Screenshot"] = "截图"
L["Sheathe / Unsheathe Weapons"] = "收起/拔出武器"
L["Loot Spec: Current Spec"] = "拾取专精：当前专精"
L["Invite Target"] = "邀请目标"
L["Focus Target"] = "设置焦点"
L["Cancel Form"] = "取消形态"
L["Follow Target"] = "跟随目标"
L["Duel Target"] = "决斗目标"
L["Inspect Target"] = "观察目标"
L["Toggle AFK"] = "切换离开状态"
L["Toggle Do Not Disturb"] = "切换勿扰状态"
L["Camp (Log Out)"] = "露营（登出）"
L["Dismount"] = "下坐骑"
L["Leave Vehicle"] = "离开载具"
L["Mark Target: %s"] = "标记目标：%s"
L["Clear Target Mark"] = "清除目标标记"
L["World Marker: %s"] = "世界标记：%s"
L["Clear World Markers"] = "清除世界标记"
L["Interface"] = "界面"
L["Misc"] = "杂项"
L["Wheel %d"] = "轮盘 %d"
