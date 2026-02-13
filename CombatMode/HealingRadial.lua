---------------------------------------------------------------------------------------
--                              HEALING RADIAL MODULE                                --
---------------------------------------------------------------------------------------
-- A radial menu for quick party member targeting and spell casting, designed for healers.
-- Shows party members as slices around screen center. Click slices to cast (works in combat).

-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- CACHING GLOBAL VARIABLES
local CreateFrame = _G.CreateFrame
local GetActionInfo = _G.GetActionInfo
local GetCursorPosition = _G.GetCursorPosition
local GetMacroBody = _G.GetMacroBody
local GetSpellName = _G.C_Spell.GetSpellName
local GetItemInfo = _G.C_Item.GetItemInfo
local InCombatLockdown = _G.InCombatLockdown
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitName = _G.UnitName
local SetCVar = _G.C_CVar.SetCVar
local unpack = _G.unpack
local debugstack = _G.debugstack
local tostring = _G.tostring
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local table = _G.table
local math = _G.math
local UIParent = _G.UIParent
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS

-- RETRIEVING ADDON TABLE
local CM = AceAddon:GetAddon("CombatMode")

-- Module namespace
CM.HealingRadial = {}
local HR = CM.HealingRadial

---------------------------------------------------------------------------------------
--                                  STATE VARIABLES                                  --
---------------------------------------------------------------------------------------
local RadialState = {
  isActive = false,
  currentButton = nil,
  selectedSlice = nil,
  partyData = {},
  sliceFrames = {},
  mainFrame = nil,
  pendingUpdate = false,
  wasMouselooking = false,
  triggerButtons = {},
}

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

-- Maps button+modifier combo to: attribute prefix, attribute button suffix, action bar slot
local BUTTON_ATTR_MAP = {
  { prefix = "",       suffix = "1", slot = 1 }, -- Left click       → slot 1
  { prefix = "",       suffix = "2", slot = 2 }, -- Right click      → slot 2
  { prefix = "shift-", suffix = "1", slot = 3 }, -- Shift+Left       → slot 3
  { prefix = "shift-", suffix = "2", slot = 4 }, -- Shift+Right      → slot 4
  { prefix = "ctrl-",  suffix = "1", slot = 5 }, -- Ctrl+Left        → slot 5
  { prefix = "ctrl-",  suffix = "2", slot = 6 }, -- Ctrl+Right       → slot 6
  { prefix = "alt-",   suffix = "1", slot = 7 }, -- Alt+Left         → slot 7
  { prefix = "alt-",   suffix = "2", slot = 8 }, -- Alt+Right        → slot 8
}

