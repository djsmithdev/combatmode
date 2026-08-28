---------------------------------------------------------------------------------------
--  Core/PartyRadial/SecureBindings.lua — PARTYRADIAL — secure slice attributes
---------------------------------------------------------------------------------------
--  What it does: Builds SecureActionButton modified attributes (macrotext / target) for
--  party slices and resolves action-bar slots from Click Casting bindings.
--  Architecture / how it works:
--    • CM.PartyRadialSecure: UpdateSecureButtonTargets, UpdateSliceActionAttributes,
--      BuildButtonAttrMap.
--    • Attribute updates only out of combat (queues pendingUpdate on RadialState).
--  Does not: Own roster data, visuals, show/hide lifecycle, or mouselook overrides
--  (Party Radial opens via keybind only).
--  Related: Core/PartyRadial/PartyData.lua, PartyRadial.lua,
--  Core/ClickCasting/AddonActionBarResolver.lua, Core/ClickCasting/BindingOverrides.lua,
--  Constants/Gameplay.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetActionInfo = _G.GetActionInfo
local GetItemInfo = _G.C_Item.GetItemInfo
local GetMacroBody = _G.GetMacroBody
local GetSpellName = _G.C_Spell.GetSpellName
local InCombatLockdown = _G.InCombatLockdown

-- Lua stdlib
local ipairs = _G.ipairs
local pcall = _G.pcall
local tonumber = _G.tonumber
local type = _G.type

local HR = CM.PartyRadial
local Secure = {}
CM.PartyRadialSecure = Secure

local function GetState()
  return HR.GetState()
end

---------------------------------------------------------------------------------------
--                    MODIFIED ATTRIBUTE MAPPING FOR SPELL CASTING                   --
---------------------------------------------------------------------------------------
-- SecureActionButtonTemplate has a built-in modified attribute system that resolves
-- attributes based on mouse button + modifier keys. For example:
--   Left click checks: type1, macrotext1 (button suffix "1" = LeftButton)
--   Shift+Right click checks: shift-type2, shift-macrotext2
-- This happens automatically at click time — even during combat lockdown — because
-- the resolution logic is part of the secure template, not addon code.
--
-- We use type="macro" + macrotext="/cast [@unitId] SpellName" because type="spell"
-- does not work on addon-created SecureActionButtonTemplate, while type="macro" does.
--
-- We pre-configure all 8 button+modifier combos on each slice out of combat.
-- When action bar content or group roster changes, we refresh the attributes.

-- Maps DB binding key to the SecureActionButton attribute prefix/suffix.
-- Slot is resolved dynamically from the user's configured binding value.
local BINDING_KEY_TO_ATTR = {
  { dbKey = "button1", prefix = "", suffix = "1" }, -- Left click
  { dbKey = "button2", prefix = "", suffix = "2" }, -- Right click
  { dbKey = "shiftbutton1", prefix = "shift-", suffix = "1" }, -- Shift+Left
  { dbKey = "shiftbutton2", prefix = "shift-", suffix = "2" }, -- Shift+Right
  { dbKey = "ctrlbutton1", prefix = "ctrl-", suffix = "1" }, -- Ctrl+Left
  { dbKey = "ctrlbutton2", prefix = "ctrl-", suffix = "2" }, -- Ctrl+Right
  { dbKey = "altbutton1", prefix = "alt-", suffix = "1" }, -- Alt+Left
  { dbKey = "altbutton2", prefix = "alt-", suffix = "2" }, -- Alt+Right
}

-- Build the button→slot map from the user's current binding settings.
-- ACTIONBUTTON and MULTIACTIONBAR1–7 bindings resolve to canonical action slots;
-- other values (FOCUSTARGET, etc.) yield nil.
local function BuildButtonAttrMap()
  local bindings = CM.DB[CM.GetBindingsLocation()].bindings
  local map = {}
  for _, entry in ipairs(BINDING_KEY_TO_ATTR) do
    local binding = bindings[entry.dbKey]
    local slot = nil
    if binding and binding.enabled and binding.value and CM.ResolveClickCastBindingToActionSlot then
      slot = CM.ResolveClickCastBindingToActionSlot(binding.value)
    end
    map[#map + 1] = {
      prefix = entry.prefix,
      suffix = entry.suffix,
      slot = slot,
      isSpellBinding = (slot ~= nil),
    }
  end
  return map
end

local function UpdateSecureButtonTargets()
  if InCombatLockdown() then
    GetState().pendingUpdate = true
    CM.DebugPrint("Party Radial: Queueing button update (in combat)")
    return
  end

  -- Clear all slices first
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice then
      slice:SetAttribute("unit", nil)
    end
  end

  -- Assign units to slice frames based on party data
  for _, member in ipairs(GetState().partyData) do
    local slice = GetState().sliceFrames[member.sliceIndex]
    if slice then
      slice:SetAttribute("unit", member.unitId)
    end
    CM.DebugPrint(
      "Party Radial: Slice "
        .. member.sliceIndex
        .. " = "
        .. member.unitId
        .. " ("
        .. member.name
        .. ")"
    )
  end

  GetState().pendingUpdate = false
end

