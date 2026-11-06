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
L["Tap to interact with the unit chosen below. Hold on a player to open their context menu."] =
  "아래에서 선택한 대상과 상호작용하려면 짧게 누르세요. 플레이어를 조준한 상태에서 길게 누르면 컨텍스트 메뉴가 열립니다."
L["Players"] = "플레이어"
L["Aim at a player for a second and the Assist HUD shows a prompt. Hold the key then to open their context menu."] =
  "플레이어를 1초 동안 조준하면 보조 HUD에 안내가 표시됩니다. 이때 키를 길게 누르면 해당 플레이어의 컨텍스트 메뉴가 열립니다."
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
L["Disable Player Interaction"] = "플레이어 상호작용 비활성화"
L["Disables interaction with players from the Interact Key."] =
  "플레이어를 조준한 상태에서 상호작용 키를 길게 누르면 해당 플레이어의 메뉴가 열립니다. 다인승 탈것 등에서 키를 기본 동작 그대로 사용하려면 끄세요."
L["Show an indicator while aiming at a player for one second. Holding the Interact Key opens their context menu."] =
  "플레이어를 1초 동안 조준하면 표시기를 보여줍니다. 상호작용 키를 길게 누르면 해당 플레이어의 컨텍스트 메뉴가 열립니다."
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

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "방사형 메뉴 휠"
L["Forever"] = "Forever"
L["Minimal"] = "미니멀"
L["Clear Slice"] = "칸 비우기"
L["UI Actions"] = "UI 동작"
L["Emotes"] = "감정 표현"
L["Commands"] = "명령어"
L["Markers"] = "징표"
L["Slice"] = "칸"
L["Choose an action"] = "동작 선택"
L["Presets"] = "프리셋"
L["New Wheel"] = "새 휠"
L["Wheel"] = "휠"
L["You can have up to %d wheels."] = "휠은 최대 %d개까지 만들 수 있습니다."
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "휠에 넣을 수 없습니다. 주문, 아이템, 장난감, 탈것 또는 매크로를 사용하세요."
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "주문, 아이템, 장난감, 탈것 또는 매크로를 여기로 끌어다 놓거나, 클릭하여 동작을 변경하세요."
L["Empty Slice"] = "빈 칸"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "주문, 아이템, 장난감, 탈것 또는 매크로를 여기로 끌어다 놓거나, 클릭하여 동작을 지정하세요. 빈 칸은 휠에서 제외됩니다."
L["A wheel needs at least one slice."] = "휠에는 최소 한 칸이 필요합니다."
L["Click to rename this wheel"] = "클릭하여 이 휠의 이름 변경"
L["Previous wheel"] = "이전 휠"
L["Next wheel"] = "다음 휠"
L["Click to select this wheel, drag to reorder"] =
  "클릭하여 이 휠 선택, 끌어서 순서 변경"
L["Add Slice"] = "칸 추가"
L["A wheel holds up to %d slices."] = "휠에는 최대 %d칸까지 둘 수 있습니다."
L["Remove Wheel"] = "휠 제거"
L["Deletes this wheel and all of its slices."] = "이 휠과 모든 칸을 삭제합니다."
L["You need at least one wheel."] = "휠이 최소 한 개 필요합니다."
L["Remove this wheel and all of its slices?"] = "이 휠과 모든 칸을 제거하시겠습니까?"
L["Add Wheel"] = "휠 추가"
L["Pick a preset wheel or a blank one."] = "프리셋 휠 또는 빈 휠을 선택하세요."
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "칸을 클릭해 동작을 고르거나, 주문, 아이템, 장난감, 탈것 또는 매크로를 그 위에 놓으세요.\n칸을 끌어서 순서를 바꿀 수 있습니다. 오른쪽 클릭하면 제거됩니다."
L["RADIAL MENU"] = "방사형 메뉴"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "주문, 아이템, 매크로, 감정 표현, 인터페이스 단축 기능을 위한 빠른 실행 휠을 만듭니다."
L["Radial Menu Keybind"] = "방사형 메뉴 단축키"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "누르고 있으면 방사형 메뉴가 열립니다. 칸을 조준한 뒤 떼면 실행됩니다. 마우스 휠로 휠을 전환합니다."
L["Radial Menu Style"] = "방사형 메뉴 스타일"
L["Choose the appearance of the Radial Menu wheels."] =
  "방사형 메뉴 휠의 모양을 선택합니다."
