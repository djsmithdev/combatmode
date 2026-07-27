# Project

- **Repository:** treat the GitHub remote for this checkout as canonical when using Git MCP or issue links.
- **Read first:** `README.md` for product intent and user-facing overview.
- **Layout:** the installable addon lives under **`CombatMode/`** (e.g. `CombatMode/CombatMode.toc`), not at the repository root—do not assume a root-level `.toc` like flat single-folder addons.
- **Structure:** `STRUCTURE.md` documents load order and embed wiring.
- **Finish code changes:** lint first (`pwsh ./scripts/lint-changed.ps1`), then bump `CombatMode/CombatMode.toc` `## Version`, update `CombatMode/CHANGELOG.md`, run `pwsh ./scripts/sync-changelog-to-lua.ps1`. Full checklist: `AGENTS.md` and `.cursor/rules/combatmode-change-checklist.mdc`.
