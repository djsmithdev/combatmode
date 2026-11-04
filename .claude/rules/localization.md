# Localization

Applies whenever you touch `CombatMode/**/*.lua` or `CombatMode/Locales/`. **Any new, changed or removed player-facing text updates every locale file in the same change.** `check-repo` fails CI otherwise.

## How it works

- `CM.L` (`Locales/Locale.lua`): English text is the key. `local L = CM.L` (per-file alias, after `local _, CM = ...`), then `L["Mouse Look"]`. A missing entry returns the key, so English is the fallback.
- `Locales/enUS.lua` is the canonical key list: `L["English text"] = true`. The other ten files (deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW) hold `L["English text"] = "Translation"` and return early unless `GetLocale()` matches.
- Locale files are listed one by one in `Embeds.xml` (the load-order check does not follow nested XML).

## Adding, changing, removing a string

- **Add:** use `L["..."]` in the code, add `L["..."] = true` to `enUS.lua`, and add a translation to **all ten** other files. Group entries under a comment per source file.
- **Change the English text:** that is a new key. Rename it in all 11 files (translate again if the meaning changed).
- **Remove:** delete the key from all 11 files.
- Translations are drafted by Claude: keep `%s` / `%d` (same count, same order unless using `%1$s`), colour codes `|cffxxxxxx...|r`, `|n`, and the name "Action Combat Mode" exactly. Mark nothing as final; files are flagged "machine-drafted".
- Prefer a Blizzard global when one exists (`ALT_KEY`, `CTRL_KEY`, `SHIFT_KEY`, `YES`, `NO`, `CANCEL`, `ACCEPT`, `OKAY`, `DEAD`, `PLAYER_OFFLINE`): the client already localizes it.

## Rules for code

- No raw English literals in anything a player reads (labels, descriptions, tooltips, popups, `print` messages, wizard text, dropdown display text).
- No concatenated sentences. Use one key with placeholders: `string.format(L["Macro names are limited to %d characters."], MAX)`. Avoid plural logic by wording ("Characters: %d / %d").
- A key must be a string literal inside `L["..."]` (the check greps for them). Never build keys dynamically; for tables of display text, list each `L["..."]` literal.
- Do NOT translate: binding IDs (`Combat Mode - ...`), SavedVariables enum values (the stored id, not the dropdown text), macro text and slash tokens, CVar names, composed macro names (user text), debug-only profiler output, the changelog.
- Matching by label (options search, `Options.FindControl` / `FocusSection` from the wizard) compares the translated string, so both sides must read the same `L["..."]`.
- Layout: translations are often 30-50% longer (German, Russian, Portuguese). Don't assume English widths; avoid `SetWordWrap(false)` on translatable text unless clipping is acceptable.
- Case-folding with `string.upper` / `string.lower` is ASCII-only in Lua 5.1; author headers in their final case in the key instead.
- Truncating names by bytes breaks UTF-8 (CJK, Cyrillic): use a UTF-8-aware cut.

**In-game checks:** switch the client to deDE / ruRU / zhCN: no clipped or overflowing text on every options tab, wizard step and popup, no tofu glyphs, wizard spotlight still finds its controls, saved settings and bindings unchanged.
