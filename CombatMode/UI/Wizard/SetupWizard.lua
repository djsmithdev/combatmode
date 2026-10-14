---------------------------------------------------------------------------------------
--  UI/Wizard/SetupWizard.lua — WIZARD — first-run setup wizard (guided tour of the options)
---------------------------------------------------------------------------------------
--  What it does: Walks a new player through the essentials inside the real options window.
--  Each step opens a tab, scrolls to a setting, dims everything but it and shows a balloon that
--  explains what it does; the player changes the setting right there (keybinds, toggles, the
--  spell lists) and presses Next. Started by the welcome popup on first install and by the cog
--  next to the version number in the options header (after a confirmation).
--  Architecture / how it works:
--    • Steps are data (STEPS): tab id, then either one control label (plus optional `also`
--      labels) or a whole section by header title, with a title and text. Options.FocusControl /
--      Options.FocusSection select the tab, scroll to it and return the frame(s) to highlight;
--      UI.ShowSpotlight (Spotlight.lua) dims around them (cut to the tab's visible area) and
--      shows the balloon.
--    • The dim never blocks the mouse, so every option keeps working while a step is shown.
--    • char.seenWizard is set when the tour finishes or is skipped (Skip / ESC).
--    • Combat: Start waits for combat to end; entering combat mid-tour ends the tour.
--  Does not: Cover every option (only the basics and the major features), or own any setting
--      (the tabs do).
--  Related: UI/Wizard/Spotlight.lua, UI/Options/OptionsPanel.lua (cog, FocusControl),
--  Core/Runtime/Runtime.lua (first-run hook)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown

-- Lua stdlib
local abs = _G.math.abs
local ipairs = _G.ipairs

local UI = CM.UI
local Options = UI.Options

local Wizard = {}
CM.Wizard = Wizard

local SETTLE_DELAY = 0.15 -- lets a tab switch start its scroll before it is checked
local SCROLL_POLL = 0.05
local SCROLL_MAX_WAIT = 1.5 -- give up waiting for the scroll to land after this long

-- A step highlights either one control (`label`, plus `also` controls on the same tab) or a whole
-- section (`section` = its header title). The order follows the sidebar tabs after the Mouse Look
-- section.
local STEPS = {
  {
    tab = "general",
    section = "MOUSE LOOK",
    title = "Mouse Look",
    body = "Mouse Look turns your mouse into your camera and puts the crosshair at the centre of the screen. "
      .. "Set the key that toggles it, and the key that interacts with NPCs and objects without leaving it.",
  },
  {
    tab = "general",
    section = "CAMERA FEATURES",
    title = "Camera Features",
    body = "Fine-tune the camera while in Mouse Look: motion sickness protection, turn speed, "
      .. "dynamic pitch and shoulder offset. Turn off or adjust anything you don't like.",
  },
  {
    tab = "crosshair",
    section = "CROSSHAIR",
    title = "Crosshair",
    body = "The on-screen reticle you aim with. Turn it on, choose its look and cast feedback, "
      .. "and set its size and position.",
  },
  {
    tab = "crosshair",
    section = "INTERACTION HUD",
    title = "Interaction HUD",
    body = "Shows a prompt next to the crosshair for what you can interact with. Choose where it sits.",
  },
  {
    tab = "crosshair",
    section = "COMBAT ASSIST",
    title = "Combat Assist",
    body = "Shows the game's suggested next ability beside the crosshair. Choose where it sits.",
  },
  {
    tab = "reticle",
    section = "RETICLE TARGETING",
    title = "Reticle Targeting",
    body = "Targets whatever is under your crosshair when you cast, replacing tab-targeting. "
      .. "Cast at Crosshair lists spells that are aimed where the crosshair points, like ground-targeted "
      .. "and area spells. Changing the main toggle reloads the UI.",
  },
  {
    tab = "reticle",
    section = "TARGET LOCK",
    title = "Target Lock",
    body = "Locks the reticle to your target so it can't swap away. Set the keys, then tap to lock "
      .. "and tap again to unlock.",
  },
  {
    tab = "clickcasting",
    section = "CLICK CASTING",
    title = "Click Casting",
    body = "Bind spells or macros to your mouse buttons while in Mouse Look. "
      .. "Pick a modifier (Base, Shift, Ctrl, Alt) at the top, then set what Left Click and Right Click do.",
  },
  {
    tab = "autocursorunlock",
    section = "AUTO UNLOCK",
    title = "Auto Unlock",
    body = "Frees your cursor automatically when you open windows like bags or the map, "
      .. "and locks it again when you close them.",
  },
  {
    tab = "allycycle",
    section = "ALLY CYCLE",
    title = "Ally Cycle",
    body = "Select group members without leaving Mouse Look: helpful spells go to the ally, "
      .. "harmful ones keep hitting your enemy target. Set the keys here.",
  },
  {
    tab = "allycycle",
    section = "ALLY HUD",
    title = "Ally HUD",
    body = "Shows the selected ally next to the crosshair. Choose where it sits and how big it is.",
  },
  {
    tab = "advanced",
    section = "FORCE LOCK",
    title = "Force Lock",
    body = "For advanced users: a custom Lua condition that keeps Mouse Look locked while it is true.",
  },
  {
    tab = "advanced",
    section = "FORCE UNLOCK",
    title = "Force Unlock",
    body = "The opposite: a custom Lua condition that keeps Mouse Look unlocked while it is true.",
  },
  {
    tab = "advanced",
    section = "CROSSHAIR",
    title = "Situational Crosshair",
    body = "Swap the crosshair's appearance while a custom Lua condition is true.",
  },
  {
    tab = "advanced",
    section = "RETICLE TARGETING",
    title = "Targeting Editors",
    body = "Open the CVar editor and the Targeting Macro Prelines editor. Editing these can break "
      .. "Reticle Targeting and Target Lock, so only touch them if you know what you are doing.",
  },
}

local active = false
local current = 0
local combatWatcher

local function StopWatchingCombat()
  if combatWatcher then
    combatWatcher:UnregisterAllEvents()
  end
end

--- Waits for `event` once, then calls `handler`.
local function WatchCombat(event, handler)
  combatWatcher = combatWatcher or CreateFrame("Frame")
  combatWatcher:UnregisterAllEvents()
  combatWatcher:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    handler()
  end)
  combatWatcher:RegisterEvent(event)
