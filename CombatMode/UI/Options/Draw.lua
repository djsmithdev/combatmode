---------------------------------------------------------------------------------------
--  UI/Options/Draw.lua — OPTIONS — theme tokens + draw primitives
---------------------------------------------------------------------------------------
--  What it does: Boots `CM.UI` with the options theme (gold accent for headers/selection;
--  green-on / grey-off toggles), StripColors, surface/card helpers,
--  config tooltips, scroll thumbs, FadeAlpha, and watermark helpers shared by options,
--  changelog, and editors.
--  Architecture / how it works:
--    • UI.Colors / Fonts / Radius — single palette; accentMarkup derived from accent RGB;
--      toggleOn is separate from accent (off uses trackOff).
--    • StripColors removes Blizzard inline colors for consistent mono body text.
--    • No settings get/set — pure presentation primitives.
--  Does not: Create the options window shell or register tabs.
--  Related: UI/Options/Widgets.lua, UI/Options/OptionsPanel.lua,
--  UI/Changelog/ChangelogPanel.lua, UI/Editors/ReticleCVarEditorPanel.lua,
--  UI/Editors/TargetingMacroPrelinesEditor.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCursorPosition = _G.GetCursorPosition
local UIParent = _G.UIParent

-- Lua stdlib
local tinsert = _G.table.insert
local ipairs = _G.ipairs
local type = _G.type
local tostring = _G.tostring
local gsub = _G.string.gsub
local format = _G.string.format
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
-- Minimal monochrome theme: one warm-gold accent (section titles, selected tab) over a
-- neutral grey ramp. Toggle on uses dedicated green; off stays trackOff grey.
-- accentMarkup is derived from accent RGB — edit accent only for headers/selection chrome.
local function RgbToCffMarkup(r, g, b)
  return format(
    "|cff%02x%02x%02x",
    floor(r * 255 + 0.5),
    floor(g * 255 + 0.5),
    floor(b * 255 + 0.5)
  )
end

UI.Colors = {
  -- Single accent (section headers + selected tab + scroll thumb).
  accent = { 0.878, 0.722, 0.278 }, -- E0B847

  -- Neutral text ramp.
  white = { 1.000, 1.000, 1.000 },
  text = { 0.804, 0.804, 0.804 }, -- primary labels
  textDim = { 0.549, 0.549, 0.549 }, -- descriptions / secondary
  grey = { 0.549, 0.549, 0.549 },
  -- Caution / destructive callouts (Advanced editor warning, etc.).
  warning = { 0.820, 0.350, 0.350 },

  -- Toggle track fill when on (green). Off uses trackOff grey.
  toggleOn = { 0.320, 0.620, 0.380, 1.0 },

  -- Window chrome: dark slate panel fill.
  windowBg = { 0.094, 0.106, 0.125, 1.0 }, -- rgb(24, 27, 32) — darker slate of 39/43/51
  windowBorder = { 0.204, 0.204, 0.204, 1.0 },
  cardBg = { 0.098, 0.098, 0.098, 1.0 },
  cardBorder = { 0.169, 0.169, 0.169, 1.0 },
  rowWash = { 1, 1, 1, 0.02 },
  trackOff = { 0.220, 0.220, 0.220, 1.0 },
  -- Input wells (text fields, editor filters): darker slate than the panel.
  inputBg = { 0.055, 0.062, 0.078, 1.0 }, -- rgb(14, 16, 20)
  tabHover = { 1, 1, 1, 0.05 },
  tabActive = { 1, 1, 1, 0.08 },
  disabled = { 0.450, 0.450, 0.450, 1.0 },
  -- Alpha applied to disabled option rows / controls (not the watermark scrim).
  disabledAlpha = 0.5,
  -- Watermark over relinquished blocks (e.g. DynamicCam): slate tint, readable but clearly inactive.
  watermarkScrim = { 0.06, 0.07, 0.08, 0.52 },
}
UI.Colors.accentMarkup =
  RgbToCffMarkup(UI.Colors.accent[1], UI.Colors.accent[2], UI.Colors.accent[3])

--- Live |cff… prefix for the theme accent (filter highlights, changelog headings, etc.).
function UI.AccentMarkup()
  return UI.Colors.accentMarkup
end

--- Wraps text in the theme accent |cff…|r markup.
function UI.AccentWrap(text)
  return UI.Colors.accentMarkup .. (text or "") .. "|r"
end

-- Chat-slash hint blue (same as Esc → Options → AddOns bridge hints).
UI.Colors.slashMarkup = "|cff69ccf0"

