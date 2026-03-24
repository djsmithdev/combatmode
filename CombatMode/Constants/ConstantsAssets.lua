---------------------------------------------------------------------------------------
--  Constants/ConstantsAssets.lua — constants module: assets/messages/visuals
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

local ipairs = _G.ipairs

CM.Constants.PopupMsg = CM.METADATA["TITLE"]
  .. "\n\n|cffffd700Thank you for trying out Combat Mode!|r \n\n|cffcfcfcfUpon closing this, an |cffB47EDEoptions panel|r will open where you'll be able to configure the addon to your liking.|r\n\n|cff909090To |cffFF5050undo all changes|r made by Combat Mode, type the following command in chat:|r\n|cff00FFFF/undocm|r"

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

CM.Constants.CrosshairEditModeMinHitSize = 128
CM.Constants.EditModeSystemDisplayName = "Combat Mode"
