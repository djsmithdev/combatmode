local L = LibStub("AceLocale-3.0"):NewLocale("CombatMode", "enUS", true)
if not L then
    error("[Combat Mode] enUS locale registration failed for Combat Mode.")
    return
end
-- @localization(locale="enUS", format="lua_additive_table", handle-unlocalized="ignore")@

L["BUTTON_1_MACRO_DESC"] = "Enter the name of the action you wish to be ran here."
L["CURSEFORGE"] = "curseforge.com/wow/addons/combat-mode"
L["DISCORD"] = "discord.gg/5mwBSmz"
