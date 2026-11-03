# Action Combat Mode (WoW addon)

Action-combat controls for World of Warcraft: Mouse Look + a reticle replace tab-targeting. Player-facing name is **"Action Combat Mode"**; folder, SavedVariables, binding names and internal IDs stay **"Combat Mode"** (`CombatMode/`, `CombatModeDB`, `CM`). Retail Mainline (Midnight, 12.x) is the primary target; the TOC also lists Classic/Era/Forever clients. Lua 5.1, no build step.

## What's where

- `CombatMode/` is the addon. Everything else (docs, `scripts/`, `.github/`) is repo tooling and never ships.
- Domains: **FreeLook** (Mouse Look, auto cursor unlock, flip camera) · **Crosshair** (reticle, Assist/Interact HUD, Target Lock marker) · **ClickCasting** (mouse/key override bindings, Reticle Targeting "prelines", composed macros) · **AllyCycle** (secure party/raid cycle + HUD) · **RadialMenu** (Radial Menu + Party Wheel) · **Options/Wizard UI** (standalone window, not Blizzard settings).
- Load order: `CombatMode/Embeds.xml` + `STRUCTURE.md`. Events: `Constants/Gameplay.lua` (`BLIZZARD_EVENTS`) → `Core/Runtime/EventRouter.lua`. Settings: `Constants/DatabaseDefaults.lua` (+ `CM.DB.global` vs `CM.DB.char`) and `UI/Options/Tabs/Tab*.lua`.
- Ownership/gotchas per module: the Lua file header first, then `.claude/rules/domain-*.md` (auto-loaded when you touch that folder).
- In-game test plans: `/ingame-test` (from the diff + each domain note's **In-game checks** line). There is no manual test doc.
- Repo tooling: `scripts/` (checks, changelog sync, hooks), `scripts/art/` (TGA compression, wizard / README preview builders, crosshair pack import), `.github/` (CI, release automation, templates).
- `CombatMode/CHANGELOG.md` is long: read only the top (`head -80`). `UI/Changelog/ChangelogData.lua` is generated; never edit or read it.

## Three concepts behind most bugs

1. **Combat lockdown / secure code:** secure frame attributes and bindings can't change in combat; queue and flush on `PLAYER_REGEN_ENABLED`. Secure snippets run in a restricted environment with very few APIs.
2. **Secret values (Mainline):** never compare/branch on possibly secret units, GUIDs, health, names (`issecretvalue`, `PublicBool`, `PublicNumber`). Details: `.claude/rules/lua-safety.md`.
3. **Reticle Targeting injects a targeting preline into bound actions via `/click`;** macros can't click other macros, so raw macro actions skip it unless composed (`ComposedMacros`).

## Commands

- `pwsh ./scripts/lint-changed.ps1` — StyLua + Selene + `check-repo` on changed Lua. **Run it twice** (the first run reformats). `scripts/dev-check.ps1` checks the toolchain against the versions CI pins.
- `pwsh ./scripts/check-repo.ps1 [-Release]` — changelog sync, TOC vs changelog version, `Embeds.xml` load order, LICENSE copies, TGA compression (`-Release`: version newer than the last tag, dated section, compare link).
- Edit/Write hook (`scripts/claude-post-edit-hook.ps1`): StyLua on edited addon Lua, and `CHANGELOG.md` edits regenerate `ChangelogData.lua`. Run `pwsh ./scripts/sync-changelog-to-lua.ps1` yourself only when you changed the changelog another way.

## Branches and CI

- Work lands on `develop` through PRs to `ThericGames/combatmode` (`/open-pr`); a `develop → master` PR is a release (`/release`), and merging it tags, packages and announces automatically (`release.yml`). Never tag or create GitHub releases by hand.
- Every PR runs `ci` (pre-commit: StyLua, Selene, `check-repo`; plus `check-repo -Release` into master), a Conventional Commits title check and path labels.

## Working agreements

- **Ask before** committing, bumping `## Version` in the TOC, pushing, or posting to GitHub. Changelog entries go in the current version section. Recipes: `/finish-change`, `/changelog`, `/open-pr`, `/release`, `/new-option`, `/new-module`. Audits: `/secret-audit`, `/secure-audit`. Test plan: `/ingame-test`.
- **WoW API facts:** `wow-api` MCP first (`lookup_api`, `get_event`, `get_enum`, `list_deprecated`…), then existing code, then Blizzard's UI source (`https://github.com/Gethe/wow-ui-source`: default frame/template/mixin behavior; branches `live`, `ptr`, `beta` for patch diffs, `forever`, `classic`, `classic_era` for the other clients), then warcraft.wiki.gg. Say so if the MCP is down.
- **Headers:** every edited/new `CombatMode/**.lua` keeps the header: `Path/File.lua — DOMAIN — title`, then *What it does / Architecture / Does not / Related*.
- **Architecture moves** (rename, move responsibility, load order) update `Embeds.xml`, `STRUCTURE.md`, the matching `domain-*.md` and the touched headers in the same change. Prefer API-preserving moves.
- Keep edits in the owning module; extend existing `CM.*` APIs; preserve slash commands and keybinds unless asked.
- Use "Action Combat Mode" in anything a player reads.

## Pitfalls

- Source files are CRLF where they were created on Windows: use the Edit tool (or a script that preserves line endings). Shell heredocs/`sed` mangle backslashes in Lua path strings (`Interface\AddOns\...`).
- Don't name addon-created macros with a `CM_` prefix (`RemoveLegacyMacros` deletes them).
- Shipped art is TGA under `CombatMode/Assets/`; never `SetAtlas` a client atlas for addon art (use `CM.SetAtlas`). Run `python scripts/art/compress-tga.py` after adding or re-exporting a TGA (lossless RLE, idempotent, verifies pixels).
