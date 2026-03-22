---------------------------------------------------------------------------------------
--  UI/CrosshairEditMode.lua — LibEditMode crosshair, settings dialog, preview panel
---------------------------------------------------------------------------------------
--  Loaded after Features/Reticle.lua (Embeds.xml). Uses CM.CreateCrosshair, CM.ApplyCrosshairAppearanceToWidget,
--  CM.CreateCrosshairScaleAnimation, and CM.HideCrosshairWhileMounted from Reticle.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsMouselooking = _G.IsMouselooking
local UIParent = _G.UIParent
local UIErrorsFrame = _G.UIErrorsFrame
local C_Timer = _G.C_Timer
local hooksecurefunc = _G.hooksecurefunc
local math = _G.math
local pairs = _G.pairs
local table = _G.table

local ON_RETAIL_CLIENT = (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)

local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

---------------------------------------------------------------------------------------
--              EDIT MODE: CROSSHAIR PREVIEW (LIBEDITMODE SELECTION)                 --
---------------------------------------------------------------------------------------
local CrosshairEditPreviewPanel
local CrosshairEditPreviewInner
local CrosshairEditPreviewTexture
local CrosshairEditPreviewAnim
local CrosshairEditPreviewStateLabel
local crosshairPreviewTicker
local crosshairPreviewStateIndex = 1

local PREVIEW_STATE_ORDER = {
  "base",
  "hostile",
  "friendly_player",
  "friendly_npc",
  "object",
  "focus"
}
local PREVIEW_CYCLE_INTERVAL = 2

local function GetCrosshairEditPreviewStateTitle(state)
  local titles = {
    base = "Base",
    hostile = "Hostile",
    friendly_player = "Friendly (player)",
    friendly_npc = "Friendly (NPC)",
    object = "Interactable",
    focus = "Target Lock"
  }
  return titles[state] or state
end

local function AnchorCrosshairEditPreviewToLibEditDialog()
  if not CrosshairEditPreviewPanel then
    return
  end
  local LEM = LibStub("LibEditMode", true)
  local dialog = LEM and LEM.internal and LEM.internal.dialog
  CrosshairEditPreviewPanel:ClearAllPoints()
  if dialog then
    CrosshairEditPreviewPanel:SetParent(dialog)
    CrosshairEditPreviewPanel:SetPoint("TOPLEFT", dialog, "TOPRIGHT", 8, 0)
    CrosshairEditPreviewPanel:SetFrameStrata(dialog:GetFrameStrata())
    CrosshairEditPreviewPanel:SetFrameLevel(dialog:GetFrameLevel() + 10)
  else
    CrosshairEditPreviewPanel:SetParent(UIParent)
    CrosshairEditPreviewPanel:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -16, -100)
    CrosshairEditPreviewPanel:SetFrameStrata("DIALOG")
    CrosshairEditPreviewPanel:SetFrameLevel(5000)
  end
end

local function EnsureCrosshairEditPreviewPanel()
  if CrosshairEditPreviewPanel then
    return
  end

  local panel = CreateFrame("Frame", "CombatModeCrosshairEditPreview", UIParent, "BackdropTemplate")
  panel:SetSize(240, 300)
  panel:SetFrameStrata("DIALOG")
  panel:SetFrameLevel(500)
  panel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  panel:SetBackdropColor(0, 0, 0, 0.92)
  panel:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
  panel:Hide()

  local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", panel, "TOP", 0, -18)
  title:SetText("|cff00FFFFCrosshair|r Preview")

  CrosshairEditPreviewStateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  CrosshairEditPreviewStateLabel:SetPoint("TOP", title, "BOTTOM", 0, -8)
  CrosshairEditPreviewStateLabel:SetTextColor(0.9, 0.9, 0.9, 1)

  local inner = CreateFrame("Frame", nil, panel)
  inner:SetSize(64, 64)
  inner:SetPoint("CENTER", panel, "CENTER", 0, -10)
  local tex = inner:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(inner)
  tex:SetBlendMode("BLEND")
  local anim = inner:CreateAnimationGroup()
  CM.CreateCrosshairScaleAnimation(anim)

  CrosshairEditPreviewPanel = panel
  CrosshairEditPreviewInner = inner
  CrosshairEditPreviewTexture = tex
  CrosshairEditPreviewAnim = anim
end

local function StopCrosshairEditPreviewTicker()
  if crosshairPreviewTicker then
    crosshairPreviewTicker:Cancel()
    crosshairPreviewTicker = nil
  end
end

