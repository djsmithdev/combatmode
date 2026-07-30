---------------------------------------------------------------------------------------
--  Core/PartyRadial/PartyRadial.lua — PARTYRADIAL — party radial runtime (CM.PartyRadial)
---------------------------------------------------------------------------------------
--  What it does: Full party-radial feature: secure slice frames that cast on party members,
--  open/hold keybind while Mouse Look is active, roster/combat/action-bar refresh, visual
--  config under DB.global.partyRadial (health bars / background), and layout-only
--  options preview (SetOptionsPreview). Slice radius, scale, role icon size, and name
--  font size are fixed constants (not user options). Health bars use the widgetstatusbar
--  L/C/R kit with a white fill tinted by health % via UnitHealthPercent color curves
--  (secret/taint-safe, same approach as Platynator/EQOL); options preview simulates varied
--  health so low-health glow is visible. Show/hide fades mainFrame alpha (combat-safe;
--  never Show/Hide secure children for visibility).
--  Architecture / how it works:
--    • CM.PartyRadial API: Initialize, Show/Hide/ShowFromKeybind, ApplyVisualConfig,
--      UpdateMainFramePosition, OnGroupRosterUpdate / OnCombatStart/End /
--      OnActionBarChanged / OnBindingChanged, OnMouselookChanged.
--    • Visibility: SetAlpha fade in/out on always-shown mainFrame (protected Show/Hide
--      avoided). Logical close (isActive, freelook, EnableMouse) is immediate on Hide;
--      visual fade-out continues on a short OnUpdate.
--    • Preview is layout-only — does not reuse mouselook-gated Show/Hide.
--  Does not: Own click-cast mouse slot overrides or SoftTarget CVars.
--  Related: Constants/PartyRadial.lua, Core/FreeLook/FreeLookController.lua,
--  Core/Runtime/EventRouter.lua, Core/Runtime/Bootstrap.lua,
--  Core/ClickCasting/BindingOverrides.lua, UI/Options/Tabs/TabPartyRadial.lua,
--  UI/Options/Tabs/TabClickCasting.lua, Core/Crosshair/Crosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local CreateColor = _G.CreateColor
local debugstack = _G.debugstack
local EvaluateColorFromBoolean = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorFromBoolean
local CreateColorCurve = _G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve
local UnitHealthPercent = _G.UnitHealthPercent
local GetActionInfo = _G.GetActionInfo
local GetCursorPosition = _G.GetCursorPosition
local GetItemInfo = _G.C_Item.GetItemInfo
local GetMacroBody = _G.GetMacroBody
local GetSpellName = _G.C_Spell.GetSpellName
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UIParent = _G.UIParent
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitInRange = _G.UnitInRange
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsUnit = _G.UnitIsUnit
local UnitName = _G.UnitName

-- Lua stdlib
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local select = _G.select
local table = _G.table
local tostring = _G.tostring
local unpack = _G.unpack
local utf8 = _G.utf8

-- Shorten display names by UTF-8 character count (byte :sub breaks Cyrillic/CJK).
local function TruncateUtf8Name(str, maxChars, keepChars, ellipsis)
  ellipsis = ellipsis or "..."
  if not str or str == "" then
    return str
  end
  if utf8 and utf8.len and utf8.offset then
    local n = utf8.len(str)
    if n and n <= maxChars then
      return str
    end
    local pos = utf8.offset(str, keepChars + 1)
    if pos then
      return str:sub(1, pos - 1) .. ellipsis
    end
    return str
  end
  if #str > maxChars then
    return str:sub(1, keepChars) .. ellipsis
  end
  return str
end

-- Colors used with EvaluateColorFromBoolean to extract tainted boolean values.
-- EvaluateColorFromBoolean(bool, trueColor, falseColor) returns a ColorMixin
-- whose fields reflect the boolean's value without triggering taint errors.
-- Reachable uses alpha; dead role icons use RGB (SetDesaturated needs a public bool).
local COLOR_REACHABLE = CreateColor(1, 1, 1, 1.0)
local COLOR_UNREACHABLE = CreateColor(1, 1, 1, 0.4)
local COLOR_ICON_ALIVE = CreateColor(1, 1, 1, 1)
local COLOR_ICON_DEAD = CreateColor(0.45, 0.45, 0.45, 1)

-- Module namespace
CM.PartyRadial = {}
local HR = CM.PartyRadial

---------------------------------------------------------------------------------------
--                                  STATE VARIABLES                                  --
---------------------------------------------------------------------------------------
local RadialState = {
  isActive = false,
  currentButton = nil,
  selectedSlice = nil,
  partyData = {},
  previewPartyData = nil, -- options-tab visual roster (real units + placeholders)
  optionsPreviewActive = false,
  sliceFrames = {},
  mainFrame = nil,
  pendingUpdate = false,
  wasMouselooking = false,
  isTogglingMouselook = false, -- Guard: true while Show/Hide is calling UnlockFreeLook/LockFreeLook
  triggerButtons = {},
  sliceRefreshElapsed = 0,
  sliceRefreshInterval = 0.08,
  -- mainFrame alpha fade: "in" | "out" | nil
  fadeMode = nil,
  fadeElapsed = 0,
  fadeFrom = 0,
  fadeTo = 1,
}

local PREVIEW_DPS_VARIANTS = {
  { name = "Mage", class = "MAGE" },
  { name = "Rogue", class = "ROGUE" },
  { name = "Hunter", class = "HUNTER" },
}
-- Options-preview health fractions per slice (low / mid / full / low / mid-high).
local PREVIEW_HEALTH_BY_SLICE = { 0.15, 0.40, 1.0, 0.25, 0.60 }

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
-- Only ACTIONBUTTON bindings produce a slot; other values (FOCUSTARGET, etc.) yield nil.
local function BuildButtonAttrMap()
  local bindings = CM.DB[CM.GetBindingsLocation()].bindings
  local map = {}
  for _, entry in ipairs(BINDING_KEY_TO_ATTR) do
    local binding = bindings[entry.dbKey]
    local slot = nil
    if binding and binding.enabled and binding.value then
      local num = binding.value:match("^ACTIONBUTTON(%d+)$")
      if num then
        slot = tonumber(num)
      end
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

-- All mouselook override binding keys
local ALL_OVERRIDE_KEYS = {
  "BUTTON1",
  "BUTTON2",
  "SHIFT-BUTTON1",
  "SHIFT-BUTTON2",
  "CTRL-BUTTON1",
  "CTRL-BUTTON2",
  "ALT-BUTTON1",
  "ALT-BUTTON2",
}

---------------------------------------------------------------------------------------
--                                UTILITY FUNCTIONS                                  --
---------------------------------------------------------------------------------------
local function GetCrosshairAnchorOffsetForUIParent()
  local xf = _G.CombatModeCrosshairFrame
  if xf and xf.GetCenter then
    local cx, cy = xf:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
      return cx - ux, cy - uy
    end
  end
  return 0, CM.DB.global and CM.DB.global.crosshairY or 50
end

local function GetCrosshairCenterScreenXY()
  local xf = _G.CombatModeCrosshairFrame
  if xf and xf.GetCenter then
    local cx, cy = xf:GetCenter()
    if cx and cy then
      return cx, cy
    end
  end
  if not CM.DB.global then
    return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
  end
  return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2 + (CM.DB.global.crosshairY or 50)
end

-- Calculate angle and distance from crosshair center to cursor position
local function GetMouseAngleAndDistanceFromCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cursorX, cursorY = cursorX / scale, cursorY / scale

  local centerX, centerY = GetCrosshairCenterScreenXY()

  local dx = cursorX - centerX
  local dy = cursorY - centerY

  -- Distance from center
  local distance = math.sqrt(dx * dx + dy * dy)

  -- Convert to degrees (0 = right, counter-clockwise positive)
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then
    angle = angle + 360
  end

  return angle, distance
end

-- Check if an angle falls within an arc (handles wrap-around at 0/360)
local function IsAngleInArc(angle, arcStart, arcEnd)
  -- Normalize all angles to 0-360
  angle = angle % 360
  arcStart = arcStart % 360
  arcEnd = arcEnd % 360

  if arcStart <= arcEnd then
    return angle >= arcStart and angle < arcEnd
  else
    -- Arc wraps around 0
    return angle >= arcStart or angle < arcEnd
  end
end

-- Get which slice the current mouse angle corresponds to
local function GetSliceFromAngle(angle)
  local sliceArc = CM.Constants.PartyRadialSliceArc
  local halfArc = sliceArc / 2

  for i, sliceData in ipairs(CM.Constants.PartyRadialSlices) do
    local centerAngle = sliceData.angle
    local arcStart = (centerAngle - halfArc) % 360
    local arcEnd = (centerAngle + halfArc) % 360

    if IsAngleInArc(angle, arcStart, arcEnd) then
      return i
    end
  end

  return nil
end

