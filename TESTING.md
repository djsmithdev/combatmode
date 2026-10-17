# CombatMode Manual Testing

Use this checklist for feature work and regressions.

## Setup

- Use Retail client with addon enabled and fresh `/reload`.
- Confirm `CombatModeDB` loads and settings panel opens (`/cm`).
- **Changelog viewer:** open sidebar → **Changelog**; confirm markdown renders (headings, bullets, links). After a version bump, confirm auto-popup once per version (`lastSeenChangelogVersion` in saved vars). If `CHANGELOG.md` was edited, confirm **`scripts/sync-changelog-to-lua.ps1`** was run so in-game text matches.
- If testing bindings, verify keybinds are set as expected.
- For API-sensitive changes, verify WoW API/event signatures via MCP tools first (or manual fallback in `RELEASE.md`).

## Setup wizard
- New character (or Debug Mode on, then `/reload`): welcome popup → OKAY opens the options window and starts the tour (Mouse Look section, Camera Features, then one whole section per step in tab order: Crosshair, Assist HUD, Reticle Targeting, Target Lock, Click Casting, Auto Unlock, Ally Cycle, Ally HUD, and the four Advanced sections).
- Each step scrolls to its setting or section, dims the rest of the screen (the cut-out stays inside the tab's visible area for tall sections), outlines it and shows a balloon (on screen, readable). The highlighted setting is fully usable: setting a keybind there matches the tab afterwards.
- Steps that ask for an action (Mouse Look: Mouse Look + Interact keys; Target Lock: Target Lock + Cycle Lock Next / Previous keys, not required while Reticle Targeting is off; Ally Cycle: Next + Previous keys) show a check list in the balloon. Checks fill green as soon as the key is bound (already-bound keys start checked), and Next stays dimmed and disabled until all are done. Skip tour and Back always work.
- Back / Next / Skip tour / ESC work; Finish ends it. Switching tabs by hand hides the dim until the next step.
- Cog left of the version chip: tooltip, confirm dialog, Yes restarts the tour, No does nothing. Version chip and search box still lay out correctly.
- Starting in combat waits for combat to end; entering combat mid-tour ends it. Existing characters (`seenWarning` set) are not prompted.

## Core and mouselook

- **Selection Circle** (Reticle Targeting tab; replaces Hide Soft Targeting Indicator from 5.0.3): `/run print(GetCVar("ObjectSelectionCircle"), GetCVar("UnitNameFocused"))`:
  - Any Hard Target (default): `0 0` with no target and the soft target shows no circle or floating name; `1 0` with a hard target, enemy or friendly (also when targeting or `/cleartarget`ing in combat, with no ADDON_ACTION_BLOCKED in BugGrabber): the red circle is under your target, turning on only once the soft target has moved onto it (no sliding from the old soft target), and it returns to `0 0` when you clear the target. The target's name still shows on its nameplate.
  - Locked Target Only: `1 0` only while your hard target is also your Target Lock (focus); a plain hard target gets no circle.
  - Soft Target (Blizzard): `1 1`, Blizzard's circle and name on the soft target, wherever it is.
  - Hidden: `0 0`.
  Overriding `SoftTargetMatchLocked` away from 1 in the CVar editor keeps the first two modes hidden. Target Lock Marker only controls the nameplate marker. The dropdown has a round ? badge to its left (the label column keeps its width, the select just gets narrower): hovering it opens a tooltip to its right listing the four options (each name on its own line with its explanation below, not in columns), with a red warning under Soft Target (Blizzard) that it follows an arc in front of the character model, not the crosshair or Shoulder Offset. Migration: a saved `reticleHideSoftIndicator = false` becomes Soft Target, `true` (or `1`) becomes Any Hard Target, and the old key disappears. Disabled while Reticle Targeting is off. Uninstall restores the previous values; for an install that predates these CVars (its saved snapshot lacks them) it sets `ObjectSelectionCircle` and `UnitNameFocused` back to `1 1`.
- **SoftTargetMatchLocked 1** (Reticle Targeting preset): `/run print(GetCVar("SoftTargetMatchLocked"))` prints `1`; with a hard target, the soft target stays on it while you aim at other enemies; with no hard target it follows your aim as before.
- **Ground spells:** press an AoE/ground spell (green circle): the cursor appears at once, not after a short delay; placing it or cancelling (Esc / right click) re-locks Mouse Look at once.
- Toggle CombatMode on/off and verify mouselook enters/exits correctly.
- Verify no stuck mouselook after opening/closing common UI panels.
- Test transitions in and out of combat; no protected-action errors.
- **Sheath Weapons with Mouse Look:** rapid Mouse Look toggles (e.g. single-pull) should not flash sheath/unsheath; unsheath on lock remains immediate; temporary unlocks (hold, ground spells, OPie) keep weapons drawn.
- **Force Lock** (Advanced): snippet `return true` re-locks after a tap unlock. Force Unlock custom condition `return true` does not unlock while Force Lock is true. Opening a bag or ground-targeting a spell still unlocks. Clearing the snippet restores the previous unlock (a prior tap-unlock stays unlocked).
- **Lock Once** (Advanced, under Force Lock): with the snippet staying `return true`, the first check locks; a manual Mouse Look unlock stays unlocked until the snippet is cleared or edited to return false and then true again. With Lock Once off, the same snippet re-locks on the next check after a manual unlock.
- **Unlock Once** (Advanced, under Force Unlock): with the snippet staying `return true`, the first check unlocks; pressing Mouse Look to lock stays locked until the snippet is cleared or edited to return false and then true again. With Unlock Once off, the same snippet unlocks again on the next check.

## Reticle and targeting CVars

- **Target Outline** (Reticle Targeting tab): with Reticle Targeting on, `/run print(GetCVar("Outline"), GetCVar("outlineMouseOverFadeDuration"), GetCVar("outlineSelectionFadeDuration"))` prints `3 3600 3600`. The outline is strong on the target and on the unit under the crosshair, including when the hovered unit becomes your target; units you sweep across leave no lingering outline. Toggle it off: `Outline` 0 and fades 0.9 / 0.32; on: back to the preset. Disabling Reticle Targeting / Uninstall restores the previous values.
- Enable/disable reticle-related settings and confirm visual/state updates.
- Confirm targeted CVars change only when feature requires it.
- Disable feature and ensure CVars/state restore path behaves correctly.
- Open **Reticle Targeting CVar editor** from Reticle options: filter/sort, double-click edit, reset overrides; reload and confirm `reticleTargetingCVarOverrides` persistence; verify excluded CVars do not appear and external `SetCVar` updates refresh the list where hooked.

## Click casting

- **Ping and marker actions:** the action dropdown lists Action Combat Mode's own actions first, then the changed Blizzard ones (Ping, Attack, Warning, On My Way, Assist, Raid Target 1-8 / None) in blue, then the rest. Ours are copper. In Mouse Look, each ping pings the unit under the crosshair (nothing happens with no unit; "Ping" alone is a contextual ping and no longer opens the wheel in Mouse Look). Raid Target N marks your hard target, or the unit under the crosshair when you have none (None clears it). Out of Mouse Look the buttons keep their normal behavior.
- **No CM_ macros:** open the macro list (`/macro`): there are no `CM_ClearTarget` / `CM_ToggleFocus*` / `CM_StartAttack` / ... entries (unmodified leftovers from older versions are deleted once on login; an edited one, or one on an action bar, is kept). Click-cast mouse actions **Clear Target, Clear Focus, Start Attack, Pet Attack** still work from their mouse buttons (with key-down off they fire on release).
- **Shorter /click line:** the macros no longer pass `LeftButton` (default) or a key-up `0`. Press bar keys and click-cast mouse buttons in and out of combat on Blizzard bars, and with ElvUI / Bartender with `ActionButtonUseKeyDown` 0 and 1 — they must still target and cast. Enter a vehicle / override bar in combat: keys 1–6 fire the override abilities. Preline editor: a 140-character preline saves and works, 141 is rejected.
- Auto Target Lock + Ignore Friendlies: a dead hostile under the crosshair is not targeted or focused. Ally Cycle with "restore after harm" on, in a group: a dead Target Lock is cleared on the next harmful cast (Blizzard bars; ElvUI / Bartender with key-down keep the older shorter macro).
- Validate base click-cast actions on valid units.
- **Start Attack** / **Pet Attack** (click-cast overrides, not Blizzard's raw binds): left-click aims at a new enemy and starts you or your pet swinging; existing Start Attack / Pet Attack slot values pick this up.
- Action Button 1 (or any bar slot) with Auto Attack / Auto Shot / Shoot / Pet Attack still gets reticle `/tar` and can swap hostiles. A new unit keeps the swing on (`/startattack` / `/cast !` / `/petattack`, not `/click` which would toggle it off).
- Validate modifier variants (Shift/Ctrl/Alt) map to expected spells/macros.
- Verify behavior remains stable in combat (no insecure action taint/errors).
- Binding refresh must not loop when Single-Button Assistant rewrites its action slot.
- Rebinding Mouse Look / Ally Cycle / Target Lock clears leftover Interact Alt+key chords without a reload.
- **Paged / bonus / secondary bar macros (Reticle Targeting on):** put a custom macro on main-bar page 1 — keybind still fires (native path). Page the main bar, or enter stealth/form so a **bonus** bar shows the same 1–12 keys with a **macro** — keybind fires and mouse click still fires. A **spell** on that paged/bonus bar still gets reticle `/tar` + `/click`. Exit a vehicle: keys must not stick on override slots 121+. Forever and Mainline: same cases.

## Interact key

- Bind Interact to an Alt+mouse chord; bind another action that also uses Alt on a related key. Confirm Interact does **not** become Alt+Alt+key.
- Switching Interact Unit (Crosshair vs Soft Targeted) keeps ALT+key on the other command as intended.

## Target Lock (4.1.3)

- Set Target Lock (focus) via keybind; confirm lock sound (if Target Lock Sound Cues on).
- Clear lock; confirm unlock sound.
- **Target Lock Behavior** (Reticle Targeting tab, under the Target Lock key): **Toggle** = as above. **Switch Target**: lock A, aim at B and press the key -> locked and targeting B; aim at empty space and press -> unlocked (target cleared); aim at A again -> stays locked; with Ignore Friendlies on, a friendly or dead unit under the crosshair changes nothing; with it off, the friendly is locked. Change the dropdown during combat: no Lua error, it applies after combat. Cycle keys still work in Switch mode.
- **Removed click-cast actions:** Toggle Focus Any / Enemy are gone from the Click Casting action dropdown. A saved slot that used one (the old default Alt + Right Click) loads turned off; a fresh install has Alt + Right Click off.
- **Mouse wheel cycle** (on by default): with Mouse Look on and a lock set, wheel cycles nearby enemies and moves the lock; without a lock (or Mouse Look off), wheel zooms the camera.
- Cycle to another enemy; confirm cycle sound cue.
- **Nameplate marker:** while locked, center reticle becomes a static Dot; hit marker (Active texture for your Appearance) appears on the locked unit’s nameplate health bar; unlock restores the reactive reticle and clears the marker instantly.
- In a **dungeon/instance**, lock / cycle / unlock with no Lua errors (focus identity may be secret under taint).

## Flip Camera keybind

- Mouse Look tab → Flip Camera Keybind (below Interact Unit): bind a key; it also shows under Action Combat Mode in the Key Bindings screen.
- Tap the key: the camera flips 180° around the character and stays; tap again: it flips back.
- Hold the key (about 0.3s+): the camera flips while held and flips back on release. No Lua errors, also in combat.

## Assist HUD (Next-cast Suggestion + Interactable Indicator)

- Setup wizard, Crosshair / Assist HUD / Ally Cycle / Ally HUD steps: the crosshair + HUD preview is not dimmed and has an accent outline; the balloon never covers it (it moves beside / below / to a screen corner). Other steps look as before.

- Aim at an NPC/object/mailbox with no hostile: icon, name beside it, Interact key in the corner badge (hidden when unbound); icon dims out of range.
- Hostile hard target or hostile under the crosshair, in or out of combat: spell suggestion + keybinds; wins over an interactable.
- "Next-cast Suggestion" (Always / Only In Combat / Hidden) and "Interactable Indicator" disable only their mode; Position/Scale/Distance apply to both. Old saved variables load without errors.

## Crosshair cast feedback & Combat Assist

- Cast feedback grow / explode / break (and Assist swipe / cancel break) work in open world.
- **Situational Appearance → Invisible** (Advanced): while the situational condition is true, the center crosshair hides; it returns when the condition is false. Target Lock still shows its center Dot.
- Repeat the same in a **dungeon/instance** with no Lua errors from cast GUID compares.
- Rapid Single-Button Assistant presses do not spam Assist cast-success press/pulse animations.
- Assist cast-success does not double-fire from assisted-action + `UNIT_SPELLCAST_SUCCEEDED`.

## Cursor unlock and cursor pulse
- Auto Unlock → Extra Frames is a pill list: typing a frame name suggests Blizzard / addon frames (right-hand label says which, and "open" if visible), Enter adds free text, × removes. Inspect button at the top right: cursor becomes the cast cursor, the screen dims (same look as the wizard tour) except the window under the cursor, which is outlined, with its name in a banner, left click adds it, right click / Esc cancels; the options window itself is never offered. Chips, suggestions and the picker popup show the WoW logo for Blizzard frames and the owning addon's AddOns-list icon for addon frames (question-mark icon if the addon has none). Existing saved frames show as pills; an added frame unlocks the cursor while it is visible.

- Trigger configured unlock conditions (UI panels/custom Lua if applicable).
- Confirm mouselook unlocks when expected and relocks when expected.
- Confirm pulse appears after unlock and does not persist unexpectedly.

## Ally Cycle

- **Away members:** in a group, an ally who logs out, or is in another zone / instance, is skipped by Ally Cycle Next / Previous (and the HUD count drops) within about a second while out of combat; they are included again when they return. An ally who is just far away in the same zone is **not** skipped (including one who arrives mid-combat). Someone who disconnects during a fight is skipped after combat ends. If every other member is away, pressing does nothing (no Lua error).

- Options → Ally Cycle tab: bind Up/Down, toggle Skip Self / Keep Ally After Harm / Ally HUD / side / scale / Distance; no Lua errors on open. Forever Beta: Ally Cycle runs like Retail (no watermark); log in, reload and fight in a group with no secure-snippet / RestrictedExecution errors.
- Ally Cycle in party/raid: Up/Down cycles members in combat; HUD shows only with a party/raid hard target (self only when Skip Self is off); Interact on a friendly NPC must not flash the HUD; unbound keys = inert.
- Helpful click-cast (Reticle Targeting; **no Ally Cycle binds required** — Forever / unbound too): Ignore Friendlies on — keeps a friendly hard target (hostile under the reticle does not steal); Ignore Friendlies off — `/tar`s helpable mouseover / `@softinteract` / `@anyfriend`, not a hostile. Ally Cycle keys bound (including solo): harmful still `/tar`s `@anyenemy`; Keep Ally After Harm restores in group.
- Ally HUD: class-colored name ("You" on self), UI-Frame role icon, raid marker, cycle index n/total; Previous travels an up arrow, Next a down arrow. Dead chrome is grey/desaturated; low HP pulses a red bar glow (no role-icon glow).
- Keep Ally After Harm: with a cycled ally selected, a harmful click-cast retargets the enemy then restores the ally; skipped while Auto Target Lock is on.

## Profiling (Function Profiler)

Built-in `Core/Dev/FunctionProfiler.lua` provides per-function CPU + memory profiling via `C_AddOnProfiler.MeasureCall`.

- Open the options panel (`/cm`), toggle **Debug Mode** ON → profiling starts automatically, data resets.
- Play your scenario.
- Toggle **Debug Mode** OFF → full sorted profile report + CPU stats prints to chat.
- The profiler wraps hot-path functions with `CM.Profile(key, func, ...)`. When profiling is off the wrapper is a transparent pass-through with no overhead, so wrappers stay in production code.
- `CM.StartProfiling()` and `CM.StopAndReportProfiling()` public APIs are available for automated testing.

## Config and persistence

- Change options in each category and verify immediate apply/refresh behavior.
- Reload UI and confirm saved values persist in correct scope.
- Test reset/default paths and ensure no stale state remains.
- Uninstall (sidebar): restores prior CVars, resets left/right click camera binds, disables addon, reloads.

## Quick regression pass

- Slash commands: `/cm`, `/combatmode`.
- Keybinds still function after reload and after disabling/re-enabling addon.
- No Lua errors in normal use paths for edited features (especially instances for focus/cast GUID paths).
- If keybind writes were changed, verify in-combat changes defer and apply automatically after leaving combat.
- For contributor lint/format checks, use helper by default: `pwsh ./scripts/lint-changed.ps1`.
- Equivalent direct gate: `pre-commit run --files <changed files>`.
- When bumping a version: update `CombatMode/CombatMode.toc` `## Version`, `CombatMode/CHANGELOG.md`, then `pwsh ./scripts/sync-changelog-to-lua.ps1` (agents ask first — see `AGENTS.md` / change checklist).
- Reserve full-repo gate for release prep: `pre-commit run --all-files`.
