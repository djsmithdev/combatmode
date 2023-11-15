-- Author: justice7ca w/ contributions from DKulan and sampconrad
CombatMode = LibStub("AceAddon-3.0"):NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")

-- Local variables
local combatModeAddonSwitch = false
local combatModeTemporaryDisable = false
local CursorActionActive = false
local CombatModeQuiet = true
local mouseLookStarted = false

-- Default frames to check
local FramesToCheck = {
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
	 "GwCharacterWindow",
	 "GwCharacterWindowsMoverFrame",
	 "StaticPopup1",
	 "FlightMapFrame",
	 "CommunitiesFrame",
	 "DungeonReadyPopup",
	 "LFGDungeonReadyDialog",
	 "BossBanner",
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
}

-- CVARS FOR RETICLE TARGETING
function CombatMode:loadReticleTargetCvars()
  -- -- interact
  SetCVar("SoftTargetInteract", 3) -- 3 = always on
  SetCVar("SoftTargetInteractArc", 1)
  SetCVar("SoftTargetInteractRange", 15)
  SetCVar("SoftTargetIconInteract", 1)
  SetCVar("SoftTargetIconGameObject", 1)
  
  -- -- friendly target
  SetCVar("SoftTargetFriend", 3)
  SetCVar("SoftTargetFriendArc", 1)
  SetCVar("SoftTargetFriendRange", 15)
  SetCVar("SoftTargetIconFriend", 1)

  -- -- enemy target
  SetCVar("SoftTargetEnemy", 3)
  SetCVar("SoftTargetEnemyArc", 0) -- 0 = No yaw arc allowed, must be directly in front (More precise. Harder to target far away enemies but better for prioritizing stacked targets). 1 = Must be in front of arc (Less precise. Makes targeting far away enemies easier but prioritizing gets messy with stacked mobs).
  SetCVar("SoftTargetEnemyRange", 60)
  SetCVar("SoftTargetIconEnemy", 0)

  -- -- general
  SetCVar("SoftTargetForce", 1) -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
  SetCVar("SoftTargetMatchLocked", 1) -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
  SetCVar("SoftTargetWithLocked", 2) -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
  SetCVar("SoftTargetNameplateEnemy", 1)
  SetCVar("SoftTargetNameplateInteract", 0)

  -- print("Combat Mode: Reticle Target CVars LOADED")
end

-- DEFAULT BLIZZARD VALUES
-- !! DO NOT CHANGE !!
function CombatMode:loadDefaultCvars()
  -- -- interact
  SetCVar("SoftTargetInteract", 1)
  SetCVar("SoftTargetInteractArc", 0)
  SetCVar("SoftTargetInteractRange", 10)
  SetCVar("SoftTargetIconInteract", 1)
  SetCVar("SoftTargetIconGameObject", 0)
  
  -- -- friendly target
  SetCVar("SoftTargetFriend", 0)
  SetCVar("SoftTargetFriendArc", 2)
  SetCVar("SoftTargetFriendRange", 45)
  SetCVar("SoftTargetIconFriend", 0)

  -- -- enemy target
  SetCVar("SoftTargetEnemy", 1)
  SetCVar("SoftTargetEnemyArc", 2)
  SetCVar("SoftTargetEnemyRange", 45)
  SetCVar("SoftTargetIconEnemy", 0)

  -- -- general
  SetCVar("SoftTargetForce", 1)
  SetCVar("SoftTargetMatchLocked", 1)
  SetCVar("SoftTargetNameplateEnemy", 1)
  SetCVar("SoftTargetNameplateInteract", 0)

  -- print("Combat Mode: Reticle Target CVars RESET")
end