---------------------------------------------------------------------------------------
--                              PARTY DATA MANAGEMENT                                --
---------------------------------------------------------------------------------------
local function RefreshPartyData()
  RadialState.partyData = {}

  -- Collect all party members including self (works solo too)
  local members = {}

  -- Add self
  local selfRole = UnitGroupRolesAssigned("player")
  if selfRole == "NONE" then
    selfRole = "DAMAGER" -- Default to DPS if no role assigned
  end
  table.insert(members, {
    unitId = "player",
    name = UnitName("player"),
    role = selfRole,
    class = select(2, UnitClass("player")),
  })

  -- Add party members
  for i = 1, 4 do
    local unitId = "party" .. i
    if UnitExists(unitId) then
      local role = UnitGroupRolesAssigned(unitId)
      if role == "NONE" then
        role = "DAMAGER"
      end
      table.insert(members, {
        unitId = unitId,
        name = UnitName(unitId),
        role = role,
        class = select(2, UnitClass(unitId)),
      })
    end
  end

  -- Sort members by role for slot assignment
  local tanks = {}
  local healers = {}
  local dps = {}

  for _, member in ipairs(members) do
    if member.role == "TANK" then
      table.insert(tanks, member)
    elseif member.role == "HEALER" then
      table.insert(healers, member)
    else
      table.insert(dps, member)
    end
  end

  -- Assign to slice positions based on role
  local assignments = {}

  -- Slice 1 (top) = Tank
  if #tanks > 0 then
    assignments[1] = tanks[1]
    table.remove(tanks, 1)
  end

  -- Slice 3 (bottom-left) = Healer
  if #healers > 0 then
    assignments[3] = healers[1]
    table.remove(healers, 1)
  end

  -- Fill DPS slots (2, 4, 5)
  local dpsSlots = { 2, 5, 4 }
  local dpsIndex = 1
  for _, slot in ipairs(dpsSlots) do
    if not assignments[slot] then
      if dps[dpsIndex] then
        assignments[slot] = dps[dpsIndex]
        dpsIndex = dpsIndex + 1
      elseif tanks[1] then
        -- Overflow: extra tanks go to DPS slots
        assignments[slot] = tanks[1]
        table.remove(tanks, 1)
      elseif healers[1] then
        -- Overflow: extra healers go to DPS slots
        assignments[slot] = healers[1]
        table.remove(healers, 1)
      end
    end
  end

  -- Fill any remaining empty slots with remaining DPS
  for i = 1, 5 do
    if not assignments[i] and dps[dpsIndex] then
      assignments[i] = dps[dpsIndex]
      dpsIndex = dpsIndex + 1
    end
  end

  -- Store assignments with slice index
  for sliceIndex, member in pairs(assignments) do
    member.sliceIndex = sliceIndex
    table.insert(RadialState.partyData, member)
  end

  CM.DebugPrint("Party Radial: Refreshed party data, " .. #RadialState.partyData .. " members")
end

-- Options-tab roster: real party members where present, role-labeled placeholders
-- for empty slices so Visual Settings preview a full 5-man layout.
local function BuildPreviewPartyData()
  RefreshPartyData()
  local preview = {}
  local occupied = {}
  for _, member in ipairs(RadialState.partyData) do
    occupied[member.sliceIndex] = true
    table.insert(preview, {
      unitId = member.unitId,
      name = member.name,
      role = member.role,
      class = member.class,
      sliceIndex = member.sliceIndex,
      isPreview = false,
    })
  end

  local dpsIndex = 1
  for i = 1, 5 do
    if not occupied[i] then
      local sliceMeta = CM.Constants.PartyRadialSlices[i]
      local role = (sliceMeta and sliceMeta.defaultRole) or "DAMAGER"
      local name, class
      if role == "TANK" then
        name, class = "Tank", "WARRIOR"
      elseif role == "HEALER" then
        name, class = "Healer", "PRIEST"
      else
        local variant = PREVIEW_DPS_VARIANTS[dpsIndex] or PREVIEW_DPS_VARIANTS[1]
        dpsIndex = dpsIndex + 1
        name, class = variant.name, variant.class
      end
      table.insert(preview, {
        unitId = "preview" .. i,
        name = name,
        role = role,
        class = class,
        sliceIndex = i,
        isPreview = true,
        previewHealthPct = PREVIEW_HEALTH_BY_SLICE[i] or 0.75,
      })
    end
  end

  RadialState.previewPartyData = preview
end

local function GetVisualPartyData()
  if RadialState.optionsPreviewActive and RadialState.previewPartyData then
    return RadialState.previewPartyData
  end
  return RadialState.partyData
end

-- Update slice frame unit attributes (only safe out of combat)
local function UpdateSecureButtonTargets()
  if InCombatLockdown() then
    RadialState.pendingUpdate = true
    CM.DebugPrint("Party Radial: Queueing button update (in combat)")
    return
  end

  -- Clear all slices first
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAttribute("unit", nil)
    end
  end

  -- Assign units to slice frames based on party data
  for _, member in ipairs(RadialState.partyData) do
    local slice = RadialState.sliceFrames[member.sliceIndex]
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

  RadialState.pendingUpdate = false
end

-- Resolve the effective action slot for a button index (1-8).
-- Blizzard's ActionButton frames compute the current slot based on bar page, bonus bar
-- (druid form, rogue stealth), vehicle bar, and override bar.
-- We try multiple resolution strategies in priority order.
local function ResolveActionSlot(buttonIndex)
  local frame = _G["ActionButton" .. buttonIndex]
  if not frame then
    return buttonIndex
  end

  -- 1. Try .action field (set by CalculateAction on Blizzard action button mixin)
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
    RadialState.pendingUpdate = true
    CM.DebugPrint("Party Radial: Queueing action attr update (in combat)")
    return
  end

  local buttonAttrMap = BuildButtonAttrMap()

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
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
        CM.DebugPrint(
          "  Slice "
            .. i
            .. " ("
            .. tostring(unitId)
            .. "): "
            .. p
            .. "type"
            .. s
            .. "=macro -> "
            .. macrotext
        )
      elseif unitId then
        -- Empty ACTIONBUTTON slot or non-spell binding: hard-target the party member.
        slice:SetAttribute(p .. "type" .. s, "target")
        slice:SetAttribute(p .. "macrotext" .. s, nil)
        CM.DebugPrint(
          "  Slice " .. i .. " (" .. tostring(unitId) .. "): " .. p .. "type" .. s .. "=target"
        )
      else
        slice:SetAttribute(p .. "type" .. s, nil)
        slice:SetAttribute(p .. "macrotext" .. s, nil)
      end
    end
  end

  CM.DebugPrint("Party Radial: Updated slice action attributes")
end

---------------------------------------------------------------------------------------
--                                FRAME CREATION                                     --
---------------------------------------------------------------------------------------
-- Inner anchor point (edge toward radial center) so scaling grows outward from center
-- and top/bottom slices don't displace asymmetrically. Returns anchor, offsetX, offsetY.
-- Uses fixed base size for positioning (scale is fixed at 1.0 for hit-area stability)
local BASE_SLICE_SIZE = 80 -- Fixed base size for slice frame
local CENTER_FIXED_SIZE = 64 -- Fixed size for dead-center elements (not tied to crosshair size)
-- Fixed layout (no longer user-configurable)
local SLICE_RADIUS = 120
local SLICE_SCALE = 1.0
local ROLE_ICON_SIZE = 64
local NAME_FONT_SIZE = 13

-- Party-slice health bar (widgetstatusbar kit), scaled from native 15px fill height.
local HB_W, HB_H = 72, 10
local HB_SCALE = HB_H / 15
local HB_BORDER_X = math.floor(8 * HB_SCALE + 0.5)
local HB_BG_X = math.max(1, math.floor(2 * HB_SCALE + 0.5))
local HB_BORDER_H = math.floor(31 * HB_SCALE + 0.5)
local HB_BORDER_END_W = math.floor(35 * HB_SCALE + 0.5)
local HB_BG_H = math.floor(18 * HB_SCALE + 0.5)
local HB_BG_END_W = math.floor(29 * HB_SCALE + 0.5)
local HB_LOW_PCT = 0.25
local HB_GLOW_R, HB_GLOW_G, HB_GLOW_B = 1, 0.12, 0.08
local HB_FILL_WHITE = "widgetstatusbar-fill-white"
local COLOR_HB_CRIT = CreateColor(1, 0.22, 0.12, 1)
local COLOR_HB_DMG = CreateColor(1, 0.85, 0.15, 1)
local COLOR_HB_OK = CreateColor(0.2, 0.85, 0.25, 1)
local COLOR_HB_GLOW_ON = CreateColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
local COLOR_HB_GLOW_OFF = CreateColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 0)
local COLOR_HB_SPARK_ON = CreateColor(1, 1, 1, 1)
local COLOR_HB_SPARK_OFF = CreateColor(1, 1, 1, 0)

-- Secret-safe health → color (same pattern as Platynator / EQOL: UnitHealthPercent + color curve).
-- Step curves hold a point's color until the next point, so green/glow-off must start
-- immediately after their thresholds (not only at 1.0).
local HB_FILL_CURVE, HB_GLOW_CURVE, HB_SPARK_CURVE
if CreateColorCurve then
  local stepType = _G.Enum and _G.Enum.LuaCurveType and _G.Enum.LuaCurveType.Step
  local yellowAt = HB_LOW_PCT + 1e-4
  local greenAt = 0.5 + 1e-4

  HB_FILL_CURVE = CreateColorCurve()
  if stepType then
    HB_FILL_CURVE:SetType(stepType)
  end
  HB_FILL_CURVE:AddPoint(0, COLOR_HB_CRIT)
  HB_FILL_CURVE:AddPoint(HB_LOW_PCT, COLOR_HB_CRIT)
  HB_FILL_CURVE:AddPoint(yellowAt, COLOR_HB_DMG)
  HB_FILL_CURVE:AddPoint(0.5, COLOR_HB_DMG)
  HB_FILL_CURVE:AddPoint(greenAt, COLOR_HB_OK)
  HB_FILL_CURVE:AddPoint(1, COLOR_HB_OK)

  HB_GLOW_CURVE = CreateColorCurve()
  if stepType then
    HB_GLOW_CURVE:SetType(stepType)
  end
  HB_GLOW_CURVE:AddPoint(0, COLOR_HB_GLOW_ON)
  HB_GLOW_CURVE:AddPoint(HB_LOW_PCT, COLOR_HB_GLOW_ON)
  HB_GLOW_CURVE:AddPoint(yellowAt, COLOR_HB_GLOW_OFF)
  HB_GLOW_CURVE:AddPoint(1, COLOR_HB_GLOW_OFF)

  HB_SPARK_CURVE = CreateColorCurve()
  if stepType then
    HB_SPARK_CURVE:SetType(stepType)
  end
  -- Visible for any partial health; off at empty/full.
  HB_SPARK_CURVE:AddPoint(0, COLOR_HB_SPARK_OFF)
  HB_SPARK_CURVE:AddPoint(0.001, COLOR_HB_SPARK_ON)
  HB_SPARK_CURVE:AddPoint(0.999, COLOR_HB_SPARK_ON)
  HB_SPARK_CURVE:AddPoint(1, COLOR_HB_SPARK_OFF)
end

local function ApplyHealthBarFill(bar, atlas)
  bar:SetStatusBarTexture(atlas)
  local fillTex = bar:GetStatusBarTexture()
  if fillTex then
    if fillTex.SetAtlas then
      fillTex:SetAtlas(atlas, false)
    end
    fillTex:SetHorizTile(true)
  end
  return fillTex
