---------------------------------------------------------------------------------------
--  Core/RadialMenu/Actions.lua — RADIALMENU — UI actions a slice can run (map, bags, panels)
---------------------------------------------------------------------------------------
--  What it does: Registry of curated UI actions (CM.RadialActions) plus one plain Button per
--  action. A slice of kind "action" runs the secure macro "/click CombatModeRadialAct_<id>"; the
--  Button's OnClick calls the matching Blizzard toggle, so panels open from the wheel in combat
--  as far as Blizzard allows.
--  Architecture / how it works:
--    • CM.RadialActions.list (ordered, for the editor picker) and .byId[id] = { id, label, icon,
--      button, run, group? }. `run` resolves the Blizzard function at click time (names differ by patch);
--      a missing function simply does nothing.
--    • Proxy buttons are created once at load (CM.InitializeRadialActions is not needed): a button
--      created out of combat is clickable by secure macros forever.
--  `group = "emote"` (DoEmote tokens), `"command"` and `"marker"` entries are listed under their own
--  sections in the editor. Entries with `macro = "/cmd"` (commands, raid / world markers) skip the proxy
--  Button: the slice runs that text as its own secure macro.
--  Icons: game menu bar art (radial_icon_*.tga), the emote name written inside the circle for emotes,
--  the addon logo for Action Combat Mode options, and "portrait" (the player's 2D portrait, drawn by
--  CM.RadialSetIcon) for Character Info.
--  Client availability: `click = {buttons}` (micro buttons; the first one that exists is clicked, as a
--  secure /click so Blizzard's own handler runs) or `requires = "Global"`; CM.RadialActions.IsAvailable
--  hides what the client lacks from the editor and the default wheels, and a saved slice for a missing
--  action is skipped by the wheel.
--  Does not: Own the wheel, draw anything, or touch bindings.
--  Related: Core/RadialMenu/Data.lua (CM.RadialEntrySecure), UI/Options/Tabs/TabRadialMenu.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame

-- Lua stdlib
local type = _G.type

local function Call(name, ...)
  local fn = _G[name]
  if type(fn) == "function" then
    fn(...)
    return true
  end
  return false
end

local function Icon(path)
  return "Interface\\Icons\\" .. path
end

-- Game menu bar art (Interface/hud/uimicromenu2x), shipped as TGA.
local function Micromenu(name)
  return "Interface\\AddOns\\CombatMode\\Assets\\radial\\radial_icon_" .. name
end

-- Emotes have no art: their slice shows the emote name inside the circle (sentinel icon "text").
local TEXT_ICON = "text"

local DEFINITIONS = {
  {
    id = "character",
    label = "Character Info",
    icon = "portrait",
    click = { "CharacterMicroButton" },
  },
  {
    id = "spellbook",
    label = "Spellbook & Talents",
    icon = Micromenu("spellbookabilities"),
    click = { "PlayerSpellsMicroButton", "SpellbookMicroButton" },
  },
  {
    id = "talents",
    label = "Talents",
    icon = Micromenu("spectalents"),
    click = { "PlayerSpellsMicroButton", "TalentMicroButton" },
  },
  {
    id = "map",
    label = "World Map",
    icon = Icon("INV_Misc_Map_01"),
    noCombat = true, -- Blizzard blocks addon code from opening the map in combat
    requires = "ToggleWorldMap",
    run = function()
      Call("ToggleWorldMap")
    end,
  },
  {
    id = "bags",
    label = "All Bags",
    icon = Icon("INV_Misc_Bag_08"),
    requires = "ToggleAllBags",
    run = function()
      Call("ToggleAllBags")
    end,
  },
  {
    id = "professions",
    label = "Professions",
    icon = Micromenu("professions"),
    click = { "ProfessionMicroButton" },
  },
  {
    id = "achievements",
    label = "Achievements",
    icon = Micromenu("achievements"),
    click = { "AchievementMicroButton" },
  },
  {
    id = "questlog",
    label = "Quest Log",
    icon = Micromenu("questlog"),
    click = { "QuestLogMicroButton" },
  },
  {
    id = "guild",
    label = "Guild & Communities",
    icon = Micromenu("guildcommunities"),
    click = { "GuildMicroButton" },
  },
  {
    id = "groupfinder",
    label = "Group Finder",
    icon = Micromenu("groupfinder"),
    click = { "LFDMicroButton", "LFGMicroButton" },
  },
  {
    id = "collections",
    label = "Warband Collection",
    icon = Micromenu("collections"),
    click = { "CollectionsMicroButton" },
  },
  {
    id = "housing",
    label = "Housing Dashboard",
    icon = Micromenu("housing"),
    click = { "HousingMicroButton" },
  },
  {
    id = "adventureguide",
    label = "Adventure Guide",
    icon = Micromenu("adventureguide"),
    click = { "EJMicroButton" },
  },
  {
    id = "calendar",
    label = "Calendar",
    icon = Icon("INV_Misc_Note_06"),
    click = { "GameTimeFrame" },
  },
  {
    id = "social",
    label = "Friends & Social",
    icon = Icon("INV_Letter_15"),
    noCombat = true,
    requires = "ToggleFriendsFrame",
    run = function()
      Call("ToggleFriendsFrame")
    end,
  },
  {
    id = "gamemenu",
    label = "Game Menu",
    icon = Micromenu("gamemenu"),
    -- MainMenuMicroButton ignores clicks unless the mouse is over it (the wheel is), and ToggleGameMenu
    -- stops casting, which is forbidden to addon code in combat.
    noCombat = true,
    requires = "ToggleGameMenu",
    run = function()
      Call("ToggleGameMenu")
    end,
  },
  {
    id = "acmoptions",
    label = "Action Combat Mode Options",
    icon = CM.Constants.Logo,
    run = function()
      if CM.OpenOptions then
        CM.OpenOptions()
      end
    end,
  },
  {
    id = "emote_wave",
    label = "Wave",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "WAVE")
    end,
  },
  {
    id = "emote_dance",
    label = "Dance",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "DANCE")
    end,
  },
  {
    id = "emote_cheer",
    label = "Cheer",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "CHEER")
    end,
  },
  {
    id = "emote_bow",
    label = "Bow",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "BOW")
    end,
  },
  {
    id = "emote_salute",
    label = "Salute",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "SALUTE")
    end,
  },
  {
    id = "emote_laugh",
    label = "Laugh",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "LAUGH")
    end,
  },
  {
    id = "emote_flex",
    label = "Flex",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "FLEX")
    end,
  },
  {
    id = "emote_roar",
    label = "Roar",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "ROAR")
    end,
  },
  {
    id = "emote_thank",
    label = "Thank",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "THANK")
    end,
  },
  {
    id = "emote_clap",
    label = "Clap",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "CLAP")
    end,
  },
  {
    id = "emote_point",
    label = "Point",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "POINT")
    end,
  },
  {
    id = "emote_cry",
    label = "Cry",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "CRY")
    end,
  },
  {
    id = "emote_sit",
    label = "Sit",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "SIT")
    end,
  },
  {
    id = "emote_kneel",
    label = "Kneel",
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", "KNEEL")
    end,
  },
}