---------------------------------------------------------------------------------------
--                                UTILITY FUNCTIONS                                  --
---------------------------------------------------------------------------------------
-- Calculate angle and distance from screen center to cursor position
local function GetMouseAngleAndDistanceFromCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cursorX, cursorY = cursorX / scale, cursorY / scale

  local centerX = UIParent:GetWidth() / 2
  local centerY = UIParent:GetHeight() / 2 + (CM.DB.global.crosshairY or 50)

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
  local sliceArc = CM.Constants.HealingRadialSliceArc
  local halfArc = sliceArc / 2

  for i, sliceData in ipairs(CM.Constants.HealingRadialSlices) do
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
  local dpsSlots = {2, 5, 4}
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

  CM.DebugPrint("Healing Radial: Refreshed party data, " .. #RadialState.partyData .. " members")
end

-- Update slice frame unit attributes (only safe out of combat)
local function UpdateSecureButtonTargets()
  if InCombatLockdown() then
    RadialState.pendingUpdate = true
    CM.DebugPrint("Healing Radial: Queueing button update (in combat)")
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
    CM.DebugPrint("Healing Radial: Slice " .. member.sliceIndex .. " = " .. member.unitId .. " (" .. member.name .. ")")
  end

  RadialState.pendingUpdate = false
end

-- Build the macrotext for a given action bar slot targeting a specific unit.
-- Returns macrotext string or nil if the slot is empty.
-- Uses /cast [@unit] SpellName for spells, /use [@unit] ItemName for items,
-- and raw macro body for user macros (which handle their own targeting).
local function BuildMacrotext(slot, unitId)
  local actionType, actionId = GetActionInfo(slot)
  if not actionType then return nil end

  if actionType == "spell" then
    local spellName = GetSpellName(actionId)
    if spellName and unitId then
      return "/cast [@" .. unitId .. "] " .. spellName
    elseif spellName then
      return "/cast " .. spellName
    end
  elseif actionType == "item" then
    local itemName = GetItemInfo(actionId)
    if itemName and unitId then
      return "/use [@" .. unitId .. "] " .. itemName
    elseif itemName then
      return "/use " .. itemName
    end
  elseif actionType == "macro" then
    -- User macros define their own targeting; use raw body
    return GetMacroBody(actionId)
  end

  return nil
end

-- Pre-configure modified attributes on all slices for spell casting.
-- SecureActionButtonTemplate resolves "shift-type1" before "type1" before "type"
-- automatically at click time, even during combat. We just need to set the
-- attributes ahead of time (out of combat) so the template knows what to do.
--
-- We use type="macro" + macrotext="/cast [@unitId] SpellName" because
-- type="spell" does not work on addon-created SecureActionButtonTemplate buttons,
-- while type="macro" with macrotext does.
--
-- Called on init, on action bar changes, on roster changes, and on combat end.
local function UpdateSliceActionAttributes()
  if InCombatLockdown() then
    RadialState.pendingUpdate = true
    CM.DebugPrint("Healing Radial: Queueing action attr update (in combat)")
    return
  end

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if not slice then break end

    local unitId = slice:GetAttribute("unit")

    for _, mapping in ipairs(BUTTON_ATTR_MAP) do
      local p = mapping.prefix   -- "" or "shift-" or "ctrl-" or "alt-"
      local s = mapping.suffix   -- "1" (left) or "2" (right)
      local macrotext = BuildMacrotext(mapping.slot, unitId)

      if macrotext then
        slice:SetAttribute(p .. "type" .. s, "macro")
        slice:SetAttribute(p .. "macrotext" .. s, macrotext)
        CM.DebugPrint("  Slice " .. i .. " (" .. tostring(unitId) .. "): " .. p .. "type" .. s .. "=macro -> " .. macrotext)
      else
        -- Empty slot: target on click (harmless fallback)
        slice:SetAttribute(p .. "type" .. s, "target")
        slice:SetAttribute(p .. "macrotext" .. s, nil)
      end
    end
  end

  CM.DebugPrint("Healing Radial: Updated slice action attributes")
end

-- Sync the full-screen click catcher's attributes to the currently angle-selected slice,
-- so clicks anywhere in that slice's angle trigger the same action as clicking the slice.
local function SyncClickCatcherAttributes()
  local catcher = RadialState.clickCatcher
  if not catcher then return end

  local sliceIndex = RadialState.selectedSlice
  if not sliceIndex then
    catcher:SetAttribute("unit", nil)
    catcher:SetAttribute("type", "target")
    for _, mapping in ipairs(BUTTON_ATTR_MAP) do
      local p, s = mapping.prefix, mapping.suffix
      catcher:SetAttribute(p .. "type" .. s, "target")
      catcher:SetAttribute(p .. "macrotext" .. s, nil)
    end
    return
  end

  local unitId = nil
  for _, member in ipairs(RadialState.partyData) do
    if member.sliceIndex == sliceIndex then
      unitId = member.unitId
      break
    end
  end

  catcher:SetAttribute("unit", unitId)
  catcher:SetAttribute("type", "target")
  for _, mapping in ipairs(BUTTON_ATTR_MAP) do
    local p, s = mapping.prefix, mapping.suffix
    local macrotext = BuildMacrotext(mapping.slot, unitId)
    if macrotext then
      catcher:SetAttribute(p .. "type" .. s, "macro")
      catcher:SetAttribute(p .. "macrotext" .. s, macrotext)
    else
      catcher:SetAttribute(p .. "type" .. s, "target")
      catcher:SetAttribute(p .. "macrotext" .. s, nil)
    end
  end
end

---------------------------------------------------------------------------------------
--                                FRAME CREATION                                     --
---------------------------------------------------------------------------------------
-- Inner anchor point (edge toward radial center) so scaling grows outward from center
-- and top/bottom slices don't displace asymmetrically. Returns anchor, offsetX, offsetY.
-- Uses fixed base size for positioning (sliceSize is now a scale factor, not pixel size)
local BASE_SLICE_SIZE = 80 -- Fixed base size for slice frame
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
  local config = CM.DB.global.healingRadial
  local sliceData = CM.Constants.HealingRadialSlices[sliceIndex]
  local angle = sliceData.angle
  local radius = config.sliceRadius
  local sliceScale = config.sliceSize or 1.0 -- sliceSize is now a scale factor (0.5-1.5)

  -- Anchor slice by its inner edge to radial center (mainFrame) so SetScale grows
  -- outward from center; otherwise top slices move up and bottom move down asymmetrically.
  local radialCenter = RadialState.mainFrame
  local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

  -- Parent to radial center frame so anchor is relative to center. SetPoint is set once at creation.
  -- Use fixed base size; sliceSize controls scale of all elements
  local slice = CreateFrame("Button", "CMHealRadialSlice" .. sliceIndex, radialCenter, "SecureActionButtonTemplate")
  slice:SetFrameStrata("DIALOG")
  slice:SetSize(BASE_SLICE_SIZE, BASE_SLICE_SIZE)
  slice:SetPoint(anchor, radialCenter, "CENTER", offsetX, offsetY)
  slice:SetScale(sliceScale) -- Apply scale factor to all elements
  -- Base type="target" is overridden by modified attributes (type1, shift-type2, etc.)
  -- set by UpdateSliceActionAttributes(). The unit attribute is used by type="target"
  -- for hover-targeting fallback; spell casting uses macrotext with [@unit] instead.
  slice:SetAttribute("type", "target")
  slice:RegisterForClicks("AnyUp", "AnyDown")
  slice.sliceIndex = sliceIndex

  -- Health bar background (repositioned in UpdateSliceVisual below name text when name size changes)
  slice.healthBG = slice:CreateTexture(nil, "BORDER")
  slice.healthBG:SetColorTexture(0.15, 0.15, 0.15, 0.9)
  slice.healthBG:SetSize(BASE_SLICE_SIZE - 16, 10)
  slice.healthBG:SetPoint("BOTTOM", slice, "BOTTOM", 0, 8)

  -- Health bar fill (StatusBar accepts secret values from UnitHealth)
  slice.healthFill = CreateFrame("StatusBar", nil, slice)
  slice.healthFill:SetPoint("LEFT", slice.healthBG, "LEFT", 1, 0)
  slice.healthFill:SetSize(BASE_SLICE_SIZE - 18, 8)
  slice.healthFill:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
  slice.healthFill:SetStatusBarColor(unpack(config.healthyColor))

  -- Role icon background/shadow (created before role icon so it's behind it)
  local roleIconSize = config.roleIconSize or 18
  slice.roleIconBG = slice:CreateTexture(nil, "BORDER")
  slice.roleIconBG:SetTexture("Interface\\AddOns\\CombatMode\\assets\\circlemask.blp")
  slice.roleIconBG:SetSize(roleIconSize * 1.1, roleIconSize * 1.1) -- 10% larger for shadow
  slice.roleIconBG:SetPoint("TOP", slice, "TOP", -1, 0)
  slice.roleIconBG:SetBlendMode("BLEND")
  slice.roleIconBG:SetVertexColor(0, 0, 0, 0.3)

  -- Role icon (created before name text so name can anchor below it)
  slice.roleIcon = slice:CreateTexture(nil, "OVERLAY")
  slice.roleIcon:SetSize(roleIconSize, roleIconSize)
  slice.roleIcon:SetPoint("TOP", slice, "TOP", 0, -4)

  -- Name text (below role icon so it doesn't overlap when icon size increases)
  slice.nameText = slice:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  slice.nameText:SetPoint("TOP", slice.roleIcon, "BOTTOM", 0, -2)
  slice.nameText:SetTextColor(1, 1, 1, 1)

  -- Smooth scale on hover: duration-based like Core cursor pulse (scaleStart/scaleTarget/scaleElapsed)
  -- Initial scale is sliceSize (scale factor), hover scales to sliceSize * 1.1 (10% increase)
  slice.targetScale = sliceScale
  slice.scaleStart = sliceScale
  slice.scaleElapsed = -1 -- -1 = idle, 0+ = animating

  -- Visual feedback on mouse enter/leave: scale slice instead of yellow highlight.
  -- Spell casting uses type="macro" with macrotext="/cast [@unit] Spell"
  -- set by UpdateSliceActionAttributes(), triggered by hardware mouse clicks.
  slice:HookScript("PostClick", function(self, btn)
    CM.DebugPrint("Healing Radial: PostClick slice " .. self.sliceIndex
      .. " btn=" .. tostring(btn) .. " unit=" .. tostring(self:GetAttribute("unit")))
  end)
  -- Selection is driven by cursor angle in TrackMousePosition (traditional pie-style radial), not OnEnter/OnLeave.
  -- Slices remain clickable for casting.

  -- Keep slices always :Show() and EnableMouse(true) so they work in combat.
  -- Show/Hide, EnableMouse, SetPoint, ClearAllPoints are ALL protected on
  -- secure frames during InCombatLockdown. Only SetAlpha is safe to toggle.
  slice:SetAlpha(0)
  slice:EnableMouse(true)

  RadialState.sliceFrames[sliceIndex] = slice
  return slice
end

-- Update main frame vertical position when crosshair Y changes (no reload needed)
function HR.UpdateMainFramePosition()
  if not RadialState.mainFrame then
    return
  end
  local crosshairY = CM.DB.global and CM.DB.global.crosshairY or 50
  RadialState.mainFrame:ClearAllPoints()
  RadialState.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, crosshairY)
end

-- Update slice positions and sizes when config changes (sliceRadius or sliceSize)
-- SetPoint is protected on secure frames during combat, so we queue updates if needed
function HR.UpdateSlicePositionsAndSizes()
  if not RadialState.sliceFrames or not RadialState.mainFrame then
    return
  end

  local config = CM.DB.global.healingRadial
  if not config then return end

  local radius = config.sliceRadius or 100
  local sliceScale = config.sliceSize or 1.0 -- sliceSize is now a scale factor

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      local sliceData = CM.Constants.HealingRadialSlices[i]
      if sliceData then
        local angle = sliceData.angle
        local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

        -- Update scale (safe in combat) - this scales all elements
        slice:SetScale(sliceScale)

        -- Update position (protected during combat, but try anyway - will work out of combat)
        if not InCombatLockdown() then
          slice:ClearAllPoints()
          slice:SetPoint(anchor, RadialState.mainFrame, "CENTER", offsetX, offsetY)
        else
          -- Queue update for after combat
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
    "BUTTON1", "BUTTON2",
    "SHIFT-BUTTON1", "SHIFT-BUTTON2",
    "CTRL-BUTTON1", "CTRL-BUTTON2",
    "ALT-BUTTON1", "ALT-BUTTON2",
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

-- Set up the mouselook override bindings for healing radial
function HR.SetupMouselookBindings()
  if not RadialState.triggerButtons then
    return
  end

  local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

  for key, triggerBtn in pairs(RadialState.triggerButtons) do
    -- Bind the mouse button to click the trigger button (shows radial)
    SetMouselookOverrideBinding(key, "CLICK " .. triggerBtn:GetName() .. ":LeftButton")
    CM.DebugPrint("Healing Radial: Bound " .. key .. " to " .. triggerBtn:GetName())
  end
end

-- Clear the mouselook override bindings (restore normal Combat Mode behavior)
function HR.ClearMouselookBindings()
  local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

  for _, key in ipairs({"BUTTON1", "BUTTON2", "SHIFT-BUTTON1", "SHIFT-BUTTON2", "CTRL-BUTTON1", "CTRL-BUTTON2", "ALT-BUTTON1", "ALT-BUTTON2"}) do
    SetMouselookOverrideBinding(key, nil)
  end
  CM.DebugPrint("Healing Radial: Cleared mouselook bindings")
end

-- Update capture frame visibility based on mouselook state
-- This should be called from Core.lua's mouselook handlers
function HR.OnMouselookChanged(isMouselooking)
  -- Dismiss radial if mouselook activates while radial is open
  -- This prevents the radial from staying open when user toggles mouselook via regular keybind
  CM.DebugPrint("Healing Radial: OnMouselookChanged(" .. tostring(isMouselooking) .. ") active=" .. tostring(RadialState.isActive) .. " btn=" .. tostring(RadialState.currentButton))

  if RadialState.isActive then
    if isMouselooking then
      -- Mouselook activated - dismiss radial
      HR.Hide() -- false = don't execute spell
    elseif RadialState.currentButton then
      -- Mouselook deactivated and radial was opened via mouse button - hide it
      -- Don't auto-hide when opened via keybind (currentButton == nil) since
      -- the keybind handler manages the lifecycle.
      HR.Hide() -- false = don't execute spell
    end
  end
end

-- Clear radial state after loading screen / zone change so IsHealingRadialActive() is false
-- and crosshair visibility can sync correctly. Does not re-engage mouselook or touch crosshair.
function HR.DismissOnLoad()
  if not RadialState.isActive then
    return
  end
  if RadialState.mainFrame then
    RadialState.mainFrame:SetScript("OnUpdate", nil)
    RadialState.mainFrame:Hide()
  end
  RadialState.isActive = false
  RadialState.selectedSlice = nil
  RadialState.currentButton = nil
  RadialState.boundKey = nil
end

-- Toggle the healing radial system (called when enabled/disabled in settings)
function HR.SetCaptureActive(active)
  if active then
    CM.DebugPrint("Healing Radial: Activated")
  else
    CM.DebugPrint("Healing Radial: Deactivated")
  end
end

local function CreateMainFrame()
  -- Main frame for center dot, OnUpdate, and radial center (slices parented here so scale grows from center).
  local mainFrame = CreateFrame("Frame", "CombatModeHealingRadialFrame", UIParent)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetSize(400, 400)
  mainFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or 50)
  mainFrame:Hide()

  RadialState.mainFrame = mainFrame

  -- Center arrow: rotates with cursor, colored by selected slice's party member class.
  -- Size and opacity use the user's crosshair settings (CM.DB.global.crosshairSize / crosshairOpacity).
  local defaultSize = CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global and CM.Constants.DatabaseDefaults.global.crosshairSize or 64
  local defaultOpacity = CM.Constants.DatabaseDefaults and CM.Constants.DatabaseDefaults.global and CM.Constants.DatabaseDefaults.global.crosshairOpacity or 1
  local arrowSize = (CM.DB.global and CM.DB.global.crosshairSize) or defaultSize
  local arrowOpacity = (CM.DB.global and CM.DB.global.crosshairOpacity) or defaultOpacity
  local arrowFrame = CreateFrame("Frame", nil, mainFrame)
  arrowFrame:SetSize(arrowSize, arrowSize)
  arrowFrame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  arrowFrame:SetFrameStrata("DIALOG")
  arrowFrame:SetFrameLevel(2)
  arrowFrame:SetAlpha(arrowOpacity)
  local arrowTex = arrowFrame:CreateTexture(nil, "OVERLAY")
  arrowTex:SetTexture("Interface\\AddOns\\CombatMode\\assets\\arrow.blp")
  arrowTex:SetAllPoints(arrowFrame)
  arrowTex:SetBlendMode("BLEND")
  RadialState.centerArrowFrame = arrowFrame
  RadialState.centerArrowTexture = arrowTex

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

    local currentScale = self.arrowLockInStartingScale + (self.arrowLockInTargetScale - self.arrowLockInStartingScale) * easedProgress
    self:SetScale(currentScale)

    local currentAlpha = self.arrowLockInStartingAlpha + (self.arrowLockInTargetAlpha - self.arrowLockInStartingAlpha) * easedProgress
    self:SetAlpha(currentAlpha)
  end)

  -- Full-screen click catcher: receives clicks outside the slice icons so that clicking
  -- anywhere within a slice's angle selects/casts for that slice (traditional radial).
  -- Created before slices so slices are on top and get clicks when cursor is over them.
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local catcher = CreateFrame("Button", "CMHealingRadialClickCatcher", mainFrame, "SecureActionButtonTemplate")
  catcher:SetFrameStrata("DIALOG")
  catcher:SetFrameLevel(0)
  catcher:SetSize(w * 2, h * 2)
  catcher:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  catcher:SetAttribute("type", "target")
  catcher:RegisterForClicks("AnyUp", "AnyDown")
  catcher:EnableMouse(true)
  catcher:SetAlpha(0)
  catcher:Show()
  RadialState.clickCatcher = catcher

  -- Create slice frames (parented to mainFrame, anchored by inner edge so hover scale is symmetric).
  for i = 1, 5 do
    CreateSliceFrame(i)
  end