end

local function ExtractColorRGBA(color)
  if not color then
    return nil
  end
  if color.GetRGBA then
    return color:GetRGBA()
  end
  if color.r then
    return color.r, color.g, color.b, color.a
  end
  return color[1], color[2], color[3], color[4]
end

local function SetHealthBarGlowShown(bar, shown)
  bar.glowLeft:SetShown(shown)
  bar.glowCenter:SetShown(shown)
  bar.glowRight:SetShown(shown)
  if shown then
    bar.glowLeft:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
    bar.glowCenter:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
    bar.glowRight:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
    bar.glowLeft:SetAlpha(1)
    bar.glowCenter:SetAlpha(1)
    bar.glowRight:SetAlpha(1)
  end
end

local function ApplyHealthBarGlowAlpha(bar, alpha)
  bar.glowLeft:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  bar.glowCenter:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  bar.glowRight:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  bar.glowLeft:SetAlpha(alpha)
  bar.glowCenter:SetAlpha(alpha)
  bar.glowRight:SetAlpha(alpha)
  bar.glowLeft:Show()
  bar.glowCenter:Show()
  bar.glowRight:Show()
end

-- Public (preview) health fraction → fill/glow/spark.
local function ApplyHealthBarPublicAppearance(bar, pct, fillTex)
  if type(pct) ~= "number" then
    bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    SetHealthBarGlowShown(bar, false)
    bar.spark:Hide()
    return
  end

  if pct <= HB_LOW_PCT then
    bar:SetStatusBarColor(COLOR_HB_CRIT:GetRGBA())
    SetHealthBarGlowShown(bar, true)
  elseif pct <= 0.5 then
    bar:SetStatusBarColor(COLOR_HB_DMG:GetRGBA())
    SetHealthBarGlowShown(bar, false)
  else
    bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())
    SetHealthBarGlowShown(bar, false)
  end

  if fillTex then
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
  end
  bar.spark:SetVertexColor(1, 1, 1, 1)
  bar.spark:SetShown(pct > 0 and pct < 1)
end

-- Live unit: UnitHealthPercent + color curves (secret/taint safe; Platynator/EQOL pattern).
local function ApplyHealthBarUnitAppearance(bar, unit, fillTex)
  if not (UnitHealthPercent and HB_FILL_CURVE) then
    return false
  end

  local fillColor = UnitHealthPercent(unit, true, HB_FILL_CURVE)
  local fr, fg, fb, fa = ExtractColorRGBA(fillColor)
  if not fr then
    return false
  end
  bar:SetStatusBarColor(fr, fg, fb, fa)

  local glowColor = UnitHealthPercent(unit, true, HB_GLOW_CURVE)
  local _, _, _, glowA = ExtractColorRGBA(glowColor)
  ApplyHealthBarGlowAlpha(bar, glowA or 0)

  if fillTex then
    bar.spark:ClearAllPoints()
    bar.spark:SetPoint("CENTER", fillTex, "RIGHT", 0, 0)
  end
  local sparkColor = UnitHealthPercent(unit, true, HB_SPARK_CURVE)
  local _, _, _, sparkA = ExtractColorRGBA(sparkColor)
  bar.spark:SetVertexColor(1, 1, 1, 1)
  bar.spark:SetAlpha(sparkA or 0)
  bar.spark:Show()
  return true
end

-- L/C/R chrome for widgetstatusbar (bg / border). Ends size to endW x height; center stretches.
local function CreateHealthBarLCR(
  bar,
  drawLayer,
  subLevel,
  leftAtlas,
  centerAtlas,
  rightAtlas,
  endW,
  height,
  xOff
)
  local left = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  left:SetAtlas(leftAtlas, false)
  left:SetSize(endW, height)
  left:SetPoint("LEFT", bar, "LEFT", -xOff, 0)

  local right = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  right:SetAtlas(rightAtlas, false)
  right:SetSize(endW, height)
  right:SetPoint("RIGHT", bar, "RIGHT", xOff, 0)

  local center = bar:CreateTexture(nil, drawLayer, nil, subLevel)
  center:SetAtlas(centerAtlas, false)
  center:SetHeight(height)
  center:SetPoint("LEFT", left, "RIGHT")
  center:SetPoint("RIGHT", right, "LEFT")

  return left, center, right
end

local function CreateSliceHealthBar(parent)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(HB_W, HB_H)
  bar:SetPoint("BOTTOM", parent, "BOTTOM", 0, 4)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  ApplyHealthBarFill(bar, HB_FILL_WHITE)
  bar:SetStatusBarColor(COLOR_HB_OK:GetRGBA())

  CreateHealthBarLCR(
    bar,
    "BACKGROUND",
    0,
    "widgetstatusbar-bgleft",
    "widgetstatusbar-bgcenter",
    "widgetstatusbar-bgright",
    HB_BG_END_W,
    HB_BG_H,
    HB_BG_X
  )

  local borderLeft, _, borderRight = CreateHealthBarLCR(
    bar,
    "OVERLAY",
    1,
    "widgetstatusbar-borderleft",
    "widgetstatusbar-bordercenter",
    "widgetstatusbar-borderright",
    HB_BORDER_END_W,
    HB_BORDER_H,
    HB_BORDER_X
  )

  -- Glow behind BG/fill (BACKGROUND) so it only blooms around the chrome, not over the track.
  local function MakeGlow(atlas, point, relative)
    local tex = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    tex:SetAtlas(atlas, false)
    tex:SetSize(HB_BORDER_END_W, HB_BORDER_H)
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
    tex:SetPoint(point, relative)
    tex:Hide()
    return tex
  end
  local glowLeft = MakeGlow("widgetstatusbar-glowleft", "LEFT", borderLeft)
  local glowRight = MakeGlow("widgetstatusbar-glowright", "RIGHT", borderRight)
  local glowCenter = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
  glowCenter:SetAtlas("widgetstatusbar-glowcenter", false)
  glowCenter:SetBlendMode("ADD")
  glowCenter:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  glowCenter:SetHeight(HB_BORDER_H)
  glowCenter:SetPoint("LEFT", glowLeft, "RIGHT")
  glowCenter:SetPoint("RIGHT", glowRight, "LEFT")
  glowCenter:Hide()
  bar.glowLeft = glowLeft
  bar.glowCenter = glowCenter
  bar.glowRight = glowRight

  local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
  spark:SetAtlas("widgetstatusbar-spark", false)
  spark:SetSize(6, HB_H + 4)
  spark:SetBlendMode("ADD")
  spark:Hide()
  bar.spark = spark

  return bar
end

local function UpdateSliceHealthBar(slice, config, memberData, sliceIndex, isPlaceholder)
  local bar = slice.healthBar
  if not bar then
    return
  end

  bar:ClearAllPoints()
  bar:SetPoint("TOP", slice.nameText, "BOTTOM", 0, -4)

  if not config.showHealthBars then
    bar:Hide()
    return
  end

  local health, maxHealth, pct, unitId
  if RadialState.optionsPreviewActive then
    maxHealth = 100
    pct = PREVIEW_HEALTH_BY_SLICE[sliceIndex] or 0.75
    health = maxHealth * pct
  elseif isPlaceholder then
    maxHealth = 100
    pct = memberData.previewHealthPct or 0.75
    health = maxHealth * pct
  else
    unitId = memberData.unitId
    -- Predicted health; StatusBar accepts secret values. Color via UnitHealthPercent curves.
    health = UnitHealth(unitId, true)
    maxHealth = UnitHealthMax(unitId)
  end

  bar:SetMinMaxValues(0, maxHealth)
  bar:SetValue(health)

  local fillTex = ApplyHealthBarFill(bar, HB_FILL_WHITE)
  if unitId then
    if not ApplyHealthBarUnitAppearance(bar, unitId, fillTex) and pct ~= nil then
      ApplyHealthBarPublicAppearance(bar, pct, fillTex)
    end
  else
    ApplyHealthBarPublicAppearance(bar, pct, fillTex)
  end

  bar:Show()
end

local function GetSliceInnerAnchor(angleDeg, radius)
  local a = math.rad(angleDeg)
  local x = radius * math.cos(a)
  local y = radius * math.sin(a)
  local h = BASE_SLICE_SIZE / 2
  -- Angle 0 = right, 90 = up; inner = edge/corner toward radial center.
  if angleDeg >= 315 then
    return "TOPLEFT", x - h, y + h
  elseif angleDeg < 45 then
    return "BOTTOMLEFT", x - h, y - h
  elseif angleDeg >= 45 and angleDeg < 135 then
    return "BOTTOM", x, y - h
  elseif angleDeg >= 135 and angleDeg < 225 then
    return "BOTTOMRIGHT", x + h, y - h
  else
    return "TOPRIGHT", x + h, y + h
  end
end

