---------------------------------------------------------------------------------------
--  Config/TargetingMacroPrelinesEditor.lua — Targeting macro prelines editor (AceConfig)
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Description = U.Spacing, U.Description

local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

-- WoW API
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI
local UIParent = _G.UIParent
local CLOSE = _G.CLOSE

-- Lua stdlib
local strtrim = _G.strtrim
local ipairs = _G.ipairs
local math = _G.math

local APP_NAME = "CombatMode_TargetingMacroPrelines"
local registered = false

local function NormalizeInput(value)
  value = type(value) == "string" and strtrim(value) or ""
  if value == "" then
    return nil
  end
  return value
end

local function EnsureRegistered()
  if registered then
    return
  end

  local defaults = (CM.TargetingMacroPrelinesDefaults or {})

  local options = {
    name = CM.METADATA["TITLE"] .. " - Targeting Macro Prelines",
    type = "group",
    args = {
      description = Description("prelines", 2),
      prelineAny = {
        type = "input",
        multiline = 2,
        name = "Preline |cff00ff00(Any unit)|r",
        desc = "Used when |cff909090Only Allow Reticle To Target Enemies|r is |cffE52B50OFF|r.",
        width = "full",
        order = 3,
        hidden = function()
          return CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly == true
        end,
        get = function()
          return (CM.DB and CM.DB.global and CM.DB.global.targetingMacroPrelineAnyOverride)
            or defaults.any
            or ""
        end,
        set = function(_, value)
          CM.DB.global.targetingMacroPrelineAnyOverride = NormalizeInput(value)
        end,
      },
      prelineEnemy = {
        type = "input",
        multiline = 2,
        name = "Preline |cffE52B50(Enemies only)|r",
        desc = "Used when |cff909090Only Allow Reticle To Target Enemies|r is |cff00ff00ON|r.",
        width = "full",
        order = 4,
        hidden = function()
          return not (CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly == true)
        end,
        get = function()
          return (CM.DB and CM.DB.global and CM.DB.global.targetingMacroPrelineEnemyOverride)
            or defaults.enemy
            or ""
        end,
        set = function(_, value)
          CM.DB.global.targetingMacroPrelineEnemyOverride = NormalizeInput(value)
        end,
      },
      spacer = Spacing("full", 5),
      devnote = {
        type = "group",
        name = "|cffffd700Developer Note|r",
        order = 5.1,
        inline = true,
        args = {
          crosshairNote = {
            type = "description",
            name = "|cff909090Knowing the basics of |cffB47EDEMacros|r and their |cffB47EDEConditionals|r is essential for modifying the |cff00FFFFReticle Targeting|r prelines.|r \n\n|cffFF5050Be cautious when editing these values as you could potentially break the functionality of |cff00FFFFReticle Targeting|r and |cffcc00ffTarget Lock|r.|r",
            order = 1,
          },
          wowpediaApi = {
            name = "You can find the documentation for Macros here:",
            desc = "warcraft.wiki.gg/wiki/Making_a_macro",
            type = "input",
            width = 1.75,
            order = 2,
            get = function()
              return "warcraft.wiki.gg/wiki/Making_a_macro"
            end,
          },
          spacer = Spacing(0.2, 2.1),
          wowpediaApi2 = {
            name = "You can find the documentation for Conditionals here:",
            desc = "warcraft.wiki.gg/wiki/Macro_conditionals",
            type = "input",
            width = 1.75,
            order = 3,
            get = function()
              return "warcraft.wiki.gg/wiki/Macro_conditionals"
            end,
          },
        },
      },
      reset = {
        type = "execute",
        name = "Reset to Defaults",
        desc = "Clear overrides and revert back to CombatMode defaults.",
        width = 1.4,
        order = 6,
        confirmText = CM.METADATA["TITLE"]
          .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
        confirm = true,
        func = function()
          CM.DB.global.targetingMacroPrelineAnyOverride = nil
          CM.DB.global.targetingMacroPrelineEnemyOverride = nil
          ReloadUI()
        end,
      },
      spacer2 = Spacing(1.05, 6.1),
      applyReload = {
        type = "execute",
        name = "Apply Changes",
        desc = "Reload UI to apply changes.",
        width = 1.4,
        order = 7,
        confirmText = CM.METADATA["TITLE"]
          .. "\n\n|cffcfcfcfA |cffE52B50UI Reload|r is required when making changes to |cff00FFFFReticle Targeting|r.|r \n\n|cffffd700Proceed?|r",
        confirm = true,
        func = function()
          ReloadUI()
        end,
      },
    },
  }

  AceConfig:RegisterOptionsTable(APP_NAME, options)
  registered = true
end

function CM.OpenTargetingMacroPrelinesEditor()
  if InCombatLockdown and InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open this editor while in combat.|r")
    return
  end

  EnsureRegistered()
  AceConfigDialog:SetDefaultSize(APP_NAME, 690, 400)
  AceConfigDialog:Open(APP_NAME)

  local widget = AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP_NAME]
  if not (widget and widget.frame) then
    return
  end

  -- Position the editor to the right of the Settings panel (when possible).
  do
    local anchor = _G.SettingsPanel or _G.InterfaceOptionsFrame
    if anchor and anchor.GetRight and anchor.GetTop then
      local status = AceConfigDialog:GetStatusTable(APP_NAME)
      local desiredLeft = (anchor:GetRight() or 0) + 12
      local desiredTop = (anchor:GetTop() or 0) - 18

      -- Clamp so it stays on-screen.
      if UIParent and UIParent.GetWidth then
        local uiW = UIParent:GetWidth() or 0
        local frameW = widget.frame:GetWidth() or (status.width or 700)
        local maxLeft = math.max(uiW - frameW - 12, 0)
        desiredLeft = math.min(desiredLeft, maxLeft)
      end

      status.left = desiredLeft
      status.top = desiredTop
      if widget.ApplyStatus then
        widget:ApplyStatus()
      end
    end
  end

  -- Replace the bottom-right Close button with a standard top-right X.
  do
    if not widget.frame.cmCloseX then
      local children = { widget.frame:GetChildren() }
      for _, child in ipairs(children) do
        if
          child
          and child.GetObjectType
          and child:GetObjectType() == "Button"
          and child.GetText
        then
          if child:GetText() == CLOSE then
            child:Hide()
            child:EnableMouse(false)
            break
          end
        end
      end

      local x = _G.CreateFrame("Button", nil, widget.frame, "UIPanelCloseButton")
      x:SetPoint("TOPRIGHT", widget.frame, "TOPRIGHT", -5, -5)
      widget.frame.cmCloseX = x
    end
  end
end
