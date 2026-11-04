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
