---------------------------------------------------------------------------------------
--  Config/TargetingMacroPrelinesEditor.lua — Targeting Macro Prelines editor (custom)
---------------------------------------------------------------------------------------
--  Standalone custom window (no AceConfigDialog) built with the CM.UI toolkit
--  (UI/Options/*). Opened from the Reticle Targeting tab via
--  CM.OpenTargetingMacroPrelinesEditor. Persists account-wide overrides
--  CM.DB.global.targetingMacroPrelineAnyOverride / targetingMacroPrelineEnemyOverride;
--  Core/TargetingMacroBuilder.lua applies them. Combat-guarded on open.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local strtrim = _G.strtrim
local type = _G.type

local UI = CM.UI
local M = CM.METADATA

local RELOAD_CONFIRM = "A UI Reload is required when making changes to Reticle Targeting.\nProceed?"

local window

local function NormalizeInput(value)
  value = type(value) == "string" and strtrim(value) or ""
  if value == "" then
    return nil
  end
  return value
end

local function EnemyOnly()
  return CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly == true
end

local function Build()
  local defaults = CM.TargetingMacroPrelinesDefaults or {}
  local ctx
  window, ctx = UI.CreateWindow(
    "CombatModeTargetingMacroPrelinesEditor",
    M["TITLE"] .. " - Targeting Macro Prelines Editor",
    700,
    330
  )

  ctx:Description(
    "Edit the targeting Macro preline inserted before actions when Reticle Targeting is enabled. The active field depends on Only Allow Reticle To Target Enemies."
  )

  ctx:TextInput({
    label = "Preline (Any unit) — used when 'Only Target Enemies' is OFF",
    multiline = 4,
    get = function()
      return CM.DB.global.targetingMacroPrelineAnyOverride or defaults.any or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineAnyOverride = NormalizeInput(value)
    end,
    disabled = function()
      return EnemyOnly()
    end,
  })
  ctx:TextInput({
    label = "Preline (Enemies only) — used when 'Only Target Enemies' is ON",
    multiline = 4,
    get = function()
      return CM.DB.global.targetingMacroPrelineEnemyOverride or defaults.enemy or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineEnemyOverride = NormalizeInput(value)
    end,
    disabled = function()
      return not EnemyOnly()
    end,
  })

  ctx:Gap()
  ctx:ButtonRow({
    {
      label = "Reset to Defaults",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      func = function()
        CM.DB.global.targetingMacroPrelineAnyOverride = nil
        CM.DB.global.targetingMacroPrelineEnemyOverride = nil
        ReloadUI()
      end,
    },
    {
      label = "Apply Changes (Reload UI)",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      func = function()
        ReloadUI()
      end,
    },
  })

  ctx:Finish()
end

function CM.OpenTargetingMacroPrelinesEditor()
  if InCombatLockdown and InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open this editor while in combat.|r")
    return
  end

  if not window then
    Build()
  end

  -- Anchor to the right of the main options window when it is open.
  local anchor = CM.GetOptionsFrame and CM.GetOptionsFrame()
  window:ClearAllPoints()
  if anchor and anchor:IsShown() then
    window:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 12, 0)
  else
    window:SetPoint("CENTER")
  end

  window:Show()
  window:Raise()
  UI.Options.Sync()
end
