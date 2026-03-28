---------------------------------------------------------------------------------------
--  Config/ReticleCVarEditorData.lua — Reticle Targeting CVar editor data layer
---------------------------------------------------------------------------------------
--  Row list, description fallbacks, canonical/exclusion helpers (editor + runtime
--  pruning must agree with CM.Constants.ReticleTargetingCVarEditorExcluded).
--  Override table: CM.DB.global.reticleTargetingCVarOverrides; reads/writes go through
--  CM.GetReticleTargetingCVarOverrides; SetOverride / clear-all guarded in combat.
--  Related: ReticleCVarEditorPanel.lua, RuntimeCVarManager.lua, ConstantsCVars.lua.
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local C_Console = _G.C_Console
local GetCVar = _G.GetCVar
local InCombatLockdown = _G.InCombatLockdown
local pairs = _G.pairs
local wipe = _G.wipe
local strtrim = _G.strtrim
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local strlower = _G.strlower

CM.ReticleCVarEditorData = CM.ReticleCVarEditorData or {}
local Data = CM.ReticleCVarEditorData

local cvarDescriptions = nil
local cachedLowerToCanonical = nil
local cachedExcludedLower = nil

local function EnsureCaches()
  if cachedLowerToCanonical and cachedExcludedLower then
    return
  end

  cachedLowerToCanonical = {}
  cachedExcludedLower = {}

  for cvar in pairs(CM.Constants.ReticleTargetingCVarValues) do
    cachedLowerToCanonical[strlower(cvar)] = cvar
  end

  local excluded = CM.Constants.ReticleTargetingCVarEditorExcluded
  if type(excluded) == "table" then
    for cvar in pairs(excluded) do
      cachedExcludedLower[strlower(cvar)] = true
    end
  end
end

function Data.CanonicalCVar(cvarName)
  if type(cvarName) ~= "string" then
    return nil
  end
  EnsureCaches()
  local map = cachedLowerToCanonical or {}
  return map[strlower(cvarName)]
end

function Data.IsTrackedCVar(cvarName)
  return Data.CanonicalCVar(cvarName) ~= nil
end

function Data.IsEditableCVar(cvarName)
  local canonical = Data.CanonicalCVar(cvarName)
  if not canonical then
    return false
  end
  EnsureCaches()
  local excluded = cachedExcludedLower or {}
  return not excluded[strlower(canonical)]
end
local fallbackDescriptions = {
  SoftTargetForce = "Auto-set target to match soft target. 1 = for enemies, 2 = for friends.",
  SoftTargetMatchLocked = "Match appropriate soft target to locked target. 1 = hard locked target only, 2 = for targets you attack ",
  SoftTargetWithLocked = "Allows soft target selection while player has a locked target. 2 = always do soft targeting.",
  SoftTargetEnemy = "Sets when enemy soft targeting should be enabled. 0=off, 1=gamepad, 2=KBM, 3=always.",
  SoftTargetEnemyArc = "Enemy reticle yaw arc. 0 = strict forward, 1 = wider forward arc, 2 = can be anywhere in front.",
  SoftTargetEnemyRange = "Max range to soft target enemies (limited to tab targeting range).",
  SoftTargetInteract = "Sets when soft interact should be enabled. 0=off, 1=gamepad, 2=KBM, 3=always.",
  SoftTargetInteractArc = "Interaction yaw arc. 0 = strict forward, 1 = wider forward arc, 2 = can be anywhere in front.",
  SoftTargetInteractRange = "Max range to soft target interacts (limited to tab targeting and individual interact ranges).",
  SoftTargetFriend = "Sets when friend soft targeting should be enabled. 0=off, 1=gamepad, 2=KBM, 3=always.",
  SoftTargetFriendArc = "Friendly reticle yaw arc. 0 = strict forward, 1 = wider forward arc, 2 = can be anywhere in front.",
  SoftTargetFriendRange = "Max range to soft target friends (limited to tab targeting range).",
  SoftTargetNameplateEnemy = "Always show nameplates for soft enemy target.",
  SoftTargetIconEnemy = "Show icon for soft enemy target.",
}

local function BuildDescriptionMap()
  cvarDescriptions = {}
  if not C_Console or not C_Console.GetAllCommands then
    return
  end

  local commands = C_Console.GetAllCommands()
  for _, info in pairs(commands or {}) do
    local cvar = info and info.command
    local canonical = cvar and Data.CanonicalCVar(cvar)
    if canonical then
      cvarDescriptions[canonical] = info.help or ""
    end
  end
end

local function GetDescription(cvar)
  if not cvarDescriptions then
    BuildDescriptionMap()
  end
  local descriptions = cvarDescriptions or {}
  local description = descriptions[cvar]
  if description and description ~= "" then
    return description
  end
  return fallbackDescriptions[cvar] or ""
end

function Data.GetOverrides()
  return CM.GetReticleTargetingCVarOverrides()
end

function Data.GetRows()
  local rows = {}
  local defaults = CM.Constants.ReticleTargetingCVarValues
  local overrides = Data.GetOverrides()

  for cvar, defaultValue in pairs(defaults) do
    if Data.IsEditableCVar(cvar) then
      local overrideValue = overrides[cvar]
      local effectiveValue = overrideValue ~= nil and overrideValue or defaultValue
      local currentValue = GetCVar(cvar) or ""
      rows[#rows + 1] = {
        cvar = cvar,
        description = GetDescription(cvar),
        defaultValue = tostring(defaultValue),
        currentValue = tostring(currentValue),
        effectiveValue = tostring(effectiveValue),
        overrideValue = overrideValue ~= nil and tostring(overrideValue) or nil,
        isOverridden = overrideValue ~= nil,
      }
    end
  end

  return rows
end

local function NormalizeByDefaultType(cvar, inputValue)
  local defaultValue = CM.Constants.ReticleTargetingCVarValues[cvar]
  if defaultValue == nil then
    return nil
  end

  local trimmed = strtrim(inputValue or "")
  if trimmed == "" then
    return nil
  end

  if type(defaultValue) == "number" then
    local numberValue = tonumber(trimmed)
    if numberValue == nil then
      return nil
    end
    return numberValue
  end

  return trimmed
end

function Data.SetOverride(cvar, inputValue)
  if InCombatLockdown() then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: cannot edit Reticle Targeting CVars while in combat.|r"
    )
    return false
  end

  if not Data.IsEditableCVar(cvar) then
    return false
  end

  local overrides = Data.GetOverrides()
  local canonical = Data.CanonicalCVar(cvar)
  if not canonical then
    return false
  end
  local normalized = NormalizeByDefaultType(canonical, inputValue)
  if normalized == nil then
    overrides[canonical] = nil
  else
    overrides[canonical] = normalized
  end

  if CM.DB and CM.DB.char and CM.DB.char.reticleTargeting then
    CM.ConfigReticleTargeting("combatmode")
  end
  return true
end

--- Clears every account-wide reticle CVar override so effective values match
--- `CM.Constants.ReticleTargetingCVarValues` again.
function Data.ClearAllOverrides()
  if InCombatLockdown() then
    print(
      CM.Constants.BasePrintMsg
        .. "|cff909090: cannot reset Reticle Targeting CVars while in combat.|r"
    )
    return false
  end

  wipe(Data.GetOverrides())

  if CM.DB and CM.DB.char and CM.DB.char.reticleTargeting then
    CM.ConfigReticleTargeting("combatmode")
  end
  return true
end
