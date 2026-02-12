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
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAttribute("unit", nil)
    end
  end

  -- Assign units to secure buttons and slice frames based on party data
  for _, member in ipairs(RadialState.partyData) do
    local btn = RadialState.secureButtons[member.sliceIndex]
    if btn then
      btn:SetAttribute("unit", member.unitId)
    end
    local slice = RadialState.sliceFrames[member.sliceIndex]
    if slice then
      slice:SetAttribute("unit", member.unitId)
    end
    CM.DebugPrint("Healing Radial: Slice " .. member.sliceIndex .. " = " .. member.unitId .. " (" .. member.name .. ")")
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

  -- Parent directly to UIParent (not sliceContainer) to avoid secure frame hierarchy
  -- issues during InCombatLockdown. Position relative to screen center.
  local slice = CreateFrame("Button", "CMHealRadialSlice" .. sliceIndex, UIParent, "SecureActionButtonTemplate")
  slice:SetFrameStrata("DIALOG")
  slice:SetSize(config.sliceSize, config.sliceSize)
  local crosshairY = CM.DB.global.crosshairY or 50
  slice:SetPoint("CENTER", UIParent, "CENTER", x, crosshairY + y)
  slice:SetAttribute("type", "target")
  slice:SetAttribute("unit", nil)
  slice:RegisterForClicks("AnyUp", "AnyDown")
  slice.sliceIndex = sliceIndex

  -- Background
  slice.bg = slice:CreateTexture(nil, "BACKGROUND")
  slice.bg:SetAllPoints()
  slice.bg:SetColorTexture(unpack(config.backgroundColor))

  -- Health bar background
  slice.healthBG = slice:CreateTexture(nil, "BORDER")
  slice.healthBG:SetColorTexture(0.15, 0.15, 0.15, 0.9)
  slice.healthBG:SetSize(config.sliceSize - 16, 10)
  slice.healthBG:SetPoint("BOTTOM", slice, "BOTTOM", 0, 8)

  -- Health bar fill (StatusBar accepts secret values from UnitHealth)
  slice.healthFill = CreateFrame("StatusBar", nil, slice)
  slice.healthFill:SetPoint("LEFT", slice.healthBG, "LEFT", 1, 0)
  slice.healthFill:SetSize(config.sliceSize - 18, 8)
  slice.healthFill:SetStatusBarTexture("Interface\\BUTTONS\\WHITE8X8")
  slice.healthFill:SetStatusBarColor(unpack(config.healthyColor))

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

  -- Visual highlight + targeting on mouse enter
  slice:HookScript("OnEnter", function(self)
    RadialState.selectedSlice = self.sliceIndex
    HR.HighlightSlice(self.sliceIndex)
    -- Fire secure target action via Click() (attributes pre-configured before combat)
    if self:GetAttribute("unit") then
      self:Click()
    end
    CM.DebugPrint("Healing Radial: Hover slice " .. self.sliceIndex)
  end)
  slice:HookScript("OnLeave", function(self)
    if RadialState.selectedSlice == self.sliceIndex then
      RadialState.selectedSlice = nil
      HR.HighlightSlice(nil)
    end
  end)

  -- Keep slices always :Show() and EnableMouse(true) so they work in combat.
  -- SecureActionButtonTemplate can't have Show/Hide or EnableMouse toggled during
  -- InCombatLockdown. Use alpha only for visibility. Slices won't interfere when
  -- radial is hidden because mouselook captures the cursor.
  slice:SetAlpha(0)
  slice:EnableMouse(true)

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
    btn:SetAttribute("type", nil)
    btn:SetAttribute("unit", nil)
    btn:SetSize(1, 1)
    btn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    btn:Show()

    RadialState.secureButtons[i] = btn
  end

  -- Store reference for secure execution
  for i = 1, 5 do
    container:SetFrameRef("slice" .. i, RadialState.secureButtons[i])
  end

  RadialState.secureContainer = container
end