L["Party Wheel Spells"] = "파티 휠 주문"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "키를 누르고 있는 동안 파티 대상 지정 휠을 여는 이로운 주문입니다. 파티원 쪽으로 밀고 떼면 그에게 시전하고, 중앙으로 돌아오면 자신에게 시전합니다. 짧게 누르면 우호적 대상에게, 선택된 대상이 없으면 자신에게 시전합니다."
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "각 휠의 칸을 편집하고, 휠 이름을 바꾸고, 휠을 추가하거나 제거합니다."

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "위"
L["Bottom"] = "아래"
L["Ally Cycle"] = "아군 순환"
L["ALLY CYCLE"] = "아군 순환"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "이로운 주문은 아군을 대상으로 하고, 해로운 주문은 조준점의 적에게 유지되어 전투와 지원을 매끄럽게 이어줍니다."
L["Ally Cycle - Next"] = "아군 순환 - 다음"
L["Target the next group member."] = "다음 파티원을 대상으로 지정합니다."
L["Ally Cycle - Previous"] = "아군 순환 - 이전"
L["Target the previous group member."] = "이전 파티원을 대상으로 지정합니다."
L["Skip Self"] = "자신 건너뛰기"
L["Skip yourself when cycling through group members."] =
  "파티원을 순환할 때 자신을 건너뜁니다."
L["Keep Ally After Harm"] = "공격 후 아군 유지"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "해로운 주문이 조준점의 적을 대상으로 한 뒤 이전 아군을 복원합니다. 변경하기 전까지 치유 전문화에서는 기본으로 켜져 있습니다."
L["Disabled while Auto Target Lock is on"] =
  "자동 대상 고정이 켜져 있는 동안 비활성화됩니다"
L["ALLY HUD"] = "아군 HUD"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "아군 순환이 선택한 파티원을 보여주는 HUD입니다."
L["Ally HUD"] = "아군 HUD"
L["Show a unit frame for the currently selected group member."] =
  "현재 선택된 파티원의 유닛 프레임을 표시합니다."
L["Where the Ally HUD sits relative to the crosshair."] =
  "조준점을 기준으로 아군 HUD가 놓이는 위치입니다."
L["Scales the size of the Ally HUD."] = "아군 HUD의 크기를 조절합니다."
L["Distance between the Ally HUD and the crosshair."] =
  "아군 HUD와 조준점 사이의 거리입니다."

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "자동 해제"
L["AUTO UNLOCK"] = "자동 해제"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "창이 열리면 마우스 룩을 자동으로 일시 중지하고, 닫히면 다시 시작합니다."
L["Release the cursor when UI panels open."] = "UI 창이 열리면 커서를 해제합니다."
L["Unlock Mounts"] = "해제할 탈것"
L["Mounts that force a cursor unlock while mounted."] =
  "탈것을 타고 있는 동안 커서를 강제로 해제하는 탈것입니다."
L["Extra Frames"] = "추가 프레임"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "자동 해제를 일으키는 추가 프레임 이름입니다. 입력해서 블리자드 및 애드온 프레임을 검색하거나, 검사 버튼으로 화면의 창을 클릭하세요."

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "고급"
L["SOUNDS"] = "소리"
L["Control the sound cues used by some of the other features."] =
  "다른 일부 기능에서 사용하는 효과음을 설정합니다."
