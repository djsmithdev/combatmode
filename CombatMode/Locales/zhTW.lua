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

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = "滑鼠視角"
L["CAMERA FEATURES"] = "鏡頭功能"
L["ADDITIONAL FEATURES"] = "附加功能"
L["Crosshair - More accurate"] = "準星 - 更精確"
L["Soft Target - More forgiving"] = "軟目標 - 更寬容"
L["Mouse Look is on"] = "滑鼠視角已開啟"
L["In combat"] = "戰鬥中"
L["Talking to an NPC"] = "與NPC對話中"
L["Any checked"] = "任一勾選項"
L["All checked"] = "所有勾選項"
L["Off"] = "關閉"
L["Control relinquished to %s"] = "已將控制權交給 %s"
L["Disabled while Motion Sickness Protection is on"] = "動態暈眩保護開啟時無法使用"
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  "將游標鎖定在準星位置，移動滑鼠即可轉向，無需按住右鍵。"
L["Mouse Look Keybind"] = "滑鼠視角按鍵"
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] =
  "點按切換滑鼠視角，按住可暫時解鎖游標。"
L["Interact Keybind"] = "互動按鍵"
L["Tap to interact with a player or the unit chosen below."] =
  "點按可與玩家或下方所選單位互動。"
L["Players"] = "玩家"
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  "瞄準玩家一秒後，輔助HUD會顯示提示，此時按下該鍵即可開啟其右鍵選單。"
L["NPCs and objects"] = "NPC和物件"
L["Interacts as normal with the unit chosen in Interact Unit."] =
  "與「互動單位」中選擇的單位正常互動。"
L["Interact Unit"] = "互動單位"
L["Which unit will be interacted with when the key is pressed."] =
  "按下按鍵時與哪個單位進行互動。"
L["Flip Camera Keybind"] = "翻轉鏡頭按鍵"
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  "點按可將鏡頭繞角色翻轉180°；按住則僅在按住期間保持翻轉。"
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  "修復在macOS上切換視窗後游標卡住的問題。重新擷取並釋放滑鼠視角，以清除遊戲在背景執行時遺留的卡住的擷取。"
L["Curated camera adjustments for a more action-focused experience."] =
  "為更注重動作的體驗精選的鏡頭調整。"
L["Motion Sickness Protection"] = "動態暈眩保護"
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] =
  "防止 Action Combat Mode 覆蓋暴雪的動態暈眩設定。"
L["Turn Speed"] = "轉向速度"
L["Controls how quickly the camera turns while using Mouse Look."] =
  "控制使用滑鼠視角時鏡頭的轉動速度。"
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] =
  "限制鏡頭拉近的最小距離。設為0則關閉。"
L["Dynamic Pitch"] = "動態俯仰"
L["Dynamically tilt the camera up and down as you move it."] =
  "移動鏡頭時動態地上下傾斜鏡頭。"
L["Pitch Strength"] = "俯仰強度"
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  "動態俯仰使鏡頭傾斜的幅度。數值越低，角色在螢幕上的位置越高。飛行時傾斜幅度更大，並隨此值縮放。"
L["Shoulder Offset"] = "越肩偏移"
L["Camera's horizontal position relative to the character."] =
  "鏡頭相對於角色的水平位置。"
L["Disable Offset With Mouselook"] = "滑鼠視角時停用偏移"
L["Shoulder Offset eases to 0 when disabling Mouse Look."] =
  "關閉滑鼠視角時，越肩偏移會平滑過渡到0。"
L["When off, Shoulder Offset stays constant at all times."] =
  "關閉時，越肩偏移始終保持不變。"
L["Swap Shoulder Keybind"] = "切換肩膀按鍵"
L["Press to mirror Shoulder Offset to the other side of your character."] =
  "按下可將越肩偏移鏡像到角色的另一側。"
L["Extra functionalities tied to Mouse Look behaviour."] =
  "與滑鼠視角行為相關的額外功能。"
L["Cursor Pulse"] = "游標脈衝"
L["Flash the cursor when Mouse Look is turned off."] = "關閉滑鼠視角時讓游標閃爍。"
L["Hide Tooltips"] = "隱藏提示"
L["Hide tooltips while Mouse Look is on, unless the key below is held."] =
  "滑鼠視角開啟時隱藏提示，除非按住下方的按鍵。"