--- Wraps a slash command (or any text) in the shared chat-hint blue |cff…|r markup.
function UI.SlashWrap(text)
  return UI.Colors.slashMarkup .. (text or "") .. "|r"
end

-- Toggle-track green / dim grey for ON·OFF state chips in labels and descriptions.
UI.Colors.onMarkup =
  RgbToCffMarkup(UI.Colors.toggleOn[1], UI.Colors.toggleOn[2], UI.Colors.toggleOn[3])
UI.Colors.offMarkup =
  RgbToCffMarkup(UI.Colors.textDim[1], UI.Colors.textDim[2], UI.Colors.textDim[3])

--- Wraps ON/OFF (or custom text) in green (on) or dim grey (off) |cff…|r markup.
function UI.OnOffWrap(isOn, text)
  local mark = isOn and UI.Colors.onMarkup or UI.Colors.offMarkup
  return mark .. (text or (isOn and "ON" or "OFF")) .. "|r"
end

-- Fixed type scale: `base` for option rows, `nav` for the left sidebar tabs,
-- `header` for section titles, `desc` for muted under-option helpers.
UI.Fonts = {
  base = 10,
  nav = 12,
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
-- the four corners rounded by a circular alpha mask.
--
-- Each surface is a 9-slice: 4 masked corner quads + 4 solid edges + 1 solid center.
-- Textures are parented to `textureParent` (draw order / layers) and sized against
-- `bounds` (may be the same frame, or a pad frame that extends past it).
-- Returns { SetColor, Show, Hide } so callers can recolor or toggle visibility.
local function Build9Slice(textureParent, bounds, radius, layer, color, inset)
  bounds = bounds or textureParent
  inset = inset or 0
  local r, g, b, a = color[1], color[2], color[3], color[4] or 1
  local pieces = {}

  local function solid(...)
    local tex = textureParent:CreateTexture(nil, layer)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetPoint(...)
    pieces[#pieces + 1] = tex
    return tex
  end

  -- Center + 4 edges (solid rectangles, no rounding).
  local c = solid("TOPLEFT", bounds, "TOPLEFT", inset + radius, -(inset + radius))
  c:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -(inset + radius), inset + radius)

  local topEdge = solid("TOPLEFT", bounds, "TOPLEFT", inset + radius, -inset)
  topEdge:SetPoint("TOPRIGHT", bounds, "TOPRIGHT", -(inset + radius), -inset)
  topEdge:SetHeight(radius)

  local bottomEdge = solid("BOTTOMLEFT", bounds, "BOTTOMLEFT", inset + radius, inset)
  bottomEdge:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -(inset + radius), inset)
  bottomEdge:SetHeight(radius)

  local leftEdge = solid("TOPLEFT", bounds, "TOPLEFT", inset, -(inset + radius))
  leftEdge:SetPoint("BOTTOMLEFT", bounds, "BOTTOMLEFT", inset, inset + radius)
  leftEdge:SetWidth(radius)

  local rightEdge = solid("TOPRIGHT", bounds, "TOPRIGHT", -inset, -(inset + radius))
  rightEdge:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset + radius)
  rightEdge:SetWidth(radius)

  -- 4 rounded corners: R×R quad showing one quadrant of a 2R circular mask.
  local function corner(point, xoff, yoff)
    local tex = textureParent:CreateTexture(nil, layer)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetSize(radius, radius)
    tex:SetPoint(point, bounds, point, xoff, yoff)
    local mask = textureParent:CreateMaskTexture()
    mask:SetTexture(CORNER_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetSize(radius * 2, radius * 2)
    mask:SetPoint(point, bounds, point, xoff, yoff)
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
    Show = function()
      for _, tex in ipairs(pieces) do
        tex:Show()
      end
    end,
    Hide = function()
      for _, tex in ipairs(pieces) do
        tex:Hide()
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
--- Fully transparent border (`a == 0`) uses fill inset 0 (full-bleed) unless `fillInset`
--- is passed explicitly (scroll thumbs keep inset 1 so they stay visually thin).
function UI.StyleRounded(frame, fill, border, radius, fillInset)
  radius = radius or UI.Radius.card
  fill = fill or UI.Colors.cardBg
  border = border or UI.Colors.cardBorder

  if fillInset == nil then
    local borderA = border[4] or 1
    fillInset = borderA > 0 and 1 or 0
  end

  local borderSlice = Build9Slice(frame, frame, radius, "BACKGROUND", border, 0)
  local fillSlice = Build9Slice(frame, frame, radius, "BORDER", fill, fillInset)

  frame.cmSetFill = function(_, r, g, b, a)
    fillSlice.SetColor(r, g, b, a)
  end
  frame.cmSetBorder = function(_, r, g, b, a)
    borderSlice.SetColor(r, g, b, a)
  end
  return frame
end

--- Rounded BACKGROUND hover wash for option rows. Textures are parented to `frame` (so
--- they sit under OVERLAY labels) and sized to `bounds` (a pad frame that may extend
--- past the row). Returns { Show, Hide }.
function UI.CreateRoundedHover(frame, bounds, color, radius)
  local slice = Build9Slice(
    frame,
    bounds,
    radius or UI.Radius.control,
    "BACKGROUND",
    color or UI.Colors.tabHover,
    0
  )
  slice.Hide()
  return slice
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
--- flat button in the theme accent yellow. Closes its parent by default; override OnClick
--- for custom behavior. Caller positions it.
function UI.CreateCloseButton(parent)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(22, 22)
  -- Sit above the title bar drag handle, which overlaps this corner; otherwise the drag
  -- frame swallows clicks and only the sliver past the title bar edge stays clickable.
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  UI.StyleRounded(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

  local a = UI.Colors.accent
  local x = UI.CreateFontString(btn, "OVERLAY", 14, "GameFontNormalLarge")
  x:SetPoint("CENTER", btn, "CENTER", 0, 0)
  x:SetText("\195\151") -- multiplication sign (crisp X glyph)
  x:SetTextColor(a[1], a[2], a[3])

  btn:SetScript("OnEnter", function(self)
    self:cmSetFill(1, 1, 1, 0.10)
    -- Slightly lift the muted accent toward white on hover.
    x:SetTextColor(a[1] + (1 - a[1]) * 0.35, a[2] + (1 - a[2]) * 0.35, a[3] + (1 - a[3]) * 0.35)
  end)
  btn:SetScript("OnLeave", function(self)
    self:cmSetFill(0, 0, 0, 0)
    x:SetTextColor(a[1], a[2], a[3])
  end)
  btn:SetScript("OnClick", function()
    parent:Hide()
  end)
  return btn
end

--- Frameless icon button that shows a copy-link popup (LaunchURL / CopyToClipboard are
--- protected from addons). Caller positions it. Same frame level as CreateCloseButton.
--- `label` is a short name in the popup (e.g. "Discord", "GitHub").
function UI.CreateIconLinkButton(parent, texturePath, url, tooltip, label)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(18, 18)
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(btn)
  icon:SetTexture(texturePath)
  icon:SetAlpha(0.8)

  btn:SetScript("OnEnter", function()
    icon:SetAlpha(1)
  end)
  btn:SetScript("OnLeave", function()
    icon:SetAlpha(0.8)
  end)
  btn:SetScript("OnClick", function()
    if type(url) ~= "string" or url == "" then
      return
    end
    if UI.ShowCopyLink then
      UI.ShowCopyLink(url, label)
    end
  end)

  if tooltip then
    UI.AttachTooltip(btn, tooltip, "ANCHOR_BOTTOM")
  end
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

--- Sizes an EditBox to the options type scale (defaults to UI.Fonts.base). ChatFontNormal
--- is larger than option-row text; use this for every config / editor input field.
function UI.SetEditBoxFont(edit, pixelSize, template)
  if not edit or not edit.SetFont then
    return edit
  end
  local fontObj = _G[template or "GameFontHighlightSmall"] or _G.GameFontHighlightSmall
  local path, _, flags = fontObj:GetFont()
  if path then
    edit:SetFont(path, pixelSize or UI.Fonts.base, flags or "")
  else
    edit:SetFontObject(fontObj)
  end
  return edit
end

---------------------------------------------------------------------------------------
--                                    BEHAVIORS                                      --
---------------------------------------------------------------------------------------
-- Themed config tooltip (CombatModeUITooltip). Replaces GameTooltip for options chrome
-- so tips match card surfaces and are not suppressed by gameplay hideTooltip.
local tipFrame
local tipTitle
local tipBody
local tipLinePool = {} -- { label = FontString, value = FontString }

local TIP_PAD_X = 12
local TIP_PAD_Y = 10
local TIP_GAP = 4
local TIP_SIMPLE_W = 240
local TIP_RICH_W = 300
local TIP_OWNER_GAP = 8

local function ResolveTooltipContent(content)
  if type(content) == "function" then
    content = content()
  end
  if type(content) == "string" then
    if content == "" then
      return nil
    end
    return { text = content }
  end
  if type(content) == "table" then
    return content
  end
  return nil
end

local function EnsureTipLine(index)
  local line = tipLinePool[index]
  if line then
    return line
  end
  local label = UI.CreateFontString(tipFrame, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  local value = UI.CreateFontString(tipFrame, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  value:SetJustifyH("LEFT")
  value:SetJustifyV("TOP")
  value:SetWordWrap(true)
  if value.SetNonSpaceWrap then
    value:SetNonSpaceWrap(true)
  end
  line = { label = label, value = value }
  tipLinePool[index] = line
  return line
end

local function EnsureTooltipFrame()
  if tipFrame then
    return tipFrame
  end

  tipFrame = CreateFrame("Frame", "CombatModeUITooltip", UIParent)
  tipFrame:SetFrameStrata("TOOLTIP")
  tipFrame:SetFrameLevel(10000)
  tipFrame:SetClampedToScreen(true)
  tipFrame:EnableMouse(false)
  tipFrame:Hide()
  UI.StyleRounded(tipFrame, UI.Colors.cardBg, UI.Colors.cardBorder, UI.Radius.card)

  tipTitle = UI.CreateFontString(tipFrame, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  tipTitle:SetJustifyH("LEFT")
  tipTitle:SetWordWrap(true)
  tipTitle:SetTextColor(UI.Colors.accent[1], UI.Colors.accent[2], UI.Colors.accent[3], 1)

  tipBody = UI.CreateFontString(tipFrame, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  tipBody:SetJustifyH("LEFT")
  tipBody:SetWordWrap(true)
  tipBody:SetTextColor(UI.Colors.text[1], UI.Colors.text[2], UI.Colors.text[3], 1)

  return tipFrame
end

local function PositionTooltip(owner, anchor)
  tipFrame:ClearAllPoints()
  if not owner then
    tipFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    return
  end
  if anchor == "ANCHOR_TOPLEFT" then
    tipFrame:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, TIP_OWNER_GAP)
  elseif anchor == "ANCHOR_LEFT" then
    tipFrame:SetPoint("RIGHT", owner, "LEFT", -TIP_OWNER_GAP, 0)
  else
    -- ANCHOR_RIGHT (default)
    tipFrame:SetPoint("LEFT", owner, "RIGHT", TIP_OWNER_GAP, 0)
  end
end

--- Shows the themed config tooltip beside `owner`.
--- `content` is a string, a table `{ title?, text?, lines? }`, or a function returning either.
--- `lines` entries are `{ label, value, kind? }` (`kind = "warn"` uses warning color).
function UI.ShowTooltip(owner, content, anchor)
  content = ResolveTooltipContent(content)
  if not content then
    UI.HideTooltip()
    return
  end

  EnsureTooltipFrame()

  local title = nil
  if content.title then
    title = tostring(content.title)
    if title == "" then
      title = nil
    end
  end
  local body = nil
  if content.text then
    body = tostring(content.text)
    if body == "" then
      body = nil
    end
  end

  local lines = content.lines
  local hasLines = type(lines) == "table" and #lines > 0
  local rich = title ~= nil or hasLines
  local maxW = rich and TIP_RICH_W or TIP_SIMPLE_W
  local textW = maxW - TIP_PAD_X * 2

  for _, line in ipairs(tipLinePool) do
    line.label:Hide()
    line.value:Hide()
  end

  local y = TIP_PAD_Y
  local contentW = 0

  if title then
    tipTitle:ClearAllPoints()
    tipTitle:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X, -y)
    tipTitle:SetWidth(textW)
    tipTitle:SetText(UI.StripColors(title) or title)
    tipTitle:Show()
    local th = tipTitle:GetStringHeight()
    if th < 1 then
      th = UI.Fonts.base + 2
    end
    contentW = max(contentW, min(tipTitle:GetStringWidth(), textW))
    y = y + th + TIP_GAP
  else
    tipTitle:Hide()
    tipTitle:SetText("")
  end

  if body then
    tipBody:ClearAllPoints()
    tipBody:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X, -y)
    tipBody:SetWidth(textW)
    tipBody:SetText(UI.StripColors(body) or body)
    tipBody:Show()
    local bh = tipBody:GetStringHeight()
    if bh < 1 then
      bh = UI.Fonts.desc + 2
    end
    contentW = max(contentW, min(tipBody:GetStringWidth(), textW))
    if tipBody.GetWrappedWidth then
      contentW = max(contentW, min(tipBody:GetWrappedWidth(), textW))
    end
    y = y + bh + (hasLines and TIP_GAP + 2 or 0)
  else
    tipBody:Hide()
    tipBody:SetText("")
  end

  if hasLines then
    local lineIndex = 0
    for _, entry in ipairs(lines) do
      if type(entry) == "table" and (entry.label or entry.value) then
        lineIndex = lineIndex + 1
        local line = EnsureTipLine(lineIndex)
        local labelText = entry.label and tostring(entry.label) or ""
        local valueText = entry.value ~= nil and tostring(entry.value) or ""
        local warn = entry.kind == "warn"
        local dim = UI.Colors.textDim
        local valColor = warn and UI.Colors.warning or UI.Colors.text

        line.label:ClearAllPoints()
        line.label:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X, -y)
        line.label:SetText(UI.StripColors(labelText) or labelText)
        line.label:SetTextColor(dim[1], dim[2], dim[3], 1)
        line.label:Show()

        local labelW = line.label:GetStringWidth()
        local valueW = max(48, textW - labelW - 6)
        line.value:ClearAllPoints()
        line.value:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X + labelW + 6, -y)
        line.value:SetWidth(valueW)
        line.value:SetText(UI.StripColors(valueText) or valueText)
        line.value:SetTextColor(valColor[1], valColor[2], valColor[3], 1)
        line.value:Show()

        local valueH = line.value:GetStringHeight()
        if valueH < 1 then
          valueH = UI.Fonts.desc + 2
        end
        local labelH = max(line.label:GetStringHeight(), UI.Fonts.desc + 2)
        y = y + max(labelH, valueH) + 2
      end
    end
  end

  -- Rich tips keep a fixed max width for wrapping. Simple text tips hug content.
  local width
  if title or hasLines then
    width = maxW
  else
    width = max(min(contentW + TIP_PAD_X * 2, TIP_SIMPLE_W), 80)
    if body then
      tipBody:SetWidth(width - TIP_PAD_X * 2)
      local bh = tipBody:GetStringHeight()
      if bh < 1 then
        bh = UI.Fonts.desc + 2
      end
      y = TIP_PAD_Y + bh
    end
  end
  local height = y + TIP_PAD_Y - (hasLines and 2 or 0)
  tipFrame:SetSize(width, max(height, TIP_PAD_Y * 2 + UI.Fonts.desc))
  PositionTooltip(owner, anchor or "ANCHOR_RIGHT")
  tipFrame:Show()
end

--- Hides the themed config tooltip if shown.
function UI.HideTooltip()
  if tipFrame then
    tipFrame:Hide()
  end
end

--- Tooltip on hover. `content` is a string, content table, or function returning either.
function UI.AttachTooltip(widget, content, anchor)
  if not content then
    return
  end
  widget:HookScript("OnEnter", function(self)
    UI.ShowTooltip(self, content, anchor or "ANCHOR_RIGHT")
  end)
  widget:HookScript("OnLeave", function()
    UI.HideTooltip()
  end)
end

--- Registers a named frame so pressing ESC closes it (standard Blizzard pattern).
function UI.EnableEscClose(frame, globalName)
  _G[globalName] = frame
  tinsert(_G.UISpecialFrames, globalName)
end

--- Makes `frame` draggable by `handle`. When `persist` is true the anchor is saved to
--- CM.DB.global.optionsPanelPosition (optional; the main options window docks left-of-center on
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
  UI.StyleRounded(bar, { 1, 1, 1, 0.05 }, { 0, 0, 0, 0 }, thickness / 2, 1)

  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(thickness)
  thumb:SetHeight(40)
  thumb:SetPoint("TOP", bar, "TOP", 0, 0)
  local a = UI.Colors.accent
  -- Explicit fill inset keeps the painted thumb thinner than the hit/track width.
  UI.StyleRounded(thumb, { a[1], a[2], a[3], 1 }, { 0, 0, 0, 0 }, thickness / 2, 1)
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

function UI.CreateScrollFrame(parent, thickness)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  thickness = thickness or 6
  local bar, thumb = StyleThumbBar(parent, thickness)
  WireThumbScroll(scroll, bar, thumb)

  scroll.cmScrollBar = bar
  bar.cmThumb = thumb
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
  local s = UI.Colors.watermarkScrim or UI.Colors.windowBg
  scrim:SetColorTexture(s[1], s[2], s[3], s[4] or 0.42)

  local stamp =
    UI.CreateFontString(overlay, "OVERLAY", fontSize or UI.Fonts.header, "GameFontNormalLarge")
  stamp:SetPoint("CENTER", overlay, "CENTER", 0, 0)
  stamp:SetJustifyH("CENTER")
  stamp:SetText(UI.StripColors(text) or "")
  local a = UI.Colors.accent
  stamp:SetTextColor(a[1], a[2], a[3])
  stamp:SetShadowColor(0, 0, 0, 1)
  stamp:SetShadowOffset(1, -1)

  overlay.stamp = stamp
  overlay:Hide()
  return overlay
end