L["Mouse Look Sounds"] = "마우스 룩 소리"
L["Play a cue when Mouse Look turns on and off."] =
  "마우스 룩이 켜지고 꺼질 때 효과음을 재생합니다."
L["Target Lock Sounds"] = "대상 고정 소리"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "대상 고정을 설정하거나 해제하거나 전환할 때 효과음을 재생합니다."
L["Radial Menu Sounds"] = "방사형 메뉴 소리"
L["Play cues when interacting with Radial Menu wheels."] =
  "방사형 메뉴 휠을 조작할 때 효과음을 재생합니다."
L["Ally Cycle Sounds"] = "아군 순환 소리"
L["Play a cue when Ally Cycle moves to another ally."] =
  "아군 순환이 다른 아군으로 넘어갈 때 효과음을 재생합니다."
L["FORCE LOCK"] = "강제 잠금"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "사용자 지정 Lua 조건이 참인 동안 마우스 룩을 계속 켜 두는 고급 옵션입니다."
L["Custom Condition"] = "사용자 지정 조건"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "참으로 평가되는 동안 마우스 룩을 잠금 상태로 유지하는 사용자 지정 Lua 코드입니다."
L["Lock Once"] = "한 번만 잠금"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "조건이 처음 참이 될 때만 마우스 룩을 잠급니다. 수동으로 해제한 상태는 조건이 거짓이 되었다가 다시 참이 될 때까지 유지됩니다."
L["FORCE UNLOCK"] = "강제 해제"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "강제 잠금의 반대: 사용자 지정 Lua 조건이 참인 동안 마우스 룩을 꺼 둡니다."
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "참으로 평가되는 동안 마우스 룩을 해제 상태로 유지하는 사용자 지정 Lua 코드입니다."
L["Unlock Once"] = "한 번만 해제"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "조건이 처음 참이 될 때만 마우스 룩을 해제합니다. 수동으로 잠근 상태는 조건이 거짓이 되었다가 다시 참이 될 때까지 유지됩니다."
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "사용자 지정 Lua 조건이 참인 동안 조준점의 모양을 바꿉니다."
L["Situational Appearance"] = "상황별 모양"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "상황별 조건이 참인 동안 조준점이 사용하는 텍스처입니다."
L["Situational Condition"] = "상황별 조건"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "참으로 평가되는 동안 조준점이 상황별 모양을 사용하도록 강제하는 사용자 지정 Lua 코드입니다."
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "Action Combat Mode의 기본 조준선 대상 지정 CVar와 대상 지정 매크로 프리라인을 수정합니다."
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "경고: 이 값을 수정하면 조준선 대상 지정과 대상 고정이 작동하지 않을 수 있습니다."
L["Reticle Targeting CVar Editor"] = "조준선 대상 지정 CVar 편집기"
L["Targeting Macro Prelines Editor"] = "대상 지정 매크로 프리라인 편집기"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "뒤로"
L["Next"] = "다음"
L["Finish"] = "완료"
L["Skip tour"] = "둘러보기 건너뛰기"
L["Assist HUD"] = "보조 HUD"
L["Target Lock"] = "대상 고정"
L["Party Wheel"] = "파티 휠"
L["Set a Mouse Look key"] = "마우스 룩 단축키 지정"
L["Set an Interact key"] = "상호작용 단축키 지정"
L["Set a Target Lock key"] = "대상 고정 단축키 지정"
L["Set a Cycle Lock - Next key"] = "고정 순환 - 다음 단축키 지정"
L["Set a Cycle Lock - Previous key"] = "고정 순환 - 이전 단축키 지정"
L["Set a Radial Menu key"] = "방사형 메뉴 단축키 지정"
L["Set an Ally Cycle - Next key"] = "아군 순환 - 다음 단축키 지정"
L["Set an Ally Cycle - Previous key"] = "아군 순환 - 이전 단축키 지정"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "조준선 대상 지정을 켜거나 끄면 UI가 다시 불러와집니다."
L["Needs Reticle Targeting."] = "조준선 대상 지정이 필요합니다."
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "커서를 화면 중앙에 고정하고 마우스를 움직여 방향을 조절합니다. 더 이상 오른쪽 클릭을 누르고 있을 필요가 없습니다.\n\n{전환 단축키}와 조준 중인 대상과 {상호작용하는 단축키}를 지정하세요."
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "대상과 전투 상태에 따라 반응하는, 완전히 사용자 지정 가능한 조준점입니다.\n\n{모양}, {크기}, {위치}를 선택하세요."
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "적을 조준하면 조준점 옆의 HUD가 {다음 주문}을 추천하고 단축키를 보여줍니다.\n\n상호작용할 수 있는 대상을 조준하면 대신 그 {이름}과 {상호작용 단축키}를 보여줍니다.\n\n각각 켜거나 끌 수 있으며 조준점에 대한 {방향}, {크기}, {거리}를 설정하세요."
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "적을 조준하는 것만으로 대상을 지정하고, 지면 지정 주문과 광역 능력을 Tab 대상 지정 없이 조준점이 가리키는 곳에 바로 사용하세요.\n\n{아군 무시}를 켜면 아군을 건너뜁니다."
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "조준점 위치에 시전할 지면 지정 주문입니다.\n\n{주문 이름 또는 ID}를 입력해 추가하세요."
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!매크로인 행동 버튼은 조준선 대상 지정을 스스로 적용받을 수 없습니다.}\n\n{+}를 눌러 {매크로 작성기}를 열고 매크로를 작성하면 대상 지정 로직이 자동으로 추가됩니다.\n\n그런 다음 이 목록에서 행동 단축바로 끌어다 놓으세요. 아이콘을 {오른쪽 클릭}하면 편집할 수 있습니다."
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "한 번 눌러 대상을 고정하면 조준점이 더 이상 대상을 바꾸지 않습니다. 고정 중에는 순환 단축키가 근처 적으로 넘어갑니다.\n\n{대상 고정 동작}은 다시 눌렀을 때 해제할지({전환}) 조준점 아래의 대상으로 고정을 옮길지({대상 교체}) 정합니다.\n\n단축키를 지정하세요."
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "마우스 룩 중에 마우스 클릭을 동작으로 바꿉니다. 예를 들어 {왼쪽·오른쪽 클릭}으로 행동 단축바의 주문을 시전할 수 있습니다.\n\n{보조 키}를 함께 쓰거나 쓰지 않고 각 클릭이 하는 일을 정하세요."
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "전투 중에도 사용할 수 있는 {주문, 아이템, 매크로, 바로가기} 휠입니다.\n\n단축키를 누른 채 마우스를 조각 쪽으로 움직이고 놓으면 사용됩니다.\n\n{스크롤}하여 휠을 전환하세요."
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "여기에 등록된 {이로운 주문}의 단축키를 누르고 있으면 파티원 휠이 열립니다. 한 명 쪽으로 움직이고 놓으면 그에게 시전하고, {중앙}으로 돌아오면 자신에게 시전합니다.\n\n단축키를 {짧게 누르면} 우호적 대상에게, 없으면 자신에게 시전합니다.\n\n{주문 이름 또는 ID}를 입력해 추가하세요."
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "마우스 룩 중에 파티원을 순환하면 {이로운 주문}은 아군에게, {해로운 주문}은 계속 적에게 적용됩니다.\n\n{아군 HUD}가 선택된 대상을 보여줍니다.\n\n순환 단축키를 지정하세요."
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "{가방, 지도 또는 다른 창}을 열면 마우스 룩이 일시 중지되었다가 다시 시작됩니다.\n\n마찬가지로 일시 중지시킬 {탈것이나 추가 창}을 등록하세요."