L["Show Tooltips With"] = "顯示提示按鍵"
L["Hold this key to show tooltips while Mouse Look is on."] =
  "滑鼠視角開啟時，按住此鍵可顯示提示。"
L["Auto Sheath"] = "自動收起武器"
L["Sheath weapons automatically with Mouse Look."] = "隨滑鼠視角自動收起武器。"
L["Vignette Shows When"] = "暗角顯示條件"
L["Darkens the edges of the screen while the checked situations are true."] =
  "當勾選的情形成立時，使螢幕邊緣變暗。"
L["Vignette Match"] = "暗角符合方式"
L["Any: one checked situation is enough. All: every checked situation must be true at once."] =
  "任一：勾選的情形滿足其一即可。全部：所有勾選的情形必須同時成立。"

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = "任何硬目標"
L["Locked Target Only"] = "僅鎖定的目標"
L["Soft Target (Blizzard)"] = "軟目標（暴雪）"
L["Hidden"] = "隱藏"
L["Toggle"] = "切換"
L["Switch Target"] = "切換目標"
L["A UI Reload is required when making this change. Proceed?"] =
  "進行此變更需要重新載入介面。是否繼續？"
L["Create New Macro"] = "建立新巨集"
L["Write a macro that starts with your Reticle Targeting preline."] =
  "編寫一個以準星瞄準前置行開頭的巨集。"
L["Unavailable in combat."] = "戰鬥中無法使用。"
L["Drag to a button on your action bars to use."] = "拖曳到快捷列按鈕上即可使用。"
L["Right-click to edit"] = "右鍵編輯"
L["+%d more in /macro"] = "/macro 中還有 %d 個"
L["Reticle Targeting Macros"] = "準星瞄準巨集"
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  "作為巨集的動作按鈕不會自動繼承準星瞄準邏輯。若要讓它們遵循這些規則，請使用巨集編寫器建立，然後拖曳到快捷列上。"
L["Reticle Targeting"] = "準星瞄準"
L["RETICLE TARGETING"] = "準星瞄準"
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  "啟用基於瞄準的單位選取，並可精確放置地面法術與範圍技能。"
L["Enable Reticle Targeting"] = "啟用準星瞄準"
L["Aim the crosshair at units to pick targets instead of tab-targeting."] =
  "將準星對準單位來選取目標，取代Tab選取。"
L["Ignore Friendlies"] = "忽略友方"
L["Ignore friendly NPCs and Players, and only target hostile units."] =
  "忽略友方NPC和玩家，只選取敵對單位。"
L["Click Casting Only"] = "僅點擊施法"
L["Apply reticle targeting logic only to Click Casting binds."] =
  "僅對點擊施法綁定套用準星瞄準邏輯。"
L["Excluded Spells"] = "排除的法術"
L["Spells to skip the reticle targeting logic."] = "跳過準星瞄準邏輯的法術。"
L["Cast at Crosshair"] = "在準星處施放"
L["Ground spells to cast at the crosshair location."] = "在準星位置施放的地面法術。"
L["TARGET LOCK"] = "目標鎖定"
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  "鎖定目標以防止誤切換，並在單位間循環以優先處理特定敵人。"
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  "警告：目標鎖定會使用你的專注目標。其他任何設定專注目標的功能都會與之衝突。"
L["Target Lock Keybind"] = "目標鎖定按鍵"
L["Lock the reticle to a target, preventing it from swapping."] =
  "將準星鎖定在目標上，防止其切換。"
L["Cycle Lock - Next"] = "循環鎖定 - 下一個"
L["Move Target Lock to the next valid nearby target."] =
  "將目標鎖定移至附近下一個有效目標。"
L["Cycle Lock - Previous"] = "循環鎖定 - 上一個"
L["Move Target Lock to the previous valid nearby target."] =
  "將目標鎖定移至附近上一個有效目標。"
