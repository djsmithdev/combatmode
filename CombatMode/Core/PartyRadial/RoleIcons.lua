---------------------------------------------------------------------------------------
--  Core/PartyRadial/RoleIcons.lua — PARTYRADIAL — role atlas + inspect + icon glow
---------------------------------------------------------------------------------------
--  What it does: Resolves role icon atlases (melee/ranged DPS, Disabled when dead,
--  Decline overlay when mind-controlled), party spec inspect queue, and low-health
--  circle glow on the role icon.
--  Architecture / how it works:
--    • CM.PartyRadialRoleIcons: RequestPartySpecInspects, ResolveRoleIconAtlas,
--      UpdateRoleIconLowHealthGlow, PublicBool helpers.
--    • Uses HealthBars HB_* / ExtractColorRGBA and PartyData preview stamps.
--    • INSPECT_READY late-binds CM.PartyRadial.UpdateAllSlices.
--  Does not: Create slice chrome (Visual) or pulse OnUpdate (HealthBars).
--  Related: Core/PartyRadial/Visual.lua, HealthBars.lua, PartyData.lua,
--  Constants/PartyRadial.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local C_SpecializationInfo = _G.C_SpecializationInfo
local CanInspect = _G.CanInspect
local GetInspectSpecialization = _G.GetInspectSpecialization
local NotifyInspect = _G.NotifyInspect
local UnitExists = _G.UnitExists
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitHealthPercent = _G.UnitHealthPercent
local UnitIsCharmed = _G.UnitIsCharmed
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsPossessed = _G.UnitIsPossessed
local issecretvalue = _G.issecretvalue

-- Lua stdlib
local ipairs = _G.ipairs
local type = _G.type

local HR = CM.PartyRadial
local PartyData = CM.PartyRadialPartyData
local HealthBars = CM.PartyRadialHealthBars
local RoleIcons = {}
CM.PartyRadialRoleIcons = RoleIcons

local function GetState()
  return HR.GetState()
end

local PREVIEW_HEALTH_BY_SLICE = PartyData.PREVIEW_HEALTH_BY_SLICE
local HB_LOW_PCT = HealthBars.HB_LOW_PCT
local HB_GLOW_R = HealthBars.HB_GLOW_R
local HB_GLOW_G = HealthBars.HB_GLOW_G
local HB_GLOW_B = HealthBars.HB_GLOW_B
local HB_GLOW_CURVE = HealthBars.HB_GLOW_CURVE
local ExtractColorRGBA = HealthBars.ExtractColorRGBA