end

---------------------------------------------------------------------------------------
--                                VISUAL UPDATES                                     --
---------------------------------------------------------------------------------------
local function UpdateSliceVisual(sliceIndex)
  local slice = RadialState.sliceFrames[sliceIndex]
  local config = CM.DB.global.healingRadial

  -- Find member assigned to this slice
  local memberData = nil
  for _, member in ipairs(RadialState.partyData) do
    if member.sliceIndex == sliceIndex then
      memberData = member
      break
    end
  end

  if not memberData or not UnitExists(memberData.unitId) then
    -- Use alpha only (not Hide/Show or EnableMouse) to avoid protected frame errors in combat
    slice:SetAlpha(0)
    return
  end

  -- Show visually via alpha (combat-safe)
  slice:SetAlpha(1)

  -- Update name (class-coloured; show "You" for the player; font/size with drop shadow; always shown)
  local fontPath = "Fonts\\FRIZQT__.TTF"
  local fontSize = config.nameFontSize or 12
  -- Always use drop shadow (no outline)
  slice.nameText:SetFont(fontPath, fontSize, nil)
  slice.nameText:SetShadowColor(0, 0, 0, 1)
  slice.nameText:SetShadowOffset(1, -1)
  local displayName = (memberData.unitId == "player") and "You" or (memberData.name or "Unknown")
  if #displayName > 10 then
    displayName = displayName:sub(1, 9) .. "..."
  end
  local color = (memberData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberData.class])
    and RAID_CLASS_COLORS[memberData.class]
    or { r = 1, g = 1, b = 1 }
  slice.nameText:SetTextColor(color.r, color.g, color.b, 1)
  slice.nameText:SetText(displayName)
  slice.nameText:Show()
  -- Position health bar below name so it doesn't overlap when font size is large
  slice.healthBG:ClearAllPoints()
  slice.healthBG:SetPoint("TOP", slice.nameText, "BOTTOM", 0, -4)

  -- Update health bar (using StatusBar to handle secret values from 12.0.0)
  if config.showHealthBars then
    local health = UnitHealth(memberData.unitId)
    local maxHealth = UnitHealthMax(memberData.unitId)

    slice.healthFill:SetMinMaxValues(0, maxHealth)
    slice.healthFill:SetValue(health)

    -- Color and percent text via pcall to safely handle secret values
    local ok, pct = pcall(function()
      local h = UnitHealth(memberData.unitId)
      local m = UnitHealthMax(memberData.unitId)
      return m > 0 and (h / m) or 1
    end)

    if ok and pct then
      if pct > 0.5 then
        slice.healthFill:SetStatusBarColor(unpack(config.healthyColor))
      elseif pct > 0.25 then
        slice.healthFill:SetStatusBarColor(unpack(config.damagedColor))
      else
        slice.healthFill:SetStatusBarColor(unpack(config.criticalColor))
      end
    else
      -- Values are secret; bar still fills correctly via StatusBar, use default color
      slice.healthFill:SetStatusBarColor(unpack(config.healthyColor))
    end

    slice.healthBG:Show()
    slice.healthFill:Show()
  else
    slice.healthBG:Hide()
    slice.healthFill:Hide()
  end

  -- Update role icon background/shadow (always shown when role icon is shown)
  local size = config.roleIconSize or 18
  slice.roleIconBG:SetSize(size * 1.1, size * 1.1) -- 10% larger for shadow

  -- Update role icon (always shown)
  slice.roleIcon:SetSize(size, size)
  local roleAtlas = {
    TANK = "UI-LFG-RoleIcon-Tank",
    HEALER = "UI-LFG-RoleIcon-Healer",
    DAMAGER = "UI-LFG-RoleIcon-DPS",
  }
  if roleAtlas[memberData.role] then
    slice.roleIcon:SetAtlas(roleAtlas[memberData.role])
    slice.roleIcon:Show()
    slice.roleIconBG:Show() -- Show background when role icon is shown
  else
    slice.roleIcon:Hide()
    slice.roleIconBG:Hide() -- Hide background when role icon is hidden
  end
