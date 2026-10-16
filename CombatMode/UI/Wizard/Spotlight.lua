---------------------------------------------------------------------------------------
--  UI/Wizard/Spotlight.lua — WIZARD — dimmed-screen spotlight + explanation balloon
---------------------------------------------------------------------------------------
--  What it does: Dims the whole screen except one frame (the "hole") and shows a balloon next
--  to it with a title, a short explanation, step counter and Back / Next / Skip controls. Used
--  by the setup wizard's tour (UI/Wizard/SetupWizard.lua).
--  Architecture / how it works:
--    • The dim is UI.CreateDimHole: four rectangles around the hole (top / bottom / left / right)
--      and an accent outline marking it (the frame picker reuses it). Nothing is mouse-blocking: the highlighted widget (and the rest
--      of the options window) stays fully usable, so the player can change settings mid-tour.
--    • The target is one frame or a list of frames (the hole is their union); the dim hides
--      while no target is visible (e.g. the player switched tabs) and returns when it is.
--    • An OnUpdate re-reads the target's screen rect every frame, so the hole follows the
--      widget while the options tab is still scrolling it into view.
--    • The balloon sits right of the hole, else left, else below / above, clamped on screen.
--    • Steps that show the live crosshair / HUD preview pass `alsoHighlight` (a function returning
--      frames): their union becomes a second hole with its own outline (so the crosshair is not
--      dimmed), and the balloon moves to a spot that covers neither hole.
--    • Tasks: a step can list actions (label + done()) shown as a check list under the text; Next /
--      Finish stay disabled until every one is done (re-checked a few times a second).
--    • Between steps the whole spotlight fades out (UI.FadeOutSpotlight) while the options tab scrolls
--      to the next target, and fades back in with it (UI.ShowSpotlight), so it never visibly chases a
--      moving widget.
--    • ESC skips the tour (keyboard is captured only while the spotlight is shown; every other
--      key still propagates so the game stays responsive).
--  Does not: Decide what to highlight or what the steps say (SetupWizard.lua).
--  Related: UI/Wizard/SetupWizard.lua, UI/Options/Draw.lua, UI/Options/Widgets.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local max = _G.math.max
local min = _G.math.min
local sort = _G.table.sort

local UI = CM.UI
local C = UI.Colors

local DIM_ALPHA = 0.62
local RING_W = 2 -- accent outline thickness
local HOLE_PAD = 6 -- breathing room between the highlighted widget and the dim
-- Extra room around the live preview (crosshair + HUD): the HUD's key / name text hangs outside its frame.
local EXTRA_PAD_X = 100
local EXTRA_PAD_Y = 16
local BALLOON_W = 320
local BALLOON_PAD = 14
local BALLOON_GAP = 16 -- distance from the hole to the balloon
local SCREEN_MARGIN = 12
local BTN_W = 88
local ROOT_LEVEL = 9000
local FADE_TIME = 0.15
local TASK_H = 20
local TASK_GAP = 10
local TASK_POLL_S = 0.2
local CHECK_TEXTURE = CM.Constants.CheckMark

local spotlight

