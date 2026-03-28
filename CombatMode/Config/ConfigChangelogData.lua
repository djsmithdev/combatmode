---------------------------------------------------------------------------------------
--  Config/ConfigChangelogData.lua - changelog body for in-game viewer
--  Regenerate from CHANGELOG.md:  scripts\sync-changelog-to-lua.ps1
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

CM.Config = CM.Config or {}
CM.Config.ChangelogText = [[
# Changelog

All notable changes to this project will be documented in this file.

This log follows Keep a Changelog (https://keepachangelog.com/en/1.1.0/) and Semantic Versioning (https://semver.org/spec/v2.0.0.html).

## [3.2.2] - 2026-03-28

### Added

- Changelog popup on first login after updating the addon.

## [3.2.1] - 2026-03-27

### Fixed

- Cast @cursor whitelist not applying correctly.

## [3.2.0] - 2026-03-27

### Added

- Reticle Targeting CVar editor: customize the CVars Combat Mode uses for Reticle Targeting.
- Targeting macro prelines editor: customize macro prelines injected into actions when Reticle Targeting is enabled.

## [3.1.10] - 2026-03-26

### Added

- Explicit third-party action bar policy: when Bartender4, Dominos, or ElvUI is detected, Combat Mode forces `macroInjectionClickCastOnly=true` and locks that toggle; Blizzard default bars keep full reticle targeting macro injection.

## [3.1.9] - 2026-03-26

### Changed

- Refactored action bar binding overrides: canonical action-slot id is derived from the binding prefix and button index instead of `MultiBar*ButtonN` frames, whose `action` attribute can be ambiguous with Bartender4, Dominos, ElvUI, and similar addons.
- Code cleanup.

## [3.1.8] - 2026-03-25

### Fixed

- Reticle Targeting with ElvUI and Bartender4.

## [3.1.7] - 2026-03-24

### Fixed

- Sticky crosshair table name.

## [3.1.6] - 2026-03-24

### Added

- GitHub package release workflow.

### Changed

- Code cleanup.

## [3.1.5] - 2026-03-23

### Changed

- Cursor freelook centring is tied to the Crosshair being active, not Reticle Targeting.
- Crosshair reactivity no longer requires Reticle Targeting.
- Interaction HUD range check adjusted.

Together, these updates allow using the Crosshair and Interaction HUD independently of Reticle Targeting configuration.

## [3.1.4] - 2026-03-23

### Changed

- Performance improvements.
- Split `Constants.lua` into smaller files under `/Constants`.

## [3.1.3] - 2026-03-23

### Fixed

- Interaction HUD errors from secret values in dungeons.

### Changed

- Interaction HUD and Healing Radial fonts are no longer tied to a specific client language.
- Updated LibEditMode.

## [3.1.2] - 2026-03-22

### Added

- LibEditMode in the `Libs` folder.

## [3.1.1] - 2026-03-22

### Added

- Edit Mode support: adjust the Crosshair from Blizzard’s Edit Mode.
- Interaction HUD option for the crosshair: shows interactable NPCs and objects to the right of the crosshair when enabled.

### Changed

- Crosshair vertical positioning limit removed.
- Crosshair behavior aligns more closely with config options, including more reliable cursor centring.
- Reorganized project structure into smaller, easier-to-maintain files.

### Fixed

- Reticle Targeting blacklist not excluding spells from targeting macro injection, which broke Hold To Cast and empowered spell options (e.g. Hold & Release). Excluding a spell by name on the list now restores expected behavior.
]]
