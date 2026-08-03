---------------------------------------------------------------------------------------
--  Constants/Assets.lua — CONSTANTS — textures, welcome copy, crosshair appearances
---------------------------------------------------------------------------------------
--  What it does: Holds static art paths and copy used by welcome UI, crosshair rendering,
--  Assisted Combat chrome, and modifier-key glyphs. Also defines CrosshairTextureObj /
--  appearance select values and reaction color tables the Crosshair tab and runtime read.
--  Architecture / how it works:
--    • `PopupMsg` / `BasePrintMsg` — welcome modal + print prefix (version from METADATA).
--  • Logo/Title BLPs, AssistedSpellIcon{Background,Glow,Frame,Mask,CooldownSwipe},
--      ModifierKey{Ctrl,Shift,Alt} BLPs under Interface\AddOns\CombatMode\assets\.
--    • CrosshairTextureObj entries pair active/inactive BLPs; AppearanceSelectValues
--      drives the Crosshair options dropdown.
--    • CrosshairReactionColors, CrosshairCastBreak (shared interrupt VFX), and
--      CrosshairCompanionOffsetX (Assist + Interaction HUD gap past reticle edge).
--  Does not: Draw widgets, own frame lifecycle, apply appearance at runtime, or
--  own Blizzard atlas FlipBook/VFX names (those stay local to the owning module).
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/AssistedHighlight/Assist.lua,
--  Core/Crosshair/AssistedHighlight/{Keybinds,CastProgress,Feedback}.lua,
--  Core/Crosshair/Animations.lua, UI/Options/Tabs/TabCrosshair.lua,
--  UI/Options/Widgets.lua, UI/Options/OptionsPanel.lua
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
CM.Constants.AssistedSpellIconBackground = assetsFolderPath .. "spell-bg.blp"
CM.Constants.AssistedSpellIconGlow = assetsFolderPath .. "spell-glow.blp"
CM.Constants.AssistedSpellIconFrame = assetsFolderPath .. "spell-frame.blp"
CM.Constants.AssistedSpellIconMask = assetsFolderPath .. "spell-mask.blp"
CM.Constants.AssistedSpellIconCooldownSwipe = assetsFolderPath .. "spell-swipe.blp"
CM.Constants.ModifierKeyCtrl = assetsFolderPath .. "key-ctrl.blp"
CM.Constants.ModifierKeyShift = assetsFolderPath .. "key-shift.blp"
CM.Constants.ModifierKeyAlt = assetsFolderPath .. "key-alt.blp"

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
  hostile = { 1, 0.2, 0.3, 1 }, -- red (also cast-break flash + Target Lock nameplate)
  friendly_npc = { 0, 1, 0.3, 0.8 }, -- green (friendly NPCs)
  friendly_player = { 0.3, 0.6, 1, 0.8 }, -- blue (friendly players)
  object = { 1, 0.8, 0.2, 0.8 }, -- yellow
  base = { 1, 1, 1, 0.5 }, -- white
  mounted = { 1, 1, 1, 0 }, -- transparent
  focus = { 1, 0.2, 0.3, 1 }, -- Target Lock nameplate: same as hostile
}

-- Interrupt/cancel cast-break VFX (crosshair cast feedback + Assist CastProgress).
-- Flash red uses CrosshairReactionColors.hostile (do not duplicate the RGB).
CM.Constants.CrosshairCastBreak = {
  duration = 0.18,
  shakePx = 5,
  flashHz = 22,
  grey = { 0.72, 0.72, 0.72, 1 },
}

-- Interaction HUD + Combat Assist: pixels beyond the crosshair edge (keep in sync).
CM.Constants.CrosshairCompanionOffsetX = 24
