# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/2.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.5.0] - 2026-08-28

### Added

- Crosshair **Reaction Colors** editor (Crosshair tab → Edit): customize reticle tint and alpha per reaction — Hostile, Friendly NPC, Friendly Player, Object, and Base (idle).
- Crosshair **Situational Condition** (Crosshair tab): optional custom Lua checked during Mouse Look. Return `true` to swap the reticle to the **X** texture while keeping your reaction colors. Default covers player dead/ghost and stealth; clear the field to disable.

### Changed

- Reticle reaction tints, Target Lock nameplate marker (arrive + settled pulse), and cast-break / cast-feedback hostile flashes now use your customized colors (Target Lock and cast feedback use **Hostile**).

## [4.4.2] - 2026-08-28

### Fixed

- Auto Target Lock no longer leaves focus stuck on a dead corpse: auto-lock prelines add `,nodead` on focus targeting branches (`,harm` / `,exists` alone still match corpses) and resync focus each cast (`/focus [nodead]` or `/focus [nodead,harm]`) instead of sticky `[@focus,noexists]`.
- Enemies Only + Auto Target Lock: `/focus [nodead,harm]` no longer auto-focuses friendly targets when you hard-target them, so hostile casts do not require manually clearing focus or cycling Target Lock.
- Opening options no longer errors on characters whose spellbook exposes pet spells when `C_SpellBook.GetSpellBookItemInfo` is unavailable.

### Changed

- Default auto-lock prelines updated again; reset Macro Prelines to defaults and `/reload` if you customized them under 4.4.0–4.4.1.

## [4.4.1] - 2026-08-27

### Fixed

- Auto Target Lock no longer re-locks a dead hostile hard target after the lock dies (clears dead hostile targets before retarget/re-lock), which was causing invalid-target casts until you aimed at a new unit.

### Changed

- Default targeting prelines tightened for the 255-character macro limit. If you've modified the Macro Prelines, it's advised to reset them to defaults to pick up the new revised versions.

## [4.4.0] - 2026-08-27

### Added

- Auto Target Lock option under Reticle Targeting: Target Lock engages automatically when attacking units (clears when the unit dies and re-locks onto a new crosshair target).
- Support for new Click Casting bindings for MultiBar 5 to 7.
- More bindable actions in the Click Casting action dropdown: pings, arena target/focus (1–5), vehicle exit/seats, party pets (1–4), sit/sheath/run, pitch up/down, and Toggle Ping Listener.

### Changed

- Targeting Macro Prelines editor always shows all four preline fields; inactive combinations show a watermark (Auto Target Lock × Enemies Only). Labels include the active Enemies Only / Auto Target Lock state.
- Default reticle targeting prelines adjusted for Auto Target Lock behavior and the 255-character SecureActionButton `macrotext` limit (auto-lock variants keep death-unlock + re-lock; soft-target conditions are trimmed where needed to leave room for the longest `/click` cast line).
- Targeting Macro Prelines editor enforces a max length (`CM.TargetingMacroPrelineMaxLen`, 129) so custom prelines cannot truncate the trailing `/click` on the worst-case primary-bar path; oversized saved overrides are ignored at runtime.

### Fixed

- Target Lock nameplate marker now appears reliably with nameplate addons (e.g. Platynator): marker parents to the nameplate root with ignore-parent-alpha so health-bar fades no longer hide it; animations (scale/alpha + color pulse) phases no longer fight each other; plate recycle resumes settled without a second flash.

## [4.3.3] - 2026-08-20

### Fixed

- Fixed issue where upgrading items would cause a Lua error due to `StaticPopup_Show` hook + dismiss loop.

## [4.3.2] - 2026-08-20

### Fixed

