---------------------------------------------------------------------------------------
--  UI/Editors/CrosshairTextureEditor.lua — EDITOR — crosshair texture browser
---------------------------------------------------------------------------------------
--  What it does: Standalone editor (CM.OpenCrosshairTextureEditor) where the player picks the
--  Inactive (Base) and Active texture of the crosshair separately from a thumbnail grid of every
--  catalog texture, or applies a curated preset pair in one click. Serves both the main
--  Appearance (Crosshair tab) and the Situational Appearance (Advanced tab).
--  Architecture / how it works:
--    • Target "main" writes DB.global.crosshairAppearance, "situational" writes
--      crosshairSituationalAppearance; both store the table built by
--      CM.Constants.MakeCrosshairAppearance(baseId, activeId) (Constants/Assets.lua).
--    • Slots row (Inactive / Active cards) chooses which slot a grid click assigns. Presets
--      set both slots to a curated pair. Each card has an eye button that hides just that
--      slot (id "none", empty path); situational with both slots hidden stores
--      CrosshairSituationalHidden (the whole reticle is suppressed).
--    • Main target also shows Mounted and Disabled (Target Lock) cards
--      (DB.global.crosshairMountedId / crosshairTargetLockId), picked independently. Same eye
--      button and grid behavior; presets and Reset to Default set both back to the Dot.
--    • Grid: one scroll frame of lightweight cells (texture + tinted background, no rounded
--      9-slice per cell) built once from CM.Constants.CrosshairTextures on first open.
--    • Every change calls CM.CreateCrosshair / CM.RefreshCrosshairAppearance (the Crosshair tab
--      live preview shows it) and UI.Options.Sync so the Appearance rows' thumbnails update.
--    • Opens beside CombatModeOptionsFrame when visible; combat-guarded.
--  Does not: Own texture data (Constants/Assets.lua), render the reticle, or edit reaction
--  colors (UI/Editors/CrosshairColorsEditor.lua; thumbnails here use those tints).
--  Related: UI/Options/Tabs/TabCrosshair.lua, UI/Options/Tabs/TabAdvanced.lua,
--  UI/Options/Widgets.lua (row button `previews`), Core/Crosshair/Animations.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown

-- Lua stdlib
local floor = _G.math.floor
local ipairs = _G.ipairs
local pairs = _G.pairs
local tsort = _G.table.sort

local UI = CM.UI
local C = UI.Colors
local M = CM.METADATA

local CONTENT_W = 348
local EDITOR_W = CONTENT_W + 32
local EDITOR_H = 560
local SLOT_H = 64
local PRESET_COLS = 5
local PRESET_GAP = 6
local PRESET_W = floor((CONTENT_W - (PRESET_COLS - 1) * PRESET_GAP) / PRESET_COLS)
local PRESET_H = 40
local CELL = 38
local CELL_GAP = 4
local SCROLL_W = 338
local RESET_H = UI.Sizes.control
local EYE_SIZE = 24
local IDLE_H = 52

local window
local slotCards = {}
local presetButtons = {}
local cells = {}
local slotsHost

local target = "main"
local activeSlot = "base"
local rememberedId = {} -- last visible texture id per slot, restored by the eye button
local NONE = CM.Constants.CrosshairNoneId

local function DbKey()
  return target == "situational" and "crosshairSituationalAppearance" or "crosshairAppearance"
end

--- Current selection: baseId, activeId ("none" for a hidden slot).
local function GetState()
  local saved = CM.DB.global[DbKey()]
  local appearance = CM.Constants.NormalizeCrosshairAppearance(saved)
  if appearance and appearance.Hidden then
    return NONE, NONE
  end
  if not appearance then
    if target == "situational" then
      return NONE, NONE
    end
    appearance = CM.Constants.CrosshairTextureObj.Default
  end
  return appearance.BaseId, appearance.ActiveId
end

local Refresh

--- Re-reads the Appearance rows' thumbnails on the options tabs.
local function SyncOptions()
  if UI.Options and UI.Options.Sync then
    UI.Options.Sync()
  end
