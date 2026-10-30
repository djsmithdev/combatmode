---------------------------------------------------------------------------------------
--  Core/RadialMenu/RadialMenu.lua — RADIALMENU — façade: init, events, Mouse Look handoff
---------------------------------------------------------------------------------------
--  What it does: Public entry points of the Radial Menu domain. Bootstrap calls
--  CM.InitializeRadialMenu; EventRouter calls CM.OnRadialMenuEvent for RADIAL_MENU_EVENTS.
--  Architecture / how it works:
--    • The wheel is shown / hidden by secure snippets (Secure.lua); this file only reacts through
--      HookScript OnShow / OnHide (insecure, so they also run when the wheel opens in combat).
--    • Mouse Look handoff: CM.IsRadialMenuOpen feeds CM.ShouldFreeLookBeOff (FreeLookController),
--      so showing the wheel frees the cursor and hiding it re-locks through CM.ReconcileFreeLook.
--    • While the wheel is open GameTooltip is suppressed (hidden on show, re-hidden by an OnShow hook).
--    • SPELLS_CHANGED (spec / talent swaps change spell names) re-stores the slices out of combat.
--    • Party Wheel (PartyWheel.lua): same OnShow / OnHide hooks (view kind "party"), but the view
--      and Mouse Look only react once CM.PartyWheelStartReveal's hold delay passes; roster
--      re-store on GROUP_ROSTER_UPDATE / UNIT_CONNECTION (offline flags) and its combat-deferred
--      store flushed on PLAYER_REGEN_ENABLED.
--  Does not: Own secure frames (Secure.lua), draw (View.lua), or store wheels (Data.lua).
--  Related: Core/RadialMenu/{Data,Actions,Secure,PartyWheel,View}.lua,
--  Core/FreeLook/FreeLookController.lua,
--  Core/Runtime/{Bootstrap,EventRouter}.lua, Constants/Gameplay.lua (RADIAL_MENU_EVENTS)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown

local initialized = false
local spellsChangedToken = 0

local function HideGameTooltip()
  if GameTooltip and GameTooltip:IsShown() then
    GameTooltip:Hide()
  end
end

local function ReconcileNow()
  if CM.ReconcileFreeLook then
    CM.ReconcileFreeLook()
  end
end

function CM.InitializeRadialMenu()
  local wheel = CM.RadialGetWheelFrame()
  if not wheel then
    return
  end
  if not initialized then
    initialized = true
    wheel:HookScript("OnShow", function()
      CM.RadialViewShown()
      HideGameTooltip()
      ReconcileNow()
    end)
    if GameTooltip and GameTooltip.HookScript then
      GameTooltip:HookScript("OnShow", function(tooltip)
        if CM.IsRadialMenuOpen() then
          tooltip:Hide()
        end
      end)
    end
    wheel:HookScript("OnHide", function()
      CM.RadialViewHidden()
      ReconcileNow()
    end)
    local party = CM.PartyWheelGetFrame and CM.PartyWheelGetFrame()
    if party then
      -- Drawn only once held (CM.PartyWheelStartReveal): a quick tap casts with no flash.
      party:HookScript("OnShow", function()
        CM.PartyWheelStartReveal(function()
          CM.RadialViewShown("party")
          HideGameTooltip()
          ReconcileNow()
        end)
      end)
      party:HookScript("OnHide", function()
        if CM.PartyWheelStopReveal() then
          CM.RadialViewHidden("party")
          ReconcileNow()
        end
      end)
    end
  end
  CM.RadialRefresh()
  if CM.PartyWheelRefresh then
    CM.PartyWheelRefresh(true)
  end
end

--- Events from Constants/Gameplay.lua RADIAL_MENU_EVENTS.
function CM.OnRadialMenuEvent(event)
  if event == "GROUP_ROSTER_UPDATE" then
    -- Party Wheel pages follow the group; in combat they wait for PLAYER_REGEN_ENABLED.
    if CM.PartyWheelRefresh then
      CM.PartyWheelRefresh(false)
    end
    return
  end
  if event == "UNIT_CONNECTION" then
    -- Party Wheel offline flags (po<k>_<i>); the view greys the slice now, even in combat.
    if CM.PartyWheelRefresh then
      CM.PartyWheelRefresh(false)
    end
  end
  if event == "PLAYER_REGEN_ENABLED" and CM.PartyWheelFlush then
    CM.PartyWheelFlush()
  end
  if event == "SPELLS_CHANGED" then
    if InCombatLockdown() or not C_Timer then
      return
    end
    -- Bursts on login / spec swap: store once, after they settle.
    spellsChangedToken = spellsChangedToken + 1
    local token = spellsChangedToken
    C_Timer.After(0.5, function()
      if token == spellsChangedToken and not InCombatLockdown() then
        CM.RadialRefresh()
        if CM.PartyWheelRefresh then
          CM.PartyWheelRefresh(false)
        end
      end
    end)
    return
  end
  if CM.RadialViewRefresh then
    CM.RadialViewRefresh()
  end
end
