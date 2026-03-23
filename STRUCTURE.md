# CombatMode add-on layout

Load order is defined in [`Embeds.xml`](Embeds.xml) (included from [`CombatMode.toc`](CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **Libs/** | Embedded libraries (LibStub, Ace3, LibEditMode, …); treat as vendored code per `.cursor/rules/combatmode-vendored-libs.mdc`. |
| **Constants/** | Static tables and constants consumed by runtime modules (frame watch tables, radial data, reticle data, etc.). |
| **Features/** | Runtime behavior modules: AceAddon shell, crosshair, click overrides, pulse, cursor unlock, healing radial. |
| **Config/** | AceConfig option tables (`Config*.lua`), shared UI helpers (`ConfigShared.lua`), and assembly (`ConfigCategories.lua` → `CM.Config.OptionCategories`). |
| **UI/** | Non–AceConfig client UI (e.g. LibEditMode crosshair registration and preview). |
| **assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **Libs** — dependency order preserved in `Embeds.xml`.
2. **Features/Core.lua** — must run first so `AceAddon:NewAddon("CombatMode")` exists.
3. **Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers.
4. **Features/** — remaining behavior scripts, then **UI/CrosshairEditMode.lua** after **Features/Reticle.lua** (Edit Mode uses `CM` APIs from Reticle).
5. **Config/** — `ConfigShared.lua` first (defines `CM.Config.OptionsUI`), then each `Config*.lua`, then **ConfigCategories.lua** (wires `CM.Config.OptionCategories`).
6. **Frame** — `CombatModeFrame` XML; scripts call globals defined in **Features/Core.lua**.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** Blizzard settings → Combat Mode; trees built from `CM.Config.AboutOptions` and `CM.Config.OptionCategories`.