end

local function UpdateAllSlices()
  for i = 1, 5 do
    UpdateSliceVisual(i)
  end
end

-- Accessible via HR so closures created before this point can call it
function HR.HighlightSlice(sliceIndex)
  -- Start scale transition: grow selected by 10% (sliceSize * 1.1), others back to sliceSize
  -- (duration-based in TrackMousePosition, like Core pulse)
  local config = CM.DB.global.healingRadial
  local baseScale = config and config.sliceSize or 1.0
  local hoverScale = baseScale * 1.1 -- 10% increase

  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice.scaleStart = slice:GetScale()
      if i == sliceIndex and slice:GetAlpha() > 0 then
        slice.targetScale = hoverScale
      else
        slice.targetScale = baseScale
      end
      slice.scaleElapsed = 0
    end
  end
end

---------------------------------------------------------------------------------------
--                              RADIAL CONTROL                                       --
---------------------------------------------------------------------------------------
-- Check if the triggering mouse button is still held down
local function IsMouseButtonStillDown(buttonKey)
  if not buttonKey then return false end

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

local function TrackMousePosition(_, elapsed)
  if not RadialState.isActive then
    return
  end

  -- Check button release to close the radial (only when opened via mouse button, not keybind)
  if RadialState.currentButton then
    local elapsed_since_show = _G.GetTime() - (RadialState.showTime or 0)
    if elapsed_since_show > 0.2 then
      if not IsMouseButtonStillDown(RadialState.currentButton) then
        CM.DebugPrint("Healing Radial: Button released, closing (combat=" .. tostring(InCombatLockdown()) .. ")")
        HR.ExecuteAndHide()
        return
      end
    end
  end
  -- When opened via keybind, key release is handled by HideFromKeybind()
  -- via runOnUp binding (with spurious key-up counter).

  -- Traditional radial: selection follows cursor angle (entire screen = pie chart)
  -- Center acts as neutral zone - if cursor is too close, no slice is selected
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30 -- pixels from center where no slice is selected
  local sliceIndex = nil
  if distance > CENTER_DEAD_ZONE then
    sliceIndex = GetSliceFromAngle(angle)
  end
  if sliceIndex ~= RadialState.selectedSlice then
    RadialState.selectedSlice = sliceIndex
    HR.HighlightSlice(sliceIndex)
  end

  -- Keep click catcher in sync so clicks anywhere in the slice's angle trigger that slice's action
  SyncClickCatcherAttributes()

  -- Center arrow: rotate toward cursor, tint by selected slice's class color; use crosshair size/opacity
  -- Arrow alpha: 1.0 over a player, 0.5 not over a player, 0.2 dead center. Don't override if lock-in animation is running.
  local arrowFrame = RadialState.centerArrowFrame
  local arrowTex = RadialState.centerArrowTexture
  if arrowFrame and arrowTex then
    local size = CM.DB.global.crosshairSize or 64
    arrowFrame:SetSize(size, size)
    if arrowFrame.arrowLockInElapsed == -1 then
      local arrowAlpha
      if distance <= CENTER_DEAD_ZONE then
        arrowAlpha = 0.2 -- dead center
      else
        local selectedSlice = sliceIndex and RadialState.sliceFrames[sliceIndex]
        local unitId = selectedSlice and selectedSlice:GetAttribute("unit")
        arrowAlpha = (unitId and unitId ~= "") and 1.0 or 0.5 -- 1.0 if slice has a unit, else 0.5
      end
      arrowFrame:SetAlpha(arrowAlpha)
    end
    -- Rotation: angle 0 = right, 90 = up; texture default is typically up, so rotate by (angle - 90)
    arrowTex:SetRotation(math.rad(angle - 90))
    local r, g, b = 1, 1, 1
    if sliceIndex then
      for _, member in ipairs(RadialState.partyData) do
        if member.sliceIndex == sliceIndex and member.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[member.class] then
          local c = RAID_CLASS_COLORS[member.class]
          r, g, b = c.r, c.g, c.b
          break
        end
      end
    end
    arrowTex:SetVertexColor(r, g, b, 0.7)
  end

  -- Smooth scale transition (duration-based, same pattern as Core cursor pulse)
  local SLICE_SCALE_DURATION = 0.1
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice and slice.scaleElapsed and slice.scaleElapsed >= 0 then
      slice.scaleElapsed = slice.scaleElapsed + elapsed
      if slice.scaleElapsed >= SLICE_SCALE_DURATION then
        slice.scaleElapsed = -1
        slice:SetScale(slice.targetScale)
      else
        local progress = slice.scaleElapsed / SLICE_SCALE_DURATION
        local scale = slice.scaleStart + (slice.targetScale - slice.scaleStart) * progress
        slice:SetScale(scale)
      end
    end
  end

  -- Update health bars periodically
  UpdateAllSlices()
