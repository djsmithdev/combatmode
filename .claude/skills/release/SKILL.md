---
name: release
description: Prepare an addon release — version/changelog match, changelog sync, full lint, release notes. Only when the user asks to ship or finalize a version.
disable-model-invocation: true
---

# Release prep

Canonical procedure is `RELEASE.md`; smoke tests are `TESTING.md`. Read `RELEASE.md` first, then:

1. Confirm `## Version` in `CombatMode/CombatMode.toc` matches the newest `## [x.y.z] - date` section in `CombatMode/CHANGELOG.md` (and the compare links at the bottom).
2. `pwsh ./scripts/sync-changelog-to-lua.ps1`.
3. Full lint gate: `pre-commit run --all-files`.
4. Verify changed WoW APIs/events with the `wow-api` MCP before finalizing notes.
5. Call out player-impacting changes in the notes: bindings, CVars, settings migrations, removed options.
6. List the `TESTING.md` sections the release touches. Do not tag, push, create the GitHub release or commit without explicit approval; the GitHub release triggers packaging and Discord workflows.
