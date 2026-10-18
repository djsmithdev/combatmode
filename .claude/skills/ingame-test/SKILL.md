---
name: ingame-test
description: Turn the current diff into a short in-game test checklist using TESTING.md, listing the assumptions that can only be verified on a live client. Use after a code change, before the user tests in WoW.
---

# In-game test checklist

1. `git diff --stat` (staged + unstaged) and group changed files by feature.
2. Map features to `TESTING.md` sections. Get the section list with `grep -n "^## " TESTING.md` and read **only** the matching sections: Setup, Setup wizard, Core and mouselook, Reticle and targeting CVars, Click casting, Interact key, Target Lock, Flip Camera keybind, Assist HUD, Crosshair cast feedback & Combat Assist, Cursor unlock, Ally Cycle, Profiling, Config and persistence, Quick regression pass.
3. Output, kept short:
   - **Must test** — 5-10 concrete steps (what to press/click, what you should see), ordered by risk: combat-lockdown paths first (anything bound or attribute-changing, tested both out of combat and by entering combat mid-step), then instance/secret-value paths (dungeon, raid, M+), then plain UI.
   - **Needs a live client to prove** — assumptions the code can't verify offline: API behavior I inferred but didn't confirm (return values in instances, secret vs public), restricted-environment limits, client differences (Retail vs Classic/Era/Forever), `/reload` persistence of new DB keys.
   - **Quick regression** — only the lines from "Quick regression pass" that touch the changed domains.
   - **Debug aids** — `debugMode` / the Function Profiler (`TESTING.md` Profiling) if the change is performance-sensitive.
4. If a changed behavior has no `TESTING.md` line, propose the line (one sentence) and add it only if the user agrees.
5. Don't claim anything passed; this skill only prepares the test plan.
