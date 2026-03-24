# Claude / multi-tool entry

Layered context for Claude Code and similar agents. **Cursor-specific rules** remain in `.cursor/rules/*.mdc`; this file composes portable `.context/` docs and points to the full playbook.

@.context/project.md
@.context/api.md
@.context/patterns.md

Also read **`AGENTS.md`** for the rule map, project map, and finish checklist (authoritative for this repo).

## Evidence

Do not ship behavior changes based on memory alone. Confirm WoW API usage with MCP tools or project code; cite or point to the defining module when changing runtime behavior.

## Pattern learning

When you discover a durable pattern (debugging technique, API workaround, architecture decision), add a short entry to `.context/patterns.md` (or extend the linked `.cursor/rules` notes if that is more appropriate). Prefer one source of truth—avoid duplicating long policy text.

## Finish requirements

Match **`AGENTS.md`**: pre-commit on changed Lua, Selene/Stylua as in contributor workflow, no combat-unsafe paths, enable/disable symmetry for mouselook/CVars/bindings when touched.