-- Options UI: widgets, panel, search, pickers
L["What's New"] = "새로운 기능"
L["See what's new in this version"] = "이 버전의 새로운 기능을 확인합니다"
L["Link"] = "링크"
L["Copy the %s link (Ctrl+C), then paste it in your browser."] =
  "%s 링크를 복사(Ctrl+C)한 뒤 브라우저에 붙여넣으세요."
L["Character-specific option."] = "캐릭터별 옵션입니다."
L["NEW"] = "신규"
L["ON"] = "켬"
L["OFF"] = "끔"
L["Are you sure?"] = "정말 진행하시겠습니까?"
L["> Press key (ESC clears) <"] = "> 키를 누르세요 (ESC로 지우기) <"
L["WoW API Documentation"] = "WoW API 문서"
L["Pick a frame on screen"] = "화면에서 프레임 선택"
L["Pick a frame"] = "프레임 선택"
L["Silence Alerts"] = "알림 끄기"
L["Debug Mode"] = "디버그 모드"
L["Reset to Defaults"] = "기본값으로 초기화"
L["Reset all Action Combat Mode settings to defaults and reload?"] =
  "Action Combat Mode의 모든 설정을 기본값으로 되돌리고 다시 불러오시겠습니까?"
L["Uninstall"] = "제거"
L["Uninstall Action Combat Mode?\n\nThis will restore your previous camera and targeting settings, disable the addon, and reload."] =
  "Action Combat Mode를 제거하시겠습니까?\n\n이전 카메라 및 대상 지정 설정이 복원되고, 애드온이 비활성화되며, UI가 다시 불러와집니다."
