# CombatMode Release Checklist

Use this checklist when preparing a release build.

## 1) Version and metadata

- Update addon version in `CombatMode/CombatMode.toc` (and any mirrored version fields).
- Verify `## Interface` targets current Retail build.
- Confirm addon title/notes/author metadata are accurate.

## 2) API and compatibility checks

- MCP-first (preferred):
  - Validate new/changed WoW API calls (`lookup_api`).
  - Check deprecated APIs and replacements (`list_deprecated`).
  - Confirm enums/events where relevant (`get_enum`, `get_event`).
- Manual fallback (no MCP available):
  - Verify each changed API/event on [warcraft.wiki.gg API docs](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API).
  - Confirm events used in `CM.Constants.BLIZZARD_EVENTS` have correct payload expectations for handlers.
  - Manually review protected-action APIs (`SetBinding`, `SetOverrideBinding*`, `SetMouselookOverrideBinding`, CVar writes) for combat guards/deferred handling.
- Prefer Mainline-safe behavior unless explicitly shipping cross-version logic.

## 3) Load order and packaging sanity

- Confirm `CombatMode/Embeds.xml` load order still matches module dependencies.
- Ensure new files are included in `CombatMode/Embeds.xml` and/or `CombatMode/CombatMode.toc` as needed.
- Verify no accidental dev-only artifacts are referenced.

## 4) Functional smoke test

- Run quick pass from `TESTING.md`:
  - core mouselook toggle/lock/unlock flow
  - reticle + targeting CVar behavior
  - click-casting base/modifier paths
  - healing radial open/cast flow
  - slash commands and keybind sanity
- Confirm no combat-lockdown errors and no new Lua errors.
- If MCP was unavailable during implementation, run an additional manual API spot-check for each changed WoW API call before tagging release.
- Run full lint/format gate for release prep: `pre-commit run --all-files`.

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
