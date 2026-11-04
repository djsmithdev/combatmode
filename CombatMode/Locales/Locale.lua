---------------------------------------------------------------------------------------
--  Locales/Locale.lua — LOCALES — CM.L string table
---------------------------------------------------------------------------------------
--  What it does: Creates `CM.L`, the table every player-facing string is read through
--  (`local L = CM.L`, then `L["English text"]`). The English text is the key, so a string
--  with no translation falls back to itself and nothing ever shows a blank or a raw ID.
--  Architecture / how it works:
--    • `__index` returns the key for any missing entry (English fallback).
--    • `__newindex` stores `true` as "same as the key" (enUS.lua lists keys that way) and
--      any other value as the translation (xxXX.lua).
--    • Loads right after Constants/Namespace.lua and before every consumer, because
--      Constants/Assets.lua already builds strings at load time.
--    • Each xxXX.lua returns early unless GetLocale() matches, so only one table runs.
--  Does not: Translate anything itself, touch SavedVariables, or translate binding IDs,
--  stored enum values, macro text or the changelog (see .claude/rules/localization.md).
--  Related: Locales/enUS.lua (canonical key list), Locales/xxXX.lua,
--  scripts/check-repo.ps1 (locale sync check), .claude/rules/localization.md
---------------------------------------------------------------------------------------
local _, CM = ...

local rawset = rawset

CM.L = setmetatable({}, {
  __index = function(_, key)
    return key
  end,
  __newindex = function(t, key, value)
    if value == true then
      rawset(t, key, key)
    elseif type(value) == "string" then
      rawset(t, key, value)
    end
  end,
})