local function CreateSliceFrame(sliceIndex)
  local sliceData = CM.Constants.PartyRadialSlices[sliceIndex]
  local angle = sliceData.angle
  local radius = SLICE_RADIUS
  local sliceScale = SLICE_SCALE

  -- Anchor slice by its inner edge to radial center (mainFrame) so SetScale grows
  -- outward from center; otherwise top slices move up and bottom move down asymmetrically.
  local radialCenter = RadialState.mainFrame
  local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

  -- Parent to mainFrame so slices inherit position and alpha from the radial center.
  local slice = CreateFrame(
    "Button",
    "CMHealRadialSlice" .. sliceIndex,
    radialCenter,
    "SecureActionButtonTemplate"
  )
  slice:SetFrameStrata("DIALOG")
  slice:SetSize(BASE_SLICE_SIZE, BASE_SLICE_SIZE)
  slice:SetPoint(anchor, radialCenter, "CENTER", offsetX, offsetY)
  slice:SetScale(sliceScale) -- Apply config scale factor
  -- No base "type" attribute: unrecognized button clicks (Mouse4/Mouse5 etc.)
  -- fall through to nil and do nothing. Spell casting is handled by modified
  -- attributes (type1, shift-type2, etc.) set by UpdateSliceActionAttributes().
  -- Previously type="target" here caused Mouse4/5 releases to hard-target the unit.
  -- Register all clicks so Mouse4/Mouse5 don't get silently swallowed by EnableMouse.
  -- Left/right fire spell casting via SecureActionButtonTemplate attributes.
  -- Other buttons are caught by PostClick below to close the radial (tap-to-toggle).
  slice:RegisterForClicks("AnyUp", "AnyDown")
  slice.sliceIndex = sliceIndex

  -- Inner visual frame: a non-secure Frame child used for hover scale animation.
  -- SetScale on SecureActionButtonTemplate is PROTECTED during combat, but SetScale
  -- on a regular Frame child is NOT protected. All visual elements (icon, name, health)
  -- are created inside this inner frame so scaling it zooms the visuals without touching
  -- the protected secure button. The inner frame fills the slice exactly.
  local inner = CreateFrame("Frame", nil, slice)
  inner:SetAllPoints(slice)
  inner:SetFrameLevel(slice:GetFrameLevel() + 1)
  slice.innerFrame = inner
  slice.healthBar = CreateSliceHealthBar(inner)

  -- Role icon (created first so roleIconBG can anchor to it)
  local roleIconSize = ROLE_ICON_SIZE
  slice.roleIcon = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIcon:SetSize(roleIconSize, roleIconSize)
  slice.roleIcon:SetPoint("TOP", inner, "TOP", 0, -4)

  -- Role icon backdrop (Radial_Wheel_BG_Small from interface/radialwheel/uiradialwheel, 189x189)
  -- Centered on role icon, larger so the shadow extends around it.
  slice.roleIconBG = inner:CreateTexture(nil, "BORDER")
  slice.roleIconBG:SetAtlas("Radial_Wheel_BG_Small")
  slice.roleIconBG:SetSize(roleIconSize * 1.5, roleIconSize * 1.5)
  slice.roleIconBG:SetPoint("CENTER", slice.roleIcon, "CENTER", 0, 0)

  -- Role icon hover border (UI-LFG-RoleIcon-Incentive from interface/lfgframe/uilfgprompts)
  -- Overlays the role icon for the currently moused-over slice only.
  slice.roleIconBorder = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIconBorder:SetAtlas("UI-LFG-RoleIcon-Incentive")
  slice.roleIconBorder:SetSize(roleIconSize, roleIconSize)
  slice.roleIconBorder:SetPoint("TOP", inner, "TOP", 0, -4)
  slice.roleIconBorder:Hide()

  -- Role icon checkmark (UI-LFG-ReadyMark from interface/lfgframe/uilfgprompts)
  -- Overlays the role icon when this slice's unit is the current target.
  slice.roleIconCheckmark = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIconCheckmark:SetAtlas("UI-LFG-ReadyMark")
  slice.roleIconCheckmark:SetSize(roleIconSize * 0.7, roleIconSize * 0.7) -- smaller so it sits inside the role icon
  slice.roleIconCheckmark:SetPoint("CENTER", slice.roleIcon, "CENTER", 0, 0)
  slice.roleIconCheckmark:Hide()

  -- Name text (below role icon so it doesn't overlap when icon size increases)
  slice.nameText = inner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  slice.nameText:SetPoint("TOP", slice.roleIcon, "BOTTOM", 0, -2)
  slice.nameText:SetTextColor(1, 1, 1, 1)

  -- Smooth scale on hover via innerFrame (combat-safe).
  -- targetScale/scaleStart track the hover animation; applied to innerFrame, not the secure slice.
  slice.targetScale = 1.0 -- inner frame starts at 1.0 (config scale is on the secure slice)
  slice.scaleStart = 1.0
  slice.scaleElapsed = -1 -- -1 = idle, 0+ = animating

  -- Visual feedback on mouse enter/leave: scale slice instead of yellow highlight.
  -- Spell casting uses type="macro" with macrotext="/cast [@unit] Spell"
  -- set by UpdateSliceActionAttributes(), triggered by hardware mouse clicks.
  slice:HookScript("PostClick", function(self, btn, down)
    CM.DebugPrint(
      "Party Radial: PostClick slice "
        .. self.sliceIndex
        .. " btn="
        .. tostring(btn)
        .. " unit="
        .. tostring(self:GetAttribute("unit"))
    )
    -- Close radial on non-left/right clicks (e.g. Mouse4/Mouse5 tap-to-toggle)
    if down and btn ~= "LeftButton" and btn ~= "RightButton" then
      CM.DebugPrint("Party Radial: Slice received " .. tostring(btn) .. ", closing radial")
      HR.Hide()
    end
  end)
  -- Selection is driven by cursor angle in TrackMousePosition (traditional pie-style radial), not OnEnter/OnLeave.
  -- Slices remain clickable for casting.

  -- Keep slices always :Show() so they work in combat (Hide/Show is protected).
  -- mainFrame (parent) uses SetAlpha(0/1) to toggle radial visibility,
  -- which propagates to child slices automatically.
  -- Start with EnableMouse(false) since the radial starts hidden; SetSliceMouseEnabled
  -- toggles this when the radial shows/hides (out of combat only).
  slice:SetAlpha(0)
  slice:EnableMouse(false)

  RadialState.sliceFrames[sliceIndex] = slice
  return slice
end

-- Toggle mouse interaction on all slices.
-- EnableMouse is protected on SecureActionButtonTemplate during combat, so this
-- only works out of combat. In combat, slices keep whatever state they had.
--
-- Strategy:
--   Out of combat Show: enable mouse → slices receive clicks
--   Out of combat Hide: disable mouse → invisible slices don't intercept clicks
--   Combat starts: enable mouse (so slices are ready if radial opens in combat)
--   Combat Hide: can't disable → invisible slices stay clickable (acceptable:
--     user is typically in mouselook with no cursor during combat)
--   Combat ends: if radial hidden, disable mouse (cleanup)
local function SetSliceMouseEnabled(enabled)
  if InCombatLockdown() then
    return -- Can't toggle EnableMouse during combat
  end
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:EnableMouse(enabled)
    end
  end
  if RadialState.closeButton then
    RadialState.closeButton:EnableMouse(enabled)
  end
end

-- Update main frame vertical position when crosshair Y changes (no reload needed)
function HR.UpdateMainFramePosition()
  if not RadialState.mainFrame then
    return
  end
  -- SetPoint on mainFrame is protected during combat (secure descendants), so only
  -- update out of combat. In combat, the position is already set from last Show().
  if not InCombatLockdown() then
    local ox, oy = GetCrosshairAnchorOffsetForUIParent()
    RadialState.mainFrame:ClearAllPoints()
    RadialState.mainFrame:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
  end
end

-- Update slice positions when layout needs a refresh (fixed radius + scale)
-- SetPoint is protected on secure frames during combat, so we queue updates if needed
function HR.UpdateSlicePositionsAndSizes()
  if not RadialState.sliceFrames or not RadialState.mainFrame then
    return
  end

  local config = CM.DB.global.partyRadial
  if not config then
    return
  end

  local radius = SLICE_RADIUS
  local sliceScale = SLICE_SCALE

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      local sliceData = CM.Constants.PartyRadialSlices[i]
      if sliceData then
        local angle = sliceData.angle
        local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

        -- SetScale, ClearAllPoints, SetPoint are all protected on secure frames in combat
        if not InCombatLockdown() then
          slice:SetScale(sliceScale)
          slice:ClearAllPoints()
          slice:SetPoint(anchor, RadialState.mainFrame, "CENTER", offsetX, offsetY)
        else
          RadialState.pendingUpdate = true
        end
      end
    end
  end
end

-- Create non-secure trigger buttons for mouselook override bindings.
-- When mouselook is active and the player presses a mouse button, the override
-- binding clicks the trigger button, which calls HR.Show() to open the radial.
-- Spell casting is handled by the modified attributes on the slice frames.
local function CreateMouseOverrideButtons()
  local buttonKeys = {
    "BUTTON1",
    "BUTTON2",
    "SHIFT-BUTTON1",
    "SHIFT-BUTTON2",
    "CTRL-BUTTON1",
    "CTRL-BUTTON2",
    "ALT-BUTTON1",
    "ALT-BUTTON2",
  }

  RadialState.triggerButtons = {}

  for _, key in ipairs(buttonKeys) do
    local triggerBtn = CreateFrame("Button", "CMHealRadialTrigger_" .. key:gsub("-", "_"), UIParent)
    triggerBtn:SetSize(1, 1)
    triggerBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    triggerBtn.buttonKey = key
    triggerBtn:RegisterForClicks("AnyDown")

    triggerBtn:SetScript("OnClick", function(self)
      HR.Show(self.buttonKey)
    end)

    RadialState.triggerButtons[key] = triggerBtn
  end
end

-- Set up the mouselook override bindings for party radial
function HR.SetupMouselookBindings()
  if not RadialState.triggerButtons then
    return
  end

  local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

  for key, triggerBtn in pairs(RadialState.triggerButtons) do
    -- Bind the mouse button to click the trigger button (shows radial)
    SetMouselookOverrideBinding(key, "CLICK " .. triggerBtn:GetName() .. ":LeftButton")
    CM.DebugPrint("Party Radial: Bound " .. key .. " to " .. triggerBtn:GetName())
  end
end

-- Clear the mouselook override bindings (restore normal Combat Mode behavior)
function HR.ClearMouselookBindings()
  local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

  for _, key in ipairs(ALL_OVERRIDE_KEYS) do
    SetMouselookOverrideBinding(key, nil)
  end
  CM.DebugPrint("Party Radial: Cleared mouselook bindings")
end

