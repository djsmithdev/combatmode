---------------------------------------------------------------------------------------
--  Core/PartyRadial/PartyData.lua — PARTYRADIAL — roster + shared radial state
---------------------------------------------------------------------------------------
--  What it does: Owns CM.PartyRadial namespace bootstrap, RadialState, and party roster
--  build/refresh including options-preview placeholders (dead / mind-controlled stamps).
--  Architecture / how it works:
--    • CM.PartyRadial = CM.PartyRadial or {}; local HR alias; RadialState table.
--    • HR.GetState returns RadialState for sibling modules.
--    • CM.PartyRadialPartyData: RefreshPartyData, BuildPreviewPartyData,
--      GetVisualPartyData, PREVIEW_* stamp tables. UnitName stored only when public
--      (secret names → nil; Visual shows "…").
--  Does not: Own secure attributes, health bars, role icons, frames, or show/hide.
--  Related: Core/PartyRadial/SecureBindings.lua, Visual.lua, Lifecycle.lua,
--  PartyRadial.lua, Constants/PartyRadial.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitName = _G.UnitName

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
local pairs = _G.pairs
local select = _G.select
local table = _G.table

-- Module namespace (siblings alias HR / GetState)
CM.PartyRadial = CM.PartyRadial or {}
local HR = CM.PartyRadial

local PartyData = {}
CM.PartyRadialPartyData = PartyData

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
-- Options-preview health fractions per slice (low / mid / full / mid / mid-high).
-- Dead + mind-controlled stamps are applied after roster fill (Rogue placeholder /
-- slice 4), not by hard-coding 0% onto the player's DPS slot.
local PREVIEW_HEALTH_BY_SLICE = { 0.15, 0.75, 1.0, 0.55, 0.60 }
local PREVIEW_CONTROLLED_SLICE = 4

PartyData.PREVIEW_DPS_VARIANTS = PREVIEW_DPS_VARIANTS
PartyData.PREVIEW_HEALTH_BY_SLICE = PREVIEW_HEALTH_BY_SLICE
PartyData.PREVIEW_CONTROLLED_SLICE = PREVIEW_CONTROLLED_SLICE

HR.GetState = function()
  return RadialState
end

-- Store only public names; secret UnitName values cannot be truncated/compared later.
local function SafeUnitName(unitId)
  local name = UnitName(unitId)
  if name ~= nil and issecretvalue and issecretvalue(name) then
    return nil
  end
  return name
end

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
    name = SafeUnitName("player"),
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
        name = SafeUnitName(unitId),
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
-- for empty slices so Visual Settings preview a full 5-man layout. Always stamps
-- one dead + one mind-controlled slice so Disabled / Decline role icons are visible.
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

  -- Dead: Rogue placeholder (melee DPS), never the player when a placeholder exists.
  -- Controlled: prefer slice 4; if that member is dead, pick another preview DPS.
  local deadMember
  for _, member in ipairs(preview) do
    if member.isPreview and member.class == "ROGUE" then
      deadMember = member
      break
    end
  end
  if not deadMember then
    for _, member in ipairs(preview) do
      if member.isPreview and member.role == "DAMAGER" and member.unitId ~= "player" then
        deadMember = member
        break
      end
    end
  end

  if deadMember then
    deadMember.previewDead = true
    deadMember.previewHealthPct = 0
    if deadMember.isPreview then
      deadMember.name = "Dead"
    end
  end

  local controlledMember
  for _, member in ipairs(preview) do
    if member.sliceIndex == PREVIEW_CONTROLLED_SLICE and not member.previewDead then
      controlledMember = member
      break
    end
  end
  if not controlledMember then
    for _, member in ipairs(preview) do
      if
        member.isPreview
        and member.role == "DAMAGER"
        and not member.previewDead
        and member.unitId ~= "player"
      then
        controlledMember = member
        break
      end
    end
  end
  if controlledMember then
    controlledMember.previewControlled = true
    if controlledMember.isPreview then
      controlledMember.name = "Charmed"
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

PartyData.RefreshPartyData = RefreshPartyData
PartyData.BuildPreviewPartyData = BuildPreviewPartyData
PartyData.GetVisualPartyData = GetVisualPartyData