--- A screen dim with a rectangular hole and an accent outline around it (four mouse-transparent
--- dim rectangles plus four outline edges, all children of `parent`, above frame level `level`).
--- `hole.Layout(left, right, top, bottom)` cuts the hole (UIParent units); with no rect it dims the
--- whole screen. `hole.SetShown(false)` hides all of it. Used by the tour and the frame picker.
function UI.CreateDimHole(parent, level)
  local pieces = {}
  for i = 1, 4 do
    local piece = CreateFrame("Frame", nil, parent)
    piece:SetFrameLevel(level + 1)
    piece:EnableMouse(false)
    local tex = piece:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(0, 0, 0, DIM_ALPHA)
    pieces[i] = piece
  end

  -- Outline only (four edges): the highlighted widget inside stays untouched and readable.
  local function MakeRing()
    local r = CreateFrame("Frame", nil, parent)
    r:SetFrameLevel(level + 2)
    r:EnableMouse(false)
    local function Edge(p1, p2)
      local edge = r:CreateTexture(nil, "OVERLAY")
      edge:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
      edge:SetPoint(p1, r, p1)
      edge:SetPoint(p2, r, p2)
      return edge
    end
    Edge("TOPLEFT", "TOPRIGHT"):SetHeight(RING_W)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT"):SetHeight(RING_W)
    Edge("TOPLEFT", "BOTTOMLEFT"):SetWidth(RING_W)
    Edge("TOPRIGHT", "BOTTOMRIGHT"):SetWidth(RING_W)
    return r
  end
  local ring = MakeRing()

  -- Pools for LayoutRects (several holes): dim rectangles and outlines created on demand.
  local multiPieces = {}
  local multiRings = {}

  local hole = {}

  local function HideMulti()
    for i = 1, #multiPieces do
      multiPieces[i]:Hide()
    end
    for i = 1, #multiRings do
      multiRings[i]:Hide()
    end
  end

  function hole.SetShown(shown)
    for i = 1, #pieces do
      pieces[i]:SetShown(shown)
    end
    ring:SetShown(shown)
    if not shown then
      HideMulti()
    end
  end

  --- Cuts several holes at once: `rects` = list of { left, right, top, bottom } in UIParent
  --- units. The screen is cut into vertical bands at every hole edge and each band dims whatever
  --- its holes do not cover.
  function hole.LayoutRects(rects)
    for i = 1, #pieces do
      pieces[i]:Hide()
    end
    ring:Hide()
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local xs = { 0, screenW }
    for _, r in ipairs(rects) do
      xs[#xs + 1] = r.left
      xs[#xs + 1] = r.right
    end
    sort(xs)
    local used = 0
    local function Dim(x1, x2, y1, y2)
      used = used + 1
      local piece = multiPieces[used]
      if not piece then
        piece = CreateFrame("Frame", nil, parent)
        piece:SetFrameLevel(level + 1)
        piece:EnableMouse(false)
        local tex = piece:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetColorTexture(0, 0, 0, DIM_ALPHA)
        multiPieces[used] = piece
      end
      piece:ClearAllPoints()
      piece:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x1, y1)
      piece:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x2, y2)
      piece:Show()
    end
    for k = 1, #xs - 1 do
      local x1, x2 = xs[k], xs[k + 1]
      if x2 > x1 then
        local spans = {}
        for _, r in ipairs(rects) do
          if r.left <= x1 and r.right >= x2 then
            spans[#spans + 1] = r
          end
        end
        sort(spans, function(a, b)
          return a.bottom < b.bottom
        end)
        local y = 0
        for _, r in ipairs(spans) do
          if r.bottom > y then
            Dim(x1, x2, y, r.bottom)
          end
          y = max(y, r.top)
        end
        if y < screenH then
          Dim(x1, x2, y, screenH)
        end
      end
    end
    for i = used + 1, #multiPieces do
      multiPieces[i]:Hide()
    end
    for i, r in ipairs(rects) do
      local outline = multiRings[i]
      if not outline then
        outline = MakeRing()
        multiRings[i] = outline
      end
      outline:ClearAllPoints()
      outline:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", r.left, r.bottom)
      outline:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", r.right, r.top)
      outline:Show()
    end
    for i = #rects + 1, #multiRings do
      multiRings[i]:Hide()
    end
  end

  function hole.Layout(left, right, top, bottom)
    local top_, bottom_, left_, right_ = pieces[1], pieces[2], pieces[3], pieces[4]
    HideMulti()
    if not left then
      top_:ClearAllPoints()
      top_:SetAllPoints(UIParent)
      top_:Show()
      bottom_:Hide()
      left_:Hide()
      right_:Hide()
      ring:Hide()
      return
    end
    hole.SetShown(true)
    top_:ClearAllPoints()
    top_:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, top)
    top_:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, 0)
    bottom_:ClearAllPoints()
    bottom_:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    bottom_:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, bottom)
    left_:ClearAllPoints()
    left_:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, bottom)
    left_:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", left, top)
    right_:ClearAllPoints()
    right_:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", right, bottom)
    right_:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, top)
    ring:ClearAllPoints()
    ring:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    ring:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", right, top)
  end

  return hole
