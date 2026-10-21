---------------------------------------------------------------------------------------
--  UI/Editors/TargetingMacroPrelinesEditor.lua — EDITOR — targeting macro prelines
---------------------------------------------------------------------------------------
--  What it does: Standalone editor (CM.OpenTargetingMacroPrelinesEditor) for customizing
--  the targeting prelines injected into click-cast macros. Shows all four preline fields
--  (normal any/enemy + Auto Target Lock any/enemy); inactive fields use the disabled
--  watermark overlay based on Auto Target Lock and Ignore Friendlies.
--  Architecture / how it works:
--    • Defaults from TargetingMacroBuilder.TargetingMacroPrelinesDefaults.
--    • Override keys: targetingMacroPrelineAnyOverride / EnemyOverride,
--      AutoLockAnyOverride / AutoLockEnemyOverride.
--    • Active field = Auto Target Lock mode × Ignore Friendlies; others stay visible but
--      stamped Inactive (same pattern as the Ignore Friendlies pair overlay).
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

-- Lua stdlib
local strtrim = _G.strtrim
local type = _G.type

local UI = CM.UI
local M = CM.METADATA

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

local window

local function PrelineMaxLen()
  return CM.TargetingMacroPrelineMaxLen or 140
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
        return "Inactive — Ignore Friendlies is OFF"
      end
    elseif EnemyOnly() then
      return "Inactive — Ignore Friendlies is ON"
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

  local maxLenMarkup = UI.AccentWrap(tostring(maxLen))
  ctx:Description({
    allowColors = true,
    text = "Customize the targeting prelines injected before each ability when Reticle Targeting is enabled."
      .. "\n\n• Only the preline matching your current "
      .. UI.AccentWrap("Ignore Friendlies")
      .. " X "
      .. UI.AccentWrap("Auto Target Lock")
      .. " settings is active."
      .. "\n• Max "
      .. maxLenMarkup
      .. " characters per preline — SecureActionButton macros are capped at "
      .. UI.AccentWrap("255")
      .. "; the rest is reserved for the trailing "
      .. UI.SlashWrap("/click")
      .. " line."
      .. "\n• Use "
      .. UI.AccentWrap("Apply Changes")
      .. " to reload and pick up edits.",
  })

  local function StateLines(enemiesOn, autoLockOn)
    return "Ignore Friendlies: "
      .. UI.OnOffWrap(enemiesOn)
      .. "\nAuto Target Lock: "
      .. UI.OnOffWrap(autoLockOn)
  end

  local function AddPrelineField(opts)
    ctx:TextInput({
      label = opts.label,
      labelAllowColors = true,
      labelSize = UI.Fonts.small,
      -- Ignore Friendlies / Auto Target Lock state, shown as the small muted helper under the label.
      desc = opts.state,
      descAllowColors = true,
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
    label = "Preline: Ignore Friendlies + No Auto Lock",
    state = StateLines(true, false),
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
    label = "Preline: Ignore Friendlies + Auto Lock",
    state = StateLines(true, true),
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
    label = "Preline: Target Any Unit + No Auto Lock",
    state = StateLines(false, false),
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
    label = "Preline: Target Any Unit + Auto Lock",
    state = StateLines(false, true),
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
      reload = true,
      func = function()
        CM.DB.global.targetingMacroPrelineAnyOverride = nil
        CM.DB.global.targetingMacroPrelineEnemyOverride = nil
        CM.DB.global.targetingMacroPrelineAutoLockAnyOverride = nil
        CM.DB.global.targetingMacroPrelineAutoLockEnemyOverride = nil
        CM.ReloadUI()
      end,
    },
    {
      label = "Apply Changes",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      reload = true,
      func = function()
        CM.ReloadUI()
      end,
    },
  })

  ctx:Finish()
  -- Measure content once, publish as the shared secondary-editor height, then apply it
  -- (published via UI.SetSecondaryEditorHeight).
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