-- Update capture frame visibility based on mouselook state
-- This should be called from Core.lua's mouselook handlers
function HR.OnMouselookChanged(isMouselooking)
  -- Dismiss radial if mouselook activates while radial is open
  -- This prevents the radial from staying open when user toggles mouselook via regular keybind
  CM.DebugPrint(
    "Party Radial: OnMouselookChanged("
      .. tostring(isMouselooking)
      .. ") active="
      .. tostring(RadialState.isActive)
      .. " btn="
      .. tostring(RadialState.currentButton)
      .. " toggling="
      .. tostring(RadialState.isTogglingMouselook)
  )

  -- Skip if the radial itself is toggling mouselook (Show calling UnlockFreeLook,
  -- or Hide calling LockFreeLook). Without this guard, Show() sets isActive=true
  -- then calls UnlockFreeLook() which fires OnMouselookChanged(false), which sees
  -- isActive + currentButton and immediately calls Hide() — closing the radial
  -- before it ever displays.
  if RadialState.isTogglingMouselook then
    return
  end

  if RadialState.isActive then
    -- Hide when mouselook is reactivated externally, or when it was opened via mouse
    -- button and mouselook is dropped externally. For keybind-opened radial
    -- (currentButton == nil), lifecycle is managed by the keybind handler.
    if isMouselooking or RadialState.currentButton then
      HR.Hide()
    end
  end
end

-- Clear radial state after loading screen / zone change so IsPartyRadialActive() is false
-- and crosshair visibility can sync correctly. Does not re-engage mouselook or touch crosshair.
function HR.DismissOnLoad()
  if RadialState.optionsPreviewActive then
    HR.SetOptionsPreview(false)
  end
  if not RadialState.isActive then
    if RadialState.mainFrame then
      RadialState.fadeMode = nil
      RadialState.mainFrame:SetScript("OnUpdate", nil)
      RadialState.mainFrame:SetAlpha(0)
    end
    return
  end
  if RadialState.mainFrame then
    RadialState.fadeMode = nil
    RadialState.mainFrame:SetScript("OnUpdate", nil)
    RadialState.mainFrame:SetAlpha(0)
  end
  SetSliceMouseEnabled(false)
  RadialState.isActive = false
  RadialState.selectedSlice = nil
  RadialState.currentButton = nil
  RadialState.boundKey = nil
end

-- Toggle the party radial system (called when enabled/disabled in settings).
-- When enabling/disabling, the config setter forces ReloadUI() so the frame is created
-- or not in HR.Initialize(); this is only for any other callers that need to dismiss the radial.
function HR.SetCaptureActive(active)
  if not active and RadialState.isActive then
    HR.Hide()
  end
  if active then
    CM.DebugPrint("Party Radial: Activated")
  else
    CM.DebugPrint("Party Radial: Deactivated")
  end
end

local function CreateMainFrame()
  -- Architecture: mainFrame (always shown) → slices (SecureActionButtonTemplate)
  --
  -- mainFrame has secure descendants (slices), so Show/Hide, SetPoint, ClearAllPoints
  -- are ALL protected on it during InCombatLockdown(). We use SetAlpha(0/1) for
  -- visibility toggling (always combat-safe).
  --
  -- Click-through prevention for hidden slices: out of combat, we toggle
  -- EnableMouse(false) on each slice when hiding and EnableMouse(true) when showing.
  -- In combat, EnableMouse is protected, so we accept that invisible slices at
  -- screen center may intercept clicks. This is acceptable because during combat
  -- the user is typically in mouselook mode (no visible cursor to click with).
  local mainFrame = CreateFrame("Frame", "CombatModePartyRadialFrame", UIParent)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetSize(400, 400)
  local ox, oy = GetCrosshairAnchorOffsetForUIParent()
  mainFrame:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
  mainFrame:SetAlpha(0)
  mainFrame:EnableMouse(false)
  mainFrame:Show()

  -- Wheel background (Radial_Wheel_BG from interface/radialwheel/uiradialwheel), ~30% larger than frame
  local wheelBG = mainFrame:CreateTexture(nil, "BACKGROUND")
  wheelBG:SetAtlas("Radial_Wheel_BG")
  local frameSize = 400
  wheelBG:SetSize(frameSize * 1.3, frameSize * 1.3)
  wheelBG:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  wheelBG:SetShown(CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground)
  RadialState.wheelBG = wheelBG

  RadialState.mainFrame = mainFrame

  -- Refresh slice visuals (e.g. target checkmark) when the player's target changes
  mainFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  mainFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" and HR.UpdateAllSlices then
      HR.UpdateAllSlices()
    end
  end)

  -- Center arrow: static BG with rotating pointer on top. Fixed size and opacity (not tied to crosshair).
  local centerSize = CENTER_FIXED_SIZE
  local arrowFrame = CreateFrame("Frame", nil, mainFrame)
  arrowFrame:SetSize(centerSize, centerSize)
  arrowFrame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  arrowFrame:SetFrameStrata("DIALOG")
  arrowFrame:SetFrameLevel(2)
  arrowFrame:SetAlpha(1.0)
  -- Static background (Ping_OVMarker_Pointer_BG from interface/radialwheel/uipingsystem2x, 47x47)
  local centerBGScale = 0.7 -- BG, close icon, and Select_Close use this scale relative to frame
  local arrowBG = arrowFrame:CreateTexture(nil, "BACKGROUND")
  arrowBG:SetAtlas("Ping_OVMarker_Pointer_BG")
  arrowBG:SetSize(centerSize * centerBGScale, centerSize * centerBGScale)
  arrowBG:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  -- Static close icon (Radial_Wheel_Icon_Close from interface/radialwheel/uiradialwheel), always visible
  local centerIconClose = arrowFrame:CreateTexture(nil, "ARTWORK")
  centerIconClose:SetAtlas("Radial_Wheel_Icon_Close")
  centerIconClose:SetSize(centerSize * centerBGScale * 0.5, centerSize * centerBGScale * 0.5) -- half of BG size
  centerIconClose:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  -- Select-close state (Radial_Wheel_Select_Close), shown when cursor over dead center instead of rotating arrow
  local centerSelectClose = arrowFrame:CreateTexture(nil, "ARTWORK")
  centerSelectClose:SetAtlas("Radial_Wheel_Select_Close")
  centerSelectClose:SetSize(centerSize * centerBGScale * 1.15, centerSize * centerBGScale * 1.15) -- slightly larger than BG
  centerSelectClose:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  centerSelectClose:Hide()
  -- Rotating pointer (Ping_OVMarker_Pointer_Assist from interface/radialwheel/uiradialwheel, 75x75)
  local arrowTex = arrowFrame:CreateTexture(nil, "OVERLAY")
  arrowTex:SetAtlas("Ping_OVMarker_Pointer_Assist")
  arrowTex:SetSize(centerSize * 1.25, centerSize * 1.25) -- larger than BG so it extends beyond
  arrowTex:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  RadialState.centerArrowFrame = arrowFrame
  RadialState.centerArrowTexture = arrowTex
  RadialState.centerArrowBG = arrowBG
  RadialState.centerBGScale = centerBGScale
  RadialState.centerIconClose = centerIconClose
  RadialState.centerSelectClose = centerSelectClose

  -- Arrow lock-in animation state (similar to crosshair lock-in animation)
  arrowFrame.arrowLockInElapsed = -1 -- -1 = idle, 0+ = animating
  arrowFrame.arrowLockInIsUnlocking = false
  arrowFrame.arrowLockInStartingScale = 1.0
  arrowFrame.arrowLockInStartingAlpha = 1.0
  arrowFrame.arrowLockInTargetScale = 1.0
  arrowFrame.arrowLockInTargetAlpha = 1.0
  arrowFrame.arrowLockInOriginalScale = 1.0
  arrowFrame.arrowLockInOriginalAlpha = 1.0

  -- Arrow lock-in animation update function (similar to crosshair lock-in)
  local ARROW_LOCK_IN_DURATION = 0.25
  local ARROW_UNLOCK_DURATION = 0.2
  arrowFrame:SetScript("OnUpdate", function(self, elapsed)
    if self.arrowLockInElapsed == -1 then
      return
    end

    local duration = self.arrowLockInIsUnlocking and ARROW_UNLOCK_DURATION or ARROW_LOCK_IN_DURATION
    self.arrowLockInElapsed = self.arrowLockInElapsed + elapsed

    if self.arrowLockInElapsed > duration then
      if self.arrowLockInIsUnlocking then
        -- Unlock phase 1 complete (shrunk), now bounce back to original
        self.arrowLockInIsUnlocking = false
        self.arrowLockInStartingScale = self.arrowLockInTargetScale
        self.arrowLockInStartingAlpha = self.arrowLockInTargetAlpha
        self.arrowLockInTargetScale = self.arrowLockInOriginalScale
        self.arrowLockInTargetAlpha = self.arrowLockInOriginalAlpha
        local remainder = self.arrowLockInElapsed - duration
        self.arrowLockInElapsed = remainder
        duration = ARROW_UNLOCK_DURATION * 0.5
      else
        -- Animation complete
        self.arrowLockInElapsed = -1
        self:SetScale(self.arrowLockInTargetScale)
        self:SetAlpha(self.arrowLockInTargetAlpha)
        return
      end
    end

    local progress = self.arrowLockInElapsed / duration
    local easedProgress = 1 - (1 - progress) * (1 - progress)

    local currentScale = self.arrowLockInStartingScale
      + (self.arrowLockInTargetScale - self.arrowLockInStartingScale) * easedProgress
    self:SetScale(currentScale)

    local currentAlpha = self.arrowLockInStartingAlpha
      + (self.arrowLockInTargetAlpha - self.arrowLockInStartingAlpha) * easedProgress
    self:SetAlpha(currentAlpha)
  end)

  -- Center close button: an invisible secure button covering the dead zone (30px radius).
  -- Clicking the center X clears the current target, closes the radial, and re-engages
  -- mouselook (left/right). ClearTarget must be secure — use macrotext /cleartarget.
  local CENTER_DEAD_ZONE_PX = 30
  local closeBtn = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
  closeBtn:SetSize(CENTER_DEAD_ZONE_PX * 2, CENTER_DEAD_ZONE_PX * 2)
  closeBtn:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  closeBtn:SetFrameStrata("DIALOG")
  closeBtn:SetFrameLevel(arrowFrame:GetFrameLevel() + 10) -- Above slices so it catches clicks first
  closeBtn:RegisterForClicks("AnyDown")
  closeBtn:SetAttribute("type", "macro")
  closeBtn:SetAttribute("macrotext", "/cleartarget")
  closeBtn:EnableMouse(false) -- Toggled by SetSliceMouseEnabled alongside slices
  closeBtn:HookScript("PostClick", function(_, button)
    if button == "LeftButton" or button == "RightButton" then
      CM.LockFreeLook()
      HR.Hide()
    else
      -- Non-left/right (e.g. Mouse5 tap-to-toggle): just close the radial
      HR.Hide()
    end
  end)
  RadialState.closeButton = closeBtn

  -- Create slice frames (parented to mainFrame so they inherit alpha/position).
  for i = 1, 5 do
    CreateSliceFrame(i)
  end
