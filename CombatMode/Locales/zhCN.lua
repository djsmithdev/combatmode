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
