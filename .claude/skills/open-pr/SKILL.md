---
name: open-pr
description: Commit the current work on a branch and open a pull request against develop with a conventional title and a filled-in template. Only when the user asks to open a PR.
disable-model-invocation: true
---

# Open a PR

PRs go to `djsmithdev/combatmode`, base `develop` (`master` only takes the release PR, see `/release`). Ask before committing, pushing and creating the PR; one confirmation can cover all three if the user gives it.

1. **Checks** — run `/finish-change` steps that apply (API check, safety review, `lint-changed.ps1` twice). Stop on any `[FAIL]`.
2. **Branch** — if on `develop` or `master`, create `<type>/<short-slug>` from `develop`. Stage only the files of this change (`git add <paths>`, never `-A` blindly) and check `git status` for strays.
3. **Title / commit** — Conventional Commits, matching history: `feat|fix|perf|refactor|style|docs|chore|ci|build|revert`, optional scope (domain: `crosshair`, `click-casting`, `radial-menu`...), lower-case imperative summary under ~70 chars. CI's `pr-title` check enforces the same format.
4. **Body** — fill `.github/PULL_REQUEST_TEMPLATE.md` from the diff:
   - **Summary**: what changed and why, 1-3 bullets;
   - **Player impact**: what the player sees (changelog wording), or "None" for tooling;
   - **Test plan**: `/ingame-test` output condensed to the must-test steps;
   - tick only the checklist items that were actually done; leave in-game items unticked unless the user says they tested.
5. **Push + create** — `git push -u origin <branch>`, then `gh pr create --repo djsmithdev/combatmode --base develop --head <branch> --title ... --body-file <tmp>` (`origin` is `djsmithdev/combatmode` itself; branches are pushed there, no fork). Use the scratchpad for the body file.
6. Report the PR URL. CI (lint + check-repo), title check and labels run automatically; don't poll them.