end

---------------------------------------------------------------------------------------
--                                VISUAL UPDATES                                     --
---------------------------------------------------------------------------------------
local function UpdateSliceVisual(sliceIndex)
  local slice = RadialState.sliceFrames[sliceIndex]
  local config = CM.DB.global.partyRadial

  -- Find member assigned to this slice
  local memberData = nil
  for _, member in ipairs(GetVisualPartyData()) do
    if member.sliceIndex == sliceIndex then
      memberData = member
      break
    end
  end

  local isPlaceholder = memberData and memberData.isPreview
  if not memberData or (not isPlaceholder and not UnitExists(memberData.unitId)) then
    -- Use alpha only (not Hide/Show or EnableMouse) to avoid protected frame errors in combat
    slice:SetAlpha(0)
    return
  end

  -- Show visually via alpha (combat-safe)
  slice:SetAlpha(1)

  -- Determine if unit is reachable (in range).
  -- Dim out-of-range slices via innerFrame alpha so the user can see at a glance
  -- who can be targeted. Player is always reachable (you can always heal yourself).
  --
  -- UnitInRange returns tainted booleans in combat — boolean tests (if/and/or/tostring)
  -- all propagate taint and error. C_CurveUtil.EvaluateColorFromBoolean (added 12.0.0)
  -- accepts a tainted boolean and returns a ColorMixin whose fields reflect the boolean
  -- without triggering taint errors. We encode reachable=alpha 1.0, unreachable=alpha 0.4
  -- in the colors, then apply the .a field via SetAlpha (which accepts secret numbers).
  if slice.innerFrame and EvaluateColorFromBoolean then
    if isPlaceholder or memberData.unitId == "player" then
      slice.innerFrame:SetAlpha(1.0)
    else
      local inRange = UnitInRange(memberData.unitId)
      local rangeColor = EvaluateColorFromBoolean(inRange, COLOR_REACHABLE, COLOR_UNREACHABLE)
      slice.innerFrame:SetAlpha(rangeColor.a)
    end
  end

  -- Update name (class-coloured; show "You" for the player; font/size with drop shadow; always shown)
  local fontSize = NAME_FONT_SIZE
  -- Always use drop shadow (no outline); locale-safe font (same as GameFontNormalSmall resolution)
  CM.SetFontStringFromTemplate(slice.nameText, fontSize, _G.GameFontNormalSmall)
  slice.nameText:SetShadowColor(0, 0, 0, 1)
  slice.nameText:SetShadowOffset(1, -1)
  local displayName = (not isPlaceholder and memberData.unitId == "player") and "You"
    or (memberData.name or "Unknown")
  displayName = TruncateUtf8Name(displayName, 10, 9, "...")
  local color = (memberData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberData.class])
      and RAID_CLASS_COLORS[memberData.class]
    or { r = 1, g = 1, b = 1 }
  slice.nameText:SetTextColor(color.r, color.g, color.b, 1)
  slice.nameText:SetText(displayName)
  slice.nameText:Show()
  UpdateSliceHealthBar(slice, config, memberData, sliceIndex, isPlaceholder)

  -- Update role icon backdrop (centered on role icon, extends beyond for shadow)
  local size = ROLE_ICON_SIZE
  slice.roleIconBG:SetSize(size * 1.5, size * 1.5)

  -- Update role icon (always shown)
  slice.roleIcon:SetSize(size, size)
  if slice.roleIconBorder then
    slice.roleIconBorder:SetSize(size, size)
  end
  if slice.roleIconCheckmark then
    local checkSize = size * 0.7 -- smaller so it sits inside the role icon
    slice.roleIconCheckmark:SetSize(checkSize, checkSize)
  end
  local roleAtlas = {
    TANK = "UI-LFG-RoleIcon-Tank",
    HEALER = "UI-LFG-RoleIcon-Healer",
    DAMAGER = "UI-LFG-RoleIcon-DPS",
  }
  if roleAtlas[memberData.role] then
    slice.roleIcon:SetAtlas(roleAtlas[memberData.role])
    -- Grey out dead/ghost members (secret-safe via EvaluateColorFromBoolean).
    if isPlaceholder or not UnitIsDeadOrGhost then
      slice.roleIcon:SetVertexColor(1, 1, 1, 1)
      if slice.roleIcon.SetDesaturated then
        slice.roleIcon:SetDesaturated(false)
      end
    elseif EvaluateColorFromBoolean then
      local isDead = UnitIsDeadOrGhost(memberData.unitId)
      local iconColor = EvaluateColorFromBoolean(isDead, COLOR_ICON_DEAD, COLOR_ICON_ALIVE)
      if slice.roleIcon.SetDesaturated then
        slice.roleIcon:SetDesaturated(false)
      end
      slice.roleIcon:SetVertexColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a)
    else
      local isDead = UnitIsDeadOrGhost(memberData.unitId)
      if slice.roleIcon.SetDesaturated then
        slice.roleIcon:SetDesaturated(isDead and true or false)
      end
      if isDead then
        slice.roleIcon:SetVertexColor(0.45, 0.45, 0.45, 1)
      else
        slice.roleIcon:SetVertexColor(1, 1, 1, 1)
      end
    end
    slice.roleIcon:Show()
    slice.roleIconBG:Show() -- Show background when role icon is shown
    -- Show checkmark when this slice's unit is the current target
    if slice.roleIconCheckmark then
      if not isPlaceholder and UnitIsUnit(memberData.unitId, "target") then
        slice.roleIconCheckmark:Show()
      else
        slice.roleIconCheckmark:Hide()
      end
    end
  else
    slice.roleIcon:Hide()
    slice.roleIconBG:Hide() -- Hide background when role icon is hidden
    if slice.roleIconCheckmark then
      slice.roleIconCheckmark:Hide()
    end
  end
end

local function UpdateAllSlices()
  for i = 1, 5 do
    UpdateSliceVisual(i)
  end
end
HR.UpdateAllSlices = UpdateAllSlices

local function PreviewOnUpdate(_, elapsed)
  RadialState.sliceRefreshElapsed = (RadialState.sliceRefreshElapsed or 0) + elapsed
  if RadialState.sliceRefreshElapsed >= (RadialState.sliceRefreshInterval or 0.08) then
    RadialState.sliceRefreshElapsed = 0
    UpdateAllSlices()
  end
end

local function StopOptionsPreviewVisuals()
  if RadialState.mainFrame then
    RadialState.fadeMode = nil
    RadialState.mainFrame:SetScript("OnUpdate", nil)
    RadialState.mainFrame:SetAlpha(0)
  end
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
      slice.targetScale = 1.0
      slice.scaleStart = 1.0
      slice.scaleElapsed = -1
      if slice.innerFrame then
        slice.innerFrame:SetScale(1.0)
        slice.innerFrame:SetAlpha(1.0)
      end
    end
  end
  SetSliceMouseEnabled(false)
end

local function StartOptionsPreviewVisuals()
  if not RadialState.mainFrame then
    return
  end
  BuildPreviewPartyData()
  HR.UpdateMainFramePosition()
  HR.UpdateSlicePositionsAndSizes()
  if RadialState.wheelBG then
    RadialState.wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  RadialState.sliceRefreshElapsed = 0
  UpdateAllSlices()
  -- Layout-only: do not steal clicks or cast while tweaking settings.
  SetSliceMouseEnabled(false)
  RadialState.fadeMode = nil
  RadialState.mainFrame:SetAlpha(1)
  RadialState.mainFrame:SetScript("OnUpdate", PreviewOnUpdate)
end

--- Re-applies Visual Settings to frames (radius/scale always; font/icon/health/bg
--- when the radial is open or options preview is active).
function HR.ApplyVisualConfig()
  if not RadialState.mainFrame then
    return
  end
  HR.UpdateSlicePositionsAndSizes()
  if RadialState.wheelBG then
    RadialState.wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  if RadialState.isActive or RadialState.optionsPreviewActive then
    UpdateAllSlices()
  end
end

function HR.IsOptionsPreviewActive()
  return RadialState.optionsPreviewActive
end

--- Forces the Party Radial on-screen for the options tab without freelook unlock,
--- mouse capture, or marking IsActive(). Empty roster slots use placeholders.
function HR.SetOptionsPreview(enabled)
  enabled = enabled and true or false
  if RadialState.optionsPreviewActive == enabled then
    return
  end

  if enabled then
    if InCombatLockdown() or not HR.IsEnabled() or not RadialState.mainFrame then
      return
    end
    -- Gameplay radial must not stay "active" under a layout preview.
    if RadialState.isActive then
      HR.Hide()
    end
    RadialState.optionsPreviewActive = true
    StartOptionsPreviewVisuals()
    return
  end

  RadialState.optionsPreviewActive = false
  RadialState.previewPartyData = nil
  StopOptionsPreviewVisuals()
  -- Restore secure-button roster without placeholders.
  RefreshPartyData()
end

-- Accessible via HR so closures created before this point can call it
function HR.HighlightSlice(sliceIndex)
  -- Start scale transition on the inner visual frame: grow selected by 10%, others back to 1.0.
  -- The inner frame is a regular (non-secure) Frame, so SetScale is always combat-safe.
  -- Hover scale is on innerFrame (slice frame itself stays at fixed SLICE_SCALE).
  local BASE_INNER = 1.0
  local HOVER_INNER = 1.1

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice and slice.innerFrame then
      slice.scaleStart = slice.innerFrame:GetScale()
      if i == sliceIndex and slice:GetAlpha() > 0 then
        slice.targetScale = HOVER_INNER
      else
        slice.targetScale = BASE_INNER
      end
      slice.scaleElapsed = 0
    end
    -- Show role icon incentive border only on the moused-over slice
    if slice and slice.roleIconBorder then
      if sliceIndex and i == sliceIndex and slice:GetAlpha() > 0 then
        slice.roleIconBorder:Show()
      else
        slice.roleIconBorder:Hide()
      end
    end
  end
