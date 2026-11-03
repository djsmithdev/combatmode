---
name: release
description: Prepare an addon release on develop — version bump, dated changelog section and compare links, release gate, then the develop → master PR whose merge publishes automatically. Only when the user asks to ship or finalize a version.
disable-model-invocation: true
---

# Release

Merging a `develop → master` PR publishes the release. `.github/workflows/release.yml` sees a TOC `## Version` with no tag yet, creates the tag + GitHub release (notes = that changelog section, via `scripts/changelog-section.py`), packages with the BigWigs packager (CurseForge, Wago, zip on the GitHub release), then posts to Discord. Nobody tags or creates releases by hand. Ask before every commit, push and PR.

## 1. Prepare on `develop`

1. Pick the SemVer bump with the user. Set `## Version` in `CombatMode/CombatMode.toc`.
2. In `CombatMode/CHANGELOG.md`, give the current section its version and date (`## [x.y.z] - YYYY-MM-DD`), add `[x.y.z]: https://github.com/ThericGames/combatmode/compare/<previous>...x.y.z` at the bottom and move `[Unreleased]` to compare from `x.y.z`. The hook syncs `ChangelogData.lua`.
3. TOC sanity:
   - `## Interface` lists the current Mainline, Forever and Classic builds (comma-delimited, so each client accepts the unsuffixed TOC);
   - keep the `## Interface-{Forever,Mists,Cata,Titan,Wrath,BCC,Classic}` lines so the packager tags those flavors; never add `-g retail` to `release-package.yml` (that uploads Mainline only);
   - Title / Notes / `X-Wago-ID` are still right.
4. Verify changed WoW APIs/events with the `wow-api` MCP (`list_deprecated` too).
5. Gate: `pwsh ./scripts/check-repo.ps1 -Release` (version newer than the latest tag, dated section, compare link, sync, load order, LICENSE copies identical, TGAs) and `pre-commit run --all-files`.

## 2. Release PR

1. Commit on `develop` (`chore: release x.y.z`), push, then `gh pr create --repo ThericGames/combatmode --base master --head develop --title "chore: release x.y.z"`. Body: the changelog section, then a **Player impact** list (bindings, CVars, settings migrations, removed options) and the in-game areas to smoke test (`/ingame-test` on `git diff <last tag>...develop`).
2. CI runs the same gate (`release-gate` job). Merge with a **merge commit** (not squash) so `develop` and `master` don't diverge.

## 3. After the merge

- `gh run list --workflow release.yml --repo ThericGames/combatmode`: release, package and discord jobs green.
- The GitHub release has `CombatMode-x.y.z.zip`; new files on [CurseForge](https://www.curseforge.com/wow/addons/combat-mode) and [Wago](https://addons.wago.io/addons/combat-mode).
- Rerun a failed step with the **Release Package** / **Discord Release Notification** workflow's *Run workflow* button (tag input).

## Setup reference

- Secrets: `CF_API_KEY` (CurseForge), `WAGO_API_TOKEN` (Wago), `DISCORD_WEBHOOK_URL`. Variables: `CURSEFORGE_PROJECT_ID`, `WAGO_PROJECT_ID` (also `## X-Wago-ID` in the TOC).
- The packager runs with `-t CombatMode -m .pkgmeta`: only `CombatMode/` ships. `LICENSE` exists at the root (GitHub sidebar) and in `CombatMode/` (shipped); `check-repo` keeps them identical. GitHub's "Source code" archives are not addon-ready; the workflow zip is.
