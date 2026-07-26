# CombatMode add-on layout

Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **CombatMode/Libs/** | Embedded libraries (LibStub, Ace3, …); treat as vendored code per `.cursor/rules/combatmode-vendored-libs.mdc`. |
| **CombatMode/Constants/** | Static tables and constants consumed by runtime modules (frame watch tables, radial data, reticle data, etc.). |
| **CombatMode/Core/** | Runtime behavior modules: addon lifecycle + dispatch, dedicated free-look controller, crosshair/reticle targeting, click overrides, cursor unlock, healing radial, plus supporting modules (animations, interaction HUD, macro builders, addon bar resolvers). |
| **CombatMode/Config/** | Namespace init (`ConfigNamespace.lua` → `CM.Config`), in-game changelog (`ConfigChangelogData.lua` + `ConfigChangelogPanel.lua`; body synced from `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1`), plus standalone custom editors: Reticle CVar (`ReticleCVarEditorData.lua`, `ReticleCVarEditorPanel.lua`; account overrides in `CM.DB.global.reticleTargetingCVarOverrides`, merged at runtime via `Core/RuntimeCVarManager.lua`) and Targeting Macro Prelines (`TargetingMacroPrelinesEditor.lua`, rebuilt on the `CM.UI` toolkit). No AceConfig/AceGUI. |
| **CombatMode/UI/** | Custom (non-Ace) client UI. `UI/Options/` is the standalone options window: `Draw.lua` (theme tokens + primitives), `Widgets.lua` (control factories), `OptionsPanel.lua` (window shell + layout + `CM.OpenOptions`), and `Tabs/Tab*.lua` (per-category builders including Crosshair). |
| **CombatMode/assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **CombatMode/Libs** — dependency order preserved in `CombatMode/Embeds.xml`.
2. **CombatMode/Core/Runtime.lua** — must run first so `AceAddon:NewAddon("CombatMode")` exists.
3. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers.
4. **CombatMode/Core/** — remaining runtime scripts. Runtime “submodules” loaded immediately after constants:
   - **Core/RuntimeEventRouter.lua** (event routing + `_G.CombatMode_OnEvent`)
   - **Core/RuntimeCVarManager.lua** (all CVar-writing helpers; reticle preset + `reticleTargetingCVarOverrides` → `CM.GetEffectiveReticleTargetingCVarValues`)
   - **Core/RuntimeBindingQueue.lua** (combat-safe deferred binding updates)
   - **Core/RuntimeBootstrap.lua** (startup sequence)
   Then feature modules, including **Core/FreeLookController.lua** for mouselook transitions and **Core/Crosshair.lua**.
5. **CombatMode/UI/Options/** — options window toolkit: **Draw.lua** then **Widgets.lua** (both define `CM.UI`), then **OptionsPanel.lua** (defines `CM.UI.Options.AddTab` / `CM.UI.CreateWindow` / `CM.OpenOptions`), then **Tabs/Tab*.lua** (each registers a tab via `AddTab`).
6. **CombatMode/Config/** — **ConfigNamespace.lua** first (defines `CM.Config`), then **ConfigChangelogData.lua** + **ConfigChangelogPanel.lua**, then the standalone editors (**ReticleCVarEditorData/Panel.lua**, **TargetingMacroPrelinesEditor.lua**); these load after the `UI/Options` toolkit they consume.
7. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; scripts call globals defined in **CombatMode/Core/Runtime.lua**.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** standalone movable window `CombatModeOptionsFrame` opened by `CM.OpenOptions()` (bound to `/cm` and the first-login popup); tabs registered via `CM.UI.Options.AddTab` in `UI/Options/Tabs/`. No longer listed under Blizzard settings → AddOns.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (sidebar footer → View Changelog, or auto after version bump via `Core/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `Config/ConfigChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.
