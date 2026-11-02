
<p align="center">
  <img width="512" height="256" src="media/cmtitle.svg">
</p>

<p align="center">
<strong>Action Combat Mode</strong> brings modern action-game controls to <em>World of Warcraft</em>, replacing traditional tab-targeting with intuitive aiming, more engaging controls, and immersive combat.
</p>

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> FEATURES

<p align="center">
  <img src="media/reticle_targeting.gif">
</p>

<p align="center">
  <img src="media/cast_at_crosshair.gif">
</p>

<p align="center">
  <img src="media/mouse_look.gif">
</p>

<p align="center">
  <img src="media/click_casting.gif">
</p>

<p align="center">
  <img src="media/crosshair.gif">
</p>

<p align="center">
  <img src="media/assist_hud.gif">
</p>

<p align="center">
  <img src="media/radial_menu.gif">
</p>

<p align="center">
  <img src="media/party_wheel.gif">
</p>

<p align="center">
  <img src="media/target_lock.gif">
</p>

<p align="center">
  <img src="media/ally_cycle.gif">
</p>

<p align="center">
  <img src="media/auto_unlock.gif">
</p>

## <img width="20" height="20" src="media/cmlogo.svg"> DOWNLOAD

Grab it on [**CurseForge**](https://www.curseforge.com/wow/addons/combat-mode) or [**Wago Addons**](https://addons.wago.io/addons/combat-mode).

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> INSTRUCTIONS

After installing the AddOn, you'll be greeted by this message. Click Okay to proceed and follow the Setup Wizard.

<p align="center">
  <img src="media/welcome_msg.png">
</p>

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> SUPPORT

You can report bugs, request features and provide feedback over on our [**Discord**](https://www.discord.gg/5mwBSmz).

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> LICENSE

Free to use, not to redistribute or sell. Contributions through pull requests are welcome. See the [LICENSE](LICENSE) for the full terms.

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> ARCHITECTURE

Action Combat Mode is organized by **domain**. Runtime lives under `CombatMode/Core/`; settings under `CombatMode/UI/`; static tables under `CombatMode/Constants/`.

| Domain | Owns |
|--------|------|
| **Runtime** | AddOn shell, events, CVars, binding queue, bootstrap (`Core/Runtime/`) |
| **FreeLook** | Mouse Look state, auto cursor unlock, flip camera, vignette |
| **Crosshair** | Reticle, Assist HUD (next-cast suggestion and interactable indicator), Target Lock marker, cast animations |
| **ClickCasting** | Mouse/key override bindings, Reticle Targeting macros, composed macros |
| **AllyCycle** | Party/raid ally cycling + Ally HUD (secure Next/Previous, help/harm macros) |
| **RadialMenu** | Radial Menu wheels and the Party Wheel |
| **Options / Wizard** | Standalone options window, editors and the first-run setup wizard (`UI/`) |

Load order and public entry points: **[STRUCTURE.md](STRUCTURE.md)**.

<br />

## <img width="20" height="20" src="media/cmlogo.svg"> CONTRIBUTING

Pull requests to [**Action Combat Mode's repository on GitHub**](https://github.com/djsmithdev/combatmode) are welcome. See **[CONTRIBUTING.md](CONTRIBUTING.md)** for setup, the PR flow and the automatic checks; architecture and coding rules are in **[CLAUDE.md](CLAUDE.md)**.

<br />
