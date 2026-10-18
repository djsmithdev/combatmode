---
name: changelog
description: Add or edit a CombatMode/CHANGELOG.md entry in house style and sync it to the in-game viewer. Use when the user asks for a changelog entry or after they approve one.
---

# Changelog entry

1. Read only the top of `CombatMode/CHANGELOG.md` (`head -60`) to find the current version section (it must match `## Version` in `CombatMode/CombatMode.toc`) and copy its tone.
2. Add the entry under the right Keep a Changelog heading (`Added` / `Changed` / `Deprecated` / `Removed` / `Fixed` / `Security`) in that section. Player-facing wording: say what the player sees, use "Action Combat Mode", bold the option or feature name, no internal function or file names.
3. Run `pwsh ./scripts/sync-changelog-to-lua.ps1` so `UI/Changelog/ChangelogData.lua` matches. Never edit that file by hand.
4. Don't bump the version, create a new section or commit unless the user asked. A new version also needs the compare links at the bottom of the changelog refreshed.
