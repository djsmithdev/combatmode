---------------------------------------------------------------------------------------
--  Locales/zhTW.lua — LOCALES — Chinese (Traditional) strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the zhTW client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "zhTW", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "zhTW" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "歡迎使用 Action Combat Mode！"
L["The configuration panel will open after you close this message."] =
  "關閉此訊息後將開啟設定面板。"
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "你可以隨時使用 |cff69ccf0/acm|r 或 |cff69ccf0/actioncombatmode|r 重新開啟。"
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090若要還原先前的設定，請使用選項面板中的|cffff5555解除安裝|r按鈕。|r"
L["Mouse Look"] = "滑鼠視角"
L["Flip Camera"] = "翻轉鏡頭"
L["Swap Shoulder"] = "切換肩部視角"
L["Reset Mouse Look"] = "重設滑鼠視角"
L["Ally Cycle Next"] = "友方循環：下一個"
L["Ally Cycle Previous"] = "友方循環：上一個"
L["Toggle Focus Target"] = "切換焦點目標"
L["Cycle Focus Next"] = "焦點循環：下一個"
L["Cycle Focus Previous"] = "焦點循環：上一個"
L["Radial Menu"] = "輪盤選單"

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "按鍵綁定變更"
L["deferred %s until combat ends."] = "%s已延後到戰鬥結束後。"
L["failed to apply %s: %s"] = "套用%s失敗：%s"
L["applied deferred binding updates."] = "已套用延後的按鍵綁定更新。"
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50偵測到 %s！|r 正在移交轉向速度、肩部視角和動態俯仰。"
L["Cannot uninstall while in combat."] = "戰鬥中無法解除安裝。"
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "已還原你先前的鏡頭/目標設定與預設的滑鼠鏡頭按鍵綁定，並已停用此插件。"
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "輸入 |cff69ccf0/acm|r 或 |cff69ccf0/actioncombatmode|r 開啟設定。"
L["camera and targeting CVars restored."] = "已還原鏡頭與目標選擇 CVar。"
L["Cannot open settings while in combat."] = "戰鬥中無法開啟設定。"
L["Cannot open this editor while in combat."] = "戰鬥中無法開啟此編輯器。"
L["Cannot open editor while in combat."] = "戰鬥中無法開啟編輯器。"
L["cannot edit Reticle Targeting CVars while in combat."] =
  "戰鬥中無法編輯準星選目標的 CVar。"
L["cannot reset Reticle Targeting CVars while in combat."] =
  "戰鬥中無法重設準星選目標的 CVar。"
L["MOVEANDSTEER unbind"] = "解除 MOVEANDSTEER 綁定"
L["restore default mouse camera bindings"] = "還原預設的滑鼠鏡頭按鍵綁定"
L["Minimum Zoom"] = "最小縮放"
L["ally cycle bindings"] = "友方循環按鍵綁定"
L["radial menu"] = "輪盤選單"
L["target lock keybinding"] = "鎖定目標按鍵綁定"
L["cycle focus next keybinding"] = "焦點循環下一個按鍵綁定"
L["cycle focus previous keybinding"] = "焦點循環上一個按鍵綁定"
L["ally cycle next keybinding"] = "友方循環下一個按鍵綁定"
L["ally cycle previous keybinding"] = "友方循環上一個按鍵綁定"
L["radial menu keybinding"] = "輪盤選單按鍵綁定"
L["reticle interact keybinding"] = "準星互動按鍵綁定"
L["mouse look keybinding"] = "滑鼠視角按鍵綁定"
L["flip camera keybinding"] = "翻轉鏡頭按鍵綁定"
L["reset mouse look keybinding"] = "重設滑鼠視角按鍵綁定"
L["swap shoulder keybinding"] = "切換肩部視角按鍵綁定"
