local CM = _G.GetGlobalStore()

CM.Constants = {}

CM.Constants.CrosshairTexture = "Interface\\AddOns\\CombatMode\\assets\\crosshair.tga"
CM.Constants.CrosshairActiveTexture = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"

CM.Constants.BLIZZARD_EVENTS = {
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SOFT_ENEMY_CHANGED",
  "PLAYER_SOFT_INTERACT_CHANGED"
}

-- Default frames to check with a static name
CM.Constants.FramesToCheck = {
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

-- Default frames to check with a dynamic name: any frame containing a string defined here will be matched, e.g. "OPieRT" will match the frame "OPieRT-1234-5678"
CM.Constants.WildcardFramesToMatch = {
  "OPieRT"
}

-- The dynamic names of the frames defined right above, determined on loading into the game world. Do not add frame names in this table, do it above instead!
CM.Constants.WildcardFramesToCheck = {}

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
  "FOCUSTARGET",
  "FOLLOWTARGET",
  "INTERACTTARGET",
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
  "TARGETSELF"
}

-- Matches the bindable actions values defined right above with more readable names for the UI
CM.Constants.OverrideActions = {
  CLEARFOCUS = "Clear Focus",
  CLEARTARGET = "Clear Target",
  CUSTOMACTION = "Custom Action"
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

-- CVARS FOR RETICLE TARGETING
CM.Constants.CustomCVarValues = {
  -- general
  ["SoftTargetForce"] = 1, -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  ["SoftTargetMatchLocked"] = 1, -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  ["SoftTargetWithLocked"] = 2, -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
  ["SoftTargetNameplateEnemy"] = 1,
  ["SoftTargetNameplateInteract"] = 0,
  ["deselectOnClick"] = 1, -- Disables Sticky Targeting. We never want this w/ soft targeting, as it interferes w/ SoftTargetForce
  -- interact
  ["SoftTargetInteract"] = 3, -- 3 = always on
  ["SoftTargetInteractArc"] = 0, -- 0 = No yaw arc allowed, must be directly in front (More precise. Harder to target far away enemies but better for prioritizing stacked targets). 1 = Must be in front of arc (Less precise. Makes targeting far away enemies easier but prioritizing gets messy with stacked mobs).
  ["SoftTargetInteractRange"] = 15,
  ["SoftTargetIconInteract"] = 1,
  ["SoftTargetIconGameObject"] = 1,
  -- friendly target
  ["SoftTargetFriend"] = 3,
  ["SoftTargetFriendArc"] = 0,
  ["SoftTargetFriendRange"] = 15,
  ["SoftTargetIconFriend"] = 0,
  -- enemy target
  ["SoftTargetEnemy"] = 3,
  ["SoftTargetEnemyArc"] = 0,
  ["SoftTargetEnemyRange"] = 60,
  ["SoftTargetIconEnemy"] = 0
}

-- DEFAULT BLIZZARD VALUES
-- !! DO NOT CHANGE !!
CM.Constants.BlizzardCVarValues = {
  ["SoftTargetForce"] = 1,
  ["SoftTargetMatchLocked"] = 1,
  ["SoftTargetWithLocked"] = 1,
  ["SoftTargetNameplateEnemy"] = 1,
  ["SoftTargetNameplateInteract"] = 0,
  ["SoftTargetInteract"] = 1,
  ["SoftTargetInteractArc"] = 0,
  ["SoftTargetInteractRange"] = 10,
  ["SoftTargetIconInteract"] = 1,
  ["SoftTargetIconGameObject"] = 0,
  ["SoftTargetFriend"] = 0,
  ["SoftTargetFriendArc"] = 2,
  ["SoftTargetFriendRange"] = 45,
  ["SoftTargetIconFriend"] = 0,
  ["SoftTargetEnemy"] = 1,
  ["SoftTargetEnemyArc"] = 2,
  ["SoftTargetEnemyRange"] = 45,
  ["SoftTargetIconEnemy"] = 0
}
