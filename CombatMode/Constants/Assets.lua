---------------------------------------------------------------------------------------
--  Constants/Assets.lua — CONSTANTS — textures, welcome copy, crosshair appearances
---------------------------------------------------------------------------------------
--  What it does: Holds static art paths and copy used by welcome UI, crosshair rendering,
--  Assisted Combat chrome, and modifier-key glyphs. Also defines CrosshairTextureObj /
--  appearance select values and reaction color tables the Crosshair tab and runtime read.
--  Architecture / how it works:
--    • `PopupMsg` / `BasePrintMsg` — welcome modal + print prefix (version from METADATA).
--    • Art lives under Interface\AddOns\CombatMode\Assets\: branding\ (logo, title, Discord/GitHub/
--      Sponsor icons), crosshair\ (reticle BLP pairs), assisthud\ (AssistedSpellIcon*, ModifierKey{Ctrl,
--      Shift,Alt}), ui\ (window shadow TGA) and atlas\ (shipped Blizzard atlases, Constants/Atlas.lua).
--    • CrosshairTextureObj entries pair active/inactive BLPs; AppearanceSelectValues
--      drives the Crosshair options dropdown. CrosshairSituationalHidden is the
--      Advanced-only Invisible choice (no texture).
--    • CrosshairReactionColors (defaults only — runtime tints use
--      CM.GetCrosshairReactionColor), CrosshairCastBreak (shared interrupt VFX), and
--      CrosshairCompanionOffsetX (default companion Distance fallback).
--  Does not: Draw widgets, own frame lifecycle, apply appearance at runtime, or
--  own Blizzard atlas FlipBook/VFX names (those stay local to the owning module).
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/AssistedHighlight/Assist.lua,
--  Core/Crosshair/AssistedHighlight/{Keybinds,CastProgress,Feedback}.lua,
--  Core/Crosshair/Animations.lua, UI/Editors/CrosshairColorsEditor.lua,
--  UI/Options/Tabs/TabCrosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local ipairs = _G.ipairs

-- Body only: the welcome modal (CM.UI.ShowWelcome) draws the wordmark header itself.
-- Slash commands keep inline color: blue for options (/acm, /actioncombatmode).
CM.Constants.PopupMsg = "Welcome to Action Combat Mode!\n\n"
  .. "The configuration panel will open after you close this message.\n\n"
  .. "You can reopen it anytime with |cff69ccf0/acm|r or |cff69ccf0/actioncombatmode|r.\n\n"
  .. "|cff909090To restore your previous settings, use the |cffff5555Uninstall|r button in the options panel.|r\n\n"

-- Key Bindings screen labels. The binding names in Bindings.xml ("Combat Mode - ...") are IDs the
-- client stores players' key assignments under (and the code looks up by that exact string), so
-- they stay as they are; these globals only change the text shown for them.
local BINDING_DISPLAY_NAMES = {
  "Mouse Look",
  "Flip Camera",
  "Reset Mouse Look",
  "Ally Cycle Next",
  "Ally Cycle Previous",
  "Toggle Focus Target",
  "Cycle Focus Next",
  "Cycle Focus Previous",
}
for _, label in ipairs(BINDING_DISPLAY_NAMES) do
  _G["BINDING_NAME_Combat Mode - " .. label] = "Action Combat Mode - " .. label
end

CM.Constants.BasePrintMsg = CM.METADATA["TITLE"]
  .. " |cff00ff00v."
  .. CM.METADATA["VERSION"]
  .. "|r"

local assetsFolderPath = "Interface\\AddOns\\CombatMode\\Assets\\"
local brandingPath = assetsFolderPath .. "branding\\"
local crosshairPath = assetsFolderPath .. "crosshair\\"
local assistHudPath = assetsFolderPath .. "assisthud\\"
local uiPath = assetsFolderPath .. "ui\\"
CM.Constants.Logo = brandingPath .. "cmlogo.blp"
CM.Constants.Title = brandingPath .. "cmtitle.blp"
-- The title art is stored squashed in the 256x64 texture canvas (with empty space above and
-- below the lettering), so it must be displayed at this aspect, not the file's 4:1. 2.1 was
-- measured from the in-game render against the mockup (2.7 looked stretched sideways).
-- Use CM.Constants.TitleSize(height) wherever the title is drawn.
CM.Constants.TitleAspect = 2.1
function CM.Constants.TitleSize(height)
  return math.floor(height * CM.Constants.TitleAspect + 0.5), height
