---------------------------------------------------------------------------------------
--  Core/ClickCasting/TargetingMacroBuilder.lua — CLICKCAST — reticle macro text
---------------------------------------------------------------------------------------
--  What it does: Builds the macrotext injected into click-cast proxies: targeting prelines
--  (any vs enemy-only, optional Auto Target Lock variants, with DB overrides), optional
--  Ally Cycle restore post-line, /click bar button or /cast [@cursor] for ground spells,
--  and membership tests for cast-at-cursor / exclude lists (spell IDs).
--  Architecture / how it works:
--    • BuildClickCastMacroText(bindingValue) — no-op text when reticleTargeting off.
--    • Default prelines clear dead focus + dead hostile hard target (friendly corpses
--      kept for res), then /tar (any/enemy + autoLockAny/autoLockEnemy). Overrides from
--      global.targetingMacroPreline*Override keys.
--      char.autoTargetLockOnAttack selects the auto-lock pair. Enemy-only gates the
--      focus branch on harm so a friendly Target Lock does not hijack hostile casts.
--    • Auto-lock prelines: clear dead focus + dead hard target, /tar (soft ,nodead on
--      focus/mouseover branches — harm alone matches corpses), then /focus resync
--      ([nodead] any / [nodead,harm] enemy) so sticky empty-focus cannot leave a dead
--      lock. Cleartarget prevents corpse re-lock on hard target.
--    • Helpful spells (Reticle Targeting): Ignore Friendlies → no /tar (keep friendly hard
--      target). Any → /tar @mouseover if [help], then @softinteract (NPCs), then
--      @anyfriend (players). A hostile under the reticle does not steal a friendly
--      hard target. Not gated on Ally Cycle keybinds (Forever / unbound users).
--      Unclassified + cycle keys bound → treated as help. Harmful + cycle keys →
--      ENEMY / AUTO_LOCK_ENEMY (including solo). Auto-swing uses /startattack or
--      /cast ! or /petattack after /tar. Restore `/targetlasttarget [harm]` is
--      in-group only when cycle keys are bound (not Auto Lock). Its preline also clears a dead
--      focus, falling back to a variant without that line when the whole macro would not fit in 255
--      (SLIMMER_PRELINE: ElvUI / Bartender with key-down).
--    • The /click line omits /click's default args (LeftButton, key-up) and only adds
--      "LeftButton 1" for addon bars with key-down on. CM.TargetingMacroPrelineMaxLen =
--      255 − worst /click cast − newline (140); editor enforces.
--    • IsCastAtCursorSpell / IsExcludedFromTargetingSpell read char CSV spell-ID lists;
--      builtin skyriding IDs from Constants.ReticleTargetingBuiltinExcludeSpellIds.
--    • GetEffectiveBarButtonFrameName uses AddonActionBarResolver for third-party bars.
--    • GetDisplayedActionSlotInfo — currently shown action (live frame action attr,
--      reject stale override 121–132 after dismount, else page/bonus or MultiBar slot).
--      IsSlotMacro / BuildClickCastMacroText / BindingOverrides use this so paged /
--      bonus / secondary bar macros are not misclassified as page-1 spells.
--    • Single-Button Assistant (Assisted Combat) buttons are detected live
--      (C_ActionBar.IsAssistedCombatAction, assistant spell id fallback) and always get the
--      harmful targeting route instead of being classified by their churning suggested spell.
--    • Click frame map from CM.Constants.ClickCastBars (ACTIONBUTTON + MultiBar 1–7).
--  Does not: Own SecureActionButton frames or SetOverrideBinding (BindingOverrides).
--  Related: Core/ClickCasting/BindingOverrides.lua,
--  Core/AllyCycle/{AllyCycle,Cycle}.lua,
--  UI/Editors/TargetingMacroPrelinesEditor.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/SpellMultiSelect.lua,
--  Constants/DatabaseDefaults.lua, Constants/Gameplay.lua,
--  Core/ClickCasting/AddonActionBarResolver.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_ActionBar = _G.C_ActionBar
local C_AssistedCombat = _G.C_AssistedCombat
local C_CVar = _G.C_CVar
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local GetActionInfo = _G.GetActionInfo
local IsInGroup = _G.IsInGroup

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local strtrim = _G.strtrim
local string = _G.string
local tonumber = _G.tonumber
local type = _G.type

-- Click-cast macro wrapper: binding value (e.g. ACTIONBUTTON1) -> frame name.
-- Shared map includes ACTIONBUTTON + MULTIACTIONBAR1–7 (MultiBar5–7 = DF+ bars).
local CLICKCAST_BARS = CM.Constants.ClickCastBars
  or {
    { bind = "ACTIONBUTTON", frame = "ActionButton", count = 12 },
    { bind = "MULTIACTIONBAR1BUTTON", frame = "MultiBarBottomLeftButton", count = 12 },
    { bind = "MULTIACTIONBAR2BUTTON", frame = "MultiBarBottomRightButton", count = 12 },
    { bind = "MULTIACTIONBAR3BUTTON", frame = "MultiBarRightButton", count = 12 },
    { bind = "MULTIACTIONBAR4BUTTON", frame = "MultiBarLeftButton", count = 12 },
  }

