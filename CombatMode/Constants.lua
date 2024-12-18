---------------------------------------------------------------------------------------
--                               CONSTANT DATA & ASSETS                              --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

CM.Constants = {}

---------------------------------------------------------------------------------------
--                                        CVARS                                      --
---------------------------------------------------------------------------------------
-- CVARS FOR RETICLE TARGETING
CM.Constants.ReticleTargetingCVarValues = {
  -- SoftTarget General
  ["interactKeyWarningTutorial"] = 1, -- Hides the interact key tutorial if using the INTERACTMOUSEOVER binding
  ["deselectOnClick"] = 1, -- Disables Sticky Targeting. We never want this w/ soft targeting, as it interferes w/ SoftTargetForce
  ["SoftTargetForce"] = 1, -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  ["SoftTargetMatchLocked"] = 1, -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  ["SoftTargetWithLocked"] = 2, -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
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
  ["SoftTargetNameplateEnemy"] = 1, -- Always show nameplates  for soft target enemy.
  -- SoftTarget Icon
  ["SoftTargetIconEnemy"] = 0,
  ["SoftTargetIconInteract"] = 1,
  ["SoftTargetIconGameObject"] = 1,
  -- cursor centering
  ["CursorFreelookCentering"] = 0, -- !BUG: needs to be set to 0 initially because Blizzard broke something in 10.2, otherwise it wll cause the camera to jolt the equivalent vector to the centered cursor position from where your cursor was before locking.
  ["CursorStickyCentering"] = 1 -- !BUG: we can't use it due to the issue described above. Fore more info, see: https://github.com/Stanzilla/WoWUIBugs/issues/504
}

-- CVARS FOR ACTION CAMERA
-- https://warcraft.wiki.gg/wiki/CVar_ActionCam
CM.Constants.ActionCameraCVarValues = {
  ["test_cameraDynamicPitch"] = 1, -- Vertical Pitch
  ["test_cameraDynamicPitchBaseFovPad"] = 0, -- Pitch (ground)
  ["test_cameraDynamicPitchBaseFovPadFlying"] = 0.5, -- Pitch (flying)
  ["test_cameraDynamicPitchBaseFovPadDownScale"] = 0.25, -- Down Scale
  ["test_cameraDynamicPitchSmartPivotCutoffDist"] = 10, -- Smart Pivot Cutoff Distance
  ["test_cameraHeadMovementStrength"] = 0, -- Head Tracking
  ["test_cameraOverShoulder"] = 1.2, -- Shoulder horizontal offset
  ["CameraKeepCharacterCentered"] = 0, -- Disable Motion Sickness
  ["CameraReduceUnexpectedMovement"] = 0 -- Disable Motion Sickness
}

