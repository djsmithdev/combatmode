---------------------------------------------------------------------------------------
--  Locales/enUS.lua — LOCALES — canonical English strings
---------------------------------------------------------------------------------------
--  What it does: Lists every player-facing string as an `L[<English text>] = true` line.
--  This file is the source of truth for the key set: scripts/check-repo.ps1 requires every
--  string read through L in the addon to be listed here, and every other locale to define
--  exactly these keys.
--  Architecture / how it works:
--    • `true` means "same as the key" (see Locales/Locale.lua `__newindex`).
--    • Group entries under a comment per file or tab; keep placeholders (%s, %d) and colour
--      codes (|cffxxxxxx...|r) as they appear in the code.
--  Does not: Hold translations; those live in the other Locales/xxXX.lua files.
--  Related: Locales/Locale.lua, .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

-- selene: allow(unused_variable)
local L = CM.L

-- Constants/Assets.lua: welcome popup and Key Bindings labels
L["Welcome to Action Combat Mode!"] = true
L["The configuration panel will open after you close this message."] = true
L["You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r."] = true
L["|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r"] =
  true
L["Mouse Look"] = true
L["Flip Camera"] = true
L["Swap Shoulder"] = true
L["Reset Mouse Look"] = true
L["Ally Cycle Next"] = true
L["Ally Cycle Previous"] = true
L["Toggle Focus Target"] = true
L["Cycle Focus Next"] = true
L["Cycle Focus Previous"] = true
L["Radial Menu"] = true

-- Core messages: chat output, binding queue contexts, combat-lockdown notices
L["binding change"] = true
L["deferred %s until combat ends."] = true
L["failed to apply %s: %s"] = true
L["applied deferred binding updates."] = true
L["|cffE52B50%s detected!|r Handing over turn speed, shoulder, and dynamic pitch."] = true
L["Cannot uninstall while in combat."] = true
L["restored your previous camera/targeting settings and default mouse camera binds, then disabled the addon."] =
  true
L["Type |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r for settings."] = true
L["camera and targeting CVars restored."] = true
L["Cannot open settings while in combat."] = true
L["Cannot open this editor while in combat."] = true
L["Cannot open editor while in combat."] = true
L["cannot edit Reticle Targeting CVars while in combat."] = true
L["cannot reset Reticle Targeting CVars while in combat."] = true
L["MOVEANDSTEER unbind"] = true
L["restore default mouse camera bindings"] = true
L["Minimum Zoom"] = true
L["ally cycle bindings"] = true
L["radial menu"] = true
L["target lock keybinding"] = true
L["cycle focus next keybinding"] = true
L["cycle focus previous keybinding"] = true
L["ally cycle next keybinding"] = true
L["ally cycle previous keybinding"] = true
L["radial menu keybinding"] = true
L["reticle interact keybinding"] = true
L["mouse look keybinding"] = true
L["flip camera keybinding"] = true
L["reset mouse look keybinding"] = true
L["swap shoulder keybinding"] = true

-- TabGeneral.lua: Mouse Look tab
L["MOUSE LOOK"] = true
L["CAMERA FEATURES"] = true
L["ADDITIONAL FEATURES"] = true
L["Crosshair - More accurate"] = true
L["Soft Target - More forgiving"] = true
L["Mouse Look is on"] = true
L["In combat"] = true
L["Talking to an NPC"] = true
L["Any checked"] = true
L["All checked"] = true
L["Off"] = true
L["Control relinquished to %s"] = true
L["Disabled while Motion Sickness Protection is on"] = true
L["Lock the cursor to the position of the Crosshair and steer by moving the mouse without holding right-click."] =
  true
L["Mouse Look Keybind"] = true
L["Tap to toggle Mouse Look. Hold to unlock the cursor temporarily."] = true
L["Interact Keybind"] = true
L["Tap to interact with a player or the unit chosen below."] = true
L["Players"] = true
L["Aim at a player for a second and the Assist HUD shows a prompt. Press the key then to open their context menu."] =
  true