local BindingToClickFrame = {}
for _, bar in ipairs(CLICKCAST_BARS) do
  for i = 1, bar.count do
    BindingToClickFrame[bar.bind .. i] = bar.frame .. i
  end
end

-- Helper function to check which action bar type is currently active.
-- Returns the frame prefix for the active bar type, or nil if using default bar.
local function GetActiveActionBarType()
  if C_ActionBar then
    -- Check for override action bar (vehicles, quest UIs, etc.)
    if C_ActionBar.HasOverrideActionBar and C_ActionBar.HasOverrideActionBar() then
      return "OverrideActionBarButton"
    end
    -- Check for bonus action bar (druid forms, rogue stealth, etc.)
    if C_ActionBar.HasBonusActionBar and C_ActionBar.HasBonusActionBar() then
      return "BonusActionButton"
    end
    -- Check for extra action bar (encounter-specific abilities)
    if C_ActionBar.HasExtraActionBar and C_ActionBar.HasExtraActionBar() then
      -- Extra action bar uses ExtraActionButton1, not ACTIONBUTTON bindings
      return nil
    end
    -- Check for temp shapeshift action bar
    if C_ActionBar.HasTempShapeshiftActionBar and C_ActionBar.HasTempShapeshiftActionBar() then
      return "TempShapeshiftActionButton"
    end
  end

  -- Fallback to frame visibility check for override bar (for older clients or if API unavailable)
  local overrideBar = _G.OverrideActionBar
  if overrideBar and overrideBar:IsShown() then
    return "OverrideActionBarButton"
  end

  -- Default action bar
  return nil
end

-- Helper function to resolve the correct frame name for ACTIONBUTTON bindings.
-- Checks for OverrideActionBarButton, BonusActionButton, or TempShapeshiftActionButton when active,
-- falls back to ActionButton otherwise.
local function ResolveActionButtonFrame(bindingValue)
  if not bindingValue:match("^ACTIONBUTTON") then
    -- Not an ACTIONBUTTON binding, return the mapped frame directly
    return BindingToClickFrame[bindingValue]
  end

  -- Extract button number from binding (e.g., "ACTIONBUTTON5" -> 5)
  local buttonNum = bindingValue:match("(%d+)$")
  if not buttonNum then
    return BindingToClickFrame[bindingValue]
  end

  -- Check which action bar type is currently active
  local activeBarType = GetActiveActionBarType()
  if activeBarType then
    local frameName = activeBarType .. buttonNum
    local ok, actionFrame = pcall(function()
      return _G[frameName]
    end)
    if ok and actionFrame then
      -- Check if the frame has an action assigned
      local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action")
        or actionFrame.action
      local action = rawAction and tonumber(rawAction)
      if action and action > 0 then
        return frameName
      end
    end
  end

  -- Fall back to regular ActionButton
  return BindingToClickFrame[bindingValue]
end

-- Primary action bar slot index (1–12): frame names used by common bar replacement addons for bar 1.
-- First match that exists and is shown wins; then first that exists; else caller uses ActionButtonN.
local PRIMARY_BAR_FRAME_CANDIDATES = {
  function(i)
    return "ElvUI_Bar1Button" .. i
  end,
  function(i)
    return "BT4Button" .. i
  end,
}

local function FindPrimaryBarButtonFrame(index)
  local n = tonumber(index)
  if not n or n < 1 or n > 12 then
    return nil
  end

  for _, makeName in ipairs(PRIMARY_BAR_FRAME_CANDIDATES) do
    local name = makeName(n)
    local f = _G[name]
    if f then
      local ok, shown = pcall(function()
        return f.IsShown and f:IsShown()
      end)
      if ok and shown then
        return name
      end
    end
  end

  for _, makeName in ipairs(PRIMARY_BAR_FRAME_CANDIDATES) do
    local name = makeName(n)
    if _G[name] then
      return name
    end
  end

  return nil
end

-- Some action bar addons require matching the /click "down" arg to ActionButtonUseKeyDown so secure clicks fire.
local function GetActionButtonUseKeyDownMacroSuffix()
  local v = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("ActionButtonUseKeyDown")
  if v == "1" then
    return "1"
  end
  return "0"
end

local function IsAddonActionButtonFrame(frameName)
  if not frameName or frameName == "" then
    return false
  end
  return frameName:match("^BT4Button") ~= nil or frameName:match("^ElvUI_Bar") ~= nil
end

-- Frame state the macro checks at run time to click the override-bar button instead of the main bar's.
local CLICK_BAR_STATE_CONDITIONS = "[overridebar][possessbar][shapeshift][vehicleui]"

