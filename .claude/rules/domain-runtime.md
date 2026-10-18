---
description: Addon shell, DB init/migrations, event routing, binding queue, bootstrap, constants
paths:
  - "CombatMode/Core/Runtime/**"
  - "CombatMode/Constants/**"
  - "CombatMode/Embeds.xml"
  - "CombatMode/CombatMode.toc"
  - "CombatMode/Bindings.xml"
---

# Runtime shell, events and constants

- **Runtime.lua** — `local addonName, CM = ...`; lifecycle (`ADDON_LOADED` / `PLAYER_LOGIN` → `OnInitialize` / `OnEnable`), slash `/acm` `/actioncombatmode`, throttled `CombatMode_OnUpdate` (`ReconcileFreeLook` + crosshair reaction), welcome/changelog scheduling, `UninstallCombatMode` (restores `priorCVarSnapshot` and BUTTON1/2 camera binds, then `ReloadUI`). `GetBindingsLocation` → `"global"` vs `"char"` from `useGlobalBindings`.
- **InitDatabase** merges `Constants.DatabaseDefaults` into `global` + `char["Name - Realm"]`, then coerces Forever's `1`/`0` to booleans (`CM.DbBool` / `NormalizeBools`). **Every data-shape change (rename, removed feature, reshaped table) is an explicit, commented migration here**, never in a feature module. Existing ones drop `partyRadial`, convert `reticleHideSoftIndicator` → `selectionCircleMode` and `assistedHighlightEnabled` → `assistedHighlightMode`, drop the merged `interactionHUD*` keys, disable click-cast slots using removed Toggle Focus actions, and rewrite the old situational default.
- **EventRouter.lua** — `eventCategoryMap` is built from `Constants.BLIZZARD_EVENTS`; `CombatMode_OnEvent(self, event, ...)` dispatches by category (one event may be in several). `REFRESH_BINDINGS_EVENTS` are coalesced through `C_Timer` so bursts run one `RefreshClickCastMacros`; self-echo events during apply are suppressed. A new event = add to a `BLIZZARD_EVENTS` category in `Constants/Gameplay.lua` + a handler in `EventRouter`; it never registers events itself.
- **BindingQueue.lua** — `TryApplyBindingChange(context, applyFn)` runs now out of combat, else queues; `FlushDeferredBindingChanges` (on `PLAYER_REGEN_ENABLED`) pcalls each closure. Callers pass closures; it doesn't build macros or bindings itself.
- **Bootstrap.lua** — ordered enable sequence (CVar snapshot, overrides, frame tracking, crosshair, legacy macro cleanup, MoveAndSteer → Mouse Look rebind, Ally Cycle init). `RemoveLegacyMacros` deletes old `CM_` macros that still hold our text and aren't on a bar, so never name addon-created macros `CM_*`.
- **UserLuaCondition.lua** — `CM.EvaluateUserLuaCondition(source, cache, label)` compiles user Lua with `loadstring` (cached per consumer; empty → false; errors logged throttled, return false). Used by Auto Unlock, Mouse Look force lock, crosshair situational texture. Treat the source as untrusted input: never pass secrets or write APIs into its environment.
- **Constants** — static data only (`Namespace.lua` first). `Gameplay.lua` holds `BLIZZARD_EVENTS`, `ClickCastBars` (ACTIONBUTTON + MULTIACTIONBAR1–7, MultiBar5–7 = 145/157/169 bases), `ActionsToProcess` / `OverrideActions` / `ButtonsToOverride`, and `ReticleTargetingBuiltinExcludeSpellIds` (skyriding). `DatabaseDefaults.lua` is the single place for defaults. Check `Constants/CVars.lua` + `Core/Runtime/CVarManager.lua` + the CVar editor data together when touching reticle CVars.
- `Embeds.xml` is the load order (and the root frame `OnEvent` / `OnUpdate`); `Bindings.xml` declares keybinds (names are internal "Combat Mode" IDs; the category label says "Action Combat Mode"). The TOC lists many client interface numbers; don't change them without being asked.