- Experimental camera features popup now reliably suppressed on every login/reload. Replaced `UIParent:UnregisterEvent` with a `StaticPopup_Show` hook so the popup is intercepted before it can appear — works regardless of addon load timing.
- Camera no longer jumps or zooms erratically when "Disable with Mouse Look" toggles mouse look on and off. Added `ConfigActionCameraMouselookDisable` which only toggles behavioral Action Camera CVars (shoulder offset, head tracking, pitch, motion sickness); preference CVars (zoom, FOV, zoom speed, turn speed) are left unchanged so zoom/fov survive mouse look toggles.

### Changed

- Sticky Targeting moved from the Action Camera tab to Reticle Targeting.
- Mouse Look Turn Speed moved from the Action Camera tab to General > Mouse Look.

## [4.3.1] - 2026-08-20

### Added

- Four new adjustable Action Camera CVars in the Action Camera options tab: Field of View (50–90°), Max Zoom Distance (15–39 yards), Zoom Scroll Speed (1–50 inc/s), and Head Tracking Strength (0–2). Each slider applies immediately and only shows when the Action Camera preset is on (disabled when DynamicCam is loaded).
- Frame name to Vignette effect: `CombatModeVignetteFrame`.
- Added Alliance's version of Traveler's Tundra Mammoth to the Unlock Mount list.

### Changed

- Camera presets now apply adjustable CVars (FOV, max zoom, scroll speed, head tracking) on top of the base Action Camera preset values at enable time.

## [4.3.0] - 2026-08-19

### Added

- Vignette Effect option under Action Camera > Additional Features: Darkens the edges of the screen to reduce visual distractions. On by default.
- Vignette Fade with Mouse Look toggle: Vignette fades out when Mouse Look is off and fades in when engaged. On by default.
- `CM.IsMouselooking()` public API: tracks Combat Mode's own intentional mouselook, distinct from Blizzard's `IsMouselooking`. Combines an internal flag with the Blizzard API so external addons starting or stopping mouselook are also handled safely.

### Changed

- Crosshair while mounted now shows an inactive dot texture instead of being hidden; the "Hide While Mounted" option was removed.
- Target Lock now always prefers your current target, falling back to the unit under the crosshair when no target exists. The "Lock Selected Target" option was removed; both the Target Lock keybind and the click-cast Toggle Focus bindings share this behavior.
- Target Lock sound cues are now always on; the sound cue toggle was removed from the options.
- Toggle Focus Any / Toggle Focus Enemy bindable actions now use the same target-first macros as the Target Lock keybind, and CM macros are refreshed on every load so existing installs pick up the updated behavior.
- Reticle Targeting in Enemies Only mode now ignores a friendly Target Lock for hostile casts, so locking a party member as focus no longer redirects your attacks; the friendly focus is still honored when Enemies Only is off.
- Default click-cast binds for Alt+Left / Alt+Right mouse now use Toggle Focus (Enemy / Any) instead of Focus Target / Clear Focus.
- Vendor Mount auto-unlock renamed to Unlock Mounts. It is now a customizable multi-select field, pre-populated with the current vendor mount list so users can add their own mounts that force a cursor unlock.
- Vignette, crosshair, animations, assisted highlight, and party radial now use `CM.IsMouselooking()` instead of the raw Blizzard API, so they only respond to Combat Mode's intentional mouselook — not right-click-drag camera turn or other addon mouselook.

### Removed

- "Hide While Mounted" crosshair option (new mounted crosshair state).
- "Target Lock Sound Cues" option (always on now).
- "Lock Selected Target" option (target-first behavior is now the default).

### Fixed

- Friendly Target Lock no longer hijacks abilities when Enemies Only is on: offensive spells skip the friendly focus and target hostile units instead.
- Experimental camera features popup no longer appears when applying Action Camera CVars — the `EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED` unregister now runs before the CVar writes.

## [4.2.1] - 2026-08-12

### Added

- Target Lock marker now flashes red when the locked unit is casting, making it easier to track interrupt windows at a glance.

### Fixed