end
-- Soft window drop shadow: 128x128 TGA, a blurred rounded box (box 48..80, radius 10) sliced as
-- 9 pieces by UI.AddWindowShadow.
CM.Constants.Shadow = uiPath .. "shadow.tga"
-- Blizzard textures shipped as TGAs (so they do not depend on the client): color picker thumbs
-- (64x16 sheet), the wizard check mark and the frame picker's fallback addon icon.
CM.Constants.ColorPickerThumbs = uiPath .. "colorpicker-buttons.tga"
CM.Constants.CheckMark = uiPath .. "checkbox-check.tga"
CM.Constants.UnknownAddonIcon = uiPath .. "question-mark.tga"
CM.Constants.DiscordIcon = brandingPath .. "discord.blp"
CM.Constants.GitHubIcon = brandingPath .. "github.blp"
CM.Constants.SponsorIcon = brandingPath .. "sponsor.blp"
CM.Constants.DiscordURL = "https://www.discord.gg/5mwBSmz"
CM.Constants.GitHubURL = "https://github.com/djsmithdev/combatmode"
CM.Constants.SponsorsURL = "https://github.com/sponsors/sampconrad"
-- Combat Assist icon shell: background and mask are Blizzard atlases; the frame (84x74 TGA, ring
-- on the left with a pointer on the right), glow and cooldown swipe are addon textures.
CM.Constants.AssistedSpellIconBackground = "UI-Journeys-Delve-rewardicon-ring-BG"
CM.Constants.AssistedSpellIconGlow = assistHudPath .. "spell-glow.blp"
CM.Constants.AssistedSpellIconFrame = assistHudPath .. "spell-frame.tga"
CM.Constants.AssistedSpellIconMask = "UI-Journeys-Delve-rewardicon-ring-Mask"
CM.Constants.AssistedSpellIconCooldownSwipe = assistHudPath .. "spell-swipe.blp"
CM.Constants.ModifierKeyCtrl = assistHudPath .. "key-ctrl.blp"
CM.Constants.ModifierKeyShift = assistHudPath .. "key-shift.blp"
CM.Constants.ModifierKeyAlt = assistHudPath .. "key-alt.blp"

--[[
  CROSSHAIR TEXTURES
  To add custom textures, you'll need two .BLP textures: one for the active and one for the inactive states.
  Place them in the CombatMode/Assets/crosshair folder and rename them as follows:
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
    Base = crosshairPath .. "crosshair" .. assetName .. ".blp",
    Active = crosshairPath .. "crosshair" .. assetName .. "-hit.blp",
  }
  CM.Constants.CrosshairAppearanceSelectValues[assetName] = assetName
end

-- Situational-only. Not a texture; the reticle hides while the condition is true.
-- Kept out of CrosshairAppearanceSelectValues so the main Appearance dropdown cannot select it.
CM.Constants.CrosshairSituationalHidden = {
  Name = "Invisible",
  Hidden = true,
}

CM.Constants.CrosshairReactionColors = {
  hostile = { 1, 0.2, 0.3, 1 }, -- red (also cast-break flash + Target Lock nameplate)
  friendly_npc = { 0, 1, 0.3, 0.8 }, -- green (friendly NPCs)
  friendly_player = { 0.3, 0.6, 1, 0.8 }, -- blue (friendly players)
  object = { 1, 0.8, 0.2, 0.8 }, -- yellow
  base = { 1, 1, 1, 0.5 }, -- white
  mounted = { 1, 1, 1, 0 }, -- transparent
  --  focus = { 1, 0.2, 0.3, 1 }, -- defaults only; runtime focus tint uses hostile via getter
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
