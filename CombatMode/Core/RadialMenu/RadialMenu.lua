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
--  Does not: Own secure frames (Secure.lua), draw (View.lua), or store wheels (Data.lua).
--  Related: Core/RadialMenu/{Data,Actions,Secure,View}.lua, Core/FreeLook/FreeLookController.lua,
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
  end
  CM.RadialRefresh()
end

--- Events from Constants/Gameplay.lua RADIAL_MENU_EVENTS.
function CM.OnRadialMenuEvent(event)
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
      end
    end)
    return
  end
  if CM.RadialViewRefresh then
    CM.RadialViewRefresh()
  end
end
