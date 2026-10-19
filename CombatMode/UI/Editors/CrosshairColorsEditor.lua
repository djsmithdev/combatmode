---------------------------------------------------------------------------------------
--  UI/Editors/CrosshairColorsEditor.lua — EDITOR — crosshair reaction colors
---------------------------------------------------------------------------------------
--  What it does: Standalone editor (CM.OpenCrosshairColorsEditor) with reaction
--  tabs and an embedded color picker (no modal-on-modal). Live-updates crosshair tints.
--  Architecture / how it works:
--    • Tabs: hostile, friendly_npc, friendly_player, object, base.
--    • DB.global.crosshairReactionColors[state] = { r, g, b, a }; Reset Color clears one override.
--    • Opens beside CombatModeOptionsFrame when visible; combat-guarded.
--  Does not: Edit mounted/focus colors (mounted fixed; focus → hostile at runtime).
--  Related: Core/Crosshair/Crosshair.lua, UI/Options/ColorPickerDialog.lua,
--  UI/Options/Tabs/TabCrosshair.lua, Constants/Assets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown

local UI = CM.UI
local C = UI.Colors
local M = CM.METADATA

local REACTION_STATES = {
  { key = "hostile", tab = "Hostile" },
  { key = "friendly_npc", tab = "NPC" },
  { key = "friendly_player", tab = "Player" },
  { key = "object", tab = "Object" },
  { key = "base", tab = "Base" },
}

local TAB_BAR_W = 330
local EDITOR_W = TAB_BAR_W + 32
local EDITOR_H = 398
local PICKER_CARD_PAD = 10
local RESET_BTN_H = UI.Sizes.control
local PICKER_BODY_H = UI.PickerBodyHeight

local window
local picker
local tabButtons = {}
local activeKey = "hostile"
local switchingTab

--- Re-tints everything that previews the reaction colors: the Appearance rows' tiles and the
--- Crosshair Textures editor (cards + presets).
local function RefreshColorPreviews()
  if UI.Options and UI.Options.Sync then
    UI.Options.Sync()
  end
  if CM.RefreshCrosshairTextureEditor then
    CM.RefreshCrosshairTextureEditor()
  end
end

local function SetReactionColor(key, r, g, b, a)
  local globalDb = CM.DB.global
  globalDb.crosshairReactionColors = globalDb.crosshairReactionColors or {}
  globalDb.crosshairReactionColors[key] = { r, g, b, a }
  CM.RefreshCrosshairAppearance()
  RefreshColorPreviews()
end

local function UpdateTabStyles()
  for _, state in ipairs(REACTION_STATES) do
    local btn = tabButtons[state.key]
    if btn then
      btn:cmSetTabSelected(state.key == activeKey)
    end
  end
end

local function SelectReactionTab(key)
  if switchingTab or not picker then
    return
  end
  activeKey = key
  UpdateTabStyles()
  switchingTab = true
  local c = CM.GetCrosshairReactionColor(key)
  picker.SetColor(c[1], c[2], c[3], c[4])
  switchingTab = false
end