-- Arguments after the frame name. /click defaults to LeftButton and to a key-up click (a down arg of
-- 0 is the same as none), so they are left out to keep the macro short. Some addon action buttons
-- (Bartender/ElvUI) need the down arg to match ActionButtonUseKeyDown for secure clicks to fire,
-- so only for them and only when key-down is on we pass "LeftButton 1" (down needs the button).
local function ClickArgs(frameName)
  if IsAddonActionButtonFrame(frameName) and GetActionButtonUseKeyDownMacroSuffix() == "1" then
    return " LeftButton 1"
  end
  return ""
end

local function FormatClickLine(frameName)
  return "/click " .. frameName .. ClickArgs(frameName)
end

-- Auto Attack / Auto Shot / Shoot / Pet Attack are combat swings, not IsSpellHarmful.
local AUTO_SWING_KIND = {
  [6603] = "attack",
  [75] = "shot",
  [5019] = "shoot",
  [287988] = "pet",
}

local function AutoSwingKind(spellId)
  return AUTO_SWING_KIND[spellId]
end

local function AutoSwingSwapCommand(kind, spellId)
  if kind == "shot" or kind == "shoot" then
    local name
    if C_Spell and C_Spell.GetSpellInfo and spellId then
      local info = C_Spell.GetSpellInfo(spellId)
      name = info and info.name
    end
    if type(name) == "string" and name ~= "" then
      return "/cast !" .. name
    end
    return "/cast !spell:" .. tostring(spellId)
  end
  if kind == "pet" then
    return "/petattack"
  end
  return "/startattack"
end

local function IsAutoSwingSpell(spellId)
  if type(spellId) ~= "number" or spellId <= 0 then
    return false
  end
  if AutoSwingKind(spellId) then
    return true
  end
  if C_Spell and C_Spell.IsAutoRepeatSpell then
    local ok, isRepeat = pcall(C_Spell.IsAutoRepeatSpell, spellId)
    if ok and isRepeat then
      return true
    end
  end
  local IsAutoRepeatSpell = _G.IsAutoRepeatSpell
  if IsAutoRepeatSpell then
    local ok, isRepeat = pcall(IsAutoRepeatSpell, spellId)
    return ok and isRepeat or false
  end
  return false
end

local function ShouldInjectTargetingForSpell(spellId)
  if not spellId or type(spellId) ~= "number" or spellId <= 0 then
    return false
  end
  if IsAutoSwingSpell(spellId) then
    return true
  end
  -- Only inject targeting logic for actual combat spells (helpful/harmful).
  -- Use C_Spell helpers (spellId-based). If unavailable, fall back to injecting for spells
  -- unless explicitly excluded elsewhere.
  if C_Spell and C_Spell.IsSpellHelpful and C_Spell.IsSpellHarmful then
    local okHelp, isHelp = pcall(C_Spell.IsSpellHelpful, spellId)
    local okHarm, isHarm = pcall(C_Spell.IsSpellHarmful, spellId)
    return (okHelp and isHelp) or (okHarm and isHarm) or false
  end
  return true
end

local function IsSpecialLogicalBarFrameName(frameName)
  if not frameName then
    return false
  end
  return frameName:match("^OverrideActionBarButton")
    or frameName:match("^BonusActionButton")
    or frameName:match("^TempShapeshiftActionButton")
end

function CM.IsSpecialLogicalBarFrameName(frameName)
  return IsSpecialLogicalBarFrameName(frameName) and true or false
end

-- Override / vehicle / possess / temp-shapeshift bars use action slots 121–132.
-- After dismount the button attribute can linger; reject those when the bar is gone.
local OVERRIDE_ACTION_MIN = 121
local OVERRIDE_ACTION_MAX = 132

local function IsOverrideStyleBarActive()
  if C_ActionBar then
    if C_ActionBar.HasOverrideActionBar then
      local ok, v = pcall(C_ActionBar.HasOverrideActionBar)
      if ok and v then
        return true
      end
    end
    if C_ActionBar.HasVehicleActionBar then
      local ok, v = pcall(C_ActionBar.HasVehicleActionBar)
      if ok and v then
        return true
      end
    end
    if C_ActionBar.HasTempShapeshiftActionBar then
      local ok, v = pcall(C_ActionBar.HasTempShapeshiftActionBar)
      if ok and v then
        return true
      end
    end
  end
  local overrideBar = _G.OverrideActionBar
  if overrideBar then
    local ok, shown = pcall(function()
      return overrideBar.IsShown and overrideBar:IsShown()
    end)
    if ok and shown then
      return true
    end
  end
  return false
end

local function IsStaleOverrideAction(action)
  if not action or action < OVERRIDE_ACTION_MIN or action > OVERRIDE_ACTION_MAX then
    return false
  end
  return not IsOverrideStyleBarActive()
end

local function GetActionBarPageSafe()
  if C_ActionBar and C_ActionBar.GetActionBarPage then
    local ok, page = pcall(C_ActionBar.GetActionBarPage)
    if ok and type(page) == "number" and page > 0 then
      return page
    end
  end
  local GetActionBarPage = _G.GetActionBarPage
  if GetActionBarPage then
    local ok, page = pcall(GetActionBarPage)
    if ok and type(page) == "number" and page > 0 then
      return page
    end
  end
  return 1
