---------------------------------------------------------------------------------------
--  UI/Options/Draw.lua — OPTIONS TOOLKIT — drawing primitives + brand palette
---------------------------------------------------------------------------------------
--  Owns the low-level, reusable visual primitives for the custom (non-Ace) options
--  window: the theme tokens (CM.UI.Colors / UI.Fonts / UI.Radius — a minimal neutral-grey
--  ramp with a single warm-yellow accent), UI.StripColors, solid/rounded surfaces,
--  circular knob masking, font sizing, tooltip attach, ESC-close, drag-to-move with
--  position persistence helpers for optional drag (UI.EnableDrag / UI.RestorePosition),
--  StyleThumbBar scrollbars shared by CreateScrollFrame / CreateMultilineEditScroll /
--  CreateVerticalSlider (thin rounded track + thumb, wheel scroll eases toward a target),
--  UI.FadeAlpha for tab/segment crossfades, and the "control relinquished" watermark
--  overlay (CreateWatermark). The main options window docks left on open and does not
--  persist its position.
--
--  Owns visuals only — no settings logic. Consumed by UI/Options/Widgets.lua and
--  UI/Options/OptionsPanel.lua. This is our own license-safe reimplementation of the
--  "modern rounded card" aesthetic using Blizzard-shipped textures (no third-party art).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- WoW API
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local GetCursorPosition = _G.GetCursorPosition
local UIParent = _G.UIParent

-- Lua stdlib
local tinsert = _G.table.insert
local ipairs = _G.ipairs
local type = _G.type
local gsub = _G.string.gsub
local abs = _G.math.abs
local floor = _G.math.floor
local max = _G.math.max
local min = _G.math.min

local CORNER_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

CM.UI = CM.UI or {}
local UI = CM.UI

---------------------------------------------------------------------------------------
--                                     PALETTE                                       --
---------------------------------------------------------------------------------------
-- Minimal monochrome theme: one warm-yellow accent (section titles + "on" states) over a
-- neutral grey ramp. Deliberately no blue tint and no per-feature hues.
UI.Colors = {
  -- Single accent (section headers + selected tab).
  accent = { 1.000, 0.804, 0.235 }, -- FFCD3C

  -- Neutral text ramp.
  white = { 1.000, 1.000, 1.000 },
  text = { 0.804, 0.804, 0.804 }, -- primary labels
  textDim = { 0.549, 0.549, 0.549 }, -- descriptions / secondary
  grey = { 0.549, 0.549, 0.549 },

  -- Toggle "on" track (not a per-feature accent).
  green = { 0.290, 0.780, 0.420 },

  -- Window chrome: flat, near-black neutral greys.
  windowBg = { 0.055, 0.055, 0.055, 0.98 },
  windowBorder = { 0.204, 0.204, 0.204, 1.0 },
  cardBg = { 0.098, 0.098, 0.098, 1.0 },
  cardBorder = { 0.169, 0.169, 0.169, 1.0 },
  rowWash = { 1, 1, 1, 0.02 },
  trackOff = { 0.220, 0.220, 0.220, 1.0 },
  inputBg = { 0.035, 0.035, 0.035, 1.0 },
  tabHover = { 1, 1, 1, 0.05 },
  tabActive = { 1, 1, 1, 0.08 },
  disabled = { 0.450, 0.450, 0.450, 1.0 },
}

-- Fixed type scale: everything is `base` except section headers (ctx:Header) and the
-- muted under-option descriptions (`desc`).
UI.Fonts = {
  base = 10,
  header = 13,
  desc = 9,
}

-- Corner radii: small, so surfaces read as flat panels rather than pills.
UI.Radius = {
  window = 4,
  card = 3,
  control = 3,
}

--- Strips WoW color escape sequences so the panel renders in the neutral theme ramp
--- regardless of the inline |cff..| markup the option strings still carry.
function UI.StripColors(text)
  if not text or text == "" then
    return text
  end
  text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = gsub(text, "|r", "")
  return text
end

