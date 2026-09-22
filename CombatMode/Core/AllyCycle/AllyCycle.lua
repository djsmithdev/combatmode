---------------------------------------------------------------------------------------
--  Core/AllyCycle/AllyCycle.lua — ALLYCYCLE — façade / init / events
---------------------------------------------------------------------------------------
--  What it does: Public Ally Cycle entry points: Initialize, roster/binding refresh,
--  and event hooks for group/target/combat. Wires HUD + Cycle modules.
--  Architecture / how it works:
--    • Enable = Up/Down keybinds bound (CM.IsAllyCycleEnabled).
--    • OnGroupRosterUpdate / OnCombatEnd refresh secure unit attrs; HUD tracks target.
--  Does not: Build click-cast macrotext (TargetingMacroBuilder) or own options UI.
--  Related: Core/AllyCycle/{Cycle,HUD}.lua, Core/Runtime/{Bootstrap,EventRouter}.lua,
--  Core/Crosshair/Crosshair.lua, UI/Options/Tabs/TabAllyCycle.lua
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
