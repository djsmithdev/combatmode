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
2. Run lint/format on changed files:
   - `pre-commit run --files <changed files>`
3. Run focused runtime checks from `TESTING.md` for touched features.
4. Open your PR.

## When to run full-repo checks

Use full sweep only for release prep or explicit maintainer request:

- `pre-commit run --all-files`

## API validation policy

- MCP-first for changed WoW APIs/events:
  - `lookup_api`, `list_deprecated`, `get_event`, `get_enum`
- Manual fallback:
  - verify changes against Warcraft Wiki API docs and event payload docs

## PR minimum checklist

- Changed-files pre-commit checks pass.
- Feature behavior verified with focused testing (`TESTING.md`).
- Any process/rule/documentation updates included when workflow/architecture changed.
- If you change **`CombatMode/CHANGELOG.md`**, run **`scripts/sync-changelog-to-lua.ps1`** so **`CombatMode/Config/ConfigChangelogData.lua`** matches the in-game changelog (or note in the PR if intentionally deferred).