end

local function GetBonusBarOffsetSafe()
  if C_ActionBar and C_ActionBar.GetBonusBarOffset then
    local ok, offset = pcall(C_ActionBar.GetBonusBarOffset)
    if ok and type(offset) == "number" then
      return offset
    end
  end
  local GetBonusBarOffset = _G.GetBonusBarOffset
  if GetBonusBarOffset then
    local ok, offset = pcall(GetBonusBarOffset)
    if ok and type(offset) == "number" then
      return offset
    end
  end
  return 0
end

local function HasBonusActionBarSafe()
  if C_ActionBar and C_ActionBar.HasBonusActionBar then
    local ok, v = pcall(C_ActionBar.HasBonusActionBar)
    if ok and v then
      return true
    end
  end
  return GetBonusBarOffsetSafe() ~= 0
end

-- ACTIONBUTTON index → action slot for the currently paged / bonus bar.
local function ComputeActionButtonSlot(buttonNum)
  local id = tonumber(buttonNum)
  local buttons = tonumber(_G.NUM_ACTIONBAR_BUTTONS) or 12
  if not id or id < 1 or id > buttons then
    return nil
  end
  local pages = tonumber(_G.NUM_ACTIONBAR_PAGES) or 6
  local bonusOffset = GetBonusBarOffsetSafe()
  if HasBonusActionBarSafe() and bonusOffset ~= 0 then
    return id + ((pages + bonusOffset - 1) * buttons)
  end
  local page = GetActionBarPageSafe()
  return id + ((page - 1) * buttons)
end

local function ReadFrameActionId(frameName)
  if not frameName then
    return nil
  end
  local ok, actionFrame = pcall(function()
    return _G[frameName]
  end)
  if not ok or not actionFrame then
    return nil
  end
  local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action")
    or actionFrame.action
  local action = rawAction and tonumber(rawAction)
  if not action or action <= 0 then
    return nil
  end
  if IsStaleOverrideAction(action) then
    return nil
  end
  return action
end

--- Currently displayed action for ACTIONBUTTON / MULTIACTIONBAR* bindings.
--- Prefers the live button action attribute; rejects stale override slots (121–132)
--- after dismount; falls back to page/bonus math or ResolveClickCastBindingToActionSlot.
function CM.GetDisplayedActionSlotInfo(bindingValue)
  if not bindingValue or bindingValue == "" then
    return nil
  end

  local frameName = CM.GetEffectiveBarButtonFrameName(bindingValue)
  local action = ReadFrameActionId(frameName)

  if not action then
    local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
    if buttonNum then
      action = ComputeActionButtonSlot(buttonNum)
    elseif CM.ResolveClickCastBindingToActionSlot then
      action = CM.ResolveClickCastBindingToActionSlot(bindingValue)
    end
  end

  if not action or action <= 0 then
    return nil
  end

  local getOk, atype, id = pcall(GetActionInfo, action)
  if not getOk then
    return nil
  end
  return atype, id, action
end

local function ResolveAddonMultiBarButtonFrame(bindingValue)
  local prefix, slotStr = bindingValue:match("^(MULTIACTIONBAR%d+BUTTON)(%d+)$")
  if not prefix or not slotStr then
    return nil
  end
  local btnIdx = tonumber(slotStr)
  if not btnIdx or btnIdx < 1 or btnIdx > 12 then
    return nil
  end

  local baseFrame = ResolveActionButtonFrame(bindingValue)
  if not baseFrame then
    return nil
  end

  -- Resolve lives in AddonActionBarResolver.lua; it matches addon action slots
  -- by reading action from the Blizzard base multibar frame.
  return CM.ResolveAddonMultiBarButtonFrameByBase(prefix, btnIdx, baseFrame)
end

-- Frame to read action from and /click for macros: addon replacement bar when present, else Blizzard.
function CM.GetEffectiveBarButtonFrameName(bindingValue)
  local base = ResolveActionButtonFrame(bindingValue)
  if not base then
    return nil
  end

  local actionBtnNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  if actionBtnNum then
    if not IsSpecialLogicalBarFrameName(base) then
      return FindPrimaryBarButtonFrame(actionBtnNum) or base
    end
    return base
  end

  if bindingValue:match("^MULTIACTIONBAR%d+BUTTON%d+$") then
    return ResolveAddonMultiBarButtonFrame(bindingValue) or base
  end

  return base
end

-- Shared note: a condition group with ONLY @unit (no boolean) is ALWAYS true — use
-- ,exists / harm / nodead / nomounted / etc. so fallthrough works. @unit still implies
-- exists when paired with those booleans (harm/nodead already require exists).
-- After /clearfocus [@focus,dead], focus retarget need not repeat ,nodead.
-- /tar is a valid alias for /target. Do not use /f — that is /follow, not /focus.
-- @anyenemy is hostile-only — ,harm is redundant on it.
-- @anyfriend is players (target / softfriend). Friendly NPCs are @softinteract.

