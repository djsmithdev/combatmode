# CombatMode add-on layout

Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **CombatMode/Libs/** | Embedded libraries (LibStub, Ace3, LibEditMode, …); treat as vendored code per `.cursor/rules/combatmode-vendored-libs.mdc`. |
| **CombatMode/Constants/** | Static tables and constants consumed by runtime modules (frame watch tables, radial data, reticle data, etc.). |
| **CombatMode/Features/** | Runtime behavior modules: AceAddon shell, crosshair/reticle targeting, click overrides, cursor unlock, healing radial, plus supporting modules (animations, interaction HUD, macro builders, addon bar resolvers). |
| **CombatMode/Config/** | AceConfig option tables (`Config*.lua`), shared UI helpers (`ConfigShared.lua`), and assembly (`ConfigCategories.lua` → `CM.Config.OptionCategories`). |
| **CombatMode/UI/** | Non-AceConfig client UI (e.g. LibEditMode crosshair registration and preview). |
| **CombatMode/assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **CombatMode/Libs** — dependency order preserved in `CombatMode/Embeds.xml`.
2. **CombatMode/Features/Core.lua** — must run first so `AceAddon:NewAddon("CombatMode")` exists.
3. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers.
4. **CombatMode/Features/** — remaining behavior scripts, then **CombatMode/UI/CrosshairEditMode.lua** after **CombatMode/Features/Reticle.lua** (Edit Mode uses `CM` APIs from Reticle).
5. **CombatMode/Config/** — `ConfigShared.lua` first (defines `CM.Config.OptionsUI`), then each `Config*.lua`, then **ConfigCategories.lua** (wires `CM.Config.OptionCategories`).
6. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; scripts call globals defined in **CombatMode/Features/Core.lua**.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** Blizzard settings → Combat Mode; trees built from `CM.Config.AboutOptions` and `CM.Config.OptionCategories`.
