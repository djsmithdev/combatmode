---------------------------------------------------------------------------------------
--  Constants/ConstantsFrameWatch.lua — constants module: frame watch/mounts
---------------------------------------------------------------------------------------
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

-- Default frames to check with a static name.
CM.Constants.FramesToCheck = {
  "AchievementFrame", "AddonList", "AuctionFrame", "AuctionHouseFrame",
  "BankFrame", "BattlefieldFrame", "BFAMissionFrame", "BonusRollFrame",
  "CalendarFrame", "CharacterFrame", "ChatMenu", "ChooseItemsFrame",
  "ClassTalentFrame", "ClassTrainerFrame", "ClickBindingFrame",
  "CoinPickupFrame", "CollectionsJournal", "CommunitiesFrame",
  "ContainerFrame1", "ContainerFrame2", "ContainerFrame3", "ContainerFrame4",
  "ContainerFrame5", "ContainerFrame6", "ContainerFrame7", "ContainerFrame8",
  "ContainerFrame9", "ContainerFrame10", "ContainerFrame11",
  "ContainerFrame12", "ContainerFrame13", "ContainerFrame14",
  "ContainerFrame15", "ContainerFrame16", "ContainerFrame17",
  "ContainerFrameCombinedBags", "CovenantMissionFrame",
  "CovenantSanctumFrame", "DeathRecapFrame", "DressUpFrame", "DropDownList1",
  "DropDownList2", "DropDownList3", "DungeonReadyPopup",
  "EditModeManagerFrame", "EmoteMenu", "EncounterJournal",
  "ExpansionLandingPage", "FlightMapFrame", "FriendsFrame", "GameMenuFrame",
  "GarrisonCapacitiveDisplayFrame", "GenericTraitFrame", "GossipFrame",
  "GuildFrame", "GuildRegistrarFrame", "HelpFrame", "InspectFrame",
  "InspectPaperDollFrame", "InterfaceOptionsFrame", "InventoryManagerFrame",
  "ItemInteractionFrame", "ItemUpgradeFrame", "ItemTextFrame",
  "KeyBindingFrame", "LanguageMenu", "LFGDungeonReadyDialog",
  "LFDRoleCheckPopup", "LFGListInviteDialog", "LookingForGuildFrame",
  "MacroFrame", "MailFrame", "MajorFactionRenownFrame", "MerchantFrame",
  "OptionsFrame", "OrderHallMissionFrame", "OrderHallTalentFrame",
  "PaperDollFrame", "PetitionFrame", "PetPaperDollFrame", "PetRenamePopup",
  "PetStable", "PlayerChoiceFrame", "PlayerTalentFrame",
  "ProfessionsCustomerOrdersFrame", "ProfessionsFrame", "PVEFrame",
  "PVPMatchResults", "PVPMatchScoreboard", "PVPUIFrame", "QuestFrame",
  "QuestLogFrame", "QuestLogPopupDetailFrame", "QuestShareFrame",
  "QuickKeybindFrame", "RaidFrame", "ReadyCheckListenerFrame",
  "ReputationFrame", "ScriptErrorsFrame", "SkillFrame", "SettingsPanel",
  "SpellBookFrame", "SplashFrame", "StackSplitFrame", "StaticPopup1",
  "StaticPopup2", "StaticPopup3", "StaticPopup4", "StatsFrame",
  "SuggestFrame", "TabardFrame", "TalentFrame", "TalentTrainerFrame",
  "TaxiFrame", "TorghastLevelPickerFrame", "TradeFrame", "TradeSkillFrame",
  "TutorialFrame", "UnitPopup", "VoiceMacroMenu", "WardrobeFrame",
  "WorldMapFrame", "AccountantFrame", "ACP_AddonList", "ARKINV_Frame1",
  "AutoPotion_Template_Dialog", "BagnonFrameinventory", "BagnonInventory1",
  "ChessFrame", "ConnectFrame", "CosmosDropDown", "CosmosDropDownBis",
  "CosmosMasterFrame", "CraftFrame", "GamesListFrame", "GwCharacterWindow",
  "GwCharacterWindowsMoverFrame", "ImmersionFrame", "ImprovedErrorFrame",
  "LoXXXotFrame", "MAOptions", "MinesweeperFrame", "NxSocial", "OthelloFrame",
  "PetJournalParent", "SoundOptionsFrame", "StaticPopXXXup1",
  "TicTacToeFrame", "TotemStomperFrame", "UIOptionsFrame",
  "VideoOptionsFrame", "WantAds", "SubscriptionInterstitialFrame",
  "CinematicFrameCloseDialog", "MovieFrame", "HouseEditorFrame",
  "HousingDashboardFrame", "CatalogShopFrame",
  "HousingCornerstonePurchaseFrame", "ProfessionsBookFrame",
  "DelvesDifficultyPickerFrame",
  "Baganator_CategoryViewBackpackViewFrameblizzard",
  "Baganator_CategoryViewBackpackViewFramegw2_ui",
  "Baganator_CategoryViewBackpackViewFrame"
}

-- Default wildcard patterns and known candidates by prefix.
CM.Constants.WildcardFramesToMatch = { "OPieRT" }

CM.Constants.WildcardFrameCandidates = {
  OPieRT = { "OPieRT", "OPieRT-1", "OPieRT-2", "OPieRT-3" }
}

-- Runtime-discovered wildcard frame names.
CM.Constants.WildcardFramesToCheck = {}

-- Vendor mounts to force UnlockFreeLook.
CM.Constants.MountsToCheck = {
  61447,  -- Traveler's Tundra Mammoth
  122708, -- Grand Expedition Yak
  264058, -- Mighty Caravan Brutosaur
  465235, -- Trader's Gilded Brutosaur
  457485  -- Grizzly Hills Packmaster
}
