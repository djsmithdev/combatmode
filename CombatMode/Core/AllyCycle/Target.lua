---------------------------------------------------------------------------------------
--  Core/AllyCycle/Target.lua — ALLYCYCLE — friendly-hard-target identity
---------------------------------------------------------------------------------------
--  What it does: Resolves whether the hard target is an Ally HUD unit, plus name,
--  role, class color, raid-marker index, cycle index, and range alpha.
--  Architecture / how it works:
--    • CM.AllyCycleTarget: IsFriendlyHardTarget, GetDisplayName, GetClassRGB,
--      GetRoleAtlas, GetRaidTargetIndex, ApplyRaidMarker, GetIndex, FormatIndex,
--      GetRangeAlpha, IsDead, IsPlayer.
--    • CM.IsAllyCycleFriendlyHardTarget is implemented here (party/raid roster +
--      Skip Self + assist). Friendly NPCs (Interact) are not HUD units.
--    • Secret-safe: PublicBool / issecretvalue; raid index is presence not math;
--      range encodes secret UnitInRange in ColorMixin alpha (no Lua compare).
--  Does not: Own cluster chrome, fade/slide, or the health-bar widget.
--  Related: Core/AllyCycle/HealthBar.lua, Motion.lua, HUD.lua, Cycle.lua, AllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateColor = _G.CreateColor
local GetClassColor = _G.GetClassColor
local GetRaidTargetIndex = _G.GetRaidTargetIndex
local SetRaidTargetIconTexture = _G.SetRaidTargetIconTexture
local UnitCanAssist = _G.UnitCanAssist
local UnitCanAttack = _G.UnitCanAttack
local UnitClass = _G.UnitClass
local UnitExists = _G.UnitExists
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitInParty = _G.UnitInParty
local UnitInRaid = _G.UnitInRaid
local UnitInRange = _G.UnitInRange
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsUnit = _G.UnitIsUnit
local UnitName = _G.UnitName
local EvaluateColorFromBoolean = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorFromBoolean

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local tostring = _G.tostring
local type = _G.type

local Target = {}
CM.AllyCycleTarget = Target

local ROLE_ATLASES = {
  TANK = "UI-Frame-TankIcon",
  HEALER = "UI-Frame-HealerIcon",
  DAMAGER = "UI-Frame-DpsIcon",
  NONE = "UI-Frame-DpsIcon",
}

local RAID_TARGET_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcons]]
local RAID_TARGET_TEXTURE_ROWS = 4
local RAID_TARGET_TEXTURE_COLUMNS = 4

-- Encode range in ColorMixin alpha so secret UnitInRange never enters a Lua compare.
local COLOR_IN_RANGE = CreateColor and CreateColor(1, 1, 1, 1)
local COLOR_OUT_OF_RANGE = CreateColor and CreateColor(1, 1, 1, 0.3)

Target.RAID_TARGET_TEXTURE = RAID_TARGET_TEXTURE

