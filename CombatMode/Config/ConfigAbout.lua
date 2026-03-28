---------------------------------------------------------------------------------------
--  Config/ConfigAbout.lua — About panel (reset, debug, metadata, links, View Changelog)
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Header = U.Spacing, U.Header

CM.Config.AboutOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  args = {
    ---------------------------------------------------------------------------------------
    --                                   DEBUG & RESET                                   --
    ---------------------------------------------------------------------------------------
    resetButton = {
      type = "execute",
      name = "Default",
      desc = "Resets Combat Mode's settings to their default values.",
      confirmText = CM.METADATA["TITLE"]
        .. "\n\n|cffcfcfcfResetting Combat Mode's options to their default will force a |cffE52B50UI Reload|r.|r \n\n|cffffd700Proceed?|r",
      confirm = true,
      width = 0.7,
      func = function()
        CM:OnResetDB()
      end,
      order = 0,
    },
    spacing = Spacing(1.6, 0.1),
    silenceAlertsToggle = {
      type = "toggle",
      name = "Silence Alerts",
      desc = "Stops Combat Mode from printing alert messages in the chat window after loading screens.",
      width = 0.7,
      set = function(_, value)
        CM.DB.global.silenceAlerts = value
      end,
      get = function()
        return CM.DB.global.silenceAlerts
      end,
      order = 0.2,
    },
    debugModeToggle = {
      type = "toggle",
      name = "Debug Mode",
      desc = "Enables the printing of state logs in the chat window to assist with development.",
      width = 0.7,
      set = function(_, value)
        CM.DB.global.debugMode = value
      end,
      get = function()
        return CM.DB.global.debugMode
      end,
      order = 0.3,
    },
    ---------------------------------------------------------------------------------------
    --                                   LOGO & ABOUT                                    --
    ---------------------------------------------------------------------------------------
    header = Header("about", 1),
    spacing2 = Spacing("full", 1.1),
    logoImage = {
      type = "description",
      name = " ",
      width = 0.5,
      image = CM.Constants.Logo,
      imageWidth = 64,
      imageHeight = 64,
      imageCoords = { 0, 1, 0, 1 },
      order = 1.2,
    },
    aboutDescription = {
      type = "description",
      name = CM.METADATA["NOTES"],
      fontSize = "medium",
      width = 3.1,
      order = 1.3,
    },
    spacing3 = Spacing("full", 1.4),
    ---------------------------------------------------------------------------------------
    --                                     FEATURES                                      --
    ---------------------------------------------------------------------------------------
    featuresHeader = {
      type = "description",
      name = "|cffffd700Features:|r",
      order = 2,
      fontSize = "medium",
    },
    featuresList = {
      type = "description",
      name = "|cff909090• |cffE52B50Mouse Look Camera|r - Rotate the player character's view with the camera without having to perpetually hold right click. \n• |cff00FFFFReticle Targeting|r - Enable users to target units by simply aiming the reticle at them, as well as allowing proper use of |cffcfcfcf@mouseover|r and |cffcfcfcf@cursor|r macro decorators in combination with the |cff00FFFFCrosshair|r. \n• |cffB47EDEMouse Click Casting|r - When Mouse Look is enabled, frees your mouse clicks so you can cast up to 8 skills with them. \n• |cffffd700Cursor Unlock|r - Automatically releases the cursor when opening interface panels like bags, map, character panel, etc. \n• |cff00FF7FHealing Radial|r - Radial menu for quickly casting helpful spells at party members.\n\n",
      order = 3,
    },
    versionNumber = {
      type = "description",
      name = "|cffffffffVersion:|r " .. "|cff00ff00" .. CM.METADATA["VERSION"] .. "|r\n\n",
      order = 3.2,
    },
    changelogButton = {
      type = "execute",
      name = "CHANGELOG",
      desc = "Opens the changelog in a scrollable window.",
      width = 0.7,
      func = function()
        CM.Config.ShowChangelog()
      end,
      order = 3.22,
    },
    spacing333 = Spacing("full", 3.23),
    authorsList = {
      type = "description",
      name = "|cffffffffAuthors:|r " .. "|cffcfcfcf" .. CM.METADATA["AUTHOR"] .. "|r\n",
      order = 3.3,
    },
    contributorsList = {
      type = "description",
      name = "|cffffffffContributors:|r "
        .. "|cffcfcfcf"
        .. CM.METADATA["X-CONTRIBUTORS"]
        .. "|r\n\n",
      order = 3.4,
    },
    curse = {
      name = "Download From:",
      desc = CM.METADATA["X-CURSE"],
      type = "input",
      width = 2,
      order = 4,
      get = function()
        return CM.METADATA["X-CURSE"]
      end,
    },
    spacing4 = Spacing(0.4, 4.1),
    discord = {
      name = "Feedback & Support:",
      desc = CM.METADATA["X-DISCORD"],
      type = "input",
      width = 1.1,
      order = 5,
      get = function()
        return CM.METADATA["X-DISCORD"]
      end,
    },
    spacing5 = Spacing("full", 5.1),
  },
}
