-- Author: justice7ca w/ contributions from DKulan and sampconrad
CombatMode = LibStub("AceAddon-3.0"):NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")

-- Local variables
local combatModeAddonSwitch = false
local combatModeTemporaryDisable = false
local CursorActionActive = false
local debugMode = false
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
	 "BagnonInventory1",
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
	 "SplashFrame",
	 "CalendarFrame",
	 "ExpansionLandingPage",
	 "GenericTraitFrame",
	 "PlayerChoiceFrame",
	 "ItemInteractionFrame",
	 "ScriptErrorsFrame"
}
local wildcardFramesToMatch = {
	"OPieRT"
}
local wildcardFramesToCheck = {}

local defaultButtonValues = {
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

local macroFieldDescription = "Enter the name of the macro you wish to be ran here."

-- CVARS FOR RETICLE TARGETING
-- !! DO NOT CHANGE !!
function CombatMode:loadReticleTargetCvars()
	-- general
	SetCVar("SoftTargetForce", 1) -- Auto-set target to match soft target. 1 = for enemies, 2 = for friends
	SetCVar("SoftTargetMatchLocked", 1) -- Match appropriate soft target to locked target. 1 = hard locked only, 2 = targets you attack
	SetCVar("SoftTargetWithLocked", 2) -- Allows soft target selection while player has a locked target. 2 = always do soft targeting
	SetCVar("SoftTargetNameplateEnemy", 1)
	SetCVar("SoftTargetNameplateInteract", 0)
  -- interact
  SetCVar("SoftTargetInteract", 3) -- 3 = always on
  SetCVar("SoftTargetInteractArc", 1)
  SetCVar("SoftTargetInteractRange", 15)
	SetCVar("SoftTargetIconInteract", 1)
	SetCVar("SoftTargetIconGameObject", 1)
  -- friendly target
  SetCVar("SoftTargetFriend", 3)
  SetCVar("SoftTargetFriendArc", 1)
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
function CombatMode:loadDefaultCvars()
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

-- Default button values
function CombatMode:OnInitialize()
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
				button1macro = "",

				button2 = {
					key = "BUTTON2",
					value = "ACTIONBUTTON2",
				},
				button2macro = "",

				shiftbutton1 = {
					key = "SHIFT-BUTTON1",
					value = "ACTIONBUTTON3",
				},
				shiftbutton1macro = "",

				shiftbutton2 = {
					key = "SHIFT-BUTTON2",
					value = "ACTIONBUTTON4",
				},
				shiftbutton2macro = "",

				ctrlbutton1 = {
					key = "CTRL-BUTTON1",
					value = "ACTIONBUTTON5",
				},
				ctrlbutton1macro = "",

				ctrlbutton2 = {
					key = "CTRL-BUTTON2",
					value = "ACTIONBUTTON6",
				},
				ctrlbutton2macro = "",

				altbutton1 = {
					key = "ALT-BUTTON1",
					value = "ACTIONBUTTON7",
				},
				altbutton1macro = "",

				altbutton2 = {
					key = "ALT-BUTTON2",
					value = "ACTIONBUTTON8",
				},
				altbutton2macro = "",

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
		name = "|cffff0000Combat Mode|r",
		handler = CombatMode,
		type = "group",
		args = {
			-- ABOUT
			aboutHeader = {
				type = "header",
				name = "|cffffffffABOUT|r",
				order = 0,
			},
			aboutHeaderPaddingBottom = {type = "description", name = " ", width = "full", order = 0.1, },
			aboutDescription = {
				type = "description",
				name = "Combat Mode adds Action Combat to World of Warcraft for a more dynamic combat experience.",
				order = 1,
				fontSize = "medium",
			},
			aboutDescriptionPaddingBottom = {type = "description", name = " ", width = "full", order = 1.1, },
			featuresHeader = {
				type = "description",
				name = "|cffffd700Features:|r",
				order = 2,
				fontSize = "medium",
			},
			featuresList = {
				type = "description",
				name = "|cff909090• Free Look - Move your camera without having to perpetually hold right mouse button.|r \n|cff909090• Reticle Targeting - Makes use of the SoftTarget Cvars added with Dragonflight to allow the user to target units by aiming at them.|r \n|cff909090• Ability casting w/ mouse click - When Combat Mode is enabled, frees your left and right mouse click so you can cast abilities with them.|r \n|cff909090• Automatically toggles Free Look when opening interface panels like bags, map, character panel, etc.|r \n|cff909090• Ability to add any custom frame - 3rd party AddOns or otherwise - to a watchlist to expand on the default selection.|r",
				order = 3,
				fontSize = "small",
			},
			featuresListPaddingBottom = {type = "description", name = " ", width = "full", order = 3.1, },
			curse = {
				name = "Download From:",
				desc = "curseforge.com/wow/addons/combat-mode",
				type = "input",
				width = 2,
				order = 4,
				get = function()
					return "curseforge.com/wow/addons/combat-mode"
				end,
			},
			gitDiscordSpacing = { type = "description", name = " ", width = 0.25, order = 4.1, },
			discord = {
				name = "Feedback & Support:",
				desc = "discord.gg/5mwBSmz",
				type = "input",
				width = 1.1,
				order = 5,
				get = function()
					return "discord.gg/5mwBSmz"
				end,
			},
			-- CONFIGURATION
			configurationHeaderPaddingTop = {type = "description", name = " ", width = "full", order = 5.1, },
			configurationHeader = {
				type = "header",
				name = "|cffffffffCONFIGURATION|r",
				order = 6,
			},
			-- FREELOOK CAMERA
			freeLookCameraGroup = {
				type = "group",
				name = " ",
				inline = true,
				order = 7,
				args = {
					freelookKeybindHeader = {
						type = "header",
						name = "|cffE52B50Free Look Camera|r",
						order = 1,
					},
					freelookKeybindHeaderPaddingBottom = {type = "description", name = " ", width = "full", order = 1.1, },
					freelookKeybindDescription= {
						type = "description",
						name = "Set keybinds for the Free Look camera. You can use Toggle and Press & Hold together by binding them to separate keys.",
						order = 2,
					},
					freelookKeybindDescriptionBottomPadding = {type = "description", name = " ", width = "full", order = 2.1, },
					toggleLeftPadding = {type = "description", name = " ", width = 0.5, order = 2.2, },
					toggle = {
						type = "keybinding",
						name = "|cffffd700Toggle|r",
						desc = "Toggles the Free Look camera ON or OFF.",
						width = 1,
						order = 3,
						set = function(info, key)
							local oldKey = (GetBindingKey("Combat Mode Toggle"))
							if oldKey then SetBinding(oldKey) end
							SetBinding(key, "Combat Mode Toggle")
							SaveBindings(GetCurrentBindingSet())
						end,
						get = function(info) return (GetBindingKey("Combat Mode Toggle")) end,
					},
					holdLeftPadding = {type = "description", name = " ", width = 0.5, order = 3.1, },
					hold  = {
						type = "keybinding",
						name = "|cffffd700Press & Hold|r",
						desc = "Hold to temporarily deactivate the Free Look camera.",
						width = 1,
						order = 4,
						set = function(info, key)
										local oldKey = (GetBindingKey("(Hold) Switch Mode"))
										if oldKey then SetBinding(oldKey) end
										SetBinding(key, "(Hold) Switch Mode")
										SaveBindings(GetCurrentBindingSet())
									end,
						get = function(info) return (GetBindingKey("(Hold) Switch Mode")) end,
					},
					holdBottomPadding = {type = "description", name = " ", width = "full", order = 4.1, },
				},
			},
			-- MOUSE BUTTON
			mouseButtonGroup = {
				type = "group",
				name = " ",
				inline = true,
				order = 8,
				args = {
					keybindHeader = {
						type = "header",
						name = "|cffB47EDEMouse Button Keybinds|r",
						order = 1,
					},
					keybindHeaderPaddingBottom = {type = "description", name = " ", width = "full", order = 1.1, },
					keybindDescription= {
						type = "description",
						name = "Select which actions are fired when Left and Right clicking as well as their respective Shift, CTRL and ALT modified presses.",
						order = 2,
					},
					keybindNote= {
						type = "description",
						name = "\n|cff909090To use a macro when clicking, select |cff69ccf0MACRO|r as the action and then type the exact name of the macro you'd like to cast.|r",
						order = 3,
					},
					keybindDescriptionBottomPadding = {type = "description", name = " ", width = "full", order = 3.1, },
					-- BASE CLICK GROUP
					unmodifiedGroup = {
						type = "group",
						name = "|cff97a2ffBase Clicks|r",
						inline = true,
						order = 4,
						args = {
							button1 = {
								name = "Left Click",
								desc = "Left Click",
								type = "select",
								width = 1.5,
								order = 1,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.button1.value = value
								end,
								get = function()
									return self.db.profile.bindings.button1.value
								end
							},
							button1SidePadding = { type = "description", name = " ", width = 0.2, order = 1.1, },
							button1macro = {
								name = "Left Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 2,
								set = function(info, value)
									self.db.profile.bindings.button1macro = value
								end,
								get = function()
									return self.db.profile.bindings.button1macro
								end,
								disabled = function()
									return self.db.profile.bindings.button1.value ~= defaultButtonValues.MACRO
								end
							},
							button2 = {
								name = "Right Click",
								desc = "Right Click",
								type = "select",
								width = 1.5,
								order = 3,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.button2.value = value
								end,
								get = function()
									return self.db.profile.bindings.button2.value
								end
							},
							button2SidePadding = { type = "description", name = " ", width = 0.2, order = 3.1, },
							button2macro = {
								name = "Right Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 4,
								set = function(info, value)
									self.db.profile.bindings.button2macro = value
								end,
								get = function()
									return self.db.profile.bindings.button2macro
								end,
								disabled = function()
									return self.db.profile.bindings.button2.value ~= defaultButtonValues.MACRO
								end
							},
						},
					},
					unmodifiedGroupBottomPadding = { type = "description", name = " ", width = "full", order = 4.1, },
					-- SHIFT CLICK GROUP
					shiftGroup = {
						type = "group",
						name = "|cff97a2ffShift-modified Clicks|r",
						inline = true,
						order = 5,
						args = {
							shiftbutton1 = {
								name = "Shift + Left Click",
								desc = "Shift + Left Click",
								type = "select",
								width = 1.5,
								order = 1,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.shiftbutton1.value = value
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton1.value
								end
							},
							shiftbutton1SidePadding = { type = "description", name = " ", width = 0.2, order = 1.1, },
							shiftbutton1macro = {
								name = "Shift + Left Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 2,
								set = function(info, value)
									self.db.profile.bindings.shiftbutton1macro = value
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton1macro
								end,
								disabled = function()
									return self.db.profile.bindings.shiftbutton1.value ~= defaultButtonValues.MACRO
								end
							},
							shiftbutton2 = {
								name = "Shift + Right Click",
								desc = "Shift + Right Click",
								type = "select",
								width = 1.5,
								order = 3,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.shiftbutton2.value = value
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton2.value
								end
							},
							shiftbutton2SidePadding = { type = "description", name = " ", width = 0.2, order = 3.1, },
							shiftbutton2macro = {
								name = "Shift + Right Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 4,
								set = function(info, value)
									self.db.profile.bindings.shiftbutton2macro = value
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton2macro
								end,
								disabled = function()
									return self.db.profile.bindings.shiftbutton2.value ~= defaultButtonValues.MACRO
								end
							},
						},
					},
					shiftGroupBottomPadding = { type = "description", name = " ", width = "full", order = 5.1, },
					-- CTRL CLICK GROUP
					ctrlGroup = {
						type = "group",
						name = "|cff97a2ffCTRL-modified Clicks|r",
						inline = true,
						order = 6,
						args = {
							ctrlbutton1 = {
								name = "Control + Left Click",
								desc = "Control + Left Click",
								type = "select",
								width = 1.5,
								order = 1,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.ctrlbutton1.value = value
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton1.value
								end
							},
							ctrlbutton1SidePadding = { type = "description", name = " ", width = 0.2, order = 1.1, },
							ctrlbutton1macro = {
								name = "Control + Left Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 2,
								set = function(info, value)
									self.db.profile.bindings.ctrlbutton1macro = value
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton1macro
								end,
								disabled = function()
									return self.db.profile.bindings.ctrlbutton1.value ~= defaultButtonValues.MACRO
								end
							},
							ctrlbutton2 = {
								name = "Control + Right Click",
								desc = "Control + Right Click",
								type = "select",
								width = 1.5,
								order = 3,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.ctrlbutton2.value = value
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton2.value
								end
							},
							ctrlbutton2SidePadding = { type = "description", name = " ", width = 0.2, order = 3.1, },
							ctrlbutton2macro = {
								name = "Control + Right Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 4,
								set = function(info, value)
									self.db.profile.bindings.ctrlbutton2macro = value
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton2macro
								end,
								disabled = function()
									return self.db.profile.bindings.ctrlbutton2.value ~= defaultButtonValues.MACRO
								end
							},
						},
					},
					ctrlGroupBottomPadding = { type = "description", name = " ", width = "full", order = 6.1, },
					-- ALT CLICK GROUP
					altGroup = {
						type = "group",
						name = "|cff97a2ffALT-modified Clicks|r",
						inline = true,
						order = 7,
						args = {
							altbutton1 = {
								name = "Alt + Left Click",
								desc = "Alt + Left Click",
								type = "select",
								width = 1.5,
								order = 1,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.altbutton1.value = value
								end,
								get = function()
									return self.db.profile.bindings.altbutton1.value
								end
							},
							altbutton1SidePadding = { type = "description", name = " ", width = 0.2, order = 1.1, },
							altbutton1macro = {
								name = "Alt + Left Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 2,
								set = function(info, value)
									self.db.profile.bindings.altbutton1macro = value
								end,
								get = function()
									return self.db.profile.bindings.altbutton1macro
								end,
								disabled = function()
									return self.db.profile.bindings.altbutton1.value ~= defaultButtonValues.MACRO
								end
							},
							altbutton2 = {
								name = "Alt + Right Click",
								desc = "Alt + Right Click",
								type = "select",
								width = 1.5,
								order = 3,
								values = defaultButtonValues,
								set = function(info, value)
									self.db.profile.bindings.altbutton2.value = value
								end,
								get = function()
									return self.db.profile.bindings.altbutton2.value
								end
							},
							altbutton2SidePadding = { type = "description", name = " ", width = 0.2, order = 3.1, },
							altbutton2macro = {
								name = "Alt + Right Click Macro",
								desc = macroFieldDescription,
								type = "input",
								width = 1.5,
								order = 4,
								set = function(info, value)
									self.db.profile.bindings.altbutton2macro = value
								end,
								get = function()
									return self.db.profile.bindings.altbutton2macro
								end,
								disabled = function()
									return self.db.profile.bindings.altbutton2.value ~= defaultButtonValues.MACRO
								end
							},
						},
					},					
				},
			},
			-- WATCHLIST
			watchlistGroup = {
				type = "group",
				name = " ",
				order = 9,
				inline = true,
				args = {
					frameWatchingHeader = {
						type = "header",
						name = "|cff00FF7FCursor Unlock|r",
						order = 1,
					},
					frameWatchingHeaderPaddingBottom = {type = "description", name = " ", width = "full", order = 1.1, },
					frameWatchingDescription= {
						type = "description",
						name = "Select whether Combat Mode should automatically disable Free Look and release the cursor when specific frames are visible (Bag, Map, Quest, etc).",
						order = 2,
					},
					frameWatchingWarning= {
						type = "description",
						name = "\n|cffff0000Disabling this will also disable the Frame Watchlist.|r",
						fontSize = "medium",
						order = 3,
					},
					frameWatching = {
						type = "toggle",
						name = "Enable Cursor Unlock",
						desc = "Automatically disables Free Look and releases the cursor when specific frames are visible (Bag, Map, Quest, etc).",
						order = 4,
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
					frameWatchingHeaderPaddingTop = {type = "description", name = " ", width = "full", order = 4.1, },
					-- WATCHLIST INPUT
					watchlistInputGroup = {
						type = "group",
						name = "|cff69ccf0Frame Watchlist|r",
						order = 5,	
						args = {
							watchlistDescription= {
								type = "description",
								name = "Additional frames - 3rd party AddOns or otherwise - that you'd like Combat Mode to watch for, freeing the cursor automatically when they become visible.",
								order = 1,
							},
							watchlist = {
								name = "Frame Watchlist",
								desc = "Use command |cff69ccf0/fstack|r in chat to check frame names. \n|cffffd700Separate names with commas.|r \n|cffffd700Names are case sensitive.|r",
								type = "input",
								width = "full",
								order = 2,
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
								name = "\n|cff909090Use command |cff69ccf0/fstack|r in chat to check frame names. Mouse over the frame you want to add and look for the identification that usually follows this naming convention: AddonName + Frame. Ex: WeakAurasFrame.|r",
								order = 3,
							},
						},
					},
				},
			},
			-- RETICLE TARGETING
			reticleTargetingGroup = {
				type = "group",
				name = " ",
				order = 10,
				inline = true,
				args = {
					reticleTargetingHeader = {
						type = "header",
						name = "|cff00FFFFReticle Targeting|r",
						order = 1,
					},
					reticleTargetingHeaderPaddingBottom = {type = "description", name = " ", width = "full", order = 1.1, },
					reticleTargetingDescription= {
						type = "description",
						name = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable with predictable behavior.",
						order = 2,
					},
					reticleTargetingWarning= {
						type = "description",
						name = "\n|cffff0000This will override all Cvar values related to SoftTarget. Uncheck to reset them to the default values.|r",
						fontSize = "medium",
						order = 3,
					},
					reticleTargeting = {
						type = "toggle",
						name = "Enable Reticle Targeting",
						desc = "Configures Blizzard's Action Targeting feature from the frustrating default settings to something actually usable w/ predictable behavior.",
						order = 4,
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
						order = 5,
					},
					reticleTargetingNotePaddingBottom = {type = "description", name = " ", width = "full", order = 5.1, },
				},
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
 
-- Initialise the table by going through ALL available globals once and keeping the ones that match
function CombatMode:InitializeWildcardFrameTracking(frameArr)
	CombatMode:print("Looking for wildcard frames...")

	for _, frameNameToFind in pairs(frameArr) do
		wildcardFramesToCheck[frameNameToFind] = {}

		for frameName in pairs(_G) do
			if string.match(frameName, frameNameToFind) then
				CombatMode:print("Matched " .. frameNameToFind .. " to frame " .. frameName)
				local frameGroup = wildcardFramesToCheck[frameNameToFind]
				frameGroup[#frameGroup+1] = frameName
			end
		end
	end

	CombatMode:print("Wildcard frames initialized")
end

function CombatMode:OnEnable()
	CombatMode:InitializeWildcardFrameTracking(wildcardFramesToMatch)

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

function CombatMode:BindBindingOverride(button, value, macroValue)
	MouselookStop()

	local valueToUse
	if value == defaultButtonValues.MACRO then
		valueToUse = "MACRO " .. macroValue
	else
		valueToUse = value
	end
	SetMouselookOverrideBinding(button, valueToUse)

	MouselookStart()
end

function CombatMode:BindBindingOverrides()
	MouselookStop()
	CombatMode:BindBindingOverride("BUTTON1", self.db.profile.bindings.button1.value,
		self.db.profile.bindings.button1macro)
	CombatMode:BindBindingOverride("BUTTON2", self.db.profile.bindings.button2.value,
		self.db.profile.bindings.button2macro)
	CombatMode:BindBindingOverride("CTRL-BUTTON1", self.db.profile.bindings.ctrlbutton1.value,
		self.db.profile.bindings.ctrlbutton1macro)
	CombatMode:BindBindingOverride("CTRL-BUTTON2", self.db.profile.bindings.ctrlbutton2.value,
		self.db.profile.bindings.ctrlbutton2macro)
	CombatMode:BindBindingOverride("ALT-BUTTON1", self.db.profile.bindings.altbutton1.value,
		self.db.profile.bindings.altbutton1macro)
	CombatMode:BindBindingOverride("ALT-BUTTON2", self.db.profile.bindings.altbutton2.value,
		self.db.profile.bindings.altbutton2macro)
	CombatMode:BindBindingOverride("SHIFT-BUTTON1", self.db.profile.bindings.shiftbutton1.value,
		self.db.profile.bindings.shiftbutton1macro)
	CombatMode:BindBindingOverride("SHIFT-BUTTON2", self.db.profile.bindings.shiftbutton2.value,
		self.db.profile.bindings.shiftbutton2macro)
	MouselookStart()
end

function CombatMode:UnmouseableFrameOnScreen(frameArr)
	local allowFrameWatching = self.db.global.frameWatching == true
	if not allowFrameWatching then
		return false
	end

	for _, frameName in pairs(frameArr) do
		local curFrame = getglobal(frameName)
		if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
			CombatMode:print(frameName .. " is visible, enabling cursor")
			return true
		end
	end
end

function CombatMode:UnmouseableFrameGroupOnScreen(frameNameGroups)
	for _, frameNames in pairs(frameNameGroups) do
		if CombatMode:UnmouseableFrameOnScreen(frameNames) == true then
			return true
		end
	end
end

function CombatMode:checkForDisableState()
	return (CombatMode:UnmouseableFrameOnScreen(FramesToCheck)
	or CombatMode:UnmouseableFrameOnScreen(self.db.global.watchlist)
	or CombatMode:UnmouseableFrameGroupOnScreen(wildcardFramesToCheck)
	or SpellIsTargeting()
	or CursorActionActive)
end


function CombatMode:print(statement)
	if debugMode then
		print("CombatMode: " .. statement)
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
		CombatMode:print("Combat Mode Enabled")
		if SmartTargetingEnabled then
			CombatMode:SmartTarget()
		end
	else
		CombatMode:print("Combat Mode Disabled")
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

