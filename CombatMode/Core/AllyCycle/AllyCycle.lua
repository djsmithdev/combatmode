---------------------------------------------------------------------------------------
--  Core/AllyCycle/AllyCycle.lua — ALLYCYCLE — façade / init / events
---------------------------------------------------------------------------------------
--  What it does: Public init and event hooks; wires HUD + Cycle.
--  Architecture / how it works:
--    • Enable = Up/Down keybinds bound. Combat end resets lastUnit then flushes roster.
--    • IsAllyCycleRestoreAfterHarm: user toggle, else healer spec. Used by
--      TargetingMacroBuilder (harm /tar then /targetlasttarget).
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

local function AllyCycleDb()
  return CM.DB and CM.DB.global and CM.DB.global.allyCycle
end

function CM.IsPlayerHealerSpec()
  local specIndex
  if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
    specIndex = C_SpecializationInfo.GetSpecialization()
  elseif GetSpecialization then
    specIndex = GetSpecialization()
  end
  if not specIndex or not GetSpecializationRole then
    return false
  end
  return GetSpecializationRole(specIndex) == "HEALER"
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
