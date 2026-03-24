---------------------------------------------------------------------------------------
--  Constants/ConstantsCVars.lua — constants module: cvar presets/defaults
---------------------------------------------------------------------------------------
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

-- CVARS FOR RETICLE TARGETING
CM.Constants.ReticleTargetingCVarValues = {
  ["interactKeyWarningTutorial"] = 1, -- Hides the interact key tutorial if using the INTERACTMOUSEOVER binding
  ["deselectOnClick"] = 1,            -- Disables Sticky Targeting. We never want this w/ soft targeting, as it interferes w/ SoftTargetForce
  ["enableMouseoverCast"] = 0,        -- Disabling to avoid issues with targeting macro preline priority
  -- SoftTarget General
  ["SoftTargetForce"] = 0,            -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  ["SoftTargetMatchLocked"] = 0,      -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  ["SoftTargetWithLocked"] = 0,       -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
  -- SoftTarget Enemy
  ["SoftTargetEnemy"] = 3,            -- Sets when enemy soft targeting should be enabled. 0=off, 1=gamepad, 2=KBM, 3=always
  ["SoftTargetEnemyArc"] = 0,         -- 0 = No yaw arc allowed, must be directly in front (More precise. Harder to target far away enemies but better for prioritizing stacked targets). 1 = Must be in front of arc (Less precise. Makes targeting far away enemies easier but prioritizing gets messy with stacked mobs).
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
  ["SoftTargetIconInteract"] = 1,   -- We need this to be enabled for the interaction HUD to work properly.
  ["SoftTargetIconGameObject"] = 1, -- We need this to be enabled for the interaction HUD to work properly.
  -- cursor centering
  ["CursorFreelookCentering"] = 0,  -- !BUG: needs to be set to 0 initially because Blizzard broke something in 10.2, otherwise it wll cause the camera to jolt the equivalent vector to the centered cursor position from where your cursor was before locking.
  ["CursorStickyCentering"] = 1     -- !BUG: we can't use it due to the issue described above. Fore more info, see: https://github.com/Stanzilla/WoWUIBugs/issues/504
}

-- Minimal SoftTarget CVars so the Interaction HUD (softinteract) works when Reticle Targeting
-- is off; full stack remains CM.ConfigReticleTargeting("combatmode").
CM.Constants.InteractionHUDSoftTargetCVarValues = {
  ["interactKeyWarningTutorial"] = 1,
  ["SoftTargetInteract"] = 3,
  ["SoftTargetInteractArc"] = 1,
  ["SoftTargetInteractRange"] = 15,
  ["SoftTargetIconInteract"] = 1,
  ["SoftTargetIconGameObject"] = 1
}

-- CVARS FOR ACTION CAMERA
-- https://warcraft.wiki.gg/wiki/CVar_ActionCam
CM.Constants.ActionCameraCVarValues = {
  ["test_cameraDynamicPitch"] = 1,                       -- Vertical Pitch
  ["test_cameraDynamicPitchBaseFovPad"] = 0,             -- Pitch (ground)
  ["test_cameraDynamicPitchBaseFovPadFlying"] = 0.5,     -- Pitch (flying)
  ["test_cameraDynamicPitchBaseFovPadDownScale"] = 0.25, -- Down Scale
  ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 10,  -- Smart Pivot Cutoff Distance
  ["test_cameraHeadMovementStrength"] = 0,               -- Head Tracking
  ["test_cameraOverShoulder"] = 1.0,                     -- Shoulder horizontal offset
  ["CameraKeepCharacterCentered"] = 0,                   -- Disable Motion Sickness
  ["CameraReduceUnexpectedMovement"] = 0                 -- Disable Motion Sickness
}

-- CVARS FOR STICKY CROSSHAIR
CM.Constants.TagetFocusCVarValues = {
  ["test_cameraTargetFocusEnemyEnable"] = 1,
  ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.7,  -- horizontal strength
  ["test_cameraTargetFocusEnemyStrengthPitch"] = 0.2 -- vertical strength
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
  ["CursorStickyCentering"] = 0
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
  ["CameraReduceUnexpectedMovement"] = 1
}

CM.Constants.BlizzardTagetFocusCVarValues = {
  ["test_cameraTargetFocusEnemyEnable"] = 0,
  ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.4,
  ["test_cameraTargetFocusEnemyStrengthPitch"] = 0.5
}