end

---------------------------------------------------------------------------------------
--                              RADIAL CONTROL                                       --
---------------------------------------------------------------------------------------
-- Check if the triggering mouse button is still held down
local function IsMouseButtonStillDown(buttonKey)
  if not buttonKey then
    return false
  end

  -- Determine which base button we're checking
  local isButton1 = buttonKey:find("BUTTON1")
  local isButton2 = buttonKey:find("BUTTON2")

  -- Check the actual mouse button state
  local mouseDown = false
  if isButton1 then
    mouseDown = _G.IsMouseButtonDown("LeftButton")
  elseif isButton2 then
    mouseDown = _G.IsMouseButtonDown("RightButton")
  end

  return mouseDown
end

---------------------------------------------------------------------------------------
--                         MAINFRAME SHOW/HIDE ALPHA FADE                            --
---------------------------------------------------------------------------------------
local FADE_IN_DURATION = 0.18
local FADE_OUT_DURATION = 0.22

local function EaseOutQuad(progress)
  local inv = 1 - progress
  return 1 - inv * inv
end

local function ResetRadialHideVisuals()
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
      slice.targetScale = 1.0
      slice.scaleStart = 1.0
      slice.scaleElapsed = -1
      if slice.innerFrame then
        slice.innerFrame:SetScale(1.0)
        slice.innerFrame:SetAlpha(1.0)
      end
    end
  end

  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    arrowFrame.arrowLockInElapsed = -1
    arrowFrame:SetScale(1.0)
    arrowFrame:SetAlpha(1.0)
  end
end

local function FinishFadeOutVisuals()
  ResetRadialHideVisuals()
  if RadialState.mainFrame then
    RadialState.mainFrame:SetAlpha(0)
    if not RadialState.isActive then
      RadialState.mainFrame:SetScript("OnUpdate", nil)
    end
  end
end

-- Returns true while a fade is still running.
local function UpdateRadialFade(elapsed)
  if not RadialState.fadeMode or not RadialState.mainFrame then
    return false
  end

  local duration = RadialState.fadeMode == "in" and FADE_IN_DURATION or FADE_OUT_DURATION
  RadialState.fadeElapsed = RadialState.fadeElapsed + elapsed
  local progress = RadialState.fadeElapsed / duration
  if progress >= 1 then
    RadialState.mainFrame:SetAlpha(RadialState.fadeTo)
    local mode = RadialState.fadeMode
    RadialState.fadeMode = nil
    RadialState.fadeElapsed = 0
    if mode == "out" then
      FinishFadeOutVisuals()
    end
    return false
  end

  local eased = EaseOutQuad(progress)
  local alpha = RadialState.fadeFrom + (RadialState.fadeTo - RadialState.fadeFrom) * eased
  RadialState.mainFrame:SetAlpha(alpha)
  return true
end

local function StartRadialFade(toAlpha)
  local frame = RadialState.mainFrame
  if not frame then
    return
  end

  local fromAlpha = frame:GetAlpha() or 0
  RadialState.fadeFrom = fromAlpha
  RadialState.fadeTo = toAlpha
  RadialState.fadeElapsed = 0
  if toAlpha >= fromAlpha then
    RadialState.fadeMode = "in"
  else
    RadialState.fadeMode = "out"
  end

  if math.abs(toAlpha - fromAlpha) < 0.001 then
    frame:SetAlpha(toAlpha)
    local mode = RadialState.fadeMode
    RadialState.fadeMode = nil
    RadialState.fadeElapsed = 0
    if mode == "out" then
      FinishFadeOutVisuals()
    end
  end
end

local function FadeOutOnUpdate(_, elapsed)
  if not UpdateRadialFade(elapsed) and RadialState.mainFrame and not RadialState.isActive then
    RadialState.mainFrame:SetScript("OnUpdate", nil)
  end
end

local function TrackMousePosition(_, elapsed)
  if RadialState.fadeMode == "in" then
    UpdateRadialFade(elapsed)
  end

  if not RadialState.isActive then
    return
  end

  -- Check button release to close the radial (only when opened via mouse button, not keybind)
  if RadialState.currentButton then
    local elapsed_since_show = _G.GetTime() - (RadialState.showTime or 0)
    if elapsed_since_show > 0.2 then
      if not IsMouseButtonStillDown(RadialState.currentButton) then
        CM.DebugPrint(
          "Party Radial: Button released, closing (combat=" .. tostring(InCombatLockdown()) .. ")"
        )
        HR.ExecuteAndHide()
        return
      end
    end
  end
  -- When opened via keybind, key release is handled by HideFromKeybind()
  -- via runOnUp binding (with spurious key-up counter).

  -- Radial selection: cursor angle picks a slice, but only within a reasonable
  -- distance from center. Beyond the outer edge of slices, nothing is selected
  -- so the hover animation doesn't mislead the user into clicking outside the frames.
  -- Uses RadialState.maxSelectDistance computed at Show time (combat-safe, no DB access).
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  local sliceIndex = nil
  if distance > CENTER_DEAD_ZONE and distance <= (RadialState.maxSelectDistance or 160) then
    sliceIndex = GetSliceFromAngle(angle)
  end
  if sliceIndex ~= RadialState.selectedSlice then
    RadialState.selectedSlice = sliceIndex
    HR.HighlightSlice(sliceIndex)
  end

  -- Center: static X (Icon_Close) always visible; over dead zone show Select_Close and hide rotating arrow
  -- Center size is fixed (CENTER_FIXED_SIZE), not tied to crosshair.
  local arrowFrame = RadialState.centerArrowFrame
  local arrowTex = RadialState.centerArrowTexture
  local centerSelectClose = RadialState.centerSelectClose
  if arrowFrame and arrowTex then
    local overDeadCenter = (distance <= CENTER_DEAD_ZONE)
    if centerSelectClose then
      if overDeadCenter then
        centerSelectClose:Show()
        arrowTex:Hide()
      else
        centerSelectClose:Hide()
        arrowTex:Show()
      end
    end
    if arrowFrame.arrowLockInElapsed == -1 then
      -- Alpha: full when over dead center; 1.0 over a player, 0.5 not over a player when outside center
      local arrowAlpha
      if overDeadCenter then
        arrowAlpha = 1.0
      else
        local selectedSlice = sliceIndex and RadialState.sliceFrames[sliceIndex]
        local unitId = selectedSlice and selectedSlice:GetAttribute("unit")
        arrowAlpha = (unitId and unitId ~= "") and 1.0 or 0.5
      end
      arrowFrame:SetAlpha(arrowAlpha)
    end
    -- Rotation: angle 0 = right, 90 = up; atlas arrow points down, so rotate by (angle + 90) to align with cursor
    arrowTex:SetRotation(math.rad(angle + 90))
  end

  -- Smooth scale transition on innerFrame (duration-based, always combat-safe).
  -- innerFrame is a regular Frame child, so SetScale is never protected.
  local SLICE_SCALE_DURATION = 0.1
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice and slice.innerFrame and slice.scaleElapsed and slice.scaleElapsed >= 0 then
      slice.scaleElapsed = slice.scaleElapsed + elapsed
      if slice.scaleElapsed >= SLICE_SCALE_DURATION then
        slice.scaleElapsed = -1
        slice.innerFrame:SetScale(slice.targetScale)
      else
        local progress = slice.scaleElapsed / SLICE_SCALE_DURATION
        local scale = slice.scaleStart + (slice.targetScale - slice.scaleStart) * progress
        slice.innerFrame:SetScale(scale)
      end
    end
  end

  -- Update expensive slice/unit status at a short cadence instead of every frame.
  RadialState.sliceRefreshElapsed = (RadialState.sliceRefreshElapsed or 0) + elapsed
  if RadialState.sliceRefreshElapsed >= (RadialState.sliceRefreshInterval or 0.08) then
    RadialState.sliceRefreshElapsed = 0
    UpdateAllSlices()
  end
end

function HR.Show(buttonKey)
  if not CM.DB.global.partyRadial or not CM.DB.global.partyRadial.enabled then
    return false
  end
  if not RadialState.mainFrame then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  if RadialState.optionsPreviewActive then
    HR.SetOptionsPreview(false)
  end

  -- Store state
  RadialState.isActive = true
  RadialState.currentButton = buttonKey
  RadialState.wasMouselooking = _G.IsMouselooking()
  RadialState.showTime = _G.GetTime()
  -- Cache max selection distance for TrackMousePosition
  RadialState.maxSelectDistance = SLICE_RADIUS + BASE_SLICE_SIZE / 2

  -- Stop mouselook so cursor is free for slice selection
  -- Use UnlockFreeLook() instead of direct MouselookStop() to ensure proper state management
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't immediately close us
  if RadialState.wasMouselooking then
    RadialState.isTogglingMouselook = true
    CM.UnlockFreeLook()
    RadialState.isTogglingMouselook = false
  end

  -- Initial selection from current cursor angle
  -- Only select within dead zone → outer edge of slices range
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  RadialState.selectedSlice = nil
  if distance > CENTER_DEAD_ZONE and distance <= RadialState.maxSelectDistance then
    RadialState.selectedSlice = GetSliceFromAngle(angle)
  end
  -- Update visuals first so slice alpha is set to 1 for populated slices
  -- (HighlightSlice checks GetAlpha() > 0 to decide if a slice can be scaled)
  RadialState.sliceRefreshElapsed = 0
  UpdateAllSlices()

  -- Enable mouse on slices so they can receive clicks (out of combat only;
  -- in combat, slices keep EnableMouse from last out-of-combat Show, which is true)
  SetSliceMouseEnabled(true)

  -- Fade mainFrame + children in via alpha (combat-safe).
  if RadialState.wheelBG then
    RadialState.wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  StartRadialFade(1)

  -- Apply initial highlight AFTER slices are visible
  HR.HighlightSlice(RadialState.selectedSlice)

  -- Start mouse tracking (also drives fade-in)
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation (always start from base scale 1.0 to prevent compounding)
  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    local baseArrowScale = 1.0
    local baseArrowAlpha = 1.0
    arrowFrame.arrowLockInOriginalScale = baseArrowScale
    arrowFrame.arrowLockInOriginalAlpha = baseArrowAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = baseArrowScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = baseArrowScale
    arrowFrame.arrowLockInTargetAlpha = baseArrowAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Party Radial: Shown for " .. buttonKey)

  return true
