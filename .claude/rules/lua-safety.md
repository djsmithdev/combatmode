---
description: Combat lockdown, secret-value and taint guardrails for all addon Lua
paths:
  - "CombatMode/**/*.lua"
---

# Lua safety

## Combat lockdown and secure flow

- Never perform protected UI actions in combat unless the API is explicitly combat-safe; guard with `InCombatLockdown()`.
- `EnableMouse`, `SetPoint`, `SetAttribute`, `SetHitRectInsets` on secure frames are protected in combat (error or silent no-op).
- Keep secure setup deterministic; avoid attribute churn in combat. Reuse existing secure patterns (`SecureActionButtonTemplate`, macrotext, override bindings).
- When a refresh hits lockdown, **queue and flush on `PLAYER_REGEN_ENABLED`** (Ally Cycle `pendingRoster`, `CM.FlushPendingClickCastRefresh` / BindingQueue). Never silently drop mid-combat bar/bind updates.
- The restricted environment (secure snippets) only has a few unit APIs (`UnitExists`, `UnitIsDead`, `UnitIsGhost`, `PlayerCanAssist/Attack`…); compute anything else insecurely and push it in as attributes out of combat.

## Secret values and instance taint (Mainline)

Unit identity and many measures are **secret** in instances while execution is tainted; comparing or branching on them raises Lua errors.

Never on possibly secret values: `==`/`~=`/`<`/`>` on `UnitGUID`, cast GUIDs, `UnitReaction`, raw `UnitHealth`/widths/alphas, secret strings; truth-testing secret booleans (`if UnitIsDeadOrGhost(u) then`); `#`/`:sub`/`strfind`/`tostring` as a compare key; arithmetic then compare.

Instead:
- `issecretvalue(v)` before any branch/compare; treat secret as unknown and fail soft (base tint, skip filter, placeholder `"…"`).
- Booleans: `PublicBool` pattern (secret → `nil`; branch only on public `true`/`false`). Numbers: `PublicNumber(v, fallback)` before compare/arithmetic.
- Identity: `UnitExists`, `UnitIsUnit`, plate/frame identity — not GUID equality.
- Cast GUID match: if either side is secret treat as compatible for the single in-flight cast; deferred cancel uses a public generation token.
- Health/dead styling: `UnitHealthPercent` + color curves / `C_CurveUtil.EvaluateColorFromBoolean`; never compare raw secret health fractions.
- Presence: `UnitExists` first; for a GUID use `issecretvalue(guid)` as presence, never `guid ~= nil`.

Reference modules: `Core/Crosshair/{Crosshair,FocusNameplateMarker,Animations}.lua`, `AssistedHighlight/{Interact,CastProgress}.lua`, `Core/AllyCycle/{Target,HealthBar,Motion,HUD}.lua`.

## Taint, CVars and state

- Do not replace Blizzard globals/hooks unless required; keep helpers `local`; minimize work in `OnUpdate` / high-frequency events.
- CVars: write only through the owning module (CVarManager), only for explicit feature behavior.
- Runtime state (mouselook, targeting, overrides): every enable/apply has a matching disable/cleanup.
- Validate external inputs; early-return on invalid state; reuse constants/default tables. Data-shape migrations stay explicit and centralized in `InitDatabase`.
