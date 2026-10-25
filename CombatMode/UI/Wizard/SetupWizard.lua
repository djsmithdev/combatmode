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
--      labels) or a whole section by header title (`sectionEnd` = a later section's title where
--      the highlight ends, so one step can cover several sections), with a title and text. Options.FocusControl /
--      Options.FocusSection select the tab, scroll to it and return the frame(s) to highlight;
--      UI.ShowSpotlight (Spotlight.lua) dims around them (cut to the tab's visible area) and
--      shows the balloon.
--    • The dim never blocks the mouse, so every option keeps working while a step is shown.
--    • Steps marked `preview` (Crosshair, Assist HUD, Ally HUD) also leave that one live element
--      (crosshair, Assist HUD or Ally HUD) undimmed with its own outline, and the balloon keeps clear.
--    • global.seenWizard is set when the tour finishes or is skipped (Skip / ESC).
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

-- A step's `body` can use `{text}` for accent-coloured words, `{!text}` for red warning text and a blank line (`\n\n`) between paragraphs.
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
      .. "no more holding right-click.\n\n"
      .. "Set a {key to toggle it}, and {one to interact with} whatever you're aiming at.",
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
    tab = "crosshair",
    section = "CROSSHAIR",
    preview = "crosshair",
    title = "Crosshair",
    body = "A reactive, fully customizable crosshair that adapts to your target and combat state.\n\nChoose its {look}, {size} and {position}.",
  },
  {
    tab = "crosshair",
    section = "ASSIST HUD",
    preview = "assist",
    title = "Assist HUD",
    body = "Aim at an enemy and the HUD next to your crosshair suggests your {next spell} and shows its key.\n\nAim at something you can interact with and it shows its {name} and your {Interact key} instead.\n\nTurn either on or off, and set its {side}, {size} and {distance} from the crosshair.",
  },
  {
    tab = "reticle",
    section = "RETICLE TARGETING",
    title = "Reticle Targeting",
    body = "Target enemies just by aiming at them, and drop ground-targeted spells and AoE abilities right where your crosshair points, with no tab-targeting.\n\n{Ignore Friendlies} makes it skip allies.",
    warning = "Turning Reticle Targeting on or off reloads the UI.",
  },
  {
    tab = "reticle",
    label = "Excluded Spells",
    title = "Excluded Spells",
    body = "Spells that should skip or don't need the Reticle Targeting logic applied to them at all.\n\nType a {spell name or ID} to add it.",
  },
  {
    tab = "reticle",
    label = "Cast at Crosshair",
    title = "Cast at Crosshair",
    body = "Ground-targeted spells that should be cast at the crosshair location.\n\nType a {spell name or ID} to add it.",
  },
  {
    tab = "reticle",
    label = "Reticle Targeting Macros",
    title = "Reticle Targeting Macros",
    body = "{!Action buttons that are macros cannot inherit Reticle Targeting on their own.}\n\nPress {+} to open the {Macro Composer}, write your macro there and it gets the targeting logic added for you.\n\nThen drag it from this list onto your action bars; {right-click} an icon to edit it.",
  },
  {
    tab = "reticle",
    section = "TARGET LOCK",
    title = "Target Lock",
    body = "Lock onto a target with one tap so the reticle stops swapping. While locked, the cycle keys jump to nearby enemies.\n\n{Target Lock Behavior} decides whether tapping again unlocks ({Toggle}) or moves the lock to whatever is under the crosshair ({Switch Target}).\n\nSet your keys.",
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
    tab = "clickcasting",
    section = "CLICK CASTING",
    title = "Click Casting",
    body = "Turn your mouse clicks into actions while in Mouse Look, such as casting your action bar "
      .. "spells with {Left and Right Click}.\n\n"
      .. "Pick what each click does, with or without a {modifier key}.",
  },
  {
    tab = "radialmenu",
    section = "RADIAL MENU",
    title = "Radial Menu",
    body = "A wheel of your {spells, items, macros and shortcuts} that works in combat.\n\n"
      .. "Hold its key, move the mouse toward a slice and release to use it.\n\n"
      .. "{Scroll} to switch between wheels.",
    tasks = {
      {
        label = "Set a Radial Menu key",
        done = function()
          return Bound("Combat Mode - Radial Menu")
        end,
      },
    },
  },
  {
    tab = "allycycle",
    section = "ALLY CYCLE",
    sectionEnd = "ALLY HUD",
    preview = "ally",
    title = "Ally Cycle",
    body = "Cycle through group members in Mouse Look so {helpful spells} go to the ally while {harmful ones} keep hitting your enemy.\n\nThe {Ally HUD} shows who is selected.\n\nSet your cycle keys.",
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
    tab = "autocursorunlock",
    section = "AUTO UNLOCK",
    title = "Auto Unlock",
    body = "Mouse Look pauses when you open {bags, the map or other windows}, then resumes.\n\n"
      .. "Add {mounts or extra windows} that should pause it too.",
  },
  {
    tab = "advanced",
    section = "SOUNDS",
    sectionEnd = "RETICLE TARGETING",
    title = "Advanced",
    body = "Sound cues and power-user tools: {custom Lua conditions} and {Reticle Targeting editors}.",
    warning = "Editing these can break Reticle Targeting and Target Lock. Only change them if you know what you are doing.",
  },
}

-- Frames of the live crosshair + HUD preview the Crosshair / Ally Cycle tabs force on screen. Steps
-- marked `preview` leave them undimmed (outlined) and keep the balloon off them.
-- Per `preview` kind: the frames to leave undimmed and how far to pad around them (the Assist HUD's key /
-- name text hangs outside its frame, so those labels are listed too instead of padding the frame wide,
-- which would swallow the crosshair).
local PREVIEW_KINDS = {
  crosshair = {
    frames = function()
      return { _G.CombatModeCrosshairFrame }
    end,
    padX = 14,
    padY = 14,
  },
  assist = {
    frames = function()
      local frame = CM.GetAssistedHighlightFrame and CM.GetAssistedHighlightFrame()
      if not frame then
        return {}
      end
      return { frame, frame.keybindText, frame.nameText }
    end,
    padX = 14,
    padY = 14,
  },
  ally = {
    frames = function()
      return { _G.CombatModeAllyCycleHUD }
    end,
    padX = 16,
    padY = 14,
  },
}

local function PreviewFrames(kind)
  local def = PREVIEW_KINDS[kind]
  return def and def.frames() or {}, def and def.padX, def and def.padY
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
  CM.DB.global.seenWizard = true
  Options.Sync()
  -- Upgrades see the changelog after the tour (no-op when this version was already seen).
  C_Timer.After(0.5, function()
    if CM.Config and CM.Config.MaybeShowChangelogOnNewVersion then
      CM.Config.MaybeShowChangelogOnNewVersion()
    end
  end)
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
    -- `sectionEnd`: the highlight runs on to the end of that later section of the same tab.
    if targets and step.sectionEnd then
      for _, section in ipairs(Options.sections) do
        if section.tab == step.tab and section.label == step.sectionEnd then
          targets[2] = section.lastFrame
          break
        end
      end
    end
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
