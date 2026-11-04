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
