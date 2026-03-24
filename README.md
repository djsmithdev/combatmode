
<p align="center">
  <img width="512" height="128" src="media/cmtitle.svg">
</p>

<p align="center">
Introducing <strong>Combat Mode</strong> – an AddOn designed to bring a more dynamic action combat experience to <em>World of Warcraft</em> by implementing Free Look, Reticle Targeting, casting with mouse clicks, and more!
</p>

<p align="center">
  <img src="media/previewGif.gif">
</p>

<p align="center">
With a full suite of carefully programmed changes inspired by <ins>Guild Wars 2's Action Camera</ins> - <strong>all aimed at breathing some much-needed life into WoW's tab-targeting combat</strong> - Combat Mode introduces features like <ins>Free Look</ins>, allowing you to change your character’s facing direction by moving the mouse without needing to perpetually hold right-click. When enabled - either through a <em>toggle</em> or <em>press & hold</em> key bind - the cursor is locked to the center of the screen and transformed into a <ins>reticle capable of target selection</ins>, even supporting the use of <em>@cursor</em> or <em>@mouseover</em> macros.
</p>
<p align="center">
Combat Mode takes it further by allowing you to <ins>cast spells with mouse clicks</ins>, a mechanic inspired by third-person action games. For convenience, the AddOn will <ins>automatically deactivate Free Look while interacting with a range of interface panels</ins>, reactivating it once closed.
</p>
<p align="center">
Experience <em>World of Warcraft</em> like never before with <strong>Combat Mode</strong>!
</p>


<br />

## <img width="20" height="20" src="media/cmlogo.svg"> FEATURES
- <strong>[Free Look Camera](https://en.wikipedia.org/wiki/Free_look)</strong> - Rotate the player character's view with the camera without having to perpetually hold right click.
- <strong>Reticle Targeting</strong> - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of @mouseover and @cursor macro decorators in combination with the crosshairs.
- <strong>Mouse Click Casting</strong> - When Free Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them.
- <strong>Cursor Unlock</strong> - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc.
- <strong>Healing Radial</strong> - Radial menu for quickly targeting and casting helpful spells at party members.
<p align="center">
  <img src="media/previewGif2.gif">
</p>

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> DOWNLOAD

Grab it on [**CurseForge**](https://www.curseforge.com/wow/addons/combat-mode).

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> INSTRUCTIONS

After installing the AddOn, you'll be greeted by this message upon your first login on each character:

![previewMsg](media/previewMsg.png)

1. Click OK to proceed or go to Game Menu (ESC) > Options > AddOns > Combat Mode.
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

### Code Style & Linting

- Install [StyLua](https://github.com/JohnnyMorganz/StyLua) and [Selene](https://github.com/Kampfkarren/selene).
- Format check: `stylua --check CombatMode`
- Lint check: `selene --config selene.toml CombatMode`
- Install pre-commit hooks (recommended):
  - `pip install pre-commit`
  - `pre-commit install`
  - `pre-commit run --all-files`

<br />