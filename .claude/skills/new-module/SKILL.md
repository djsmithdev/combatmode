---
name: new-module
description: Add a new Lua file to the addon with the right header, load order, docs and lint. Use when creating CombatMode/**.lua.
---

# Add a Lua module

1. **Place it** in the owning domain folder (`Constants/`, `Core/<Domain>/`, `UI/...`). Prefer extending an existing module over a new file.
2. **Header** — first lines: `Path/File.lua — DOMAIN — short title`, then *What it does / Architecture / Does not / Related* (see an existing file in the same folder for tone).
3. **Prologue order** — `local _, CM = ...` → WoW API aliases (`local InCombatLockdown = _G.InCombatLockdown`, …) → Lua stdlib → module locals. No `local CM = _G.CM`, no shared alias module, no ad-hoc event frames (use `Constants/Gameplay.lua` + `EventRouter`).
4. **Load order** — add it to `CombatMode/Embeds.xml` after everything it consumes and before its callers; mirror that in `STRUCTURE.md`. Standalone editors go after the `UI/Options` toolkit.
5. **Docs** — add the module to the matching `.claude/rules/domain-*.md` only if it has a non-obvious gotcha; a header is the default home for ownership.
6. Run `/finish-change` (lint twice).
