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

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "마우스 룩"
L["CAMERA FEATURES"] = "카메라 기능"
L["ADDITIONAL FEATURES"] = "추가 기능"
L["Crosshair - More accurate"] = "조준점 - 더 정확함"
L["Soft Target - More forgiving"] = "소프트 대상 - 더 관대함"
L["Mouse Look is on"] = "마우스 룩 켜짐"
L["In combat"] = "전투 중"
L["Talking to an NPC"] = "NPC와 대화 중"
L["Any checked"] = "선택 항목 중 하나"
L["All checked"] = "선택 항목 모두"
L["Off"] = "꺼짐"
L["Control relinquished to %s"] = "%s에게 제어권을 넘김"
L["Disabled while Motion Sickness Protection is on"] =
  "멀미 방지가 켜져 있는 동안 비활성화됨"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "커서를 조준점 위치에 고정하고, 마우스 오른쪽 버튼을 누르지 않고도 마우스를 움직여 방향을 조종합니다."
L["Mouse Look Keybind"] = "마우스 룩 단축키"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "누르면 마우스 룩을 전환합니다. 길게 누르면 커서를 일시적으로 해제합니다."
L["Interact Keybind"] = "상호작용 단축키"
L["Tap to interact with a player or the unit chosen below."] =
  "눌러서 플레이어 또는 아래에서 선택한 대상과 상호작용합니다."
L["Players"] = "플레이어"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "플레이어를 1초간 조준하면 보조 HUD에 안내가 표시됩니다. 그때 키를 누르면 해당 플레이어의 메뉴가 열립니다."
L["NPCs and objects"] = "NPC 및 오브젝트"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "'상호작용 대상'에서 선택한 대상과 평소처럼 상호작용합니다."
L["Interact Unit"] = "상호작용 대상"
L["Which unit will be interacted with when the key is pressed."] =
  "키를 눌렀을 때 상호작용할 대상입니다."
L["Flip Camera Keybind"] = "카메라 뒤집기 단축키"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "누르면 카메라를 캐릭터 주위로 180° 뒤집습니다. 길게 누르면 키를 누르고 있는 동안에만 뒤집힙니다."
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "macOS에서 창을 전환한 뒤 커서가 멈춘 경우 복구합니다. 마우스 룩을 다시 잡았다가 해제하여 게임이 백그라운드에서 멈춘 채 남긴 입력 캡처를 해제합니다."
L["Curated camera adjustments for a more action-focused experience."] =
  "더 액션 중심의 경험을 위해 엄선한 카메라 조정입니다."
L["Motion Sickness Protection"] = "멀미 방지"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "Action Combat Mode가 블리자드의 멀미 설정을 덮어쓰지 않도록 합니다."
L["Turn Speed"] = "회전 속도"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "마우스 룩 사용 중 카메라가 회전하는 속도를 조절합니다."
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "카메라가 이 거리보다 가까이 확대되지 않도록 합니다. 0이면 꺼집니다."
L["Dynamic Pitch"] = "동적 기울기"
L["Dynamically tilt the camera up and down as you move it."] =
  "카메라를 움직일 때 위아래로 동적으로 기울입니다."
L["Pitch Strength"] = "기울기 강도"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "동적 기울기가 카메라를 얼마나 기울일지 정합니다. 값이 낮을수록 캐릭터가 화면에서 더 높게 유지됩니다. 비행 중에는 더 많이 기울며 이 값에 비례합니다."
L["Shoulder Offset"] = "어깨 시점 오프셋"
L["Camera's horizontal position relative to the character."] =
  "캐릭터를 기준으로 한 카메라의 가로 위치입니다."
L["Disable Offset With Mouselook"] = "마우스 룩 시 오프셋 해제"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "마우스 룩을 끄면 어깨 시점 오프셋이 부드럽게 0으로 돌아갑니다."
L["When off, Shoulder Offset stays constant at all times."] =
  "꺼 두면 어깨 시점 오프셋이 항상 일정하게 유지됩니다."
L["Swap Shoulder Keybind"] = "어깨 전환 단축키"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "누르면 어깨 시점 오프셋을 캐릭터의 반대편으로 반전시킵니다."
L["Extra functionalities tied to Mouse Look behaviour."] =
  "마우스 룩 동작과 연동되는 추가 기능입니다."
L["Cursor Pulse"] = "커서 점멸"
L["Flash the cursor when Mouse Look is turned off."] =
  "마우스 룩이 꺼질 때 커서를 깜빡입니다."
L["Hide Tooltips"] = "툴팁 숨기기"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "마우스 룩이 켜져 있는 동안 아래 키를 누르고 있지 않으면 툴팁을 숨깁니다."
L["Show Tooltips With"] = "툴팁 표시 키"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "마우스 룩이 켜져 있는 동안 이 키를 누르고 있으면 툴팁이 표시됩니다."
L["Auto Sheath"] = "자동 무기 집어넣기"
L["Sheath weapons automatically with Mouse Look."] =
  "마우스 룩과 함께 무기를 자동으로 집어넣습니다."
L["Vignette Shows When"] = "비네트 표시 조건"
L["Darkens the edges of the screen while the checked situations are true."] =
  "선택한 상황이 참인 동안 화면 가장자리를 어둡게 합니다."
L["Vignette Match"] = "비네트 조건 일치"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "하나라도: 선택한 상황 중 하나면 충분합니다. 모두: 선택한 모든 상황이 동시에 참이어야 합니다."
