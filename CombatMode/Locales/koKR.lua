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

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = "단축키 변경"
L["deferred %s until combat ends."] = "%s 적용이 전투 종료 후로 미뤄졌습니다."
L["failed to apply %s: %s"] = "%s 적용 실패: %s"
L["applied deferred binding updates."] = "미뤄진 단축키 변경을 적용했습니다."
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] =
  "|cffE52B50%s 감지됨!|r 회전 속도, 어깨 시점, 동적 피치 제어를 넘깁니다."
L["Cannot uninstall while in combat."] = "전투 중에는 제거할 수 없습니다."
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  "이전 카메라/대상 지정 설정과 기본 마우스 카메라 단축키를 복원하고 애드온을 비활성화했습니다."
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] =
  "설정을 열려면 |cff69ccf0/acm|r 또는 |cff69ccf0/actioncombatmode|r를 입력하세요."
L["camera and targeting CVars restored."] =
  "카메라 및 대상 지정 CVar를 복원했습니다."
L["Cannot open settings while in combat."] = "전투 중에는 설정을 열 수 없습니다."
L["Cannot open this editor while in combat."] =
  "전투 중에는 이 편집기를 열 수 없습니다."
L["Cannot open editor while in combat."] = "전투 중에는 편집기를 열 수 없습니다."
L["cannot edit Reticle Targeting CVars while in combat."] =
  "전투 중에는 조준선 대상 지정 CVar를 편집할 수 없습니다."
L["cannot reset Reticle Targeting CVars while in combat."] =
  "전투 중에는 조준선 대상 지정 CVar를 초기화할 수 없습니다."
L["MOVEANDSTEER unbind"] = "MOVEANDSTEER 단축키 해제"
L["restore default mouse camera bindings"] = "기본 마우스 카메라 단축키 복원"
L["Minimum Zoom"] = "최소 확대/축소"
L["ally cycle bindings"] = "아군 순환 단축키"
L["radial menu"] = "원형 메뉴"
L["target lock keybinding"] = "대상 고정 단축키"
L["cycle focus next keybinding"] = "주시 순환 다음 단축키"
L["cycle focus previous keybinding"] = "주시 순환 이전 단축키"
L["ally cycle next keybinding"] = "아군 순환 다음 단축키"
L["ally cycle previous keybinding"] = "아군 순환 이전 단축키"
L["radial menu keybinding"] = "원형 메뉴 단축키"
L["reticle interact keybinding"] = "조준선 상호작용 단축키"
L["mouse look keybinding"] = "마우스 시점 단축키"
L["flip camera keybinding"] = "카메라 반전 단축키"
L["reset mouse look keybinding"] = "마우스 시점 초기화 단축키"
L["swap shoulder keybinding"] = "어깨 시점 전환 단축키"