-- CVARS FOR STICKY CROSSHAIR / TARGET FOCUS
CM.Constants.TagetFocusCVarValues = {
  ["test_cameraTargetFocusEnemyEnable"] = 1,
  ["test_cameraTargetFocusEnemyStrengthYaw"] = 0.7, -- horizontal strength
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

---------------------------------------------------------------------------------------
--                                       MACROS                                      --
---------------------------------------------------------------------------------------
-- For interrupts/taunts we use CM_PrioritizeTarge
-- For everything else we wannna macro, we use CM_PrioritizeCursor
CM.Constants.Macros = {
  CM_ClearTarget = "/stopmacro [noexists]\n/cleartarget",
  CM_ClearFocus = "/stopmacro [noexists]\n/clearfocus",
  CM_CastCursor = "#showtooltip\n/cast [mod:shift] SPELL; [@cursor] SPELL",
  CM_PrioritizeTarget = "#showtooltip\n/cleartarget [help][noharm][dead]\n/cast [@target,harm,nodead][@mouseover,harm,nodead] SPELL\n/startattack",
  CM_PrioritizeCursor = "#showtooltip\n/cleartarget [help][noharm][dead]\n/cast [@mouseover,harm,nodead][@target,harm,nodead] SPELL\n/startattack",
  CM_PrioritizeCursorShift = "#showtooltip [mod:shift] SPELL_1; SPELL_2\n/cleartarget [help][noharm][dead]\n/cast [mod:shift,@mouseover,harm,nodead][mod:shift,@target,harm,nodead] SPELL_1; [@mouseover,harm,nodead][@target,harm,nodead] SPELL_2\n/startattack",
}

---------------------------------------------------------------------------------------
--                                  REGISTERED EVENTS                                --
---------------------------------------------------------------------------------------
-- EVENTS TO BE TRACKED
CM.Constants.BLIZZARD_EVENTS = {
  -- Events that fire UnlockFreeLook()
  UNLOCK_EVENTS = {
    "LOADING_SCREEN_ENABLED", -- This forces a relock when quick-loading (e.g: loading after starting m+ run) thanks to the OnUpdate fn
    "BARBER_SHOP_OPEN",
    "CINEMATIC_START",
    "PLAY_MOVIE"
  },
  -- Events that fire LockFreeLook()
  LOCK_EVENTS = {
    "CINEMATIC_STOP",
    "STOP_MOVIE"
  },
  -- Events that fire Rematch()
  REMATCH_EVENTS = {
    "PLAYER_ENTERING_WORLD" -- Loading Cvars on every reload
  },
  -- Events responsible for crosshair reaction
  TARGETING_EVENTS = {
    "PLAYER_SOFT_ENEMY_CHANGED",
    "PLAYER_SOFT_INTERACT_CHANGED"
  },
  FRIENDLY_TARGETING_EVENTS = {
    "PLAYER_REGEN_ENABLED", -- Disabling friendly targeting when leaving combat
    "PLAYER_REGEN_DISABLED" -- Enabling friendly targeting when entering combat
  },
  -- Events that don't fall within the previous categories
  UNCATEGORIZED_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED", -- Toggling crosshair when mounting/dismounting
    "PLAYER_REGEN_ENABLED" -- Resetting crosshair when leaving combat
  }
}

---------------------------------------------------------------------------------------
--                                        ASSETS                                     --
---------------------------------------------------------------------------------------
CM.Constants.PopupMsg = CM.METADATA["TITLE"] ..
                          "\n\n|cffffd700Thank you for trying out Combat Mode!|r \n\n|cffcfcfcfUpon closing this, an |cffB47EDEoptions panel|r will open where you'll be able to configure the addon to your liking.|r\n\n|cff909090To |cffFF5050undo all changes|r made by Combat Mode, type the following command in chat:|r\n|cff00FFFF/undocm|r"

CM.Constants.BasePrintMsg = CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r"

local assetsFolderPath = "Interface\\AddOns\\CombatMode\\assets\\"

CM.Constants.Logo = assetsFolderPath .. "cmlogo.blp"

CM.Constants.Title = assetsFolderPath .. "cmtitle.blp"

CM.Constants.PulseAtlas = "dragonflight-landingbutton-circleglow"

--[[
  CROSSHAIR TEXTURES
  To add custom textures, you'll need two .BLP textures: one for the active and one for the inactive states.
  Place them in the the CombatMode/assets folder and rename them as follows:
  Base texture = "crosshairASSETNAME.blp"
  Hit texture = "crosshairASSETNAME-hit.blp"
  Where "ASSETNAME" is the name you want to be displayed on the dropdown.
  Then just add that same "ASSETNAME" to the CrosshairTextureObj table below:
  This is case sensitive!
]] --
CM.Constants.CrosshairTextureObj = {}

CM.Constants.CrosshairAppearanceSelectValues = {}

local crosshairAssetNames = {
  "Arrows",
  "Bracket",
  "Cross",
  "Default",
  "Diamond",
  "Dot",
  "InvertedY",
  "Line",
  "Ornated",
  "Split",
  "Square",
  "Triangle",
  "X"
}