L["Target Lock Behavior"] = "目標鎖定行為"
L["What the Target Lock key does when you press it."] = "按下目標鎖定鍵時的行為。"
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] =
  "鎖定你的目標或準星下的單位。再次點按可解除鎖定。"
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  "鎖定準星下的單位，並取代目前的鎖定。準星下沒有目標時點按可解除鎖定。瞄準已鎖定的單位則維持鎖定。"
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  "開啟「忽略友方」後，準星下的友方或已死亡單位會被忽略：鎖定維持不變。"
L["Auto Target Lock"] = "自動目標鎖定"
L["Target Lock engages automatically when attacking units."] =
  "攻擊單位時自動啟用目標鎖定。"
L["Target Lock Marker"] = "目標鎖定標記"
L["Show a crosshair marker on the nameplate of the locked target."] =
  "在被鎖定目標的名條上顯示準星標記。"
L["Focus Locked Target"] = "聚焦鎖定目標"
L["Pulls the camera toward your locked target, keeping it in focus."] =
  "將鏡頭拉向被鎖定的目標，使其保持在焦點中。"
L["TARGETING INDICATORS"] = "目標指示"
L["Visual indicators that highlight targets in the world for easier identification."] =
  "在世界中醒目標示目標的視覺指示，便於辨認。"
L["Target Outline"] = "目標輪廓"
L["Show an outline effect on your target."] = "在你的目標上顯示輪廓效果。"
L["Only available on Retail"] = "僅在正式服可用"
L["Selection Circle"] = "選取圈"
L["Which target gets Blizzard's selection circle underneath their feet."] =
  "決定哪個目標腳下顯示暴雪的選取圈。"
L["The circle under whatever you have targeted, enemy or friendly."] =
  "顯示在你選取的任何目標（無論敵友）腳下的圈。"
L["The circle only under your Target Lock."] = "僅顯示在你的鎖定目標腳下。"
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] =
  "由暴雪控制 ObjectSelectionCircle 與 UnitNameFocused 的行為。"
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  "暴雪會從角色模型前方的扇形區域中選取軟目標，不會考慮準星位置或越肩偏移。"
L["No selection circle."] = "不顯示選取圈。"

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = "準星"
L["CROSSHAIR"] = "準星"
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  "會對目標和戰鬥狀態做出反應的動態準星，可提升精準度並引導準星瞄準。"
L["Enable Crosshair"] = "啟用準星"
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] =
  "處於滑鼠視角時，在螢幕上顯示動態且有回饋的準星。"
L["Cast Feedback"] = "施法回饋"
L["Crosshair provides visual feedback while casting."] = "施法時準星會提供視覺回饋。"
L["Appearance"] = "外觀"
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  "準星在各狀態下使用的紋理。點擊其一可選擇紋理，也可從預設開始。"
L["Inactive"] = "未啟用"
L["Active"] = "已啟用"
L["Mounted"] = "騎乘中"
L["Disabled"] = "已停用"
L["Reaction Colors"] = "反應顏色"
L["Edit"] = "編輯"
L["Customize the colors used by the crosshair when targeting different types of units."] =
  "自訂準星瞄準不同類型單位時使用的顏色。"
L["Scale"] = "縮放"
L["Scales the size of the crosshair."] = "縮放準星的大小。"
L["Vertical Position"] = "垂直位置"
L["Move the crosshair up or down from screen center."] =
  "將準星從螢幕中心上移或下移。"
L["ASSIST HUD"] = "輔助HUD"
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  "瞄準敵人時引導技能循環，並顯示互動提示的HUD。"
L["Next-cast Suggestion"] = "下一個施法建議"
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] =
  "瞄準目標時顯示輔助醒目提示的下一個施法建議。"
L["Always"] = "始終"
L["Only In Combat"] = "僅戰鬥中"
L["Interactable Indicator"] = "可互動指示"
L["Show an indicator while aiming at an interactable unit or object."] =
  "瞄準可互動的單位或物件時顯示指示。"
