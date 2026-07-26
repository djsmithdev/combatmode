---------------------------------------------------------------------------------------
--  UI/Options/BlizzardSettingsBridge.lua — OPTIONS — Blizzard AddOns panel shortcut
---------------------------------------------------------------------------------------
--  Registers a minimal Escape → Options → AddOns → Combat Mode canvas category whose
--  only control is a button that opens the standalone Combat Mode options window
--  (CM.OpenOptions) and closes SettingsPanel so the Blizzard Esc → Options UI does
--  not stay stacked behind it. Same pattern as Chattynator: settings still live in
--  CombatModeOptionsFrame; this is a discoverability bridge, not a settings host.
--
--  Related: UI/Options/OptionsPanel.lua (CM.OpenOptions).
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

  local previous = titleArt
  local version = (CM.METADATA and CM.METADATA["VERSION"])
    or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(
      "CombatMode",
      "Version"
    ))
    or ""
  if version ~= "" then
    local versionText = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    versionText:SetPoint("TOP", previous, "BOTTOM", 0, -16)
    versionText:SetText(WrapWhite("Version: " .. version))
    previous = versionText
  end

  local instructions = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  instructions:SetPoint("TOP", previous, "BOTTOM", 0, -28)
  instructions:SetText(WrapWhite("Use the button below to open Combat Mode options."))
  previous = instructions

  local slashHint = optionsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  slashHint:SetPoint("TOP", previous, "BOTTOM", 0, -12)
  slashHint:SetText("You can also type |cff69ccf0/cm|r or |cff69ccf0/combatmode|r in chat.")
  previous = slashHint

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
  button:SetPoint("TOP", previous, "BOTTOM", 0, -28)
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