L["NPCs and objects"] = true
L["Interacts as normal with the unit chosen in Interact Unit."] = true
L["Interact Unit"] = true
L["Which unit will be interacted with when the key is pressed."] = true
L["Flip Camera Keybind"] = true
L["Tap to flip the camera 180° around your character. Hold to flip it only while the key is held."] =
  true
L["Recover a stuck cursor after switching windows on macOS. Re-grabs and releases Mouse Look to clear a capture the game left stuck while running in the background."] =
  true
L["Curated camera adjustments for a more action-focused experience."] = true
L["Motion Sickness Protection"] = true
L["Prevents Action Combat Mode from overriding Blizzard's Motion Sickness settings."] = true
L["Turn Speed"] = true
L["Controls how quickly the camera turns while using Mouse Look."] = true
L["Stops the camera from zooming in closer than this distance. 0 turns it off."] = true
L["Dynamic Pitch"] = true
L["Dynamically tilt the camera up and down as you move it."] = true
L["Pitch Strength"] = true
L["How far Dynamic Pitch tilts the camera. Lower values keep your character higher on screen. Flying tilts further and scales with this."] =
  true
L["Shoulder Offset"] = true
L["Camera's horizontal position relative to the character."] = true
L["Disable Offset With Mouselook"] = true
L["Shoulder Offset eases to 0 when disabling Mouse Look."] = true
L["When off, Shoulder Offset stays constant at all times."] = true
L["Swap Shoulder Keybind"] = true
L["Press to mirror Shoulder Offset to the other side of your character."] = true
L["Extra functionalities tied to Mouse Look behaviour."] = true
L["Cursor Pulse"] = true
L["Flash the cursor when Mouse Look is turned off."] = true
L["Hide Tooltips"] = true
L["Hide tooltips while Mouse Look is on, unless the key below is held."] = true
L["Show Tooltips With"] = true
L["Hold this key to show tooltips while Mouse Look is on."] = true
L["Auto Sheath"] = true
L["Sheath weapons automatically with Mouse Look."] = true
L["Vignette Shows When"] = true
L["Darkens the edges of the screen while the checked situations are true."] = true
L["Vignette Match"] = true
L["Any: one checked situation is enough. All: every checked situation must be true at once."] = true

-- TabReticleTargeting.lua: Reticle Targeting tab
L["Any Hard Target"] = true
L["Locked Target Only"] = true
L["Soft Target (Blizzard)"] = true
L["Hidden"] = true
L["Toggle"] = true
L["Switch Target"] = true
L["A UI Reload is required when making this change. Proceed?"] = true
L["Create New Macro"] = true
L["Write a macro that starts with your Reticle Targeting preline."] = true
L["Unavailable in combat."] = true
L["Drag to a button on your action bars to use."] = true
L["Right-click to edit"] = true
L["+%d more in /macro"] = true
L["Reticle Targeting Macros"] = true
L["Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."] =
  true
L["Reticle Targeting"] = true
L["RETICLE TARGETING"] = true
L["Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."] =
  true
L["Enable Reticle Targeting"] = true
L["Aim the crosshair at units to pick targets instead of tab-targeting."] = true
L["Ignore Friendlies"] = true
L["Ignore friendly NPCs and Players, and only target hostile units."] = true
L["Click Casting Only"] = true
L["Apply reticle targeting logic only to Click Casting binds."] = true
L["Excluded Spells"] = true
L["Spells to skip the reticle targeting logic."] = true
L["Cast at Crosshair"] = true
L["Ground spells to cast at the crosshair location."] = true
L["TARGET LOCK"] = true
L["Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies."] =
  true
L["Warning: Target Lock uses your Focus Target. Anything else that sets your focus will interfere with it."] =
  true
L["Target Lock Keybind"] = true
L["Lock the reticle to a target, preventing it from swapping."] = true
L["Cycle Lock - Next"] = true
L["Move Target Lock to the next valid nearby target."] = true
L["Cycle Lock - Previous"] = true
L["Move Target Lock to the previous valid nearby target."] = true
L["Target Lock Behavior"] = true
L["What the Target Lock key does when you press it."] = true
L["Locks your target, or the unit under the crosshair. Tap again to unlock."] = true
L["Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock."] =
  true
