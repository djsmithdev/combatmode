# CombatMode add-on layout

Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **CombatMode/Constants/** | Static tables and constants consumed by runtime modules (frame watch tables, radial data, reticle data, etc.). |
| **CombatMode/Core/** | Runtime behavior modules: addon lifecycle + dispatch, dedicated free-look controller, crosshair/reticle targeting, click overrides, cursor unlock, healing radial, plus supporting modules (animations, interaction HUD, macro builders, addon bar resolvers). |
| **CombatMode/UI/** | Custom client UI. `UI/Options/` is the standalone options window: `Draw.lua` (theme tokens + primitives), `Widgets.lua` (control factories), `OptionsPanel.lua` (window shell + layout + `CM.OpenOptions`), and `Tabs/Tab*.lua` (per-category builders including Crosshair). `UI/Changelog/` is the in-game changelog viewer (`ChangelogNamespace.lua` → `CM.Config`, `ChangelogData.lua` body synced from `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1`, `ChangelogPanel.lua` window). `UI/Editors/` holds standalone secondary editor windows built on the `CM.UI` toolkit: Reticle CVar (`ReticleCVarEditorData.lua`, `ReticleCVarEditorPanel.lua`; account overrides in `CM.DB.global.reticleTargetingCVarOverrides`, merged at runtime via `Core/RuntimeCVarManager.lua`) and Targeting Macro Prelines (`TargetingMacroPrelinesEditor.lua`). |
| **CombatMode/assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **CombatMode/Core/Runtime.lua** — receives the AddOn namespace (`local addonName, CM = ...`), optional `_G.CM` alias, registers `ADDON_LOADED` / `PLAYER_LOGIN` lifecycle, native `CombatModeDB` merge, and slash commands (`/cm`, `/combatmode`, `/undocm`).
2. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers.
3. **CombatMode/Core/** — remaining runtime scripts. Runtime “submodules” loaded immediately after constants:
   - **Core/RuntimeEventRouter.lua** (event routing + `_G.CombatMode_OnEvent`)
   - **Core/RuntimeCVarManager.lua** (all CVar-writing helpers; reticle preset + `reticleTargetingCVarOverrides` → `CM.GetEffectiveReticleTargetingCVarValues`)
   - **Core/RuntimeBindingQueue.lua** (combat-safe deferred binding updates)
   - **Core/RuntimeBootstrap.lua** (startup sequence)
   Then feature modules, including **Core/FreeLookController.lua** for mouselook transitions and **Core/Crosshair.lua**.
4. **CombatMode/UI/Options/** — options window toolkit: **Draw.lua** then **Widgets.lua** (both define `CM.UI`), then **OptionsPanel.lua** (defines `CM.UI.Options.AddTab` / `CM.UI.CreateWindow` / `CM.OpenOptions`), then **Tabs/Tab*.lua** (each registers a tab via `AddTab`).
5. **CombatMode/UI/Changelog/** — **ChangelogNamespace.lua** first (defines `CM.Config`), then **ChangelogData.lua** + **ChangelogPanel.lua**; and **CombatMode/UI/Editors/** — the standalone editors (**ReticleCVarEditorData/Panel.lua**, **TargetingMacroPrelinesEditor.lua**). Both load after the `UI/Options` toolkit they consume.
6. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; `OnEvent` / `OnUpdate` call globals defined in Core. Events are registered on this frame during `CM:OnEnable()`.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** standalone movable window `CombatModeOptionsFrame` opened by `CM.OpenOptions()` (bound to `/cm` and the first-login popup); tabs registered via `CM.UI.Options.AddTab` in `UI/Options/Tabs/`. No longer listed under Blizzard settings → AddOns.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (sidebar footer → View Changelog, or auto after version bump via `Core/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `UI/Changelog/ChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.
