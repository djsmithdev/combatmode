# Patterns and policy

## Meta: document what you learn

When you fix a non-obvious bug or establish a new convention, record it briefly here **or** update the relevant `.cursor/rules/*.mdc` file—**not both** with full duplication. Link to the file or rule name.

Suggested buckets (map to existing rules):

- **Taint / secure UI / combat lockdown** → `.cursor/rules/combatmode-lua-safety.mdc`
- **Architecture and module ownership** → `.cursor/rules/combatmode-architecture-and-style.mdc`
- **UI (options window, frames)** → architecture doc + `CombatMode/UI/Options/*` and `TabCrosshair.lua` headers

## CombatMode-specific reminders

- **Mouselook / free-look / CVars:** free-look state machine lives in `Core/FreeLookController.lua`; **all addon-owned `SetCVar` writes route through** `Core/RuntimeCVarManager.lua` (`CM.SetCVar*` helpers). Modules should compute/decide values locally, then call the manager to perform the write. Keep enable/disable paths symmetric.
- **Free-look / OPie / CursorFreelookCentering:** lock applies centering with the HealingRadial pattern: force CVar `0` → `MouselookStart` → deferred `1`. Writing `1` mid-look (or starting while already `1`) can leave the cursor visible (10.2 quirk in `ConstantsCVars`). OPie `MouselookStop`s itself and `AutoCursorUnlock` frees centering; `CM.NotifyOpieUnlockFrameVisible` latches that, and Runtime calls `CM.RematchFreeLookAfterOpieIfNeeded()` on the next “should be locked” tick to bounce rematch. Prefer this over mid-look CVar writes.
- **Override bindings / secure buttons:** follow existing `SecureActionButtonTemplate` and `Core/BindingOverrides.lua` patterns.
- **Options UI:** settings live in a **standalone custom window** (`CombatModeOptionsFrame`, opened by `CM.OpenOptions()` / `/cm`), **not** Blizzard settings. Build tabs in `UI/Options/Tabs/Tab*.lua` with the `ctx:Toggle/Slider/Dropdown/Keybind/TextInput/Button/Card` helpers; wire get/set/disabled closures to existing `CM.*` APIs + `CM.DB`. Every value control auto-registers with `CM.UI.Options.Sync()` — call `Options.Sync()` (widgets do this after set) so dependent `disabled` states refresh. Toolkit primitives are in `UI/Options/Draw.lua` (theme tokens `CM.UI.Colors` / `UI.Fonts` / `UI.Radius`) + `UI/Options/Widgets.lua`; standalone editors reuse `CM.UI.CreateWindow`. The theme is deliberately monochrome: all text renders at `UI.Fonts.base` with inline `|cff..|` markup stripped by `UI.StripColors`, and the accent yellow is reserved for section headers, the selected tab, and toggle on-states (grey when off) — do not reintroduce per-feature colors in tab builders.
- **Options live preview:** tabs that need on-screen feedback use `onSelect`/`onDeselect` (see `OptionsPanel` ActivateTab/DeactivateTab). Crosshair → `CM.SetCrosshairOptionsPreview`; Party Radial → `CM.HealingRadial.SetOptionsPreview` (layout-only: no freelook unlock, keep `IsActive` false, placeholders for empty slices). Do not reuse gameplay `Show`/`Hide` for options previews when those paths require mouselook.
- **Namespace / DB:** modules use `local _, CM = ...` (Blizzard AddOn namespace; Runtime also sets optional `_G.CM = CM` for debug). SavedVariables keep AceDB-compatible shape (`CombatModeDB.global` + `CombatModeDB.char["Name - Realm"]`); nested defaults merge lives in `CM.InitDatabase`.
- **Root frame events:** `CombatModeFrame` XML `OnEvent` calls `_G.CombatMode_OnEvent(self, event, ...)`. Do not treat the first argument as the event name (that was AceEvent’s call shape). Rematch (`PLAYER_ENTERING_WORLD`) depends on this.
- **Vendored libs:** Ace3/LibStub are removed. If reintroducing libs under `CombatMode/Libs/**`, see `.cursor/rules/combatmode-vendored-libs.mdc`.

## Index of canonical rules

| Topic | Location |
| --- | --- |
| WoW MCP workflow | `.cursor/rules/wow-mcp-first.mdc` |
| Module map | `.cursor/rules/combatmode-architecture-and-style.mdc` |
| Lua safety | `.cursor/rules/combatmode-lua-safety.mdc` |
| Change checklist | `.cursor/rules/combatmode-change-checklist.mdc` |
| Release process | `.cursor/rules/combatmode-release-flow.mdc` + `RELEASE.md` |
