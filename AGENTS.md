# CombatMode Agent Playbook

This file defines how AI agents should work in this addon workspace.

## Primary references

1. Use WoW API MCP tools first (`lookup_api`, `search_api`, `list_deprecated`, `get_event`, `get_enum`).
2. Follow architecture docs and in-file header purpose comments.
3. Fall back to external docs only when MCP/tooling cannot answer.

## Project map

- `CombatMode.toc`: metadata, SavedVariables, top-level include.
- `Embeds.xml`: load order and root frame script wiring.
- `Features/`: runtime behavior modules.
- `Config/`: AceConfig option builders and options assembly.
- `UI/`: non-Ace UI integrations (Edit Mode crosshair).
- `Bindings.xml`: keybind declarations.

See `STRUCTURE.md` for load-order details.

## Implementation expectations

- Keep behavior changes local to the owning module.
- Preserve centralized event wiring and core dispatch patterns.
- Respect combat lockdown and secure frame constraints.
- Avoid introducing globals unless explicitly required.
- Put user-facing settings into `Config/*Options.lua` and wire in `Config/Config.lua`.
- Keep DB scope intentional (`CM.DB.global` vs `CM.DB.char`).

## Before finishing a change

- Verify deprecations/replacements via WoW MCP tools.
- Confirm no combat-unsafe paths were introduced.
- Validate enable/disable symmetry for runtime state (mouselook/CVars/bindings).
- Ensure docs/rule updates if architecture or workflow changed.
