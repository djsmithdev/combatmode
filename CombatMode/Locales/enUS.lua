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