-- Default button values
function CombatMode:OnInitialize()

	defaultButtonValues = {
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
		ACTIONBUTTON12 = "ACTIONBUTTON12"
	}

	databaseDefaults = {
		global = {
		  version = "1.0.0",
			watchlist = {
				"SortedPrimaryFrame", 
				"WeakAurasOptions",
			},
			frameWatching = true,
			reticleTargeting = false,
		},
		profile = {
			bindings = {
				button1 = {
					key = "BUTTON1",
					value = "ACTIONBUTTON1",
				},
				button2 = {
					key = "BUTTON2",
					value = "ACTIONBUTTON2",
				},
				shiftbutton1 = {
					key = "SHIFT-BUTTON1",
					value = "ACTIONBUTTON3",
				},
				shiftbutton2 = {
					key = "SHIFT-BUTTON2",
					value = "ACTIONBUTTON4",
				},
				ctrlbutton1 = {
					key = "CTRL-BUTTON1",
					value = "ACTIONBUTTON5",
				},
				ctrlbutton2 = {
					key = "CTRL-BUTTON2",
					value = "ACTIONBUTTON6",
				},
				altbutton1 = {
					key = "ALT-BUTTON1",
					value = "ACTIONBUTTON7",
				},
				altbutton2 = {
					key = "ALT-BUTTON2",
					value = "ACTIONBUTTON8",
				},
				toggle = {
					key = "Combat Mode Toggle",
					value = "BUTTON3",
				},
				hold = {
					key = "(Hold) Switch Mode",
					value = "BUTTON4",
				},
			},
		}
	}

	CombatModeOptions = { 
		name = "Combat Mode Settings",
		handler = CombatMode,
		type = "group",
		args = {
			freelookkeybindHeader = {
				type = "header",
				name = "|cff00FF7FFree Look Camera|r",
				order = 0,
			},
			freelookKeybindDescription= {
				type = "description",
				name = "Set keybinds for the Free Look camera. You can use Toggle and Press & Hold together by binding them to separate keys.",
				order = 1,
			},
			blank1 = {type = "description", name = " ", width = "full", order = 2, },
			toggle = {
				type = "keybinding",
				name = "|cff69ccf0Toggle|r",
				desc = "Toggles the Free Look camera ON or OFF.",
				width = 1.5,
				set = function(info, key)
					local oldKey = (GetBindingKey("Combat Mode Toggle"))
					if oldKey then SetBinding(oldKey) end
					SetBinding(key, "Combat Mode Toggle")
					SaveBindings(GetCurrentBindingSet())
				end,
	get = function(info) return (GetBindingKey("Combat Mode Toggle")) end,
				order = 3,
			},
			blank2 = {type = "description", name = " ", width = 0.2, order = 4, },
			hold  = {
				type = "keybinding",
				name = "|cff69ccf0Press & Hold|r",
				desc = "Hold to temporarily deactivate the Free Look camera.",
				width = 1.5,
				set = function(info, key)
								local oldKey = (GetBindingKey("(Hold) Switch Mode"))
								if oldKey then SetBinding(oldKey) end
								SetBinding(key, "(Hold) Switch Mode")
								SaveBindings(GetCurrentBindingSet())
							end,
				get = function(info) return (GetBindingKey("(Hold) Switch Mode")) end,
				order = 5,
			},
			blank3 = {type = "description", name = " ", width = "full", order = 6, },
			keybindHeader = {
				type = "header",
				name = "|cff00FF7FMouse Button Keybinds|r",
				order = 7,
			},
			keybindDescription= {
				type = "description",
				name = "Select which actions are fired when Left and Right clicking as well as their respective Shift, CTRL and ALT modified presses.",
				order = 8,
			},
			blank4 = {type = "description", name = " ", width = "full", order = 9, },
			unmodifiedDescription= {
				type = "description",
				name = "|cff69ccf0Unmodified Base Clicks|r",
				order = 10,
				fontSize = "medium",
			},
			button1 = {
				name = "Left Click",
				desc = "Left Click",
				type = "select",
				width = 1.5,
				order = 11,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.button1.value = value
				end,
				get = function()
					return self.db.profile.bindings.button1.value
				end
			},
			blank5 = {type = "description", name = " ", width = 0.2, order = 12, },
			button2 = {
				name = "Right Click",
				desc = "Right Click",
				type = "select",
				width = 1.5,
				order = 13,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.button2.value = value
				end,
				get = function()
					return self.db.profile.bindings.button2.value
				end
			},
			blank6 = {type = "description", name = " ", width = "full", order = 14, },
			shiftDescription= {
				type = "description",
				name = "|cff69ccf0Shift-modified Clicks|r",
				order = 15,
				fontSize = "medium",
			},
			shiftbutton1 = {
				name = "Shift + Left Click",
				desc = "Shift + Left Click",
				type = "select",
				width = 1.5,
				order = 16,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.shiftbutton1.value = value
				end,
				get = function()
					return self.db.profile.bindings.shiftbutton1.value
				end
			},	
			blank7 = {type = "description", name = " ", width = 0.2, order = 17, },
			shiftbutton2 = {
				name = "Shift + Right Click",
				desc = "Shift + Right Click",
				type = "select",
				width = 1.5,
				order = 18,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.shiftbutton2.value = value
				end,
				get = function()
					return self.db.profile.bindings.shiftbutton2.value
				end
			},
			blank8 = {type = "description", name = " ", width = "full", order = 19, },
			ctrlDescription= {
				type = "description",
				name = "|cff69ccf0CTRL-modified Clicks|r",
				order = 20,
				fontSize = "medium",
			},
			ctrlbutton1 = {
				name = "Control + Left Click",
				desc = "Control + Left Click",
				type = "select",
				width = 1.5,
				order = 21,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.ctrlbutton1.value = value
				end,
				get = function()
					return self.db.profile.bindings.ctrlbutton1.value
				end
			},
			blank9 = {type = "description", name = " ", width = 0.2, order = 22, },
			ctrlbutton2 = {
				name = "Control + Right Click",
				desc = "Control + Right Click",
				type = "select",
				width = 1.5,
				order = 23,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.ctrlbutton2.value = value
				end,
				get = function()
					return self.db.profile.bindings.ctrlbutton2.value
				end
			},
			blank10 = {type = "description", name = " ", width = "full", order = 24, },
			altDescription= {
				type = "description",
				name = "|cff69ccf0ALT-modified Clicks|r",
				order = 25,
				fontSize = "medium",
			},
			altbutton1 = {
				name = "Alt + Left Click",
				desc = "Alt + Left Click",
				type = "select",
				width = 1.5,
				order = 26,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.altbutton1.value = value
				end,
				get = function()
					return self.db.profile.bindings.altbutton1.value
				end
			},	
			blank11 = {type = "description", name = " ", width = 0.2, order = 27, },
			altbutton2 = {
				name = "Alt + Right Click",
				desc = "Alt + Right Click",
				type = "select",
				width = 1.5,
				order = 28,
				values = defaultButtonValues,
				set = function(info, value)
					self.db.profile.bindings.altbutton2.value = value
				end,
				get = function()
					return self.db.profile.bindings.altbutton2.value
				end
			},
			blank12 = {type = "description", name = " ", width = "full", order = 29, },
			watchlistHeader = {
				type = "header",
				name = "|cff00FF7FFrame Watchlist|r",
				order = 30,
			},
			watchlistDescription= {
				type = "description",
				name = "Add custom frames - 3rd party AddOns or otherwise - that you'd like Combat Mode to watch for, freeing the cursor automatically when they become visible.",
				order = 31,
			},
			watchlistWarning= {
				type = "description",
				name = "\n|cffff0000Names are case sensitive. Separate them with commas.|r",
				fontSize = "medium",
				order = 32,
			},
			watchlist = {
				name = "Frame Watchlist",
				desc = "Add custom frames - 3rd party AddOns or otherwise - that you'd like Combat Mode to watch for, freeing the cursor automatically when they become visible.\n|cff909090Use command /fstack in chat to check frame names.|r \n|cff909090Separate names with commas.|r \n|cffff0000Names are case sensitive.|r",
				type = "input",
				width = "full",
				order = 33,
				set = function(info, input)
					self.db.global.watchlist = {}
					for value in string.gmatch(input, "[^,]+") do -- Split at the ", "
						value = value:gsub("^%s*(.-)%s*$", "%1") -- Trim spaces
						table.insert(self.db.global.watchlist, value)
					end
				end,				
				get = function(info)
					local watchlist = self.db.global.watchlist or {}
					return table.concat(watchlist, ", ")
				end
			},
			watchlistNote= {
				type = "description",
				name = "\n|cff909090Use command /fstack in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: AddonName + Frame. Ex: WeakAuraFrame.|r",
				order = 34,
			},
			blank13 = {type = "description", name = " ", width = "full", order = 35, },
			frameWatchingHeader = {
				type = "header",
				name = "|cff00FF7FFrame Watching|r",
				order = 36,
			},
			frameWatchingDescription= {
				type = "description",
				name = "Select whether Combat Mode should automatically disable Free Look and release the cursor when specific frames are visible (Bag, Map, Quest, etc).",
				order = 37,
			},
			frameWatchingWarning= {
				type = "description",
				name = "\n|cffff0000Disabling this will also disable the Frame Watchlist.|r",
				fontSize = "medium",
				order = 38,
			},
			frameWatching = {
				type = "toggle",
				name = "Allow Frame Watching",
				desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).",
				order = 39,
				set = function(info, value)
					self.db.global.frameWatching = value
					if value then
						  FrameWatching = true
					else
							FrameWatching = false
					end
				end,
				get = function(info)
					return self.db.global.frameWatching
				end,
			},
			blank14 = {type = "description", name = " ", width = "full", order = 35, },
			reticleTargetingHeader = {
				type = "header",
				name = "|cff00FF7FReticle Targeting|r",
				order = 40,
			},
			reticleTargetingDescription= {
				type = "description",
				name = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable with predictable behavior.",
				order = 41,
			},
			reticleTargetingWarning= {
				type = "description",
				name = "\n|cffff0000This will override all Cvar values related to SoftTarget. Uncheck to reset them to the default values.|r",
				fontSize = "medium",
				order = 42,
			},
			reticleTargeting = {
				type = "toggle",
				name = "Activate Reticle Targeting",
				desc = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable w/ predictable behavior.\n|cffff0000This will override all Cvar values related to SoftTarget.|r \n|cff909090Please note that manually changing Cvars with AddOns like Advanced Interface Options will override Combat Mode values. This is intended so you can tweak things if you want. Although it's highly advised that you don't as the values set by Combat Mode were meticuously tested to provide the most accurate representation of Reticle Targeting possible with the available Cvars.|r",
				order = 43,
				set = function(info, value)
					self.db.global.reticleTargeting = value
					if value then
							CombatMode:loadReticleTargetCvars()
					else
							CombatMode:loadDefaultCvars()
					end
				end,
				get = function(info)
					return self.db.global.reticleTargeting
				end,
			},
			reticleTargetingNote= {
				type = "description",
				name = "\n|cff909090Please note that manually changing Cvars w/ AddOns like Advanced Interface Options will override Combat Mode values. This is intended so you can tweak things if you want. Although it's highly advised that you don't as the values set by Combat Mode were meticuously tested to provide the most accurate representation of Reticle Targeting possible with the available Cvars.|r",
				order = 44,
			},
		}
	}

		
	self.db = LibStub("AceDB-3.0"):New("CombatModeDB")
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Combat Mode", CombatModeOptions)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Combat Mode", "Combat Mode")
    self:RegisterChatCommand("cm", "ChatCommand")
    self:RegisterChatCommand("combatmode", "ChatCommand")
	self.db = LibStub("AceDB-3.0"):New("CombatModeDB", databaseDefaults, true)

