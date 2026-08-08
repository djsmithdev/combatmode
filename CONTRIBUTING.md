# Contributing to CombatMode

Use this guide for day-to-day contributor workflow.

## Prerequisites

- `stylua`
- `selene`
- `pre-commit`
- WoW API MCP access is preferred for API validation (manual fallback is acceptable when MCP is unavailable)
- Script index helper: `pwsh ./scripts/help.ps1`

## First-hour path

Start here before large refactors. Prefer the owning module over new files.

### Change a toggle (options → behavior)

1. Find the setting in `CombatMode/UI/Options/Tabs/Tab*.lua` (get/set closures).
2. Confirm the DB key lives in `CombatMode/Constants/DatabaseDefaults.lua` with the right scope (`global` vs `char`).
3. Apply behavior in the **feature module** that owns it (`Core/FreeLook`, `Core/Crosshair`, …) — not in the tab file.
4. If enable/disable touches mouselook, CVars, or bindings: keep **apply ↔ cleanup** symmetric and combat-safe (`InCombatLockdown` / defer).

### Add a constant

1. Put static tables in `CombatMode/Constants/` (the domain file that already owns that concern: Assets, CVars, PartyRadial, …).
2. Consume via `CM.Constants.*` from feature code — avoid magic numbers in hot paths.
3. New files must be listed in `CombatMode/Embeds.xml` **before** their consumers.

### Don’t compare `UnitGUID` (and friends) as truth

Retail can return **secret** values. Comparing them with `==` / using them as table keys / truncating them for display can error or taint.

- Prefer `UnitExists("unit")`, plate identity (`GetNamePlateForUnit`), and `issecretvalue` / `canaccessvalue` / `PublicBool`-style helpers already used in Crosshair / Party Radial / Focus marker.
- Full guardrails: `.cursor/rules/combatmode-lua-safety.mdc` (Secret values section).
- When unsure, look at nearby code in the same module rather than inventing a new pattern.

### Keep docs cold

If you **move**, **rename**, or **re-order** modules:

| Update | Why |
|--------|-----|
| `CombatMode/Embeds.xml` | Load order |
| `STRUCTURE.md` | Human map |
| `.cursor/rules/combatmode-architecture-and-style.mdc` | Agent module map |
| Touched file headers | What this module owns / does not |

Policy: `.cursor/rules/combatmode-docs-and-headers-stay-in-sync.mdc`. Do **not** leave STRUCTURE or headers stale after a move.

## Default local workflow

1. Make your code changes.
2. **Lint:**
   - Preferred: `pwsh ./scripts/lint-changed.ps1`
   - Equivalent: `pre-commit run --files <changed files>`
3. **Version + changelog (when ready to bump):** agents ask before doing this; humans can wait until shipping a version or preparing a PR that should bump.
   - Bump `## Version` in `CombatMode/CombatMode.toc` (SemVer).
   - Update `CombatMode/CHANGELOG.md` (Keep a Changelog; match TOC version).
   - Run `pwsh ./scripts/sync-changelog-to-lua.ps1` so `CombatMode/UI/Changelog/ChangelogData.lua` matches the in-game viewer.
4. **Profile performance (optional):** toggle the Debug Mode ON in the options panel to start the built-in profiler, play your scenario, toggle it OFF to dump the report (see `TESTING.md`).
5. Run focused runtime checks from `TESTING.md` for touched features.
6. Open your PR.

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
- Architecture moves updated Embeds + STRUCTURE + architecture rule + headers (see **Keep docs cold**).
- Any process/rule/documentation updates included when workflow changed.
