---------------------------------------------------------------------------------------
--  Core/AllyCycle/Cycle.lua — ALLYCYCLE — secure UP/DOWN party/raid targeting
---------------------------------------------------------------------------------------
--  What it does: Secure Up/Down hard-target through group/index order. Skip Self
--  (default on) omits the player from the roster.
--  Architecture / how it works:
--    • SecureActionButton + key-up wrap; ASC/DESC headers; takeNext; restore-if-lost
--      via PlayerCanAssist (RestrictedEnv has no UnitIsUnit). Frame refs must be
--      SecureGroupHeaderTemplate.
--    • skipPlayer attribute set OOC from DB (RestrictedEnv cannot read CM.DB).
--    • PrepareCycle / ResetAllyCycleCursor OOC only (SetAttribute is lockdown-blocked).
--    • GetAllyCycleIndex for the HUD (reuses a child scratch table); NotifyCycle on
--      advance (not restore) plays a quiet UI tick (softer than Target Lock cycle).
--    • CM.Profile keys: AllyCycle:GetIndex / ApplyBindings / RefreshRoster.
--    • Forever Beta (interface 16xxx) cannot compile secure snippets; headers stay
--      hidden and wrap/binds no-op. Detect via GetBuildInfo, not loadstring_untainted
--      (that global is not addon-visible on Mainline either) or WOW_PROJECT_ID (Forever
--      reports as Mainline).
--  Does not: Own HUD chrome or click-cast prelines.
--  Related: Core/AllyCycle/{HUD,AllyCycle}.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/Runtime/BindingQueue.lua, UI/Options/Tabs/TabAllyCycle.lua, Bindings.xml
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local ClearOverrideBindings = _G.ClearOverrideBindings
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetBuildInfo = _G.GetBuildInfo
local GetNormalizedRealmName = _G.GetNormalizedRealmName
local GetRealmName = _G.GetRealmName
local InCombatLockdown = _G.InCombatLockdown
local PlaySound = _G.PlaySound
local SOUNDKIT = _G.SOUNDKIT
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
local select = _G.select
local tostring = _G.tostring
local wipe = _G.wipe

-- Forever 1.60.x TOC is 16xxx. Classic Era is 115xx; Mainline is 12xxxx.
-- RestrictedExecution is broken on that client; do not probe loadstring_untainted
-- (nil in addon _G on Retail too — that disabled Ally Cycle everywhere).
local interfaceVersion = (GetBuildInfo and select(4, GetBuildInfo())) or 0
local FOREVER_CLIENT = type(interfaceVersion) == "number"
  and interfaceVersion >= 16000
  and interfaceVersion < 20000
local SECURE_SNIPPETS_OK = not FOREVER_CLIENT

local BIND_UP = "Combat Mode - Ally Cycle Next"
local BIND_DOWN = "Combat Mode - Ally Cycle Previous"
local GROUPS = "1,2,3,4,5,6,7,8"
local INITIAL_CONFIG = [[
    self:SetWidth(1)
    self:SetHeight(1)
    self:EnableMouse(false)
  ]]
-- Softer than Target Lock's IG_MAINMENU_OPTION cycle tick.
local ALLY_CYCLE_SOUND = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856

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
  if SECURE_SNIPPETS_OK then
    header:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
    -- SecureGroupHeaderTemplate only populates while shown.
    header:Show()
  else
    header:Hide()
  end
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
if SECURE_SNIPPETS_OK then
  SelfHeader:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
  SelfHeader:Show()
else
  SelfHeader:Hide()
end

local GroupAsc = CreateGroupHeader("CombatModeAllyCycleGroupAsc", "ASC")
local GroupDesc = CreateGroupHeader("CombatModeAllyCycleGroupDesc", "DESC")

local function EnsureSelfHeaderNameList()
  if not SECURE_SNIPPETS_OK then
    return
  end
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

function CM.IsAllyCycleSkipPlayer()
  local ac = CM.DB and CM.DB.global and CM.DB.global.allyCycle
  if ac and ac.skipPlayer == false then
    return false
  end
  return true
end