end

function HR.Show(buttonKey)
  if not CM.DB.global.healingRadial or not CM.DB.global.healingRadial.enabled then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  -- Store state
  RadialState.isActive = true
  RadialState.currentButton = buttonKey
  RadialState.wasMouselooking = _G.IsMouselooking()
  RadialState.showTime = _G.GetTime()

  -- Stop mouselook so cursor is free for slice selection
  -- Use UnlockFreeLook() instead of direct MouselookStop() to ensure proper state management
  if RadialState.wasMouselooking then
    CM.UnlockFreeLook()
  end

  -- Initial selection from current cursor angle (traditional radial: screen = pie)
  -- Center acts as neutral zone - if cursor is too close, no slice is selected
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30 -- pixels from center where no slice is selected
  RadialState.selectedSlice = nil
  if distance > CENTER_DEAD_ZONE then
    RadialState.selectedSlice = GetSliceFromAngle(angle)
  end
  HR.HighlightSlice(RadialState.selectedSlice)

  -- Spell casting happens via modified attributes (type1="macro", macrotext1=...)
  -- on slice frames, triggered by hardware mouse clicks over a slice.

  -- Update visuals
  UpdateAllSlices()

  -- Show mainFrame (center dot visual + OnUpdate host). Safe in combat since
  -- it has no secure descendants — slices are parented to UIParent directly.
  RadialState.mainFrame:Show()

  -- Start mouse tracking
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation
  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    local currentScale = arrowFrame:GetScale()
    local currentAlpha = arrowFrame:GetAlpha()
    arrowFrame.arrowLockInOriginalScale = currentScale
    arrowFrame.arrowLockInOriginalAlpha = currentAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = currentScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = currentScale
    arrowFrame.arrowLockInTargetAlpha = currentAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Healing Radial: Shown for " .. buttonKey)

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
    CM.DebugPrint("Healing Radial: Closing (slice " .. RadialState.selectedSlice .. " was hovered)")
  else
    CM.DebugPrint("Healing Radial: Closing (no slice selected)")
  end

  HR.Hide()