---------------------------------------------------------------------------------------
--                                ROLE ICON HELPERS                                  --
---------------------------------------------------------------------------------------
-- Public boolean when not secret; nil when unknown/secret (cannot branch on it).
local function PublicBool(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  return value and true or false
end

-- Spec ID for player via C_SpecializationInfo; party via GetInspectSpecialization when known.
local function GetUnitSpecID(unitId)
  if not unitId or unitId == "" then
    return nil
  end
  if unitId == "player" and C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if specIndex and specIndex > 0 and C_SpecializationInfo.GetSpecializationInfo then
      local specID = C_SpecializationInfo.GetSpecializationInfo(specIndex)
      if specID and specID > 0 then
        return specID
      end
    end
  end
  if GetInspectSpecialization then
    local specID = GetInspectSpecialization(unitId)
    if specID and specID > 0 then
      return specID
    end
  end
  return nil
end

-- One-at-a-time NotifyInspect so DAMAGER party members get melee vs ranged atlases
-- (GetInspectSpecialization is empty until inspected). Hybrid DPS without inspect stay melee.
local partySpecInspectFrame
local function RequestPartySpecInspects()
  if InCombatLockdown() or not NotifyInspect or not CanInspect then
    return
  end
  if not partySpecInspectFrame then
    partySpecInspectFrame = CreateFrame("Frame")
    partySpecInspectFrame:RegisterEvent("INSPECT_READY")
    partySpecInspectFrame:SetScript("OnEvent", function(_, event)
      if event ~= "INSPECT_READY" then
        return
      end
      if GetState().isActive or GetState().optionsPreviewActive then
        if HR.UpdateAllSlices then
          HR.UpdateAllSlices()
        end
      end
      RequestPartySpecInspects()
    end)
  end

  for _, member in ipairs(GetState().partyData or {}) do
    local unitId = member.unitId
    if
      unitId
      and unitId ~= "player"
      and member.role == "DAMAGER"
      and UnitExists(unitId)
      and not GetUnitSpecID(unitId)
      and CanInspect(unitId)
    then
      NotifyInspect(unitId)
      return
    end
  end
end

-- True when DAMAGER should use the RangedDPS atlas; false → melee DPS (default fallback).
local function IsRangedDamager(unitId, classFile, isPlaceholder)
  local rangedSpecs = CM.Constants.PartyRadialRangedSpecIDs
  local rangedClasses = CM.Constants.PartyRadialRangedDamagerClasses
  if not isPlaceholder and unitId then
    local specID = GetUnitSpecID(unitId)
    if specID and rangedSpecs and rangedSpecs[specID] then
      return true
    end
    if specID then
      return false -- known melee (or non-ranged) DPS spec
    end
  end
  return classFile and rangedClasses and rangedClasses[classFile] or false
end

-- Charmed or possessed = being controlled. UnitIsControlling is the controller, not victim.
local function IsUnitControlledPublic(unitId)
  if not unitId then
    return nil
  end
  local charmed = UnitIsCharmed and UnitIsCharmed(unitId)
  local possessed = UnitIsPossessed and UnitIsPossessed(unitId)
  local c = PublicBool(charmed)
  local p = PublicBool(possessed)
  if c == nil or p == nil then
    -- If either side is secret, still accept a public true from the other.
    if c == true or p == true then
      return true
    end
    return nil
  end
  return c or p
end

local function ResolveRoleIconAtlas(role, unitId, classFile, isPlaceholder, memberData)
  local atlases = CM.Constants.PartyRadialRoleAtlases
  if not atlases or not role then
    return nil, false, false
  end

  local entry = atlases[role]
  if not entry then
    return nil, false, false
  end

  local showControlledOverlay = false
  if
    (GetState().optionsPreviewActive and memberData and memberData.previewControlled)
    or ((not isPlaceholder) and IsUnitControlledPublic(unitId) == true)
  then
    showControlledOverlay = true
  end

  local isDead = false
  if GetState().optionsPreviewActive and memberData and memberData.previewDead then
    isDead = true
  elseif not isPlaceholder and UnitIsDeadOrGhost and unitId then
    local deadPublic = PublicBool(UnitIsDeadOrGhost(unitId))
    if deadPublic == true then
      isDead = true
    end
  end

  -- Controlled overlay sits on the living role icon; dead uses Disabled (no Decline pulse).
  if isDead then
    showControlledOverlay = false
  end

  local ranged = role == "DAMAGER" and IsRangedDamager(unitId, classFile, isPlaceholder)
  if isDead then
    if ranged and entry.rangedDisabled then
      return entry.rangedDisabled, true, showControlledOverlay
    end
    return entry.disabled or entry.normal, true, showControlledOverlay
  end
  if ranged and entry.ranged then
    return entry.ranged, false, showControlledOverlay
  end
  return entry.normal, false, showControlledOverlay
end

local function UpdateRoleIconLowHealthGlow(slice, memberData, isPlaceholder, hasRole)
  local glow = slice.roleIconGlow
  local glowFrame = slice.roleIconGlowFrame
  if not glow or not glowFrame then
    return
  end

  local function ClearGlow()
    slice.roleIconGlowBaseA = 0
    glowFrame:Hide()
  end

  local function ArmGlow(baseA)
    slice.roleIconGlowBaseA = baseA
    glow:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, baseA)
    glowFrame:Show()
  end

  if not hasRole or not memberData then
    ClearGlow()
    return
  end

  if memberData.previewDead or memberData.previewControlled then
    ClearGlow()
    return
  end

  -- Options preview / placeholder: public fractions (same sources as health bar).
  if GetState().optionsPreviewActive or isPlaceholder then
    local pct = memberData.previewHealthPct
      or PREVIEW_HEALTH_BY_SLICE[memberData.sliceIndex]
      or 0.75
    if pct <= HB_LOW_PCT then
      ArmGlow(1)
    else
      ClearGlow()
    end
    return
  end

  if not memberData.unitId then
    ClearGlow()
    return
  end

  local unitId = memberData.unitId
  -- Dead/ghost: no low-health glow (Disabled atlas already communicates state).
  local deadPublic = UnitIsDeadOrGhost and PublicBool(UnitIsDeadOrGhost(unitId))
  if deadPublic == true then
    ClearGlow()
    return
  end

  if UnitHealthPercent and HB_GLOW_CURVE then
    local glowColor = UnitHealthPercent(unitId, true, HB_GLOW_CURVE)
    local _, _, _, glowA = ExtractColorRGBA(glowColor)
    -- May be secret 0/1; pulse OnUpdate gates without a public boolean test.
    ArmGlow(glowA or 0)
    return
  end

  local health = UnitHealth(unitId, true)
  local maxHealth = UnitHealthMax(unitId)
  if
    type(health) == "number"
    and type(maxHealth) == "number"
    and not (issecretvalue and (issecretvalue(health) or issecretvalue(maxHealth)))
    and maxHealth > 0
    and (health / maxHealth) <= HB_LOW_PCT
  then
    ArmGlow(1)
    return
  end
  ClearGlow()
end

RoleIcons.PublicBool = PublicBool
RoleIcons.RequestPartySpecInspects = RequestPartySpecInspects
RoleIcons.ResolveRoleIconAtlas = ResolveRoleIconAtlas
RoleIcons.UpdateRoleIconLowHealthGlow = UpdateRoleIconLowHealthGlow
