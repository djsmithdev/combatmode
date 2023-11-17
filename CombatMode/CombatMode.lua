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
			reticleTargeting = true,
			crosshair = true,
			crosshairSize = 64,
			crosshairOpacity = 1.0,
			crosshairY = 100,
		},
		profile = {
			bindings = {
				button1 = {
					key = "BUTTON1",
					value = "ACTIONBUTTON1",
					macro = ""
				},
				button2 = {
					key = "BUTTON2",
					value = "ACTIONBUTTON2",
					macro = ""
				},
				shiftbutton1 = {
					key = "SHIFT-BUTTON1",
					value = "ACTIONBUTTON3",
					macro = ""
				},
				shiftbutton2 = {
					key = "SHIFT-BUTTON2",
					value = "ACTIONBUTTON4",
					macro = ""
				},
				ctrlbutton1 = {
					key = "CTRL-BUTTON1",
					value = "ACTIONBUTTON5",
					macro = ""
				},
				ctrlbutton2 = {
					key = "CTRL-BUTTON2",
					value = "ACTIONBUTTON6",
					macro = ""
				},
				altbutton1 = {
					key = "ALT-BUTTON1",
					value = "ACTIONBUTTON7",
					macro = ""
				},
				altbutton2 = {
					key = "ALT-BUTTON2",
					value = "ACTIONBUTTON8",
					macro = ""
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
				name = "|cff909090• Free Look - Move your camera without having to perpetually hold right mouse button. \n• Reticle Targeting - Makes use of the SoftTarget Cvars added with Dragonflight to allow the user to target units by aiming at them. \n• Ability casting w/ mouse click - When Combat Mode is enabled, frees your left and right mouse click so you can cast abilities with them. \n• Automatically toggles Free Look when opening interface panels like bags, map, character panel, etc. \n• Ability to add any custom frame - 3rd party AddOns or otherwise - to a watchlist to expand on the default selection. \n• Optional adjustable Crosshair texture to assist with Reticle Targeting.|r",
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
									CombatMode:BindBindingOverride("BUTTON1", self.db.profile.bindings.button1)
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
									self.db.profile.bindings.button1.macro = value
									CombatMode:BindBindingOverride("BUTTON1", self.db.profile.bindings.button1)
								end,
								get = function()
									return self.db.profile.bindings.button1.macro
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
									CombatMode:BindBindingOverride("BUTTON2", self.db.profile.bindings.button2)
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
									self.db.profile.bindings.button2.macro = value
									CombatMode:BindBindingOverride("BUTTON2", self.db.profile.bindings.button2)
								end,
								get = function()
									return self.db.profile.bindings.button2.macro
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
									CombatMode:BindBindingOverride("SHIFT-BUTTON1", self.db.profile.bindings.shiftbutton1)
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
									self.db.profile.bindings.shiftbutton1.macro = value
									CombatMode:BindBindingOverride("SHIFT-BUTTON1", self.db.profile.bindings.shiftbutton1)
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton1.macro
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
									CombatMode:BindBindingOverride("SHIFT-BUTTON2", self.db.profile.bindings.shiftbutton2)
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
									self.db.profile.bindings.shiftbutton2.macro = value
									CombatMode:BindBindingOverride("SHIFT-BUTTON2", self.db.profile.bindings.shiftbutton2)
								end,
								get = function()
									return self.db.profile.bindings.shiftbutton2.macro
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
									CombatMode:BindBindingOverride("CTRL-BUTTON1", self.db.profile.bindings.ctrlbutton1)
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
									self.db.profile.bindings.ctrlbutton1.macro = value
									CombatMode:BindBindingOverride("CTRL-BUTTON1", self.db.profile.bindings.ctrlbutton1)
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton1.macro
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
									CombatMode:BindBindingOverride("CTRL-BUTTON2", self.db.profile.bindings.ctrlbutton2)
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
									self.db.profile.bindings.ctrlbutton2.macro = value
									CombatMode:BindBindingOverride("CTRL-BUTTON2", self.db.profile.bindings.ctrlbutton2)
								end,
								get = function()
									return self.db.profile.bindings.ctrlbutton2.macro
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
									CombatMode:BindBindingOverride("ALT-BUTTON1", self.db.profile.bindings.altbutton1)
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
									self.db.profile.bindings.altbutton1.macro = value
									CombatMode:BindBindingOverride("ALT-BUTTON1", self.db.profile.bindings.altbutton1)
								end,
								get = function()
									return self.db.profile.bindings.altbutton1.macro
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
									CombatMode:BindBindingOverride("ALT-BUTTON2", self.db.profile.bindings.altbutton2)
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
									self.db.profile.bindings.altbutton2.macro = value
									CombatMode:BindBindingOverride("ALT-BUTTON2", self.db.profile.bindings.altbutton2)
								end,
								get = function()
									return self.db.profile.bindings.altbutton2.macro
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
					-- CROSSHAIR
					crosshairGroup = {
						type = "group",
						name = "|cff69ccf0Crosshair|r",
						order = 6,	
						args = {
							crosshairDescription= {
								type = "description",
								name = "Places a crosshair texture in the center of the screen to assist with Reticle Targeting.",
								order = 1,
							},
							crosshair = {
								type = "toggle",
								name = "Enable Crosshair",
								desc = "Places a crosshair texture in the center of the screen to assist with Reticle Targeting.",
								width = "full",
								order = 2,
								set = function(info, value)
									self.db.global.crosshair = value
									if value then
											CombatMode:ShowCrosshair()
									else
											CombatMode:HideCrosshair()
									end
								end,
								get = function(info)
									return self.db.global.crosshair
								end,
							},
							crosshairNote= {
								type = "description",
								name = "\n|cff909090The crosshair has been programed with CombatMode's |cff00FFFFReticle Targeting|r in mind. Utilizing the Crosshair without it could lead to unintended behavior.|r",
								order = 3,
							},
							crosshairPaddingBottom = {type = "description", name = " ", width = "full", order = 3.1, },
							crosshairSize = {
								type = "range",
								name = "Crosshair Size",
								desc = "Adjusts the size of the crosshair in 16-pixel increments.",
								min = 16,
								max = 128,
								softMin = 16,
								softMax = 128,
								step = 16,
								width = 1.6,
								order = 4,
								disabled = function()
									return self.db.global.crosshair ~= true
								end,
								set = function(info, value)
									self.db.global.crosshairSize = value
									if value then
										CombatMode:UpdateCrosshair()
									end
								end,
								get = function(info)
									return self.db.global.crosshairSize
								end,
							},
							crosshairSlidersSpacing = { type = "description", name = " ", width = 0.2, order = 4.1, },
							crosshairAlpha = {
								type = "range",
								name = "Crosshair Opacity",
								desc = "Adjusts the opacity of the crosshair.",
								min = 0.1,
								max = 1.0,
								softMin = 0.1,
								softMax = 1.0,
								step = 0.1,
								width = 1.6,
								order = 5,
								isPercent = true,
								disabled = function()
									return self.db.global.crosshair ~= true
								end,
								set = function(info, value)
									self.db.global.crosshairOpacity = value
									if value then
										CombatMode:UpdateCrosshair()
									end
								end,
								get = function(info)
									return self.db.global.crosshairOpacity
								end,
							},
							crosshairAlphaPaddingBottom = {type = "description", name = " ", width = "full", order = 5.1, },
							crosshairY = {
								type = "range",
								name = "Crosshair Vertical Position",
								desc = "Adjusts the vertical position of the crosshair.",
								min = -500,
								max = 500,
								softMin = -500,
								softMax = 500,
								step = 10,
								width = "full",
								order = 6,
								disabled = function()
									return self.db.global.crosshair ~= true
								end,
								set = function(info, value)
									self.db.global.crosshairY = value
									if value then
										CombatMode:UpdateCrosshair()
									end
								end,
								get = function(info)
									return self.db.global.crosshairY
								end,
							},
						},
					},
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

-- CROSSHAIR
local CrosshairFrame = CreateFrame("Frame", "CombatModeCrosshairFrame", UIParent)

function CombatMode:BaseCrosshairState()
	local crossBase = "Interface\\AddOns\\CombatMode\\assets\\crosshair.tga"
	CrosshairFrame.texture:SetTexture(crossBase)
	CrosshairFrame.texture:SetVertexColor(1, 1, 1, .5)
end

function CombatMode:HostileCrosshairState()
	local crossHit = "Interface\\AddOns\\CombatMode\\assets\\crosshair-hit.tga"
	CrosshairFrame.texture:SetTexture(crossHit)
	CrosshairFrame.texture:SetVertexColor(1, .2, 0.3, 1)
end

function CombatMode:CreateCrosshair()
	CrosshairFrame.texture = CrosshairFrame:CreateTexture()
	CrosshairFrame.texture:SetAllPoints(CrosshairFrame)
	
	CrosshairFrame:SetPoint("CENTER", 0, self.db.global.crosshairY or 100)
	CrosshairFrame:SetSize(self.db.global.crosshairSize or 64, self.db.global.crosshairSize or 64)
	CrosshairFrame:SetAlpha(self.db.global.crosshairOpacity or 1.0)
	CombatMode:BaseCrosshairState()
end

function CombatMode:ShowCrosshair()
	CrosshairFrame.texture:Show()
end

function CombatMode:HideCrosshair()
	CrosshairFrame.texture:Hide()
end

function CombatMode:UpdateCrosshair()
	local dbValueToUpdate = self.db.global

	if dbValueToUpdate.crosshairY then
			CrosshairFrame:SetPoint("CENTER", 0, dbValueToUpdate.crosshairY)
	end

	if dbValueToUpdate.crosshairSize then
			CrosshairFrame:SetSize(dbValueToUpdate.crosshairSize, dbValueToUpdate.crosshairSize)
	end

	if dbValueToUpdate.crosshairOpacity then
			CrosshairFrame:SetAlpha(dbValueToUpdate.crosshairOpacity)
	end
end


function CombatMode:OnEnable()
	CombatMode:BindBindingOverrides()

	CombatMode:InitializeWildcardFrameTracking(wildcardFramesToMatch)

	self:CreateCrosshair()
	if self.db.global.crosshair then
		self:ShowCrosshair()
	else
		self:HideCrosshair()
	end

	-- Register Events
	self:RegisterEvent("PLAYER_ENTERING_WORLD", CombatMode_OnEvent)
	self:RegisterEvent("ADDON_LOADED", CombatMode_OnEvent)
	self:RegisterEvent("PLAYER_TARGET_CHANGED", CombatMode_OnEvent)
	self:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED", CombatMode_OnEvent)
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
	local valueToUse
	if value == defaultButtonValues.MACRO then
		valueToUse = "MACRO " .. macroValue
	else
		valueToUse = value
	end
	SetMouselookOverrideBinding(button, valueToUse)

	CombatMode:print(button .. "'s override binding is now " .. value)
end

function CombatMode:BindBindingOverrides()
	MouselookStop()
	CombatMode:BindBindingOverride("BUTTON1", self.db.profile.bindings.button1)
	CombatMode:BindBindingOverride("BUTTON2", self.db.profile.bindings.button2)
	CombatMode:BindBindingOverride("CTRL-BUTTON1", self.db.profile.bindings.ctrlbutton1)
	CombatMode:BindBindingOverride("CTRL-BUTTON2", self.db.profile.bindings.ctrlbutton2)
	CombatMode:BindBindingOverride("ALT-BUTTON1", self.db.profile.bindings.altbutton1)
	CombatMode:BindBindingOverride("ALT-BUTTON2", self.db.profile.bindings.altbutton2)
	CombatMode:BindBindingOverride("SHIFT-BUTTON1", self.db.profile.bindings.shiftbutton1)
	CombatMode:BindBindingOverride("SHIFT-BUTTON2", self.db.profile.bindings.shiftbutton2)
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

function CombatMode_OnEvent(event, unit, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		CombatMode:startMouselook()
		CombatMode:Rematch()
	end
	

	if combatModeAddonSwitch then
		if event == "PLAYER_TARGET_CHANGED" and not CombatMode:checkForDisableState() then			
			-- target changed		
		end

		if event == "PLAYER_SOFT_ENEMY_CHANGED" and not CombatMode:checkForDisableState() then
			local isTargetVisible = UnitIsVisible("target")
			local isTargetHostile = UnitReaction("player","target") and UnitReaction("player","target") <= 4

			if isTargetVisible and isTargetHostile then
				CombatMode:HostileCrosshairState()
			else
				CombatMode:BaseCrosshairState()
			end
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

