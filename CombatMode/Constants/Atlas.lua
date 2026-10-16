---------------------------------------------------------------------------------------
--  Constants/Atlas.lua — CONSTANTS — shipped Blizzard atlas textures
---------------------------------------------------------------------------------------
--  What it does: Maps the Blizzard atlas names the addon draws with to TGA copies shipped in
--  Assets\atlas\, plus helpers that draw them like SetAtlas / C_Texture.GetAtlasInfo.
--  Why: atlases are tied to the client build; other clients (Classic, Forever) lack many of
--  them, so every atlas the addon uses is exported once (wow.export) and loaded as a file.
--  Architecture / how it works:
--    • ATLASES: atlas name -> { file stem, w/h = the size the client draws it at (the TGAs are
--      often stored 2x larger and downsample), tileH / tileV for the tiling nine-slice edges }.
--      The "_" / "!" tiling prefix stays in the key but not in the file name.
--    • CM.GetAtlasInfo(name): C_Texture.GetAtlasInfo-shaped table (whole file, 0..1 coords),
--      nil for names that are not shipped.
--    • CM.SetAtlas(tex, name, useAtlasSize, filterMode): SetAtlas drop-in; a shipped name is
--      drawn from its TGA (tiling edges use REPEAT wrap), anything else falls back to the
--      client atlas (e.g. icons other addons declare).
--    • CM.SetAtlasMask(mask, name): MaskTexture version (black-additive clamp).
--  Does not: Own any widget or decide where an atlas is used.
--  Related: Constants/Assets.lua, UI/Options/Draw.lua, UI/Options/Widgets.lua, Core/*
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local ATLAS_PATH = "Interface\\AddOns\\CombatMode\\Assets\\atlas\\"

local ATLASES = {
  ["!GenericMetal2-NineSlice-EdgeLeft"] = {
    file = "GenericMetal2-NineSlice-EdgeLeft",
    w = 64,
    h = 512,
    tileV = true,
  },
  ["!GenericMetal2-NineSlice-EdgeRight"] = {
    file = "GenericMetal2-NineSlice-EdgeRight",
    w = 64,
    h = 512,
    tileV = true,
  },
  ["Artifacts-BG-Shadow"] = { file = "Artifacts-BG-Shadow", w = 896, h = 615 },
  ["CircleMaskScalable"] = { file = "CircleMaskScalable", w = 64, h = 64 },
  ["GenericMetal2-NineSlice-CornerBottomLeft"] = {
    file = "GenericMetal2-NineSlice-CornerBottomLeft",
    w = 64,
    h = 64,
  },
  ["GenericMetal2-NineSlice-CornerBottomRight"] = {
    file = "GenericMetal2-NineSlice-CornerBottomRight",
    w = 64,
    h = 64,
  },
  ["GenericMetal2-NineSlice-CornerTopLeft"] = {
    file = "GenericMetal2-NineSlice-CornerTopLeft",
    w = 64,
    h = 64,
  },
  ["GenericMetal2-NineSlice-CornerTopRight"] = {
    file = "GenericMetal2-NineSlice-CornerTopRight",
    w = 64,
    h = 64,
  },
  ["PetJournal-BattleSlot-Shadow"] = { file = "PetJournal-BattleSlot-Shadow", w = 138, h = 72 },
  ["QuestLog-icon-setting"] = { file = "QuestLog-icon-setting", w = 15, h = 16 },
  ["UF-RogueCP-Slash-Blue"] = { file = "UF-RogueCP-Slash-Blue", w = 258, h = 129 },
  ["UI-Frame-DpsIcon"] = { file = "UI-Frame-DpsIcon", w = 31, h = 30 },
  ["UI-Frame-HealerIcon"] = { file = "UI-Frame-HealerIcon", w = 31, h = 30 },
  ["UI-Frame-TankIcon"] = { file = "UI-Frame-TankIcon", w = 31, h = 30 },
  ["UI-Journeys-Delve-Arrow-down-pressed"] = {
    file = "UI-Journeys-Delve-Arrow-down-pressed",
    w = 18,
    h = 11,
  },
  ["UI-Journeys-Delve-rewardicon-ring-BG"] = {
    file = "UI-Journeys-Delve-rewardicon-ring-BG",
    w = 54,
    h = 54,
  },
  ["UI-Journeys-Delve-rewardicon-ring-Mask"] = {
    file = "UI-Journeys-Delve-rewardicon-ring-Mask",
    w = 64,
    h = 64,
  },
  ["_GenericMetal2-NineSlice-EdgeBottom"] = {
    file = "GenericMetal2-NineSlice-EdgeBottom",
    w = 512,
    h = 64,
    tileH = true,
  },
  ["_GenericMetal2-NineSlice-EdgeTop"] = {
    file = "GenericMetal2-NineSlice-EdgeTop",
    w = 512,
    h = 64,
    tileH = true,
  },
  ["common-icon-minus"] = { file = "common-icon-minus", w = 16, h = 16 },
  ["common-icon-plus"] = { file = "common-icon-plus", w = 16, h = 16 },
  ["decor-controls-inspect-default"] = { file = "decor-controls-inspect-default", w = 36, h = 36 },
  ["dragonflight-landingbutton-circleglow"] = {
    file = "dragonflight-landingbutton-circleglow",
    w = 100,
    h = 100,
  },
  ["evergreen-weeklyrewards-frame-back"] = {
    file = "evergreen-weeklyrewards-frame-back",
    w = 1134,
    h = 712,
  },
  ["evergreen-weeklyrewards-frame-back-shadow"] = {
    file = "evergreen-weeklyrewards-frame-back-shadow",
    w = 513,
    h = 513,
  },
  ["evergreen-weeklyrewards-header"] = { file = "evergreen-weeklyrewards-header", w = 735, h = 15 },
  ["friends-icon-addFriend-logo-WoW"] = { file = "friends-icon-addFriend-logo-WoW", w = 52, h = 52 },
  ["housing-floor-arrow-down-default"] = {
    file = "housing-floor-arrow-down-default",
    w = 16,
    h = 16,
  },
  ["housing-floor-arrow-up-default"] = { file = "housing-floor-arrow-up-default", w = 16, h = 16 },
  ["housing-floor-list-bg-active"] = { file = "housing-floor-list-bg-active", w = 235, h = 47.5 },
  ["mechagon-projects"] = { file = "mechagon-projects", w = 32, h = 32 },
  ["newplayertutorial-icon-mouse-leftbutton"] = {
    file = "newplayertutorial-icon-mouse-leftbutton",
    w = 52,
    h = 69,
  },
  ["newplayertutorial-icon-mouse-rightbutton"] = {
    file = "newplayertutorial-icon-mouse-rightbutton",
    w = 52,
    h = 69,
  },
  ["talents-search-suggestion-magnifyingglass"] = {
    file = "talents-search-suggestion-magnifyingglass",
    w = 12,
    h = 12,
  },
  ["widgetstatusbar-bgcenter"] = { file = "widgetstatusbar-bgcenter", w = 64, h = 18, tileH = true },
  ["widgetstatusbar-bgleft"] = { file = "widgetstatusbar-bgleft", w = 29, h = 18 },
  ["widgetstatusbar-bgright"] = { file = "widgetstatusbar-bgright", w = 29, h = 18 },
  ["widgetstatusbar-bordercenter"] = {
    file = "widgetstatusbar-bordercenter",
    w = 64,
    h = 31,
    tileH = true,
  },
  ["widgetstatusbar-borderleft"] = { file = "widgetstatusbar-borderleft", w = 35, h = 31 },
  ["widgetstatusbar-borderright"] = { file = "widgetstatusbar-borderright", w = 35, h = 31 },
  ["widgetstatusbar-fill-white"] = {
    file = "widgetstatusbar-fill-white",
    w = 256,
    h = 15,
    tileH = true,
  },
  ["widgetstatusbar-glowcenter"] = {
    file = "widgetstatusbar-glowcenter",
    w = 64,
    h = 31,
    tileH = true,
  },
  ["widgetstatusbar-glowleft"] = { file = "widgetstatusbar-glowleft", w = 35, h = 31 },
  ["widgetstatusbar-glowright"] = { file = "widgetstatusbar-glowright", w = 34, h = 31 },
  ["widgetstatusbar-spark"] = { file = "widgetstatusbar-spark", w = 8, h = 32 },
}

local infoCache = {}

function CM.GetAtlasInfo(name)
  local entry = ATLASES[name]
  if not entry then
    return nil
  end
  local info = infoCache[name]
  if not info then
    local file = ATLAS_PATH .. entry.file
    info = {
      file = file,
      filename = file,
      width = entry.w,
      height = entry.h,
      leftTexCoord = 0,
      rightTexCoord = 1,
      topTexCoord = 0,
      bottomTexCoord = 1,
      tilesHorizontally = entry.tileH or false,
      tilesVertically = entry.tileV or false,
    }
    infoCache[name] = info
  end
  return info
end

--- Drop-in for texture:SetAtlas(name, useAtlasSize, filterMode).
function CM.SetAtlas(tex, name, useAtlasSize, filterMode)
  local info = CM.GetAtlasInfo(name)
  if not info then
    tex:SetAtlas(name, useAtlasSize, filterMode)
    return
  end
  tex:SetTexture(
    info.file,
    info.tilesHorizontally and "REPEAT" or "CLAMP",
    info.tilesVertically and "REPEAT" or "CLAMP",
    filterMode
  )
  tex:SetTexCoord(0, 1, 0, 1)
  if useAtlasSize then
    tex:SetSize(info.width, info.height)
  end
end

--- Drop-in for maskTexture:SetAtlas(name, ...). Masks must clamp to black.
function CM.SetAtlasMask(mask, name)
  local info = CM.GetAtlasInfo(name)
  if not info then
    mask:SetAtlas(name, false)
    return
  end
  mask:SetTexture(info.file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
end
