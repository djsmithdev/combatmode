# CombatMode patterns (agent notes)

## Module split (AssistedHighlight / PartyRadial)

Prefer thin domain modules ending in a façade that re-exports the public `CM.*` API.

- **AssistedHighlight:** `Keybinds` → `Motion` → `CastProgress` → `Feedback` → `Assist` (façade). Export as `CM.AssistedHighlightXxx`; Assist owns public chrome APIs.
- **PartyRadial:** `PartyData` → `SecureBindings` → `HealthBars` → `RoleIcons` → `Visual` → `Lifecycle` → `PartyRadial` (façade). Bootstrap `CM.PartyRadial` + `RadialState` in `PartyData` (`HR.GetState`); siblings use `CM.PartyRadialXxx` and late-bind `CM.PartyRadial.*` where needed. Keep `Constants/PartyRadial.lua` for slice geometry, `PartyRadialLayout` / `PartyRadialHealthBar`, and role/atlas tables (not DB options).

## Secret-safe / instance taint

Canonical rules live in **`.cursor/rules/combatmode-lua-safety.mdc`** (Secret values and instance taint).

Summary: never `==`/`</>` on possibly secret UnitGUID/cast GUID/reaction/health/name/width; use `issecretvalue` first, `PublicBool` / `PublicNumber`, `UnitExists`/`UnitIsUnit`/frame identity, color curves / `EvaluateColorFromBoolean`, and combat-deferred binding flushes. Reference Crosshair, FocusNameplateMarker, CastProgress, InteractionHUD Target, PartyRadial HealthBars/RoleIcons/Visual.

## macOS stuck-cursor freeze

A `MouselookStop()` issued while the window is backgrounded (a watched frame auto-unlocks Mouse Look during an alt-tab, e.g. bags/LFG) leaves the OS mouse capture stuck — frozen cursor/camera on return while `IsMouselooking()` lies. There is no window-focus event and the background keeps rendering, so it can't be detected from `OnUpdate`. Recovery is the manual `Combat Mode - Reset Mouse Look` keybind (`CombatMode_ResetMouseLook`, `Core/FreeLook/FreeLookController.lua`): re-grab + release through `CM.LockFreeLook` / `CM.UnlockFreeLook` (keeps UI in sync). The config keybind (`UI/Options/Tabs/TabGeneral.lua`) is shown macOS-only via `IsMacClient()`.
