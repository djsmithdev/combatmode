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

Durable notes in the architecture rule include FlipBook/atlas VFX lookup (TextureAtlasViewer / wow-ui-source / peer addons — not `GetAtlasInfo`).

## Layout (quick)

- Installable addon lives under **`CombatMode/`**, not the repo root.
- Domains: `Core/{Runtime,FreeLook,Crosshair,ClickCasting,PartyRadial}`, `Constants/`, `UI/{Options,Changelog,Editors}`. Crosshair companions: `InteractionHUD/` (Target, Visual, HUD), `AssistedHighlight/` (Keybinds, Motion, CastProgress, Feedback, Assist), and `FocusNameplateMarker`. Party Radial companions: `PartyData` → `SecureBindings` → `HealthBars` → `RoleIcons` → `Visual` → `Lifecycle` → `PartyRadial` (façade).
- No vendored Ace3/LibStub — do not add `CombatMode/Libs/**` unless asked.

## Finish

Follow `.cursor/rules/combatmode-change-checklist.mdc` (lint changed Lua; **ask** before TOC / changelog / sync).

## Optional

- Specialist: `.claude/agents/combatmode-wow-specialist.md` (WoW API + ownership + lockdown).
- Human docs: `README.md` (architecture blurb), `CONTRIBUTING.md` (first-hour path: toggle / constant / secrets / docs-cold), `RELEASE.md`, `TESTING.md`, `CombatMode/CHANGELOG.md`.
