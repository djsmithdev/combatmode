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
