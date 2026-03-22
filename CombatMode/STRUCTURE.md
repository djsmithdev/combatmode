# CombatMode add-on layout

Load order is defined in [`Embeds.xml`](Embeds.xml) (included from [`CombatMode.toc`](CombatMode.toc)).

## Folders

| Folder | Role |
|--------|------|
| **Libs/** | Embedded libraries (LibStub, Ace3, LibEditMode, …). |
| **Features/** | Runtime modules: AceAddon shell, data, crosshair, click overrides, pulse, cursor unlock, healing radial. |
| **Config/** | AceConfig option tables (`*Options.lua`), shared UI helpers (`OptionsShared.lua`), and assembly (`Config.lua` → `CM.Config.OptionCategories`). |
| **UI/** | Non–AceConfig client UI (e.g. LibEditMode crosshair registration and preview). |
| **assets/** | Art and title textures referenced by the TOC and UI. |

## Load order (scripts)

1. **Libs** — dependency order preserved in `Embeds.xml`.
2. **Features/Core.lua** — must run **before** **Features/Constants.lua** so `AceAddon:NewAddon("CombatMode")` exists; Constants attaches `CM.Constants` via `GetAddon("CombatMode")`.
3. **Features/** — remaining feature scripts, then **UI/CrosshairEditMode.lua** after **Features/Reticle.lua** (Edit Mode uses `CM` APIs from Reticle).
4. **Config/** — `OptionsShared.lua` first (defines `CM.Config.OptionsUI`), then each `*Options.lua`, then **Config.lua** (wires `CM.Config.OptionCategories`).
5. **Frame** — `CombatModeFrame` XML; scripts call globals defined in **Features/Core.lua**.

## Public entry points

- **Slash:** `/cm`, `/combatmode`, `/undocm` (Core).
- **Options:** Blizzard settings → Combat Mode; trees built from `CM.Config.AboutOptions` and `CM.Config.OptionCategories`.
