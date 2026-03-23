# CombatMode Release Checklist

Use this checklist when preparing a release build.

## 1) Version and metadata

- Update addon version in `CombatMode.toc` (and any mirrored version fields).
- Verify `## Interface` targets current Retail build.
- Confirm addon title/notes/author metadata are accurate.

## 2) API and compatibility checks

- Validate new/changed WoW API calls via MCP (`lookup_api`).
- Check for deprecated APIs and replacements (`list_deprecated`).
- Confirm updated enums/events where relevant (`get_enum`, `get_event`).
- Prefer Mainline-safe behavior unless explicitly shipping cross-version logic.

## 3) Load order and packaging sanity

- Confirm `Embeds.xml` load order still matches module dependencies.
- Ensure new files are included in `Embeds.xml` and/or `CombatMode.toc` as needed.
- Verify no accidental dev-only artifacts are referenced.

## 4) Functional smoke test

- Run quick pass from `TESTING.md`:
  - core mouselook toggle/lock/unlock flow
  - reticle + targeting CVar behavior
  - click-casting base/modifier paths
  - healing radial open/cast flow
  - slash commands and keybind sanity
- Confirm no combat-lockdown errors and no new Lua errors.

## 5) Settings and persistence

- Verify new settings have defaults and correct DB scope (`global` or `char`).
- Reload UI and ensure values persist and re-apply correctly.
- Confirm reset/default flows remain valid.

## 6) Changelog and release notes

- Summarize user-visible changes first (features/fixes/behavior changes).
- Note any keybind, CVar, or migration-impacting changes explicitly.
- Include known limitations or follow-up items if any.

## Suggested changelog format

```text
## x.y.z
- Feature: ...
- Fix: ...
- Improvement: ...
- Notes: (migrations, known caveats)
```