- Party Radial no longer produces "Unknown Unit" red errors when changing zones while in a party, even when the radial is not open. The fix disarms slice secure buttons on every zone transition so they cannot intercept stray clicks or binding-resolution events with stale/out-of-zone unit tokens.
- Settings CVar snapshot is no longer overwritten on every login, ensuring the Uninstall button correctly restores the user's pre-Combat Mode camera and targeting CVars.

## [4.2.0] - 2026-08-08

### Added

- In-game function-level profiler (`Core/Dev/FunctionProfiler.lua`): lightweight wrapper around `C_AddOnProfiler.MeasureCall` with per-key cumulative CPU and memory stats. Access via the Debug Mode toggle in the options panel — toggle ON to start profiling, toggle OFF to print a sorted report + CPU stats to chat.
- `CM.StartProfiling()` and `CM.StopAndReportProfiling()` public APIs for automated performance testing.

### Changed

- Debug Mode toggle now also drives profiling: on → start, off → report + reset.
- Optimised several hot paths:
  - `ShouldFreeLookBeOff` early-exit short circuit (-14% avg, -42% alloc per call).
  - `C_AssistedCombat.GetNextCastSpell` cached for 1 second (-31% alloc per assist tick).
  - Consolidated duplicate `IsMouselooking()` calls in the root OnUpdate (-19% root tick time).
  - Party Radial `TrackMousePosition` slice refresh throttled to 0.15s (-11% avg, -10% alloc per call).
  - Binding fingerprint uses a numeric hash instead of string allocation.
  - `UpdateFocusCycleWheelBindings` and `UpdateAllHealthBarGlowPulses` use local caching and batch operations.

## [4.1.6] - 2026-08-06

### Added