end

--- Re-evaluates the step's tasks: marks each row and enables Next / Finish once all are done.
local function RefreshTasks(self)
  local allDone = true
  for i, task in ipairs(self.tasks) do
    local row = self.taskRows[i]
    local done = task.done() and true or false
    allDone = allDone and done
    if row then
      row.check:SetShown(done)
      if done then
        row.label:SetTextColor(C.success[1], C.success[2], C.success[3])
      else
        row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
      end
    end
  end
  for _, button in ipairs({ self.next, self.finish }) do
    button:SetEnabled(allDone)
    button:SetAlpha(allDone and 1 or 0.45)
  end
end

local function EnsureTaskRow(self, i)
  local row = self.taskRows[i]
  if row then
    return row
  end
  row = CreateFrame("Frame", nil, self.taskHost)
  row:SetHeight(TASK_H)
  row:SetPoint("TOPLEFT", self.taskHost, "TOPLEFT", 0, -(i - 1) * TASK_H)
  row:SetPoint("TOPRIGHT", self.taskHost, "TOPRIGHT", 0, -(i - 1) * TASK_H)
  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetSize(14, 14)
  box:SetPoint("LEFT", row, "LEFT", 0, 0)
  UI.StyleRounded(box, C.inputBg, C.cardBorder, 3, 1)
  row.check = box:CreateTexture(nil, "OVERLAY")
  row.check:SetTexture(CHECK_TEXTURE)
  row.check:SetDesaturated(true)
  row.check:SetVertexColor(C.success[1], C.success[2], C.success[3])
  row.check:SetPoint("CENTER", box, "CENTER", 0, 0)
  row.check:SetSize(20, 20)
  row.check:Hide()
  row.label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  row.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
  row.label:SetJustifyH("LEFT")
  row.label:SetTextColor(C.text[1], C.text[2], C.text[3])
  self.taskRows[i] = row
  return row
end

--- Union rect (UIParent units, padded) of the visible frames in `frames`, or nil when none show.
local function ExtraRect(frames)
  local left, right, top, bottom
  for i = 1, #frames do
    local frame = frames[i]
    local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if frame:IsVisible() and l and r and t and b then
      local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
      left = left and min(left, l * scale) or l * scale
      right = right and max(right, r * scale) or r * scale
      bottom = bottom and min(bottom, b * scale) or b * scale
      top = top and max(top, t * scale) or t * scale
    end
  end
  if not left then
    return nil
  end
  local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
  return {
    left = max(left - EXTRA_PAD_X, 0),
    right = min(right + EXTRA_PAD_X, screenW),
    bottom = max(bottom - EXTRA_PAD_Y, 0),
    top = min(top + EXTRA_PAD_Y, screenH),
  }
end

