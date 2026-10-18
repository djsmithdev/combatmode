---
name: secret-audit
description: Audit changed (or named) addon Lua for secret-value misuse — compares, truth tests, length/concat or arithmetic on values that can be secret in instances. Use before finishing any change touching unit, health, cast, name, or nameplate data.
---

# Secret-value audit

Target: `git diff` of `CombatMode/**.lua` (staged + unstaged), or the files/functions the user names. Rules: `.claude/rules/lua-safety.md`.

1. Find every value that can be secret: `UnitGUID`, cast GUIDs, `UnitName`/`UnitFullName`, `UnitReaction`, `UnitHealth*`/`UnitPower*`, `UnitIsDeadOrGhost`, `UnitCanAttack`/`UnitIsEnemy` style booleans, `UnitCastingInfo`/`UnitChannelInfo` returns, aura data, nameplate/bar measures (`GetWidth`, `GetAlpha`, `GetValue`), texture paths/atlas names read back from frames, and anything derived from them.
2. For each, trace to its use and flag any of: `==`/`~=`/`<`/`>` against it; `if v then` / `not v` / `and`/`or` on a possibly secret boolean; `#`, `:sub`, `strfind`, `tostring`, `..`, `string.format` on a secret string; use as a table key; arithmetic followed by a compare; passing it to a helper that does one of these.
3. Accept as safe: guarded by `issecretvalue` first with a fail-soft branch; routed through `PublicBool` / `PublicNumber`; used only as an argument to an API that takes secrets (e.g. `SetStatusBarColor`, color curves, `UnitHealthPercent` with curves); `UnitExists` / `UnitIsUnit` presence checks.
4. Check the fallbacks: secret → unknown must degrade quietly (base tint, skip, placeholder), never throw and never cache a wrong "public" answer.
5. Cross-check against existing patterns in `Core/Crosshair/{Crosshair,FocusNameplateMarker}.lua`, `AssistedHighlight/{Interact,CastProgress}.lua`, `Core/AllyCycle/{Target,HealthBar,HUD}.lua` and reuse their helpers instead of writing new ones.
6. Report as a table: `file:line | value | problem | fix`. Say plainly if nothing is wrong, and list anything you couldn't classify. Verify unsure API return behavior with the `wow-api` MCP; flag what only a live instance can confirm. Don't edit unless asked.