- Reset Mouse Look keybind to recover a macOS stuck-cursor freeze after switching windows (macOS only, PR #179, thanks Roman Kitaev).
- GitHub Sponsors button in the config panel header.

## [4.1.5] - 2026-08-05

### Added

- Scale sliders for Interaction HUD, Combat Assist, and Party Radial (0.5–1.5); each scales the full companion / radial chrome.
- Added Discord & GitHub repository links to the config panel.

### Changed

- Crosshair Size is now Scale (0.5–1.5, default 1.0); existing pixel sizes migrate to the equivalent scale.
- Added new Combat Mode theme to celebrate the release of version 4.

### Fixed

- While Target Lock is held (and the marker option is on), the center reticle stays on the locked dot even if the focus nameplate is not visible.
- Cycling Target Lock with the mouse wheel no longer briefly flashes the reactive crosshair; the locked dot stays up across focus swaps.

## [4.1.4] - 2026-08-03

### Added

- Target Lock Marker option (on by default): turn off to keep the normal reactive crosshair while locked, with no nameplate hit marker.

### Changed

- Party Radial runtime is split into focused submodules under `Core/PartyRadial/` (`PartyData` → `SecureBindings` → `HealthBars` → `RoleIcons` → `Visual` → `Lifecycle` → façade; behavior unchanged).
- Shared crosshair cast-break VFX tuning and companion side offset live in `Constants/Assets.lua` (`CrosshairCastBreak`, `CrosshairCompanionOffsetX`); cast-break flash red reuses hostile reaction color.
- Party Radial Show Health Bars is on by default for new installs.
- Target Lock (keybind, mouse-wheel cycle, marker, and sound cues) is fully disabled when Reticle Targeting is off, matching the options panel.

### Fixed

- Crosshair cast feedback and Combat Assist cast swipe/break no longer error in instances when cast GUIDs are secret under taint.
- Hardened several patterns across the code base against possibly secret or tainted value comparisons.
- Target Lock no longer leaves the center reticle stuck on a static Dot when the focus nameplate never appears; the plate marker still shows if the plate arrives later.
- Party Radial no longer blanket-enables slice mouse when the feature is disabled; inactive slices also collapse hit rects out of combat to reduce free-cursor click-steal.

## [4.1.3] - 2026-08-02

### Added

- Cycle Target Lock with Mouse Wheel (on by default): while Mouse Look is on and a Target Lock is set, mouse wheel cycles nearby enemies and moves the lock. Without a lock (or with Mouse Look off), the wheel zooms the camera as usual.
- Target Lock Sound Cues (on by default): play distinct cues when a Target Lock is set, cleared, or cycled to another enemy.
- Target Lock nameplate marker: while locked, the center reticle becomes a static Dot and a hit marker (the Active texture for your selected crosshair Appearance) appears on the locked unit's nameplate health bar.

### Changed

- Combat Assist animations & appearance reworked to be more subtle/less annoying.
- Sheath Weapons with Mouse Look now waits briefly before sheathing after unlock, so rapid Mouse Look toggles (e.g. while single-pulling) no longer flash sheath/unsheath. Unsheath on lock is still immediate.
- Combat Assist and Interaction HUD runtime code are split into focused submodules under `Core/Crosshair/AssistedHighlight/` and `Core/Crosshair/InteractionHUD/` (behavior unchanged).
- Party Radial slices have been expanded to provide more information.

### Fixed

- Binding another action to an Interact key that already includes Alt (for example Alt+Mouse Button 3) no longer leaves Interact as Alt+Alt+key.
- Rapid Single-Button Assistant presses no longer spam Combat Assist cast-success press/pulse animations (repeats are coalesced while feedback is already playing).
- Click-cast binding refresh no longer loops when Blizzard's Single-Button Assistant rewrites its action slot.

## [4.1.2] - 2026-08-01

### Added

- Combat Mode is now also published on [Wago Addons](https://addons.wago.io/addons/combat-mode); GitHub releases upload to both CurseForge and Wago.

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

[Unreleased]: https://github.com/djsmithdev/combatmode/compare/4.5.0...HEAD
[4.5.0]: https://github.com/djsmithdev/combatmode/compare/4.4.2...4.5.0
[4.4.2]: https://github.com/djsmithdev/combatmode/compare/4.4.1...4.4.2
[4.4.1]: https://github.com/djsmithdev/combatmode/compare/4.4.0...4.4.1
[4.4.0]: https://github.com/djsmithdev/combatmode/compare/4.3.3...4.4.0
[4.3.3]: https://github.com/djsmithdev/combatmode/compare/4.3.2...4.3.3
[4.3.2]: https://github.com/djsmithdev/combatmode/compare/4.3.1...4.3.2
[4.3.1]: https://github.com/djsmithdev/combatmode/compare/4.3.0...4.3.1
[4.3.0]: https://github.com/djsmithdev/combatmode/compare/4.2.1...4.3.0
[4.2.1]: https://github.com/djsmithdev/combatmode/compare/4.2.0...4.2.1
[4.2.0]: https://github.com/djsmithdev/combatmode/compare/4.1.6...4.2.0
[4.1.6]: https://github.com/djsmithdev/combatmode/compare/4.1.5...4.1.6
[4.1.5]: https://github.com/djsmithdev/combatmode/compare/4.1.4...4.1.5
[4.1.4]: https://github.com/djsmithdev/combatmode/compare/4.1.3...4.1.4
[4.1.3]: https://github.com/djsmithdev/combatmode/compare/4.1.2...4.1.3
[4.1.2]: https://github.com/djsmithdev/combatmode/compare/4.1.1...4.1.2
[4.1.1]: https://github.com/djsmithdev/combatmode/compare/4.1.0...4.1.1
[4.1.0]: https://github.com/djsmithdev/combatmode/compare/4.0.3...4.1.0
[4.0.3]: https://github.com/djsmithdev/combatmode/compare/4.0.2...4.0.3
[4.0.2]: https://github.com/djsmithdev/combatmode/compare/4.0.1...4.0.2
[4.0.1]: https://github.com/djsmithdev/combatmode/compare/4.0.0...4.0.1
[4.0.0]: https://github.com/djsmithdev/combatmode/compare/3.3.1...4.0.0