function CM.RefreshCrosshairEditPreview()
  if not CrosshairEditPreviewPanel or not CrosshairEditPreviewPanel:IsShown() then
    return
  end
  if not CM.DB or not CM.DB.global then
    return
  end
  local DefaultConfig = CM.Constants.DatabaseDefaults.global
  local UserConfig = CM.DB.global
  local crosshairSize = UserConfig.crosshairSize or DefaultConfig.crosshairSize
  local crosshairOpacity = UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity

  CrosshairEditPreviewInner:SetSize(crosshairSize, crosshairSize)
  CrosshairEditPreviewInner:SetAlpha(crosshairOpacity)

  local state = PREVIEW_STATE_ORDER[crosshairPreviewStateIndex]
  if CrosshairEditPreviewStateLabel then
    CrosshairEditPreviewStateLabel:SetText(GetCrosshairEditPreviewStateTitle(state))
  end
  CM.ApplyCrosshairAppearanceToWidget(
    CrosshairEditPreviewInner,
    CrosshairEditPreviewTexture,
    CrosshairEditPreviewAnim,
    state,
    0,
    true
  )
end

local function CrosshairEditPreviewAdvance()
  crosshairPreviewStateIndex = (crosshairPreviewStateIndex % #PREVIEW_STATE_ORDER) + 1
  CM.RefreshCrosshairEditPreview()
end

function CM.ShowCrosshairEditPreview()
  if not ON_RETAIL_CLIENT then
    return
  end
  EnsureCrosshairEditPreviewPanel()
  AnchorCrosshairEditPreviewToLibEditDialog()
  crosshairPreviewStateIndex = 1
  CrosshairEditPreviewPanel:Show()
  CM.RefreshCrosshairEditPreview()
  StopCrosshairEditPreviewTicker()
  crosshairPreviewTicker = C_Timer.NewTicker(PREVIEW_CYCLE_INTERVAL, CrosshairEditPreviewAdvance)
end

function CM.HideCrosshairEditPreview()
  StopCrosshairEditPreviewTicker()
  crosshairPreviewStateIndex = 1
  if CrosshairEditPreviewPanel then
    CrosshairEditPreviewPanel:Hide()
  end
end

--- LibEditMode uses one shared settings dialog for every registered frame. Selection OnHide is not
--- reliable when switching to another addon's frame, so we key off dialog:Update(selection) instead.
local function SyncCrosshairEditPreviewFromDialog(selection)
  local frame = _G.CombatModeCrosshairFrame
  if not frame or not selection or selection.parent ~= frame then
    CM.HideCrosshairEditPreview()
    return
  end
  EnsureCrosshairEditPreviewPanel()
  AnchorCrosshairEditPreviewToLibEditDialog()
  if CrosshairEditPreviewPanel:IsShown() and crosshairPreviewTicker then
    CM.RefreshCrosshairEditPreview()
  else
    CM.ShowCrosshairEditPreview()
  end
end

---------------------------------------------------------------------------------------
--                    LIBEDITMODE: CROSSHAIR (RETAIL / EDIT MODE)                    --
---------------------------------------------------------------------------------------
local crosshairEditModeRegistered = false

-- Hint when Edit Mode drag leaves the crosshair off horizontal center (snapped back on save).
local CROSSHAIR_HORIZONTAL_DRAG_EPS = 5
local CROSSHAIR_HORIZONTAL_DRAG_HINT_THROTTLE = 4
local crosshairHorizontalDragHintLast = 0

local function BuildCrosshairAppearanceDropdownValues()
  local t = {}
  for assetName in pairs(CM.Constants.CrosshairAppearanceSelectValues) do
    t[#t + 1] = { text = assetName, value = assetName }
  end
  table.sort(t, function(a, b)
    return a.text < b.text
  end)
  return t
end

function CM.RegisterCrosshairEditMode()
  if crosshairEditModeRegistered or not ON_RETAIL_CLIENT then
    return
  end
  local LibEditMode = LibStub("LibEditMode", true)
  if not LibEditMode then
    return
  end

  local frame = _G.CombatModeCrosshairFrame
  if not frame then
    return
  end

  crosshairEditModeRegistered = true

  local _, _, yDefault = CM.GetCrosshairPositionForLayout(LibEditMode:GetActiveLayoutName())
  local defaultPos = { point = "CENTER", x = 0, y = yDefault }

  LibEditMode:AddFrame(frame, function(_, layoutNameCb)
    if not CM.DB.global.crosshairLayoutPositions then
      CM.DB.global.crosshairLayoutPositions = {}
    end
    local cx, cy = frame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux and math.abs(cx - ux) > CROSSHAIR_HORIZONTAL_DRAG_EPS then
      local now = GetTime()
      if now - crosshairHorizontalDragHintLast >= CROSSHAIR_HORIZONTAL_DRAG_HINT_THROTTLE then
        crosshairHorizontalDragHintLast = now
        if UIErrorsFrame and UIErrorsFrame.AddMessage then
          UIErrorsFrame:AddMessage(
            CM.METADATA["TITLE"] ..
              ": Crosshair stays centered horizontally; drag vertically to adjust height.",
            1,
            1,
            0,
            1
          )
        end
      end
    end
    local verticalY = (cx and cy and ux and uy) and (cy - uy) or (CM.DB.global.crosshairY or CM.Constants.DatabaseDefaults.global.crosshairY)
    CM.DB.global.crosshairLayoutPositions[layoutNameCb] = { point = "CENTER", x = 0, y = verticalY }
    CM.DB.global.crosshairY = verticalY
    CM.CreateCrosshair()
    if CM.HealingRadial and CM.HealingRadial.UpdateMainFramePosition then
      CM.HealingRadial.UpdateMainFramePosition()
    end
  end, defaultPos, CM.Constants.EditModeSystemDisplayName)

  local lemDialog = LibEditMode.internal and LibEditMode.internal.dialog
  if lemDialog then
    hooksecurefunc(lemDialog, "Update", function(_, selection)
      SyncCrosshairEditPreviewFromDialog(selection)
    end)
    lemDialog:HookScript("OnHide", function()
      CM.HideCrosshairEditPreview()
    end)
  end

  local LEM = LibEditMode
  local ST = LEM.SettingType

  LEM:AddFrameSettings(frame, {
    {
      name = "Show Crosshair",
      kind = ST.Checkbox,
      default = true,
      get = function()
        return CM.DB.global.crosshair
      end,
      set = function(_, value)
        CM.DB.global.crosshair = value
        if value then
          CM.DisplayCrosshair(true)
        else
          CM.DisplayCrosshair(false)
        end
        CM.CreateCrosshair()
      end
    },
    {
      name = "Hide Crosshair While Mounted",
      kind = ST.Checkbox,
      default = false,
      get = function()
        return CM.DB.global.crosshairMounted
      end,
      set = function(_, value)
        CM.DB.global.crosshairMounted = value
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    {
      name = "Crosshair Appearance",
      kind = ST.Dropdown,
      default = "Default",
      values = BuildCrosshairAppearanceDropdownValues,
      get = function()
        return CM.DB.global.crosshairAppearance and CM.DB.global.crosshairAppearance.Name or "Default"
      end,
      set = function(_, value)
        CM.DB.global.crosshairAppearance = CM.Constants.CrosshairTextureObj[value]
        CM.CreateCrosshair()
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    {
      name = "Crosshair Size",
      kind = ST.Slider,
      default = 64,
      minValue = 16,
      maxValue = 128,
      valueStep = 16,
      get = function()
        return CM.DB.global.crosshairSize
      end,
      set = function(_, value)
        CM.DB.global.crosshairSize = value
        CM.CreateCrosshair()
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    },
    {
      name = "Crosshair Opacity",
      kind = ST.Slider,
      default = 1,
      minValue = 0.1,
      maxValue = 1,
      valueStep = 0.1,
      formatter = function(value)
        return _G.FormatPercentage(value, true)
      end,
      get = function()
        return CM.DB.global.crosshairOpacity
      end,
      set = function(_, value)
        CM.DB.global.crosshairOpacity = value
        CM.CreateCrosshair()
      end,
      disabled = function()
        return CM.DB.global.crosshair ~= true
      end
    }
  })

  LEM:RegisterCallback("layout", function(layoutName)
    CM.ApplyCrosshairPositionForLayout(layoutName)
    CM.CreateCrosshair()
    if CM.HealingRadial and CM.HealingRadial.UpdateMainFramePosition then
      CM.HealingRadial.UpdateMainFramePosition()
    end
  end)

  LEM:RegisterCallback("enter", function()
    if CM.DB.global.crosshair then
      CM.DisplayCrosshair(true)
    end
  end)

  LEM:RegisterCallback("exit", function()
    CM.HideCrosshairEditPreview()
    if CM.HideCrosshairWhileMounted() then
      CM.DisplayCrosshair(false)
    elseif CM.DB.global.crosshair then
      CM.DisplayCrosshair(IsMouselooking())
    else
      CM.DisplayCrosshair(false)
    end
  end)

  LEM:RegisterCallback("create", function(newLayoutName, _, sourceLayoutName)
    if not CM.DB.global.crosshairLayoutPositions then
      CM.DB.global.crosshairLayoutPositions = {}
    end
    if sourceLayoutName and CM.DB.global.crosshairLayoutPositions[sourceLayoutName] then
      CM.DB.global.crosshairLayoutPositions[newLayoutName] = _G.CopyTable(CM.DB.global.crosshairLayoutPositions[sourceLayoutName])
    end
  end)

  LEM:RegisterCallback("rename", function(oldLayoutName, newLayoutName)
    local t = CM.DB.global.crosshairLayoutPositions
    if t and t[oldLayoutName] then
      t[newLayoutName] = t[oldLayoutName]
      t[oldLayoutName] = nil
    end
  end)

  LEM:RegisterCallback("delete", function(deletedLayoutName)
    local t = CM.DB.global.crosshairLayoutPositions
    if t and t[deletedLayoutName] then
      t[deletedLayoutName] = nil
    end
  end)
end
