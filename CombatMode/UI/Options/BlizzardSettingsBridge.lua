---------------------------------------------------------------------------------------
--  UI/Options/BlizzardSettingsBridge.lua — OPTIONS — Esc → AddOns bridge
---------------------------------------------------------------------------------------
--  What it does: Registers a minimal Blizzard Settings category whose only control is
--  "Open Options", which calls CM.OpenOptions and hides the settings panel. Keeps Combat
--  Mode discoverable from Esc → Options → AddOns without hosting settings there.
--  Architecture / how it works:
--    • Category display name uses TOC Title / cmtitle texture markup.
--    • Not a settings host — all real config lives in CombatModeOptionsFrame.
--  Does not: Duplicate tab controls or persist settings.
--  Related: UI/Options/OptionsPanel.lua, Core/Runtime/Runtime.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local DynamicResizeButton_Resize = _G.DynamicResizeButton_Resize
local HideUIPanel = _G.HideUIPanel
local Settings = _G.Settings
local WHITE_FONT_COLOR = _G.WHITE_FONT_COLOR

local C_AddOns = _G.C_AddOns
local C_XMLUtil = _G.C_XMLUtil

-- Lua stdlib
local type = _G.type

-- Same wordmark markup as CombatMode.toc Title (AddOns list + settings sidebar).
local CATEGORY_NAME = "|A:::|a|TInterface\\Addons\\CombatMode\\assets\\cmtitle:22:95|t"

local function CategoryDisplayName()
  local fromToc = CM.METADATA and CM.METADATA["TITLE"]
  if type(fromToc) == "string" and fromToc ~= "" then
    return fromToc
  end
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    local title = C_AddOns.GetAddOnMetadata("CombatMode", "Title")
    if type(title) == "string" and title ~= "" then
      return title
    end
  end
  return CATEGORY_NAME
end

local function WrapWhite(text)
  if WHITE_FONT_COLOR and WHITE_FONT_COLOR.WrapTextInColorCode then
    return WHITE_FONT_COLOR:WrapTextInColorCode(text)
  end
  return text
end

local function RegisterBlizzardAddOnCategory()
  if
    not Settings
    or not Settings.RegisterCanvasLayoutCategory
    or not Settings.RegisterAddOnCategory
  then
    return
  end

  local displayName = CategoryDisplayName()
  local optionsFrame = CreateFrame("Frame")

  -- One top-down chain from above center; no mixed absolute CENTER anchors.
  local titleArt = optionsFrame:CreateTexture(nil, "ARTWORK")
  titleArt:SetTexture(
    (CM.Constants and CM.Constants.Title) or "Interface\\AddOns\\CombatMode\\assets\\cmtitle"
  )
  titleArt:SetSize(320, 74)
  titleArt:SetPoint("TOP", optionsFrame, "CENTER", 0, 130)

  local version = (CM.METADATA and CM.METADATA["VERSION"])
    or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(
      "CombatMode",
      "Version"
    ))
    or ""
  local versionText
  if version ~= "" then
    versionText = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    versionText:SetPoint("TOP", titleArt, "BOTTOM", 0, -16)
    versionText:SetText(WrapWhite("Version: " .. version))
  end

  local instructions = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  instructions:SetPoint("TOP", versionText or titleArt, "BOTTOM", 0, -28)
  instructions:SetText(WrapWhite("Use the button below to open Combat Mode options."))

  local slashHint = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  slashHint:SetPoint("TOP", instructions, "BOTTOM", 0, -12)
  slashHint:SetText("You can also type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r in chat.")

  local template = "SharedButtonLargeTemplate"
  if C_XMLUtil and C_XMLUtil.GetTemplateInfo and not C_XMLUtil.GetTemplateInfo(template) then
    template = "UIPanelDynamicResizeButtonTemplate"
  end
  local button = CreateFrame("Button", nil, optionsFrame, template)
  button:SetText("Open Options")
  button.padding = 40
  if DynamicResizeButton_Resize then
    DynamicResizeButton_Resize(button)
  end
  button:SetPoint("TOP", slashHint, "BOTTOM", 0, -28)
  button:SetScale(1.5)
  button:SetScript("OnClick", function()
    -- Close Esc → Options so only CombatModeOptionsFrame remains.
    local settingsPanel = _G.SettingsPanel
    if settingsPanel and settingsPanel:IsShown() then
      if HideUIPanel then
        HideUIPanel(settingsPanel)
      else
        settingsPanel:Hide()
      end
    end
    if CM.OpenOptions then
      CM.OpenOptions()
    end
  end)

  optionsFrame.OnCommit = function() end
  optionsFrame.OnDefault = function() end
  optionsFrame.OnRefresh = function() end

  local category = Settings.RegisterCanvasLayoutCategory(optionsFrame, displayName)
  category.ID = displayName
  Settings.RegisterAddOnCategory(category)
end

RegisterBlizzardAddOnCategory()
