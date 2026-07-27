# CombatMode Agent Playbook

This file defines how AI agents should work in this addon workspace.

**Claude Code / multi-tool entry:** read **`CLAUDE.md`** first; it `@`-includes **`.context/project.md`**, **`.context/api.md`**, and **`.context/patterns.md`**. Cursor-specific rules live in **`.cursor/rules/*.mdc`**; this file remains the canonical playbook for rule map, project map, and finish checklist.

## Primary references

1. Use WoW API MCP tools first (`lookup_api`, `search_api`, `list_deprecated`, `get_event`, `get_enum`).
2. Follow architecture docs and in-file header purpose comments.
3. Fall back to external docs only when MCP/tooling cannot answer.
4. Follow contributor workflow defaults from `CONTRIBUTING.md`.

## Rule map

- `.cursor/rules/wow-mcp-first.mdc`: WoW API source-of-truth workflow and output expectations.
- `.cursor/rules/combatmode-architecture-and-style.mdc`: module ownership and coding conventions.
- `.cursor/rules/combatmode-lua-safety.mdc`: combat lockdown, secure flow, taint, and state hygiene guardrails.
- `.cursor/rules/combatmode-change-checklist.mdc`: pre-finish validation checklist for feature changes.
- `.cursor/rules/combatmode-release-flow.mdc`: release-only checklist and process.
- `.cursor/rules/combatmode-vendored-libs.mdc`: policy if third-party code is reintroduced under `CombatMode/Libs/**` (Ace3/LibStub are removed).

## Project map

- `CombatMode/CombatMode.toc`: metadata, SavedVariables, top-level include.
- `CombatMode/Embeds.xml`: load order and root frame script wiring.
- `CombatMode/Core/`: runtime behavior modules, grouped by domain.
  - `Core/Runtime/Runtime.lua`: owns AddOn namespace (`local addonName, CM = ...`; optional `_G.CM` alias), native `CombatModeDB` → `CM.DB`, slash commands (`SlashCmdList`), lifecycle (`ADDON_LOADED` / `PLAYER_LOGIN`), cross-feature orchestration + global `CombatMode_OnUpdate`; registers events on `CombatModeFrame`; first-login welcome via deferred `CM.UI.ShowWelcome`; schedules in-game changelog when `CM.DB.global.lastSeenChangelogVersion` differs from `CM.METADATA["VERSION"]` (or always in Debug Mode) via `CM.Config.MaybeShowChangelogOnNewVersion` in `UI/Changelog/ChangelogPanel.lua`.
  - `Core/Runtime/EventRouter.lua`: centralized event dispatch + global `CombatMode_OnEvent`.
  - `Core/Runtime/CVarManager.lua`: all CVar-writing helpers, pre-CM `priorCVarSnapshot` capture/restore, reticle preset resolution (`CM.GetEffectiveReticleTargetingCVarValues` merges `CM.Constants.ReticleTargetingCVarValues` with account-wide `CM.DB.global.reticleTargetingCVarOverrides`; excluded keys in `CM.Constants.ReticleTargetingCVarEditorExcluded` are pruned and never overridden).
  - `Core/Runtime/BindingQueue.lua`: combat-safe deferred binding updates.
  - `Core/Runtime/Bootstrap.lua`: startup sequence (`CM.BootstrapFeatureModules`) + `CM.RestorePriorBindings` (Uninstall: default left/right click camera binds).
  - `Core/FreeLook/`: mouselook/free-look state machine (`FreeLookController.lua`) and auto cursor unlock (`AutoCursorUnlock.lua`).
  - `Core/Crosshair/`: crosshair visuals (`Crosshair.lua`), Interaction HUD, Assisted Highlight, animations.
  - `Core/ClickCasting/`: binding overrides, targeting macro builder, third-party action bar resolver.
  - `Core/PartyRadial/PartyRadial.lua`: party radial (`CM.PartyRadial` API).
