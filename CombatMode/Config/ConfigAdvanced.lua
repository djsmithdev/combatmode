---------------------------------------------------------------------------------------
--  Config/ConfigAdvanced.lua — Advanced panel (custom cursor-unlock Lua condition)
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Header, Description = U.Spacing, U.Header, U.Description

CM.Config.AdvancedOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    header = Header("advanced", 1),
    description = Description("advanced", 2),
    customCondition = {
      type = "group",
      name = "",
      order = 3,
      inline = true,
      args = {
        customConditionCode = {
          type = "input",
          name = "Custom Condition:",
          order = 1,
          multiline = 14,
          width = "full",
          set = function(_, input)
            CM.DB.global.customCondition = input
          end,
          get = function()
            return CM.DB.global.customCondition
          end,
        },
        spacing5 = Spacing("full", 2),
        devnote = {
          type = "group",
          name = "|cffffd700Developer Note|r",
          order = 3,
          inline = true,
          args = {
            crosshairNote = {
              type = "description",
              name = "|cff909090Knowing the basics of |cff69ccf0Lua|r and the |cffffd700WoW API|r is essential for using custom conditions.|r \n\n|cffFF5050Combat Mode's authors are not responsible for custom code issues and are not obligated to provide users any support for it.|r",
              order = 1,
            },
            wowpediaApi = {
              name = "You can find the documentation for the WoW API here:",
              desc = "warcraft.wiki.gg/wiki/World_of_Warcraft_API",
              type = "input",
              width = 2.2,
              order = 3,
              get = function()
                return "warcraft.wiki.gg/wiki/World_of_Warcraft_API"
              end,
            },
          },
        },
      },
    },
  },
}