for _, assetName in ipairs(crosshairAssetNames) do
  CM.Constants.CrosshairTextureObj[assetName] = {
    Name = assetName,
    Base = assetsFolderPath .. "crosshair" .. assetName .. ".blp",
    Active = assetsFolderPath .. "crosshair" .. assetName .. "-hit.blp"
  }
  CM.Constants.CrosshairAppearanceSelectValues[assetName] = assetName
end

-- CROSSHAIR REACTION COLORS
CM.Constants.CrosshairReactionColors = {
  hostile = {1, .2, 0.3, 1}, -- red
  friendly = {0, 1, 0.3, .8}, -- green
  object = {1, 0.8, 0.2, .8}, -- yellow
  base = {1, 1, 1, .5}, -- white
  mounted = {1, 1, 1, 0} -- transparent
}

---------------------------------------------------------------------------------------
--                                   FRAME WATCHING                                  --
---------------------------------------------------------------------------------------
-- Default frames to check with a static name
CM.Constants.FramesToCheck = {
  -- Blizzard frames
  "AchievementFrame",
  "AddonList",
  "AuctionFrame",
  "AuctionHouseFrame",
  "BankFrame",
  "BattlefieldFrame",
  "BFAMissionFrame",
  "BonusRollFrame",
  "CalendarFrame",
  "CharacterFrame",
  "ChatMenu",
  "ChooseItemsFrame",
  "ClassTalentFrame",
  "ClassTrainerFrame",
  "ClickBindingFrame",
  "CoinPickupFrame",
  "CollectionsJournal",
  "CommunitiesFrame",
  "ContainerFrame1",
  "ContainerFrame2",
  "ContainerFrame3",
  "ContainerFrame4",
  "ContainerFrame5",
  "ContainerFrame6",
  "ContainerFrame7",
  "ContainerFrame8",
  "ContainerFrame9",
  "ContainerFrame10",
  "ContainerFrame11",
  "ContainerFrame12",
  "ContainerFrame13",
  "ContainerFrame14",
  "ContainerFrame15",
  "ContainerFrame16",
  "ContainerFrame17",
  "ContainerFrameCombinedBags",
  "CovenantMissionFrame",
  "CovenantSanctumFrame",
  "DeathRecapFrame",
  "DressUpFrame",
  "DropDownList1",
  "DropDownList2",
  "DropDownList3",
  "DungeonReadyPopup",
  "EditModeManagerFrame",
  "EmoteMenu",
  "EncounterJournal",
  "ExpansionLandingPage",
  "FlightMapFrame",
  "FriendsFrame",
  "GameMenuFrame",
  "GarrisonCapacitiveDisplayFrame",
  "GenericTraitFrame",
  "GossipFrame",
  "GuildFrame",
  "GuildRegistrarFrame",
  "HelpFrame",
  "InspectFrame",
  "InspectPaperDollFrame",
  "InterfaceOptionsFrame",
  "InventoryManagerFrame",
  "ItemInteractionFrame",
  "ItemUpgradeFrame",
  "ItemTextFrame",
  "KeyBindingFrame",
  "LanguageMenu",
  "LFGDungeonReadyDialog",
  "LFDRoleCheckPopup",
  "LFGListInviteDialog",
  "LookingForGuildFrame",
  "MacroFrame",
  "MailFrame",
  "MajorFactionRenownFrame",
  "MerchantFrame",
  "OptionsFrame",
  "OrderHallMissionFrame",
  "OrderHallTalentFrame",
  "PaperDollFrame",
  "PetitionFrame",
  "PetPaperDollFrame",
  "PetRenamePopup",
  "PetStable",
  "PlayerChoiceFrame",
  "PlayerTalentFrame",
  "ProfessionsCustomerOrdersFrame",
  "ProfessionsFrame",
  "PVEFrame",
  "PVPMatchResults",
  "PVPMatchScoreboard",
  "PVPUIFrame",
  "QuestFrame",
  "QuestLogFrame",
  "QuestLogPopupDetailFrame",
  "QuestShareFrame",
  "QuickKeybindFrame",
  "RaidFrame",
  "ReadyCheckListenerFrame",
  "ReputationFrame",
  "ScriptErrorsFrame",
  "SkillFrame",
  "SettingsPanel",
  "SpellBookFrame",
  "SplashFrame",
  "StackSplitFrame",
  "StaticPopup1",
  "StaticPopup2",
  "StaticPopup3",
  "StaticPopup4",
  "StatsFrame",
  "SuggestFrame",
  "TabardFrame",
  "TalentFrame",
  "TalentTrainerFrame",
  "TaxiFrame",
  "TorghastLevelPickerFrame",
  "TradeFrame",
  "TradeSkillFrame",
  "TutorialFrame",
  "UnitPopup",
  "VoiceMacroMenu",
  "WardrobeFrame",
  "WorldMapFrame",
  "AccountantFrame",
  "ACP_AddonList",
  "ARKINV_Frame1",
  "AutoPotion_Template_Dialog",
  "BagnonFrameinventory",
  "BagnonInventory1",
  "ChessFrame",
  "ConnectFrame",
  "CosmosDropDown",
  "CosmosDropDownBis",
  "CosmosMasterFrame",
  "CraftFrame",
  "GamesListFrame",
  "GwCharacterWindow",
  "GwCharacterWindowsMoverFrame",
  "ImmersionFrame",
  "ImprovedErrorFrame",
  "LoXXXotFrame",
  "MAOptions",
  "MinesweeperFrame",
  "NxSocial",
  "OthelloFrame",
  "PetJournalParent",
  "SoundOptionsFrame",
  "StaticPopXXXup1",
  "TicTacToeFrame",
  "TotemStomperFrame",
  "UIOptionsFrame",
  "VideoOptionsFrame",
  "WantAds",
  "SubscriptionInterstitialFrame",
  "CinematicFrameCloseDialog",
  "MovieFrame"
}

