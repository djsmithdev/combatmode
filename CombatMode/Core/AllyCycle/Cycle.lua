---------------------------------------------------------------------------------------
--  Core/AllyCycle/Cycle.lua — ALLYCYCLE — secure UP/DOWN party/raid targeting
---------------------------------------------------------------------------------------
--  What it does: Secure Ally Cycle button (Left=Up, Right=Down) that hard-targets the
--  next/previous group member in Blizzard group/index order, skipping the player.
--  Architecture / how it works:
--    • CombatModeAllyCycle: SecureActionButton + OnClick wrap (key-up only).
--    • Dual SecureGroupHeaderTemplate rosters (ASC for Up, DESC for Down) —
--      takeNext walk so a pause between presses continues in the pressed direction.
--    • Self header (nameList) supplies the player’s secure unit token; skip-self
--      compares use exact tokens only.
--    • Restore-if-lost: if lastUnit exists and the hard target is missing or
--      not assistable (PlayerCanAssist — RestrictedEnv has no UnitIsUnit),
--      this press reselects lastUnit; the next press takeNext.
--    • PrepareCycle (CallMethod) syncs lastUnit from the hard target only out of combat
--      (secure SetAttribute is lockdown-blocked; dual headers already keep direction).
--    • Frame refs are SecureGroupHeaderTemplate only — non-secure frames raise
--      "Invalid frame handle" under RestrictedEnv (esp. in combat).
--    • Roster signature clears lastUnit when membership/order changes.
--    • CM.ResetAllyCycleCursor clears lastUnit OOC (PLAYER_REGEN_ENABLED).
--    • CM.GetAllyCycleIndex(unit) — insecure ASC walk (skip player); current/total
--      for the HUD. UnitIsUnit via PublicBool (secret → current unknown).
--    • On advance (chosen ~= lastUnit) CallMethod NotifyCycle up/down so the HUD
--      can slide; restore-if-lost does not notify.
--    • Bindings.xml names + SetOverrideBindingClick (Target Lock pattern).
--    • CM.IsAllyCycleEnabled — either Up or Down key bound.
--  Does not: Own Ally HUD chrome or TargetingMacroBuilder help/harm prelines.
--  Related: Core/AllyCycle/{HUD,AllyCycle}.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/Runtime/BindingQueue.lua, UI/Options/Tabs/TabAllyCycle.lua, Bindings.xml
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local ClearOverrideBindings = _G.ClearOverrideBindings
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetNormalizedRealmName = _G.GetNormalizedRealmName
local GetRealmName = _G.GetRealmName
local InCombatLockdown = _G.InCombatLockdown
local SecureHandlerSetFrameRef = _G.SecureHandlerSetFrameRef
local SecureHandlerWrapScript = _G.SecureHandlerWrapScript
local SetOverrideBindingClick = _G.SetOverrideBindingClick
local UIParent = _G.UIParent
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UnitName = _G.UnitName

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
local tostring = _G.tostring

local BIND_UP = "Combat Mode - Ally Cycle Up"
local BIND_DOWN = "Combat Mode - Ally Cycle Down"
local GROUPS = "1,2,3,4,5,6,7,8"

local OverrideOwner = CreateFrame("Frame", "CombatModeAllyCycleOverrideOwner", UIParent)
local CycleButton =
  CreateFrame("Button", "CombatModeAllyCycle", OverrideOwner, "SecureActionButtonTemplate")
-- Key-up only: AnyUp+AnyDown would advance twice per press (skipping members).
CycleButton:RegisterForClicks("AnyUp")
CycleButton:SetAttribute("useOnKeyDown", false)
CycleButton:SetAttribute("checkselfcast", false)
CycleButton:SetAttribute("checkfocuscast", false)
CycleButton:SetAttribute("checkmouseovercast", false)
CycleButton:SetAttribute("type", "target")
CycleButton:Hide()

local function CreateGroupHeader(name, sortDir)
  local header = CreateFrame("Frame", name, UIParent, "SecureGroupHeaderTemplate")
  header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
  header:SetSize(1, 1)
  header:SetAlpha(0)
  header:EnableMouse(false)
  header:SetAttribute("showRaid", true)
  header:SetAttribute("showParty", true)
  header:SetAttribute("showPlayer", true)
  header:SetAttribute("showSolo", true)
  header:SetAttribute("groupFilter", GROUPS)
  header:SetAttribute("groupBy", "GROUP")
  header:SetAttribute("groupingOrder", GROUPS)
  header:SetAttribute("sortMethod", "INDEX")
  header:SetAttribute("sortDir", sortDir or "ASC")
  header:SetAttribute("template", "SecureUnitButtonTemplate")
  header:SetAttribute(
    "initialConfigFunction",
    [[
    self:SetWidth(1)
    self:SetHeight(1)
    self:EnableMouse(false)
  ]]
  )
  -- SecureGroupHeaderTemplate only populates while shown.
  header:Show()
  return header
