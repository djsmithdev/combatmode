---------------------------------------------------------------------------------------
--  UI/Editors/TargetingMacroPrelinesEditor.lua — EDITOR — targeting macro prelines
---------------------------------------------------------------------------------------
--  What it does: Standalone editor (CM.OpenTargetingMacroPrelinesEditor) for customizing
--  the targeting prelines injected into click-cast macros. Shows all four preline fields
--  (normal any/enemy + Auto Target Lock any/enemy); inactive fields use the disabled
--  watermark overlay based on Auto Target Lock and Enemies Only.
--  Architecture / how it works:
--    • Defaults from TargetingMacroBuilder.TargetingMacroPrelinesDefaults.
--    • Override keys: targetingMacroPrelineAnyOverride / EnemyOverride,
--      AutoLockAnyOverride / AutoLockEnemyOverride.
--    • Active field = Auto Target Lock mode × Enemies Only; others stay visible but
--      stamped Inactive (same pattern as the Enemies Only pair overlay).
--    • Max length = CM.TargetingMacroPrelineMaxLen (255 − worst /click − newline);
--      EditBox SetMaxLetters + validate refuse oversized input.
--    • Reset clears all four overrides. Combat-guarded open; uses CM.UI CreateWindow.
--  Does not: Rebuild secure macrotext until reload / RefreshClickCastMacros path runs.
--  Related: Core/ClickCasting/TargetingMacroBuilder.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, Constants/DatabaseDefaults.lua,
--  UI/Options/OptionsPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local InCombatLockdown = _G.InCombatLockdown
local ReloadUI = _G.ReloadUI

-- Lua stdlib
local strtrim = _G.strtrim
local type = _G.type

local UI = CM.UI
local M = CM.METADATA

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

local window

local function PrelineMaxLen()
  return CM.TargetingMacroPrelineMaxLen or 129
end

local function NormalizeInput(value)
  value = type(value) == "string" and strtrim(value) or ""
  if value == "" then
    return nil
  end
  return value
end

local function ValidatePreline(value)
  value = type(value) == "string" and value or ""
  local maxLen = PrelineMaxLen()
  if #value > maxLen then
    return "Preline must be "
      .. maxLen
      .. " characters or fewer (room for /click under the 255 macro limit)."
  end
  return true
end

local function EnemyOnly()
  return CM.DB and CM.DB.char and CM.DB.char.reticleTargetingEnemyOnly == true
end

local function AutoTargetLock()
  return CM.DB and CM.DB.char and CM.DB.char.autoTargetLockOnAttack == true
end

-- forAutoLock / forEnemyOnly describe which mode this field belongs to.
local function FieldDisabled(forAutoLock, forEnemyOnly)
  return function()
    if forAutoLock then
      if not AutoTargetLock() then
        return true
      end
    elseif AutoTargetLock() then
      return true
    end
    if forEnemyOnly then
      return not EnemyOnly()
    end
    return EnemyOnly()
  end
end

local function FieldWatermark(forAutoLock, forEnemyOnly)
  return function()
    if forAutoLock then
      if not AutoTargetLock() then
        return "Inactive — Auto Target Lock is OFF"
      end
    elseif AutoTargetLock() then
      return "Inactive — Auto Target Lock is ON"
    end
    if forEnemyOnly then
      if not EnemyOnly() then
        return "Inactive — Enemies Only is OFF"
      end
    elseif EnemyOnly() then
      return "Inactive — Enemies Only is ON"
    end
    return "Inactive"
  end
end

local function Build()
  local defaults = CM.TargetingMacroPrelinesDefaults or {}
  local maxLen = PrelineMaxLen()
  local ctx
  window, ctx = UI.CreateWindow(
    "CombatModeTargetingMacroPrelinesEditor",
    M["TITLE"] .. " - Targeting Macro Prelines Editor",
    700,
    UI.GetSecondaryEditorHeight(),
    { noScroll = true }
  )

  ctx:Description(
    "Edit the targeting macro preline inserted before actions when Reticle Targeting is enabled. "
      .. "\n- All four prelines are listed; only the one matching your current settings is active."
      .. "\n- Max "
      .. maxLen
      .. " characters per preline (SecureActionButton 255-char limit minus the /click line)."
  )

  local function AddPrelineField(opts)
    ctx:TextInput({
      label = opts.label,
      multiline = 4,
      maxLetters = maxLen,
      get = opts.get,
      set = opts.set,
      validate = ValidatePreline,
      disabled = opts.disabled,
      watermarkWhenDisabled = opts.watermarkWhenDisabled,
    })
  end

  AddPrelineField({
    label = "Preline: Target Enemies Only + No Auto Lock"
      .. "\nEnemies Only: ON"
      .. "\nAuto Target Lock: OFF",
    get = function()
      return CM.DB.global.targetingMacroPrelineEnemyOverride or defaults.enemy or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineEnemyOverride = NormalizeInput(value)
    end,
    disabled = FieldDisabled(false, true),
    watermarkWhenDisabled = FieldWatermark(false, true),
  })
  AddPrelineField({
    label = "Preline: Target Enemies Only + Auto Lock"
      .. "\nEnemies Only: ON"
      .. "\nAuto Target Lock: ON",
    get = function()
      return CM.DB.global.targetingMacroPrelineAutoLockEnemyOverride or defaults.autoLockEnemy or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineAutoLockEnemyOverride = NormalizeInput(value)
    end,
    disabled = FieldDisabled(true, true),
    watermarkWhenDisabled = FieldWatermark(true, true),
  })
  AddPrelineField({
    label = "Preline: Target Any Unit + No Auto Lock"
      .. "\nEnemies Only: OFF"
      .. "\nAuto Target Lock: OFF",
    get = function()
      return CM.DB.global.targetingMacroPrelineAnyOverride or defaults.any or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineAnyOverride = NormalizeInput(value)
    end,
    disabled = FieldDisabled(false, false),
    watermarkWhenDisabled = FieldWatermark(false, false),
  })
  AddPrelineField({
    label = "Preline: Target Any Unit + Auto Lock"
      .. "\nEnemies Only: OFF"
      .. "\nAuto Target Lock: ON",
    get = function()
      return CM.DB.global.targetingMacroPrelineAutoLockAnyOverride or defaults.autoLockAny or ""
    end,
    set = function(value)
      CM.DB.global.targetingMacroPrelineAutoLockAnyOverride = NormalizeInput(value)
    end,
    disabled = FieldDisabled(true, false),
    watermarkWhenDisabled = FieldWatermark(true, false),
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
        CM.DB.global.targetingMacroPrelineAutoLockAnyOverride = nil
        CM.DB.global.targetingMacroPrelineAutoLockEnemyOverride = nil
        ReloadUI()
      end,
    },
    {
      label = "Apply Changes",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      func = function()
        ReloadUI()
      end,
    },
  })

  ctx:Finish()
  -- Measure content once, publish as the shared secondary-editor height, then apply it
  -- (same GetSecondaryEditorHeight path the CVar editor uses).
  UI.SizeWindowToContent(window)
  UI.SetSecondaryEditorHeight(window:GetHeight())
  window:SetHeight(UI.GetSecondaryEditorHeight())
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
  window:SetHeight(UI.GetSecondaryEditorHeight())
  UI.Options.Sync()
end
