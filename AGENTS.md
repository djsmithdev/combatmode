# CombatMode Agent Playbook

How agents should work in this addon workspace.

## Source of truth

1. **`.cursor/rules/*.mdc`** — always-applied policy (MCP, architecture, Lua safety, finish checklist). Cursor loads these automatically; other tools should read the same files.
2. **Lua file headers** — default for every module: What it does / Architecture / Does not / Related.
3. **`STRUCTURE.md`** + **`CombatMode/Embeds.xml`** — load order.
4. **This file** — short index for non-Cursor agents.

## Rule map

| Topic | File |
| --- | --- |
| WoW MCP first | `.cursor/rules/wow-mcp-first.mdc` |
| Folder map + conventions + durable notes | `.cursor/rules/combatmode-architecture-and-style.mdc` |
| Combat lockdown / secret values / taint / CVar hygiene | `.cursor/rules/combatmode-lua-safety.mdc` |
| Finish a code change | `.cursor/rules/combatmode-change-checklist.mdc` |
| Docs/headers when architecture moves | `.cursor/rules/combatmode-docs-and-headers-stay-in-sync.mdc` |
| Release prep (manual / when asked) | `.cursor/rules/combatmode-release-flow.mdc` + `RELEASE.md` |

## Human docs

- `README.md` (architecture blurb), `CONTRIBUTING.md` (first-hour path), `TESTING.md` (smoke tests), `RELEASE.md` (release checklist), `CombatMode/CHANGELOG.md`.