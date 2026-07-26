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
- `.cursor/rules/combatmode-vendored-libs.mdc`: policy for `CombatMode/Libs/**` vendored third-party code.

## Project map

- `CombatMode/CombatMode.toc`: metadata, SavedVariables, top-level include.
- `CombatMode/Embeds.xml`: load order and root frame script wiring.
- `CombatMode/Core/`: runtime behavior modules.
  - `Core/Runtime.lua`: lifecycle + cross-feature orchestration + global `CombatMode_OnUpdate`; first-login welcome via deferred `CM.UI.ShowWelcome`; schedules in-game changelog when `CM.DB.global.lastSeenChangelogVersion` differs from `CM.METADATA["VERSION"]` (or always in Debug Mode) via `CM.Config.MaybeShowChangelogOnNewVersion` in `Config/ConfigChangelogPanel.lua`.
  - `Core/RuntimeEventRouter.lua`: centralized event dispatch + global `CombatMode_OnEvent`.
  - `Core/RuntimeCVarManager.lua`: all CVar-writing helpers, reticle preset resolution (`CM.GetEffectiveReticleTargetingCVarValues` merges `CM.Constants.ReticleTargetingCVarValues` with account-wide `CM.DB.global.reticleTargetingCVarOverrides`; excluded keys in `CM.Constants.ReticleTargetingCVarEditorExcluded` are pruned and never overridden), and reset-to-default.
  - `Core/RuntimeBindingQueue.lua`: combat-safe deferred binding updates.
  - `Core/RuntimeBootstrap.lua`: startup sequence (`CM.BootstrapFeatureModules`).
  - `Core/FreeLookController.lua`: mouselook/free-look state machine and cursor mode keybind flow.
- `CombatMode/Constants/`: static tables (`CM.Constants`). `ConstantsCVars.lua` defines `ReticleTargetingCVarValues` (CombatMode defaults) and `ReticleTargetingCVarEditorExcluded` (keys hidden from the editor and pruned from saved overrides).
- `CombatMode/UI/Options/`: standalone custom options window (replaces AceConfig; AceConfig-3.0 + AceGUI-3.0 removed).
  - `UI/Options/Draw.lua`: theme tokens `CM.UI.Colors` / `UI.Fonts` / `UI.Radius` (minimal grey ramp + single accent yellow), `UI.StripColors`, `UI.SetFontSize`, and drawing primitives (rounded surfaces, circular knob mask, tooltip/ESC/drag helpers).
  - `UI/Options/Widgets.lua`: control factories (toggle, slider, dropdown, keybind, text/multiline, button, header, description); every value control has `:Refresh()` and registers for `CM.UI.Options.Sync()`; `UI.Confirm(text, onAccept)` (Yes/No) and `UI.Notify(text, onClose)` (single Okay) share the themed modal `CombatModeConfirmDialog`; `UI.ShowWelcome` owns the dedicated first-install modal `CombatModeWelcomeDialog` (not in `UISpecialFrames`); any toggle/button with `confirm = true` routes through `UI.Confirm`.
  - `UI/Options/OptionsPanel.lua`: `CombatModeOptionsFrame` window shell + sidebar + layout `ctx`; `CM.OpenOptions`/`ToggleOptions`/`CloseOptions` (combat-guarded), `CM.GetOptionsFrame`, `CM.UI.CreateWindow`/`CM.UI.NewLayout`, and `CM.UI.Options.AddTab`. Always docks left on open (`Options.DockWindowLeft`). Sidebar footer (`BuildSidebarFooter`) holds Silence Alerts / Debug Mode toggles + View Changelog / Reset to Defaults buttons.
  - `UI/Options/Tabs/Tab*.lua`: per-category tab builders (General, Crosshair, ReticleTargeting, ClickCasting, AutoCursorUnlock, Camera, HealingRadial) wiring get/set/disabled to `CM.*` + `CM.DB`. Optional `onSelect`/`onDeselect` hooks fire on tab switch and window show/hide; `TabCrosshair` uses them with `CM.SetCrosshairOptionsPreview` to preview the reticle, Interaction HUD, and Combat Assist live; `TabHealingRadial` uses them with `CM.HealingRadial.SetOptionsPreview` so Party Radial Visual Settings preview live.
- `CombatMode/Config/`: in-game changelog + standalone custom editors (no AceConfig/AceGUI).
  - `Config/ConfigNamespace.lua`: initializes the `CM.Config` namespace only.
  - `Config/ConfigChangelogData.lua`: `CM.Config.ChangelogText` (markdown body for the viewer; keep aligned with `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1` or the VS Code task **Sync CHANGELOG.md to ConfigChangelogData.lua**).
  - `Config/ConfigChangelogPanel.lua`: in-game changelog window (`SimpleHTML` + scroll frame); `CM.Config.ShowChangelog`, `CM.Config.MaybeShowChangelogOnNewVersion`; updates `lastSeenChangelogVersion` when the panel is shown. Reached from the sidebar footer (View Changelog).
  - `Config/ReticleCVarEditorData.lua` + `Config/ReticleCVarEditorPanel.lua`: Reticle Targeting CVar browser/editor (custom frame, not AceConfigDialog): `CM.OpenReticleTargetingCVarEditor`; data layer owns row build, canonical/exclusion helpers (`Data.CanonicalCVar`, `Data.IsEditableCVar`), and override writes guarded in combat; panel owns list UI, debounced refresh, `CVAR_UPDATE` / `SetCVar` hooks for live values and attribution; anchors to the right of `CM.GetOptionsFrame()` when open.
  - `Config/TargetingMacroPrelinesEditor.lua`: Targeting Macro Prelines editor — standalone custom window built on the `CM.UI` toolkit (no AceConfigDialog); `CM.OpenTargetingMacroPrelinesEditor`; account-wide overrides in `CM.DB.global` consumed by `Core/TargetingMacroBuilder.lua`.
- `scripts/sync-changelog-to-lua.ps1`: copies `CombatMode/CHANGELOG.md` into `ConfigChangelogData.lua` (`CM.Config.ChangelogText`).
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

- Verify deprecations/replacements via WoW MCP tools.
- Confirm no combat-unsafe paths were introduced.
- Validate enable/disable symmetry for runtime state (mouselook/CVars/bindings).
- Ensure docs/rule updates if architecture or workflow changed.
- Run lint/format via pre-commit on changed files: `pre-commit run --files <changed lua files>`.
- Use direct tool commands only for targeted debugging (`stylua --check ...`, `selene --config selene.toml ...`).
- Run repo-wide formatting/lint only for release prep or explicit maintainer request: `pre-commit run --all-files`.