end

local function Commit(appearance)
  CM.DB.global[DbKey()] = appearance
  if target == "main" then
    CM.CreateCrosshair()
  elseif CM.RefreshCrosshairAppearance then
    CM.RefreshCrosshairAppearance()
  end
  SyncOptions()
  Refresh()
end

local function SetPair(baseId, activeId)
  if target == "situational" and baseId == NONE and activeId == NONE then
    Commit(CM.Constants.CrosshairSituationalHidden)
    return
  end
  local appearance = CM.Constants.MakeCrosshairAppearance(baseId, activeId)
  if appearance then
    Commit(appearance)
  end
end

-- Idle slots (main target only): each has its own DB key, picked independently.
local IDLE_KEYS = { mounted = "crosshairMountedId", lock = "crosshairTargetLockId" }

--- Texture id of an idle slot, "none" when hidden.
local function GetIdleId(slot)
  local id = CM.DB.global[IDLE_KEYS[slot]]
  if not CM.Constants.CrosshairTextureById[id] then
    id = CM.Constants.CrosshairIdleDefaultId
  end
  return id
end

local function SetIdle(slot, id)
  CM.DB.global[IDLE_KEYS[slot]] = id
  CM.CreateCrosshair()
  CM.RefreshCrosshairAppearance()
  SyncOptions()
  Refresh()
end

local function SlotId(slot)
  if IDLE_KEYS[slot] then
    return GetIdleId(slot)
  end
  local baseId, activeId = GetState()
  return slot == "base" and baseId or activeId
end

--- Assigns a texture id (or NONE) to one slot, leaving the others as they are.
local function SetSlot(slot, id)
  if IDLE_KEYS[slot] then
    SetIdle(slot, id)
    return
  end
  local baseId, activeId = GetState()
  if slot == "base" then
    baseId = id
  else
    activeId = id
  end
  SetPair(baseId, activeId)
end

--- Eye button: hides one slot, or brings back its last texture (the default's when none is known).
local function ToggleSlotHidden(slot)
  local current = SlotId(slot)
  if current ~= NONE then
    rememberedId[slot] = current
    SetSlot(slot, NONE)
    return
  end
  local fallback = CM.Constants.CrosshairIdleDefaultId
  if not IDLE_KEYS[slot] then
    local default = CM.Constants.CrosshairTextureObj.Default
    fallback = slot == "base" and default.BaseId or default.ActiveId
  end
  SetSlot(slot, rememberedId[slot] or fallback)
end

--- Mounted and Disabled go back to the Dot (every preset and Reset to Default pair with it).
local function ResetIdleSlots()
  for _, key in pairs(IDLE_KEYS) do
    CM.DB.global[key] = CM.Constants.CrosshairIdleDefaultId
  end
end

local function Tint(texture, state)
  local c = CM.GetCrosshairReactionColor(state)
  texture:SetVertexColor(c[1], c[2], c[3], 1)
end

-- Eye button art: pack textures (visible / hidden state).
local function EyeIcon(isHidden)
  return CM.Constants.CrosshairTextureById[isHidden and "pack-117" or "pack-115"].path
end

Refresh = function()
  if not window then
    return
  end
  local baseId, activeId = GetState()
  local byId = CM.Constants.CrosshairTextureById

  local mainTarget = target == "main"
  slotsHost:SetHeight(mainTarget and (SLOT_H + IDLE_H + 8) or SLOT_H)

  for slot, card in pairs(slotCards) do
    local id = baseId
    if slot == "active" then
      id = activeId
    elseif IDLE_KEYS[slot] then
      id = GetIdleId(slot)
      card.button:SetShown(mainTarget)
    end
    local entry = id and byId[id]
    local isHidden = id == NONE
    card.texture:SetShown(entry ~= nil and not isHidden)
    if entry and not isHidden then
      card.texture:SetTexture(entry.path)
      Tint(card.texture, slot == "active" and "hostile" or "base")
    end
    card.button:cmSetTabSelected(slot == activeSlot)
    card.eye:SetIcon(EyeIcon(isHidden))
  end

  local curId = baseId
  local otherId = activeId
  if activeSlot == "active" then
    curId, otherId = activeId, baseId
  elseif IDLE_KEYS[activeSlot] then
    curId, otherId = GetIdleId(activeSlot), nil
  end
  for _, cell in ipairs(cells) do
    local a = 0
    if cell.id == curId then
      a = 0.45
    elseif cell.id == otherId then
      a = 0.18
    end
    cell.selectedAlpha = a
    if a > 0 then
      cell.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], a)
    else
      cell.bg:SetColorTexture(C.cardBg[1], C.cardBg[2], C.cardBg[3], 1)
    end
  end

  for _, entry in ipairs(presetButtons) do
    Tint(entry.inactive, "base")
    Tint(entry.active, "hostile")
    -- A preset is a full set: Inactive/Active pair plus the Dot for Mounted and Disabled (main).
    local selected = entry.preset.BaseId == baseId
      and entry.preset.ActiveId == activeId
      and (
        not mainTarget
        or (
          GetIdleId("mounted") == CM.Constants.CrosshairIdleDefaultId
          and GetIdleId("lock") == CM.Constants.CrosshairIdleDefaultId
        )
      )
    if selected then
      entry.button:cmSetBorderGradient(C.accentTop, C.accentBottom)
    else
      entry.button:cmSetBorderGradient(C.controlBorderTop, C.controlBorderBottom)
    end
  end
