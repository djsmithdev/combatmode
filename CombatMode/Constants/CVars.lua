---------------------------------------------------------------------------------------
--  Constants/CVars.lua — CONSTANTS — CVar presets / editor exclusions
---------------------------------------------------------------------------------------
--  What it does: Declares every named CVar preset Combat Mode may apply: reticle targeting,
--  Interaction HUD SoftTarget subset, Action Camera, sticky crosshair (TargetFocus), and
--  matching Blizzard reset tables. Builds ManagedCVarNames as the union used for prior
--  snapshots. Also lists ReticleTargetingCVarEditorExcluded keys the editor must not show.
--  Architecture / how it works:
--    • ReticleTargetingCVarValues — SoftTarget*, deselectOnClick, CursorStickyCentering, etc.
--    • InteractionHUDSoftTargetCVarValues — SoftTargetInteract + icon CVars when HUD is on
--      without full reticle targeting.
--    • ActionCameraCVarValues / TargetFocusCVarValues (+ Blizzard* counterparts).
--    • ManagedCVarNames also includes cameraYaw/PitchMoveSpeed and CursorCenteredYPos.
--  Does not: Call SetCVar or merge DB overrides (CVarManager owns writes + effective values).
--  Related: Core/Runtime/CVarManager.lua, UI/Editors/ReticleCVarEditorData.lua,
--  UI/Editors/ReticleCVarEditorPanel.lua, Constants/DatabaseDefaults.lua,
--  Core/Crosshair/InteractionHUD/HUD.lua, UI/Options/Tabs/TabReticleTargeting.lua,
--  UI/Options/Tabs/TabCamera.lua
---------------------------------------------------------------------------------------
local _, CM = ...

local ipairs = _G.ipairs
local pairs = _G.pairs
local table = _G.table
local type = _G.type

-- CVARS FOR RETICLE TARGETING
CM.Constants.ReticleTargetingCVarValues = {
  ["interactKeyWarningTutorial"] = 1, -- Hides the interact key tutorial if using the INTERACTMOUSEOVER binding
  ["deselectOnClick"] = 1, -- Disables Sticky Targeting. We never want this w/ soft targeting, as it interferes w/ SoftTargetForce
  ["enableMouseoverCast"] = 0, -- Disabling to avoid issues with targeting macro preline priority
  -- SoftTarget General
  ["SoftTargetForce"] = 0, -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  ["SoftTargetMatchLocked"] = 0, -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  ["SoftTargetWithLocked"] = 0, -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
  -- SoftTarget Enemy
  ["SoftTargetEnemy"] = 3, -- Sets when enemy soft targeting should be enabled. 0=off, 1=gamepad, 2=KBM, 3=always
  ["SoftTargetEnemyArc"] = 0, -- 0 = No yaw arc allowed, must be directly in front (More precise. Harder to target far away enemies but better for prioritizing stacked targets). 1 = Must be in front of arc (Less precise. Makes targeting far away enemies easier but prioritizing gets messy with stacked mobs).
  ["SoftTargetEnemyRange"] = 60,
  -- SoftTarget Interact
  ["SoftTargetInteract"] = 3,
  ["SoftTargetInteractArc"] = 1, -- Setting it to 1 since we don't need too much precision when interacting with NPCs and having to aim precisely at them when this is set to 0 gets annoying.
  ["SoftTargetInteractRange"] = 15,
  -- SoftTarget Friend
  ["SoftTargetFriend"] = 0,
  ["SoftTargetFriendArc"] = 0,
  ["SoftTargetFriendRange"] = 60,
  -- SoftTarget Nameplate
  ["SoftTargetNameplateEnemy"] = 0, -- Always show nameplates  for soft target enemy.
  -- SoftTarget Icon
  ["SoftTargetIconEnemy"] = 0,
  ["SoftTargetIconInteract"] = 0, -- We don't seem to need this to be enabled for the interaction HUD to work properly.
  ["SoftTargetIconGameObject"] = 0, -- Wedon't seem to need this to be enabled for the interaction HUD to work properly.
  -- cursor centering
  ["CursorFreelookCentering"] = 0, -- !BUG: needs to be set to 0 initially because Blizzard broke something in 10.2, otherwise it wll cause the camera to jolt the equivalent vector to the centered cursor position from where your cursor was before locking.
  ["CursorStickyCentering"] = 1, -- !BUG: we can't use it due to the issue described above. Fore more info, see: https://github.com/Stanzilla/WoWUIBugs/issues/504
}

-- Not shown in the Reticle CVar editor; saved overrides for these keys are ignored and pruned.
CM.Constants.ReticleTargetingCVarEditorExcluded = {
  ["CursorStickyCentering"] = true,
  ["CursorFreelookCentering"] = true,
  ["enableMouseoverCast"] = true,
  ["deselectOnClick"] = true,
  ["interactKeyWarningTutorial"] = true,
}

-- Minimal SoftTarget CVars so the Interaction HUD (softinteract) works when Reticle Targeting
-- is off; full stack remains CM.ConfigReticleTargeting("combatmode").
CM.Constants.InteractionHUDSoftTargetCVarValues = {
  ["interactKeyWarningTutorial"] = 1,
  ["SoftTargetInteract"] = 3,
  ["SoftTargetInteractArc"] = 1,
  ["SoftTargetInteractRange"] = 15,
  ["SoftTargetIconInteract"] = 0,
  ["SoftTargetIconGameObject"] = 0,
}

