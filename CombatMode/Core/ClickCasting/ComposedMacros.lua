---------------------------------------------------------------------------------------
--  Core/ClickCasting/ComposedMacros.lua — CLICKCAST — preline + user body WoW macros
---------------------------------------------------------------------------------------
--  What it does: Builds real WoW macros (preline + user-written body) so macros keep reticle
--  targeting without hand-copying the preline. They are dragged to action bars from the
--  Reticle Targeting Macros shelf, or picked in a click-cast Run MACRO slot.
--  Architecture / how it works:
--    • CM.ComposeMacroText(body) — active preline (CM.GetActiveTargetingPreline) + "\n" + body.
--    • Budget — a plain macro is capped at 255 chars (no /click line, unlike click-cast
--      macrotext). CM.ComposedMacroBodyBudget() = 255 - #preline - newline; the editor counter,
--      maxLetters and the save check all read it.
--    • CM.SaveComposedMacro — create/edit the macro (character macro unless Account-Wide
--      Binds) and remember its body in CM.DB.global.composedMacros[name].
--    • CM.RebuildComposedMacros — re-edits registered macros whose text no longer matches the
--      active preline (Auto Target Lock / Ignore Friendlies / preline override changes).
--      Runs from RefreshClickCastMacros and at login; skipped in combat.
--    • CM.EnumerateMacros / CM.IsComposedMacroBody feed the Click Casting macro dropdown
--      (icon + whether a macro opens with an ACM targeting preline); CM.EnumerateComposedMacros
--      lists only those, for the draggable Reticle Targeting Macros shelf.
--  Does not: Build click-cast proxy macrotext (TargetingMacroBuilder) or draw the editor UI.
--  Related: Core/ClickCasting/TargetingMacroBuilder.lua, Core/ClickCasting/BindingOverrides.lua,
--  UI/Editors/ComposedMacroEditor.lua, UI/Options/Tabs/TabReticleTargeting.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateMacro = _G.CreateMacro
local DeleteMacro = _G.DeleteMacro
local EditMacro = _G.EditMacro
local GetMacroBody = _G.GetMacroBody
local GetMacroInfo = _G.GetMacroInfo
local GetNumMacros = _G.GetNumMacros
local InCombatLockdown = _G.InCombatLockdown

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local strtrim = _G.strtrim

local MACRO_MAX = 255
local MACRO_NAME_MAX = 16
local QUESTION_MARK_ICON = 134400 -- lets #showtooltip drive the icon
local DEFAULT_MAX_ACCOUNT_MACROS = 120
local DEFAULT_MAX_CHARACTER_MACROS = 18

CM.ComposedMacroNameMax = MACRO_NAME_MAX

local function Say(msg)
  print(CM.Constants.BasePrintMsg .. "|cff909090: " .. msg .. "|r")
end

local function Preline()
  return CM.GetActiveTargetingPreline and CM.GetActiveTargetingPreline() or ""
end

function CM.ComposeMacroText(body)
  local pre = Preline()
  if pre == "" then
    return body or ""
  end
  return pre .. "\n" .. (body or "")
end

