---------------------------------------------------------------------------------------
--  Locales/koKR.lua — LOCALES — Korean strings
---------------------------------------------------------------------------------------
--  What it does: Translations for the koKR client. Keys are the English text from
--  Locales/enUS.lua; a missing key falls back to English in game.
--  Architecture / how it works:
--    • Returns early unless GetLocale() == "koKR", so only the active table runs.
--    • Machine-drafted; needs native review. Keep placeholders (%s, %d), colour codes
--      (|cffxxxxxx...|r) and the name "Action Combat Mode" exactly as in the key.
--  Does not: Add keys that are not in enUS.lua (scripts/check-repo.ps1 fails on those).
--  Related: Locales/enUS.lua, Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

if _G.GetLocale() ~= "koKR" then
  return
end

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = "Action Combat Mode에 오신 것을 환영합니다!"
L["The configuration panel will open after you close this message."] =
  "이 메시지를 닫으면 설정 창이 열립니다."
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] =
  "|cff69ccf0/acm|r 또는 |cff69ccf0/actioncombatmode|r로 언제든지 다시 열 수 있습니다."
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  "|cff909090이전 설정을 복원하려면 옵션 창의 |cffff5555제거|r 버튼을 사용하세요.|r"
L["Mouse Look"] = "마우스 시점"
L["Flip Camera"] = "카메라 반전"
L["Swap Shoulder"] = "어깨 시점 전환"
L["Reset Mouse Look"] = "마우스 시점 초기화"
L["Ally Cycle Next"] = "아군 순환: 다음"
L["Ally Cycle Previous"] = "아군 순환: 이전"
L["Toggle Focus Target"] = "주시 대상 전환"
L["Cycle Focus Next"] = "주시 순환: 다음"
L["Cycle Focus Previous"] = "주시 순환: 이전"
L["Radial Menu"] = "원형 메뉴"
