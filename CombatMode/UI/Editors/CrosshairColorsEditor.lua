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
local EDITOR_H = 370
local PICKER_CARD_PAD = 10
local RESET_BTN_H = 28
local PICKER_BODY_H = UI.PickerBodyHeight

local window
local picker
local tabButtons = {}
local activeKey = "hostile"
local switchingTab

local function SetReactionColor(key, r, g, b, a)
  local globalDb = CM.DB.global
  globalDb.crosshairReactionColors = globalDb.crosshairReactionColors or {}
  globalDb.crosshairReactionColors[key] = { r, g, b, a }
  CM.RefreshCrosshairAppearance()
end

local function UpdateTabStyles()
  for _, state in ipairs(REACTION_STATES) do
    local btn = tabButtons[state.key]
    if btn then
      local selected = state.key == activeKey
      if selected then
        btn:cmSetFill(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
        btn.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
      else
        btn:cmSetFill(0, 0, 0, 0)
        btn.label:SetTextColor(0.56, 0.56, 0.56)
      end
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
  btn:SetSize(64, 26)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * 66, 0)
  UI.StyleRounded(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

  local label = UI.CreateFontString(btn, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  label:SetPoint("CENTER")
  label:SetText(state.tab)
  btn.label = label

  btn:SetScript("OnClick", function()
    SelectReactionTab(state.key)
  end)
  btn:SetScript("OnEnter", function(self)
    if state.key ~= activeKey then
      self:cmSetFill(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
    end
  end)
  btn:SetScript("OnLeave", function(self)
    if state.key ~= activeKey then
      self:cmSetFill(0, 0, 0, 0)
    end
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

  local desc = UI.CreateFontString(content, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
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

  local pickerCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  pickerCard:SetSize(
    TAB_BAR_W,
    PICKER_CARD_PAD + PICKER_BODY_H + PICKER_CARD_PAD + RESET_BTN_H + PICKER_CARD_PAD
  )
  pickerCard:SetPoint("TOPLEFT", tabBar, "BOTTOMLEFT", 0, -12)
  UI.StyleRounded(pickerCard, C.cardBg, C.cardBorder, UI.Radius.card)
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
  UI.StylePill(resetBtn, { 0.16, 0.16, 0.16, 1 }, { 0, 0, 0, 0 })
  local resetText = UI.CreateFontString(resetBtn, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  resetText:SetPoint("CENTER")
  resetText:SetText("Reset Color")
  resetText:SetTextColor(C.text[1], C.text[2], C.text[3])
  resetBtn:SetScript("OnEnter", function(self)
    self:cmSetFill(0.26, 0.26, 0.26, 1)
    resetText:SetTextColor(1, 1, 1)
  end)
  resetBtn:SetScript("OnLeave", function(self)
    self:cmSetFill(0.16, 0.16, 0.16, 1)
    resetText:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  resetBtn:SetScript("OnClick", function()
    if activeKey then
      CM.ResetCrosshairReactionColor(activeKey)
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