-- More UI panels (plain Blizzard toggles; names verified like the rest, a missing one does nothing).
local function Panel(id, label, icon, run, noCombat)
  DEFINITIONS[#DEFINITIONS + 1] =
    { id = id, label = label, icon = icon, run = run, noCombat = noCombat }
end

Panel("reputation", "Reputation", Icon("Achievement_Reputation_01"), function()
  Call("ToggleCharacter", "ReputationFrame")
end)
Panel("currency", "Currency", Icon("INV_Misc_Coin_01"), function()
  Call("ToggleCharacter", "TokenFrame")
end)
Panel("greatvault", "Great Vault", Icon("INV_Box_01"), function()
  local loadAddOn = _G.C_AddOns and _G.C_AddOns.LoadAddOn or _G.LoadAddOn
  if not _G.WeeklyRewardsFrame and loadAddOn then
    loadAddOn("Blizzard_WeeklyRewards")
  end
  if _G.WeeklyRewardsFrame then
    Call("ToggleFrame", _G.WeeklyRewardsFrame)
  end
end, true)
Panel("mounts", "Mount Journal", Icon("Ability_Mount_RidingHorse"), function()
  Call("ToggleCollectionsJournal", 1)
end)
Panel("petjournal", "Pet Journal", Icon("INV_Pet_BattlePetTraining"), function()
  Call("ToggleCollectionsJournal", 2)
end)
Panel("toybox", "Toy Box", Icon("INV_Misc_Toy_10"), function()
  Call("ToggleCollectionsJournal", 3)
end)
Panel("macros", "Macros", Icon("INV_Scroll_03"), function()
  Call("ShowMacroFrame")
end, true)

-- More emotes (DoEmote is not protected).
for _, emote in ipairs({
  { "hello", "Hello", "HELLO" },
  { "bye", "Goodbye", "BYE" },
  { "applaud", "Applaud", "APPLAUD" },
  { "shrug", "Shrug", "SHRUG" },
  { "yes", "Yes", "YES" },
  { "no", "No", "NO" },
  { "kiss", "Kiss", "KISS" },
  { "flirt", "Flirt", "FLIRT" },
  { "rude", "Rude", "RUDE" },
  { "ready", "Ready", "READY" },
  { "victory", "Victory", "VICTORY" },
}) do
  DEFINITIONS[#DEFINITIONS + 1] = {
    id = "emote_" .. emote[1],
    label = emote[2],
    group = "emote",
    icon = TEXT_ICON,
    run = function()
      Call("DoEmote", emote[3])
    end,
  }
end

-- Slash commands run as the slice's own secure macro text (`macro`), so they work in combat as far as
-- the command allows. No proxy button is made for these.
local function Command(id, label, group, icon, macro, noCombat, needsGroup)
  DEFINITIONS[#DEFINITIONS + 1] = {
    id = id,
    label = label,
    group = group,
    icon = icon,
    macro = macro,
    noCombat = noCombat,
    needsGroup = needsGroup, -- shown as unusable on the wheel while not in a group
  }
end

Command(
  "readycheck",
  "Ready Check",
  "command",
  Icon("Achievement_Dungeon_ClassicDungeonMaster"),
  "/readycheck"
)
Command("roll", "Roll (1-100)", "command", Icon("INV_Misc_Dice_02"), "/roll")
Command("afk", "Toggle AFK", "command", Icon("Spell_Nature_Sleep"), "/afk")
Command("dnd", "Toggle Do Not Disturb", "command", Icon("Spell_Holy_SealOfProtection"), "/dnd")
Command("camp", "Camp (Log Out)", "command", Icon("INV_Misc_Bedroll_01"), "/camp", true)
Command("dismount", "Dismount", "command", Icon("Ability_Mount_Dreadsteed"), "/dismount")
Command(
  "leavevehicle",
  "Leave Vehicle",
  "command",
  Icon("Ability_Vehicle_LoadSelfCatapult"),
  "/leavevehicle"
)

local MARKERS = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local function MarkerIcon(index)
  return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end
for index, name in ipairs(MARKERS) do
  Command("tm" .. index, "Mark Target: " .. name, "marker", MarkerIcon(index), "/tm " .. index)
end
Command("tm0", "Clear Target Mark", "marker", Icon("Ability_Rogue_Disguise"), "/tm 0")
for index, name in ipairs(MARKERS) do
  Command(
    "wm" .. index,
    "World Marker: " .. name,
    "marker",
    MarkerIcon(index),
    "/wm " .. index,
    nil,
    true
  )
end
Command(
  "cwm",
  "Clear World Markers",
  "marker",
  Icon("Ability_Rogue_Disguise"),
  "/cwm all",
  nil,
  true
)

-- Client availability: panels and commands that the running client doesn't have (Classic / Forever
-- lack many Retail windows) are hidden from the editor and skipped by the wheel. `click` lists micro
-- buttons (first one that exists is clicked); `requires` names a global the action needs.
local PANEL_REQUIRES = {
  reputation = "ToggleCharacter",
  currency = "ToggleCharacter",
  greatvault = "C_WeeklyRewards",
  mounts = "ToggleCollectionsJournal",
  petjournal = "ToggleCollectionsJournal",
  toybox = "ToggleCollectionsJournal",
  macros = "ShowMacroFrame",
  cwm = "PlaceRaidMarker",
}
for index = 1, 8 do
  PANEL_REQUIRES["wm" .. index] = "PlaceRaidMarker"