---------------------------------------------------------------------------------------
--                          SOLID ROUNDED-RECT RENDERER                             --
---------------------------------------------------------------------------------------
-- Crisp rounded rectangle drawn from solid fills (WHITE8x8 via SetColorTexture) with
-- the four corners rounded by a circular alpha mask. This is our license-safe stand-in
-- for EasyFind's private rounded-rect atlas: solid, sharp, no cloudy edges.
--
-- Each surface is a 9-slice: 4 masked corner quads + 4 solid edges + 1 solid center.
-- Returns { SetColor(r,g,b,a) } so callers can recolor on state changes (toggles, hover).
local function Build9Slice(frame, radius, layer, color, inset)
  inset = inset or 0
  local r, g, b, a = color[1], color[2], color[3], color[4] or 1
  local pieces = {}

  local function solid(...)
    local tex = frame:CreateTexture(nil, layer)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetPoint(...)
    pieces[#pieces + 1] = tex
    return tex
  end

  -- Center + 4 edges (solid rectangles, no rounding).
  local c = solid("TOPLEFT", frame, "TOPLEFT", inset + radius, -(inset + radius))
  c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + radius), inset + radius)

  local topEdge = solid("TOPLEFT", frame, "TOPLEFT", inset + radius, -inset)
  topEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + radius), -inset)
  topEdge:SetHeight(radius)

  local bottomEdge = solid("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + radius, inset)
  bottomEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + radius), inset)
  bottomEdge:SetHeight(radius)

  local leftEdge = solid("TOPLEFT", frame, "TOPLEFT", inset, -(inset + radius))
  leftEdge:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + radius)
  leftEdge:SetWidth(radius)

  local rightEdge = solid("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + radius))
  rightEdge:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + radius)
  rightEdge:SetWidth(radius)

  -- 4 rounded corners: R×R quad showing one quadrant of a 2R circular mask.
  local function corner(point, xoff, yoff)
    local tex = frame:CreateTexture(nil, layer)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetSize(radius, radius)
    tex:SetPoint(point, frame, point, xoff, yoff)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CORNER_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(radius * 2, radius * 2)
    mask:SetPoint(point, frame, point, xoff, yoff)
    tex:AddMaskTexture(mask)
    pieces[#pieces + 1] = tex
  end
  corner("TOPLEFT", inset, -inset)
  corner("TOPRIGHT", -inset, -inset)
  corner("BOTTOMLEFT", inset, inset)
  corner("BOTTOMRIGHT", -inset, inset)

  return {
    SetColor = function(nr, ng, nb, na)
      for _, tex in ipairs(pieces) do
        tex:SetVertexColor(nr, ng, nb, na or 1)
      end
    end,
  }
end

---------------------------------------------------------------------------------------
--                                    PRIMITIVES                                     --
---------------------------------------------------------------------------------------
--- Solid color texture pinned to all corners of `frame` on the given draw layer.
function UI.Fill(frame, layer, color, alpha)
  local tex = frame:CreateTexture(nil, layer or "BACKGROUND")
  tex:SetAllPoints(frame)
  tex:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
  return tex
end

--- Paints a crisp solid rounded rectangle onto `frame` (thin border + fill).
--- Exposes frame.cmSetFill(r,g,b,a) / frame.cmSetBorder(r,g,b,a) for state recolors.
--- `radius` defaults to a card corner; pass height/2 for a pill.
function UI.StyleRounded(frame, fill, border, radius)
  radius = radius or UI.Radius.card
  fill = fill or UI.Colors.cardBg
  border = border or UI.Colors.cardBorder

  local borderSlice = Build9Slice(frame, radius, "BACKGROUND", border, 0)
  local fillSlice = Build9Slice(frame, radius, "BORDER", fill, 1)

  frame.cmSetFill = function(_, r, g, b, a)
    fillSlice.SetColor(r, g, b, a)
  end
  frame.cmSetBorder = function(_, r, g, b, a)
    borderSlice.SetColor(r, g, b, a)
  end
  return frame
end

--- Convenience: small-radius control surface (was a full pill before the flat theme).
function UI.StylePill(frame, fill, border)
  UI.StyleRounded(frame, fill, border, UI.Radius.control)
end

--- Creates a card frame (parented, no positioning) styled like a settings group.
function UI.CreateCard(parent)
  local card = CreateFrame("Frame", nil, parent)
  UI.StyleRounded(card, UI.Colors.cardBg, UI.Colors.cardBorder, UI.Radius.card)
  return card
end

--- Custom window close button ("X") — replaces Blizzard's UIPanelCloseButton art with a
--- flat button that lifts to a neutral grey on hover. Closes its parent by default;
--- override OnClick for custom behavior. Caller positions it.
function UI.CreateCloseButton(parent)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(22, 22)
  -- Sit above the title bar drag handle, which overlaps this corner; otherwise the drag
  -- frame swallows clicks and only the sliver past the title bar edge stays clickable.
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  UI.StyleRounded(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

  local x = UI.CreateFontString(btn, "OVERLAY", 14, "GameFontNormalLarge")
  x:SetPoint("CENTER", btn, "CENTER", 0, 0)
  x:SetText("\195\151") -- multiplication sign (crisp X glyph)
  x:SetTextColor(0.60, 0.60, 0.60)

  btn:SetScript("OnEnter", function(self)
    self:cmSetFill(1, 1, 1, 0.10)
    x:SetTextColor(1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self:cmSetFill(0, 0, 0, 0)
    x:SetTextColor(0.60, 0.60, 0.60)
  end)
  btn:SetScript("OnClick", function()
    parent:Hide()
  end)
  return btn
end

--- Circular texture: a texture with a circular alpha mask applied (for switch knobs/dots).
function UI.CreateCircle(frame, layer, color)
  local tex = frame:CreateTexture(nil, layer or "ARTWORK")
  tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  local mask = frame:CreateMaskTexture()
  mask:SetTexture(
    "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE",
    "CLAMPTOBLACKADDITIVE"
  )
  mask:SetAllPoints(tex)
  tex:AddMaskTexture(mask)
  tex.cmMask = mask
  return tex
end

--- Font string sized in pixels using the addon's locale-aware font helper. Defaults to the
--- fixed base size; only section headers should opt into UI.Fonts.header.
function UI.CreateFontString(parent, layer, pixelSize, template)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontNormal")
  if CM.SetFontStringFromTemplate then
    CM.SetFontStringFromTemplate(fs, pixelSize or UI.Fonts.base, _G[template or "GameFontNormal"])
  end
  return fs
end

--- Applies the theme's pixel sizing to a font string that already exists (e.g. a Button's
--- built-in label, which can't be routed through UI.CreateFontString).
function UI.SetFontSize(fs, pixelSize, template)
  if fs and CM.SetFontStringFromTemplate then
    CM.SetFontStringFromTemplate(fs, pixelSize or UI.Fonts.base, _G[template or "GameFontNormal"])
  end
  return fs
end

---------------------------------------------------------------------------------------
--                                    BEHAVIORS                                      --
---------------------------------------------------------------------------------------
--- Delayed tooltip on hover. `getText` returns the (already color-coded) string.
function UI.AttachTooltip(widget, getText, anchor)
  if not getText then
    return
  end
  widget:HookScript("OnEnter", function(self)
    local text = type(getText) == "function" and getText() or getText
    if not text or text == "" then
      return
    end
    GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  widget:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

--- Registers a named frame so pressing ESC closes it (standard Blizzard pattern).
function UI.EnableEscClose(frame, globalName)
  _G[globalName] = frame
  tinsert(_G.UISpecialFrames, globalName)
end

--- Makes `frame` draggable by `handle`. When `persist` is true the anchor is saved to
--- CM.DB.global.optionsPanelPosition (optional; the main options window docks left on
--- open and does not persist).
function UI.EnableDrag(frame, handle, persist)
  handle = handle or frame
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  handle:EnableMouse(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  handle:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    if persist and CM.DB and CM.DB.global then
      local point, _, relPoint, x, y = frame:GetPoint(1)
      CM.DB.global.optionsPanelPosition = { point = point, relPoint = relPoint, x = x, y = y }
    end
  end)
end

--- Restores a persisted position, or centers the frame if none is saved.
function UI.RestorePosition(frame)
  local pos = CM.DB and CM.DB.global and CM.DB.global.optionsPanelPosition
  frame:ClearAllPoints()
  if type(pos) == "table" and pos.point then
    frame:SetPoint(pos.point, _G.UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
  else
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
  end
end

---------------------------------------------------------------------------------------
--                              CUSTOM SCROLLBAR / SCROLL                             --
---------------------------------------------------------------------------------------
-- Thin, modern, thumb-only scrollbar that replaces UIPanelScrollFrameTemplate's chrome
-- (Blizzard track + up/down arrow buttons). Track + thumb are crisp rounded fills; the
-- thumb is drag-scrollable and the wheel eases toward a target offset (smooth scroll).
-- No Blizzard scroll art.
--
-- Returns (scrollFrame, content, scrollBar). The caller positions scrollFrame + scrollBar
-- and sizes content's width; scrollFrame.cmUpdate() (also run on scroll/size changes)
-- recomputes the thumb + visibility.

local SCROLL_WHEEL_STEP = 72
local SCROLL_SMOOTH_SPEED = 16 -- higher = snappier ease toward target

--- Builds the thin rounded track + draggable thumb (parented to `owner`, positioned by caller).
local function StyleThumbBar(owner, thickness)
  thickness = thickness or 6
  local bar = CreateFrame("Frame", nil, owner)
  bar:SetWidth(thickness)
  UI.StyleRounded(bar, { 1, 1, 1, 0.05 }, { 0, 0, 0, 0 }, thickness / 2)

  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(thickness)
  thumb:SetHeight(40)
  thumb:SetPoint("TOP", bar, "TOP", 0, 0)
  local a = UI.Colors.accent
  UI.StyleRounded(thumb, { a[1], a[2], a[3], 1 }, { 0, 0, 0, 0 }, thickness / 2)
  thumb:EnableMouse(true)
  return bar, thumb
end

--- Wires wheel scrolling + thumb sizing/drag onto an existing ScrollFrame + bar/thumb.
local function WireThumbScroll(scroll, bar, thumb)
  local targetScroll = 0
  local smoothing = false

  local function Range()
    return scroll:GetVerticalScrollRange() or 0
  end

  local function ClampScroll(value)
    local range = Range()
    if value < 0 then
      return 0
    end
    if value > range then
      return range
    end
    return value
  end

  local function UpdateThumbOnly()
    local range = Range()
    local trackH = bar:GetHeight()
    if range <= 1 or trackH <= 1 then
      bar:Hide()
      return
    end
    bar:Show()
    local viewH = scroll:GetHeight()
    local contentH = viewH + range
    local thumbH = max(24, trackH * (viewH / contentH))
    thumb:SetHeight(thumbH)
    local pct = scroll:GetVerticalScroll() / range
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -pct * (trackH - thumbH))
  end

  local function StopSmooth()
    if not smoothing then
      return
    end
    smoothing = false
    scroll:SetScript("OnUpdate", nil)
  end

  local function StartSmooth()
    if smoothing then
      return
    end
    smoothing = true
    scroll:SetScript("OnUpdate", function(self, elapsed)
      if thumb.dragging then
        return
      end
      local current = self:GetVerticalScroll()
      local diff = targetScroll - current
      if abs(diff) < 0.35 then
        self:SetVerticalScroll(targetScroll)
        UpdateThumbOnly()
        StopSmooth()
        return
      end
      local t = min(1, (elapsed or 0) * SCROLL_SMOOTH_SPEED)
      self:SetVerticalScroll(current + diff * t)
      UpdateThumbOnly()
    end)
  end

  function scroll.cmUpdate()
    local range = Range()
    local trackH = bar:GetHeight()
    if range <= 1 or trackH <= 1 then
      bar:Hide()
      targetScroll = 0
      StopSmooth()
      scroll:SetVerticalScroll(0)
      return
    end
    targetScroll = ClampScroll(targetScroll)
    if not smoothing and not thumb.dragging then
      -- External SetVerticalScroll callers (caret keep-in-view, etc.) stay in sync.
      targetScroll = ClampScroll(scroll:GetVerticalScroll())
    elseif targetScroll > range then
      targetScroll = range
      scroll:SetVerticalScroll(range)
    end
    UpdateThumbOnly()
  end

  --- Scroll to `value`. Pass true for instant (thumb drag / programmatic snaps).
  local function ScrollTo(value, instant)
    targetScroll = ClampScroll(value)
    if instant then
      StopSmooth()
      scroll:SetVerticalScroll(targetScroll)
      UpdateThumbOnly()
      return
    end
    StartSmooth()
  end

  scroll.cmScrollTo = ScrollTo
  function scroll.cmGetTargetScroll()
    return targetScroll
  end

  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(_, delta)
    -- Accumulate on the target so rapid wheel notches keep momentum.
    ScrollTo(targetScroll - delta * SCROLL_WHEEL_STEP, false)
  end)
  scroll:SetScript("OnScrollRangeChanged", scroll.cmUpdate)
  scroll:HookScript("OnSizeChanged", scroll.cmUpdate)

  thumb:SetScript("OnMouseDown", function(self)
    local _, cy = GetCursorPosition()
    StopSmooth()
    self.dragging = true
    self.dragStartY = cy
    self.startScroll = scroll:GetVerticalScroll()
    targetScroll = self.startScroll
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self.dragging = false
    targetScroll = scroll:GetVerticalScroll()
  end)
  thumb:SetScript("OnUpdate", function(self)
    if not self.dragging then
      return
    end
    local trackH = bar:GetHeight()
    local thumbH = self:GetHeight()
    local usable = trackH - thumbH
    if usable <= 0 then
      return
    end
    local _, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local deltaPx = (self.dragStartY - cy) / scale
    ScrollTo(self.startScroll + (deltaPx / usable) * Range(), true)
  end)
end

function UI.CreateScrollFrame(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  local bar, thumb = StyleThumbBar(parent, 6)
  WireThumbScroll(scroll, bar, thumb)

  scroll.cmScrollBar = bar
  return scroll, content, bar
end

--- ScrollFrame whose scroll child is a multi-line EditBox, with our custom thin bar
--- (no Blizzard scroll chrome). Returns (scroll, edit, bar); caller positions all three.
--- Clicking the scroll surface focuses the EditBox (AceGUI MultiLineEditBox parity) —
--- without that, nested tab ScrollFrames make the field feel permanently disabled.
function UI.CreateMultilineEditScroll(owner)
  local scroll = CreateFrame("ScrollFrame", nil, owner)
  scroll:EnableMouse(true)

  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:EnableMouse(true)
  edit:SetWidth(1)
  edit:SetHeight(1)
  scroll:SetScrollChild(edit)

  local bar, thumb = StyleThumbBar(owner, 5)
  WireThumbScroll(scroll, bar, thumb)

  local function SyncEditSize(width, height)
    if width and width > 0 then
      edit:SetWidth(width)
    end
    -- Keep the edit at least as tall as the viewport so empty fields remain clickable.
    local h = height or scroll:GetHeight() or 0
    if h > 0 and edit:GetHeight() < h then
      edit:SetHeight(h)
    end
  end

  scroll:HookScript("OnSizeChanged", function(_, w, h)
    SyncEditSize(w, h)
  end)
  scroll:SetScript("OnMouseDown", function()
    edit:SetFocus()
  end)
  edit:HookScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
    -- Keep the caret in view while typing (y is negative as the cursor moves down).
    local offset = scroll:GetVerticalScroll()
    local viewH = scroll:GetHeight()
    local cursorTop = -y
    local cursorBottom = cursorTop + (cursorHeight or 0)
    if cursorTop < offset then
      scroll:SetVerticalScroll(cursorTop)
    elseif cursorBottom > offset + viewH then
      scroll:SetVerticalScroll(cursorBottom - viewH)
    end
    if scroll.cmUpdate then
      scroll.cmUpdate()
    end
  end)
  return scroll, edit, bar
end

--- Value-driven vertical scrollbar using the same StyleThumbBar chrome as CreateScrollFrame
--- (thin rounded track + rounded thumb). Exposes a Slider-compatible subset for callers that
--- drive their own row virtualization: SetMinMaxValues / SetValueStep / SetValue / SetScript
--- ("OnValueChanged"). Wheel / cmScrollBy ease toward a target; thumb drag snaps instantly.
--- Hides when max <= min (empty range), matching CreateScrollFrame.
function UI.CreateVerticalSlider(parent)
  local thickness = 6
  local bar, thumb = StyleThumbBar(parent, thickness)

  local minV, maxV = 0, 0
  local step = 1
  local value = 0 -- last snapped value reported to OnValueChanged
  local displayValue = 0 -- visual thumb position (may be mid-ease)
  local targetValue = 0
  local smoothing = false
  local onValueChanged

  -- Frame does not declare OnValueChanged (Slider does); intercept so callers can
  -- SetScript("OnValueChanged", ...) without changing ReticleCVarEditorPanel.
  local rawSetScript = bar.SetScript
  local rawGetScript = bar.GetScript
  function bar:SetScript(scriptType, handler)
    if scriptType == "OnValueChanged" then
      onValueChanged = handler
      return
    end
    return rawSetScript(self, scriptType, handler)
  end
  function bar:GetScript(scriptType)
    if scriptType == "OnValueChanged" then
      return onValueChanged
    end
    return rawGetScript(self, scriptType)
  end

  local function Clamp(v)
    if v < minV then
      return minV
    end
    if v > maxV then
      return maxV
    end
    return v
  end

  local function ClampSnap(v)
    if step and step > 0 then
      v = minV + floor((v - minV) / step + 0.5) * step
    end
    return Clamp(v)
  end

  local function UpdateThumb()
    local trackH = bar:GetHeight() or 0
    if maxV <= minV or trackH <= 1 then
      bar:Hide()
      return
    end
    bar:Show()
    local range = maxV - minV
    local thumbH = max(24, trackH / (range + 1))
    thumb:SetHeight(thumbH)
    local pct = (displayValue - minV) / range
    if pct < 0 then
      pct = 0
    elseif pct > 1 then
      pct = 1
    end
    thumb:ClearAllPoints()
    thumb:SetPoint("TOP", bar, "TOP", 0, -pct * (trackH - thumbH))
  end

  local function ReportSnapped()
    local snapped = ClampSnap(displayValue)
    if snapped ~= value then
      value = snapped
      if onValueChanged then
        onValueChanged(bar, value)
      end
    end
  end

  local function StopSmooth()
    if not smoothing then
      return
    end
    smoothing = false
    bar:SetScript("OnUpdate", nil)
  end

  local function StartSmooth()
    if smoothing then
      return
    end
    smoothing = true
    bar:SetScript("OnUpdate", function(_, elapsed)
      if thumb.dragging then
        return
      end
      local diff = targetValue - displayValue
      if abs(diff) < 0.02 then
        displayValue = targetValue
        UpdateThumb()
        ReportSnapped()
        value = ClampSnap(displayValue)
        StopSmooth()
        return
      end
      local t = min(1, (elapsed or 0) * SCROLL_SMOOTH_SPEED)
      displayValue = displayValue + diff * t
      UpdateThumb()
      ReportSnapped()
    end)
  end

  local function ApplyInstant(newValue, silent)
    newValue = ClampSnap(newValue)
    StopSmooth()
    displayValue = newValue
    targetValue = newValue
    local changed = newValue ~= value
    value = newValue
    UpdateThumb()
    if not silent and changed and onValueChanged then
      onValueChanged(bar, value)
    end
  end

  function bar:SetMinMaxValues(newMin, newMax)
    minV = newMin or 0
    maxV = newMax or 0
    if maxV < minV then
      maxV = minV
    end
    targetValue = Clamp(targetValue)
    displayValue = Clamp(displayValue)
    ApplyInstant(value, true)
  end

  function bar:SetValueStep(newStep)
    step = newStep or 1
  end

  function bar:SetValue(newValue)
    ApplyInstant(newValue or 0, false)
  end

  function bar:GetValue()
    return value
  end

  function bar:GetMinMaxValues()
    return minV, maxV
  end

  --- Ease by `delta` value units (negative = scroll up / earlier rows). Instant while dragging.
  function bar:cmScrollBy(delta, instant)
    if maxV <= minV then
      return
    end
    local nextTarget = Clamp(targetValue + (delta or 0))
    if instant or thumb.dragging then
      ApplyInstant(nextTarget, false)
      return
    end
    targetValue = nextTarget
    StartSmooth()
  end

  bar:HookScript("OnSizeChanged", UpdateThumb)

  thumb:SetScript("OnMouseDown", function(self)
    local _, cy = GetCursorPosition()
    StopSmooth()
    self.dragging = true
    self.dragStartY = cy
    self.startValue = displayValue
    targetValue = displayValue
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self.dragging = false
    targetValue = value
    displayValue = value
    UpdateThumb()
  end)
  thumb:SetScript("OnUpdate", function(self)
    if not self.dragging then
      return
    end
    local trackH = bar:GetHeight()
    local thumbH = self:GetHeight()
    local usable = trackH - thumbH
    if usable <= 0 then
      return
    end
    local range = maxV - minV
    if range <= 0 then
      return
    end
    local _, cy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local deltaPx = (self.dragStartY - cy) / scale
    ApplyInstant(self.startValue + (deltaPx / usable) * range, false)
  end)

  UpdateThumb()
  return bar
end

---------------------------------------------------------------------------------------
--                              FADE / MOTION HELPERS                                --
---------------------------------------------------------------------------------------
--- Eased alpha tween used by tab / segment crossfades. Clears any prior OnUpdate on the
--- frame. `onDone` runs when the tween reaches `toAlpha` (and after no-op snaps).
function UI.FadeAlpha(frame, toAlpha, duration, onDone)
  if not frame then
    if onDone then
      onDone()
    end
    return
  end
  duration = duration or 0.16
  frame:SetScript("OnUpdate", nil)
  local fromAlpha = frame:GetAlpha()
  if abs(fromAlpha - toAlpha) < 0.01 then
    frame:SetAlpha(toAlpha)
    if onDone then
      onDone()
    end
    return
  end
  local elapsed = 0
  frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + (dt or 0)
    local p = min(1, elapsed / duration)
    local eased = 1 - (1 - p) * (1 - p)
    self:SetAlpha(fromAlpha + (toAlpha - fromAlpha) * eased)
    if p >= 1 then
      self:SetScript("OnUpdate", nil)
      self:SetAlpha(toAlpha)
      if onDone then
        onDone()
      end
    end
  end)
end

---------------------------------------------------------------------------------------
--                                    WATERMARK                                       --
---------------------------------------------------------------------------------------
-- Semi-transparent "stamp" overlay drawn on top of a block whose control has been
-- handed off to a third party (e.g. DynamicCam). Dims + blocks the region and shows a
-- centered notice. Returns the overlay frame; call :Show()/:Hide() to toggle.
function UI.CreateWatermark(parent, text, fontSize)
  local overlay = CreateFrame("Frame", nil, parent)
  overlay:SetAllPoints(parent)
  overlay:SetFrameLevel(parent:GetFrameLevel() + 30)
  -- Block clicks on the relinquished controls, but let the wheel bubble up so the page
  -- still scrolls when hovering the stamped block.
  overlay:EnableMouse(true)

  local scrim = overlay:CreateTexture(nil, "OVERLAY")
  scrim:SetAllPoints(overlay)
  scrim:SetColorTexture(0.02, 0.02, 0.02, 0.62)

  local stamp =
    UI.CreateFontString(overlay, "OVERLAY", fontSize or UI.Fonts.header, "GameFontNormalLarge")
  stamp:SetPoint("CENTER", overlay, "CENTER", 0, 0)
  stamp:SetJustifyH("CENTER")
  stamp:SetText(UI.StripColors(text) or "")
  local a = UI.Colors.accent
  stamp:SetTextColor(a[1], a[2], a[3])
  stamp:SetShadowColor(0, 0, 0, 1)
  stamp:SetShadowOffset(1, -1)

  overlay:Hide()
  return overlay
end
