---
description: Mouse Look, camera/CVar management and Vignette notes
paths:
  - "CombatMode/Core/FreeLook/**"
  - "CombatMode/Core/Runtime/CVarManager.lua"
  - "CombatMode/Core/Vignette.lua"
  - "CombatMode/Constants/CVars.lua"
---

# Mouse Look, camera and CVars

- **CVarManager** — all addon `SetCVar` writes; prior snapshot capture/restore; reticle presets + overrides; Interaction HUD SoftTarget subset (never writes SoftTargetIconInteract/GameObject); Mouse Look camera (`ApplyMouseLookCamera` / `ClearMouseLookCamera`; shoulder tweens with vignette duration — intent vs blend; `shoulderFollowsMouseLook` gates chrome-linked ease vs constant offset; DynamicCam: unlock→0 + optional restore from live/snapshot, else relinquish; `SetDynamicPitch` sticky; `ApplyActionCamMotionSicknessGate` / `respectMotionSickness`); `SyncTargetFocusFromFocusUnit` kept even with DynamicCam; `MigrateMouseLookCameraDB`. `ConfigStickyCrosshair` is an uninstall helper only.
- **Minimum Zoom** — `global.minCameraZoom` (0 = off), `CM.ApplyMinCameraZoom` in CVarManager: no CVar exists and the mouse wheel zooms through the engine binding (a `hooksecurefunc("CameraZoomIn")` never fires), so the `CAMERAZOOMIN` keys get a `SetOverrideBindingClick` to a plain button that zooms by `min(1, distance - min)` (own target tracked for 0.3 s because `GetCameraZoom` lags), queued via `TryApplyBindingChange` and re-applied on `UPDATE_BINDINGS`. A 0.03 s throttled OnUpdate frame (shown only while the option is on) is only the safety net for zoom the keys didn't cause. Always active, even with DynamicCam / SteadyCam.
- **FreeLookController** — mouselook lock/unlock; centering `0 → MouselookStart → deferred 1`; OPie rematch latch; sheath debounce; Apply/Clear Mouse Look camera on lock / permanent unlock.
  Force lock (non-Once) ignores the Mouse Look keybind and clears a stale `FreeLookOverride`; the tap poll never clears chrome / sheathes while mouselooking.
- **Vignette** — edge darkening while Mouse Look is on; smooth fade with `CM.IsMouselooking()`; options on the Mouse Look tab.
- Camera Features (Motion Sickness Protection, Dynamic Pitch, Pitch Strength, Shoulder Offset) live on the General tab below Mouse Look (no Camera tab).
- **AutoCursorUnlock** — answers "should the cursor stay unlocked": watched frames (`FramesToCheck` + watchlist + wildcard tracking when `DB.global.frameWatching`, incl. OPie), vendor mounts, pet battle, feign death, and the user's `customCondition`; `customLockCondition` is the inverse (force Mouse Look on), both via `Core/Runtime/UserLuaCondition.lua`. It only answers; `FreeLookController` owns lock/unlock and the `ShouldFreeLookBeOff` aggregation. OPie visibility notifies FreeLookController so centering rematches after the ring closes. Frame lists/mounts live in `Constants/FrameWatch.lua`.