end

--- Ends the wizard from any step and marks it as seen (finished and skipped are the same).
function Wizard.Finish()
  active = false
  StopWatchingCombat()
  UI.HideSpotlight()
  Options.CancelKeybindCapture()
  CM.DB.char.seenWizard = true
  Options.Sync()
end

local ShowStep

function ShowStep(i)
  local step = STEPS[i]
  if not step then
    Wizard.Finish()
    return
  end
  current = i
  -- Fade the old highlight away while the tab scrolls, so it never chases a moving widget.
  UI.FadeOutSpotlight()
  local targets
  if step.section then
    targets = Options.FocusSection(step.tab, step.section)
  else
    local frame = Options.FocusControl(step.tab, step.label, step.group)
    targets = { frame }
    for _, label in ipairs(step.also or {}) do
      local control = Options.FindControl(step.tab, label, step.group)
      if control then
        targets[#targets + 1] = control.frame
      end
    end
  end
  -- Unknown section: fall back to the tab's sidebar button.
  targets = targets or { Options.GetTabButton(step.tab) }
  local last = i == #STEPS
  local scroll = Options.GetTabScroll(step.tab)
  local waited = SETTLE_DELAY
  local function show()
    if not active or current ~= i then
      return
    end
    local options = CM.GetOptionsFrame()
    if not (options and options:IsShown() and targets[1]) then
      Wizard.Finish()
      return
    end
    UI.ShowSpotlight(targets, {
      title = step.title,
      body = step.body,
      step = i .. " / " .. #STEPS,
      nextLabel = last and "Finish" or "Next",
      isLast = last,
      canGoBack = i > 1,
      clip = Options.GetTabScroll(step.tab),
      onNext = function()
        Options.CancelKeybindCapture()
        ShowStep(i + 1)
      end,
      onBack = function()
        Options.CancelKeybindCapture()
        ShowStep(i - 1)
      end,
      onSkip = Wizard.Finish,
    })
  end
  -- Show the new step once the scroll has landed (or after a timeout).
  local function WaitForScroll()
    if not active or current ~= i then
      return
    end
    local moving = scroll
      and scroll.cmGetTargetScroll
      and abs((scroll:GetVerticalScroll() or 0) - scroll.cmGetTargetScroll()) > 1
    if moving and waited < SCROLL_MAX_WAIT then
      waited = waited + SCROLL_POLL
      C_Timer.After(SCROLL_POLL, WaitForScroll)
    else
      -- One more beat so the final scroll position is laid out before measuring.
      C_Timer.After(SCROLL_POLL, show)
    end
  end
  C_Timer.After(SETTLE_DELAY, WaitForScroll)
end

--- Starts (or restarts) the tour from the first step. Waits for combat to end.
function Wizard.Start()
  if InCombatLockdown() then
    WatchCombat("PLAYER_REGEN_ENABLED", Wizard.Start)
    return
  end
  if not CM.OpenOptions then
    return
  end
  UI.HideSpotlight()
  active = true
  CM.OpenOptions()
  WatchCombat("PLAYER_REGEN_DISABLED", Wizard.Finish)
  -- Let the options window lay out before measuring the first target.
  C_Timer.After(0.25, function()
    if active then
      ShowStep(1)
    end
  end)
end
