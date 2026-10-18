---
name: new-option
description: Add a new user setting to the addon end to end (default, DB scope, options control, search, wizard, tests, changelog).
---

# Add a setting

1. **Default + scope** — add the key to `CombatMode/Constants/DatabaseDefaults.lua` under `global` (account-wide) or `char` (per character). Booleans must be real booleans (Forever's `1`/`0` is coerced by `InitDatabase`). Renamed/reshaped data needs an explicit migration in `InitDatabase`, not a hidden one elsewhere.
2. **Behavior** — implement in the owning module as an apply/refresh function the toggle calls; guard secure/binding work with `InCombatLockdown()` and queue to `PLAYER_REGEN_ENABLED`. Keep enable/disable symmetric.
3. **Control** — add a `ctx:Toggle/Dropdown/Slider/TextInput/Keybind/...` in the matching `UI/Options/Tabs/Tab*.lua`. Give it a `label` (and `desc`) so options search indexes it; hidden-when rows use `hidden`, and call `layout:Reflow()` where rows collapse. Slider defaults via `opts.default` (right-click reset). Use "Action Combat Mode" in text.
4. **Events** — if it needs a new Blizzard event, add it to `BLIZZARD_EVENTS` in `Constants/Gameplay.lua` and handle it in `Core/Runtime/EventRouter.lua`.
5. **Wizard** — if first-run users should see it, add/adjust the step in `UI/Wizard/SetupWizard.lua`.
6. **Docs** — one line in the matching `TESTING.md` section; changelog entry via the `changelog` skill (ask first); update the Lua header and `domain-*.md` if ownership or a gotcha changed.
7. Run `/finish-change`.
