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
