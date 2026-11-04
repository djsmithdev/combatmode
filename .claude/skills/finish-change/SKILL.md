---
name: finish-change
description: Finish a code change in the addon — validate WoW API use, combat/secret safety, lint twice, run the repo checks, sync docs/headers, then ask about a version bump. Use after editing CombatMode/**.lua.
---

# Finish a code change

Run in order; skip steps that don't apply (e.g. pure docs edits skip 1-3).

1. **API check** — verify every changed/new WoW API, event, enum with the `wow-api` MCP (`lookup_api`, `get_event`, `get_enum`, `list_deprecated`). Say so if the MCP is unavailable.
2. **Safety review** (see `.claude/rules/lua-safety.md`; run `/secret-audit` / `/secure-audit` when the change touches unit data or bindings / secure frames):
   - protected calls guarded by `InCombatLockdown()`; lockdown-blocked refreshes queued and flushed on `PLAYER_REGEN_ENABLED`;
   - no compare/branch/length/concat on possibly secret values;
   - enable/apply has a matching disable/cleanup (mouselook, CVars, bindings, overrides);
   - new setting has a default, the right DB scope (`global` vs `char`) and an options control.
3. **Test plan** — run `/ingame-test` for the in-game checklist.
4. **Lint + repo checks** — `pwsh ./scripts/lint-changed.ps1`, **twice** (first run reformats with StyLua; it also runs `check-repo`: changelog sync, TOC/changelog version, `Embeds.xml` load order, LICENSE, TGA compression). Fix Selene findings (unused locals, declaration order) and any `[FAIL]`.
4b. **Locale sync** — if the change added, changed or removed player-facing text, confirm every `L["..."]` it touches is in `Locales/enUS.lua` and in all ten other locale files (see `.claude/rules/localization.md`); `check-repo` reports gaps. No raw English literals or concatenated sentences left behind.
5. **Docs/headers** — edited Lua files keep the standard header; ownership/load-order moves update `Embeds.xml`, `STRUCTURE.md`, the matching `.claude/rules/domain-*.md`. Standalone editors register in `Embeds.xml` after the `UI/Options` toolkit.
6. **Version/changelog — ask first.** Don't bump the TOC or edit `CHANGELOG.md` unless the user agrees; then use the `changelog` skill. Never commit unless asked; when the user says to, commit on `develop` (Conventional Commits title, only this change's files) and push it directly, no branch or PR.

Report what was verified and what still needs an in-game check.