end

function HR.Hide()
  if not RadialState.isActive then
    return
  end
  CM.DebugPrint("Healing Radial: HR.Hide called from: " .. (debugstack(2, 1, 0) or "unknown"))

  -- Stop mouse tracking
  RadialState.mainFrame:SetScript("OnUpdate", nil)

  -- Hide all slices via alpha; reset scale and animation state to base sliceSize scale
  local config = CM.DB.global.healingRadial
  local baseScale = config and config.sliceSize or 1.0
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
      slice.targetScale = baseScale
      slice.scaleStart = baseScale
      slice.scaleElapsed = -1
      slice:SetScale(baseScale)
    end
  end

  -- Reset arrow animation state (no unlock animation needed since frame is hidden immediately)
  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    arrowFrame.arrowLockInElapsed = -1
  end

  -- Hide mainFrame (center dot). Safe in combat — no secure descendants.
  RadialState.mainFrame:Hide()

  -- Mark inactive so ShouldFreeLookBeOff() via IsHealingRadialActive()
  -- no longer detects the radial as open.
  RadialState.isActive = false
  RadialState.selectedSlice = nil

  -- Re-engage mouselook if it was active before radial opened
  -- Use LockFreeLookWithCVar() to ensure proper state management and handle camera jolt CVar
  if RadialState.wasMouselooking then
    -- Restore crosshair before starting mouselook (needed for lock-in animation)
    if CM.DB.global.crosshair then
      CM.DisplayCrosshair(true)
    end
    -- LockFreeLookWithCVar handles CVar, calls MouselookStart, handles UI state,
    -- plays animations, and notifies radial via OnMouselookChanged
    SetCVar("CursorFreelookCentering", 0)
    CM.LockFreeLook()
  else
    -- Restore crosshair even if mouselook wasn't active
    if CM.DB.global.crosshair then
      CM.DisplayCrosshair(true)
    end
  end

  CM.DebugPrint("Healing Radial: Hidden (combat=" .. tostring(InCombatLockdown()) .. ")")
