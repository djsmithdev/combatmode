# CombatMode add-on layout

Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **CombatMode/Libs/** | Embedded libraries (LibStub, Ace3, LibEditMode, …); treat as vendored code per `.cursor/rules/combatmode-vendored-libs.mdc`. |
| **CombatMode/Constants/** | Static tables and constants consumed by runtime modules (frame watch tables, radial data, reticle data, etc.). |
| **CombatMode/Core/** | Runtime behavior modules: addon lifecycle + dispatch, dedicated free-look controller, crosshair/reticle targeting, click overrides, cursor unlock, healing radial, plus supporting modules (animations, interaction HUD, macro builders, addon bar resolvers). |
| **CombatMode/Config/** | AceConfig option tables (`Config*.lua`), shared UI helpers (`ConfigShared.lua`), assembly (`ConfigCategories.lua` → `CM.Config.OptionCategories`), in-game changelog (`ConfigChangelogData.lua` + `ConfigChangelogPanel.lua`; body synced from `CombatMode/CHANGELOG.md` via `scripts/sync-changelog-to-lua.ps1`), plus standalone editors: Reticle CVar (`ReticleCVarEditorData.lua`, `ReticleCVarEditorPanel.lua`; account overrides in `CM.DB.global.reticleTargetingCVarOverrides`, merged at runtime via `Core/RuntimeCVarManager.lua`) and Targeting Macro Prelines (`TargetingMacroPrelinesEditor.lua`). |
| **CombatMode/UI/** | Non-AceConfig client UI (e.g. LibEditMode crosshair registration and preview). |
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
   Then feature modules, including **Core/FreeLookController.lua** for mouselook transitions, and **CombatMode/UI/CrosshairEditMode.lua** after **CombatMode/Core/Crosshair.lua** (Edit Mode uses `CM` APIs).
5. **CombatMode/Config/** — `ConfigShared.lua` first (defines `CM.Config.OptionsUI`), then **ConfigChangelogData.lua** and **ConfigChangelogPanel.lua** (before **ConfigAbout.lua**), then each remaining `Config*.lua`. Standalone editors load in `Embeds.xml` before the category that opens them (e.g. **ReticleCVarEditor** + **TargetingMacroPrelinesEditor** before **ConfigReticleTargeting.lua**), then **ConfigCategories.lua** (wires `CM.Config.OptionCategories`).
6. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; scripts call globals defined in **CombatMode/Core/Runtime.lua**.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** Blizzard settings → Combat Mode; trees built from `CM.Config.AboutOptions` and `CM.Config.OptionCategories`.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (About → View Changelog, or auto after version bump via `Core/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `Config/ConfigChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.
