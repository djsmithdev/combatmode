---
name: secure-audit
description: Audit changed addon Lua for combat-lockdown and secure-environment problems — protected calls in combat, unqueued binding/attribute changes, and secure snippets using unavailable APIs. Use before finishing changes to bindings, secure frames, click casting or Ally Cycle.
---

# Combat-lockdown / secure audit

Target: `git diff` of `CombatMode/**.lua` and `Bindings.xml`, or what the user names. Rules: `.claude/rules/lua-safety.md`, `.claude/rules/domain-runtime.md` (BindingQueue).

1. **Protected calls** — find `SetAttribute`, `SetOverrideBinding*`, `ClearOverrideBindings`, `SetBinding`/`SaveBindings`, `CreateMacro`/`EditMacro`/`DeleteMacro`, `RegisterForClicks`, and `EnableMouse` / `SetPoint` / `SetSize` / `Show` / `Hide` / `SetHitRectInsets` on secure or protected frames. Each must be reachable only out of combat: guarded by `InCombatLockdown()` or routed through `CM.TryApplyBindingChange`; a lockdown hit must **queue and flush on `PLAYER_REGEN_ENABLED`** (`FlushDeferredBindingChanges`, `FlushPendingClickCastRefresh`, Ally Cycle `pendingRoster`), not silently drop.
2. **Triggers** — check what can call the code in combat: event handlers, `OnUpdate`, `C_Timer` callbacks, hooks on Blizzard frames, options-UI callbacks. A function that is safe by itself can be called from a combat event.
3. **Secure snippets** (`SecureHandlerWrapScript`, `SecureHandlerSetFrameRef`, `SetAttribute("_onclick", …)`, macrotext): the restricted environment has only a handful of unit APIs (`UnitExists`, `UnitIsDead`, `UnitIsGhost`, `PlayerCanAssist`/`PlayerCanAttack`, …) and no `UnitIsUnit` / `UnitIsConnected` / `UnitIsVisible` / map APIs. Flag unavailable calls, unbounded loops and global access. Anything else is computed insecurely and pushed in as attributes **out of combat** (see Ally Cycle `away-<unit>` and `skipPlayer`).
4. **Macrotext** — length ≤ 255 (`SECURE_MACROTEXT_MAX`), no nested `/click` of a macro button (silent no-op), conditionals with `@unit` groups include `exists`/`noexists`, preline stays first.
5. **Symmetry** — every apply path has its clear/restore path (bindings restored on disable and uninstall, CVar snapshot restored, override bindings cleared), including the "disabled while in combat" case.
6. **Taint** — no replaced Blizzard globals; hooks use `hooksecurefunc`; new helpers are `local`.
7. Report `file:line | call | how it can run in combat | fix`. Say plainly when clean, and list what only a live client can prove (e.g. real lockdown behavior, restricted-environment API availability). Verify API protection status with the `wow-api` MCP. Don't edit unless asked.
