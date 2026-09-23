---------------------------------------------------------------------------------------
--  Core/AllyCycle/AllyCycle.lua — ALLYCYCLE — façade / init / events
---------------------------------------------------------------------------------------
--  What it does: Public init and event hooks; wires HUD + Cycle.
--  Architecture / how it works:
--    • Enable = Up/Down keybinds bound. Combat end resets lastUnit then flushes roster.
--  Does not: Build click-cast macros or own options UI.
--  Related: Core/AllyCycle/{Cycle,HUD}.lua, Core/Runtime/{Bootstrap,EventRouter}.lua,
--  UI/Options/Tabs/TabAllyCycle.lua
---------------------------------------------------------------------------------------
local _, CM = ...

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