-- Full macrotext = preline + "\n" + /click [+ optional post-line]. Hard engine
-- limit is 255 (patch 11.0.2). Same patch: macrotext cannot /click another
-- macro-executing button — do not split onto a second type=macro SecureActionButton.
local SECURE_MACROTEXT_MAX = 255
-- Longest cast line BuildClickCastMacroText emits: the ACTIONBUTTON conditional /click with the
-- override frame (OverrideActionBarButton12) and an ElvUI primary bar (ElvUI_Bar1Button12) that
-- needs the key-down arg.
local CLICKCAST_WORST_CAST_LINE_LEN = #(
  "/click "
  .. CLICK_BAR_STATE_CONDITIONS
  .. " OverrideActionBarButton12; ElvUI_Bar1Button12 LeftButton 1"
)
-- Max editable preline so pre + newline + worst cast stays within SECURE_MACROTEXT_MAX.
CM.TargetingMacroPrelineMaxLen = SECURE_MACROTEXT_MAX - CLICKCAST_WORST_CAST_LINE_LEN - 1

-- Regular (Auto Target Lock OFF), Ignore Friendlies OFF:
-- Clear dead focus + dead *hostile* hard target (keep friendly corpses for res).
local CLICKCAST_PRE_LINE_ANY = "/clearfocus [@focus,dead]\n"
  .. "/cleartarget [dead,harm]\n"
  .. "/tar [@focus,exists];[nomounted,@mouseover]"

-- Regular (Auto Target Lock OFF), Ignore Friendlies ON:
-- Clear dead focus + dead hostile hard target. Focus branch gated on harm so a friendly
-- Target Lock (e.g. a party member) is ignored for hostile casts. Otherwise: mouseover
-- hostile+alive under the crosshair; else anyenemy (hard target, then softenemy /
-- Action Targeting). Soft ,nodead kept on mouseover; dropped on @anyenemy (hostile
-- corpse already cleared).
local CLICKCAST_PRE_LINE_ENEMY = "/clearfocus [@focus,dead]\n"
  .. "/cleartarget [dead,harm]\n"
  .. "/tar [@focus,harm];[nomounted,@mouseover,harm,nodead][nomounted,@anyenemy]"

-- Auto Target Lock ON — shared behavior:
-- Must leave room for the longest /click cast line under the 255-char macrotext cap.
-- Clear dead focus AND dead hostile hard target — otherwise a hostile corpse stays
-- selected and [@focus,noexists] can re-lock it. Friendly dead targets are left alone
-- (battle res). Then retarget; resync focus each click ([nodead] / [nodead,harm]) so
-- a dead lock cannot persist when clearfocus misses. [dead,harm] on /cleartarget
-- defaults to @target. Focus branches must include ,nodead — ,harm / ,exists alone
-- still match corpses.

-- Auto Target Lock ON, Ignore Friendlies OFF:
-- Attack-driven: soft-target harm+alive. [@focus,nodead] skips a dead lock for /tar.
local CLICKCAST_PRE_LINE_AUTO_LOCK_ANY = "/clearfocus [@focus,dead]\n"
  .. "/cleartarget [dead,harm]\n"
  .. "/tar [@focus,nodead];[@mouseover,harm,nodead]\n"
  .. "/focus [nodead]"

-- Auto Target Lock ON, Ignore Friendlies ON:
-- ,nodead on the focus and mouseover branches (a dead hostile under the reticle is not picked up);
-- resync /focus [nodead,harm] (replaces sticky noexists). Mounted (skyriding) abilities are
-- excluded from targeting by the builtin exclude list, so there is no [nomounted] here.
local CLICKCAST_PRE_LINE_AUTO_LOCK_ENEMY = "/clearfocus [@focus,dead]\n"
  .. "/cleartarget [dead,harm]\n"
  .. "/tar [@focus,harm,nodead][@mouseover,harm,nodead][@anyenemy]\n"
  .. "/focus [nodead,harm]"

-- Export defaults so the prelines editor can show a starting point even when no override exists.
CM.TargetingMacroPrelinesDefaults = {
  any = CLICKCAST_PRE_LINE_ANY,
  enemy = CLICKCAST_PRE_LINE_ENEMY,
  autoLockAny = CLICKCAST_PRE_LINE_AUTO_LOCK_ANY,
  autoLockEnemy = CLICKCAST_PRE_LINE_AUTO_LOCK_ENEMY,
}

--- Builds a set of numeric spell IDs from a CSV list. Numeric tokens are used as-is;
--- legacy name tokens are resolved via C_Spell.GetSpellInfo when possible.
local function ParseSpellListIds(list)
  if not list or list == "" then
    return nil
  end
  local ids = {}
  local any = false
  for entry in string.gmatch(list, "[^,]+") do
    local token = strtrim(entry)
    if token ~= "" then
      local idText = token:gsub("^#", "")
      local id = tonumber(idText)
      if id and id > 0 then
        ids[id] = true
        any = true
      elseif C_Spell and C_Spell.GetSpellInfo then
        local si = C_Spell.GetSpellInfo(token)
        local spellId = si and (si.spellID or si.spellId)
        if spellId and spellId > 0 then
          ids[spellId] = true
          any = true
        end
      end
    end
  end
  if not any then
    return nil
  end
  return ids