end

function CombatMode:ChatCommand(input)
    if not input or input:trim() == "" then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("cm", "CombatMode", input)
    end
end

function CombatMode:OnEnable()
	-- Register Events
	self:RegisterEvent("PLAYER_ENTERING_WORLD", CombatMode_OnEvent)
	self:RegisterEvent("ADDON_LOADED", CombatMode_OnEvent)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", CombatMode_OnEvent)
	-- self:RegisterEvent("CURSOR_UPDATE", CombatMode_OnEvent)
	self:RegisterEvent("PET_BAR_UPDATE", CombatMode_OnEvent)
	self:RegisterEvent("ACTIONBAR_UPDATE_STATE", CombatMode_OnEvent)
	self:RegisterEvent("QUEST_FINISHED", CombatMode_OnEvent)
	self:RegisterEvent("QUEST_PROGRESS", CombatMode_OnEvent)
end

function CombatMode:OnDisable()
    -- Called when the addon is disabled
end

function CombatMode:BindBindingOverride(button, value)
	MouselookStop()
	SetMouselookOverrideBinding(button, value)
	MouselookStart()
end

function CombatMode:BindBindingOverrides()
	MouselookStop()
	SetMouselookOverrideBinding("BUTTON1", self.db.profile.bindings.button1.value)
	SetMouselookOverrideBinding("BUTTON2", self.db.profile.bindings.button2.value)
	SetMouselookOverrideBinding("CTRL-BUTTON1", self.db.profile.bindings.ctrlbutton1.value)
	SetMouselookOverrideBinding("CTRL-BUTTON2", self.db.profile.bindings.ctrlbutton2.value)
	SetMouselookOverrideBinding("ALT-BUTTON1", self.db.profile.bindings.altbutton1.value)
	SetMouselookOverrideBinding("ALT-BUTTON2", self.db.profile.bindings.altbutton2.value)
	SetMouselookOverrideBinding("SHIFT-BUTTON1", self.db.profile.bindings.shiftbutton1.value)
	SetMouselookOverrideBinding("SHIFT-BUTTON2", self.db.profile.bindings.shiftbutton2.value)
	MouselookStart()