local function MakeTabButton(parent, state, index)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(64, 32)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * 66, 0)

  local label = UI.CreateFontString(btn, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  label:SetPoint("CENTER", btn, "CENTER", 4, 0)
  label:SetText(state.tab)
  btn.label = label

  -- Same look as the sidebar tabs (selected pill, orange capsule marker, hover wash).
  UI.StyleTab(btn, label, 18)

  btn:SetScript("OnClick", function()
    SelectReactionTab(state.key)
  end)

  tabButtons[state.key] = btn
  return btn
end

local function Build()
  window = UI.CreateBareWindow(
    "CombatModeCrosshairColorsEditor",
    M["TITLE"] .. " - Reaction Colors",
    EDITOR_W,
    EDITOR_H
  )
  window:Hide()

  local content = CreateFrame("Frame", nil, window)
  content:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -44)
  content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 16)

  local desc =
    UI.CreateFontString(content, "OVERLAY", UI.Fonts.sectionDesc, "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  desc:SetWidth(EDITOR_W - 48)
  desc:SetJustifyH("LEFT")
  desc:SetWordWrap(true)
  desc:SetText(
    "Select a tab to customize the color and alpha of the crosshair when targeting different types of units.\n\n"
      .. "• "
      .. UI.AccentWrap("Target Lock")
      .. " and "
      .. UI.AccentWrap("Cast Feedback")
      .. " animations use the Hostile color."
      .. "\n• Inactive crosshair states use the Base style."
  )
  desc:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

  local tabBar = CreateFrame("Frame", nil, content)
  tabBar:SetSize(TAB_BAR_W, 26)
  tabBar:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)

  for i, state in ipairs(REACTION_STATES) do
    MakeTabButton(tabBar, state, i)
  end

  -- Hairline under the reaction tabs (same treatment as other segmented option hosts).
  local sepGap = 8
  local sep = UI.CreateLine(content, false, C.divider, "ends")
  sep:SetHeight(1)
  sep:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -sepGap)
  sep:SetPoint("TOPRIGHT", tabBar, "BOTTOMRIGHT", 0, -sepGap)

  local pickerCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  pickerCard:SetSize(
    TAB_BAR_W,
    PICKER_CARD_PAD + PICKER_BODY_H + PICKER_CARD_PAD + RESET_BTN_H + PICKER_CARD_PAD
  )
  pickerCard:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -sepGap)
  UI.StyleRounded(pickerCard, C.cardBg, C.cardBorder, UI.Radius.button)
  pickerCard:cmSetBorderGradient(C.controlBorderTop, C.controlBorderBottom)
  pickerCard:SetClipsChildren(true)

  local pickerHost = CreateFrame("Frame", nil, pickerCard)
  pickerHost:SetPoint("TOPLEFT", pickerCard, "TOPLEFT", PICKER_CARD_PAD, -PICKER_CARD_PAD)
  pickerHost:SetPoint("TOPRIGHT", pickerCard, "TOPRIGHT", -PICKER_CARD_PAD, -PICKER_CARD_PAD)
  pickerHost:SetHeight(PICKER_BODY_H)
  pickerHost:SetClipsChildren(true)

  picker = UI.CreateEmbeddedColorPicker(pickerHost, {
    pollParent = window,
    onChange = function(r, g, b, a)
      if switchingTab or not activeKey then
        return
      end
      SetReactionColor(activeKey, r, g, b, a)
    end,
  })
  picker.LayoutInParent()

  local resetBtn = CreateFrame("Button", nil, pickerCard)
  resetBtn:SetHeight(RESET_BTN_H)
  resetBtn:SetPoint("BOTTOMLEFT", pickerCard, "BOTTOMLEFT", PICKER_CARD_PAD, PICKER_CARD_PAD)
  resetBtn:SetPoint("BOTTOMRIGHT", pickerCard, "BOTTOMRIGHT", -PICKER_CARD_PAD, PICKER_CARD_PAD)
  UI.StyleControl(resetBtn)
  local resetText = UI.CreateFontString(resetBtn, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  resetText:SetPoint("CENTER")
  resetText:SetText("Reset to Default")
  UI.WireControlHover(resetBtn, resetText)
  resetBtn:SetScript("OnClick", function()
    if activeKey then
      CM.ResetCrosshairReactionColor(activeKey)
      RefreshColorPreviews()
      SelectReactionTab(activeKey)
    end
  end)

  window:SetScript("OnShow", function()
    picker.LayoutInParent()
    picker.StartPolling()
    SelectReactionTab(activeKey)
  end)
  window:SetScript("OnHide", function()
    picker.StopPolling()
  end)
end

function CM.OpenCrosshairColorsEditor()
  if InCombatLockdown and InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open this editor while in combat.|r")
    return
  end

  if not window then
    Build()
  end

  local anchor = CM.GetOptionsFrame and CM.GetOptionsFrame()
  window:ClearAllPoints()
  if anchor and anchor:IsShown() then
    window:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 12, 0)
  else
    window:SetPoint("CENTER")
  end

  window:Show()
  window:Raise()
end
