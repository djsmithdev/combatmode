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
