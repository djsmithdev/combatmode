---------------------------------------------------------------------------------------
--  Core/AllyCycle/AllyCycle.lua — ALLYCYCLE — façade / init / events
---------------------------------------------------------------------------------------
--  What it does: Public init and event hooks; wires HUD + Cycle.
--  Architecture / how it works:
--    • Enable = Up/Down keybinds bound. Combat end resets lastUnit then flushes roster.
--    • IsAllyCycleRestoreAfterHarm: user toggle, else healer spec. Used by
--      TargetingMacroBuilder (harm /tar then /targetlasttarget). Healer-spec
--      probe is pcall-guarded — Classic/TBC may stub GetSpecializationRole
--      (function exists, calling it errors). Missing API → not a healer.
--  Does not: Build click-cast macros or own options UI.
--  Related: Core/AllyCycle/{Cycle,Target,HealthBar,Motion,HUD}.lua, Core/Runtime/{Bootstrap,EventRouter}.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, UI/Options/Tabs/TabAllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local GetSpecialization = _G.GetSpecialization
local GetSpecializationRole = _G.GetSpecializationRole
local C_SpecializationInfo = _G.C_SpecializationInfo

-- Lua stdlib
local pcall = _G.pcall
local type = _G.type

local function AllyCycleDb()
  return CM.DB and CM.DB.global and CM.DB.global.allyCycle
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if ok then
    return result
  end
  return nil
end

function CM.IsPlayerHealerSpec()
  local specIndex =
    SafeCall(C_SpecializationInfo and C_SpecializationInfo.GetSpecialization or GetSpecialization)
  if type(specIndex) ~= "number" or specIndex <= 0 then
    return false
  end
  local role = SafeCall(
    (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationRole) or GetSpecializationRole,
    specIndex
  )
  return role == "HEALER"
end

--- Harm click-cast restores the ally after /tar. User toggle wins; otherwise healer spec.
function CM.IsAllyCycleRestoreAfterHarm()
  local ac = AllyCycleDb()
  if ac and ac.restoreAllyAfterHarmSet then
    return ac.restoreAllyAfterHarm == true
  end
  return CM.IsPlayerHealerSpec()
end

function CM.SetAllyCycleRestoreAfterHarm(enabled)
  local ac = AllyCycleDb()
  if not ac then
    return
  end
  ac.restoreAllyAfterHarm = enabled and true or false
  ac.restoreAllyAfterHarmSet = true
end

function CM.InitializeAllyCycle()
  if CM.ApplyAllyCycleBindings then
    CM.ApplyAllyCycleBindings()
  end
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end

function CM.OnAllyCycleGroupRosterUpdate()
  if CM.RefreshAllyCycleRoster then
    CM.RefreshAllyCycleRoster()
  end
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end

function CM.OnAllyCycleCombatEnd()
  if CM.ResetAllyCycleCursor then
    CM.ResetAllyCycleCursor()
  end
  if CM.FlushPendingAllyCycleRoster then
    CM.FlushPendingAllyCycleRoster()
  end
  if CM.ApplyAllyCycleBindings then
    CM.ApplyAllyCycleBindings()
  end
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end

function CM.OnAllyCycleTargetChanged()
  if CM.RefreshAllyCycleHUD then
    CM.RefreshAllyCycleHUD()
  end
end
