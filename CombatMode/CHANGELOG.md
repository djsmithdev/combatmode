# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.1.1] - 2026-08-01

### Fixed

- Combat Assist no longer plays its cast-success animation twice when using the Single-Button Assistant action (the assisted-action event and `UNIT_SPELLCAST_SUCCEEDED` are coalesced into one).

## [4.1.0] - 2026-07-30

### Added

- Crosshair Cast Feedback: the crosshair grows while channeling, explodes on a successful cast, and shakes on cancel or interrupt.
- Sheath Weapons with Mouse Look (on by default): unsheath when Mouse Look turns on; sheath when it turns off or Auto Cursor Unlock opens a panel. Temporary unlocks (hold, Party Radial, ground spells, OPie) keep weapons drawn.
- Redesigned Combat Assist HUD with improved animations and custom keyboard/mouse icons for Click Casting bindings.
- Redesigned Interaction HUD with Left/Right placement, fixed icon size, and opacity independent of the crosshair opacity slider.
- Redesigned Party Radial with rebuilt health bars, smooth fade in/out, and greyed role icons for dead members.

### Changed

- Combat Assist, Interaction HUD, and Party Radial options streamlined for a fixed, more controllable layout.
- Clicking a Party Radial slice now also hard-targets that party member.
- Clicking the Party Radial center close (X) clears the current target.

### Fixed

- Rebinding Mouse Look, Party Radial, or Target Lock now clears leftover Interact Alt+key chords and refreshes Target Lock overrides immediately (no reload required when stealing a key).

## [4.0.3] - 2026-07-28

### Added

- Character-specific options now show a blue © mark beside the title; hover it for a tooltip explaining they are saved per character.
- Interact Unit option (Crosshair Unit or Soft Targeted Unit) under the Interact keybind; switching units rebinds the key and keeps ALT+key on the other command to avoid Blizzard's interact warning.
- Excluded Spells and Cast at Crosshair input fields under Reticle Targeting now use a pill multi-selector: type a name or ID for suggestions from your spellbook, then pick to add it to the list.

### Changed

- Cast-at-crosshair and excluded-spell lists are stored as spell IDs. Legacy name tokens migrate when the options UI loads.


## [4.0.2] - 2026-07-27

### Added

- Uninstall button in the options sidebar: restores your pre-Combat Mode camera and targeting CVars, resets Left/Right Click to the default camera binds, disables the addon, and reloads.
- Combat Mode now snapshots your CVars before changing them, so Uninstall can restore *your* settings instead of only hard-coded Blizzard defaults.
- Changelog window now has a left-hand version list; click a version to scroll to that section.

### Changed

- Welcome popup now clarifies the difference between deleting the addon folder and and fully uninstalling.

### Removed

- `/undocm` slash command — use the Uninstall button in options instead.


## [4.0.1] - 2026-07-27

### Added

- Excluded Spells and Cast at Crosshair now accept spell IDs as well as names (including mixed lists such as `Heroic Leap, #6544`).

### Fixed

- Keybind options can no longer bind Left or Right Mouse Button, which previously could clear Camera Or Select Or Move from `BUTTON1`.

### Changed

- Clarified helper text on several options.

## [4.0.0] - 2026-07-25

### Changed

- **Breaking:** rebuilt the settings UI as a standalone, movable Combat Mode window with a sidebar layout. Open it with `/cm` or `/combatmode`, or from Escape > Options > AddOns > Combat Mode.
- **Breaking:** Crosshair can no longer be edited through Edit Mode; its settings live under the Crosshair tab in the new options window.
- Healing Radial renamed to Party Radial, with a live preview while adjusting visual settings.
- Action Camera options moved into a dedicated Action Camera section.

### Removed

- Ace3 / LibStub dependency stack in favor of native Combat Mode modules. SavedVariables (`CombatModeDB`) and slash commands are unchanged.

### Fixed

- Rapidly toggling OPie rings could leave the cursor stuck and visible while Mouse Look was active.
- Reloading could leave the cursor visible while still in the Mouse Look state after the loading screen.

## [3.3.1] - 2026-07-18

### Changed

- Improved cursor unlock performance by caching compiled custom conditions and checking open Blizzard UI panels before scanning watched frames.

## [3.3.0] - 2026-04-24

### Added