end

local function RelatedSpellIds(spellId)
  local related = { [spellId] = true }
  if C_SpellBook and C_SpellBook.FindBaseSpellByID then
    local base = C_SpellBook.FindBaseSpellByID(spellId)
    if base and base > 0 then
      related[base] = true
    end
  end
  if C_SpellBook and C_SpellBook.FindSpellOverrideByID then
    local override = C_SpellBook.FindSpellOverrideByID(spellId)
    if override and override > 0 then
      related[override] = true
    end
  end
  return related
end

local function SpellListContains(list, spellId)
  if not spellId or spellId <= 0 then
    return false
  end
  local ids = ParseSpellListIds(list)
  if not ids then
    return false
  end
  for id in pairs(RelatedSpellIds(spellId)) do
    if ids[id] then
      return true
    end
  end
  return false
end

-- Returns true if spellId is in the user's cast-at-crosshair list (CSV of spell IDs).
function CM.IsCastAtCursorSpell(spellId)
  return SpellListContains(CM.DB.char.castAtCursorSpells, spellId)
end

local function BuiltinExcludeContains(spellId)
  local builtin = CM.Constants and CM.Constants.ReticleTargetingBuiltinExcludeSpellIds
  if not builtin or not spellId or spellId <= 0 then
    return false
  end
  for id in pairs(RelatedSpellIds(spellId)) do
    if builtin[id] then
      return true
    end
  end
  return false
end

-- Returns true if spellId is in the exclude-from-targeting list (CSV of spell IDs)
-- or the builtin skyriding set (not shown in options).
function CM.IsExcludedFromTargetingSpell(spellId)
  return BuiltinExcludeContains(spellId)
    or SpellListContains(CM.DB.char.excludeFromTargetingSpells, spellId)
end

-- Helpful: Ignore Friendlies = do not /tar. Any = reticle /tar helpable mouseover, NPCs, players
-- (not unfiltered mouseover — that would /tar a hostile and drop a cycled ally).
local CLICKCAST_PRE_LINE_ALLY_HELP = "/clearfocus [@focus,dead]"
local CLICKCAST_PRE_LINE_ALLY_HELP_ANY = "/clearfocus [@focus,dead]\n"
  .. "/tar [nomounted,@mouseover,help,nodead][nomounted,@softinteract,exists][nomounted,@anyfriend,exists]"

-- Same as ENEMY (clears a dead focus too). Keeps [@focus,harm] so hostile Target Lock still wins
-- /tar. With the /targetlasttarget post-line this can overflow the 255-char cap on setups with a
-- long /click line (ElvUI / Bartender with key-down), so it falls back to the slimmer variant below
-- (no dead-focus clear) whenever the whole macro would not fit.
local CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE_SLIM = "/cleartarget [dead,harm]\n"
  .. "/tar [@focus,harm];[nomounted,@mouseover,harm,nodead][nomounted,@anyenemy]"
local CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE = "/clearfocus [@focus,dead]\n"
  .. CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE_SLIM
local CLICKCAST_POST_LINE_ALLY_HARM_RESTORE = "/targetlasttarget [harm]"

-- Prelines with a slimmer stand-in, used when the assembled macro is over SECURE_MACROTEXT_MAX.
local SLIMMER_PRELINE = {
  [CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE] = CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE_SLIM,
}

local function AllyCycleRestoreAfterHarm()
  return CM.IsAllyCycleRestoreAfterHarm and CM.IsAllyCycleRestoreAfterHarm()
end

local function GetAllyCycleHarmPreLine()
  if CM.DbBool(CM.DB.char.autoTargetLockOnAttack, false) then
    return CLICKCAST_PRE_LINE_AUTO_LOCK_ENEMY
  end
  if AllyCycleRestoreAfterHarm() then
    return CLICKCAST_PRE_LINE_ALLY_HARM_RESTORE
  end
  return CLICKCAST_PRE_LINE_ENEMY
end

local function GetAllyCycleHarmPostLine()
  if CM.DbBool(CM.DB.char.autoTargetLockOnAttack, false) then
    return nil
  end
  if not AllyCycleRestoreAfterHarm() then
    return nil
  end
  return CLICKCAST_POST_LINE_ALLY_HARM_RESTORE
end