- `CombatMode/Constants/`: static tables (`CM.Constants`). `Namespace.lua` first; `CVars.lua` defines `ReticleTargetingCVarValues` (CombatMode defaults) and `ReticleTargetingCVarEditorExcluded` (keys hidden from the editor and pruned from saved overrides).
- `CombatMode/UI/Options/`: standalone custom options window.
  - `UI/Options/Draw.lua`: theme tokens `CM.UI.Colors` / `UI.Fonts` / `UI.Radius` (minimal grey ramp + single accent yellow), `UI.StripColors`, `UI.SetFontSize`, and drawing primitives (rounded surfaces, circular knob mask, tooltip/ESC/drag helpers).
  - `UI/Options/Widgets.lua`: control factories (toggle, slider, dropdown, keybind, text/multiline, button, header, description); every value control has `:Refresh()` and registers for `CM.UI.Options.Sync()`; `UI.Confirm(text, onAccept)` (Yes/No) and `UI.Notify(text, onClose)` (single Okay) share the themed modal `CombatModeConfirmDialog`; `UI.ShowWelcome` owns the dedicated first-install modal `CombatModeWelcomeDialog` (not in `UISpecialFrames`); any toggle/button with `confirm = true` routes through `UI.Confirm`.
  - `UI/Options/OptionsPanel.lua`: `CombatModeOptionsFrame` window shell + sidebar + layout `ctx`; `CM.OpenOptions`/`ToggleOptions`/`CloseOptions` (combat-guarded), `CM.GetOptionsFrame`, `CM.UI.CreateWindow`/`CM.UI.NewLayout`, and `CM.UI.Options.AddTab`. Always docks left-of-center on open (`Options.DockWindowLeft`) so the crosshair/radial stay clear. Sidebar footer (`BuildSidebarFooter`) holds Silence Alerts / Debug Mode toggles + View Changelog / Reset to Defaults / Uninstall buttons.
  - `UI/Options/BlizzardSettingsBridge.lua`: Escape → Options → AddOns → Combat Mode canvas category with an Open Options button that calls `CM.OpenOptions` (settings still live in the standalone window).
  - `UI/Options/Tabs/Tab*.lua`: per-category tab builders (General, Crosshair, ReticleTargeting, ClickCasting, AutoCursorUnlock, Camera, PartyRadial) wiring get/set/disabled to `CM.*` + `CM.DB`. Optional `onSelect`/`onDeselect` hooks fire on tab switch and window show/hide; `TabCrosshair` uses them with `CM.SetCrosshairOptionsPreview` to preview the reticle, Interaction HUD, and Combat Assist live; `TabPartyRadial` uses them with `CM.PartyRadial.SetOptionsPreview` so Party Radial Visual Settings preview live.
- `CombatMode/UI/Changelog/`: in-game changelog viewer.
  - `UI/Changelog/ChangelogNamespace.lua`: initializes the `CM.Config` namespace only.
  - `UI/Changelog/ChangelogData.lua`: `CM.Config.ChangelogText` (markdown body for the viewer; keep aligned with `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1` or the VS Code task **Sync CHANGELOG.md to ChangelogData.lua**).
  - `UI/Changelog/ChangelogPanel.lua`: in-game changelog window (`SimpleHTML` + scroll frame); `CM.Config.ShowChangelog`, `CM.Config.MaybeShowChangelogOnNewVersion`; updates `lastSeenChangelogVersion` when the panel is shown. Reached from the sidebar footer (View Changelog).
- `CombatMode/UI/Editors/`: standalone secondary editor windows built on the `CM.UI` toolkit.
  - `UI/Editors/ReticleCVarEditorData.lua` + `UI/Editors/ReticleCVarEditorPanel.lua`: Reticle Targeting CVar browser/editor (custom frame): `CM.OpenReticleTargetingCVarEditor`; data layer owns row build, canonical/exclusion helpers (`Data.CanonicalCVar`, `Data.IsEditableCVar`), and override writes guarded in combat; panel owns list UI, debounced refresh, `CVAR_UPDATE` / `SetCVar` hooks for live values and attribution; anchors to the right of `CM.GetOptionsFrame()` when open.
  - `UI/Editors/TargetingMacroPrelinesEditor.lua`: Targeting Macro Prelines editor — standalone custom window built on the `CM.UI` toolkit; `CM.OpenTargetingMacroPrelinesEditor`; account-wide overrides in `CM.DB.global` consumed by `Core/ClickCasting/TargetingMacroBuilder.lua`.
- `scripts/sync-changelog-to-lua.ps1`: copies `CombatMode/CHANGELOG.md` into `UI/Changelog/ChangelogData.lua` (`CM.Config.ChangelogText`).
- `CombatMode/Bindings.xml`: keybind declarations.

See `STRUCTURE.md` for load-order details.

## Implementation expectations

- Keep behavior changes local to the owning module.
- Preserve centralized event wiring and core dispatch patterns.
- Respect combat lockdown and secure frame constraints.
- Avoid introducing globals unless explicitly required.
- Put user-facing settings into the owning `UI/Options/Tabs/Tab*.lua` builder (via the `ctx:*` widget helpers); register new tabs with `CM.UI.Options.AddTab`.
- Keep DB scope intentional (`CM.DB.global` vs `CM.DB.char`).

## Before finishing a change

Authoritative day-to-day finish order is also in `.cursor/rules/combatmode-change-checklist.mdc`.

1. Verify deprecations/replacements via WoW MCP tools; confirm no combat-unsafe paths; validate enable/disable symmetry for mouselook/CVars/bindings when touched; update architecture docs/headers if the module graph changed.
2. **Lint first** (before version/changelog):
   - Preferred: `pwsh ./scripts/lint-changed.ps1`
   - Equivalent: `pre-commit run --files <changed lua files>`
   - Debug only: `stylua --check ...`, `selene --config selene.toml ...`
   - Full repo only for release prep / explicit request: `pre-commit run --all-files`
3. **After code changes** (skip for pure docs/rules-only edits):
   - Bump `## Version` in `CombatMode/CombatMode.toc` (SemVer).
   - Update `CombatMode/CHANGELOG.md` (Keep a Changelog): fold `[Unreleased]` into `## [x.y.z] - YYYY-MM-DD` matching the TOC version; use standard categories; refresh compare links.
   - Run `pwsh ./scripts/sync-changelog-to-lua.ps1` so `CombatMode/UI/Changelog/ChangelogData.lua` matches the in-game viewer.
