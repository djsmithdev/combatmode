-- CONSTANT DATA & ASSETS
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

CM.Constants = {}

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
  -- Events that don't fall within the previous categories
  UNCATEGORIZED_EVENTS = {
    "PLAYER_MOUNT_DISPLAY_CHANGED", -- Toggling crosshair when mounting/dismounting
    "PLAYER_REGEN_ENABLED" -- Reseting crosshair when leaving combat
  },
}

CM.Constants.PopupMsg = CM.METADATA["TITLE"] ..
                          "\n|cffffd700Planning on uninstalling?|r \nBefore doing so, make sure to uncheck the |cff00FFFFReticle Targeting|r option under settings to reset the CVars to their default values.|r \n|cff909090Type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r for settings.|r"

CM.Constants.BasePrintMsg = CM.METADATA["TITLE"] .. " |cff00ff00v." .. CM.METADATA["VERSION"] .. "|r"

local assetsFolderPath = "Interface\\AddOns\\CombatMode\\assets\\"

CM.Constants.Logo = assetsFolderPath .. "cmlogo.blp"

CM.Constants.Title = assetsFolderPath .. "cmtitle.blp"

-- CROSSHAIR TEXTURES
-- To add custom textures, you'll need two .BLP textures: one for the active and one for the inactive states.
-- Place them in the the CombatMode/assets folder and rename them as follows:
-- Base texture = "crosshairASSETNAME.blp"
-- Hit texture = "crosshairASSETNAME-hit.blp"
-- Where "ASSETNAME" is the name you want to be displayed on the dropdown.
-- Then just add that same "ASSETNAME" to the CrosshairTextureObj table below:
-- This is case sensitive!
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
  "X",
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

-- Default frames to check with a static name
CM.Constants.FramesToCheck = {
  -- Blizzard frames
  "AchievementFrame",
  "AddonList",
  "AuctionFrame",
  "AuctionHouseFrame",
  "BankFrame",
  "BattlefieldFrame",
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
  "LFGListInviteDialog",
  "LookingForGuildFrame",
  "LootFrame",
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
  "OPieRT",
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
  "TARGETMOUSEOVER"
}

-- Matches the bindable actions values defined right above with more readable names for the UI
CM.Constants.OverrideActions = {
  CLEARFOCUS = "Clear Focus",
  CLEARTARGET = "Clear Target",
  CUSTOMACTION = "Custom Action"
}

CM.Constants.Macros = {
  CM_ClearTarget = "/stopmacro [noexists]\n/cleartarget",
  CM_ClearFocus = "/clearfocus",
  CM_HardTarget = "#showtooltip\n/cleartarget [help][noharm,exists][dead]\n/target [@mouseover,harm,nodead]\n/startattack\n/cast PLACEHOLDER_SPELL",
  CM_SoftTarget = "#showtooltip\n/cleartarget\n/cast [@mouseover,harm,nodead][] PLACEHOLDER_SPELL\n/startattack",
  CM_CastCursor = "#showtooltip\n/cast [mod:shift] PLACEHOLDER_SPELL; [nomod, @cursor] PLACEHOLDER_SPELL"
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
  ["SoftTargetFriend"] = 0,
  ["SoftTargetFriendArc"] = 0,
  ["SoftTargetFriendRange"] = 15,
  ["SoftTargetIconFriend"] = 0,
  -- enemy target
  ["SoftTargetEnemy"] = 3,
  ["SoftTargetEnemyArc"] = 0,
  ["SoftTargetEnemyRange"] = 60,
  ["SoftTargetIconEnemy"] = 0,
  -- cursor centering
  ["CursorFreelookCentering"] = 0, -- needs to be set to 0 initially because Blizzard changed this cvar to be called BEFORE MouselookStart() method, which means if we set to 1 by default, it will cause the camera to snap to cursor position as you enable free look.
  ["CursorStickyCentering"] = 1 -- does not work in its current implementation. Most likely related to the recent CursorFreelookCentering change.
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
  ["SoftTargetIconEnemy"] = 0,
  ["CursorFreelookCentering"] = 0,
  ["CursorStickyCentering"] = 0
}

local DefaultBindings = {
  button1 = {
    enabled = true,
    key = "BUTTON1",
    value = "ACTIONBUTTON1",
    customAction = ""
  },
  button2 = {
    enabled = true,
    key = "BUTTON2",
    value = "ACTIONBUTTON2",
    customAction = ""
  },
  shiftbutton1 = {
    enabled = true,
    key = "SHIFT-BUTTON1",
    value = "ACTIONBUTTON3",
    customAction = ""
  },
  shiftbutton2 = {
    enabled = true,
    key = "SHIFT-BUTTON2",
    value = "ACTIONBUTTON4",
    customAction = ""
  },
  ctrlbutton1 = {
    enabled = true,
    key = "CTRL-BUTTON1",
    value = "ACTIONBUTTON5",
    customAction = ""
  },
  ctrlbutton2 = {
    enabled = true,
    key = "CTRL-BUTTON2",
    value = "ACTIONBUTTON6",
    customAction = ""
  },
  altbutton1 = {
    enabled = true,
    key = "ALT-BUTTON1",
    value = "ACTIONBUTTON7",
    customAction = ""
  },
  altbutton2 = {
    enabled = true,
    key = "ALT-BUTTON2",
    value = "ACTIONBUTTON8",
    customAction = ""
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
      "WeakAurasOptions"
    },
    customCondition = "",
    reticleTargeting = true,
    crosshairPriority = true,
    crosshair = true,
    crosshairMounted = true,
    crosshairAppearance = CM.Constants.CrosshairTextureObj.Default,
    crosshairSize = 64,
    crosshairOpacity = 1.0,
    crosshairY = 100,
    debugMode = false,
    bindings = DefaultBindings
  },
  char = {
    useGlobalBindings = false,
    bindings = DefaultBindings
  }
}