--- Classify spell for Ally Cycle routing. Dual help+harm → help (stick to ally).
--- True for a Single-Button Assistant (Assisted Combat) action button. Its slot shows whichever
--- spell is currently suggested, and that churns (and is a non-combat or placeholder spell right
--- after loading), so classifying it by spell would leave the targeting pre-line off. The slot
--- check is live (not the cached slot set), with the assistant spell id as a fallback.
local function IsAssistedCombatButton(slot, spellId)
  if slot and C_ActionBar and C_ActionBar.IsAssistedCombatAction then
    local ok, isAssisted = pcall(C_ActionBar.IsAssistedCombatAction, slot)
    if ok and isAssisted then
      return true
    end
  end
  if slot and CM.IsAssistedCombatActionSlot and CM.IsAssistedCombatActionSlot(slot) then
    return true
  end
  if spellId and C_AssistedCombat and C_AssistedCombat.GetActionSpell then
    local ok, assistantSpell = pcall(C_AssistedCombat.GetActionSpell)
    if ok and assistantSpell and assistantSpell == spellId then
      return true
    end
  end
  return false
end

local function GetAllyCycleSpellRoute(spellId)
  if not spellId or type(spellId) ~= "number" or spellId <= 0 then
    return nil
  end
  if IsAutoSwingSpell(spellId) then
    return "harm"
  end
  if not (C_Spell and C_Spell.IsSpellHelpful and C_Spell.IsSpellHarmful) then
    return nil
  end
  local okHelp, isHelp = pcall(C_Spell.IsSpellHelpful, spellId)
  local okHarm, isHarm = pcall(C_Spell.IsSpellHarmful, spellId)
  isHelp = okHelp and isHelp
  isHarm = okHarm and isHarm
  if isHelp then
    return "help"
  end
  if isHarm then
    return "harm"
  end
  return nil
end

-- Cycle Up/Down bound. Gates harm/restore routing only — not helpful prelines.
local function AllyCycleKeysBound()
  return CM.IsAllyCycleEnabled and CM.IsAllyCycleEnabled()
end

local function AllyCycleInGroup()
  return IsInGroup and IsInGroup()
end

local function FriendlyPreservingHelpPreLine()
  if CM.DbBool(CM.DB.char.reticleTargetingEnemyOnly, true) then
    return CLICKCAST_PRE_LINE_ALLY_HELP
  end
  return CLICKCAST_PRE_LINE_ALLY_HELP_ANY
end

local function GetClickCastPreLine(spellId, routeOverride)
  if not CM.DB.char.reticleTargeting then
    return nil
  end

  local route = routeOverride or GetAllyCycleSpellRoute(spellId)

  -- Helpful: Reticle Targeting friendly-preserving path (not Ally Cycle–gated).
  if route == "help" then
    return FriendlyPreservingHelpPreLine()
  end

  -- Harmful + cycle keys: enemy / restore-aware preline (including solo).
  if AllyCycleKeysBound() and route == "harm" then
    return GetAllyCycleHarmPreLine()
  end

  -- Unclassified + cycle keys: treat as help (same as when cycling is on).
  if AllyCycleKeysBound() then
    return FriendlyPreservingHelpPreLine()
  end

  local function GetOverride(key)
    local v = CM.DB and CM.DB.global and CM.DB.global[key]
    if type(v) ~= "string" then
      return nil
    end
    v = strtrim(v)
    if v == "" then
      return nil
    end
    -- Oversized saved overrides would truncate the trailing /click; ignore them.
    local maxLen = CM.TargetingMacroPrelineMaxLen
    if maxLen and #v > maxLen then
      return nil
    end
    return v
  end

  local autoLock = CM.DbBool(CM.DB.char.autoTargetLockOnAttack, false)
  if CM.DbBool(CM.DB.char.reticleTargetingEnemyOnly, true) then
    if autoLock then
      return GetOverride("targetingMacroPrelineAutoLockEnemyOverride")
        or CLICKCAST_PRE_LINE_AUTO_LOCK_ENEMY
    end
    return GetOverride("targetingMacroPrelineEnemyOverride") or CLICKCAST_PRE_LINE_ENEMY
  end
  if autoLock then
    return GetOverride("targetingMacroPrelineAutoLockAnyOverride")
      or CLICKCAST_PRE_LINE_AUTO_LOCK_ANY
  end
  return GetOverride("targetingMacroPrelineAnyOverride") or CLICKCAST_PRE_LINE_ANY
end

local function GetClickCastPostLine(spellId, routeOverride)
  if not CM.DB.char.reticleTargeting then
    return nil
  end
  if not (AllyCycleKeysBound() and AllyCycleInGroup()) then
    return nil
  end
  if (routeOverride or GetAllyCycleSpellRoute(spellId)) ~= "harm" then
    return nil
  end
  return GetAllyCycleHarmPostLine()
end

