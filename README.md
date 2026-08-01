
<p align="center">
  <img width="512" height="128" src="media/cmtitle.svg">
</p>

<p align="center">
Introducing <strong>Combat Mode</strong> – an AddOn designed to bring a more dynamic action combat experience to <em>World of Warcraft</em> by implementing Mouse Look, Reticle Targeting, casting with mouse clicks, and more!
</p>

<p align="center">
  <img src="media/previewGif.gif">
</p>

<p align="center">
With a full suite of carefully curated changes inspired by <ins>Guild Wars 2's Action Camera</ins> - <strong>all aimed at breathing some much-needed life into WoW's tab-targeting combat</strong> - Combat Mode introduces features like <ins>Mouse Look</ins>, allowing you to change your character’s facing direction by moving the mouse without needing to perpetually hold right-click. When enabled, the cursor is locked to the center of the screen and transformed into a <ins>reticle capable of target selection</ins>.
</p>
<p align="center">
Combat Mode takes it further by allowing you to <ins>cast spells with mouse clicks</ins>, a mechanic inspired by third-person action games. For convenience, the AddOn will <ins>automatically deactivate Mouse Look while interacting with a range of interface panels</ins>, reactivating it once closed.
</p>
<p align="center">
Experience <em>World of Warcraft</em> like never before with <strong>Combat Mode</strong>!
</p>


<br />

## <img width="20" height="20" src="media/cmlogo.svg"> FEATURES
- <strong>[Mouse Look](https://en.wikipedia.org/wiki/Free_look)</strong> - Lock the cursor to screen center and steer with the mouse — no more holding right-click to turn. Toggle it on, hold it when you need to temporarily free the cursor, and control your facing direction by simply moving the mouse. 
- <strong>Reticle Targeting</strong> - Aim the crosshair to target enemies and friendlies the way action games do. Built for `@cursor` and `@mouseover` macros, with optional Target Lock, automatic casting at crosshair location, spell exclusions, and advanced CVar / targeting-macro logic editors when you want full control.
- <strong>Click Casting</strong> - Bind Left, Right, and modified mouse clicks to your rotation so every press under Mouse Look casts a spell — up to eight actions on your left and right click.
- <strong>Interaction HUD</strong> - When something under the reticle can be interacted with (NPCs, world objects, interactables), a clear icon appears beside the crosshair so you never miss a prompt mid-combat.
- <strong>Combat Assist</strong> - Shows Blizzard's Assisted Combat next-cast suggestion next to the crosshair, with satisfying cast-success feedback so your rotation stays readable without staring at the action bar.
- <strong>Action Camera</strong> - Optional dynamic camera preset that leans into that third-person action feel while Mouse Look is active.
- <strong>Auto Cursor Unlock</strong> - Automatically drops Mouse Look when you open bags, the map, character panel, and other UI — then snaps back when you're done so mouse look never fights your menus.
- <strong>Party Radial</strong> - Hold a key during Mouse Look to open a radial of your party: pick a slice to hard-target or cast helpful spells at group members, with health bars and role icons so triage stays fast.

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> DOWNLOAD

Grab it on [**CurseForge**](https://www.curseforge.com/wow/addons/combat-mode) or [**Wago Addons**](https://addons.wago.io/addons/combat-mode).

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> INSTRUCTIONS

After installing the AddOn, you'll be greeted by this message upon your first login on each character:

![previewMsg](media/previewMsg.png)

1. Click Okay to proceed or go to Game Menu (ESC) > Options > AddOns > Combat Mode.
2. In the options panel, you'll be able to configure the addon to your liking.

<strong>Please, take your time reading what each option does, their tooltips and dev notes. They answer the majority of the most commonly asked questions.</strong>

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> SUPPORT

You can report bugs, request features and provide feedback over on our [**Discord**](https://www.discord.gg/5mwBSmz).

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> CONTRIBUTING

You can submit a PR with your contributions to [**Combat Mode's repository on GitHub**](https://github.com/djsmithdev/combatmode).

### Developer quickstart

1. Clone and install the addon into your Retail `Interface/AddOns` folder for local testing.
2. Review module ownership and load order in [STRUCTURE.md](STRUCTURE.md).
3. Run a focused manual pass from [TESTING.md](TESTING.md) for your changed features.
4. Validate release/API compatibility checks from [RELEASE.md](RELEASE.md).
5. Open a PR and complete the repo checklist in `.github/PULL_REQUEST_TEMPLATE.md`.
6. Follow [CONTRIBUTING.md](CONTRIBUTING.md) for contributor workflow and PR minimum checks.

### Code Style & Linting

- Install [StyLua](https://github.com/JohnnyMorganz/StyLua) and [Selene](https://github.com/Kampfkarren/selene).
- Script index helper: `pwsh ./scripts/help.ps1`
- Setup sanity helper: `pwsh ./scripts/dev-check.ps1`
- Default changed-files helper: `pwsh ./scripts/lint-changed.ps1`
- Default local gate (changed files): `pre-commit run --files <changed files>`
- Tool-specific debug checks: `stylua --check <paths>`, `selene --config selene.toml <paths>`
- Install pre-commit hooks (recommended):
  - `pip install pre-commit`
  - `pre-commit install`
  - Release prep / full sweep only: `pre-commit run --all-files`

<br />