# CombatMode add-on layout

High-level domain map: [README — Architecture](README.md#architecture).
Detailed folder map and ownership: [architecture rule](.cursor/rules/combatmode-architecture-and-style.mdc).
Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

When you move or rename modules, update this file, `Embeds.xml`, the architecture rule, and touched Lua headers in the same change (see [docs-sync rule](.cursor/rules/combatmode-docs-and-headers-stay-in-sync.mdc)).

## Load order (scripts)

1. **CombatMode/Core/Runtime/Runtime.lua** — receives the AddOn namespace (`local addonName, CM = ...`), optional `_G.CM` alias, registers `ADDON_LOADED` / `PLAYER_LOGIN` lifecycle, native `CombatModeDB` merge, and slash commands (`/cm`, `/combatmode`).
2. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers (`Namespace.lua` first).
3. **CombatMode/Core/Dev/** — developer tools with no production impact when idle:
   - **FunctionProfiler.lua** (zero-overhead `C_AddOnProfiler.MeasureCall` wrapper; gated by Debug Mode toggle)
4. **CombatMode/Core/Runtime/** — remaining runtime support scripts:
   - **EventRouter.lua** (event routing + `_G.CombatMode_OnEvent`)
   - **CVarManager.lua** (all CVar-writing helpers; reticle preset + `reticleTargetingCVarOverrides` → `CM.GetEffectiveReticleTargetingCVarValues`)
   - **BindingQueue.lua** (combat-safe deferred binding updates)
   - **Bootstrap.lua** (startup sequence)
5. **CombatMode/Core/ClickCasting/**, **FreeLook/**, **Crosshair/**, **PartyRadial/** — feature modules (see `Embeds.xml` for exact order). Crosshair Improvements lives in `Core/Crosshair/CrosshairImprovements.lua` and owns class-aware hostile range colors, spell overrides, and native reaction-color customization.
6. **CombatMode/UI/Options/** — options window toolkit: **Draw.lua** then **Widgets.lua** then **SpellMultiSelect.lua** (all define `CM.UI` pieces), then **OptionsPanel.lua** (defines `CM.UI.Options.AddTab` / `CM.UI.CreateWindow` / `CM.OpenOptions`), then **BlizzardSettingsBridge.lua** (AddOns panel shortcut), then **Tabs/Tab*.lua** (each registers a tab via `AddTab`).
7. **CombatMode/UI/Changelog/** — **ChangelogNamespace.lua** first (defines `CM.Config`), then **ChangelogData.lua** + **ChangelogPanel.lua**; and **CombatMode/UI/Editors/** — the standalone editors (**ReticleCVarEditorData/Panel.lua**, **TargetingMacroPrelinesEditor.lua**). Both load after the `UI/Options` toolkit they consume.
8. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; `OnEvent` / `OnUpdate` call globals defined in Core. Events are registered on this frame during `CM:OnEnable()`.

## Public entry points

- **Slash:** `/cm`, `/combatmode` (Core/Runtime). Uninstall is the options sidebar button (`CM.UninstallCombatMode`), not a slash command.
- **Options:** standalone movable window `CombatModeOptionsFrame` opened by `CM.OpenOptions()` (bound to `/cm`, the first-login popup, and Escape → Options → AddOns → Combat Mode via `UI/Options/BlizzardSettingsBridge.lua`); tabs registered via `CM.UI.Options.AddTab` in `UI/Options/Tabs/`.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (sidebar footer → View Changelog, or auto after version bump via `Core/Runtime/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `UI/Changelog/ChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.
