---------------------------------------------------------------------------------------
--  Constants/Assets.lua — CONSTANTS — assets, welcome message, crosshair textures
---------------------------------------------------------------------------------------
--  Owns CM.Constants.PopupMsg (first-install welcome body), BasePrintMsg, Logo/Title
--  texture paths, PulseAtlas, and CrosshairTextureObj / CrosshairReaction* tables used
--  by Core/Crosshair and the Crosshair options tab.
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local ipairs = _G.ipairs

-- Body only: the welcome modal (CM.UI.ShowWelcome) draws the logo + wordmark header itself.
-- Slash commands keep inline color: blue for options (/cm, /combatmode).
CM.Constants.PopupMsg = "Thank you for trying out Combat Mode!\n\n"
  .. "Upon closing this, the config panel will automatically open.\n\n"
  .. "You can also open it anytime with the commands |cff69ccf0/cm|r or |cff69ccf0/combatmode|r.\n\n"
  .. "If you decide not to keep Combat Mode, use the |cffff5555Uninstall|r button at the bottom of the options sidebar. That restores your previous camera and targeting settings, disables the addon, and reloads.\n\n"
  .. "|cff909090Do not only disable or delete the addon without Uninstall — some camera settings are saved by the game and would otherwise stick around.|r"

CM.Constants.BasePrintMsg = CM.METADATA["TITLE"]
  .. " |cff00ff00v."
  .. CM.METADATA["VERSION"]
  .. "|r"

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
]]
--
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
    Active = assetsFolderPath .. "crosshair" .. assetName .. "-hit.blp",
  }
  CM.Constants.CrosshairAppearanceSelectValues[assetName] = assetName
end

CM.Constants.CrosshairReactionColors = {
  hostile = { 1, 0.2, 0.3, 1 }, -- red
  friendly_npc = { 0, 1, 0.3, 0.8 }, -- green (friendly NPCs)
  friendly_player = { 0.3, 0.6, 1, 0.8 }, -- blue (friendly players)
  object = { 1, 0.8, 0.2, 0.8 }, -- yellow
  base = { 1, 1, 1, 0.5 }, -- white
  mounted = { 1, 1, 1, 0 }, -- transparent
  focus = { 1, 0, 1, 1 }, -- purple
}