-- Default frames to check with a dynamic name: any frame containing a string defined here will be matched, e.g. "OPieRT" will match the frame "OPieRT-1234-5678"
CM.Constants.WildcardFramesToMatch = {
  "OPieRT"
}

-- The dynamic names of the frames defined right above, determined on loading into the game world. Do not add frame names in this table, do it above instead!
CM.Constants.WildcardFramesToCheck = {}

-- Vendor mounts to force UnlockFreeLook
CM.Constants.MountsToCheck = {
  "Grand Expedition Yak",
  "Traveler's Tundra Mammoth",
  "Mighty Caravan Brutosaur",
  "Trader's Gilded Brutosaur",
  "Grizzly Hills Packmaster"
}

---------------------------------------------------------------------------------------
--                                   BUTTON OVERRIDE                                 --
---------------------------------------------------------------------------------------
-- The name of the actions a user can bind to mouse buttons
CM.Constants.ActionsToProcess = {
  "ACTIONBUTTON1",
  "ACTIONBUTTON2",
  "ACTIONBUTTON3",
  "ACTIONBUTTON4",
  "ACTIONBUTTON5",
  "ACTIONBUTTON6",
  "ACTIONBUTTON7",
  "ACTIONBUTTON8",
  "ACTIONBUTTON9",
  "ACTIONBUTTON10",
  "ACTIONBUTTON11",
  "ACTIONBUTTON12",
  "MULTIACTIONBAR1BUTTON1",
  "MULTIACTIONBAR1BUTTON2",
  "MULTIACTIONBAR1BUTTON3",
  "MULTIACTIONBAR1BUTTON4",
  "MULTIACTIONBAR1BUTTON5",
  "MULTIACTIONBAR1BUTTON6",
  "MULTIACTIONBAR1BUTTON7",
  "MULTIACTIONBAR1BUTTON8",
  "MULTIACTIONBAR1BUTTON9",
  "MULTIACTIONBAR1BUTTON10",
  "MULTIACTIONBAR1BUTTON11",
  "MULTIACTIONBAR1BUTTON12",
  "MULTIACTIONBAR2BUTTON1",
  "MULTIACTIONBAR2BUTTON2",
  "MULTIACTIONBAR2BUTTON3",
  "MULTIACTIONBAR2BUTTON4",
  "MULTIACTIONBAR2BUTTON5",
  "MULTIACTIONBAR2BUTTON6",
  "MULTIACTIONBAR2BUTTON7",
  "MULTIACTIONBAR2BUTTON8",
  "MULTIACTIONBAR2BUTTON9",
  "MULTIACTIONBAR2BUTTON10",
  "MULTIACTIONBAR2BUTTON11",
  "MULTIACTIONBAR2BUTTON12",
  "MULTIACTIONBAR3BUTTON1",
  "MULTIACTIONBAR3BUTTON2",
  "MULTIACTIONBAR3BUTTON3",
  "MULTIACTIONBAR3BUTTON4",
  "MULTIACTIONBAR3BUTTON5",
  "MULTIACTIONBAR3BUTTON6",
  "MULTIACTIONBAR3BUTTON7",
  "MULTIACTIONBAR3BUTTON8",
  "MULTIACTIONBAR3BUTTON9",
  "MULTIACTIONBAR3BUTTON10",
  "MULTIACTIONBAR3BUTTON11",
  "MULTIACTIONBAR3BUTTON12",
  "MULTIACTIONBAR4BUTTON1",
  "MULTIACTIONBAR4BUTTON2",
  "MULTIACTIONBAR4BUTTON3",
  "MULTIACTIONBAR4BUTTON4",
  "MULTIACTIONBAR4BUTTON5",
  "MULTIACTIONBAR4BUTTON6",
  "MULTIACTIONBAR4BUTTON7",
  "MULTIACTIONBAR4BUTTON8",
  "MULTIACTIONBAR4BUTTON9",
  "MULTIACTIONBAR4BUTTON10",
  "MULTIACTIONBAR4BUTTON11",
  "MULTIACTIONBAR4BUTTON12",
  "FOCUSTARGET",
  "FOLLOWTARGET",
  "INTERACTTARGET",
  "INTERACTMOUSEOVER",
  "JUMP",
  "MOVEANDSTEER",
  "MOVEBACKWARD",
  "MOVEFORWARD",
  "TARGETFOCUS",
  "TARGETLASTHOSTILE",
  "TARGETLASTTARGET",
  "TARGETNEARESTENEMY",
  "TARGETNEARESTENEMYPLAYER",
  "TARGETNEARESTFRIEND",
  "TARGETNEARESTFRIENDPLAYER",
  "TARGETPET",
  "TARGETPREVIOUSENEMY",
  "TARGETPREVIOUSENEMYPLAYER",
  "TARGETPREVIOUSFRIEND",
  "TARGETPREVIOUSFRIENDPLAYER",
  "TARGETSCANENEMY",
  "TARGETSELF",
  "TARGETMOUSEOVER",
  "ASSISTTARGET",
  "ATTACKTARGET",
  "PETATTACK",
  "STARTATTACK",
  "STOPATTACK",
  "STOPCASTING",
  "EXTRAACTIONBUTTON1",
  "ACTIONPAGE1",
  "ACTIONPAGE2",
  "ACTIONPAGE3",
  "ACTIONPAGE4",
  "ACTIONPAGE5",
  "ACTIONPAGE6",
  "BONUSACTIONBUTTON1",
  "BONUSACTIONBUTTON10",
  "BONUSACTIONBUTTON2",
  "BONUSACTIONBUTTON3",
  "BONUSACTIONBUTTON4",
  "BONUSACTIONBUTTON5",
  "BONUSACTIONBUTTON6",
  "BONUSACTIONBUTTON7",
  "BONUSACTIONBUTTON8",
  "BONUSACTIONBUTTON9",
  "CAMERAZOOMIN",
  "CAMERAZOOMOUT",
  "DISMOUNT",
  "NEXTACTIONPAGE",
  "PREVIOUSACTIONPAGE",
  "RAIDTARGET1",
  "RAIDTARGET2",
  "RAIDTARGET3",
  "RAIDTARGET4",
  "RAIDTARGET5",
  "RAIDTARGET6",
  "RAIDTARGET7",
  "RAIDTARGET8",
  "RAIDTARGETNONE",
  "SCREENSHOT",
  "SHAPESHIFTBUTTON1",
  "SHAPESHIFTBUTTON10",
  "SHAPESHIFTBUTTON2",
  "SHAPESHIFTBUTTON3",
  "SHAPESHIFTBUTTON4",
  "SHAPESHIFTBUTTON5",
  "SHAPESHIFTBUTTON6",
  "SHAPESHIFTBUTTON7",
  "SHAPESHIFTBUTTON8",
  "SHAPESHIFTBUTTON9",
  "STRAFELEFT",
  "STRAFERIGHT",
  "TARGETPARTYMEMBER1",
  "TARGETPARTYMEMBER2",
  "TARGETPARTYMEMBER3",
  "TARGETPARTYMEMBER4",
  "TOGGLEAUTORUN",
  "TURNLEFT",
  "TURNRIGHT"
}

