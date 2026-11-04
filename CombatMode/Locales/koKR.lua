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

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "모든 하드 대상"
L["Locked Target Only"] = "고정된 대상만"
L["Soft Target (Blizzard)"] = "소프트 대상 (블리자드)"
L["Hidden"] = "숨김"
L["Toggle"] = "전환"
L["Switch Target"] = "대상 교체"
L["A UI Reload is required when making this change. Proceed?"] =
  "이 변경을 적용하려면 UI를 다시 불러와야 합니다. 계속하시겠습니까?"
L["Create New Macro"] = "새 매크로 만들기"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "조준선 대상 지정 사전 줄로 시작하는 매크로를 작성합니다."
L["Unavailable in combat."] = "전투 중에는 사용할 수 없습니다."
L["Drag to a button on your action bars to use."] =
  "사용하려면 행동 단축바의 버튼으로 끌어다 놓으세요."
L["Right-click to edit"] = "우클릭하여 편집"
L["+%d more in /macro"] = "/macro에 %d개 더 있음"
L["Reticle Targeting Macros"] = "조준선 대상 지정 매크로"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "매크로인 행동 버튼은 조준선 대상 지정 로직을 자동으로 상속하지 않습니다. 이 규칙을 따르게 하려면 매크로 작성기로 만든 뒤 단축바로 끌어다 놓으세요."
L["Reticle Targeting"] = "조준선 대상 지정"
L["RETICLE TARGETING"] = "조준선 대상 지정"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "조준 기반 대상 지정과 지면 지정 주문 및 광역 능력의 정밀한 배치를 가능하게 합니다."
L["Enable Reticle Targeting"] = "조준선 대상 지정 사용"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "탭 대상 지정 대신 조준점을 유닛에 맞춰 대상을 선택합니다."
L["Ignore Friendlies"] = "아군 무시"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "우호적인 NPC와 플레이어를 무시하고 적대적인 유닛만 대상으로 지정합니다."
L["Click Casting Only"] = "클릭 시전만"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "조준선 대상 지정 로직을 클릭 시전 단축키에만 적용합니다."
L["Excluded Spells"] = "제외할 주문"
L["Spells to skip the reticle targeting logic."] =
  "조준선 대상 지정 로직을 건너뛸 주문입니다."
L["Cast at Crosshair"] = "조준점에 시전"
L["Ground spells to cast at the crosshair location."] =
  "조준점 위치에 시전할 지면 지정 주문입니다."
L["TARGET LOCK"] = "대상 고정"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "대상을 고정해 실수로 바뀌는 것을 막고, 유닛을 순환하며 특정 적을 우선 지정합니다."
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "경고: 대상 고정은 주시 대상을 사용합니다. 주시 대상을 바꾸는 다른 기능은 이를 방해합니다."
L["Target Lock Keybind"] = "대상 고정 단축키"
L["Lock the reticle to a target, preventing it from swapping."] =
  "조준점을 대상에 고정하여 바뀌지 않게 합니다."
L["Cycle Lock - Next"] = "고정 순환 - 다음"
L["Move Target Lock to the next valid nearby target."] =
  "대상 고정을 근처의 다음 유효한 대상으로 옮깁니다."
L["Cycle Lock - Previous"] = "고정 순환 - 이전"
L["Move Target Lock to the previous valid nearby target."] =
  "대상 고정을 근처의 이전 유효한 대상으로 옮깁니다."
L["Target Lock Behavior"] = "대상 고정 동작"
L["What the Target Lock key does when you press it."] =
  "대상 고정 키를 눌렀을 때의 동작입니다."
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "현재 대상 또는 조준점 아래의 유닛을 고정합니다. 다시 누르면 해제됩니다."
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "조준점 아래의 유닛을 고정하며 기존 고정을 대체합니다. 조준점 아래에 아무것도 없을 때 누르면 해제됩니다. 이미 고정한 유닛을 조준하면 고정이 유지됩니다."
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "'아군 무시'가 켜져 있으면 조준점 아래의 아군이나 죽은 유닛은 무시되며 고정은 그대로 유지됩니다."
L["Auto Target Lock"] = "자동 대상 고정"
L["Target Lock engages automatically when attacking units."] =
  "유닛을 공격할 때 대상 고정이 자동으로 적용됩니다."
L["Target Lock Marker"] = "대상 고정 표시"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "고정된 대상의 이름표에 조준점 표시를 보여줍니다."
L["Focus Locked Target"] = "고정된 대상에 집중"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "카메라를 고정된 대상 쪽으로 당겨 계속 초점을 맞춥니다."
L["TARGETING INDICATORS"] = "대상 표시기"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "월드의 대상을 강조하여 더 쉽게 식별할 수 있게 하는 시각 표시기입니다."
L["Target Outline"] = "대상 외곽선"
L["Show an outline effect on your target."] = "대상에 외곽선 효과를 표시합니다."
L["Only available on Retail"] = "리테일에서만 사용 가능"
L["Selection Circle"] = "선택 원"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "어느 대상의 발밑에 블리자드의 선택 원을 표시할지 정합니다."
L["The circle under whatever you have targeted, enemy or friendly."] =
  "적이든 아군이든 지정한 모든 대상의 아래에 표시되는 원입니다."
