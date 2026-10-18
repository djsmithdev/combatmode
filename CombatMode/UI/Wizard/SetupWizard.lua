---------------------------------------------------------------------------------------
--  UI/Wizard/SetupWizard.lua — WIZARD — first-run setup wizard (guided tour of the options)
---------------------------------------------------------------------------------------
--  What it does: Walks a new player through the essentials inside the real options window.
--  Each step opens a tab, scrolls to a setting, dims everything but it and shows a balloon that
--  explains what it does; the player changes the setting right there (keybinds, toggles, the
--  spell lists) and presses Next. Started by the welcome popup on first install and by the cog
--  next to the version number in the options header (after a confirmation).
--  Architecture / how it works:
--    • Tasks: a step can ask for actions (a key bound, ...). They show as a check list in the balloon
--      and Next / Finish stay disabled until every one is done; Skip tour always works.
--    • Steps are data (STEPS): tab id, then either one control label (plus optional `also`
--      labels) or a whole section by header title, with a title and text. Options.FocusControl /
--      Options.FocusSection select the tab, scroll to it and return the frame(s) to highlight;
--      UI.ShowSpotlight (Spotlight.lua) dims around them (cut to the tab's visible area) and
--      shows the balloon.
--    • The dim never blocks the mouse, so every option keeps working while a step is shown.
--    • Steps marked `preview` (Crosshair, Assist HUD, Ally HUD) also leave that one live element
--      (crosshair, Assist HUD or Ally HUD) undimmed with its own outline, and the balloon keeps clear.
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
local GetBindingKey = _G.GetBindingKey
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

local function Bound(command)
  return GetBindingKey(command) ~= nil
end

-- A step may also carry `warning`: a caution shown in red under the text.
-- A step highlights a whole section (`section` = its header title). `tasks` are the actions the
-- step asks for: each shows as a check mark that fills in once `done()` is true, and Next stays
-- disabled until all are. The order follows the sidebar tabs after the Mouse Look section.
local STEPS = {
  {
    tab = "general",
    section = "MOUSE LOOK",
    title = "Mouse Look",
    body = "Lock your cursor to the center of the screen and steer by moving the mouse, "
      .. "no more holding right-click. Set a key to toggle it, and one to interact with "
      .. "whatever you're aiming at.",
    tasks = {
      {
        label = "Set a Mouse Look key",
        done = function()
          return Bound("Combat Mode - Mouse Look")
        end,
      },
      {
        label = "Set an Interact key",
        done = function()
          return Bound("INTERACTMOUSEOVER") or Bound("INTERACTTARGET")
        end,
      },
    },
  },
  {
    tab = "general",
    section = "CAMERA FEATURES",
    title = "Camera Features",
    body = "Fine-tune the camera while in Mouse Look. Turn off or adjust anything you don't like.",
  },
  {
    tab = "crosshair",
    section = "CROSSHAIR",
    preview = "crosshair",
    title = "Crosshair",
    body = "A reactive, fully customizable crosshair that adapts to your target and combat state. Choose its look, size and position.",
  },
  {
    tab = "crosshair",
    section = "ASSIST HUD",
    preview = "assist",
    title = "Assist HUD",
    body = "Aim at an enemy and the HUD next to your crosshair suggests your next spell and shows its key. Aim at something you can interact with and it shows its name and your Interact key instead. Turn either on or off, and set its side, size and distance from the crosshair.",
  },
  {
    tab = "reticle",
    section = "RETICLE TARGETING",
    title = "Reticle Targeting",
    body = "Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting. Ignore Friendlies makes it skip allies.",
    warning = "Turning Reticle Targeting on or off reloads the UI.",
  },
  {
    tab = "reticle",
    label = "Excluded Spells",
    title = "Excluded Spells",
    body = "Spells that should skip the Reticle Targeting logic and act on your current target as usual. Type a spell name or ID to add it.",
  },
  {
    tab = "reticle",
    label = "Cast at Crosshair",
    title = "Cast at Crosshair",
    body = "Ground-targeted spells that should be cast at the crosshair location instead of your target. Type a spell name or ID to add it.",
  },
  {
    tab = "reticle",
    label = "Reticle Targeting Macros",
    title = "Reticle Targeting Macros",
    body = "Action buttons that are macros cannot inherit Reticle Targeting on their own. Press + to open the Macro Composer, write your macro there and it gets the targeting logic added for you. Then drag it from this list onto your action bars; right-click an icon to edit it.",
  },
  {
    tab = "reticle",
    section = "TARGET LOCK",
    title = "Target Lock",
    body = "Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies. Target Lock Behavior decides whether tapping again unlocks (Toggle) or moves the lock to whatever is under the crosshair (Switch Target). Set your keys.",
    -- These keys can't be set while Reticle Targeting is off, so they don't block then.
    tasks = {
      {
        label = "Set a Target Lock key",
        done = function()
          return not CM.DB.char.reticleTargeting or Bound("Combat Mode - Toggle Focus Target")
        end,
      },
      {
        label = "Set a Cycle Lock - Next key",
        done = function()
          return not CM.DB.char.reticleTargeting or Bound("Combat Mode - Cycle Focus Next")
        end,
      },
      {
        label = "Set a Cycle Lock - Previous key",
        done = function()
          return not CM.DB.char.reticleTargeting or Bound("Combat Mode - Cycle Focus Previous")
        end,
      },
    },
  },
  {
    tab = "reticle",
    section = "TARGETING INDICATORS",
    title = "Targeting Indicators",
    body = "Choose how your target is marked in the world: an outline around it, and which target gets Blizzard's selection circle under its feet.",
  },
  {
    tab = "clickcasting",
    section = "CLICK CASTING",
    title = "Click Casting",
    body = "Bind actions to your mouse clicks while in Mouse Look. Pick a modifier (Base, Shift, "
      .. "Ctrl, Alt) at the top, then set what Left Click and Right Click do.",
  },
  {
    tab = "autocursorunlock",
    label = "Auto Unlock",
    title = "Auto Unlock",
    body = "Mouse Look pauses when you open bags, the map or other windows, then resumes.",
  },
  {
    tab = "autocursorunlock",
    label = "Unlock Mounts",
    title = "Unlock Mounts",
    body = "Mounts that should release the cursor while you are mounted on them. Search for a mount to add it.",
  },
  {
    tab = "autocursorunlock",
    label = "Extra Frames",
    title = "Extra Frames",
    body = "Add any other windows that should pause Mouse Look when they open. Type to search Blizzard and addon frames, or use the inspect button to click a window on screen.",
  },
  {
    tab = "allycycle",
    section = "ALLY CYCLE",
    title = "Ally Cycle",
    body = "Attack enemies and assist allies at once by cycling group members in Mouse Look: helpful spells go to the ally, harmful ones keep hitting your enemy target. Set your cycle keys.",
    tasks = {
      {
        label = "Set an Ally Cycle - Next key",
        done = function()
          return Bound(CM.AllyCycleBindUp or "Combat Mode - Ally Cycle Next")
        end,
      },
      {
        label = "Set an Ally Cycle - Previous key",
        done = function()
          return Bound(CM.AllyCycleBindDown or "Combat Mode - Ally Cycle Previous")
        end,
      },
    },
  },
  {
    tab = "allycycle",
    section = "ALLY HUD",
    preview = "ally",
    title = "Ally HUD",
    body = "Shows the selected ally next to the crosshair. Choose where it sits and how big it is.",
  },
  {
    tab = "advanced",
    section = "FORCE LOCK",
    title = "Force Lock",
    body = "Advanced: a custom Lua condition that keeps Mouse Look locked while it is true.",
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
    body = "Fine-tune how Reticle Targeting works with the CVar and Targeting Macro Prelines editors.",
    warning = "Editing these can break Reticle Targeting and Target Lock. Only change them if you know what you are doing.",
  },
}

-- Frames of the live crosshair + HUD preview the Crosshair / Ally Cycle tabs force on screen. Steps
-- marked `preview` leave them undimmed (outlined) and keep the balloon off them.
-- Per `preview` kind: the frame to leave undimmed and how far to pad around it (the Assist HUD's key /
-- name text hangs outside its frame, so it gets room on the sides).
local PREVIEW_KINDS = {
  crosshair = {
    frame = function()
      return _G.CombatModeCrosshairFrame
    end,
    padX = 14,
    padY = 14,
  },
  assist = {
    frame = function()
      return CM.GetAssistedHighlightFrame and CM.GetAssistedHighlightFrame()
    end,
    padX = 90,
    padY = 14,
  },
  ally = {
    frame = function()
      return _G.CombatModeAllyCycleHUD
    end,
    padX = 16,
    padY = 14,
  },
}

local function PreviewFrames(kind)
  local def = PREVIEW_KINDS[kind]
  local frame = def and def.frame()
  return frame and { frame } or {}, def and def.padX, def and def.padY
end

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
      warning = step.warning,
      step = i .. " / " .. #STEPS,
      nextLabel = last and "Finish" or "Next",
      isLast = last,
      canGoBack = i > 1,
      tasks = step.tasks,
      clip = Options.GetTabScroll(step.tab),
      alsoHighlight = step.preview and function()
        return PreviewFrames(step.preview)
      end or nil,
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
