CombatMode = LibStub("AceAddon-3.0"):NewAddon("CombatMode", "AceConsole-3.0", "AceEvent-3.0")

local combatModeAddonSwitch = false
local combatModeTemporaryDisable = false
local CursorActionActive = false
local CombatModeQuiet = true
local mouseLookStarted = false


local FramesToCheck = {
  "AuctionFrame",       "BankFrame",          "BattlefieldFrame",   "CharacterFrame",
  "ChatMenu",           "EmoteMenu",          "LanguageMenu",       "VoiceMacroMenu",
  "ClassTrainerFrame",  "CoinPickupFrame",    "CraftFrame",         "FriendsFrame",
  "GameMenuFrame",      "GossipFrame",        "GuildRegistrarFrame","HelpFrame",
  "InspectFrame",       "KeyBindingFrame",    "LoXXXotFrame",       "MacroFrame",
  "MailFrame",          "MerchantFrame",      "OptionsFrame",       "PaperDollFrame",
  "PetPaperDollFrame",  "PetRenamePopup",     "PetStable",          "QuestFrame",
  "QuestLogFrame",      "RaidFrame",          "ReputationFrame",    "ScriptErrors",
  "SkillFrame",         "SoundOptionsFrame",  "SpellBookFrame",     "StackSplitFrame",
  "StatsFrame",         "SuggestFrame",       "TabardFrame",        "TalentFrame",
  "TalentTrainerFrame", "TaxiFrame",          "TradeFrame",         "TradeSkillFrame",
  "TutorialFrame",      "UIOptionsFrame",     "UnitPopup",          "WorldMapFrame",
  "CosmosMasterFrame",  "CosmosDropDown",     "ChooseItemsFrame",   "ImprovedErrorFrame",
  "TicTacToeFrame",     "OthelloFrame",       "MinesweeperFrame",   "GamesListFrame",
  "ConnectFrame",       "ChessFrame",         "QuestShareFrame",    "TotemStomperFrame",
  "StaticPopXXXup1",    "StaticPopup2",       "StaticPopup3",       "StaticPopup4",
  "DropDownList1",      "DropDownList2",      "DropDownList3",      "WantAds",
  "CosmosDropDownBis",  "InventoryManagerFrame", "InspectPaperDollFrame",
  "ContainerFrame1",    "ContainerFrame2",    "ContainerFrame3",    "ContainerFrame4",
  "ContainerFrame5",    "ContainerFrame6",    "ContainerFrame7",    "ContainerFrame8",
  "ContainerFrame9",    "ContainerFrame10",   "ContainerFrame11",   "ContainerFrame12",
  "ContainerFrame13",   "ContainerFrame14",   "ContainerFrame15",   "ContainerFrame16",
  "ContainerFrame17",   "AutoPotion_Template_Dialog","NxSocial",    "ARKINV_Frame1",
  "AchievementFrame",   "LookingForGuildFrame", "PVPUIFrame",       "GuildFrame",
  "WorldMapFrame",      "VideoOptionsFrame",  "InterfaceOptionsFrame", "WardrobeFrame",
  "ACP_AddonList",      "PlayerTalentFrame",  "PVEFrame",           "EncounterJournal",
  "PetJournalParent",   "AccountantFrame",    "ImmersionFrame",     "BagnonFrameinventory",
  "GwCharacterWindow",  "GwCharacterWindowsMoverFrame", "StaticPopup1", "FlightMapFrame",

  "CommunitiesFrame",   "DungeonReadyPopup",   "LFGDungeonReadyDialog", "BossBanner",
  "PVPMatchResults",     "WeakAurasOptions",   "ReadyCheckListenerFrame", "BonusRollFrame",
  "QuickKeybindFrame",  "MAOptions",           "PVPReadyDialog???"
}

