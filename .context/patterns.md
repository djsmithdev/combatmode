# Patterns and policy

## Meta: document what you learn

When you fix a non-obvious bug or establish a new convention, record it briefly here **or** update the relevant `.cursor/rules/*.mdc` file—**not both** with full duplication. Link to the file or rule name.

Suggested buckets (map to existing rules):

- **Taint / secure UI / combat lockdown** → `.cursor/rules/combatmode-lua-safety.mdc`
- **Architecture and module ownership** → `.cursor/rules/combatmode-architecture-and-style.mdc`
- **UI (Ace3, frames, Edit Mode crosshair)** → architecture doc + `CombatMode/UI/CrosshairEditMode.lua` headers

## CombatMode-specific reminders

- **Mouselook / free-look / CVars:** free-look state machine lives in `Core/FreeLookController.lua`; **all addon-owned `SetCVar` writes route through** `Core/RuntimeCVarManager.lua` (`CM.SetCVar*` helpers). Modules should compute/decide values locally, then call the manager to perform the write. Keep enable/disable paths symmetric.
- **Override bindings / secure buttons:** follow existing `SecureActionButtonTemplate` and `Core/BindingOverrides.lua` patterns.
- **Vendored libs:** do not rewrite `CombatMode/Libs/**`; see `.cursor/rules/combatmode-vendored-libs.mdc`.

## Index of canonical rules

| Topic | Location |
| --- | --- |
| WoW MCP workflow | `.cursor/rules/wow-mcp-first.mdc` |
| Module map | `.cursor/rules/combatmode-architecture-and-style.mdc` |
| Lua safety | `.cursor/rules/combatmode-lua-safety.mdc` |
| Change checklist | `.cursor/rules/combatmode-change-checklist.mdc` |
| Release process | `.cursor/rules/combatmode-release-flow.mdc` + `RELEASE.md` |