-- Matches the bindable actions values defined right above with more readable names for the UI
CM.Constants.OverrideActions = {
  CLEARFOCUS = "|cff69ccf0Clear Focus|r",
  CLEARTARGET = "|cff69ccf0Clear Target|r",
  MACRO = "|cff69ccf0Run MACRO|r"
}

CM.Constants.ButtonsToOverride = {
  "button1",
  "button2",
  "shiftbutton1",
  "shiftbutton2",
  "ctrlbutton1",
  "ctrlbutton2",
  "altbutton1",
  "altbutton2"
}

---------------------------------------------------------------------------------------
--                                DB & BINDING DEFAULTS                              --
---------------------------------------------------------------------------------------
local DefaultBindings = {
  button1 = {
    enabled = true,
    key = "BUTTON1",
    value = "ACTIONBUTTON1",
    macroName = ""
  },
  button2 = {
    enabled = true,
    key = "BUTTON2",
    value = "ACTIONBUTTON2",
    macroName = ""
  },
  shiftbutton1 = {
    enabled = true,
    key = "SHIFT-BUTTON1",
    value = "ACTIONBUTTON3",
    macroName = ""
  },
  shiftbutton2 = {
    enabled = true,
    key = "SHIFT-BUTTON2",
    value = "ACTIONBUTTON4",
    macroName = ""
  },
  ctrlbutton1 = {
    enabled = true,
    key = "CTRL-BUTTON1",
    value = "ACTIONBUTTON5",
    macroName = ""
  },
  ctrlbutton2 = {
    enabled = true,
    key = "CTRL-BUTTON2",
    value = "ACTIONBUTTON6",
    macroName = ""
  },
  altbutton1 = {
    enabled = true,
    key = "ALT-BUTTON1",
    value = "ACTIONBUTTON7",
    macroName = ""
  },
  altbutton2 = {
    enabled = true,
    key = "ALT-BUTTON2",
    value = "ACTIONBUTTON8",
    macroName = ""
  },
  toggle = {
    key = "Combat Mode Toggle",
    value = "BUTTON3"
  },
  hold = {
    key = "(Hold) Switch Mode",
    value = "BUTTON4"
  }
}

CM.Constants.DatabaseDefaults = {
  global = {
    frameWatching = true,
    watchlist = {
      "PawnUIFrame",
      "SortedPrimaryFrame",
      "WeakAurasOptions",
      "DUIQuestFrame",
      "Narci_Vignette"
    },
    actionCamera = false,
    mouseLookSpeed = 120,
    pulseCursor = true,
    mountCheck = false,
    customCondition = "",
    crosshair = true,
    crosshairMounted = false,
    hideTooltip = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairSize = 64,
    crosshairOpacity = 1.0,
    crosshairY = 50,
    debugMode = false,
    bindings = DefaultBindings
  },
  char = {
    useGlobalBindings = false,
    shoulderOffset = 1.2,
    reticleTargeting = true,
    crosshairPriority = true,
    friendlyTargeting = false,
    friendlyTargetingInCombat = false,
    stickyCrosshair = false,
    bindings = DefaultBindings
  }
}
