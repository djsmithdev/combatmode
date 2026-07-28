# CombatMode add-on layout

Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **CombatMode/Constants/** | Static tables consumed by runtime modules (`Namespace.lua` first, then CVars, Assets, Gameplay, DatabaseDefaults, PartyRadial, FrameWatch, Reticle). |
| **CombatMode/Core/** | Runtime behavior, grouped by domain: `Runtime/` (shell, events, CVars, binding queue, bootstrap), `FreeLook/` (mouselook + auto cursor unlock), `Crosshair/` (reticle, Interaction HUD, Assisted Highlight, animations), `ClickCasting/` (binding overrides, macro builder, addon bar resolver), `PartyRadial/` (party radial; `CM.PartyRadial` API). |
| **CombatMode/UI/** | Custom client UI. `UI/Options/` is the standalone options window: `Draw.lua` (theme tokens + primitives), `Widgets.lua` (control factories), `SpellMultiSelect.lua` (spell pill multi-select for Reticle Targeting lists), `OptionsPanel.lua` (window shell + layout + `CM.OpenOptions`), and `Tabs/Tab*.lua` (per-category builders including Crosshair). `UI/Changelog/` is the in-game changelog viewer (`ChangelogNamespace.lua` → `CM.Config`, `ChangelogData.lua` body synced from `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1`, `ChangelogPanel.lua` window). `UI/Editors/` holds standalone secondary editor windows built on the `CM.UI` toolkit: Reticle CVar (`ReticleCVarEditorData.lua`, `ReticleCVarEditorPanel.lua`; account overrides in `CM.DB.global.reticleTargetingCVarOverrides`, merged at runtime via `Core/Runtime/CVarManager.lua`) and Targeting Macro Prelines (`TargetingMacroPrelinesEditor.lua`). |
| **CombatMode/assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **CombatMode/Core/Runtime/Runtime.lua** — receives the AddOn namespace (`local addonName, CM = ...`), optional `_G.CM` alias, registers `ADDON_LOADED` / `PLAYER_LOGIN` lifecycle, native `CombatModeDB` merge, and slash commands (`/cm`, `/combatmode`).
2. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers (`Namespace.lua` first).
3. **CombatMode/Core/Runtime/** — remaining runtime support scripts:
   - **EventRouter.lua** (event routing + `_G.CombatMode_OnEvent`)
   - **CVarManager.lua** (all CVar-writing helpers; reticle preset + `reticleTargetingCVarOverrides` → `CM.GetEffectiveReticleTargetingCVarValues`)
   - **BindingQueue.lua** (combat-safe deferred binding updates)
   - **Bootstrap.lua** (startup sequence)
4. **CombatMode/Core/ClickCasting/**, **FreeLook/**, **Crosshair/**, **PartyRadial/** — feature modules (see `Embeds.xml` for exact order).
5. **CombatMode/UI/Options/** — options window toolkit: **Draw.lua** then **Widgets.lua** then **SpellMultiSelect.lua** (all define `CM.UI` pieces), then **OptionsPanel.lua** (defines `CM.UI.Options.AddTab` / `CM.UI.CreateWindow` / `CM.OpenOptions`), then **BlizzardSettingsBridge.lua** (AddOns panel shortcut), then **Tabs/Tab*.lua** (each registers a tab via `AddTab`).
6. **CombatMode/UI/Changelog/** — **ChangelogNamespace.lua** first (defines `CM.Config`), then **ChangelogData.lua** + **ChangelogPanel.lua**; and **CombatMode/UI/Editors/** — the standalone editors (**ReticleCVarEditorData/Panel.lua**, **TargetingMacroPrelinesEditor.lua**). Both load after the `UI/Options` toolkit they consume.
7. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; `OnEvent` / `OnUpdate` call globals defined in Core. Events are registered on this frame during `CM:OnEnable()`.

## Public entry points

- **Slash:** `/cm`, `/combatmode` (Core/Runtime). Uninstall is the options sidebar button (`CM.UninstallCombatMode`), not a slash command.
- **Options:** standalone movable window `CombatModeOptionsFrame` opened by `CM.OpenOptions()` (bound to `/cm`, the first-login popup, and Escape → Options → AddOns → Combat Mode via `UI/Options/BlizzardSettingsBridge.lua`); tabs registered via `CM.UI.Options.AddTab` in `UI/Options/Tabs/`.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (sidebar footer → View Changelog, or auto after version bump via `Core/Runtime/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `UI/Changelog/ChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.