end

-- Close the radial when the triggering mouse button is released.
-- Spell casting is handled by modified attributes on each slice:
--   type1="macro", macrotext1="/cast [@partyN] SpellName" (set out of combat)
--   SecureActionButtonTemplate resolves the modifier+button combo and fires the macro
-- This function is called from TrackMousePosition when the mouse button is released.
function HR.ExecuteAndHide()
  if not RadialState.isActive then
    return
  end

  if RadialState.selectedSlice then
    CM.DebugPrint("Party Radial: Closing (slice " .. RadialState.selectedSlice .. " was hovered)")
  else
    CM.DebugPrint("Party Radial: Closing (no slice selected)")
  end

  HR.Hide()
end

function HR.Hide()
  if not RadialState.isActive then
    return
  end
  if not RadialState.mainFrame then
    RadialState.isActive = false
    RadialState.selectedSlice = nil
    RadialState.currentButton = nil
    RadialState.boundKey = nil
    return
  end
  CM.DebugPrint("Party Radial: HR.Hide called from: " .. (debugstack(2, 1, 0) or "unknown"))

  -- Disable mouse immediately so a fading radial cannot steal clicks.
  -- Only works out of combat (EnableMouse is protected on secure frames in combat).
  SetSliceMouseEnabled(false)

  -- Mark inactive so ShouldFreeLookBeOff() via IsPartyRadialActive()
  -- no longer detects the radial as open (freelook can return during fade-out).
  RadialState.isActive = false
  RadialState.selectedSlice = nil

  -- Re-engage mouselook if it was active before radial opened
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't re-enter
  if RadialState.wasMouselooking then
    -- Restore crosshair before starting mouselook (needed for lock-in animation)
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    end
    -- LockFreeLook handles MouselookStart, UI state, animations, and notifies
    -- radial via OnMouselookChanged — guard prevents re-entry
    RadialState.isTogglingMouselook = true
    CM.SetCursorFreelookCenteringCVar(false)
    CM.LockFreeLook()
    RadialState.isTogglingMouselook = false
  else
    -- Restore crosshair even if mouselook wasn't active
    if CM.IsCrosshairEnabled() then
      CM.DisplayCrosshair(true)
    end
  end

  -- Visual fade-out continues after logical close (combat-safe SetAlpha only).
  StartRadialFade(0)
  if RadialState.fadeMode == "out" then
    RadialState.mainFrame:SetScript("OnUpdate", FadeOutOnUpdate)
  else
    -- Already at 0 (or snap-finished); ensure OnUpdate is cleared.
    RadialState.mainFrame:SetScript("OnUpdate", nil)
  end

  CM.DebugPrint("Party Radial: Hidden (combat=" .. tostring(InCombatLockdown()) .. ")")
end

-- Open radial via keybind (targeting on hover, casting via mouse clicks on slices)
function HR.ShowFromKeybind()
  if not CM.DB.global.partyRadial or not CM.DB.global.partyRadial.enabled then
    return false
  end
  if not RadialState.mainFrame then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  if RadialState.optionsPreviewActive then
    HR.SetOptionsPreview(false)
  end

  -- Find which key is bound so we can poll for release in TrackMousePosition
  local boundKey = _G.GetBindingKey("Combat Mode - Party Radial")

  -- Store state (currentButton = nil signals keybind mode)
  RadialState.isActive = true
  RadialState.currentButton = nil
  RadialState.boundKey = boundKey
  RadialState.keyUpCount = 0
  RadialState.wasMouselooking = _G.IsMouselooking()
  RadialState.showTime = _G.GetTime()
  -- Cache max selection distance for TrackMousePosition
  RadialState.maxSelectDistance = SLICE_RADIUS + BASE_SLICE_SIZE / 2

  -- Stop mouselook so cursor is free for slice selection.
  -- NOTE: MouselookStop causes spurious key-up events for held keys. The
  -- time-based filter in HideFromKeybind handles this by ignoring key-ups
  -- that arrive within 0.3s of showing.
  -- Guard with isTogglingMouselook so OnMouselookChanged doesn't immediately close us
  if RadialState.wasMouselooking then
    RadialState.isTogglingMouselook = true
    CM.UnlockFreeLook()
    RadialState.isTogglingMouselook = false
  end

  -- Initial selection from current cursor angle
  -- Only select within dead zone → outer edge of slices range
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30
  RadialState.selectedSlice = nil
  if distance > CENTER_DEAD_ZONE and distance <= RadialState.maxSelectDistance then
    RadialState.selectedSlice = GetSliceFromAngle(angle)
  end
  -- Update visuals first so slice alpha is set to 1 for populated slices
  RadialState.sliceRefreshElapsed = 0
  UpdateAllSlices()

  -- Enable mouse on slices so they can receive clicks
  SetSliceMouseEnabled(true)

  -- Fade mainFrame + children in via alpha (combat-safe).
  if RadialState.wheelBG then
    RadialState.wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  StartRadialFade(1)

  -- Apply initial highlight AFTER slices are visible
  HR.HighlightSlice(RadialState.selectedSlice)

  -- Start mouse tracking (for health bar updates and OnEnter/OnLeave; also drives fade-in)
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation (always start from base scale 1.0 to prevent compounding)
  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    local baseArrowScale = 1.0
    local baseArrowAlpha = 1.0
    arrowFrame.arrowLockInOriginalScale = baseArrowScale
    arrowFrame.arrowLockInOriginalAlpha = baseArrowAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = baseArrowScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = baseArrowScale
    arrowFrame.arrowLockInTargetAlpha = baseArrowAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.IsCrosshairEnabled() then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint(
    "Party Radial: Shown via keybind (combat="
      .. tostring(InCombatLockdown())
      .. ", wasML="
      .. tostring(RadialState.wasMouselooking)
      .. ")"
  )
  return true
end

-- Close radial opened via keybind
function HR.HideFromKeybind()
  if not RadialState.isActive then
    CM.DebugPrint("Party Radial: HideFromKeybind called but radial not active")
    return
  end
  local elapsed = _G.GetTime() - (RadialState.showTime or 0)
  CM.DebugPrint(
    "Party Radial: HideFromKeybind elapsed="
      .. string.format("%.3f", elapsed)
      .. "s combat="
      .. tostring(InCombatLockdown())
  )
  -- Tap vs hold detection: if key-up arrives quickly (< 0.3s), treat as a tap —
  -- keep the radial open so the user can select a slice with the mouse. A second
  -- key-down (handled in CombatMode_PartyRadialKey) will close it.
  -- If key-up arrives after 0.3s, treat as a hold release — close the radial.
  if elapsed < 0.3 then
    CM.DebugPrint("Party Radial: Tap detected, keeping open")
    return
  end
  HR.Hide()
end

function HR.IsActive()
  return RadialState.isActive
end

function HR.IsEnabled()
  return CM.DB.global.partyRadial and CM.DB.global.partyRadial.enabled
end

---------------------------------------------------------------------------------------
--                              EVENT HANDLING                                       --
---------------------------------------------------------------------------------------
function HR.OnGroupRosterUpdate()
  RefreshPartyData()
  UpdateSecureButtonTargets()
  -- Rebuild macrotext because [@unitId] in the macrotext depends on which
  -- party member is assigned to each slice (changes with roster)
  UpdateSliceActionAttributes()

  if RadialState.optionsPreviewActive then
    BuildPreviewPartyData()
    UpdateAllSlices()
  elseif RadialState.isActive then
    UpdateAllSlices()
  end
end

-- Called when combat starts (PLAYER_REGEN_DISABLED).
-- Pre-enable mouse on slices so they're ready to receive clicks if the radial
-- opens during combat (EnableMouse is protected during InCombatLockdown).
function HR.OnCombatStart()
  if RadialState.optionsPreviewActive then
    -- Keep the preview flag; hide visuals until combat ends (protected SetPoint/SetScale).
    StopOptionsPreviewVisuals()
  end
  SetSliceMouseEnabled(true)
end

function HR.OnCombatEnd()
  -- Apply any pending updates that were blocked during combat
  if RadialState.pendingUpdate then
    RadialState.pendingUpdate = false
    UpdateSecureButtonTargets()
    UpdateSliceActionAttributes()
    HR.UpdateSlicePositionsAndSizes()
    HR.UpdateMainFramePosition()
  end

  -- If radial is not active, disable mouse on slices so invisible slices
  -- don't intercept clicks now that we're out of combat
  if not RadialState.isActive then
    SetSliceMouseEnabled(false)
  end

  if RadialState.optionsPreviewActive and not RadialState.isActive then
    StartOptionsPreviewVisuals()
  end
end

-- Called when action bar content changes (ACTIONBAR_SLOT_CHANGED).
-- Refreshes the modified attributes so slices cast the correct spells.
function HR.OnActionBarChanged()
  UpdateSliceActionAttributes()
end

-- Called when the user changes a mouse button binding in the Config panel.
-- Rebuilds the slot map from the updated binding settings.
function HR.OnBindingChanged()
  UpdateSliceActionAttributes()
end

---------------------------------------------------------------------------------------
--                              INITIALIZATION                                       --
---------------------------------------------------------------------------------------
function HR.Initialize()
  -- Ensure defaults exist
  if not CM.DB.global.partyRadial then
    CM.DB.global.partyRadial = CM.Constants.DatabaseDefaults.global.partyRadial
  end

  -- Only create the frame and overlay when party radial is enabled (avoids drawing anything when disabled)
  if CM.DB.global.partyRadial.enabled then
    CreateMainFrame()
    CreateMouseOverrideButtons()
    RefreshPartyData()
    UpdateSecureButtonTargets()
    UpdateSliceActionAttributes()
  end

  CM.DebugPrint("Party Radial: Initialized")
end

-- Expose state for Core.lua integration
function HR.GetState()
  return RadialState
end