end

-- Name-filtered header → player's secure unit token (raidN / player).
local SelfHeader =
  CreateFrame("Frame", "CombatModeAllyCycleSelfHeader", UIParent, "SecureGroupHeaderTemplate")
SelfHeader:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
SelfHeader:SetSize(1, 1)
SelfHeader:SetAlpha(0)
SelfHeader:EnableMouse(false)
SelfHeader:SetAttribute("showRaid", true)
SelfHeader:SetAttribute("showParty", true)
SelfHeader:SetAttribute("showPlayer", true)
SelfHeader:SetAttribute("showSolo", true)
SelfHeader:SetAttribute("template", "SecureUnitButtonTemplate")
SelfHeader:SetAttribute(
  "initialConfigFunction",
  [[
  self:SetWidth(1)
  self:SetHeight(1)
  self:EnableMouse(false)
]]
)
SelfHeader:Show()

local GroupAsc = CreateGroupHeader("CombatModeAllyCycleGroupAsc", "ASC")
local GroupDesc = CreateGroupHeader("CombatModeAllyCycleGroupDesc", "DESC")

local function EnsureSelfHeaderNameList()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  local playerName = UnitName and UnitName("player")
  if not playerName then
    return
  end
  local realmName = GetNormalizedRealmName and GetNormalizedRealmName()
  if (not realmName or realmName == "") and GetRealmName then
    realmName = GetRealmName()
  end
  local nameList = playerName
  if realmName and realmName ~= "" then
    nameList = nameList .. "," .. playerName .. "-" .. realmName
  end
  SelfHeader:SetAttribute("nameList", nameList)
  SelfHeader:Show()
end

--- Sync lastUnit from the hard target so Up/Down continue from who you see.
--- Only out of combat: insecure SetAttribute on this secure button is lockdown-blocked.
--- In combat, lastUnit from the previous secure click drives restore-if-lost / takeNext.
function CycleButton:PrepareCycle()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if not UnitExists("target") then
    return
  end
  if UnitIsUnit and UnitIsUnit("target", "player") then
    return
  end
  local children = { GroupAsc:GetChildren() }
  for _, child in ipairs(children) do
    local unit = child.GetAttribute and child:GetAttribute("unit")
    if unit and UnitExists(unit) and UnitIsUnit and UnitIsUnit(unit, "target") then
      if unit ~= "player" and not UnitIsUnit(unit, "player") then
        self:SetAttribute("lastUnit", unit)
      end
      return
    end
  end
end

if SecureHandlerSetFrameRef then
  SecureHandlerSetFrameRef(CycleButton, "selfHeader", SelfHeader)
  SecureHandlerSetFrameRef(CycleButton, "groupAsc", GroupAsc)
  SecureHandlerSetFrameRef(CycleButton, "groupDesc", GroupDesc)
end

-- ASC takeNext = Up; DESC takeNext = Down. Same lastUnit works for both directions
-- after a pause (group / group_reverse pattern).
if SecureHandlerWrapScript then
  SecureHandlerWrapScript(
    CycleButton,
    "OnClick",
    CycleButton,
    [[
      if down then
        return false
      end

      self:CallMethod("PrepareCycle")

      local mode = SecureCmdOptionParse("[group:raid] raid;[group:party] party;solo")
      if mode == "solo" then
        self:SetAttribute("unit", nil)
        self:SetAttribute("lastUnit", nil)
        return
      end

      local selfHeader = self:GetFrameRef("selfHeader")
      local selfMember = selfHeader and selfHeader:GetChildren()
      local selfUnit = selfMember and selfMember:GetAttribute("unit")

      local goDown = button == "RightButton"
      local header = goDown and self:GetFrameRef("groupDesc") or self:GetFrameRef("groupAsc")
      local lastUnit = self:GetAttribute("lastUnit")

      -- Invalidate cursor when roster membership/order changes.
      local signature = mode .. "|" .. (selfUnit or "")
      local asc = self:GetFrameRef("groupAsc")
      if asc then
        for slot = 1, 40 do
          local member = asc:GetFrameRef("child" .. slot)
          local unit = member and member:GetAttribute("unit")
          if unit and UnitExists(unit) then
            signature = signature .. ";" .. unit
          end
        end
      end
      if mode ~= self:GetAttribute("mode") or signature ~= self:GetAttribute("rosterSignature") then
        lastUnit = nil
      end
      self:SetAttribute("mode", mode)
      self:SetAttribute("rosterSignature", signature)

      local firstUnit = nil
      local chosen = nil
      local takeNext = false

      -- Harm retarget replaces the friendly hard target; reselect lastUnit
      -- instead of advancing. RestrictedEnv has no UnitIsUnit — restore when
      -- target is gone or not assistable (PlayerCanAssist). Next press takeNext.
      if lastUnit and UnitExists(lastUnit)
        and (not UnitExists("target") or not PlayerCanAssist("target"))
      then
        chosen = lastUnit
      end

      if not chosen and header then
        for slot = 1, 40 do
          local member = header:GetFrameRef("child" .. slot)
          local unit = member and member:GetAttribute("unit")
          if unit and UnitExists(unit)
            and unit ~= "player"
            and (not selfUnit or unit ~= selfUnit)
          then
            if not firstUnit then
              firstUnit = unit
            end
            if takeNext then
              chosen = unit
              break
            end
            if lastUnit and unit == lastUnit then
              takeNext = true
            end
          end
        end
      end

      if not chosen then
        chosen = firstUnit
      end

      if chosen and UnitExists(chosen) then
        local advanced = (not lastUnit) or (chosen ~= lastUnit)
        self:SetAttribute("unit", chosen)
        self:SetAttribute("lastUnit", chosen)
        if advanced then
          self:CallMethod("NotifyCycle", goDown and "down" or "up")
        end
      else
        self:SetAttribute("unit", nil)
        self:SetAttribute("lastUnit", nil)
      end
    ]]
  )