L["View the changelog"] = "변경 내역 보기"
L["Run the setup wizard again?"] = "설정 마법사를 다시 실행하시겠습니까?"
L["Run the setup wizard"] = "설정 마법사 실행"
L["GitHub Repository"] = "GitHub 저장소"
L["Discord Server"] = "Discord 서버"
L["%s · Section"] = "%s · 섹션"
L["Sidebar"] = "사이드바"
L["Search options..."] = "옵션 검색..."
L["No matching options"] = "일치하는 옵션이 없습니다"
L["Section"] = "섹션"
L["Tab"] = "탭"
L["Color"] = "색상"
L["Type spell name or ID…"] = "주문 이름 또는 ID 입력…"
L["Type mount name or spell ID…"] = "탈것 이름 또는 주문 ID 입력…"
L["Type a frame name…"] = "프레임 이름 입력…"
L["Blizzard"] = "블리자드"
L["Addon"] = "애드온"
L["open"] = "열림"
L["Click a frame to add it to the list. Right-click or press Esc to cancel."] =
  "프레임을 클릭하면 목록에 추가됩니다. 오른쪽 클릭 또는 Esc로 취소합니다."
L["Line %d: %s"] = "%d번째 줄: %s"
L["Unknown API: %s - did you mean %s?"] = "알 수 없는 API: %s - %s을(를) 의미하셨나요?"
L["Unknown API: %s"] = "알 수 없는 API: %s"
L["%s (+%d more)"] = "%s (외 %d개)"
L["Version: %s"] = "버전: %s"
L["Use the button below to open Action Combat Mode options."] =
  "아래 버튼을 눌러 Action Combat Mode 옵션을 여세요."
L["You can also type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r in chat."] =
  "채팅창에 |cff69ccf0/acm|r 또는 |cff69ccf0/actioncombatmode|r를 입력해도 됩니다."
L["Open Options"] = "옵션 열기"

-- Editors: macro composer, prelines, crosshair colors and textures, CVar editor
L["%d / %d characters"] = "%d / %d자"
L["%s (over the macro limit)"] = "%s (매크로 제한 초과)"
L["Ignore Friendlies: %s"] = "아군 무시: %s"
L["Auto Target Lock: %s"] = "자동 대상 고정: %s"
L["Preline: Ignore Friendlies + No Auto Lock"] = "사전 줄: 아군 무시 + 자동 고정 없음"
L["Preline: Ignore Friendlies + Auto Lock"] = "사전 줄: 아군 무시 + 자동 고정"
L["Preline: Target Any Unit + No Auto Lock"] =
  "사전 줄: 모든 유닛 대상 + 자동 고정 없음"
