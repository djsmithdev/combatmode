# Claude / multi-tool entry

Layered context for Claude Code and similar agents. **Cursor-specific rules** remain in `.cursor/rules/*.mdc`; this file composes portable `.context/` docs and points to the full playbook.

@.context/project.md
@.context/api.md
@.context/patterns.md

Also read **`AGENTS.md`** for the rule map, project map, and finish checklist (authoritative for this repo).

## Evidence

Do not ship behavior changes based on memory alone. Confirm WoW API usage with MCP tools or project code; cite or point to the defining module when changing runtime behavior.

## Pattern learning

When you discover a durable pattern (debugging technique, API workaround, architecture decision), add a short entry to `.context/patterns.md` (or extend the linked `.cursor/rules` notes if that is more appropriate). Prefer one source of truth—avoid duplicating long policy text.

## Finish requirements

Match **`AGENTS.md`** and `.cursor/rules/combatmode-change-checklist.mdc`:

1. No combat-unsafe paths; enable/disable symmetry for mouselook/CVars/bindings when touched.
2. **Lint first:** `pwsh ./scripts/lint-changed.ps1` (or `pre-commit run --files <changed lua files>`).
3. **After code changes** (not pure docs/rules-only): bump `## Version` in `CombatMode/CombatMode.toc`, update `CombatMode/CHANGELOG.md` (Keep a Changelog), then run `pwsh ./scripts/sync-changelog-to-lua.ps1` so `UI/Changelog/ChangelogData.lua` stays in sync.