- Combat Assist spell icon suggestion on the Crosshair (Retail Assisted Combat highlight).
- Edit Mode controls for the assisted highlight widget: enable/disable, size, position (X/Y), keybind display, and keybind anchor.

## [3.2.2] - 2026-03-28

### Added

- Changelog popup on first login after updating the addon.

## [3.2.1] - 2026-03-27

### Fixed

- Cast @cursor whitelist not applying correctly.

## [3.2.0] - 2026-03-27

### Added

- Reticle Targeting CVar editor for customizing Combat Mode Reticle Targeting CVars.
- Targeting macro prelines editor for customizing injected prelines when Reticle Targeting is enabled.

## [3.1.10] - 2026-03-26

### Added

- Third-party action bar policy: when Bartender4, Dominos, or ElvUI is detected, Combat Mode forces `macroInjectionClickCastOnly=true` and locks that toggle; Blizzard default bars keep full reticle targeting macro injection.

## [3.1.9] - 2026-03-26

### Changed

- Action bar binding overrides now derive the canonical action-slot id from the binding prefix and button index instead of `MultiBar*ButtonN` frames, whose `action` attribute can be ambiguous with Bartender4, Dominos, ElvUI, and similar addons.

## [3.1.8] - 2026-03-25

### Fixed

- Reticle Targeting with ElvUI and Bartender4.

## [3.1.7] - 2026-03-24

### Fixed

- Sticky crosshair table name.

## [3.1.6] - 2026-03-24

### Added

- GitHub package release workflow.

## [3.1.5] - 2026-03-23

### Changed

- Cursor freelook centering is tied to the Crosshair being active, not Reticle Targeting.
- Crosshair reactivity no longer requires Reticle Targeting.
- Interaction HUD range check adjusted so the Crosshair and Interaction HUD can be used independently of Reticle Targeting configuration.

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
- Crosshair behavior aligns more closely with config options, including more reliable cursor centering.
- Reorganized project structure into smaller, easier-to-maintain files.

### Fixed

- Reticle Targeting blacklist not excluding spells from targeting macro injection, which broke Hold To Cast and empowered spell options (e.g. Hold & Release). Excluding a spell by name on the list now restores expected behavior.

[Unreleased]: https://github.com/djsmithdev/combatmode/compare/4.1.1...HEAD
[4.1.1]: https://github.com/djsmithdev/combatmode/compare/4.1.0...4.1.1
[4.1.0]: https://github.com/djsmithdev/combatmode/compare/4.0.3...4.1.0
[4.0.3]: https://github.com/djsmithdev/combatmode/compare/4.0.2...4.0.3
[4.0.2]: https://github.com/djsmithdev/combatmode/compare/4.0.1...4.0.2
[4.0.1]: https://github.com/djsmithdev/combatmode/compare/4.0.0...4.0.1
[4.0.0]: https://github.com/djsmithdev/combatmode/compare/3.3.1...4.0.0
[3.3.1]: https://github.com/djsmithdev/combatmode/compare/3.3.0...3.3.1
[3.3.0]: https://github.com/djsmithdev/combatmode/compare/3.2.2...3.3.0
[3.2.2]: https://github.com/djsmithdev/combatmode/compare/3.2.1...3.2.2
[3.2.1]: https://github.com/djsmithdev/combatmode/compare/3.2.0...3.2.1
[3.2.0]: https://github.com/djsmithdev/combatmode/compare/3.1.10...3.2.0
[3.1.10]: https://github.com/djsmithdev/combatmode/compare/3.1.9...3.1.10
[3.1.9]: https://github.com/djsmithdev/combatmode/compare/3.1.8...3.1.9
[3.1.8]: https://github.com/djsmithdev/combatmode/compare/3.1.7...3.1.8
[3.1.7]: https://github.com/djsmithdev/combatmode/compare/3.1.6...3.1.7
[3.1.6]: https://github.com/djsmithdev/combatmode/compare/3.1.5...3.1.6
[3.1.5]: https://github.com/djsmithdev/combatmode/compare/3.1.4...3.1.5
[3.1.4]: https://github.com/djsmithdev/combatmode/compare/3.1.3...3.1.4
[3.1.3]: https://github.com/djsmithdev/combatmode/compare/3.1.2...3.1.3
[3.1.2]: https://github.com/djsmithdev/combatmode/compare/3.1.1...3.1.2
[3.1.1]: https://github.com/djsmithdev/combatmode/releases/tag/3.1.1
