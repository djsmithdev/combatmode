## Summary

- Describe the user-visible change.
- Describe key technical/runtime changes.

## Validation

- [ ] Manual tests run from `TESTING.md` for changed areas.
- [ ] No combat-lockdown/protected-action regressions introduced.
- [ ] Keybind/mouselook/cvar state transitions verified after `/reload`.

## WoW API checks

- [ ] MCP checks run (`lookup_api` / `get_event` / `list_deprecated`) for changed APIs/events.
- [ ] If MCP unavailable, manual fallback checks run from `RELEASE.md`.

## Scope and safety

- [ ] Change stays within owning module(s); no vendored `CombatMode/Libs/**` edits.
- [ ] New settings/defaults use intentional DB scope (`global` vs `char`).
- [ ] Any load-order-sensitive files were added to `Embeds.xml`.