-- Create secure action buttons for spell casting
-- These buttons are clicked programmatically by ExecuteAndHide() when mouse is released
-- The mouselook override binding triggers HR.Show() on mouse down via a simple frame click
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
  RadialState.triggerButtons = {}

  for _, mapping in ipairs(buttonMappings) do
    -- Secure button for casting spells (clicked programmatically)
    local castBtn = CreateFrame("Button", "CMHealRadialCast_" .. mapping.key:gsub("-", "_"), UIParent, "SecureActionButtonTemplate")
    castBtn:SetSize(1, 1)
    castBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    castBtn.actionSlot = mapping.actionSlot
    castBtn.buttonKey = mapping.key
    castBtn:SetAttribute("type", nil)

    RadialState.overrideButtons[mapping.key] = castBtn

    -- Non-secure trigger button that shows the radial on mouse down
    -- This is what the mouselook override binding clicks
    local triggerBtn = CreateFrame("Button", "CMHealRadialTrigger_" .. mapping.key:gsub("-", "_"), UIParent)
    triggerBtn:SetSize(1, 1)
    triggerBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", -100, -100)
    triggerBtn.buttonKey = mapping.key
    triggerBtn:RegisterForClicks("AnyDown")

    triggerBtn:SetScript("OnClick", function(self)
      HR.Show(self.buttonKey)
    end)

    RadialState.triggerButtons[mapping.key] = triggerBtn
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
  -- If radial was showing and we exit mouselook, hide it
  if not isMouselooking and RadialState.isActive then
    HR.Hide(false) -- false = don't execute spell
  end
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
  -- Main frame for center dot visual and OnUpdate tracking.
  -- Slices are parented directly to UIParent (not this frame) to avoid
  -- secure frame hierarchy issues during InCombatLockdown.
  local mainFrame = CreateFrame("Frame", "CombatModeHealingRadialFrame", UIParent)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetSize(400, 400)
  mainFrame:SetPoint("CENTER", 0, CM.DB.global.crosshairY or 50)
  mainFrame:Hide()


  RadialState.mainFrame = mainFrame

  -- Create slice frames (parented to UIParent, not mainFrame)
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

  slice:SetAlpha(1)

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

      if config.showHealthPercent then
        slice.healthText:SetText(math.floor(pct * 100) .. "%")
        slice.healthText:Show()
      else
        slice.healthText:Hide()
      end
    else
      -- Values are secret; bar still fills correctly via StatusBar, use default color
      slice.healthFill:SetStatusBarColor(unpack(config.healthyColor))
      slice.healthText:Hide()
    end

    slice.healthBG:Show()
    slice.healthFill:Show()
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

-- Accessible via HR so closures created before this point can call it
function HR.HighlightSlice(sliceIndex)
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
    if slice:GetAlpha() > 0 then
      slice.highlight:Show()
      slice.border:Show()
    end
  end
end

---------------------------------------------------------------------------------------
--                              RADIAL CONTROL                                       --
---------------------------------------------------------------------------------------
-- Check if the triggering mouse button is still held down
local function IsMouseButtonStillDown(buttonKey)
  if not buttonKey then return false end

  -- Check for modifier + button combinations
  local isShift = _G.IsShiftKeyDown()
  local isCtrl = _G.IsControlKeyDown()
  local isAlt = _G.IsAltKeyDown()

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

local function TrackMousePosition(self, elapsed)
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
  -- When opened via keybind (currentButton == nil), the radial closes
  -- via HideFromKeybind() on key-up, not via mouse button release.

  -- Highlighting and targeting are handled by slice frame OnEnter/OnLeave
  -- (SecureHandlerEnterLeaveTemplate does targeting, HookScript does highlight)

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
  RadialState.showTime = _G.GetTime()

  -- Stop mouselook so cursor is free for slice selection
  if RadialState.wasMouselooking then
    MouselookStop()
  end

  -- NOTE: Spell casting happens in ExecuteAndHide() when mouse is released
  -- This is detected by TrackMousePosition checking IsMouseButtonDown()

  -- Update visuals
  UpdateAllSlices()

  -- Show mainFrame (center dot visual + OnUpdate host). Safe in combat since
  -- it has no secure descendants — slices are parented to UIParent directly.
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

