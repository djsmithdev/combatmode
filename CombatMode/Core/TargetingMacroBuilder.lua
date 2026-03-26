---------------------------------------------------------------------------------------
--  Core/TargetingMacroBuilder.lua — reticle targeting macro text
---------------------------------------------------------------------------------------
-- Builds click-cast macro text for reticle targeting (pre-line + /click + @cursor
-- and special-bar / ground-target handling).
--
-- Secure frame creation + SetOverrideBinding plumbing stays in BindingOverrides.lua.
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local C_ActionBar = _G.C_ActionBar
local C_CVar = _G.C_CVar
local C_Spell = _G.C_Spell
local GetActionInfo = _G.GetActionInfo

-- Lua stdlib
local ipairs = _G.ipairs
local pcall = _G.pcall
local strtrim = _G.strtrim
local string = _G.string
local tonumber = _G.tonumber
local type = _G.type

-- Click-cast macro wrapper: binding value (e.g. ACTIONBUTTON1) -> frame name.
-- This mirrors the mapping in BindingOverrides.lua (used for ACTIONBUTTON vs multibars).
local CLICKCAST_BARS = {
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

-- Some clients/setups ignore `/click ActionButtonN LeftButton 0|1` (down arg) on Blizzard bars, causing the
-- macro to do nothing. For addon action buttons (Bartender/ElvUI), the down arg matters to match
-- ActionButtonUseKeyDown. So we only append it for known addon button frames.
local function FormatClickLine(frameName, mouseButton)
  local btn = mouseButton or "LeftButton"
  if IsAddonActionButtonFrame(frameName) then
    local kd = GetActionButtonUseKeyDownMacroSuffix()
    return "/click " .. frameName .. " " .. btn .. " " .. kd
  end
  return "/click " .. frameName .. " " .. btn
end

local function ShouldInjectTargetingForSpell(spellId)
  if not spellId or type(spellId) ~= "number" or spellId <= 0 then
    return false
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

local CLICKCAST_PRE_LINE_ANY =
  "/target [@focus,exists,nodead] focus; [nomounted,@mouseover,exists] mouseover" -- used if reticleTargetingEnemyOnly is OFF- Targets any mouseover unit if it exists.
local CLICKCAST_PRE_LINE_ENEMY =
  "/target [@focus,exists,nodead] focus; [nomounted,@mouseover,harm,nodead][nomounted,@anyenemy,harm,nodead]" --  used if reticleTargetingEnemyOnly is ON - This preline will first try to cast the spell at the unit under the crosshair (mouseover) that is hostile (harm) and alive (nodead). If no unit matches that condition, it tries to find a locked target through the "target" portion of the anyenemy UnitId. If no target exists, it falls back to the "softenemy" UnitId, which is Action Targeting.

-- Returns true if spellId is in the user's "Cast @Cursor Spells" list (comma-separated names in options).
function CM.IsCastAtCursorSpell(spellId)
  if not spellId or spellId <= 0 then
    return false
  end
  local list = CM.DB.char.castAtCursorSpells
  if not list or list == "" then
    return false
  end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then
      set[n] = true
    end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then
    return false
  end
  return set[spellName:lower()] == true
end

-- Returns true if spellId is in the user's "Exclude from targeting" blacklist (no pre-line applied).
function CM.IsExcludedFromTargetingSpell(spellId)
  if not spellId or spellId <= 0 then
    return false
  end
  local list = CM.DB.char.excludeFromTargetingSpells
  if not list or list == "" then
    return false
  end
  local set = {}
  for name in string.gmatch(list, "[^,]+") do
    local n = strtrim(name):lower()
    if n ~= "" then
      set[n] = true
    end
  end
  local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
  local spellName = spellInfo and spellInfo.name
  if not spellName or spellName == "" then
    return false
  end
  return set[spellName:lower()] == true
end

local function GetClickCastPreLine()
  if not CM.DB.char.reticleTargeting then
    return nil
  end
  if CM.DB.char.reticleTargetingEnemyOnly then
    return CLICKCAST_PRE_LINE_ENEMY
  end
  return CLICKCAST_PRE_LINE_ANY
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
    CM.DebugPrint(
      "BuildClickCastMacroText: ACTIONBUTTON" .. buttonNum .. " regularFrame=" .. regularFrame
    )

    local overrideFrame = "OverrideActionBarButton" .. buttonNum
    local overrideClick = IsAddonActionButtonFrame(overrideFrame)
        and (overrideFrame .. " LeftButton " .. GetActionButtonUseKeyDownMacroSuffix())
      or (overrideFrame .. " LeftButton")

    local regularClick = IsAddonActionButtonFrame(regularFrame)
        and (regularFrame .. " LeftButton " .. GetActionButtonUseKeyDownMacroSuffix())
      or (regularFrame .. " LeftButton")

    castLine = "/click [overridebar][possessbar][shapeshift][vehicleui] "
      .. overrideClick
      .. "; "
      .. regularClick
  else
    CM.DebugPrint(
      "BuildClickCastMacroText: " .. bindingValue .. " effectiveFrame=" .. effectiveFrame
    )
    castLine = FormatClickLine(effectiveFrame, "LeftButton")
  end

  -- For ACTIONBUTTON bindings, check slot directly (same as IsSlotMacro) to avoid stale action attributes after dismounting
  if useConditionalClick and buttonNum then
    local slotNum = tonumber(buttonNum)
    if slotNum and slotNum >= 1 and slotNum <= 12 then
      local getOk, atype = pcall(GetActionInfo, slotNum)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
      end
    end
  end

  local ok, actionFrame = pcall(function()
    return _G[effectiveFrame]
  end)
  if ok and actionFrame then
    local rawAction = actionFrame.GetAttribute and actionFrame:GetAttribute("action")
      or actionFrame.action
    local action = rawAction and tonumber(rawAction)
    if action and action > 0 then
      local getOk, atype, id = pcall(GetActionInfo, action)
      if getOk then
        -- Slot is a macro: don't inject pre-line so the macro runs as written (e.g. [mod:shift], [@cursor]).
        if atype == "macro" then
          return castLine
        end
        -- Only wrap targeting logic for spells; items/mounts/etc. should just click normally.
        if atype ~= "spell" then
          return castLine
        end
        -- Special action bar abilities (override, bonus, shapeshift): don't inject pre-line, just click the button directly
        if isSpecialBarButton then
          return castLine
        end
        -- Non-combat spells (e.g. mounts) shouldn't get the targeting pre-line.
        if not ShouldInjectTargetingForSpell(id) then
          return castLine
        end
        -- Ground-targeted spell from whitelist: use /cast [@cursor] only (no pre-line).
        if
          atype == "spell"
          and id
          and type(id) == "number"
          and id > 0
          and CM.IsCastAtCursorSpell(id)
        then
          local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
          local spellName = spellInfo and spellInfo.name
          if spellName and spellName ~= "" then
            return "/cast [@cursor] " .. spellName
          end
          return "/cast [@cursor] spell:" .. id
        end
        -- Spell in blacklist (e.g. self-cast defensives): don't apply targeting pre-line.
        if
          atype == "spell"
          and id
          and type(id) == "number"
          and id > 0
          and CM.IsExcludedFromTargetingSpell(id)
        then
          return castLine
        end
      end
    end
  end

  -- Don't inject preline for special action bar buttons
  if isSpecialBarButton then
    return castLine
  end

  local pre = GetClickCastPreLine()
  -- Do not prefix pre-line with [nooverridebar]; that can be misinterpreted in combat and echo to chat.
  return pre and (pre .. "\n" .. castLine) or castLine
end
