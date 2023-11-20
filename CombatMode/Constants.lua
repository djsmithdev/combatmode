local _, Addon = ...

local SetCVar = _G.SetCVar
Addon.Constants = {}

Addon.Constants.BLIZZARD_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SOFT_ENEMY_CHANGED",
  "PLAYER_SOFT_INTERACT_CHANGED",
}

-- Default frames to check
Addon.Constants.FramesToCheck = {
  "AuctionFrame",
  "BankFrame",
  "BattlefieldFrame",
  "CharacterFrame",
  "ChatMenu",
  "EmoteMenu",
  "LanguageMenu",
  "VoiceMacroMenu",
  "ClassTrainerFrame",
  "CoinPickupFrame",
  "CraftFrame",
  "FriendsFrame",
  "GameMenuFrame",
  "GossipFrame",
  "GuildRegistrarFrame",
  "HelpFrame",
  "InspectFrame",
  "KeyBindingFrame",
  "LoXXXotFrame",
  "MacroFrame",
  "MailFrame",
  "MerchantFrame",
  "OptionsFrame",
  "PaperDollFrame",
  "PetPaperDollFrame",
  "PetRenamePopup",
  "PetStable",
  "QuestFrame",
  "QuestLogFrame",
  "RaidFrame",
  "ReputationFrame",
  "ScriptErrors",
  "SkillFrame",
  "SoundOptionsFrame",
  "SpellBookFrame",
  "StackSplitFrame",
  "StatsFrame",
  "SuggestFrame",
  "TabardFrame",
  "TalentFrame",
  "TalentTrainerFrame",
  "TaxiFrame",
  "TradeFrame",
  "TradeSkillFrame",
  "TutorialFrame",
  "UIOptionsFrame",
  "UnitPopup",
  "WorldMapFrame",
  "CosmosMasterFrame",
  "CosmosDropDown",
  "ChooseItemsFrame",
  "ImprovedErrorFrame",
  "TicTacToeFrame",
  "OthelloFrame",
  "MinesweeperFrame",
  "GamesListFrame",
  "ConnectFrame",
  "ChessFrame",
  "QuestShareFrame",
  "TotemStomperFrame",
  "StaticPopXXXup1",
  "StaticPopup2",
  "StaticPopup3",
  "StaticPopup4",
  "DropDownList1",
  "DropDownList2",
  "DropDownList3",
  "WantAds",
  "CosmosDropDownBis",
  "InventoryManagerFrame",
  "InspectPaperDollFrame",
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
  "AutoPotion_Template_Dialog",
  "NxSocial",
  "ARKINV_Frame1",
  "AchievementFrame",
  "LookingForGuildFrame",
  "PVPUIFrame",
  "GuildFrame",
  "WorldMapFrame",
  "VideoOptionsFrame",
  "InterfaceOptionsFrame",
  "WardrobeFrame",
  "ACP_AddonList",
  "PlayerTalentFrame",
  "PVEFrame",
  "EncounterJournal",
  "PetJournalParent",
  "AccountantFrame",
  "ImmersionFrame",
  "BagnonFrameinventory",
  "BagnonInventory1",
  "GwCharacterWindow",
  "GwCharacterWindowsMoverFrame",
  "StaticPopup1",
  "FlightMapFrame",
  "CommunitiesFrame",
  "DungeonReadyPopup",
  "LFGDungeonReadyDialog",
  "PVPMatchResults",
  "ReadyCheckListenerFrame",
  "BonusRollFrame",
  "QuickKeybindFrame",
  "MAOptions",
  "ClassTalentFrame",
  "CollectionsJournal",
  "ProfessionsFrame",
  "ItemUpgradeFrame",
  "ContainerFrameCombinedBags",
  "LootFrame",
  "DressUpFrame",
  "PetitionFrame",
  "QuestLogPopupDetailFrame",
  "SettingsPanel",
  "EditModeManagerFrame",
  "DeathRecapFrame",
  "AddonList",
  "SplashFrame",
  "CalendarFrame",
  "ExpansionLandingPage",
  "GenericTraitFrame",
  "PlayerChoiceFrame",
  "ItemInteractionFrame",
  "ScriptErrorsFrame"
}

Addon.Constants.wildcardFramesToMatch = {
  "OPieRT"
}

Addon.Constants.wildcardFramesToCheck = {}

