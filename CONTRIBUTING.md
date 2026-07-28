# Contributing to CombatMode

Use this guide for day-to-day contributor workflow.

## Prerequisites

- `stylua`
- `selene`
- `pre-commit`
- WoW API MCP access is preferred for API validation (manual fallback is acceptable when MCP is unavailable)
- Script index helper: `pwsh ./scripts/help.ps1`

## Default local workflow

1. Make your code changes.
2. **Lint:**
   - Preferred: `pwsh ./scripts/lint-changed.ps1`
   - Equivalent: `pre-commit run --files <changed files>`
3. **Version + changelog (when ready to bump):** agents ask before doing this; humans can wait until shipping a version or preparing a PR that should bump.
   - Bump `## Version` in `CombatMode/CombatMode.toc` (SemVer).
   - Update `CombatMode/CHANGELOG.md` (Keep a Changelog; match TOC version).
   - Run `pwsh ./scripts/sync-changelog-to-lua.ps1` so `CombatMode/UI/Changelog/ChangelogData.lua` matches the in-game viewer.
4. Run focused runtime checks from `TESTING.md` for touched features.
5. Open your PR.

## When to run full-repo checks

Use full sweep only for release prep or explicit maintainer request:

- `pre-commit run --all-files`

## API validation policy

- MCP-first for changed WoW APIs/events:
  - `lookup_api`, `list_deprecated`, `get_event`, `get_enum`
- Manual fallback:
  - verify changes against Warcraft Wiki API docs and event payload docs

## PR minimum checklist

- Changed-files lint passes (`lint-changed.ps1` / pre-commit).
- If this PR bumps a version: TOC, `CHANGELOG.md`, and changelog sync script are all updated together.
- Feature behavior verified with focused testing (`TESTING.md`).
- Any process/rule/documentation updates included when workflow/architecture changed.
