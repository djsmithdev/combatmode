# Contributing to Action Combat Mode

Pull requests are welcome. This page covers setup and the PR flow; the architecture and coding rules live in [CLAUDE.md](CLAUDE.md), [`.claude/rules/`](.claude/rules/) and [STRUCTURE.md](STRUCTURE.md) (written for [Claude Code](https://claude.com/claude-code), but meant for people too).

## Setup

1. Clone the repo and link (or copy) `CombatMode/` into your `World of Warcraft/_retail_/Interface/AddOns/` folder.
2. Install [StyLua](https://github.com/JohnnyMorganz/StyLua), [Selene](https://github.com/Kampfkarren/selene), [PowerShell 7](https://github.com/PowerShell/PowerShell) (`pwsh`), Python 3 and [pre-commit](https://pre-commit.com) (`pip install pre-commit`).
3. `pre-commit install`, then `pwsh ./scripts/dev-check.ps1` (checks the tools and that StyLua / Selene match the versions CI pins).
4. Optional: the Ketho [WoW API](https://marketplace.visualstudio.com/items?itemName=ketho.wow-api) VS Code extension. It gives Lua completion, and Claude Code's `wow-api` MCP server (`.mcp.json`) reads its annotations.

## Making a change

- Branch from `develop` and open the PR against `develop`. `master` only receives release PRs.
- Keep the change in the module that owns the feature (each Lua file's header says what it owns). New files go in `CombatMode/Embeds.xml` in load order.
- Two rules cause most bugs: nothing protected (bindings, secure attributes) may change in combat, and on Retail many unit values are *secret* and can't be compared. See [`.claude/rules/lua-safety.md`](.claude/rules/lua-safety.md).
- Player-facing changes get an entry in `CombatMode/CHANGELOG.md` under the current version, then `pwsh ./scripts/sync-changelog-to-lua.ps1` (the in-game changelog reads the generated `ChangelogData.lua`).
- Before pushing: `pwsh ./scripts/lint-changed.ps1` (run it twice; the first run reformats).

## Pull requests

- **Title:** [Conventional Commits](https://www.conventionalcommits.org), as in the history: `feat: ...`, `fix(crosshair): ...`, `refactor: ...`.
- **Body:** the template asks for a summary, the player impact and what you tested in game.
- **Automatic checks:**
  - `ci`: StyLua, Selene and `scripts/check-repo.ps1`, which covers changelog sync, TOC vs changelog version, `Embeds.xml` load order, LICENSE copies and TGA compression;
  - `pr-title`: the title format;
  - domain labels.

## Translations

Action Combat Mode ships in all 11 WoW locales. The English text is the key (`L["Mouse Look"]`, via `CM.L`), so anything missing from a locale falls back to English.

- **Fix or improve a translation:** edit the matching `CombatMode/Locales/<locale>.lua` (`L["English text"] = "Translation"`) and open a PR, or file a [translation issue](https://github.com/ThericGames/combatmode/issues/new/choose). The non-English files are machine-drafted, so native-speaker review is very welcome.
- **Keep** `%s` / `%d`, colour codes (`|cffxxxxxx...|r`, `|n`) and the name "Action Combat Mode" exactly as in English. Don't use a plain `"` inside a translation.
- **Adding or changing player-facing text in code:** wrap it in `L["..."]`, add the key to `Locales/enUS.lua` and a translation to all ten other locale files in the same change. `check-repo` fails on a missing or stale key. Details: [`.claude/rules/localization.md`](.claude/rules/localization.md).

## Releases (maintainers)

Bump `## Version` in `CombatMode/CombatMode.toc`, date the changelog section and add its compare link on `develop`, then merge a `develop → master` PR with a merge commit. `.github/workflows/release.yml` tags the version, creates the GitHub release, packages to CurseForge / Wago and posts to Discord. In Claude Code, ask it to release and it walks through this.