end
for _, def in ipairs(DEFINITIONS) do
  def.requires = def.requires or PANEL_REQUIRES[def.id]
end

local registry = { list = {}, byId = {} }
CM.RadialActions = registry

--- First existing button of a `click` list (nil when the client has none).
local function ClickButton(def)
  for _, name in ipairs(def.click) do
    if _G[name] then
      return name
    end
  end
  return nil
end

--- True when the running client offers this action.
function registry.IsAvailable(def)
  if type(def) == "string" then
    def = registry.byId[def]
  end
  if not def then
    return false
  end
  if def.click then
    return ClickButton(def) ~= nil
  end
  return def.requires == nil or _G[def.requires] ~= nil
end

--- Secure macro text a slice runs for this action, or nil when the client lacks it.
function registry.MacroText(def)
  if def.click then
    local name = ClickButton(def)
    return name and ("/click " .. name) or nil
  end
  return def.macro or ("/click " .. def.button)
end

for _, def in ipairs(DEFINITIONS) do
  if def.icon == TEXT_ICON then
    def.iconText = def.label
  end
  if not def.macro and not def.click then
    def.button = "CombatModeRadialAct_" .. def.id
    local proxy = CreateFrame("Button", def.button, _G.UIParent)
    proxy:RegisterForClicks("AnyUp", "AnyDown")
    proxy:SetScript("OnClick", function(_, _, down)
      -- "/click" sends an up and a down: run once per click.
      -- noCombat panels would taint protected Blizzard frames, so never run them in combat.
      if (down == false or down == nil) and not (def.noCombat and _G.InCombatLockdown()) then
        def.run()
      end
    end)
  end
  registry.list[#registry.list + 1] = def
  registry.byId[def.id] = def
end