L["Player Interaction Prompt"] = "玩家互動提示"
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  "瞄準玩家一秒後顯示指示。按下互動鍵即可開啟其右鍵選單。"
L["Position"] = "位置"
L["Which side of the crosshair the HUD appears on."] = "HUD顯示在準星的哪一側。"
L["Left"] = "左"
L["Right"] = "右"
L["Scales the size of the HUD."] = "縮放HUD的大小。"
L["Distance"] = "距離"
L["Distance between the HUD and the crosshair."] = "HUD與準星之間的距離。"

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = "Action Combat Mode"
L["Modified Blizzard Actions"] = "已修改的暴雪動作"
L["Blizzard Actions"] = "暴雪動作"
L["Base"] = "基礎"
L["Shift"] = "Shift"
L["Ctrl"] = "Ctrl"
L["Alt"] = "Alt"
L["Clear Target"] = "清除目標"
L["Clear Focus"] = "清除專注目標"
L["Start Attack"] = "開始攻擊"
L["Pet Attack"] = "寵物攻擊"
L["Toggle Focus Any"] = "切換專注目標（任意）"
L["Toggle Focus Enemy"] = "切換專注目標（敵人）"
L["Run MACRO"] = "執行 MACRO"
L["— none —"] = "— 無 —"
L["Override this click during Mouse Look."] = "在滑鼠視角期間覆蓋此次點擊。"
L["Action"] = "動作"
L["Macro"] = "巨集"
L["Select a macro"] = "選擇巨集"
L["No targeting"] = "無瞄準"
L["Left Click"] = "左鍵點擊"
L["Right Click"] = "右鍵點擊"
L["Shift + Left Click"] = "Shift + 左鍵點擊"
L["Shift + Right Click"] = "Shift + 右鍵點擊"
L["Ctrl + Left Click"] = "Ctrl + 左鍵點擊"
L["Ctrl + Right Click"] = "Ctrl + 右鍵點擊"
L["Alt + Left Click"] = "Alt + 左鍵點擊"
L["Alt + Right Click"] = "Alt + 右鍵點擊"
L["Click Casting"] = "點擊施法"
L["CLICK CASTING"] = "點擊施法"
L["Assign override actions to left and right clicks that are active during Mouse Look."] =
  "為左鍵和右鍵點擊指定在滑鼠視角期間生效的覆蓋動作。"
L["Account-Wide Binds"] = "帳號通用綁定"
L["Share Click Casting binds across all characters."] =
  "在所有角色之間共享點擊施法綁定。"
L["Click Binds"] = "點擊綁定"
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] =
  "基礎、Shift、Ctrl 和 Alt 各自擁有獨立的左鍵和右鍵點擊動作。"

-- TabRadialMenu.lua: Radial Menu tab
L["Radial Menu Wheels"] = "輪盤選單的輪盤"
L["Forever"] = "Forever"
L["Minimal"] = "極簡"
L["Clear Slice"] = "清空扇區"
L["UI Actions"] = "介面動作"
L["Emotes"] = "表情"
L["Commands"] = "指令"
L["Markers"] = "標記"
L["Slice"] = "扇區"
L["Choose an action"] = "選擇動作"
L["Presets"] = "預設"
L["New Wheel"] = "新輪盤"
L["Wheel"] = "輪盤"
L["You can have up to %d wheels."] = "最多可以有 %d 個輪盤。"
L["That can't go on a wheel. Use a spell, item, toy, mount or macro."] =
  "無法放入輪盤。請使用法術、物品、玩具、坐騎或巨集。"
L["Drag a spell, item, toy, mount or macro here, or click to change the action."] =
  "將法術、物品、玩具、坐騎或巨集拖到此處，或點擊以變更動作。"
L["Empty Slice"] = "空扇區"
L["Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel."] =
  "將法術、物品、玩具、坐騎或巨集拖到此處，或點擊以設定動作。空扇區不會出現在輪盤中。"
L["A wheel needs at least one slice."] = "輪盤至少需要一個扇區。"
L["Click to rename this wheel"] = "點擊重新命名此輪盤"
L["Previous wheel"] = "上一個輪盤"
L["Next wheel"] = "下一個輪盤"
L["Click to select this wheel, drag to reorder"] = "點擊選擇此輪盤，拖曳可重新排序"
L["Add Slice"] = "新增扇區"
L["A wheel holds up to %d slices."] = "一個輪盤最多有 %d 個扇區。"
L["Remove Wheel"] = "移除輪盤"
L["Deletes this wheel and all of its slices."] = "刪除此輪盤及其所有扇區。"
L["You need at least one wheel."] = "至少需要一個輪盤。"
L["Remove this wheel and all of its slices?"] = "要移除此輪盤及其所有扇區嗎？"
L["Add Wheel"] = "新增輪盤"
L["Pick a preset wheel or a blank one."] = "選擇預設輪盤或空白輪盤。"
L["Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."] =
  "點擊扇區選擇其動作，或將法術、物品、玩具、坐騎或巨集拖放到其上。\n拖曳扇區可重新排序，按右鍵可移除。"
