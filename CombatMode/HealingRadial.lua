---------------------------------------------------------------------------------------
--                              HEALING RADIAL MODULE                                --
---------------------------------------------------------------------------------------
-- A radial menu for quick party member targeting, designed for healers.
-- Shows party members as slices around screen center, cast on release.

-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")

-- CACHING GLOBAL VARIABLES
local CreateFrame = _G.CreateFrame
local GetActionInfo = _G.GetActionInfo
local GetCursorPosition = _G.GetCursorPosition
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsInGroup = _G.IsInGroup
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitName = _G.UnitName
local UIParent = _G.UIParent
local unpack = _G.unpack
local math = _G.math
local pairs = _G.pairs
local ipairs = _G.ipairs
local select = _G.select
local table = _G.table

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
  currentModifier = nil,
  selectedSlice = nil,
  partyData = {},
  sliceFrames = {},
  secureButtons = {},
  mainFrame = nil,
  sliceContainer = nil,
  pendingUpdate = false,
  wasMouselooking = false,
}

---------------------------------------------------------------------------------------
--                                UTILITY FUNCTIONS                                  --
---------------------------------------------------------------------------------------
-- Calculate angle from screen center to cursor position
local function GetMouseAngleFromCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cursorX, cursorY = cursorX / scale, cursorY / scale

  local centerX = UIParent:GetWidth() / 2
  local centerY = UIParent:GetHeight() / 2 + (CM.DB.global.crosshairY or 50)

  local dx = cursorX - centerX
  local dy = cursorY - centerY

  -- Convert to degrees (0 = right, counter-clockwise positive)
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then
    angle = angle + 360
  end

  return angle
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

-- Get the action slot based on button and modifier
local function GetActionSlotForButton(buttonKey, modifier)
  local slotMap = {
    ["BUTTON1"] = 1,
    ["BUTTON2"] = 2,
    ["SHIFT-BUTTON1"] = 3,
    ["SHIFT-BUTTON2"] = 4,
    ["CTRL-BUTTON1"] = 5,
    ["CTRL-BUTTON2"] = 6,
    ["ALT-BUTTON1"] = 7,
    ["ALT-BUTTON2"] = 8,
  }
  return slotMap[buttonKey] or 1
end

---------------------------------------------------------------------------------------
--                              PARTY DATA MANAGEMENT                                --
---------------------------------------------------------------------------------------
local function RefreshPartyData()
  RadialState.partyData = {}

  if not IsInGroup() then
    return
  end

  -- Collect all party members including self
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

-- Update secure button unit attributes (only safe out of combat)
local function UpdateSecureButtonTargets()
  if InCombatLockdown() then
    RadialState.pendingUpdate = true
    CM.DebugPrint("Healing Radial: Queueing button update (in combat)")
    return
  end

  -- Clear all buttons first
  for i = 1, 5 do
    local btn = RadialState.secureButtons[i]
    if btn then
      btn:SetAttribute("unit", nil)
    end
  end

  -- Assign units to buttons based on party data
  for _, member in ipairs(RadialState.partyData) do
    local btn = RadialState.secureButtons[member.sliceIndex]
    if btn then
      btn:SetAttribute("unit", member.unitId)
      CM.DebugPrint("Healing Radial: Slice " .. member.sliceIndex .. " = " .. member.unitId .. " (" .. member.name .. ")")
    end
  end

  RadialState.pendingUpdate = false
end