local function IsSecret(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end

local function PublicBool(v)
  if IsSecret(v) then
    return nil
  end
  if v == true then
    return true
  end
  if v == false then
    return false
  end
  return nil
end

-- SecureGroupHeader roster is party/raid (+ self). Interact NPCs can be assistable.
local function IsAllyCycleRosterUnit(unit)
  if UnitInParty and PublicBool(UnitInParty(unit)) == true then
    return true
  end
  if UnitInRaid then
    local raidIndex = UnitInRaid(unit)
    if IsSecret(raidIndex) then
      return false
    end
    if type(raidIndex) == "number" then
      return true
    end
  end
  return false
end

function Target.IsFriendlyHardTarget()
  if not UnitExists("target") then
    return false
  end
  if UnitIsUnit and UnitIsUnit("target", "player") then
    if not CM.IsAllyCycleSkipPlayer or CM.IsAllyCycleSkipPlayer() then
      return false
    end
    return true
  end
  if not IsAllyCycleRosterUnit("target") then
    return false
  end
  local attack = UnitCanAttack and UnitCanAttack("player", "target")
  local pubAttack = PublicBool(attack)
  if pubAttack == true then
    return false
  end
  local assist = UnitCanAssist and UnitCanAssist("player", "target")
  local pubAssist = PublicBool(assist)
  if pubAssist == false then
    return false
  end
  if pubAssist == true then
    return true
  end
  return false
end

function CM.IsAllyCycleFriendlyHardTarget()
  return Target.IsFriendlyHardTarget()
end

function Target.IsDead(unit)
  if not unit or not UnitIsDeadOrGhost then
    return false
  end
  return PublicBool(UnitIsDeadOrGhost(unit)) == true
end

function Target.IsPlayer(unit)
  if not unit or not UnitIsUnit then
    return false
  end
  return PublicBool(UnitIsUnit(unit, "player")) == true
end

function Target.GetDisplayName(unit, preview)
  local name = UnitName and UnitName(unit)
  if not preview and Target.IsPlayer(unit) then
    return "You"
  end
  if IsSecret(name) or type(name) ~= "string" or name == "" then
    return preview and "Ally" or "..."
  end
  return name
end

function Target.GetClassRGB(unit)
  local _, classFile = UnitClass(unit)
  if IsSecret(classFile) or type(classFile) ~= "string" then
    return 1, 1, 1
  end
  if GetClassColor then
    local r, g, b = GetClassColor(classFile)
    if r then
      return r, g, b
    end
  end
  return 1, 1, 1
end

function Target.GetRoleAtlas(unit)
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
  if IsSecret(role) or type(role) ~= "string" or role == "" then
    role = "NONE"
  end
  return ROLE_ATLASES[role] or ROLE_ATLASES.DAMAGER or ROLE_ATLASES.NONE
end

function Target.GetRaidTargetIndex(unit)
  if unit and UnitExists(unit) and GetRaidTargetIndex then
    return GetRaidTargetIndex(unit)
  end
end

-- Apply Blizzard raid-target sheet. SetRaidTargetIconTexture accepts secret indices.
function Target.ApplyRaidMarker(tex, idx)
  if not tex then
    return false
  end
  -- Under taint, a present marker is a *secret* number (issecretvalue = presence).
  -- Never truth-test / compare / arithmetic the index in Lua.
  local hasMarker = IsSecret(idx) or (type(idx) == "number" and idx >= 1 and idx <= 8)
  if not hasMarker then
    return false
  end
  tex:SetTexture(RAID_TARGET_TEXTURE)
  if SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(tex, idx)
    return true
  end
  if tex.SetSpriteSheetCell then
    tex:SetSpriteSheetCell(idx, RAID_TARGET_TEXTURE_ROWS, RAID_TARGET_TEXTURE_COLUMNS)
    return true
  end
  return false
end

function Target.GetIndex(unit)
  if CM.GetAllyCycleIndex then
    return CM.GetAllyCycleIndex(unit)
  end
end

function Target.FormatIndex(current, total)
  if type(total) ~= "number" or total < 1 then
    return nil
  end
  local curText = "?"
  if type(current) == "number" and current >= 1 then
    curText = tostring(current)
  end
  return curText .. "/" .. tostring(total)
end

-- Range alpha for the cluster. Secret UnitInRange is encoded in ColorMixin alpha.
function Target.GetRangeAlpha(unit, preview, outA)
  if type(outA) ~= "number" then
    outA = 0.3
  end
  if preview or not unit or unit == "player" or not UnitExists(unit) then
    return 1
  end
  if not UnitInRange then
    return 1
  end
  local inRange = UnitInRange(unit)
  if IsSecret(inRange) then
    if EvaluateColorFromBoolean and COLOR_IN_RANGE and COLOR_OUT_OF_RANGE then
      local rangeColor = EvaluateColorFromBoolean(inRange, COLOR_IN_RANGE, COLOR_OUT_OF_RANGE)
      if rangeColor and rangeColor.a ~= nil then
        return rangeColor.a
      end
    end
    return 1
  end
  if inRange == false then
    return outA
  end
  return 1
end
