---------------------------------------------------------------------------------------
-- UI/Editors/ComposedMacroEditor.lua — EDITOR — Macro Composer (Reticle Targeting macros)
---------------------------------------------------------------------------------------
-- What does: Standalone editor (CM.OpenComposedMacroEditor) that writes a real WoW macro:
-- the active targeting preline is shown greyed and locked above a multiline body the
-- player types (Enter = new line), and Save Macro stores the joined macro so it keeps
-- reticle targeting wherever it is used (action bar or a Run MACRO slot).
-- Architecture / how it works:
--   • Preline: CM.GetActiveTargetingPreline() (edited under Advanced > Prelines Editor).
--   • Limit: CM.ComposedMacroBodyBudget() (255 minus preline) caps the body; a live counter
--     shows usage. Saving goes through CM.SaveComposedMacro (ComposedMacros.lua).
--   • Window is rebuilt when the preline text changes (its locked block is sized at build).
-- Does not: Create the macro itself or change prelines.
-- Related: Core/ClickCasting/ComposedMacros.lua, UI/Options/Tabs/TabReticleTargeting.lua,
-- UI/Editors/TargetingMacroPrelinesEditor.lua, UI/Options/Widgets.lua (lockedPrefix)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local InCombatLockdown = _G.InCombatLockdown

local UI = CM.UI
local M = CM.METADATA

local window
local builtKey
local buildCount = 0

-- State of the macro being edited. `editingName` is the existing macro to update in place
-- (nil when composing a new one).
local editingName
local builtEditing -- whether the current window was built with the Delete button
local draftName = ""
local draftBody = ""

local function BodyBudget()
  return CM.ComposedMacroBodyBudget()
end

local function CounterText()
  local budget = BodyBudget()
  local used = #draftBody
  local text = used .. " / " .. budget .. " characters"
  if used > budget then
    return UI.AccentWrap(text) .. " (over the macro limit)"
  end
  return text
end

local function PrelineText()
  return CM.GetActiveTargetingPreline() or ""
end

local function StateLines()
  local enemiesOn = CM.DB.char.reticleTargetingEnemyOnly == true
  local autoLockOn = CM.DB.char.autoTargetLockOnAttack == true
  return "Ignore Friendlies: "
    .. UI.OnOffWrap(enemiesOn)
    .. "\nAuto Target Lock: "
    .. UI.OnOffWrap(autoLockOn)
end

-- Same names as the Prelines Editor fields.
local function PrelineLabel()
  local enemiesOn = CM.DB.char.reticleTargetingEnemyOnly == true
  local autoLockOn = CM.DB.char.autoTargetLockOnAttack == true
  return "Preline: "
    .. (enemiesOn and "Ignore Friendlies" or "Target Any Unit")
    .. (autoLockOn and " + Auto Lock" or " + No Auto Lock")
end

local function BuildKey()
  return PrelineLabel() .. "\n" .. PrelineText()
end

local function Build()
  buildCount = buildCount + 1
  builtKey = BuildKey()
  builtEditing = editingName ~= nil
  local ctx
  window, ctx = UI.CreateWindow(
    "CombatModeComposedMacroEditor" .. buildCount,
    M["TITLE"] .. " - Macro Composer",
    700,
    400,
    { noScroll = true }
  )

  ctx:Description({
    justify = "LEFT",
    color = UI.Colors.textDim,
    allowColors = true,
    text = "The targeting logic preline matching your current Reticle Targeting settings is added automatically before your lines, as the highlighted portion of the macro. To modify it, use the Prelines Editor under "
      .. UI.AccentWrap("Advanced")
      .. ".",
  })

  ctx:TextInput({
    label = "Macro Name",
    placeholder = "Enter a macro name",
    desc = function()
      return "Saved to your "
        .. (CM.DB.char.useGlobalBindings and "general" or "character")
        .. " macros."
    end,
    descAllowColors = true,
    maxLetters = CM.ComposedMacroNameMax or 16,
    get = function()
      return draftName
    end,
    set = function(value)
      draftName = value
    end,
    onTextChanged = function(value)
      draftName = value
    end,
  })

  ctx:TextInput({
    label = "Macro Text",
    desc = function()
      return PrelineLabel() .. "\n" .. StateLines() .. "\n" .. CounterText()
    end,
    descAllowColors = true,
    multiline = 5,
    lockedPrefix = PrelineText,
    lockedWidthHint = 350,
    placeholder = "#showtooltip Raptor Strike\n/cast Raptor Strike\n/cast Strider Kick",
    maxLetters = BodyBudget(),
    get = function()
      return draftBody
    end,
    set = function(value)
      draftBody = value
    end,
    onTextChanged = function(value)
      draftBody = value
      UI.Options.Sync()
    end,
  })

  ctx:Gap()
  local buttons = {}
  if builtEditing then
    buttons[#buttons + 1] = {
      label = "Delete Macro",
      danger = true,
      confirm = true,
      confirmText = "Delete this macro? Any action bar button using it will be emptied.",
      func = function()
        CM.DeleteComposedMacro(editingName, function()
          window:Hide()
          UI.Options.Sync()
        end)
      end,
    }
  end
  buttons[#buttons + 1] = {
    label = "Save Macro",
    func = function()
      CM.SaveComposedMacro(draftName, draftBody, function()
        window:Hide()
        UI.Options.Sync()
      end, editingName)
    end,
  }
  ctx:ButtonRow(buttons)

  ctx:Finish()
  UI.SizeWindowToContent(window)
end

--- Opens the composer. With `macroName` of an existing Reticle Targeting macro it edits that
--- one; otherwise it starts a new macro with an empty name (placeholder only).
function CM.OpenComposedMacroEditor(macroName)
  if InCombatLockdown and InCombatLockdown() then
    print(CM.Constants.BasePrintMsg .. "|cff909090: Cannot open editor while in combat.|r")
    return
  end

  local existingBody = macroName and CM.GetEditableMacroBody(macroName)
  if existingBody then
    editingName = macroName
    draftName = macroName
    draftBody = existingBody
  else
    editingName = nil
    draftName = ""
    draftBody = ""
  end

  -- The locked block is sized at build; start over if the preline changed since.
  -- Also rebuilt when switching between editing and new (the Delete button only exists
  -- while editing).
  if window and (builtKey ~= BuildKey() or builtEditing ~= (editingName ~= nil)) then
    window:Hide()
    window = nil
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
  UI.Options.Sync()
end
