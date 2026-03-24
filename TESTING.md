# CombatMode Manual Testing

Use this checklist for feature work and regressions.

## Setup

- Use Retail client with addon enabled and fresh `/reload`.
- Confirm `CombatModeDB` loads and settings panel opens (`/cm`).
- If testing bindings, verify keybinds are set as expected.
- For API-sensitive changes, verify WoW API/event signatures via MCP tools first (or manual fallback in `RELEASE.md`).

## Core and mouselook

- Toggle CombatMode on/off and verify mouselook enters/exits correctly.
- Verify no stuck mouselook after opening/closing common UI panels.
- Test transitions in and out of combat; no protected-action errors.

## Reticle and targeting CVars

- Enable/disable reticle-related settings and confirm visual/state updates.
- Confirm targeted CVars change only when feature requires it.
- Disable feature and ensure CVars/state restore path behaves correctly.

## Click casting

- Validate base click-cast actions on valid units.
- Validate modifier variants (Shift/Ctrl/Alt) map to expected spells/macros.
- Verify behavior remains stable in combat (no insecure action taint/errors).

## Cursor unlock and pulse

- Trigger configured unlock conditions (UI panels/custom Lua if applicable).
- Confirm mouselook unlocks when expected and relocks when expected.
- Confirm pulse appears after unlock and does not persist unexpectedly.

## Healing radial

- Open/close radial menu through configured keybind/toggle flow.
- Cast valid spells from radial targets and verify target routing.
- Check combat behavior for secure restrictions and graceful fallback.

## Config and persistence

- Change options in each category and verify immediate apply/refresh behavior.
- Reload UI and confirm saved values persist in correct scope.
- Test reset/default paths and ensure no stale state remains.

## Quick regression pass

- Slash commands: `/cm`, `/combatmode`, `/undocm`.
- Keybinds still function after reload and after disabling/re-enabling addon.
- No Lua errors in normal use paths for edited features.
- If keybind writes were changed, verify in-combat changes defer and apply automatically after leaving combat.
- For contributor lint/format checks, use helper by default: `pwsh ./scripts/lint-changed.ps1`.
- Equivalent direct gate: `pre-commit run --files <changed files>`.
- Reserve full-repo gate for release prep: `pre-commit run --all-files`.
