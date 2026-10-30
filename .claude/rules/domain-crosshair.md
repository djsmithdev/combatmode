---
description: Crosshair, Assist/Interact HUD, Target Lock marker and cast feedback notes
paths:
  - "CombatMode/Core/Crosshair/**"
  - "CombatMode/UI/Options/Tabs/TabCrosshair.lua"
  - "CombatMode/Constants/Atlas.lua"
---

# Crosshair and companions

- **Crosshair HUD** — one HUD with two modes (assist when a hostile is the hard target/under the crosshair, otherwise interact for `softinteract`: cursor icon, name, interact key; also another player under the crosshair once aimed at for `PLAYER_DWELL` (1 s) out of combat: portrait in the masked icon slot, class-coloured name, same key, which opens their menu via `CM.GetPlayerUnderCrosshair` from `PlayerMenu.lua`; secret GUIDs fail closed), all under `Core/Crosshair/AssistedHighlight/`: `Keybinds` → `Interact` (softinteract identity/name/key/range) → `Motion` (ProcLoop/glow/fade) → `CastProgress` (swipe/break) → `Feedback` (press/pulse + façade; Attach also binds CastProgress) → `Assist` (chrome + public APIs).
- **FocusNameplateMarker** — when `CM.DB.global.showTargetLockMarker` (default on): Target Lock makes the center reticle a static base-colored idle texture (`global.crosshairTargetLockId`, default `crosshairDot`; the mounted reticle uses `crosshairMountedId`; unreactive) for as long as focus exists (even with no nameplate); a hostile-red hit marker reverse-arrives onto the plate (scale/alpha), then color-pulses while settled; parented to the plate root with ignore-parent-alpha so bar fades do not stack; plate recycle resumes settled (no re-arrive). Unlock/toggle-off restores the reactive reticle. Not `Animations.lua` (reticle cast feedback only).
- **Cast feedback:** Animations outer `OnUpdate` (one motion); terminals via `CM.NotifyCrosshairCastTerminal`; gated by `crosshairCastFeedback`.
- **Assisted Combat matching:** short recent-suggestion cache — `GetNextCastSpell` often advances before `UNIT_SPELLCAST_SUCCEEDED`.
- **FlipBook / atlas VFX:** ship rows/cols/frames/duration next to the atlas constant in the owning Lua file (see `AssistedHighlight/Motion.lua` for `UF-RogueCP-Slash-Blue`). `C_Texture.GetAtlasInfo` does **not** return FlipBook grid layout. To discover: Blizzard UI source FlipBook XML, other retail addons calling `SetFlipBookRows/Columns/Frames` on the same atlas, then confirm in game. Do not vendor wow-ui-source trees or atlas catalogs into this repo.
- **Options preview:** Crosshair tab → `CM.SetCrosshairOptionsPreview` via tab `onSelect`/`onDeselect`; do not reuse mouselook-gated Show/Hide.