end

function CombatMode:UnmouseableFrameOnScreen(frameArr)
	local allowFrameWatching = self.db.global.frameWatching == true
	if not allowFrameWatching then
		return false
	end
	for index in pairs(frameArr) do
		local curFrame = getglobal(frameArr[index])
		if (curFrame and curFrame:IsVisible()) then
			return true
		end
	end
end

function CombatMode:checkForDisableState()
	return (CombatMode:UnmouseableFrameOnScreen(FramesToCheck) or CombatMode:UnmouseableFrameOnScreen(self.db.global.watchlist) or SpellIsTargeting() or CursorActionActive)
end


function CombatMode:CMPrint(statement)
	if not CombatModeQuiet then
		print(statement)
	end
end

-- Start Mouselook
function CombatMode:startMouselook()	
	if combatModeTemporaryDisable and not CombatMode:checkForDisableState() then
		ResetCursor()
		combatModeTemporaryDisable = false
		MouselookStart()
	else
		ResetCursor()
		combatModeTemporaryDisable = true
		MouselookStop()
	end
end

-- Stop Mouselook
function CombatMode:stopMouselook()
	if not combatModeTemporaryDisable then
		combatModeTemporaryDisable = true
		CursorActionActive = false
		MouselookStop()
	end
end

function CombatMode:updateState()
	if CombatMode:checkForDisableState() then
		-- disable mouselook
		CombatMode:stopMouselook()
		mouseLookStarted = false
	else
		-- enable mouselook
		if mouseLookStarted ~= true then
			CombatMode:startMouselook()
			mouseLookStarted = true
		end
	end
	