--- Characters left for the user's body after the preline and the joining newline.
function CM.ComposedMacroBodyBudget()
  local pre = Preline()
  local used = pre ~= "" and (#pre + 1) or 0
  return MACRO_MAX - used
end

local function NormalizeBody(body)
  return strtrim((body or ""):gsub("\r\n?", "\n"))
end

--- Registry of composed macros: name -> the body the player typed after the preline.
local function Registry()
  local global = CM.DB.global
  global.composedMacros = global.composedMacros or {}
  return global.composedMacros
end

--- Body saved for a composed macro (nil when the macro was not made by the composer).
function CM.GetComposedMacroBody(name)
  return CM.DB and Registry()[name]
end

--- Slot index of the macro called `name` (general 1..n, character from MAX_ACCOUNT_MACROS + 1),
--- or nil. Scans by index so it never depends on name lookups in GetMacroInfo / EditMacro.
local function MacroIndex(name)
  if not name or name == "" then
    return nil
  end
  local globalCount, charCount = GetNumMacros()
  local accountMax = _G.MAX_ACCOUNT_MACROS or DEFAULT_MAX_ACCOUNT_MACROS
  for i = 1, globalCount do
    if GetMacroInfo(i) == name then
      return i
    end
  end
  for i = accountMax + 1, accountMax + charCount do
    if GetMacroInfo(i) == name then
      return i
    end
  end
  return nil
end

--- Edits `editing` in place (renaming it when `name` differs), else creates a new macro.
local function WriteMacro(name, body, text, editing, onDone)
  local index = MacroIndex(editing or name)
  if index then
    EditMacro(index, name, nil, text)
    if editing and editing ~= name then
      Registry()[editing] = nil
    end
  else
    local globalCount, charCount = GetNumMacros()
    local perCharacter = not CM.DB.char.useGlobalBindings
    local limit, count
    if perCharacter then
      limit, count = _G.MAX_CHARACTER_MACROS or DEFAULT_MAX_CHARACTER_MACROS, charCount
    else
      limit, count = _G.MAX_ACCOUNT_MACROS or DEFAULT_MAX_ACCOUNT_MACROS, globalCount
    end
    if count >= limit then
      Say("Your " .. (perCharacter and "character" or "general") .. " macro list is full.")
      return
    end
    CreateMacro(name, QUESTION_MARK_ICON, text, perCharacter)
  end
  Registry()[name] = body
  if onDone then
    onDone()
  end
end

--- Deletes the macro `name` (and its remembered body). Action bar slots holding it go empty.
function CM.DeleteComposedMacro(name, onDone)
  if InCombatLockdown() then
    Say("Cannot delete a macro while in combat.")
    return false
  end
  local index = MacroIndex(name)
  if index then
    DeleteMacro(index)
  end
  Registry()[name] = nil
  if onDone then
    onDone()
  end
  return true
end

--- Creates or updates the macro (preline + body) and remembers the body for auto-rebuild.
--- `editing` is the name of the macro being edited (nil for a new one): it is updated in place
--- and renamed when `name` differs, instead of creating a second macro.
function CM.SaveComposedMacro(name, body, onDone, editing)
  if InCombatLockdown() then
    Say("Cannot save a macro while in combat.")
    return false
  end
  name = strtrim(name or "")
  body = NormalizeBody(body)
  if name == "" then
    Say("Enter a macro name.")
    return false
  end
  if #name > MACRO_NAME_MAX then
    Say("Macro names are limited to " .. MACRO_NAME_MAX .. " characters.")
    return false
  end
  if body == "" then
    Say("Enter the macro text to run after the targeting preline.")
    return false
  end
  local text = CM.ComposeMacroText(body)
  if #text > MACRO_MAX then
    Say("Macro is " .. (#text - MACRO_MAX) .. " characters over the " .. MACRO_MAX .. " limit.")
    return false
  end

  if editing and not MacroIndex(editing) then
    editing = nil -- deleted since the editor opened: save as a new macro
  end
  -- Taking the name of a different macro needs confirmation (the one being edited is fine).
  if name ~= editing and MacroIndex(name) then
    CM.UI.Confirm('A macro named "' .. name .. '" already exists. Overwrite it?', function()
      WriteMacro(name, body, text, nil, onDone)
    end)
    return true
  end
  WriteMacro(name, body, text, editing, onDone)
  return true
end

local overflowWarned = {} -- session-only; avoids spamming the same warning

--- Re-edits composed macros whose body no longer matches the active preline.
function CM.RebuildComposedMacros()
  if InCombatLockdown() or not CM.DB then
    return
  end
  for name, body in pairs(Registry()) do
    local current = GetMacroInfo(name) and GetMacroBody(name)
    -- Skip macros the player deleted, or rewrote so they no longer open with a preline
    -- (also protects a same-named macro on another character).
    if current and CM.IsComposedMacroBody(current) then
      local text = CM.ComposeMacroText(body)
      if #text > MACRO_MAX then
        if not overflowWarned[name] then
          overflowWarned[name] = true
          Say(
            'Macro "'
              .. name
              .. '" no longer fits with the current preline; edit it from Reticle Targeting Macros.'
          )
        end
      else
        overflowWarned[name] = nil
        if current ~= text then
          EditMacro(name, nil, nil, text)
        end
      end
    end
  end
end

--- Every macro the player owns (general + character) as { name, icon, body }, sorted by name.
function CM.EnumerateMacros()
  local list, seen = {}, {}
  local globalCount, charCount = GetNumMacros()
  local accountMax = _G.MAX_ACCOUNT_MACROS or DEFAULT_MAX_ACCOUNT_MACROS
  local function Add(index)
    local name, icon, body = GetMacroInfo(index)
    if name and not seen[name] then
      seen[name] = true
      list[#list + 1] = { name = name, icon = icon, body = body or "" }
    end
  end
  for i = 1, globalCount do
    Add(i)
  end
  for i = accountMax + 1, accountMax + charCount do
    Add(i)
  end
  table.sort(list, function(a, b)
    return a.name:lower() < b.name:lower()
  end)
  return list
end

--- True when `body` opens with one of Action Combat Mode's targeting prelines (defaults,
--- saved overrides, or the active one), i.e. the macro carries reticle targeting.
local function MatchingPreline(body)
  if type(body) ~= "string" or body == "" then
    return nil
  end
  local candidates = { Preline() }
  for _, pre in pairs(CM.TargetingMacroPrelinesDefaults or {}) do
    candidates[#candidates + 1] = pre
  end
  local global = CM.DB and CM.DB.global
  if global then
    for _, key in pairs({
      "targetingMacroPrelineAnyOverride",
      "targetingMacroPrelineEnemyOverride",
      "targetingMacroPrelineAutoLockAnyOverride",
      "targetingMacroPrelineAutoLockEnemyOverride",
    }) do
      if type(global[key]) == "string" then
        candidates[#candidates + 1] = strtrim(global[key])
      end
    end
  end
  for _, pre in pairs(candidates) do
    if pre ~= "" and body:sub(1, #pre) == pre then
      return pre
    end
  end
  return nil
end

function CM.IsComposedMacroBody(body)
  return MatchingPreline(body) ~= nil
end

--- The player's part of a macro (what the composer shows below the locked preline): the saved
--- body for composer-made macros, else the live macro text minus its leading preline.
function CM.GetEditableMacroBody(name)
  local saved = CM.GetComposedMacroBody(name)
  if saved then
    return saved
  end
  local body = GetMacroInfo(name) and GetMacroBody(name)
  local pre = MatchingPreline(body)
  if not pre then
    return nil
  end
  return strtrim(body:sub(#pre + 1))
end

--- Macros (general + character) that open with an ACM targeting preline, sorted by name.
function CM.EnumerateComposedMacros()
  local list = {}
  for _, macro in ipairs(CM.EnumerateMacros()) do
    if CM.IsComposedMacroBody(macro.body) then
      list[#list + 1] = macro
    end
  end
  return list
end