L["Preline: Target Any Unit + Auto Lock"] = "사전 줄: 모든 유닛 대상 + 자동 고정"
L["Macro Composer"] = "매크로 작성기"
L["The targeting logic preline matching your current Reticle Targeting settings is added automatically before your lines, as the highlighted portion of the macro. To modify it, use the Prelines Editor under %s."] =
  "현재 조준선 대상 지정 설정에 맞는 대상 지정 사전 줄이 매크로의 강조 표시된 부분으로 내 줄 앞에 자동으로 추가됩니다. 수정하려면 %s의 사전 줄 편집기를 사용하세요."
L["Macro Name"] = "매크로 이름"
L["Enter a macro name"] = "매크로 이름을 입력하세요"
L["Saved to your general macros."] = "공용 매크로에 저장됩니다."
L["Saved to your character macros."] = "캐릭터 매크로에 저장됩니다."
L["Macro Text"] = "매크로 내용"
L["Delete Macro"] = "매크로 삭제"
L["Delete this macro? Any action bar button using it will be emptied."] =
  "이 매크로를 삭제하시겠습니까? 이 매크로를 사용하는 행동 단축바 버튼은 비워집니다."
L["Save Macro"] = "매크로 저장"
L["Preline must be %d characters or fewer (room for /click under the 255 macro limit)."] =
  "사전 줄은 %d자 이하여야 합니다 (매크로 제한 255자 안에서 /click을 위한 공간 확보)."
L["Inactive — Auto Target Lock is OFF"] = "비활성 — 자동 대상 고정이 꺼져 있음"
L["Inactive — Auto Target Lock is ON"] = "비활성 — 자동 대상 고정이 켜져 있음"
L["Inactive — Ignore Friendlies is OFF"] = "비활성 — 아군 무시가 꺼져 있음"
L["Inactive — Ignore Friendlies is ON"] = "비활성 — 아군 무시가 켜져 있음"
L["Customize the targeting prelines injected before each ability when Reticle Targeting is enabled.\n\n• Only the preline matching your current %s X %s settings is active.\n• Max %s characters per preline — SecureActionButton macros are capped at %s; the rest is reserved for the trailing %s line.\n• Use %s to reload and pick up edits."] =
  "조준선 대상 지정이 켜져 있을 때 각 능력 앞에 삽입되는 대상 지정 사전 줄을 사용자 지정합니다.\n\n• 현재 %s X %s 설정에 맞는 사전 줄만 활성화됩니다.\n• 사전 줄당 최대 %s자 — SecureActionButton 매크로는 %s자로 제한되며, 나머지는 마지막 %s 줄을 위해 남겨 둡니다.\n• %s을(를) 사용해 UI를 다시 불러오고 변경 사항을 적용하세요."
L["Apply Changes"] = "변경 사항 적용"
L["Hostile"] = "적대"
L["NPC"] = "NPC"
L["Player"] = "플레이어"
L["Object"] = "오브젝트"
L["Select a tab to customize the color and alpha of the crosshair when targeting different types of units.\n\n• %s and %s animations use the Hostile color.\n• Inactive crosshair states use the Base style."] =
  "탭을 선택해 서로 다른 유형의 유닛을 조준할 때의 조준점 색상과 투명도를 사용자 지정합니다.\n\n• %s 및 %s 애니메이션은 적대 색상을 사용합니다.\n• 비활성 조준점 상태는 기본 스타일을 사용합니다."