---------------------------------------------------------------------------------------
--                                FRAME CREATION                                     --
---------------------------------------------------------------------------------------
local function CreateSliceFrame(sliceIndex)
  local config = CM.DB.global.healingRadial
  local sliceData = CM.Constants.HealingRadialSlices[sliceIndex]
  local angle = sliceData.angle
  local radius = config.sliceRadius

  -- Calculate position using trigonometry
  local x = radius * math.cos(math.rad(angle))
  local y = radius * math.sin(math.rad(angle))

  local slice = CreateFrame("Frame", "CMHealRadialSlice" .. sliceIndex, RadialState.sliceContainer)
  slice:SetSize(config.sliceSize, config.sliceSize)
  slice:SetPoint("CENTER", RadialState.sliceContainer, "CENTER", x, y)

  -- Background
  slice.bg = slice:CreateTexture(nil, "BACKGROUND")
  slice.bg:SetAllPoints()
  slice.bg:SetColorTexture(unpack(config.backgroundColor))

  -- Health bar background
  slice.healthBG = slice:CreateTexture(nil, "BORDER")
  slice.healthBG:SetColorTexture(0.15, 0.15, 0.15, 0.9)
  slice.healthBG:SetSize(config.sliceSize - 16, 10)
  slice.healthBG:SetPoint("BOTTOM", slice, "BOTTOM", 0, 8)

  -- Health bar fill
  slice.healthFill = slice:CreateTexture(nil, "ARTWORK")
  slice.healthFill:SetColorTexture(unpack(config.healthyColor))
  slice.healthFill:SetPoint("LEFT", slice.healthBG, "LEFT", 1, 0)
  slice.healthFill:SetSize(config.sliceSize - 18, 8)

  -- Name text
  slice.nameText = slice:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  slice.nameText:SetPoint("CENTER", slice, "CENTER", 0, 8)
  slice.nameText:SetTextColor(1, 1, 1, 1)

  -- Health percent text
  slice.healthText = slice:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  slice.healthText:SetPoint("CENTER", slice.healthBG, "CENTER", 0, 0)
  slice.healthText:SetTextColor(1, 1, 1, 1)

  -- Role icon
  slice.roleIcon = slice:CreateTexture(nil, "OVERLAY")
  slice.roleIcon:SetSize(18, 18)
  slice.roleIcon:SetPoint("TOP", slice, "TOP", 0, -4)

  -- Highlight overlay (shown when selected)
  slice.highlight = slice:CreateTexture(nil, "OVERLAY", nil, 7)
  slice.highlight:SetAllPoints()
  slice.highlight:SetColorTexture(unpack(config.highlightColor))
  slice.highlight:Hide()

  -- Border when highlighted
  slice.border = slice:CreateTexture(nil, "OVERLAY", nil, 6)
  slice.border:SetPoint("TOPLEFT", -2, 2)
  slice.border:SetPoint("BOTTOMRIGHT", 2, -2)
  slice.border:SetColorTexture(1, 1, 0, 0.8)
  slice.border:Hide()

  slice:Hide()

  RadialState.sliceFrames[sliceIndex] = slice
  return slice
end

