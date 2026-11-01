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
- `InCombatLockdown()` is not the whole permission test: `C_RestrictedActions.CheckAllowProtectedFunctions(frame, silent)` asks whether this caller may call protected functions on that frame (`silent` only hides the error, it permits nothing).
- `ADDON_RESTRICTION_STATE_CHANGED(type, state)`: read the payload `state`; `C_RestrictedActions.IsAddOnRestrictionActive` always returns `false` during that event's dispatch.

## Secret values and instance taint (Mainline)

Unit identity and many measures are **secret** in instances while execution is tainted; comparing or branching on them raises Lua errors.

Never on possibly secret values: `==`/`~=`/`<`/`>` on `UnitGUID`, cast GUIDs, `UnitReaction`, raw `UnitHealth`/widths/alphas, secret strings; truth-testing secret booleans (`if UnitIsDeadOrGhost(u) then`); `#`/`:sub`/`strfind`/`tostring` as a compare key; arithmetic then compare; a secret as a **table key** or indexed (`cache[guid] = x`, `secret.field`: both error, so GUID/name-keyed tables go through `issecretvalue` first).

Allowed on secrets: store in variables/table values, pass to functions, `type(v)` (real type), concatenate / `string.format` / `SetFormattedText` for display. The result is still secret: show it, never compare or key on it.

Returned tables can be secret too (e.g. aura data): `canaccesstable(t)` before indexing or iterating. `issecretvalue(v)` says whether `v` is secret; `canaccessvalue(v)` says whether this caller may operate on it.

`pcall` contains a missing/blocked API; it never makes a secret readable. Neither does `tostring`, serialization or a wrapper table.

Instead:
- `issecretvalue(v)` before any branch/compare; treat secret as unknown and fail soft (base tint, skip filter, placeholder `"…"`).
- Booleans: `PublicBool` pattern (secret → `nil`; branch only on public `true`/`false`). Numbers: `PublicNumber(v, fallback)` before compare/arithmetic.
- Identity: `UnitExists`, `UnitIsUnit`, plate/frame identity — not GUID equality.
- Cast GUID match: if either side is secret treat as compatible for the single in-flight cast; deferred cancel uses a public generation token.
- Health/dead styling: `UnitHealthPercent` + color curves / `C_CurveUtil.EvaluateColorFromBoolean`; never compare raw secret health fractions.
- Presence: `UnitExists` first; for a GUID use `issecretvalue(guid)` as presence, never `guid ~= nil`.

Reference modules: `Core/Crosshair/{Crosshair,FocusNameplateMarker,Animations}.lua`, `AssistedHighlight/{Interact,CastProgress}.lua`, `Core/AllyCycle/{Target,HealthBar,Motion,HUD}.lua`.

## Other clients (Forever, Classic family)

- Retail gate: `CM.IsRetailClient` (`Constants/Namespace.lua`): Mainline project ID **and** interface `>= 20000`. Forever is interface 16000-19999 (`IS_FOREVER` in `Core/RadialMenu/Actions.lua`). The project ID alone is unreliable: early Forever builds reported Mainline (1), current ones `WOW_PROJECT_CAMELOT` (18). Use the named constants, never magic numbers. When a feature is just an API, check the API instead of the client (`CM.IsInPetBattle` checks `C_PetBattles.IsInBattle`).
- Forever has the same secret model as Retail (same API flags: `UnitHealth` always secret, `UnitGUID`/`UnitName` secret when identity is restricted). Every rule above applies there; no Forever shortcuts.
- Current Classic and Era source also declare `issecretvalue` / `canaccesstable` / `canaccessvalue`; older clients may not. Capture them as `local issecretvalue = _G.issecretvalue` and handle `nil` (no secrets on that client).
- Blizzard frames, micro buttons, atlases and CVars differ per client: check existence and skip what is missing (`Constants/Atlas.lua`, `RadialMenu/Actions.lua` client availability, `CVarManager` Retail-only CVars).
- Forever can store saved booleans as `1`/`0`: `InitDatabase` coerces them; read flags through the existing helpers (`CM.DbBool`), never `== true` on raw DB values.
- The `wow-api` MCP reports Mainline only. For other clients check Blizzard's UI source on the `forever`, `classic` or `classic_era` branch.

## Taint, CVars and state

- Do not replace Blizzard globals/hooks unless required; keep helpers `local`; minimize work in `OnUpdate` / high-frequency events.
- CVars: write only through the owning module (CVarManager), only for explicit feature behavior.
- Runtime state (mouselook, targeting, overrides): every enable/apply has a matching disable/cleanup.
- Validate external inputs; early-return on invalid state; reuse constants/default tables. Data-shape migrations stay explicit and centralized in `InitDatabase`.
