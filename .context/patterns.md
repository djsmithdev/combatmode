# CombatMode patterns (agent notes)

## Module split (AssistedHighlight / PartyRadial)

Prefer thin domain modules ending in a façade that re-exports the public `CM.*` API.

- **AssistedHighlight:** `Keybinds` → `Motion` → `CastProgress` → `Feedback` → `Assist` (façade). Export as `CM.AssistedHighlightXxx`; Assist owns public chrome APIs.
- **PartyRadial:** `PartyData` → `SecureBindings` → `HealthBars` → `RoleIcons` → `Visual` → `Lifecycle` → `PartyRadial` (façade). Bootstrap `CM.PartyRadial` + `RadialState` in `PartyData` (`HR.GetState`); siblings use `CM.PartyRadialXxx` and late-bind `CM.PartyRadial.*` where needed. Keep `Constants/PartyRadial.lua` for slice geometry, `PartyRadialLayout` / `PartyRadialHealthBar`, and role/atlas tables (not DB options).

## Secret-safe / instance taint

Canonical rules live in **`.cursor/rules/combatmode-lua-safety.mdc`** (Secret values and instance taint).

Summary: never `==`/`</>` on possibly secret UnitGUID/cast GUID/reaction/health/name/width; use `issecretvalue` first, `PublicBool` / `PublicNumber`, `UnitExists`/`UnitIsUnit`/frame identity, color curves / `EvaluateColorFromBoolean`, and combat-deferred binding flushes. Reference Crosshair, FocusNameplateMarker, CastProgress, InteractionHUD Target, PartyRadial HealthBars/RoleIcons/Visual.