local function Build()
  local root = CreateFrame("Frame", "CombatModeSpotlight", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("FULLSCREEN_DIALOG")
  root:SetFrameLevel(ROOT_LEVEL)
  root:Hide()

  local hole = UI.CreateDimHole(root, ROOT_LEVEL)

  local balloon = CreateFrame("Frame", nil, root)
  balloon:SetFrameLevel(ROOT_LEVEL + 10)
  balloon:SetWidth(BALLOON_W)
  balloon:EnableMouse(true)
  UI.StyleWindow(balloon)

  local title = UI.CreateFontString(balloon, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", balloon, "TOPLEFT", BALLOON_PAD, -BALLOON_PAD)
  title:SetPoint("TOPRIGHT", balloon, "TOPRIGHT", -(BALLOON_PAD + 44), -BALLOON_PAD)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  title:SetTextColor(C.text[1], C.text[2], C.text[3])

  local rule = UI.CreateLine(balloon, false, C.headerRule, "fade")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  rule:SetPoint("TOPRIGHT", balloon, "TOPRIGHT", -BALLOON_PAD, 0)

  local body = UI.CreateFontString(balloon, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  body:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -10)
  body:SetWidth(BALLOON_W - 2 * BALLOON_PAD)
  body:SetJustifyH("LEFT")
  body:SetJustifyV("TOP")
  body:SetWordWrap(true)
  body:SetTextColor(C.text[1], C.text[2], C.text[3])

  -- Check list of the actions a step asks for (rows are created on demand).
  local taskHost = CreateFrame("Frame", nil, balloon)
  taskHost:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -TASK_GAP)
  taskHost:SetPoint("TOPRIGHT", body, "BOTTOMRIGHT", 0, -TASK_GAP)
  taskHost:SetHeight(1)

  local step = UI.CreateFontString(balloon, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  step:SetPoint("TOPRIGHT", balloon, "TOPRIGHT", -BALLOON_PAD, -(BALLOON_PAD + 3))
  step:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])

  local back = UI.CreateDialogButton(balloon, "Back")
  back:SetWidth(BTN_W)
  back:SetPoint("BOTTOMLEFT", balloon, "BOTTOMLEFT", BALLOON_PAD, BALLOON_PAD)
  local nextButton = UI.CreateDialogButton(balloon, "Next")
  nextButton:SetWidth(BTN_W + 16)
  nextButton:SetPoint("BOTTOMRIGHT", balloon, "BOTTOMRIGHT", -BALLOON_PAD, BALLOON_PAD)
  -- The last step swaps Next for an accent-coloured Finish button in the same spot.
  local finishButton = UI.CreateDialogButton(balloon, "Finish", "primary")
  finishButton:SetWidth(BTN_W + 16)
  finishButton:SetPoint("BOTTOMRIGHT", balloon, "BOTTOMRIGHT", -BALLOON_PAD, BALLOON_PAD)
  finishButton:Hide()

  local skip = CreateFrame("Button", nil, balloon)
  local skipText = UI.CreateFontString(skip, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  skipText:SetPoint("CENTER")
  skipText:SetText("Skip tour")
  skipText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  skip:SetSize(skipText:GetStringWidth() + 8, 20)
  skip:SetPoint("BOTTOM", balloon, "BOTTOM", 0, BALLOON_PAD + 4)
  skip:SetScript("OnEnter", function()
    skipText:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  skip:SetScript("OnLeave", function()
    skipText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  end)

  local self = {
    root = root,
    balloon = balloon,
    title = title,
    body = body,
    step = step,
    back = back,
    next = nextButton,
    finish = finishButton,
    skip = skip,
    taskHost = taskHost,
    taskRows = {},
    tasks = {},
  }

  back:SetScript("OnClick", function()
    if self.onBack then
      self.onBack()
    end
  end)
  nextButton:SetScript("OnClick", function()
    if self.onNext then
      self.onNext()
    end
  end)
  finishButton:SetScript("OnClick", function()
    if self.onNext then
      self.onNext()
    end
  end)
  skip:SetScript("OnClick", function()
    if self.onSkip then
      self.onSkip()
    end
  end)

  -- ESC skips; everything else keeps flowing to the game.
  root:SetScript("OnShow", function(frame)
    frame:EnableKeyboard(true)
    if frame.SetPropagateKeyboardInput and not InCombatLockdown() then
      frame:SetPropagateKeyboardInput(true)
    end
  end)
  root:SetScript("OnHide", function(frame)
    frame:EnableKeyboard(false)
  end)
  root:SetScript("OnKeyDown", function(frame, key)
    if InCombatLockdown() then
      return
    end
    if key == "ESCAPE" then
      frame:SetPropagateKeyboardInput(false)
      if self.onSkip then
        self.onSkip()
      end
    else
      frame:SetPropagateKeyboardInput(true)
    end
  end)

  local lastKey
  root:SetScript("OnUpdate", function(_, elapsed)
    local fadeTo = self.fadeTo
    if fadeTo then
      local alpha = root:GetAlpha()
      local delta = (elapsed or 0) / FADE_TIME
      alpha = alpha < fadeTo and min(alpha + delta, fadeTo) or max(alpha - delta, fadeTo)
      root:SetAlpha(alpha)
      if alpha == fadeTo then
        self.fadeTo = nil
        if fadeTo == 0 then
          self.balloon:Hide() -- invisible buttons must not catch clicks
        end
      end
    end
    if #self.tasks > 0 then
      self.taskElapsed = (self.taskElapsed or 0) + (elapsed or 0)
      if self.taskElapsed >= TASK_POLL_S then
        self.taskElapsed = 0
        RefreshTasks(self)
      end
    end
    -- While fading out for the next step the layout stays frozen where it was, so the old
    -- highlight does not follow its widget as the tab scrolls away.
    local targets = self.targets
    if self.frozen or not targets then
      return
    end
    -- Union of the visible target frames, in UIParent units.
    local screenW, screenH = UIParent:GetWidth(), UIParent:GetHeight()
    local left, right, top, bottom
    for i = 1, #targets do
      local frame = targets[i]
      local l, r, t, b = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
      if frame:IsVisible() and l and r and t and b then
        local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
        left = left and min(left, l * scale) or l * scale
        right = right and max(right, r * scale) or r * scale
        bottom = bottom and min(bottom, b * scale) or b * scale
        top = top and max(top, t * scale) or t * scale
      end
    end
    -- Keep the hole inside the options tab's visible area (a tall section scrolls past it).
    local clip = self.clip
    if left and clip and clip:IsVisible() and clip:GetLeft() then
      local scale = clip:GetEffectiveScale() / UIParent:GetEffectiveScale()
      left = max(left, clip:GetLeft() * scale)
      right = min(right, clip:GetRight() * scale)
      bottom = max(bottom, clip:GetBottom() * scale)
      top = min(top, clip:GetTop() * scale)
      if left >= right or bottom >= top then
        left = nil
      end
    end
    if not left then
      hole.SetShown(false)
      lastKey = nil
      return
    end
    left = max(left - HOLE_PAD, 0)
    right = min(right + HOLE_PAD, screenW)
    bottom = max(bottom - HOLE_PAD, 0)
    top = min(top + HOLE_PAD, screenH)

    -- The live crosshair / HUD preview (if the step shows one): union of its visible frames.
    local extra = self.alsoHighlight and ExtraRect(self.alsoHighlight())
    local key = left + right * 3 + top * 7 + bottom * 11
    if extra then
      key = key + extra.left * 13 + extra.right * 17 + extra.top * 19 + extra.bottom * 23
    end
    if key == lastKey then
      return
    end
    lastKey = key

    local main = { left = left, right = right, top = top, bottom = bottom }
    local rects = { main }
    if extra then
      rects[2] = extra
    end
    hole.LayoutRects(rects)

    -- Balloon: right of the hole, else left, else below / above; clamped on screen. With a
    -- preview shown it must also keep clear of the crosshair / HUD, so it takes the first spot
    -- (beside, below or above the widget, then a screen corner) that covers neither hole.
    local balloonH = balloon:GetHeight()
    local function Clamp(px, py)
      return max(SCREEN_MARGIN, min(px, screenW - BALLOON_W - SCREEN_MARGIN)),
        max(balloonH + SCREEN_MARGIN, min(py, screenH - SCREEN_MARGIN))
    end
    local function Covers(px, py, r)
      return px < r.right + BALLOON_GAP
        and px + BALLOON_W > r.left - BALLOON_GAP
        and py > r.bottom - BALLOON_GAP
        and py - balloonH < r.top + BALLOON_GAP
    end
    local midY = (top + bottom) / 2 + balloonH / 2
    local midX = (left + right) / 2 - BALLOON_W / 2
    local candidates = {
      { right + BALLOON_GAP, midY },
      { left - BALLOON_GAP - BALLOON_W, midY },
      { midX, bottom - BALLOON_GAP },
      { midX, top + BALLOON_GAP + balloonH },
      { screenW, screenH },
      { 0, screenH },
      { screenW, 0 },
      { 0, 0 },
    }
    local x, y
    for i = 1, #candidates do
      local cx, cy = Clamp(candidates[i][1], candidates[i][2])
      if not Covers(cx, cy, main) and not (extra and Covers(cx, cy, extra)) then
        x, y = cx, cy
        break
      end
    end
    if not x then
      -- Nothing clears both holes: keep the classic placement beside the widget.
      local px, py
      if right + BALLOON_GAP + BALLOON_W + SCREEN_MARGIN <= screenW then
        px, py = right + BALLOON_GAP, midY
      elseif left - BALLOON_GAP - BALLOON_W - SCREEN_MARGIN >= 0 then
        px, py = left - BALLOON_GAP - BALLOON_W, midY
      elseif bottom - BALLOON_GAP - balloonH >= SCREEN_MARGIN then
        px, py = midX, bottom - BALLOON_GAP
      else
        px, py = midX, top + BALLOON_GAP + balloonH
      end
      x, y = Clamp(px, py)
    end
    balloon:ClearAllPoints()
    balloon:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
  end)
  root.cmResetLayout = function()
    lastKey = nil
  end

  return self
end

--- Shows the spotlight on `target` (a frame, or a list of frames) with the balloon described by `opts`:
--- { title, body, step ("3 / 7"), nextLabel, isLast (shows the accent Finish button), canGoBack, tasks ({ label, done() } list that gates Next / Finish), clip (frame the hole is cut to), alsoHighlight (function returning the live preview frames to leave undimmed), onNext, onBack, onSkip }.
function UI.ShowSpotlight(target, opts)
  spotlight = spotlight or Build()
  local s = spotlight
  s.targets = target.GetLeft and { target } or target
  s.clip = opts.clip
  s.alsoHighlight = opts.alsoHighlight
  s.onNext, s.onBack, s.onSkip = opts.onNext, opts.onBack, opts.onSkip

  s.title:SetText(opts.title or "")
  s.body:SetText(opts.body or "")
  s.step:SetText(opts.step or "")
  s.next.text:SetText(opts.nextLabel or "Next")
  s.next:SetShown(not opts.isLast)
  s.finish.text:SetText(opts.nextLabel or "Finish")
  s.finish:SetShown(opts.isLast and true or false)
  s.back:SetShown(opts.canGoBack and true or false)

  -- Task check list under the text.
  s.tasks = opts.tasks or {}
  for i, task in ipairs(s.tasks) do
    local row = EnsureTaskRow(s, i)
    row.label:SetText(task.label)
    row:Show()
  end
  for i = #s.tasks + 1, #s.taskRows do
    s.taskRows[i]:Hide()
  end
  local tasksH = #s.tasks > 0 and (TASK_GAP + #s.tasks * TASK_H) or 0
  s.taskHost:SetHeight(max(tasksH - TASK_GAP, 1))
  s.taskElapsed = 0
  RefreshTasks(s)

  -- Title + rule + body + tasks + button row.
  local bodyH = s.body:GetStringHeight() or 40
  s.balloon:SetHeight(
    BALLOON_PAD + 22 + 6 + 1 + 10 + bodyH + tasksH + 14 + UI.Sizes.control + BALLOON_PAD
  )

  s.root.cmResetLayout()
  -- Always fade in from invisible, so the move to the new target is never seen.
  s.frozen = false
  s.root:SetAlpha(0)
  s.root:Show()
  s.balloon:Show()
  s.balloon:Raise()
  s.fadeTo = 1
end

function UI.HideSpotlight()
  if spotlight then
    spotlight.targets = nil
    spotlight.clip = nil
    spotlight.alsoHighlight = nil
    spotlight.fadeTo = nil
    spotlight.frozen = false
    spotlight.root:SetAlpha(1)
    spotlight.root:Hide()
  end
end

--- Fades the shown spotlight out (it keeps listening for ESC); UI.ShowSpotlight fades it back in.
function UI.FadeOutSpotlight()
  if spotlight and spotlight.root:IsShown() then
    spotlight.fadeTo = 0
    spotlight.frozen = true
  end
end

function UI.IsSpotlightShown()
  return spotlight ~= nil and spotlight.root:IsShown()
end