L["With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is."] =
  true
L["Auto Target Lock"] = true
L["Target Lock engages automatically when attacking units."] = true
L["Target Lock Marker"] = true
L["Show a crosshair marker on the nameplate of the locked target."] = true
L["Focus Locked Target"] = true
L["Pulls the camera toward your locked target, keeping it in focus."] = true
L["TARGETING INDICATORS"] = true
L["Visual indicators that highlight targets in the world for easier identification."] = true
L["Target Outline"] = true
L["Show an outline effect on your target."] = true
L["Only available on Retail"] = true
L["Selection Circle"] = true
L["Which target gets Blizzard's selection circle underneath their feet."] = true
L["The circle under whatever you have targeted, enemy or friendly."] = true
L["The circle only under your Target Lock."] = true
L["Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused."] = true
L["Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account."] =
  true
L["No selection circle."] = true

-- TabCrosshair.lua: Crosshair tab
L["Crosshair"] = true
L["CROSSHAIR"] = true
L["A dynamic crosshair that reacts to targets and combat states, enhancing precision and guiding Reticle Targeting."] =
  true
L["Enable Crosshair"] = true
L["While in Mouse Look, display a dynamic & reactive crosshair on your screen."] = true
L["Cast Feedback"] = true
L["Crosshair provides visual feedback while casting."] = true
L["Appearance"] = true
L["Textures utilized by the crosshair for each state. Click one to pick its texture, or start from a preset."] =
  true
L["Inactive"] = true
L["Active"] = true
L["Mounted"] = true
L["Disabled"] = true
L["Reaction Colors"] = true
L["Edit"] = true
L["Customize the colors used by the crosshair when targeting different types of units."] = true
L["Scale"] = true
L["Scales the size of the crosshair."] = true
L["Vertical Position"] = true
L["Move the crosshair up or down from screen center."] = true
L["ASSIST HUD"] = true
L["A HUD that guides spell rotation when targeting enemies and displays interaction prompts."] =
  true
L["Next-cast Suggestion"] = true
L["Show the Assisted Highlight's next-cast suggestion while aiming at a target."] = true
L["Always"] = true
L["Only In Combat"] = true
L["Interactable Indicator"] = true
L["Show an indicator while aiming at an interactable unit or object."] = true
L["Player Interaction Prompt"] = true
L["Show an indicator while aiming at a player for one second. Pressing the Interact Key opens their context menu."] =
  true
L["Position"] = true
L["Which side of the crosshair the HUD appears on."] = true
L["Left"] = true
L["Right"] = true
L["Scales the size of the HUD."] = true
L["Distance"] = true
L["Distance between the HUD and the crosshair."] = true

-- TabClickCasting.lua: Click Casting tab
L["Action Combat Mode"] = true
L["Modified Blizzard Actions"] = true
L["Blizzard Actions"] = true
L["Base"] = true
L["Shift"] = true
L["Ctrl"] = true
L["Alt"] = true
L["Clear Target"] = true
L["Clear Focus"] = true
L["Start Attack"] = true
L["Pet Attack"] = true
L["Toggle Focus Any"] = true
L["Toggle Focus Enemy"] = true
L["Run MACRO"] = true
L["— none —"] = true
L["Override this click during Mouse Look."] = true
L["Action"] = true
L["Macro"] = true
L["Select a macro"] = true
L["No targeting"] = true
L["Left Click"] = true
L["Right Click"] = true
L["Shift + Left Click"] = true
L["Shift + Right Click"] = true
L["Ctrl + Left Click"] = true
L["Ctrl + Right Click"] = true
L["Alt + Left Click"] = true
L["Alt + Right Click"] = true
L["Click Casting"] = true
L["CLICK CASTING"] = true
L["Assign override actions to left and right clicks that are active during Mouse Look."] = true
L["Account-Wide Binds"] = true
L["Share Click Casting binds across all characters."] = true
L["Click Binds"] = true
L["Base, Shift, Ctrl and Alt each have their own Left and Right Click actions."] = true