end

local SLOT_STATE_NAMES = {
  base = "inactive",
  active = "active",
  mounted = "mounted",
  lock = "disabled",
}
local SLOT_HIDE_HINTS = {
  base = "Nothing is drawn while you are not aiming at anything.",
  active = "Nothing is drawn while you are aiming at a unit or object.",
  mounted = "Nothing is drawn while you are mounted.",
  lock = "Nothing is drawn while Target Lock holds the reticle.",
}

-- Caption under each card title: when that state applies (the preview already shows the texture).
local SLOT_DESCRIPTIONS = {
  base = "Not aiming at anything",
  active = "Aiming at a unit or object",
  mounted = "While you are mounted",
  lock = "While Target Lock holds",
}

local function MakeSlotCard(parent, slot, label, anchorX, anchorY, width, height)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, height)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", anchorX, anchorY)

  local title = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  title:SetPoint("TOPLEFT", button, "TOPLEFT", 20, IDLE_KEYS[slot] and -10 or -14)
  title:SetText(label)
  UI.StyleTab(button, title, height - 20)

  local name = UI.CreateFontString(button, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  name:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  name:SetWidth(width - 20 - 30 - (height - 22) - 8) -- stops before the texture preview
  name:SetJustifyH("LEFT")
  name:SetWordWrap(true)
  name:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  name:SetText(SLOT_DESCRIPTIONS[slot])

  local texture = button:CreateTexture(nil, "ARTWORK")
  local textureSize = height - 22
  texture:SetSize(textureSize, textureSize)
  texture:SetPoint("RIGHT", button, "RIGHT", -30, -2)

  local eyeButton = CreateFrame("Button", nil, button)
  eyeButton:SetSize(EYE_SIZE, EYE_SIZE)
  eyeButton:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
  eyeButton:SetFrameLevel(button:GetFrameLevel() + 5)
  local eye = UI.CreateIconBadge(eyeButton, EYE_SIZE, EyeIcon(false))
  eyeButton:SetScript("OnEnter", function()
    eye:SetHover(true)
  end)
  eyeButton:SetScript("OnLeave", function()
    eye:SetHover(false)
  end)
  eyeButton:SetScript("OnClick", function()
    ToggleSlotHidden(slot)
  end)
  UI.AttachTooltip(eyeButton, function()
    local state = SLOT_STATE_NAMES[slot]
    if SlotId(slot) == NONE then
      return {
        title = "Show the " .. state .. " crosshair",
        text = "Brings back the texture you had before hiding it.",
        dim = true,
      }
    end
    return {
      title = "Hide the " .. state .. " crosshair",
      text = SLOT_HIDE_HINTS[slot],
      dim = true,
    }
  end)

  button:SetScript("OnClick", function()
    activeSlot = slot
    Refresh()
  end)

  slotCards[slot] = { button = button, texture = texture, eye = eye }
end

local function MakeSectionLabel(parent, text)
  local label = UI.CreateFontString(parent, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  label:SetText(text)
  label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  return label
end

local function MakePresetButton(parent, preset, index)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(PRESET_W, PRESET_H)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", (index - 1) * (PRESET_W + PRESET_GAP), 0)
  UI.StyleControl(button)

  local byId = CM.Constants.CrosshairTextureById
  local inactive = button:CreateTexture(nil, "ARTWORK")
  inactive:SetSize(26, 26)
  inactive:SetPoint("RIGHT", button, "CENTER", -1, 0)
  inactive:SetTexture(byId[preset.BaseId].path)
  Tint(inactive, "base")
  local active = button:CreateTexture(nil, "ARTWORK")
  active:SetSize(26, 26)
  active:SetPoint("LEFT", button, "CENTER", 1, 0)
  active:SetTexture(byId[preset.ActiveId].path)
  Tint(active, "hostile")

  button:SetScript("OnEnter", function(self)
    self:cmControlHover(true)
  end)
  button:SetScript("OnLeave", function(self)
    self:cmControlHover(false)
  end)
  UI.AttachTooltip(button, preset.Name)
  button:SetScript("OnClick", function()
    if target == "main" then
      ResetIdleSlots()
    end
    SetPair(preset.BaseId, preset.ActiveId)
  end)

  presetButtons[#presetButtons + 1] =
    { button = button, preset = preset, inactive = inactive, active = active }
end

local function MakeCell(parent, entry, index, cols)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(CELL, CELL)
  local col = (index - 1) % cols
  local row = floor((index - 1) / cols)
  button:SetPoint("TOPLEFT", parent, "TOPLEFT", col * (CELL + CELL_GAP), -row * (CELL + CELL_GAP))

  local bg = button:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(C.cardBg[1], C.cardBg[2], C.cardBg[3], 1)

  local glyph = button:CreateTexture(nil, "ARTWORK")
  glyph:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
  glyph:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
  glyph:SetTexture(entry.path)
  glyph:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)

  local cell = { button = button, bg = bg, id = entry.id, selectedAlpha = 0 }
  button:SetScript("OnEnter", function()
    if cell.selectedAlpha == 0 then
      bg:SetColorTexture(C.buttonHoverTop[1], C.buttonHoverTop[2], C.buttonHoverTop[3], 1)
    end
  end)
  button:SetScript("OnLeave", function()
    if cell.selectedAlpha == 0 then
      bg:SetColorTexture(C.cardBg[1], C.cardBg[2], C.cardBg[3], 1)
    end
  end)
  button:SetScript("OnClick", function()
    SetSlot(activeSlot, entry.id)
  end)

  cells[#cells + 1] = cell
end

local function Build()
  window = UI.CreateBareWindow(
    "CombatModeCrosshairTextureEditor",
    M["TITLE"] .. " - Crosshair Textures",
    EDITOR_W,
    EDITOR_H
  )
  window:Hide()

  local content = CreateFrame("Frame", nil, window)
  content:SetPoint("TOPLEFT", window, "TOPLEFT", 16, -44)
  content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -16, 16)

  local descText =
    UI.CreateFontString(content, "OVERLAY", UI.Fonts.sectionDesc, "GameFontHighlightSmall")
  descText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  descText:SetWidth(CONTENT_W)
  descText:SetJustifyH("LEFT")
  descText:SetWordWrap(true)
  descText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  descText:SetText(
    "Select a state, then pick a texture below, or apply a preset for a curated appearance."
  )

  slotsHost = CreateFrame("Frame", nil, content)
  slotsHost:SetSize(CONTENT_W, SLOT_H)
  slotsHost:SetPoint("TOPLEFT", descText, "BOTTOMLEFT", 0, -10)
  local slotW = floor((CONTENT_W - 8) / 2)
  MakeSlotCard(slotsHost, "base", "INACTIVE", 0, 0, slotW, SLOT_H)
  MakeSlotCard(slotsHost, "active", "ACTIVE", slotW + 8, 0, slotW, SLOT_H)
  MakeSlotCard(slotsHost, "mounted", "MOUNTED", 0, -(SLOT_H + 8), slotW, IDLE_H)
  MakeSlotCard(slotsHost, "lock", "DISABLED", slotW + 8, -(SLOT_H + 8), slotW, IDLE_H)

  local presetLabel = MakeSectionLabel(content, "PRESETS")
  presetLabel:SetPoint("TOPLEFT", slotsHost, "BOTTOMLEFT", 0, -14)

  local presets = {}
  for _, preset in pairs(CM.Constants.CrosshairTextureObj) do
    presets[#presets + 1] = preset
  end
  tsort(presets, function(a, b)
    if (a.Name == "Default") ~= (b.Name == "Default") then
      return a.Name == "Default"
    end
    return a.Name < b.Name
  end)
  local presetHost = CreateFrame("Frame", nil, content)
  presetHost:SetSize(CONTENT_W, PRESET_H)
  presetHost:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", 0, -6)
  for i, preset in ipairs(presets) do
    MakePresetButton(presetHost, preset, i)
  end

  local gridLabel = MakeSectionLabel(content, "ALL TEXTURES")
  gridLabel:SetPoint("TOPLEFT", presetHost, "BOTTOMLEFT", 0, -14)

  local resetBtn = CreateFrame("Button", nil, content)
  resetBtn:SetHeight(RESET_H)
  resetBtn:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 0)
  resetBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
  UI.StyleControl(resetBtn)
  local resetText = UI.CreateFontString(resetBtn, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  resetText:SetPoint("CENTER")
  resetText:SetText("Reset to Default")
  UI.WireControlHover(resetBtn, resetText)
  resetBtn:SetScript("OnClick", function()
    if target == "situational" then
      SetPair(NONE, NONE)
    else
      local default = CM.Constants.CrosshairTextureObj.Default
      ResetIdleSlots()
      SetPair(default.BaseId, default.ActiveId)
    end
  end)

  local gridHost = CreateFrame("Frame", nil, content)
  gridHost:SetPoint("TOPLEFT", gridLabel, "BOTTOMLEFT", 0, -6)
  gridHost:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, RESET_H + 8)

  local scroll, scrollChild = UI.CreateScrollFrame(gridHost)
  scroll:SetPoint("TOPLEFT", gridHost, "TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", gridHost, "BOTTOMRIGHT", -(CONTENT_W - SCROLL_W), 0)
  scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 3, 0)
  scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 3, 0)
  scrollChild:SetWidth(SCROLL_W)

  local cols = floor((SCROLL_W + CELL_GAP) / (CELL + CELL_GAP))
  local catalog = CM.Constants.CrosshairTextures
  for i, entry in ipairs(catalog) do
    MakeCell(scrollChild, entry, i, cols)
  end
  local rows = floor((#catalog - 1) / cols) + 1
  scrollChild:SetHeight(rows * (CELL + CELL_GAP) - CELL_GAP)

  window:SetScript("OnShow", Refresh)
end

--- Re-tints the open editor (called by the Reaction Colors editor as colors change).
function CM.RefreshCrosshairTextureEditor()
  Refresh()
end

--- Opens the texture browser. `which` is "main" (Crosshair tab Appearance) or "situational"
--- (Advanced tab Situational Appearance). `slot` ("base"/"active"/"mounted"/"lock", the last
--- two main only) preselects the slot to edit.
function CM.OpenCrosshairTextureEditor(which, slot)
  if InCombatLockdown and InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open this editor while in combat.|r")
    return
  end

  if not window then
    Build()
  end

  target = which == "situational" and "situational" or "main"
  activeSlot = "base"
  if slot == "active" or (target == "main" and IDLE_KEYS[slot]) then
    activeSlot = slot
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
  Refresh()
end
