# CombatMode Manual Testing

Use this checklist for feature work and regressions.

## Setup

- Use Retail client with addon enabled and fresh `/reload`.
- Confirm `CombatModeDB` loads and settings panel opens (`/cm`).
- **Changelog viewer:** open sidebar → **View Changelog**; confirm markdown renders (headings, bullets, links). After a version bump, confirm auto-popup once per version (`lastSeenChangelogVersion` in saved vars). If `CHANGELOG.md` was edited, confirm **`scripts/sync-changelog-to-lua.ps1`** was run so in-game text matches.
- If testing bindings, verify keybinds are set as expected.
- For API-sensitive changes, verify WoW API/event signatures via MCP tools first (or manual fallback in `RELEASE.md`).

## Core and mouselook

- Toggle CombatMode on/off and verify mouselook enters/exits correctly.
- Verify no stuck mouselook after opening/closing common UI panels.
- Test transitions in and out of combat; no protected-action errors.
- **Sheath Weapons with Mouse Look:** rapid Mouse Look toggles (e.g. single-pull) should not flash sheath/unsheath; unsheath on lock remains immediate; temporary unlocks (hold, Party Radial, ground spells, OPie) keep weapons drawn.

## Reticle and targeting CVars

- Enable/disable reticle-related settings and confirm visual/state updates.
- Confirm targeted CVars change only when feature requires it.
- Disable feature and ensure CVars/state restore path behaves correctly.
- Open **Reticle Targeting CVar editor** from Reticle options: filter/sort, double-click edit, reset overrides; reload and confirm `reticleTargetingCVarOverrides` persistence; verify excluded CVars do not appear and external `SetCVar` updates refresh the list where hooked.

## Click casting

- Validate base click-cast actions on valid units.
- Validate modifier variants (Shift/Ctrl/Alt) map to expected spells/macros.
- Verify behavior remains stable in combat (no insecure action taint/errors).
- Binding refresh must not loop when Single-Button Assistant rewrites its action slot.
- Rebinding Mouse Look / Party Radial / Target Lock clears leftover Interact Alt+key chords without a reload.

## Interact key

- Bind Interact to an Alt+mouse chord; bind another action that also uses Alt on a related key. Confirm Interact does **not** become Alt+Alt+key.
- Switching Interact Unit (Crosshair vs Soft Targeted) keeps ALT+key on the other command as intended.

## Target Lock (4.1.3)

- Set Target Lock (focus) via keybind; confirm lock sound (if Target Lock Sound Cues on).
- Clear lock; confirm unlock sound.
- **Mouse wheel cycle** (on by default): with Mouse Look on and a lock set, wheel cycles nearby enemies and moves the lock; without a lock (or Mouse Look off), wheel zooms the camera.
- Cycle to another enemy; confirm cycle sound cue.
- **Nameplate marker:** while locked, center reticle becomes a static Dot; hit marker (Active texture for your Appearance) appears on the locked unit’s nameplate health bar; unlock restores the reactive reticle and clears the marker instantly.
- In a **dungeon/instance**, lock / cycle / unlock with no Lua errors (focus identity may be secret under taint).

## Crosshair cast feedback & Combat Assist

- Cast feedback grow / explode / break (and Assist swipe / cancel break) work in open world.
- Repeat the same in a **dungeon/instance** with no Lua errors from cast GUID compares.
- Rapid Single-Button Assistant presses do not spam Assist cast-success press/pulse animations.
- Assist cast-success does not double-fire from assisted-action + `UNIT_SPELLCAST_SUCCEEDED`.

## Cursor unlock and cursor pulse

- Trigger configured unlock conditions (UI panels/custom Lua if applicable).
- Confirm mouselook unlocks when expected and relocks when expected.
- Confirm pulse appears after unlock and does not persist unexpectedly.

## Party radial

- Open/close radial through the configured keybind (Mouse Look on).
- Cast valid spells from radial targets and verify target routing + hard-target on slice click.
- Center close (X) clears the current target.
- Check combat behavior for secure restrictions and graceful fallback.
- Options → Party Radial tab: live Visual Settings preview (including dead / mind-controlled / low-health role states); no Lua errors on open.
- Role icons: dead uses Disabled atlas; mind-controlled shows fading Decline X; low health shows icon glow; dead health bars are greyed (no glow).

## Config and persistence

- Change options in each category and verify immediate apply/refresh behavior.
- Reload UI and confirm saved values persist in correct scope.
- Test reset/default paths and ensure no stale state remains.
- Uninstall (sidebar): restores prior CVars, resets left/right click camera binds, disables addon, reloads.

## Quick regression pass

- Slash commands: `/cm`, `/combatmode`.
- Keybinds still function after reload and after disabling/re-enabling addon.
- No Lua errors in normal use paths for edited features (especially instances for focus/cast GUID paths).
- If keybind writes were changed, verify in-combat changes defer and apply automatically after leaving combat.
- For contributor lint/format checks, use helper by default: `pwsh ./scripts/lint-changed.ps1`.
- Equivalent direct gate: `pre-commit run --files <changed files>`.
- When bumping a version: update `CombatMode/CombatMode.toc` `## Version`, `CombatMode/CHANGELOG.md`, then `pwsh ./scripts/sync-changelog-to-lua.ps1` (agents ask first — see `AGENTS.md` / change checklist).
- Reserve full-repo gate for release prep: `pre-commit run --all-files`.
