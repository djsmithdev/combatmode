---
description: Folder map, coding conventions and cross-cutting runtime notes for addon code
paths:
  - "CombatMode/**"
---

# Architecture and style

Ownership detail lives in the **Lua file headers**. Load order: `STRUCTURE.md` + `CombatMode/Embeds.xml`. Domain gotchas live in the sibling `domain-*.md` notes (loaded when you touch those folders).

## Folder map

- `CombatMode.toc` — metadata, `SavedVariables: CombatModeDB`
- `Embeds.xml` — script load order + root frame `OnEvent` / `OnUpdate`
- `Constants/` — static tables (`Namespace.lua` first). Blizzard atlases are shipped as TGAs in `Assets/atlas/` and drawn through `CM.SetAtlas` / `CM.SetAtlasMask` / `CM.GetAtlasInfo` (`Constants/Atlas.lua`); never call `SetAtlas` with a client atlas for addon art. Art folders: `Assets/{branding,crosshair,assisthud,ui,atlas}`
- `Core/{Runtime,FreeLook,Crosshair,ClickCasting,AllyCycle,Dev}/` — runtime by domain; `Dev/` holds developer tools (profiler) with no production impact when idle. `Core/Vignette.lua` fades with Mouse Look.
- `UI/{Options,Changelog,Editors,Wizard}/` — options toolkit/tabs, in-game changelog, secondary editors, first-run wizard
- `Bindings.xml` — keybind declarations

## Coding conventions

- Per-file global aliases only (no shared `CM.API` alias module). Header order: AddOn namespace (`local _, CM = ...`; Runtime uses `local addonName, CM = ...`) → WoW API → Lua stdlib → module locals. Do not use `local CM = _G.CM`.
- Centralize events via `Constants/Gameplay.lua` (`BLIZZARD_EVENTS`; one event may belong to several categories) + `EventRouter`; no ad-hoc event frames.
- Extend existing `CM` APIs; keep DB scope intentional (`CM.DB.global` vs `CM.DB.char`).
- New settings → matching `UI/Options/Tabs/Tab*.lua` via `ctx:*` helpers + `CM.UI.Options.AddTab` (see the `new-option` skill).
- Preserve slash commands and keybinds unless explicitly changing them. Call out behavior changes that affect mouselook, targeting CVars, or binding overrides.

## Cross-cutting runtime notes

- **Root frame events:** `CombatMode_OnEvent(self, event, ...)` — first arg is the frame, not the event name.
- **DB shape:** AceDB-compatible (`CombatModeDB.global` + `char["Name - Realm"]`); defaults merge in `CM.InitDatabase`. Forever may store toggles as `1`/`0` — `InitDatabase` coerces those to real booleans via `CM.DbBool` / `NormalizeBools` wherever defaults declare a boolean.
- **Function Profiler (`Core/Dev/FunctionProfiler.lua`):** wrapper around `C_AddOnProfiler.MeasureCall`. Debug Mode ON starts profiling, OFF dumps the report to chat. `CM.Profile(key, func, ...)` wraps individual calls; when profiling is off it is a transparent zero-overhead pass-through, so keep wrappers in production code. `CM.StartProfiling()` / `CM.StopAndReportProfiling()` are public.
