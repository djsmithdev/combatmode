---
name: finish-change
description: Finish a code change in the addon — validate WoW API use, combat/secret safety, lint twice, sync docs/headers, then ask about a version bump. Use after editing CombatMode/**.lua.
---

# Finish a code change

Run in order; skip steps that don't apply (e.g. pure docs edits skip 1-2 and 5).

1. **API check** — verify every changed/new WoW API, event, enum with the `wow-api` MCP (`lookup_api`, `get_event`, `get_enum`, `list_deprecated`). Say so if the MCP is unavailable.
2. **Safety review** (see `.claude/rules/lua-safety.md`):
   - protected calls guarded by `InCombatLockdown()`; lockdown-blocked refreshes queued and flushed on `PLAYER_REGEN_ENABLED`;
   - no compare/branch/length/concat on possibly secret values;
   - enable/apply has a matching disable/cleanup (mouselook, CVars, bindings, overrides);
   - new setting has a default, the right DB scope (`global` vs `char`) and an options control.
3. **Regression pass** — name the slash commands, keybind flows and runtime path touched by the change, and the matching `TESTING.md` section to run in game.
4. **Lint** — `pwsh ./scripts/lint-changed.ps1`, **twice** (first run reformats with StyLua). Fix Selene findings (unused locals, declaration order).
5. **Docs/headers** — edited Lua files keep the standard header; ownership/load-order moves update `Embeds.xml`, `STRUCTURE.md`, the matching `.claude/rules/domain-*.md`. Standalone editors register in `Embeds.xml` after the `UI/Options` toolkit.
6. **Version/changelog — ask first.** Don't bump the TOC, edit `CHANGELOG.md` or run the sync script unless the user agrees; then use the `changelog` skill. Never commit unless asked.

Report what was verified and what still needs an in-game check.