local function CreateSecureButtons()
  -- Create a secure container
  local container = CreateFrame("Frame", "CMHealRadialSecureContainer", UIParent, "SecureHandlerStateTemplate")
  container:SetSize(1, 1)
  container:SetPoint("CENTER")

  for i = 1, 5 do
    local btn = CreateFrame("Button", "CMHealRadialBtn" .. i, container, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("unit", nil)
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    btn:Hide()

    RadialState.secureButtons[i] = btn
  end

  -- Store reference for secure execution
  for i = 1, 5 do
    container:SetFrameRef("slice" .. i, RadialState.secureButtons[i])
  end

  RadialState.secureContainer = container
end

-- Create secure action buttons that will be bound to mouse buttons during mouselook
-- These handle both showing the radial (on press) and executing (on release)
local function CreateMouseOverrideButtons()
  -- Button key mappings
  local buttonMappings = {
    { key = "BUTTON1", actionSlot = 1 },
    { key = "BUTTON2", actionSlot = 2 },
    { key = "SHIFT-BUTTON1", actionSlot = 3 },
    { key = "SHIFT-BUTTON2", actionSlot = 4 },
    { key = "CTRL-BUTTON1", actionSlot = 5 },
    { key = "CTRL-BUTTON2", actionSlot = 6 },
    { key = "ALT-BUTTON1", actionSlot = 7 },
    { key = "ALT-BUTTON2", actionSlot = 8 },
  }

  RadialState.overrideButtons = {}

  for _, mapping in ipairs(buttonMappings) do
    -- Create a button that shows radial on PreClick and casts on PostClick
    local btn = CreateFrame("Button", "CMHealRadial_" .. mapping.key:gsub("-", "_"), UIParent, "SecureActionButtonTemplate")
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    btn.actionSlot = mapping.actionSlot
    btn.buttonKey = mapping.key

    -- PreClick: Show the radial (runs before secure action)
    btn:SetScript("PreClick", function(self, mouseButton, isDown)
      if isDown then
        -- Mouse button pressed - show radial
        HR.Show(self.buttonKey)
      end
    end)

    -- PostClick: Hide radial and potentially cast (runs after secure action)
    btn:SetScript("PostClick", function(self, mouseButton, isDown)
      if not isDown then
        -- Mouse button released - hide radial (spell already cast by secure action)
        HR.Hide(false) -- false because secure button already cast the spell
      end
    end)

    -- The secure button will be configured to cast the appropriate spell
    -- on the selected target when clicked
    btn:RegisterForClicks("AnyDown", "AnyUp")

    RadialState.overrideButtons[mapping.key] = btn
  end
end

-- Set up the mouselook override bindings for healing radial
function HR.SetupMouselookBindings()
  if not RadialState.overrideButtons then
    return
  end

  local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding

  for key, btn in pairs(RadialState.overrideButtons) do
    -- Bind the mouse button to click our override button
    SetMouselookOverrideBinding(key, "CLICK " .. btn:GetName() .. ":LeftButton")
    CM.DebugPrint("Healing Radial: Bound " .. key .. " to " .. btn:GetName())
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
  -- If radial was showing and we exit mouselook, hide it
  if not isMouselooking and RadialState.isActive then
    HR.Hide(false) -- false = don't execute spell
  end
end

-- Toggle the healing radial system (called when enabled/disabled in settings)
function HR.SetCaptureActive(active)
  if active then
    HR.SetupMouselookBindings()
    CM.DebugPrint("Healing Radial: Activated")
  else
    HR.ClearMouselookBindings()
    -- Restore normal Combat Mode bindings
    CM.OverrideDefaultButtons()
    CM.DebugPrint("Healing Radial: Deactivated")
  end
end

local function CreateMainFrame()
  -- Main frame (non-secure, for visuals)
  local mainFrame = CreateFrame("Frame", "CombatModeHealingRadialFrame", UIParent)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetSize(400, 400)
  mainFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or 50)
  mainFrame:Hide()

  -- Center indicator
  local centerDot = mainFrame:CreateTexture(nil, "ARTWORK")
  centerDot:SetSize(8, 8)
  centerDot:SetPoint("CENTER")
  centerDot:SetColorTexture(1, 1, 1, 0.5)
  mainFrame.centerDot = centerDot

  -- Slice container
  local sliceContainer = CreateFrame("Frame", nil, mainFrame)
  sliceContainer:SetAllPoints()
  RadialState.sliceContainer = sliceContainer

  -- Create slice frames
  for i = 1, 5 do
    CreateSliceFrame(i)
  end

  RadialState.mainFrame = mainFrame
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
    slice:Hide()
    return
  end

  slice:Show()

  -- Update name
  if config.showPlayerNames then
    local name = memberData.name or "Unknown"
    -- Truncate long names
    if #name > 10 then
      name = name:sub(1, 9) .. "..."
    end
    slice.nameText:SetText(name)
    slice.nameText:Show()
  else
    slice.nameText:Hide()
  end

  -- Update health bar
  if config.showHealthBars then
    local health = UnitHealth(memberData.unitId)
    local maxHealth = UnitHealthMax(memberData.unitId)
    local healthPercent = maxHealth > 0 and (health / maxHealth) or 1

    local maxWidth = config.sliceSize - 18
    slice.healthFill:SetWidth(math.max(1, maxWidth * healthPercent))

    -- Color by health level
    if healthPercent > 0.5 then
      slice.healthFill:SetColorTexture(unpack(config.healthyColor))
    elseif healthPercent > 0.25 then
      slice.healthFill:SetColorTexture(unpack(config.damagedColor))
    else
      slice.healthFill:SetColorTexture(unpack(config.criticalColor))
    end

    slice.healthBG:Show()
    slice.healthFill:Show()

    -- Health percent text
    if config.showHealthPercent then
      slice.healthText:SetText(math.floor(healthPercent * 100) .. "%")
      slice.healthText:Show()
    else
      slice.healthText:Hide()
    end
  else
    slice.healthBG:Hide()
    slice.healthFill:Hide()
    slice.healthText:Hide()
  end

  -- Update role icon
  if config.showRoleIcons then
    local roleAtlas = {
      TANK = "roleicon-tank",
      HEALER = "roleicon-healer",
      DAMAGER = "roleicon-dps",
    }
    if roleAtlas[memberData.role] then
      slice.roleIcon:SetAtlas(roleAtlas[memberData.role])
      slice.roleIcon:Show()
    else
      slice.roleIcon:Hide()
    end
  else
    slice.roleIcon:Hide()
  end
end

local function UpdateAllSlices()
  for i = 1, 5 do
    UpdateSliceVisual(i)
  end
end

local function HighlightSlice(sliceIndex)
  -- Clear all highlights
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice.highlight:Hide()
      slice.border:Hide()
    end
  end

  -- Highlight the selected slice
  if sliceIndex and RadialState.sliceFrames[sliceIndex] then
    local slice = RadialState.sliceFrames[sliceIndex]
    if slice:IsShown() then
      slice.highlight:Show()
      slice.border:Show()
    end
  end
end