Addon.Constants.defaultButtonValues = {
  MOVEANDSTEER = "MOVEANDSTEER",
  MOVEBACKWARD = "MOVEBACKWARD",
  MOVEFORWARD = "MOVEFORWARD",
  JUMP = "JUMP",
  CAMERAORSELECTORMOVE = "CAMERAORSELECTORMOVE",
  FOCUSTARGET = "FOCUSTARGET",
  FOLLOWTARGET = "FOLLOWTARGET",
  TARGETSCANENEMY = "TARGETSCANENEMY",
  INTERACTTARGET = "INTERACTTARGET",
  TARGETFOCUS = "TARGETFOCUS",
  TARGETLASTHOSTILE = "TARGETLASTHOSTILE",
  TARGETLASTTARGET = "TARGETLASTTARGET",
  TARGETNEAREST = "TARGETNEAREST",
  TARGETNEARESTENEMY = "TARGETNEARESTENEMY",
  TARGETNEARESTENEMYPLAYER = "TARGETNEARESTENEMYPLAYER",
  TARGETNEARESTFRIEND = "TARGETNEARESTFRIEND",
  TARGETNEARESTFRIENDPLAYER = "TARGETNEARESTFRIENDPLAYER",
  TARGETPET = "TARGETPET",
  TARGETPREVIOUS = "TARGETPREVIOUS",
  TARGETPREVIOUSENEMY = "TARGETPREVIOUSENEMY",
  TARGETPREVIOUSENEMYPLAYER = "TARGETPREVIOUSENEMYPLAYER",
  TARGETPREVIOUSFRIEND = "TARGETPREVIOUSFRIEND",
  TARGETPREVIOUSFRIENDPLAYER = "TARGETPREVIOUSFRIENDPLAYER",
  TARGETSELF = "TARGETSELF",
  ACTIONBUTTON1 = "ACTIONBUTTON1",
  ACTIONBUTTON2 = "ACTIONBUTTON2",
  ACTIONBUTTON3 = "ACTIONBUTTON3",
  ACTIONBUTTON4 = "ACTIONBUTTON4",
  ACTIONBUTTON5 = "ACTIONBUTTON5",
  ACTIONBUTTON6 = "ACTIONBUTTON6",
  ACTIONBUTTON7 = "ACTIONBUTTON7",
  ACTIONBUTTON8 = "ACTIONBUTTON8",
  ACTIONBUTTON9 = "ACTIONBUTTON9",
  ACTIONBUTTON10 = "ACTIONBUTTON10",
  ACTIONBUTTON11 = "ACTIONBUTTON11",
  ACTIONBUTTON12 = "ACTIONBUTTON12",
  MACRO = "MACRO"
}

Addon.Constants.buttonsToOverride = {
  "button1",
  "button2",
  "shiftbutton1",
  "shiftbutton2",
  "ctrlbutton1",
  "ctrlbutton2",
  "altbutton1",
  "altbutton2"
}

Addon.Constants.macroFieldDescription = "Enter the name of the macro you wish to be ran here."

-- CVARS FOR RETICLE TARGETING
function Addon.Constants.loadReticleTargetCvars()
  -- general
  SetCVar("SoftTargetForce", 1) -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  SetCVar("SoftTargetMatchLocked", 1) -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  SetCVar("SoftTargetWithLocked", 2) -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
  SetCVar("SoftTargetNameplateEnemy", 1)
  SetCVar("SoftTargetNameplateInteract", 0)
  -- interact
  SetCVar("SoftTargetInteract", 3) -- 3 = always on
  SetCVar("SoftTargetInteractArc", 0)
  SetCVar("SoftTargetInteractRange", 15)
  SetCVar("SoftTargetIconInteract", 1)
  SetCVar("SoftTargetIconGameObject", 1)
  -- friendly target
  SetCVar("SoftTargetFriend", 3)
  SetCVar("SoftTargetFriendArc", 0)
  SetCVar("SoftTargetFriendRange", 15)
  SetCVar("SoftTargetIconFriend", 0)
  -- enemy target
  SetCVar("SoftTargetEnemy", 3)
  SetCVar("SoftTargetEnemyArc", 0) -- 0 = No yaw arc allowed, must be directly in front (More precise. Harder to target far away enemies but better for prioritizing stacked targets). 1 = Must be in front of arc (Less precise. Makes targeting far away enemies easier but prioritizing gets messy with stacked mobs).
  SetCVar("SoftTargetEnemyRange", 60)
  SetCVar("SoftTargetIconEnemy", 0)

  -- print("Combat Mode: Reticle Target CVars LOADED")
end

-- DEFAULT BLIZZARD VALUES
-- !! DO NOT CHANGE !!
function Addon.Constants.loadDefaultCvars()
  -- general
  SetCVar("SoftTargetForce", 1)
  SetCVar("SoftTargetMatchLocked", 1)
  SetCVar("SoftTargetWithLocked", 1)
  SetCVar("SoftTargetNameplateEnemy", 1)
  SetCVar("SoftTargetNameplateInteract", 0)
  -- interact
  SetCVar("SoftTargetInteract", 1)
  SetCVar("SoftTargetInteractArc", 0)
  SetCVar("SoftTargetInteractRange", 10)
  SetCVar("SoftTargetIconInteract", 1)
  SetCVar("SoftTargetIconGameObject", 0)
  -- friendly target
  SetCVar("SoftTargetFriend", 0)
  SetCVar("SoftTargetFriendArc", 2)
  SetCVar("SoftTargetFriendRange", 45)
  SetCVar("SoftTargetIconFriend", 0)
  -- enemy target
  SetCVar("SoftTargetEnemy", 1)
  SetCVar("SoftTargetEnemyArc", 2)
  SetCVar("SoftTargetEnemyRange", 45)
  SetCVar("SoftTargetIconEnemy", 0)

  -- print("Combat Mode: Reticle Target CVars RESET")
end
