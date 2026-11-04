---
name: ingame-test
description: Turn the current diff into a short in-game test checklist, listing the assumptions that can only be verified on a live client. Use after a code change, before the user tests in WoW, and for the PR test plan.
---

# In-game test checklist

1. `git diff --stat` (staged + unstaged + untracked addon files) and group changed files by domain.
2. For each domain, read the changed code, the touched file headers and the matching `.claude/rules/domain-*.md` (its **In-game checks** line lists the standing regressions for that domain). The `CHANGELOG.md` entry, if any, says what the player should see.
3. Output, kept short:
   - **Must test** — 5-10 concrete steps (what to press/click, what you should see), ordered by risk: combat-lockdown paths first (anything bound or attribute-changing, tested both out of combat and by entering combat mid-step), then instance/secret-value paths (dungeon, raid, M+), then plain UI.
   - **Needs a live client to prove** — assumptions the code can't verify offline: API behavior I inferred but didn't confirm (return values in instances, secret vs public), restricted-environment limits, client differences (Retail vs Classic/Era/Forever), `/reload` persistence of new DB keys.
   - **Other clients pass** — 2-4 steps to repeat on Forever (and a Classic-family client when the change touches client-gated code: `CM.IsRetailClient`, `IS_FOREVER`, atlases, micro buttons, CVars, new APIs or DB keys): the addon loads with no Lua errors, the feature works or is skipped cleanly where that client lacks it, and new settings survive `/reload` (Forever may store flags as `1`/`0`). Skip it, and say so, for changes with no client-specific code.
   - **Locale pass** — only when the diff touches `L["..."]` strings or `Locales/`: on a non-English client (deDE or ruRU, plus zhCN/koKR for glyphs) the changed text shows translated, doesn't clip or overflow, and English-only fallbacks look intentional. Skip it, and say so, otherwise.
   - **Quick regression** — only the domain **In-game checks** items the change can affect.
   - **Debug aids** — Debug Mode starts the Function Profiler, turning it off prints the report (`architecture-and-style.md`), if the change is performance-sensitive.
4. If the change adds a behavior that should be re-checked on every future change in that domain, propose a short addition to that domain's **In-game checks** line; add it only if the user agrees.
5. Don't claim anything passed; this skill only prepares the test plan.