L["The circle only under your Target Lock."] =
  "대상 고정 중인 대상의 아래에만 표시되는 원입니다."
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "ObjectSelectionCircle과 UnitNameFocused의 동작을 블리자드가 제어하도록 합니다."
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "블리자드는 캐릭터 모델 앞쪽 호 안에서 소프트 대상을 고릅니다. 조준점 위치나 어깨 시점 오프셋은 고려하지 않습니다."
L["No selection circle."] = "선택 원이 표시되지 않습니다."

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "조준점"
L["CROSSHAIR"] = "조준점"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "대상과 전투 상태에 반응하는 동적 조준점으로, 정확도를 높이고 조준선 대상 지정을 안내합니다."
L["Enable Crosshair"] = "조준점 사용"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "마우스 룩 중에 화면에 동적이고 반응하는 조준점을 표시합니다."
L["Cast Feedback"] = "시전 피드백"
L["Crosshair provides visual feedback while casting."] =
  "시전하는 동안 조준점이 시각적 피드백을 제공합니다."
L["Appearance"] = "모양"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "각 상태에서 조준점이 사용하는 텍스처입니다. 하나를 클릭하여 텍스처를 고르거나 프리셋으로 시작하세요."
L["Inactive"] = "비활성"
L["Active"] = "활성"
L["Mounted"] = "탈것 탑승"
L["Disabled"] = "비활성화됨"
L["Reaction Colors"] = "반응 색상"
L["Edit"] = "편집"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "서로 다른 종류의 유닛을 조준할 때 조준점이 사용하는 색상을 설정합니다."
L["Scale"] = "크기"
L["Scales the size of the crosshair."] = "조준점의 크기를 조절합니다."
L["Vertical Position"] = "세로 위치"
L["Move the crosshair up or down from screen center."] =
  "조준점을 화면 중앙에서 위나 아래로 이동합니다."
L["ASSIST HUD"] = "보조 HUD"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "적을 조준할 때 주문 연계를 안내하고 상호작용 안내를 표시하는 HUD입니다."
L["Next-cast Suggestion"] = "다음 시전 추천"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "대상을 조준하는 동안 보조 강조의 다음 시전 추천을 표시합니다."
L["Always"] = "항상"
L["Only In Combat"] = "전투 중에만"
L["Interactable Indicator"] = "상호작용 표시기"
L["Show an indicator while aiming at an interactable unit or object."] =
  "상호작용 가능한 유닛이나 오브젝트를 조준하는 동안 표시기를 보여줍니다."
L["Player Interaction Prompt"] = "플레이어 상호작용 안내"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "플레이어를 1초간 조준하면 표시기를 보여줍니다. 상호작용 키를 누르면 해당 플레이어의 메뉴가 열립니다."
L["Position"] = "위치"
L["Which side of the crosshair the HUD appears on."] =
  "HUD가 조준점의 어느 쪽에 표시될지 정합니다."
L["Left"] = "왼쪽"
L["Right"] = "오른쪽"
L["Scales the size of the HUD."] = "HUD의 크기를 조절합니다."
L["Distance"] = "거리"
L["Distance between the HUD and the crosshair."] = "HUD와 조준점 사이의 거리입니다."

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "수정된 블리자드 동작"
L["Blizzard Actions"] = "블리자드 동작"
L["Base"] = "기본"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "대상 해제"
L["Clear Focus"] = "주시 대상 해제"
L["Start Attack"] = "공격 시작"
L["Pet Attack"] = "소환수 공격"
L["Toggle Focus Any"] = "주시 대상 전환 (모두)"
L["Toggle Focus Enemy"] = "주시 대상 전환 (적)"
L["Run MACRO"] = "MACRO 실행"
L["— none —"] = "— 없음 —"
L["Override this click during Mouse Look."] = "마우스 룩 중에 이 클릭을 대체합니다."
L["Action"] = "동작"
L["Macro"] = "매크로"
L["Select a macro"] = "매크로 선택"
L["No targeting"] = "대상 지정 없음"
L["Left Click"] = "왼쪽 클릭"
L["Right Click"] = "오른쪽 클릭"
L["Shift + Left Click"] = "Shift + 왼쪽 클릭"
L["Shift + Right Click"] = "Shift + 오른쪽 클릭"
L["Ctrl + Left Click"] = "Ctrl + 왼쪽 클릭"
L["Ctrl + Right Click"] = "Ctrl + 오른쪽 클릭"
L["Alt + Left Click"] = "Alt + 왼쪽 클릭"
L["Alt + Right Click"] = "Alt + 오른쪽 클릭"
L["Click Casting"] = "클릭 시전"
L["CLICK CASTING"] = "클릭 시전"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "마우스 룩 중에 활성화되는 대체 동작을 왼쪽 및 오른쪽 클릭에 지정합니다."
L["Account-Wide Binds"] = "계정 공통 단축키"
L["Share Click Casting binds across all characters."] =
  "모든 캐릭터가 클릭 시전 단축키를 공유합니다."
L["Click Binds"] = "클릭 단축키"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "기본, Shift, Ctrl, Alt 각각에 고유한 왼쪽/오른쪽 클릭 동작이 있습니다."