-- Resolve the effective action slot for primary-bar button indices (1–12).
-- Blizzard's ActionButton frames compute the current slot based on bar page, bonus bar
-- (druid form, rogue stealth), vehicle bar, and override bar.
local function ResolveActionSlot(buttonIndex)
  if buttonIndex < 1 or buttonIndex > 12 then
    return buttonIndex
  end

  local frame = _G["ActionButton" .. buttonIndex]
  if not frame then
    return buttonIndex
  end

  if frame.action and type(frame.action) == "number" and frame.action > 0 then
    return frame.action
  end

  -- 2. Try :CalculateAction() method (ActionBarActionButtonMixin)
  if frame.CalculateAction then
    local ok, action = pcall(frame.CalculateAction, frame)
    if ok and action and type(action) == "number" and action > 0 then
      return action
    end
  end

  -- 3. Try "action" attribute
  if frame.GetAttribute then
    local action = frame:GetAttribute("action")
    if action and tonumber(action) and tonumber(action) > 0 then
      return tonumber(action)
    end
    -- 4. Try "actionpage" attribute and compute
    local page = frame:GetAttribute("actionpage")
    if page and tonumber(page) and tonumber(page) > 0 then
      return (tonumber(page) - 1) * 12 + buttonIndex
    end
  end

  return buttonIndex
end

-- Prepend /target so the click hard-selects the party member before cast/use/macro.
local function WithHardTarget(unitId, body)
  if not body then
    return nil
  end
  if not unitId or unitId == "" then
    return body
  end
  return "/target [@" .. unitId .. "]\n" .. body
end

-- Build the macrotext for a given action bar slot targeting a specific unit.
-- Returns macrotext string or nil if the slot is empty.
-- Uses /cast [@unit] SpellName for spells, /use [@unit] ItemName for items,
-- and raw macro body for user macros. Always prepends /target [@unit] when unitId
-- is set so the click also hard-selects that party member.
local function BuildMacrotext(slot, unitId)
  -- When the vehicle/override bar is shown, skip spell resolution entirely.
  -- Vehicle abilities cast on party members can cause unintended effects (e.g. dismount).
  local overrideBar = _G.OverrideActionBar
  if overrideBar and overrideBar:IsShown() then
    return nil
  end

  local effectiveSlot = ResolveActionSlot(slot)
  local actionType, actionId = GetActionInfo(effectiveSlot)
  if not actionType then
    return nil
  end

  if actionType == "spell" then
    local spellName = GetSpellName(actionId)
    if spellName and unitId then
      return WithHardTarget(unitId, "/cast [@" .. unitId .. "] " .. spellName)
    elseif spellName then
      return "/cast " .. spellName
    end
  elseif actionType == "item" then
    local itemName = GetItemInfo(actionId)
    if itemName and unitId then
      return WithHardTarget(unitId, "/use [@" .. unitId .. "] " .. itemName)
    elseif itemName then
      return "/use " .. itemName
    end
  elseif actionType == "macro" then
    -- User macros define their own targeting; still hard-select the slice unit first.
    return WithHardTarget(unitId, GetMacroBody(actionId))
  end

  return nil
end

-- Pre-configure modified attributes on all slices for spell casting.
-- SecureActionButtonTemplate resolves "shift-type1" before "type1" before "type"
-- automatically at click time, even during combat. We just need to set the
-- attributes ahead of time (out of combat) so the template knows what to do.
--
-- We use type="macro" + macrotext="/target [@unit]\n/cast [@unit] SpellName" because
-- type="spell" does not work on addon-created SecureActionButtonTemplate buttons,
-- while type="macro" with macrotext does. /target hard-selects the party member.
--
-- Called on init, on action bar changes, on roster changes, and on combat end.
local function UpdateSliceActionAttributes()
  if InCombatLockdown() then
    GetState().pendingUpdate = true
    CM.DebugPrint("Party Radial: Queueing action attr update (in combat)")
    return
  end

  local buttonAttrMap = BuildButtonAttrMap()

  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if not slice then
      break
    end

    local unitId = slice:GetAttribute("unit")

    for _, mapping in ipairs(buttonAttrMap) do
      local p = mapping.prefix -- "" or "shift-" or "ctrl-" or "alt-"
      local s = mapping.suffix -- "1" (left) or "2" (right)
      local macrotext = mapping.slot and BuildMacrotext(mapping.slot, unitId) or nil

      if macrotext then
        slice:SetAttribute(p .. "type" .. s, "macro")
        slice:SetAttribute(p .. "macrotext" .. s, macrotext)
      elseif unitId then
        -- Empty slot or non-action-bar binding: hard-target the party member.
        slice:SetAttribute(p .. "type" .. s, "target")
        slice:SetAttribute(p .. "macrotext" .. s, nil)
      else
        slice:SetAttribute(p .. "type" .. s, nil)
        slice:SetAttribute(p .. "macrotext" .. s, nil)
      end
    end
  end
end

Secure.UpdateSecureButtonTargets = UpdateSecureButtonTargets
Secure.UpdateSliceActionAttributes = UpdateSliceActionAttributes
Secure.BuildButtonAttrMap = BuildButtonAttrMap