---------------------------------------------------------------------------------------
--                              RADIAL CONTROL                                       --
---------------------------------------------------------------------------------------
local function TrackMousePosition(self, elapsed)
  if not RadialState.isActive then
    return
  end

  local angle = GetMouseAngleFromCenter()
  local newSlice = GetSliceFromAngle(angle)

  -- Only update if slice changed
  if newSlice ~= RadialState.selectedSlice then
    RadialState.selectedSlice = newSlice
    HighlightSlice(newSlice)

    -- Update the override button's target to match the selected slice
    -- This allows the secure button to cast on the correct target on release
    if not InCombatLockdown() and RadialState.currentButton and RadialState.overrideButtons then
      local overrideBtn = RadialState.overrideButtons[RadialState.currentButton]
      if overrideBtn then
        local targetUnit = nil
        if newSlice then
          -- Find the unit assigned to this slice
          for _, member in ipairs(RadialState.partyData) do
            if member.sliceIndex == newSlice then
              targetUnit = member.unitId
              break
            end
          end
        end
        overrideBtn:SetAttribute("unit", targetUnit)
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

  if not IsInGroup() then
    return false
  end

  -- Store state
  RadialState.isActive = true
  RadialState.currentButton = buttonKey
  RadialState.selectedSlice = nil
  RadialState.wasMouselooking = _G.IsMouselooking()

  -- Pause free look
  if RadialState.wasMouselooking then
    MouselookStop()
  end

  -- Update spell on the override button based on which button was pressed
  local actionSlot = GetActionSlotForButton(buttonKey)
  if not InCombatLockdown() and RadialState.overrideButtons then
    local overrideBtn = RadialState.overrideButtons[buttonKey]
    if overrideBtn then
      local actionType, actionId = GetActionInfo(actionSlot)
      if actionType == "spell" then
        overrideBtn:SetAttribute("type", "spell")
        overrideBtn:SetAttribute("spell", actionId)
      elseif actionType == "macro" then
        overrideBtn:SetAttribute("type", "macro")
        overrideBtn:SetAttribute("macro", actionId)
      elseif actionType == "item" then
        overrideBtn:SetAttribute("type", "item")
        overrideBtn:SetAttribute("item", actionId)
      else
        -- Default to action button
        overrideBtn:SetAttribute("type", "action")
        overrideBtn:SetAttribute("action", actionSlot)
      end
      -- Clear unit until user selects a slice
      overrideBtn:SetAttribute("unit", nil)
    end
  end

  -- Update visuals
  UpdateAllSlices()

  -- Show UI
  RadialState.mainFrame:SetAlpha(1)
  RadialState.mainFrame:Show()

  -- Start mouse tracking
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Hide crosshair while radial is visible
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Healing Radial: Shown for " .. buttonKey)

  return true
end

function HR.Hide(executeSpell)
  if not RadialState.isActive then
    return
  end

  -- Note: Spell execution is handled by the override button's secure action
  -- The executeSpell parameter is kept for API compatibility but no longer used

  -- Stop mouse tracking
  RadialState.mainFrame:SetScript("OnUpdate", nil)

  -- Hide UI
  RadialState.mainFrame:Hide()

  -- Restore state
  RadialState.isActive = false
  RadialState.selectedSlice = nil

  -- Restore crosshair
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(true)
  end

  -- Resume free look if it was active before
  if RadialState.wasMouselooking then
    MouselookStart()
  end

  CM.DebugPrint("Healing Radial: Hidden")
end

function HR.IsActive()
  return RadialState.isActive
end

function HR.IsEnabled()
  return CM.DB.global.healingRadial and CM.DB.global.healingRadial.enabled and IsInGroup()
end

---------------------------------------------------------------------------------------
--                              EVENT HANDLING                                       --
---------------------------------------------------------------------------------------
function HR.OnGroupRosterUpdate()
  RefreshPartyData()
  UpdateSecureButtonTargets()

  if RadialState.isActive then
    UpdateAllSlices()
  end
end

function HR.OnCombatEnd()
  -- Apply any pending updates
  if RadialState.pendingUpdate then
    UpdateSecureButtonTargets()
  end
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
  CreateSecureButtons()
  CreateMouseOverrideButtons()

  -- Initial party data
  RefreshPartyData()
  UpdateSecureButtonTargets()

  -- If healing radial is already enabled, set up the bindings
  if CM.DB.global.healingRadial.enabled then
    HR.SetupMouselookBindings()
  end

  CM.DebugPrint("Healing Radial: Initialized")
end

-- Expose state for Core.lua integration
function HR.GetState()
  return RadialState
end