function CombatMode:OnInitialize()
  defaultButtonValues = {
    MOVEANDSTEER = "MOVEANDSTEER",
    MOVEBACKWARD = "MOVEBACKWARD",
    MOVEFORWARD = "MOVEFORWARD",
    JUMP = "JUMP",
    CAMERAORSELECTORMOVE = "CAMERAORSELECTORMOVE",
    TARGETSCANENEMY = "TARGETSCANENEMY",
    TARGETPREVIOUSFRIEND = "TARGETPREVIOUSFRIEND",
    INTERACTTARGET = "INTERACTTARGET",
    TARGETNEARESTENEMY = "TARGETNEARESTENEMY",
    TARGETNEARESTENEMYPLAYER = "TARGETNEARESTENEMYPLAYER",
    TARGETNEARESTFRIEND = "TARGETNEARESTFRIEND",
    TARGETNEARESTFRIENDPLAYER = "TARGETNEARESTFRIENDPLAYER",
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
        ctrlbutton1 = {
          key = "CTRL-BUTTON1",
          value = "TARGETSCANENEMY",
        },
        ctrlbutton2 = {
          key = "CTRL-BUTTON2",
          value = "TARGETNEARESTFRIEND",
        },
      },
      }
  }

  CombatModeOptions = {
    name = "Combat Mode Settings",

    handler = CombatMode,
    type = "group",
    args = {
      button1 = {
        name = "Left Click",
        desc = "Left Click",
        type = "select",
        width = "full",
        order = 1,
        values = defaultButtonValues,
        set = function(info, value)
          self.db.profile.bindings.button1.value = value
        end,
        get = function()
          return self.db.profile.bindings.button1.value
        end
      },
      button2 = {
        name = "Right Click",
        desc = "Right Click",
        type = "select",
        width = "full",
        order = 2,
        values = defaultButtonValues,
        set = function(info, value)
          self.db.profile.bindings.button2.value = value
        end,
        get = function()
          return self.db.profile.bindings.button2.value
        end
      },
      ctrlbutton1 = {
        name = "Control + Left Click",
        desc = "Control + Left Click",
        type = "select",
        width = "full",
        order = 3,
        values = defaultButtonValues,
        set = function(info, value)
          self.db.profile.bindings.ctrlbutton1.value = value
        end,
        get = function()
          return self.db.profile.bindings.ctrlbutton1.value
        end
      },
      ctrlbutton2 = {
        name = "Control + Right Click",
        desc = "Control + Right Click",
        type = "select",
        width = "full",
        order = 4,
        values = defaultButtonValues,
        set = function(info, value)
          self.db.profile.bindings.ctrlbutton2.value = value
        end,
        get = function()
          return self.db.profile.bindings.ctrlbutton2.value
        end
      }
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
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("cm", "CombatMode", input)
    end
end

function CombatMode:OnEnable()
  -- Register Events
  self:RegisterEvent("PLAYER_TARGET_CHANGED", CombatMode_OnEvent)
  self:RegisterEvent("CURSOR_UPDATE", CombatMode_OnEvent)
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
  MouselookStart()
end

function CombatMode:UnmouseableFrameOnScreen()
  for index in pairs(FramesToCheck) do
    local curFrame = getglobal(FramesToCheck[index])
    if (curFrame and curFrame:IsVisible()) then
      return true
    end
  end
end

function CombatMode:checkForDisableState()
  return (CombatMode:UnmouseableFrameOnScreen() or SpellIsTargeting() or CursorActionActive)
end


function CombatMode:CMPrint(statement)
  if not CombatModeQuiet then
    print(statement)
  end
end

-- Start Mouselook
function CombatMode:startMouselook()
  ResetCursor()
  if combatModeTemporaryDisable and not CombatMode:checkForDisableState() then
    combatModeTemporaryDisable = false
    MouselookStart()
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
  combatModeAddonSwitch = not combatModeAddonSwitch
  if combatModeAddonSwitch then
    CombatMode:BindBindingOverrides()
    CombatMode:startMouselook()
  else
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
  CombatMode:Toggle()
  if keystate == "down" then
    combatModeTemporaryDisable = true
  else
    combatModeTemporaryDisable = false
  end
end

function CombatMode_OnEvent(event, ...)
  if combatModeAddonSwitch then
    if event == "PLAYER_TARGET_CHANGED" and not CombatMode:checkForDisableState() then
      -- target changed
    end

    if event == "CURSOR_UPDATE" and not CombatMode:checkForDisableState() then
      CursorActionActive = true
    end

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
      MouselookStart()
      CursorActionActive = false
    end

    if event == "QUEST_PROGRESS" then
      MouselookStop()
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