-- OOC only: SetAttribute on this button is lockdown-blocked.
function CycleButton:PrepareCycle()
  if InCombatLockdown and InCombatLockdown() then
    return
  end
  if not UnitExists("target") then
    return
  end
  local skipPlayer = CM.IsAllyCycleSkipPlayer()
  if skipPlayer and UnitIsUnit and UnitIsUnit("target", "player") then
    return
  end
  local children = { GroupAsc:GetChildren() }
  for _, child in ipairs(children) do
    local unit = child.GetAttribute and child:GetAttribute("unit")
    if unit and UnitExists(unit) and UnitIsUnit and UnitIsUnit(unit, "target") then
      local isSelf = unit == "player" or UnitIsUnit(unit, "player")
      if not skipPlayer or not isSelf then
        self:SetAttribute("lastUnit", unit)
      end
      return
    end
  end
end

function CM.IsAllyCycleSecureAvailable()
  return SECURE_SNIPPETS_OK
end

if SecureHandlerSetFrameRef then
  SecureHandlerSetFrameRef(CycleButton, "selfHeader", SelfHeader)
  SecureHandlerSetFrameRef(CycleButton, "groupAsc", GroupAsc)
  SecureHandlerSetFrameRef(CycleButton, "groupDesc", GroupDesc)
end

if SECURE_SNIPPETS_OK and SecureHandlerWrapScript then
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

      -- RestrictedEnv: no UnitIsUnit. Restore lastUnit if target is gone / not assistable.
      if lastUnit and UnitExists(lastUnit)
        and (not UnitExists("target") or not PlayerCanAssist("target"))
      then
        chosen = lastUnit
      end

      local skipPlayer = self:GetAttribute("skipPlayer") ~= false

      if not chosen and header then
        for slot = 1, 40 do
          local member = header:GetFrameRef("child" .. slot)
          local unit = member and member:GetAttribute("unit")
          local isSelf = unit == "player" or (selfUnit and unit == selfUnit)
          if unit and UnitExists(unit) and not (skipPlayer and isSelf) then
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
  if PlaySound then
    PlaySound(ALLY_CYCLE_SOUND, "Master", true)
  end
  if CM.NotifyAllyCycleHUD then
    CM.NotifyAllyCycleHUD(direction)
  end
end

local function RefreshAllyCycleRosterImpl()
  if not SECURE_SNIPPETS_OK then
    return
  end
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

function CM.RefreshAllyCycleRoster()
  return CM.Profile("AllyCycle:RefreshRoster", RefreshAllyCycleRosterImpl)
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

local rosterKids = {}

local function PackInto(dest, ...)
  local n = select("#", ...)
  for i = 1, n do
    dest[i] = select(i, ...)
  end
  for i = n + 1, #dest do
    dest[i] = nil
  end
end

local function CollectHeaderChildren(header)
  if not header then
    if wipe then
      wipe(rosterKids)
    end
    return rosterKids
  end
  PackInto(rosterKids, header:GetChildren())
  return rosterKids
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

local function GetAllyCycleIndexImpl(unit)
  unit = unit or "target"
  local total = 0
  local current = nil
  if not GroupAsc then
    return nil, 0
  end
  local skipSelf = CM.IsAllyCycleSkipPlayer()
  local children = CollectHeaderChildren(GroupAsc)
  for _, child in ipairs(children) do
    local slot = child.GetAttribute and child:GetAttribute("unit")
    if slot then
      local exists = UnitExists(slot)
      if IsSecret(exists) or exists then
        if not skipSelf or not IsPlayerUnit(slot) then
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

function CM.GetAllyCycleIndex(unit)
  return CM.Profile("AllyCycle:GetIndex", GetAllyCycleIndexImpl, unit)
end

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

local function ApplyAllyCycleBindingsImpl()
  CycleButton:SetAttribute("skipPlayer", CM.IsAllyCycleSkipPlayer())
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

function CM.ApplyAllyCycleBindings()
  if not SECURE_SNIPPETS_OK then
    if not InCombatLockdown() then
      ClearOverrideBindings(OverrideOwner)
    end
    if CM.RefreshAllyCycleHUD then
      CM.RefreshAllyCycleHUD()
    end
    return
  end
  if InCombatLockdown() then
    if CM.TryApplyBindingChange then
      CM.TryApplyBindingChange("ally cycle bindings", function()
        CM.ApplyAllyCycleBindings()
      end)
    end
    return
  end
  return CM.Profile("AllyCycle:ApplyBindings", ApplyAllyCycleBindingsImpl)
end

CM.AllyCycleBindUp = BIND_UP
CM.AllyCycleBindDown = BIND_DOWN

function _G.CombatMode_AllyCycleUp() end
function _G.CombatMode_AllyCycleDown() end