-- Execute spell on selected target and hide the radial
-- Called when mouse button is released (detected in TrackMousePosition)
function HR.ExecuteAndHide()
  if not RadialState.isActive then
    return
  end

  if RadialState.selectedSlice then
    -- Find the unit for the selected slice
    local targetUnit = nil
    for _, member in ipairs(RadialState.partyData) do
      if member.sliceIndex == RadialState.selectedSlice then
        targetUnit = member.unitId
        break
      end
    end

    if targetUnit then
      if not InCombatLockdown() then
        -- Out of combat: cast spell directly via secure button attributes
        local castBtn = RadialState.overrideButtons and RadialState.overrideButtons[RadialState.currentButton]
        if castBtn then
          local actionSlot = castBtn.actionSlot
          local actionType, actionId = GetActionInfo(actionSlot)

          if actionType == "spell" then
            castBtn:SetAttribute("type", "spell")
            castBtn:SetAttribute("spell", actionId)
          elseif actionType == "macro" then
            castBtn:SetAttribute("type", "macro")
            castBtn:SetAttribute("macro", actionId)
          elseif actionType == "item" then
            castBtn:SetAttribute("type", "item")
            castBtn:SetAttribute("item", actionId)
          else
            castBtn:SetAttribute("type", "action")
            castBtn:SetAttribute("action", actionSlot)
          end
          castBtn:SetAttribute("unit", targetUnit)
          castBtn:Click()

          CM.DebugPrint("Healing Radial: Cast on " .. targetUnit .. " (slice " .. RadialState.selectedSlice .. ")")

          castBtn:SetAttribute("type", nil)
          castBtn:SetAttribute("unit", nil)
        end
      else
        -- In combat: target was already set via slice OnEnter Click().
        -- Can't call SetAttribute() in combat, but target persists after radial closes.
        CM.DebugPrint("Healing Radial: In combat, target " .. targetUnit .. " set via hover (slice " .. RadialState.selectedSlice .. ")")
      end
    else
      CM.DebugPrint("Healing Radial: No valid target")
    end
  else
    CM.DebugPrint("Healing Radial: No slice selected, not casting")
  end

  -- Now hide the radial
  HR.Hide(false)
end

function HR.Hide(executeSpell)
  if not RadialState.isActive then
    return
  end

  -- Stop mouse tracking
  RadialState.mainFrame:SetScript("OnUpdate", nil)

  -- Hide all slices via alpha (combat-safe, never toggle EnableMouse on secure frames)
  for i = 1, 5 do
    local slice = RadialState.sliceFrames[i]
    if slice then
      slice:SetAlpha(0)
    end
  end

  -- Hide mainFrame (center dot). Safe in combat — no secure descendants.
  RadialState.mainFrame:Hide()

  -- Restore crosshair
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(true)
  end

  -- Mark inactive so ShouldFreeLookBeOff() via IsHealingRadialActive()
  -- no longer detects the radial as open.
  RadialState.isActive = false
  RadialState.selectedSlice = nil

  CM.DebugPrint("Healing Radial: Hidden (combat=" .. tostring(InCombatLockdown()) .. ")")
end

-- Open radial via keybind (no spell casting, just targeting on hover)
function HR.ShowFromKeybind()
  if not CM.DB.global.healingRadial or not CM.DB.global.healingRadial.enabled then
    return false
  end

  if not IsInGroup() then
    return false
  end

  if RadialState.isActive then
    return false
  end

  -- Store state (currentButton = nil signals keybind mode)
  RadialState.isActive = true
  RadialState.currentButton = nil
  RadialState.selectedSlice = nil
  RadialState.wasMouselooking = _G.IsMouselooking()
  RadialState.showTime = _G.GetTime()

  -- Stop mouselook so cursor is free for slice selection
  if RadialState.wasMouselooking then
    MouselookStop()
  end

  -- Update visuals
  UpdateAllSlices()

  -- Show mainFrame (center dot + OnUpdate host)
  RadialState.mainFrame:Show()

  -- Start mouse tracking (for health bar updates and OnEnter/OnLeave)
  RadialState.mainFrame:SetScript("OnUpdate", TrackMousePosition)

  -- Hide crosshair while radial is visible
  if CM.DB.global.crosshair then
    CM.DisplayCrosshair(false)
  end

  CM.DebugPrint("Healing Radial: Shown via keybind")
  return true
end

-- Close radial opened via keybind (no spell casting)
function HR.HideFromKeybind()
  HR.Hide(false)
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

  CM.DebugPrint("Healing Radial: Initialized")
end

-- Expose state for Core.lua integration
function HR.GetState()
  return RadialState
end
