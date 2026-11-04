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