L["RADIAL MENU"] = "輪盤選單"
L["Create quick access wheels for spells, items, macros, emotes, and interface shortcuts."] =
  "為法術、物品、巨集、表情和介面捷徑建立快速存取輪盤。"
L["Radial Menu Keybind"] = "輪盤選單按鍵"
L["Hold to open the radial menu, aim at a slice, then release to activate it. Scroll to switch between wheels."] =
  "按住以開啟輪盤選單，瞄準一個扇區後放開即可觸發。捲動滑鼠滾輪可切換輪盤。"
L["Radial Menu Style"] = "輪盤選單樣式"
L["Choose the appearance of the Radial Menu wheels."] = "選擇輪盤選單的外觀。"
L["Party Wheel Spells"] = "隊伍輪盤法術"
L["Helpful spells that open a party targeting wheel while their key is held. Flick toward a party member and release to cast on them, or return to the center to cast on yourself. Tap to cast on your friendly target, or yourself if none is selected."] =
  "按住按鍵時會開啟隊伍選取輪盤的增益法術。向隊友方向滑動並放開即可對其施法，回到中心則對自己施法。輕按則對友方目標施法，未選擇目標時對自己施法。"
L["Edit the slices of each wheel, rename wheels and add or remove wheels."] =
  "編輯每個輪盤的扇區、重新命名輪盤，以及新增或移除輪盤。"

-- TabAllyCycle.lua: Ally Cycle tab
L["Top"] = "頂部"
L["Bottom"] = "底部"
L["Ally Cycle"] = "友方循環"
L["ALLY CYCLE"] = "友方循環"
L["Seamless combat and support by allowing helpful spells to target allies, while harmful spells remain focused on the hostile crosshair target."] =
  "戰鬥與輔助無縫銜接：增益法術以友方為目標，而傷害法術仍鎖定準星下的敵方目標。"
L["Ally Cycle - Next"] = "友方循環 - 下一個"
L["Target the next group member."] = "選定下一位隊伍成員。"
L["Ally Cycle - Previous"] = "友方循環 - 上一個"
L["Target the previous group member."] = "選定上一位隊伍成員。"
L["Skip Self"] = "跳過自己"
L["Skip yourself when cycling through group members."] =
  "在循環切換隊伍成員時跳過自己。"
L["Keep Ally After Harm"] = "攻擊後保留友方"
L["After a harmful spell targets the reticle enemy, restore the previous ally. On by default for Healer specs until changed."] =
  "有害法術作用於準星下的敵人後，恢復之前的友方目標。治療專精預設開啟，直到被變更。"
L["Disabled while Auto Target Lock is on"] = "自動目標鎖定開啟時已停用"
L["ALLY HUD"] = "友方 HUD"
L["A HUD displaying the group member Ally Cycle has selected."] =
  "顯示友方循環所選隊伍成員的 HUD。"
L["Ally HUD"] = "友方 HUD"
L["Show a unit frame for the currently selected group member."] =
  "為目前選定的隊伍成員顯示單位框架。"
L["Where the Ally HUD sits relative to the crosshair."] = "友方 HUD 相對於準星的位置。"
L["Scales the size of the Ally HUD."] = "縮放友方 HUD 的大小。"
L["Distance between the Ally HUD and the crosshair."] = "友方 HUD 與準星之間的距離。"

-- TabAutoCursorUnlock.lua: Auto Unlock tab
L["Auto Unlock"] = "自動解鎖"
L["AUTO UNLOCK"] = "自動解鎖"
L["Automatically pauses Mouse Look when windows open and resumes it when they close."] =
  "開啟視窗時自動暫停滑鼠視角，關閉後恢復。"