-- CVARS FOR ACTION CAMERA
-- https://warcraft.wiki.gg/wiki/CVar_ActionCam
CM.Constants.ActionCameraCVarValues = {
  ["CameraKeepCharacterCentered"] = 0, -- Disable Motion Sickness
  ["CameraReduceUnexpectedMovement"] = 0, -- Disable Motion Sickness
  ["test_cameraDynamicPitch"] = 0, -- Vertical Pitch
  ["test_cameraOverShoulder"] = 1.2, -- Shoulder horizontal offset
  ["test_cameraHeadMovementStrength"] = 1, -- Head Tracking
  ["cameraDistanceMaxZoomFactor"] = 1.0, -- Max zoom distance (1.0 = 15 yards)
  ["cameraZoomSpeed"] = 20, -- Zoom scroll speed
  ["cameraYawMoveSpeed"] = 100, -- Horizontal turn speed
  ["cameraPitchMoveSpeed"] = 50, -- Vertical turn speed
  ["cameraFov"] = 90, -- Field of view
}

-- Subset of Action Camera CVars toggled by "Disable with Mouse Look".
-- Preference CVars (zoom distance, FOV, zoom speed, turn speed) are excluded
-- so the camera does not jump when mouse look is turned off and on.
CM.Constants.ActionCameraMouselookDisableCMValues = {
  ["CameraKeepCharacterCentered"] = 0,
  ["CameraReduceUnexpectedMovement"] = 0,
  ["test_cameraDynamicPitch"] = 0,
  ["test_cameraOverShoulder"] = 1.2,
  ["test_cameraHeadMovementStrength"] = 1,
}

CM.Constants.BlizzardActionCameraMouselookDisableValues = {
  ["CameraKeepCharacterCentered"] = 1,
  ["CameraReduceUnexpectedMovement"] = 1,
  ["test_cameraDynamicPitch"] = 0,
  ["test_cameraOverShoulder"] = 0,
  ["test_cameraHeadMovementStrength"] = 0,
}

-- CVARS FOR STICKY CROSSHAIR
CM.Constants.TargetFocusCVarValues = {
  ["test_cameraTargetFocusEnemyEnable"] = 1,
  ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.7, -- horizontal strength
  ["test_cameraTargetFocusEnemyStrengthPitch"] = 0.2, -- vertical strength
}

-- DEFAULT BLIZZARD VALUES
-- !! DO NOT CHANGE !!
CM.Constants.BlizzardReticleTargetingCVarValues = {
  ["SoftTargetEnemy"] = 1,
  ["SoftTargetEnemyArc"] = 2,
  ["SoftTargetEnemyRange"] = 45,
  ["SoftTargetInteract"] = 1,
  ["SoftTargetInteractArc"] = 0,
  ["SoftTargetInteractRange"] = 10,
  ["SoftTargetIconEnemy"] = 0,
  ["SoftTargetIconGameObject"] = 0,
  ["SoftTargetIconInteract"] = 0,
  ["CursorStickyCentering"] = 0,
}

CM.Constants.BlizzardActionCameraCVarValues = {
  ["test_cameraDynamicPitch"] = 0,
  ["test_cameraDynamicPitchBaseFovPad"] = 0.4,
  ["test_cameraDynamicPitchBaseFovPadFlying"] = 0.75,
  ["test_cameraDynamicPitchBaseFovPadDownScale"] = 0.25,
  ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 10,
  ["test_cameraHeadMovementStrength"] = 0,
  ["test_cameraOverShoulder"] = 0,
  ["CameraKeepCharacterCentered"] = 1,
  ["CameraReduceUnexpectedMovement"] = 1,
  ["cameraDistanceMaxZoomFactor"] = 1.9,
  ["cameraZoomSpeed"] = 20,
  ["cameraYawMoveSpeed"] = 180,
  ["cameraPitchMoveSpeed"] = 90,
  ["cameraFov"] = 90,
}

CM.Constants.BlizzardTargetFocusCVarValues = {
  ["test_cameraTargetFocusEnemyEnable"] = 0,
  ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.4,
  ["test_cameraTargetFocusEnemyStrengthPitch"] = 0.5,
}

-- Every CVar Combat Mode may write. Used to snapshot the player's pre-CM values once
-- so Uninstall can restore them instead of hard-coded Blizzard tables.
do
  local seen = {}
  local names = {}
  local function addTable(t)
    if type(t) ~= "table" then
      return
    end
    for name in pairs(t) do
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end
  addTable(CM.Constants.ReticleTargetingCVarValues)
  addTable(CM.Constants.InteractionHUDSoftTargetCVarValues)
  addTable(CM.Constants.ActionCameraCVarValues)
  addTable(CM.Constants.TargetFocusCVarValues)
  addTable(CM.Constants.BlizzardReticleTargetingCVarValues)
  addTable(CM.Constants.BlizzardActionCameraCVarValues)
  addTable(CM.Constants.BlizzardTargetFocusCVarValues)
  for _, name in ipairs({
    "cameraYawMoveSpeed",
    "cameraPitchMoveSpeed",
    "CursorCenteredYPos",
  }) do
    if not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end
  table.sort(names)
  CM.Constants.ManagedCVarNames = names
end
