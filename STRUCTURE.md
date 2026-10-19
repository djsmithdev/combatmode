# CombatMode add-on layout

High-level domain map: [README — Architecture](README.md#architecture).
Folder map and per-domain notes: [`.claude/rules/`](.claude/rules/) (`architecture-and-style.md`, `domain-*.md`); ownership per module lives in each Lua file header.
Load order is defined in [`CombatMode/Embeds.xml`](CombatMode/Embeds.xml) (included
from [`CombatMode/CombatMode.toc`](CombatMode/CombatMode.toc)).

When you move or rename modules, update this file, `Embeds.xml`, the matching `.claude/rules/domain-*.md` note, and touched Lua headers in the same change (see `CLAUDE.md`, "Working agreements").

## Load order (scripts)

1. **CombatMode/Core/Runtime/Runtime.lua** — receives the AddOn namespace (`local addonName, CM = ...`), optional `_G.CM` alias, registers `ADDON_LOADED` / `PLAYER_LOGIN` lifecycle, native `CombatModeDB` merge, and slash commands (`/cm`, `/combatmode`).
2. **CombatMode/Constants/** — constants/data modules initialize `CM.Constants` and must load before feature consumers (`Namespace.lua` first).
3. **CombatMode/Core/Dev/** — developer tools with no production impact when idle:
   - **FunctionProfiler.lua** (zero-overhead `C_AddOnProfiler.MeasureCall` wrapper; gated by Debug Mode toggle)
4. **CombatMode/Core/Runtime/** — remaining runtime support scripts:
   - **EventRouter.lua** (event routing + `_G.CombatMode_OnEvent`)
   - **CVarManager.lua** (all CVar-writing helpers; reticle preset + `reticleTargetingCVarOverrides` → `CM.GetEffectiveReticleTargetingCVarValues`)
   - **BindingQueue.lua** (combat-safe deferred binding updates)
   - **UserLuaCondition.lua** (cached `loadstring` evaluator for user-authored Lua conditions)
   - **Bootstrap.lua** (startup sequence)
5. **CombatMode/Core/ClickCasting/**, **FreeLook/**, **Crosshair/**, **AllyCycle/** — feature modules (see `Embeds.xml` for exact order). **Vignette.lua** loads after FreeLook (fades with Mouse Look).
6. **CombatMode/UI/Options/** — options window toolkit: **Draw.lua** then **LuaCodeBox.lua** (Lua coloring, auto-indent, syntax / unknown-API diagnostics and name suggestions for `lua = true` text inputs) then **Widgets.lua** then **SpellMultiSelect.lua** then **MountMultiSelect.lua** and **FrameMultiSelect.lua** (all define `CM.UI` pieces), then **OptionsPanel.lua** (defines `CM.UI.Options.AddTab` / `CM.UI.CreateWindow` / `CM.OpenOptions`), then **OptionsSearch.lua** (title-bar search: index, dropdown, navigation), then **ColorPickerDialog.lua** (themed `ColorSelect` picker for swatches), then **BlizzardSettingsBridge.lua** (AddOns panel shortcut), then **Tabs/Tab*.lua** (each registers a tab via `AddTab`).
7. **CombatMode/UI/Wizard/** — first-run setup wizard: **Spotlight.lua** (`UI.ShowSpotlight`: dimmed screen with a hole around one widget plus an explanation balloon) then **SetupWizard.lua** (`CM.Wizard.Start`: a guided tour through the real options tabs via `Options.FocusControl`, one setting per step). Started by the first-login welcome popup (`char.seenWizard`) and the cog beside the version chip in the options header.
8. **CombatMode/UI/Changelog/** — **ChangelogNamespace.lua** first (defines `CM.Config`), then **ChangelogData.lua** + **ChangelogPanel.lua**; and **CombatMode/UI/Editors/** — the standalone editors (**ReticleCVarEditorData/Panel.lua**, **TargetingMacroPrelinesEditor.lua**, **ComposedMacroEditor.lua** (Macro Composer, opened by the + in the Reticle Targeting tab's Reticle Targeting Macros shelf; `Core/ClickCasting/ComposedMacros.lua` builds preline + body macros), **CrosshairColorsEditor.lua**, **CrosshairTextureEditor.lua** (texture browser: pick Inactive/Active crosshair textures from the catalog in `Constants/Assets.lua`, opened from the Crosshair and Advanced tabs)). Both load after the `UI/Options` toolkit they consume.
8. **Frame** — `CombatModeFrame` XML in `CombatMode/Embeds.xml`; `OnEvent` / `OnUpdate` call globals defined in Core. Events are registered on this frame during `CM:OnEnable()`.

## Public entry points

- **Slash:** `/cm`, `/combatmode` (Core/Runtime). Uninstall is the options sidebar button (`CM.UninstallCombatMode`), not a slash command.
- **Options:** standalone movable window `CombatModeOptionsFrame` opened by `CM.OpenOptions()` (bound to `/acm`, the first-login popup, and Escape → Options → AddOns → Action Combat Mode via `UI/Options/BlizzardSettingsBridge.lua`); tabs registered via `CM.UI.Options.AddTab` in `UI/Options/Tabs/`.
- **Changelog (in-game):** `CM.Config.ShowChangelog()` (sidebar footer → Changelog, or auto after version bump via `Core/Runtime/Runtime.lua` + `CM.Config.MaybeShowChangelogOnNewVersion`); body string `CM.Config.ChangelogText` in `UI/Changelog/ChangelogData.lua`, maintained from `CombatMode/CHANGELOG.md` with `scripts/sync-changelog-to-lua.ps1`.