end

function CombatMode:Toggle()
	if combatModeAddonSwitch == false then
		combatModeAddonSwitch = true
		CombatMode:BindBindingOverrides()
		CombatMode:startMouselook()
	else
		combatModeAddonSwitch = false
		CombatMode:stopMouselook()		
	end
end

function CombatModeToggleKey()
	CombatMode:Toggle()
	if combatModeAddonSwitch then
		CombatMode:CMPrint ("Combat Mode Enabled")
		if SmartTargetingEnabled then
			CombatMode:SmartTarget()
		end
	else
		CombatMode:CMPrint ("Combat Mode Disabled")
	end
end

function CombatModeHold(keystate)
	if keystate == "down" then
		combatModeAddonSwitch = false
		CombatMode:stopMouselook()
	else
		combatModeAddonSwitch = true
		CombatMode:startMouselook()
	end
end

function CombatMode:Rematch()
	local isReticleTargetingActive = self.db.global.reticleTargeting == true
	if isReticleTargetingActive then
		CombatMode:loadReticleTargetCvars()
	end
  if not IsMouselooking() then
		combatModeAddonSwitch = true
		CombatMode:startMouselook()
  elseif IsMouselooking() then
		combatModeAddonSwitch = false
		CombatMode:stopMouselook()
  end
end

function CombatMode_OnEvent(event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		CombatMode:startMouselook()
		CombatMode:Rematch()
	end

	if combatModeAddonSwitch then
		if event == "PLAYER_TARGET_CHANGED" and not CombatMode:checkForDisableState() then			
			-- target changed		
		end

		--if event == "CURSOR_UPDATE" and not CombatMode:checkForDisableState() then
		--	CursorActionActive = true
		--end

		if event == "PET_BAR_UPDATE" and CursorActionActive then
			CursorActionActive = false
			ResetCursor()
		end

		if event == "PET_BAR_UPDATE" and CursorActionActive then
			CursorActionActive = false
			ResetCursor()
		end

		if event == "ACTIONBAR_UPDATE_STATE" and CursorActionActive then
			CursorActionActive = false
			ResetCursor()
		end
		
		if event == "QUEST_FINISHED" and CursorActionActive then
			CombatMode:startMouselook()
			CursorActionActive = false
		end

		if event == "QUEST_PROGRESS" then
			CombatMode:stopMouselook()
			CursorActionActive = true
		end
	end
end

function CombatMode_OnUpdate(self, elapsed)
	if combatModeAddonSwitch then
		CombatMode:updateState()
	end
end

function CombatMode_OnLoad(self, elapsed)
end