L["Release the cursor when UI panels open."] = "開啟介面面板時釋放游標。"
L["Unlock Mounts"] = "解鎖坐騎"
L["Mounts that force a cursor unlock while mounted."] = "騎乘時會強制釋放游標的坐騎。"
L["Extra Frames"] = "額外框架"
L["Extra frame names that trigger an auto unlock. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen."] =
  "觸發自動解鎖的額外框架名稱。輸入以搜尋暴雪和插件框架，或使用檢查按鈕點擊螢幕上的視窗。"

-- TabAdvanced.lua: Advanced tab
L["Advanced"] = "進階"
L["SOUNDS"] = "音效"
L["Control the sound cues used by some of the other features."] =
  "控制其他一些功能所使用的提示音。"
L["Mouse Look Sounds"] = "滑鼠視角音效"
L["Play a cue when Mouse Look turns on and off."] =
  "滑鼠視角開啟或關閉時播放提示音。"
L["Target Lock Sounds"] = "目標鎖定音效"
L["Play cues when a Target Lock is set, cleared or cycled."] =
  "設定、清除或切換目標鎖定時播放提示音。"
L["Radial Menu Sounds"] = "輪盤選單音效"
L["Play cues when interacting with Radial Menu wheels."] =
  "與輪盤選單的輪盤互動時播放提示音。"
L["Ally Cycle Sounds"] = "友方循環音效"
L["Play a cue when Ally Cycle moves to another ally."] =
  "友方循環切換到另一名友方時播放提示音。"
L["FORCE LOCK"] = "強制鎖定"
L["An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."] =
  "進階選項：只要自訂 Lua 條件為真，就保持滑鼠視角開啟。"
L["Custom Condition"] = "自訂條件"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked."] =
  "自訂 Lua 程式碼，求值為真時會使滑鼠視角保持鎖定。"
L["Lock Once"] = "僅鎖定一次"
L["Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again."] =
  "僅在條件首次變為真時鎖定滑鼠視角。手動解鎖會一直生效，直到條件變為假後再次變為真。"
L["FORCE UNLOCK"] = "強制解鎖"
L["The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."] =
  "與「強制鎖定」相反：只要自訂 Lua 條件為真，就保持滑鼠視角關閉。"
L["Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked."] =
  "自訂 Lua 程式碼，求值為真時會使滑鼠視角保持解鎖。"
L["Unlock Once"] = "僅解鎖一次"
L["Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again."] =
  "僅在條件首次變為真時解鎖滑鼠視角。手動鎖定會一直生效，直到條件變為假後再次變為真。"
L["Swaps the crosshair's appearance for as long as a custom Lua condition is true."] =
  "只要自訂 Lua 條件為真，就更換準星外觀。"
L["Situational Appearance"] = "情境外觀"
L["Textures utilized by the crosshair while the Situational Condition returns true."] =
  "情境條件為真時準星使用的紋理。"
L["Situational Condition"] = "情境條件"
L["Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance."] =
  "自訂 Lua 程式碼，求值為真時會強制準星使用其情境外觀。"
L["Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines."] =
  "修改 Action Combat Mode 預設的準星瞄準 CVar 和瞄準巨集前置行。"
L["Warning: editing these values could break Reticle Targeting and Target Lock."] =
  "警告：編輯這些值可能會導致準星瞄準和目標鎖定失效。"
L["Reticle Targeting CVar Editor"] = "準星瞄準 CVar 編輯器"
L["Targeting Macro Prelines Editor"] = "瞄準巨集前置行編輯器"

-- SetupWizard.lua / Spotlight.lua: setup wizard
L["Back"] = "上一步"
L["Next"] = "下一步"
L["Finish"] = "完成"
L["Skip tour"] = "跳過導覽"
L["Assist HUD"] = "輔助 HUD"
L["Target Lock"] = "目標鎖定"
L["Party Wheel"] = "隊伍輪盤"
L["Set a Mouse Look key"] = "設定滑鼠視角按鍵"
L["Set an Interact key"] = "設定互動按鍵"
L["Set a Target Lock key"] = "設定目標鎖定按鍵"
L["Set a Cycle Lock - Next key"] = "設定「循環鎖定 - 下一個」按鍵"
L["Set a Cycle Lock - Previous key"] = "設定「循環鎖定 - 上一個」按鍵"
L["Set a Radial Menu key"] = "設定輪盤選單按鍵"
L["Set an Ally Cycle - Next key"] = "設定「友方循環 - 下一個」按鍵"
L["Set an Ally Cycle - Previous key"] = "設定「友方循環 - 上一個」按鍵"
L["Turning Reticle Targeting on or off reloads the UI."] =
  "開啟或關閉準星瞄準會重新載入介面。"