L["Reset to Default"] = "기본값으로 초기화"
L["Show the inactive crosshair"] = "비활성 조준점 표시"
L["Show the active crosshair"] = "활성 조준점 표시"
L["Show the mounted crosshair"] = "탈것 조준점 표시"
L["Show the disabled crosshair"] = "비활성화된 조준점 표시"
L["Hide the inactive crosshair"] = "비활성 조준점 숨기기"
L["Hide the active crosshair"] = "활성 조준점 숨기기"
L["Hide the mounted crosshair"] = "탈것 조준점 숨기기"
L["Hide the disabled crosshair"] = "비활성화된 조준점 숨기기"
L["Nothing is drawn while you are not aiming at anything."] =
  "아무것도 조준하지 않는 동안에는 아무것도 표시되지 않습니다."
L["Nothing is drawn while you are aiming at a unit or object."] =
  "유닛이나 오브젝트를 조준하는 동안에는 아무것도 표시되지 않습니다."
L["Nothing is drawn while you are mounted."] =
  "탈것에 탑승한 동안에는 아무것도 표시되지 않습니다."
L["Nothing is drawn while Target Lock holds the reticle."] =
  "대상 고정이 조준선을 유지하는 동안에는 아무것도 표시되지 않습니다."
L["Not aiming at anything"] = "아무것도 조준하지 않음"
L["Aiming at a unit or object"] = "유닛이나 오브젝트를 조준 중"
L["While you are mounted"] = "탈것에 탑승한 동안"
L["While Target Lock holds"] = "대상 고정이 유지되는 동안"
L["Brings back the texture you had before hiding it."] =
  "숨기기 전에 사용하던 텍스처를 되돌립니다."
L["Crosshair Textures"] = "조준점 텍스처"
L["Select a state, then pick a texture below, or apply a preset for a curated appearance."] =
  "상태를 선택한 뒤 아래에서 텍스처를 고르거나, 프리셋을 적용해 잘 다듬어진 모습을 사용하세요."
L["INACTIVE"] = "비활성"
L["ACTIVE"] = "활성"
L["MOUNTED"] = "탑승 중"
L["DISABLED"] = "비활성화됨"
L["PRESETS"] = "프리셋"
L["ALL TEXTURES"] = "모든 텍스처"
L["Action Combat Mode (Reticle CVar Editor)"] = "Action Combat Mode (조준선 CVar 편집기)"
L["External change (CVAR_UPDATE)"] = "외부 변경 (CVAR_UPDATE)"
L["Description"] = "설명"
L["Value"] = "값"
L["Default Value:"] = "기본값:"
L["Last Modified By:"] = "마지막 수정 주체:"
L["Double-click a row to edit. Overrides are account-wide and replace CombatMode defaults."] =
  "행을 두 번 클릭하여 편집하세요. 덮어쓰기는 계정 전체에 적용되며 CombatMode 기본값을 대체합니다."