function CM.BuildClickCastMacroText(bindingValue)
  -- When reticle targeting is off, no macro wrapping (no pre-line, no castAtCursor, no excludeFromTargeting).
  if not CM.DB.char.reticleTargeting then
    return nil
  end

  -- For ACTIONBUTTON bindings, use a conditional /click so action bar type is resolved
  -- at macro run time (works when action bars change in combat; we can't refresh bindings then).
  local buttonNum = bindingValue:match("^ACTIONBUTTON(%d+)$")
  local useConditionalClick = buttonNum ~= nil

  local clickFrame = ResolveActionButtonFrame(bindingValue)
  if not clickFrame then
    return nil
  end
  local effectiveFrame = CM.GetEffectiveBarButtonFrameName(bindingValue) or clickFrame

  -- Check if this is a special action bar button (don't inject preline for special bar abilities)
  local isSpecialBarButton = clickFrame:match("^OverrideActionBarButton")
    or clickFrame:match("^BonusActionButton")
    or clickFrame:match("^TempShapeshiftActionButton")

  local castLine
  if useConditionalClick then
    -- Use conditional macro to check for override bar at runtime
    -- (works when exiting vehicle in combat; we can't refresh bindings then)
    -- For bonus/shapeshift bars, bindings are refreshed via events when out of combat
    local regularFrame = FindPrimaryBarButtonFrame(buttonNum) or ("ActionButton" .. buttonNum)

    local overrideFrame = "OverrideActionBarButton" .. buttonNum
    castLine = "/click "
      .. CLICK_BAR_STATE_CONDITIONS
      .. " "
      .. overrideFrame
      .. ClickArgs(overrideFrame)
      .. "; "
      .. regularFrame
      .. ClickArgs(regularFrame)
  else
    castLine = FormatClickLine(effectiveFrame)
  end

  -- Classify from the currently displayed slot (paged / bonus / override-aware).
  -- Macros: no pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
  local atype, id, slot = CM.GetDisplayedActionSlotInfo(bindingValue)
  local spellIdForPreline
  -- Single-Button Assistant: its slot spell is whatever is suggested right now, so it is never
  -- classified by spell. It gets the harmful targeting route and skips the spell-based exclude /
  -- cast-at-cursor / combat-spell checks (which would otherwise drop the pre-line whenever the
  -- suggestion is a non-combat or placeholder spell, e.g. right after loading).
  local isAssistedButton = false
  if atype == "macro" then
    return castLine
  end
  if atype then
    local idNum = tonumber(id)
    isAssistedButton = IsAssistedCombatButton(slot, idNum)
    -- Auto-swing / Pet Attack IDs can show up as non-spell action types.
    if not isAssistedButton and atype ~= "spell" and not IsAutoSwingSpell(idNum) then
      return castLine
    end
    if idNum and idNum > 0 and not isAssistedButton then
      spellIdForPreline = idNum
    end
    -- Special action bar abilities (override, bonus, shapeshift): don't inject pre-line, just click the button directly
    if isSpecialBarButton then
      return castLine
    end
    -- Spell in blacklist (e.g. self-cast defensives): don't apply targeting pre-line.
    if
      not isAssistedButton
      and spellIdForPreline
      and CM.IsExcludedFromTargetingSpell(spellIdForPreline)
    then
      return castLine
    end
    -- Ground-targeted spell from whitelist: use /cast [@cursor] only (no pre-line).
    -- Must run before ShouldInjectTargetingForSpell: many ground spells are neither helpful nor harmful per C_Spell API.
    if not isAssistedButton and spellIdForPreline and CM.IsCastAtCursorSpell(spellIdForPreline) then
      local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellIdForPreline)
      local spellName = spellInfo and spellInfo.name
      if spellName and spellName ~= "" then
        return "/cast [@cursor] " .. spellName
      end
      return "/cast [@cursor] spell:" .. spellIdForPreline
    end
    -- Non-combat spells (e.g. mounts) shouldn't get the targeting pre-line.
    if not isAssistedButton and not ShouldInjectTargetingForSpell(spellIdForPreline) then
      return castLine
    end
  end

  -- Don't inject preline for special action bar buttons
  if isSpecialBarButton then
    return castLine
  end

  -- /click Attack after /tar toggles relative to "already swinging," so a swap
  -- turns the ability off. /startattack and /cast ! only start (or keep) the swing.
  if IsAutoSwingSpell(spellIdForPreline) then
    local kind = AutoSwingKind(spellIdForPreline) or "attack"
    local pre = GetClickCastPreLine(spellIdForPreline)
    local swapCmd = AutoSwingSwapCommand(kind, spellIdForPreline)
    return pre and (pre .. "\n" .. swapCmd) or swapCmd
  end

  local routeOverride = isAssistedButton and "harm" or nil
  local pre = GetClickCastPreLine(spellIdForPreline, routeOverride)
  local post = GetClickCastPostLine(spellIdForPreline, routeOverride)
  -- Do not prefix pre-line with [nooverridebar]; that can be misinterpreted in combat and echo to chat.
  local function Assemble(preLine)
    local text = castLine
    if preLine then
      text = preLine .. "\n" .. text
    end
    if post then
      text = text .. "\n" .. post
    end
    return text
  end
  local text = Assemble(pre)
  -- A preline with a slimmer stand-in gives way when the whole macro would not fit in 255.
  local slimmer = pre and SLIMMER_PRELINE[pre]
  if slimmer and #text > SECURE_MACROTEXT_MAX then
    text = Assemble(slimmer)
  end
  return text
end