end

-- Open radial via keybind (targeting on hover, casting via mouse clicks on slices)
function HR.ShowFromKeybind()
  if not CM.DB.global.healingRadial or not CM.DB.global.healingRadial.enabled then
    return false
  end

  -- Only allow activation when mouselook is active
  if not _G.IsMouselooking() then
    return false
  end

  if RadialState.isActive then
    return false
  end

  -- Find which key is bound so we can poll for release in TrackMousePosition
  local boundKey = _G.GetBindingKey("(Hold) Healing Radial")

  -- Store state (currentButton = nil signals keybind mode)
  RadialState.isActive = true
  RadialState.currentButton = nil
  RadialState.boundKey = boundKey
  RadialState.keyUpCount = 0
  RadialState.wasMouselooking = _G.IsMouselooking()
  RadialState.showTime = _G.GetTime()

  -- Stop mouselook so cursor is free for slice selection.
  -- NOTE: MouselookStop causes spurious key-up events for held keys. The
  -- time-based filter in HideFromKeybind handles this by ignoring key-ups
  -- that arrive within 0.3s of showing.
  -- Use UnlockFreeLook() instead of direct MouselookStop() to ensure proper state management
  if RadialState.wasMouselooking then
    CM.UnlockFreeLook()
  end

  -- Initial selection from current cursor angle (traditional radial: screen = pie)
  -- Center acts as neutral zone - if cursor is too close, no slice is selected
  local angle, distance = GetMouseAngleAndDistanceFromCenter()
  local CENTER_DEAD_ZONE = 30 -- pixels from center where no slice is selected
  RadialState.selectedSlice = nil
  if distance > CENTER_DEAD_ZONE then
    RadialState.selectedSlice = GetSliceFromAngle(angle)
  end
  HR.HighlightSlice(RadialState.selectedSlice)

  -- Update visuals
  UpdateAllSlices()

  -- Show mainFrame (center dot + OnUpdate host)
  RadialState.mainFrame:Show()

  -- Start mouse tracking (for health bar updates and OnEnter/OnLeave)
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Play arrow lock-in animation
  local arrowFrame = RadialState.centerArrowFrame
  if arrowFrame then
    local currentScale = arrowFrame:GetScale()
    local currentAlpha = arrowFrame:GetAlpha()
    arrowFrame.arrowLockInOriginalScale = currentScale
    arrowFrame.arrowLockInOriginalAlpha = currentAlpha
    arrowFrame.arrowLockInIsUnlocking = false
    arrowFrame.arrowLockInStartingScale = currentScale * 1.3
    arrowFrame.arrowLockInStartingAlpha = 0.0
    arrowFrame.arrowLockInTargetScale = currentScale
    arrowFrame.arrowLockInTargetAlpha = currentAlpha
    arrowFrame:SetScale(arrowFrame.arrowLockInStartingScale)
    arrowFrame:SetAlpha(arrowFrame.arrowLockInStartingAlpha)
    arrowFrame.arrowLockInElapsed = 0
  end

  -- Hide crosshair while radial is visible
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Healing Radial: Shown via keybind (combat=" .. tostring(InCombatLockdown()) .. ", wasML=" .. tostring(RadialState.wasMouselooking) .. ")")
  return true