end

function CycleButton:NotifyCycle(direction)
  if CM.NotifyAllyCycleHUD then
    CM.NotifyAllyCycleHUD(direction)
  end
end

function CM.RefreshAllyCycleRoster()
  EnsureSelfHeaderNameList()
  if SelfHeader and not SelfHeader:IsShown() then
    SelfHeader:Show()
  end
  if GroupAsc and not GroupAsc:IsShown() then
    GroupAsc:Show()
  end
  if GroupDesc and not GroupDesc:IsShown() then
    GroupDesc:Show()
  end
  CM.DebugPrint("Ally Cycle roster refreshed")
end

function CM.FlushPendingAllyCycleRoster()
  CM.RefreshAllyCycleRoster()
end

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

local function IsPlayerUnit(unit)
  if not unit then
    return false
  end
  if unit == "player" then
    return true
  end
  if not UnitIsUnit then
    return false
  end
  return PublicBool(UnitIsUnit(unit, "player")) == true
end

--- Cycle position of unit among ASC roster members (player skipped).
--- Returns currentIndex (or nil if unknown) and total.
function CM.GetAllyCycleIndex(unit)
  unit = unit or "target"
  local total = 0
  local current = nil
  if not GroupAsc then
    return nil, 0
  end
  local children = { GroupAsc:GetChildren() }
  for _, child in ipairs(children) do
    local slot = child.GetAttribute and child:GetAttribute("unit")
    if slot then
      local exists = UnitExists(slot)
      if IsSecret(exists) or exists then
        if not IsPlayerUnit(slot) then
          total = total + 1
          if unit and UnitIsUnit and PublicBool(UnitIsUnit(slot, unit)) == true then
            current = total
          end
        end
      end
    end
  end
  return current, total
end

--- Drop the cycle cursor so the next press starts at the top of the index
--- (unless OOC PrepareCycle sees a friendly hard target and continues from them).
function CM.ResetAllyCycleCursor()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  CycleButton:SetAttribute("lastUnit", nil)
end

function CM.IsAllyCycleEnabled()
  if not GetBindingKey then
    return false
  end
  return (GetBindingKey(BIND_UP) or GetBindingKey(BIND_DOWN)) and true or false
end

function CM.ApplyAllyCycleBindings()
  if InCombatLockdown() then
    if CM.TryApplyBindingChange then
      CM.TryApplyBindingChange("ally cycle bindings", function()
        CM.ApplyAllyCycleBindings()
      end)
    end
    return
  end
  ClearOverrideBindings(OverrideOwner)
  if not CM.IsAllyCycleEnabled() then
    CM.DebugPrint("Ally Cycle bindings cleared (unbound)")
    if CM.RefreshAllyCycleHUD then
      CM.RefreshAllyCycleHUD()
    end
    return
  end
  CM.RefreshAllyCycleRoster()
  local upKey = GetBindingKey(BIND_UP)
  if upKey then
    SetOverrideBindingClick(OverrideOwner, false, upKey, CycleButton:GetName(), "LeftButton")
  end
  local downKey = GetBindingKey(BIND_DOWN)
  if downKey then
    SetOverrideBindingClick(OverrideOwner, false, downKey, CycleButton:GetName(), "RightButton")
  end
  CM.DebugPrint(
    "Ally Cycle bindings applied up=" .. tostring(upKey) .. " down=" .. tostring(downKey)
  )
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end

CM.AllyCycleBindUp = BIND_UP
CM.AllyCycleBindDown = BIND_DOWN

function _G.CombatMode_AllyCycleUp() end
function _G.CombatMode_AllyCycleDown() end
