## 3.1.9 CHANGELOG
- Major refactor of action bar binding override code. ***[Technical gibberish ahead]*** Now CM computes the canonical action-slot id directly from the binding prefix and button index. This avoids relying on `MultiBar*ButtonN` frames whose `action` attribute can be ambiguous under action bar replacement addons like Bartender4, Dominos, ElvUI, etc.
- Code cleanup.

---

### 3.1.8 CHANGELOG
- Fixed issue preventing Reticle Targeting from working with ElvUI/Bartender4.

### 3.1.7 CHANGELOG
- Fixed sticky crosshair table name.

### 3.1.6 CHANGELOG
- Code cleanup.
- Added GitHub package release workflow.

### 3.1.5 CHANGELOG
- Cursor freelook centring is now tied to the Crosshair being active and not Reticle Targeting.
- Crosshair reactivity no longer requires Reticle Targeting to be enabled.
- Adjusted Interaction HUD range check.

These changes should allow the player to use the Crosshair and the Interaction HUD regardless of Reticle Targeting configuration.

### 3.1.4 CHANGELOG
- Performance pass.
- Split Constants.lua into smaller files in /Constants.

### 3.1.3 CHANGELOG
- Fixed Interaction HUD issues with secret values in dungeons throwing errors.
- Font usage for Interaction HUD and Healing Radial is now client language-agnostic.
- Updated LibEditMode.

### 3.1.2 CHANGELOG
- Added LibEditMode to Libs folder

### 3.1.1 CHANGELOG
- Added support for Edit Mode. You can now adjust the Crosshair directly from Blizzard's Edit Mode.
- Added Interaction HUD to crosshair options. This displays a HUD for interactable NPCs or objects to the right of the crosshair when enabled.
- Adjusted Crosshair positioning to remove the vertical position limit, allowing the user to place it as high or as low as they want to.
- Crosshair reaction now better reflects config options, including more reliable cursor centring.
- Fixed issue with Reticle Targeting blacklist not properly excluding spells from the targeting macro injection, which was interfering with Hold To Cast/Empowered spells. Now, if you exclude a spell by putting its name on the list, Hold To Cast & Empowered Spell options like Hold & Release should work properly.
- Reorganized project structure into smaller, more maintainable files.
