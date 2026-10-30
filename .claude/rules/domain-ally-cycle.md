---
description: Ally Cycle roster, secure snippet, HUD and options notes
paths:
  - "CombatMode/Core/AllyCycle/**"
  - "CombatMode/UI/Options/Tabs/TabAllyCycle.lua"
---

# Ally Cycle

Files in `Core/AllyCycle/`, in load order:

- `Cycle` — SecureGroupHeader ASC/DESC roster + UP/DOWN via `SetOverrideBindingClick`, key-up only. Restore-if-lost reselects `lastUnit` when the hard target is missing or not assistable (`PlayerCanAssist`; RestrictedEnv has no `UnitIsUnit`), else takeNext. `ResetAllyCycleCursor` on `PLAYER_REGEN_ENABLED`. `skipPlayer` attribute defaults on, set out of combat from `IsAllyCycleSkipPlayer`. Offline / other-zone members are skipped via `away-<unit>` attributes mirrored out of combat by `CM.RefreshAllyCycleAvailability` (the snippet cannot call `UnitIsConnected` / `UnitIsVisible` / map APIs; distance alone never skips). `GetAllyCycleIndex` reuses a header-child scratch table.
- `Target` — friendly-hard-target gate / name / role / raid marker / index / range.
- `HealthBar` — widgetstatusbar + low-HP glow.
- `Motion` — Mouse Look fade, cycle slide, housing up/down arrow travel.
- `HUD` — cluster chrome + public APIs: name, raid marker above the name, UI-Frame role icon left of the bar, cycle index n/total plus arrow right of the bar. UNIT_HEALTH/MAXHEALTH only retint the bar; live range via `UNIT_IN_RANGE_UPDATE`; OnUpdate is fade/slide/glow/preview only; `CM.Profile` keys `AllyHUD:*` / `AllyCycle:*`. Cycle advance slides in via `NotifyAllyCycleHUD` and plays the Radial Menu's slice-aim click (`U_CHAT_SCROLL_BUTTON`); fades with Mouse Look (preview bypasses); dead / offline desaturate (offline keeps the last health, `Target.IsOffline`) with "Dead" / "Offline" in place of the name, refreshed on `UNIT_CONNECTION`; low-HP red bar glow; party/raid hard target only (not Interact NPCs), self when Skip Self is off. LAYOUT lives in `HUD.lua`; bar / role / arrow atlases live in HealthBar / Target / Motion.
- `AllyCycle` — façade / events. Enable = Up/Down keybinds bound.

Forever now supports secure snippets, so there is no client gate: the headers, wrap and binds run everywhere. Do not probe `loadstring_untainted` (not addon-visible) or `WOW_PROJECT_ID` (Forever reports as Mainline).

DB `global.allyCycle`: `showHud`, `hudSide` (default BOTTOM), `scale`, `padding` (default 24), `skipPlayer`, `restoreAllyAfterHarm`. Companion Distance sliders (DB `padding` keys) also live on Interaction HUD (`interactionHUDPadding`) and Combat Assist (`assistedHighlightPadding`); fallback `CrosshairCompanionOffsetX` (24). Options sliders right-click reset via `opts.default`. Options tab preview via `SetAllyCycleOptionsPreview` (do not reuse mouselook-gated Show/Hide). Help/harm targeting routing is in `domain-click-casting.md`.