end

-- Close radial opened via keybind
function HR.HideFromKeybind()
  if not RadialState.isActive then
    CM.DebugPrint("Healing Radial: HideFromKeybind called but radial not active")
    return
  end
  RadialState.keyUpCount = (RadialState.keyUpCount or 0) + 1
  local elapsed = _G.GetTime() - (RadialState.showTime or 0)
  CM.DebugPrint("Healing Radial: HideFromKeybind key-up #" .. RadialState.keyUpCount .. " elapsed=" .. string.format("%.3f", elapsed) .. "s combat=" .. tostring(InCombatLockdown()))
  -- MouselookStop causes WoW to fire spurious key-up events. If mouselook
  -- was active when the radial opened, skip key-ups that arrive before the
  -- OnUpdate loop has had time to process (within 0.3s of showing).
  if RadialState.wasMouselooking and elapsed < 0.3 then
    CM.DebugPrint("Healing Radial: Ignoring spurious key-up")
    return
  end
  HR.Hide()
end

function HR.IsActive()
  return RadialState.isActive
end

function HR.IsEnabled()
  return CM.DB.global.healingRadial and CM.DB.global.healingRadial.enabled
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

  if RadialState.isActive then
    UpdateAllSlices()
  end
end

function HR.OnCombatEnd()
  -- Apply any pending updates that were blocked during combat
  if RadialState.pendingUpdate then
    UpdateSecureButtonTargets()
    UpdateSliceActionAttributes()
    HR.UpdateSlicePositionsAndSizes()
  end
end

-- Called when action bar content changes (ACTIONBAR_SLOT_CHANGED).
-- Refreshes the modified attributes so slices cast the correct spells.
function HR.OnActionBarChanged()
  UpdateSliceActionAttributes()
end

---------------------------------------------------------------------------------------
--                              INITIALIZATION                                       --
---------------------------------------------------------------------------------------
function HR.Initialize()
  -- Ensure defaults exist
  if not CM.DB.global.healingRadial then
    CM.DB.global.healingRadial = CM.Constants.DatabaseDefaults.global.healingRadial
  end

  CreateMainFrame()
  CreateMouseOverrideButtons()

  -- Initial party data and action bar attributes
  RefreshPartyData()
  UpdateSecureButtonTargets()
  UpdateSliceActionAttributes()

  CM.DebugPrint("Healing Radial: Initialized")
end

-- Expose state for Core.lua integration
function HR.GetState()
  return RadialState
end