-- Radial Menu: actions and preset wheels
L["Character Info"] = "캐릭터 정보"
L["Spellbook & Talents"] = "마법책 및 특성"
L["Spellbook"] = "마법책"
L["Legacy"] = "유산"
L["Talents"] = "특성"
L["World Map"] = "세계 지도"
L["All Bags"] = "모든 가방"
L["Professions"] = "전문 기술"
L["Achievements"] = "업적"
L["Quest Log"] = "퀘스트 목록"
L["Guild & Communities"] = "길드 및 커뮤니티"
L["Group Finder"] = "파티 찾기"
L["Warband Collection"] = "전투부대 수집품"
L["Housing Dashboard"] = "주거 현황판"
L["Adventure Guide"] = "모험 안내서"
L["Calendar"] = "달력"
L["Friends & Social"] = "친구 및 소셜"
L["Game Menu"] = "게임 메뉴"
L["ACM Options"] = "ACM 설정"
L["Wave"] = "손 흔들기"
L["Dance"] = "춤추기"
L["Cheer"] = "환호"
L["Bow"] = "절하기"
L["Salute"] = "경례"
L["Laugh"] = "웃기"
L["Flex"] = "근육 자랑"
L["Roar"] = "포효"
L["Thank"] = "감사"
L["Clap"] = "박수"
L["Point"] = "가리키기"
L["Cry"] = "울기"
L["Sit"] = "앉기"
L["Kneel"] = "무릎 꿇기"
L["Reputation"] = "평판"
L["Currency"] = "화폐"
L["Great Vault"] = "위대한 금고"
L["Mount Journal"] = "탈것 모음"
L["Pet Journal"] = "애완동물 모음"
L["Toy Box"] = "장난감 상자"
L["Macros"] = "매크로"
L["Hello"] = "안녕"
L["Bye"] = "작별"
L["Applaud"] = "갈채"
L["Shrug"] = "어깨 으쓱"
L["Yes"] = "예"
L["No"] = "아니요"
L["Kiss"] = "키스"
L["Flirt"] = "추파"
L["Rude"] = "무례"
L["Ready"] = "준비"
L["Victory"] = "승리"
L["Ready Check"] = "전투 준비 확인"
L["Roll (1-100)"] = "주사위 (1-100)"
L["Reload UI"] = "UI 다시 불러오기"
L["Leave Party"] = "파티 나가기"
L["Reset Instances"] = "인스턴스 초기화"
L["Pull Countdown (10s)"] = "풀 카운트다운 (10초)"
L["Role Check"] = "역할 확인"
L["Convert to Raid"] = "공격대로 전환"
L["Summon Random Mount"] = "무작위 탈것 소환"
L["Take Screenshot"] = "스크린샷 찍기"
L["Sheathe / Unsheathe Weapons"] = "무기 집어넣기 / 꺼내기"
L["Loot Spec: Current Spec"] = "전리품 전문화: 현재 전문화"
L["Invite Target"] = "대상 초대"
L["Focus Target"] = "주시 대상 설정"
L["Cancel Form"] = "변신 해제"
L["Follow Target"] = "대상 따라가기"
L["Duel Target"] = "대상에게 결투 신청"
L["Inspect Target"] = "대상 살펴보기"
L["Toggle AFK"] = "자리 비움 전환"
L["Toggle Do Not Disturb"] = "다른 용무 중 전환"
L["Camp (Log Out)"] = "야영 (로그아웃)"
L["Dismount"] = "탈것 내리기"
L["Leave Vehicle"] = "탈것에서 내리기"
L["Mark Target: %s"] = "대상 징표: %s"
L["Clear Target Mark"] = "대상 징표 해제"
L["World Marker: %s"] = "공대 위치 표시: %s"
L["Clear World Markers"] = "공대 위치 표시 해제"
L["Interface"] = "인터페이스"
L["Misc"] = "기타"
L["Wheel %d"] = "휠 %d"

-- Runtime: composed macro messages, changelog tooltip
L["Your character macro list is full."] = "캐릭터 매크로 목록이 가득 찼습니다."
L["Your general macro list is full."] = "공용 매크로 목록이 가득 찼습니다."
L["Cannot delete a macro while in combat."] =
  "전투 중에는 매크로를 삭제할 수 없습니다."
L["Cannot save a macro while in combat."] =
  "전투 중에는 매크로를 저장할 수 없습니다."
L["Enter a macro name."] = "매크로 이름을 입력하세요."
L["Macro names are limited to %d characters."] =
  "매크로 이름은 %d자까지 입력할 수 있습니다."
L["Enter the macro text to run after the targeting preline."] =
  "대상 지정 사전 줄 뒤에 실행할 매크로 내용을 입력하세요."
L["Macro is %d characters over the %d limit."] =
  "매크로가 %d자 초과했습니다 (제한 %d자)."
L["Macro “%s” no longer fits with the current preline; edit it from Reticle Targeting Macros."] =
  "매크로 「%s」이(가) 현재 사전 줄과 함께 들어가지 않습니다. 조준선 대상 지정 매크로에서 편집하세요."
L["Click to print URL to chat"] = "클릭하여 URL을 대화창에 출력"