L["Needs Reticle Targeting."] = "需要準星瞄準。"
L["Lock your cursor to the center of the screen and steer by moving the mouse, no more holding right-click.\n\nSet a {key to toggle it}, and {one to interact with} whatever you're aiming at."] =
  "將游標鎖定在螢幕中央，透過移動滑鼠來轉向，無需再按住右鍵。\n\n設定一個{切換按鍵}，以及一個與瞄準目標{互動的按鍵}。"
L["A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}."] =
  "可依據目標和戰鬥狀態自動變化、完全可自訂的準星。\n\n選擇它的{外觀}、{大小}和{位置}。"
L["Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair."] =
  "瞄準敵人時，準星旁的 HUD 會建議你的{下一個法術}並顯示其按鍵。\n\n瞄準可互動的目標時，則顯示其{名稱}和你的{互動按鍵}。\n\n可分別開啟或關閉，並設定它相對準星的{方位}、{大小}和{距離}。"
L["Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies."] =
  "只需瞄準即可選定敵人，並將指向性法術和範圍技能直接施放在準星所指之處，無需 Tab 選目標。\n\n{忽略友方}會讓它跳過友方。"
L["Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it."] =
  "應在準星位置施放的指向性法術。\n\n輸入{法術名稱或 ID}即可新增。"
L["{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it."] =
  "{!作為巨集的動作按鈕無法自行繼承準星瞄準。}\n\n點擊 {+} 開啟{巨集編輯器}，在其中編寫巨集，系統會自動為其加入瞄準邏輯。\n\n然後將它從此清單拖到你的動作列上；{右鍵點擊}圖示可進行編輯。"
L["Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys."] =
  "一鍵鎖定目標，讓準星不再切換。鎖定期間，循環按鍵會跳到附近的敵人。\n\n{目標鎖定行為}決定再次按鍵是解除鎖定（{切換}），還是將鎖定轉移到準星下的目標（{切換目標}）。\n\n設定你的按鍵。"
L["Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar spells with {Left and Right Click}.\n\nPick what each click does, with or without a {modifier key}."] =
  "在滑鼠視角下將滑鼠點擊變為動作，例如用{左鍵和右鍵}施放動作列上的法術。\n\n選擇每次點擊的功能，可搭配或不搭配{修飾鍵}。"
L["A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\nHold its key, move the mouse toward a slice and release to use it.\n\n{Scroll} to switch between wheels."] =
  "在戰鬥中也可使用的{法術、物品、巨集和捷徑}輪盤。\n\n按住按鍵，將滑鼠移向某個扇區，放開即可使用。\n\n{滾動滾輪}可切換輪盤。"
L["Hold the key of a {helpful spell} listed here to open a wheel of your group members. Move toward one and release to cast on them, or come back to the {center} to cast on yourself.\n\n{Tap} the key to cast on your friendly target, or yourself if you have none.\n\nType a {spell name or ID} to add it."] =
  "按住此處列出的{增益法術}的按鍵，開啟隊伍成員輪盤。移向某位成員並放開即可對其施放，回到{中心}則對自己施放。\n\n{輕按}按鍵則對你的友方目標施放，沒有目標時對自己施放。\n\n輸入{法術名稱或 ID}即可新增。"
L["Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys."] =
  "在滑鼠視角下循環切換隊伍成員，讓{增益法術}作用於友方，而{傷害法術}仍打向敵人。\n\n{友方 HUD}會顯示目前選中的成員。\n\n設定你的循環按鍵。"
L["Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\nAdd {mounts or extra windows} that should pause it too."] =
  "開啟{背包、地圖或其他視窗}時滑鼠視角會暫停，關閉後恢復。\n\n新增同樣需要使其暫停的{坐騎或額外框架}。"
