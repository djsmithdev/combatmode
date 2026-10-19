---------------------------------------------------------------------------------------
--  UI/Options/Draw.lua — OPTIONS — theme tokens + draw primitives
---------------------------------------------------------------------------------------
--  What it does: Boots `CM.UI` with the options theme (orange accent for headers/selection
--  and toggles on; warm-brown borders on near-black panels), StripColors, surface/card helpers,
--  config tooltips, scroll thumbs, watermark helpers, and
--  BlockBehindTooltips for top-level windows shared by options, changelog, and editors.
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
local CreateColor = _G.CreateColor
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
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

CM.UI = CM.UI or {}
local UI = CM.UI

---------------------------------------------------------------------------------------
--                                     PALETTE                                       --
---------------------------------------------------------------------------------------
-- Warm dark theme: near-black brown panels with a warm-brown border, one orange accent
-- (headers, selected tab, toggles on, input values, badges) and a cream text ramp.
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
  -- Single accent (section headers, selected tab, toggles on, input values, badges).
  accent = { 0.816, 0.541, 0.322 }, -- D08A52 copper

  -- Rule under section headers and window titles (fades out to the right): a quiet accent.
  headerRule = { 0.816, 0.541, 0.322, 0.4 },

  -- Gradient ends for accent-filled shapes (tab marker, slider fill, scroll thumb): a lighter
  -- copper on top fading to a deeper bronze below. Text can only take the flat accent.
  accentTop = { 0.925, 0.706, 0.490, 1.0 }, -- #ECB47D
  accentBottom = { 0.690, 0.420, 0.220, 1.0 }, -- #B06B38

  -- Cream text ramp.
  white = { 1.000, 1.000, 1.000 },
  text = { 0.945, 0.902, 0.827 }, -- F1E6D3: titles, labels, tabs, header icons
  textDim = { 0.612, 0.588, 0.549 }, -- #9C968C: muted grey for descriptions / secondary
  grey = { 0.612, 0.588, 0.549 },
  -- Caution / destructive callouts (Advanced editor warning, etc.).
  warning = { 0.820, 0.350, 0.350 },
  -- Done / available (wizard check marks, "open" labels). toggleOn is the copper accent, not green.
  success = { 0.380, 0.760, 0.440 },

  -- Toggle track fill when on: the accent. Off uses trackOff.
  toggleOn = { 0.816, 0.541, 0.322, 1.0 },

  -- Window chrome: three tones sampled from the mockup. windowBg is the page (content)
  -- area, headerBg the top band, sidebarBg the left panel.
  windowBg = { 0.078, 0.067, 0.055, 1.0 }, -- #14110E content
  headerBg = { 0.086, 0.082, 0.063, 1.0 }, -- #161510
  sidebarBg = { 0.094, 0.082, 0.063, 1.0 }, -- #181510
  -- Gradient pairs (top → bottom). Each pair averages to the flat colour above/nearby, so
  -- the flat token stays the "base" tone and the pair only adds the shading.
  windowBgTop = { 0.086, 0.074, 0.061, 1.0 },
  windowBgBottom = { 0.070, 0.060, 0.049, 1.0 },
  -- Header and sidebar are lighter than the flat tones above: the inner shadow is drawn on top of
  -- them (AddZoneShadow) and darkens them, so they start brighter to land where they used to.
  headerBgTop = { 0.122, 0.113, 0.088, 1.0 },
  headerBgBottom = { 0.102, 0.094, 0.073, 1.0 },
  sidebarBgTop = { 0.131, 0.115, 0.088, 1.0 },
  sidebarBgBottom = { 0.109, 0.096, 0.073, 1.0 },
  -- The one outline gradient for buttons, selects, keybinds, input wells, lists and search.
  controlBorderTop = { 0.360, 0.290, 0.220, 1.0 },
  controlBorderBottom = { 0.220, 0.170, 0.130, 1.0 },
  cardBg = { 0.110, 0.098, 0.082, 1.0 }, -- #1C1915
  -- One surface for every button-like control (buttons, dropdowns, keybinds, chips):
  -- dark fill, cardBorder outline, buttonHover while hovered.
  controlFill = { 0.110, 0.095, 0.082, 1.0 }, -- #1C1815 gradient bottom
  controlFillTop = { 0.170, 0.148, 0.126, 1.0 }, -- #2B2520 gradient top
  buttonHover = { 0.150, 0.130, 0.110, 1.0 },
  buttonHoverTop = { 0.225, 0.196, 0.165, 1.0 },
  -- Warm-brown border for cards, chips, toggles (off) and neutral buttons.
  cardBorder = { 0.290, 0.230, 0.170, 1.0 }, -- #4A3B2B
  -- Hairlines (header rule, sidebar divider, footer separator).
  divider = { 0.230, 0.190, 0.150, 1.0 }, -- #3B3026
  rowWash = { 1, 1, 1, 0.02 },
  trackOff = { 0.140, 0.125, 0.110, 1.0 }, -- toggle track, gradient bottom
  trackOffTop = { 0.265, 0.240, 0.213, 1.0 }, -- toggle track, gradient top
  -- Scroll bar track (same tone as the slider track so they read as one family).
  scrollTrack = { 0.227, 0.196, 0.161, 1.0 }, -- #3A3229
  -- Unfilled part of a slider track (lighter than trackOff so it reads against the page).
  sliderTrack = { 0.227, 0.196, 0.161, 1.0 }, -- #3A3229
  -- Input wells (text fields, editor filters): darkest surface.
  inputBg = { 0.055, 0.047, 0.040, 1.0 }, -- #0E0C0A
  -- Strips inside an input well (code box line numbers / status line): a notch lighter than inputBg.
  inputStrip = { 0.090, 0.077, 0.066, 1.0 }, -- #171310
  -- The code box's error line: a dark red strip with softer red text on it.
  errorStrip = { 0.200, 0.075, 0.070, 1.0 }, -- #331312
  errorStripText = { 0.980, 0.640, 0.600 }, -- #FAA399
  -- Hover / highlight (rows, tabs, menu items): a copper glow. A dark copper-tinted fill, a touch
  -- see-through so the panel art shows, with a copper outline that is brighter at the top.
  hoverFill = { 0.160, 0.118, 0.080, 0.32 },
  hoverFillTop = { 0.185, 0.135, 0.090, 0.32 },
  hoverFillBottom = { 0.140, 0.102, 0.068, 0.32 },
  hoverBorderTop = { 0.340, 0.235, 0.145, 0.6 },
  hoverBorderBottom = { 0.220, 0.150, 0.092, 0.6 },
  -- Selected sidebar tab: solid warm brown behind the orange label and bar.
  tabActive = { 0.140, 0.112, 0.088, 1.0 }, -- gradient bottom
  tabActiveTop = { 0.200, 0.160, 0.124, 1.0 }, -- gradient top
  tabActiveBorder = { 0.255, 0.205, 0.158, 1.0 },
  disabled = { 0.450, 0.420, 0.390, 1.0 },
  -- Alpha applied to disabled option rows / controls (not the watermark scrim).
  disabledAlpha = 0.5,
  -- Whole-page watermark scrim only (rows use UI.CreateRowStamp, which has no scrim).
  watermarkScrim = { 0.078, 0.067, 0.055, 0.7 },
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
-- RGB of the slashMarkup tint, for text that cannot carry colour markup (dropdown values).
UI.Colors.slash = { 0x69 / 255, 0xcc / 255, 0xf0 / 255 }
UI.Colors.slashMarkup = "|cff69ccf0"

--- Wraps a slash command (or any text) in the shared chat-hint blue |cff…|r markup.
function UI.SlashWrap(text)
  return UI.Colors.slashMarkup .. (text or "") .. "|r"
end

-- Toggle-track green / dim grey for ON·OFF state chips in labels and descriptions.
UI.Colors.onMarkup =
  RgbToCffMarkup(UI.Colors.toggleOn[1], UI.Colors.toggleOn[2], UI.Colors.toggleOn[3])
UI.Colors.successMarkup =
  RgbToCffMarkup(UI.Colors.success[1], UI.Colors.success[2], UI.Colors.success[3])
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
  base = 13,
  nav = 13,
  header = 17,
  desc = 10,
  -- Text directly under a section header (ctx:Description), one step above option descs.
  sectionDesc = 11,
  -- Text boxes (code, lists, search).
  input = 11,
  -- Label inside every button-like control (buttons, dropdowns, keybinds).
  button = 11,
  -- Sidebar footer toggles (Silence Alerts / Debug Mode) read smaller than page options.
  small = 11,
}

-- Shared control metrics: every button-like control (buttons, dropdowns, keybinds) is this
-- tall, so rows line up and the sidebar footer matches the page.
UI.Sizes = {
  control = 32,
  -- Search / filter boxes (header search, dropdown filter, editor filters).
  search = 32,
  -- Every scroll bar (page, menus, editors, text areas): track and thumb share this width.
  scrollbar = 5,
}

-- Corner radii.
UI.Radius = {
  -- Windows are square: the metal frame (UI.AddMetalBorder) has square inner corners.
  window = 0,
  card = 6,
  control = 6,
  -- Buttons and button-like controls.
  button = 8,
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
local function Build9Slice(textureParent, bounds, radius, layer, color, inset, corners, subLevel)
  bounds = bounds or textureParent
  inset = inset or 0
  local r, g, b, a = color[1], color[2], color[3], color[4] or 1
  local pieces = {}
  -- Pieces by vertical band so a vertical gradient stays continuous across the corners:
  -- top row and bottom row are flat end colours, the middle band carries the gradient.
  local roles = { top = {}, mid = {}, bottom = {} }
  -- Same pieces by horizontal band (left cap, middle, right cap) for horizontal gradients.
  local hroles = { left = {}, mid = {}, right = {} }
  local hasGradient = false

  local function solid(role, ...)
    local tex = textureParent:CreateTexture(nil, layer, nil, subLevel or 0)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetPoint(...)
    pieces[#pieces + 1] = tex
    roles[role][#roles[role] + 1] = tex
    hroles.mid[#hroles.mid + 1] = tex
    return tex
  end

  -- Moves a piece from the middle column into the left or right cap.
  local function hband(tex, name)
    for i, t in ipairs(hroles.mid) do
      if t == tex then
        table.remove(hroles.mid, i)
        break
      end
    end
    hroles[name][#hroles[name] + 1] = tex
  end

  local function slice()
    return {
      SetColor = function(nr, ng, nb, na)
        local flat = hasGradient and CreateColor(nr, ng, nb, na or 1) or nil
        for _, tex in ipairs(pieces) do
          tex:SetVertexColor(nr, ng, nb, na or 1)
          -- A texture keeps its gradient until it is overwritten with a flat one.
          if flat then
            tex:SetGradient("VERTICAL", flat, flat)
          end
        end
      end,
      --- Vertical gradient from the top colour to the bottom colour ({ r, g, b, a } each).
      --- The slice is cut into three bands (top row, middle, bottom row); each band takes
      --- its own part of the one overall gradient, so it stays continuous across rounded
      --- corners and also works when the radius is half the height (a pill, no middle band).
      --- With `horizontal`, the colours run left → right instead (same band logic by column).
      SetGradient = function(top, bottom, horizontal)
        hasGradient = true
        if horizontal then
          local width = (bounds:GetWidth() or 0) - inset * 2
          local hf = (width > 0) and min(radius / width, 0.5) or 0
          local function hat(t)
            return CreateColor(
              top[1] + (bottom[1] - top[1]) * t,
              top[2] + (bottom[2] - top[2]) * t,
              top[3] + (bottom[3] - top[3]) * t,
              (top[4] or 1) + ((bottom[4] or 1) - (top[4] or 1)) * t
            )
          end
          local h0, h1, h2, h3 = hat(0), hat(hf), hat(1 - hf), hat(1)
          for _, tex in ipairs(hroles.left) do
            tex:SetGradient("HORIZONTAL", h0, h1)
          end
          for _, tex in ipairs(hroles.mid) do
            tex:SetGradient("HORIZONTAL", h1, h2)
          end
          for _, tex in ipairs(hroles.right) do
            tex:SetGradient("HORIZONTAL", h2, h3)
          end
          return
        end
        local height = (bounds:GetHeight() or 0) - inset * 2
        local f = (height > 0) and min(radius / height, 0.5) or 0
        local function at(t)
          return CreateColor(
            top[1] + (bottom[1] - top[1]) * t,
            top[2] + (bottom[2] - top[2]) * t,
            top[3] + (bottom[3] - top[3]) * t,
            (top[4] or 1) + ((bottom[4] or 1) - (top[4] or 1)) * t
          )
        end
        local c0, c1, c2, c3 = at(0), at(f), at(1 - f), at(1)
        -- Vertical gradients take the minimum colour at the bottom edge of each piece.
        for _, tex in ipairs(roles.top) do
          tex:SetGradient("VERTICAL", c1, c0)
        end
        for _, tex in ipairs(roles.mid) do
          tex:SetGradient("VERTICAL", c2, c1)
        end
        for _, tex in ipairs(roles.bottom) do
          tex:SetGradient("VERTICAL", c3, c2)
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

  -- No rounding: a single rectangle.
  if radius <= 0 then
    local rect = solid("mid", "TOPLEFT", bounds, "TOPLEFT", inset, -inset)
    rect:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset)
    return slice()
  end

  -- Center + 4 edges (solid rectangles, no rounding).
  local c = solid("mid", "TOPLEFT", bounds, "TOPLEFT", inset + radius, -(inset + radius))
  c:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -(inset + radius), inset + radius)

  local topEdge = solid("top", "TOPLEFT", bounds, "TOPLEFT", inset + radius, -inset)
  topEdge:SetPoint("TOPRIGHT", bounds, "TOPRIGHT", -(inset + radius), -inset)
  topEdge:SetHeight(radius)

  local bottomEdge = solid("bottom", "BOTTOMLEFT", bounds, "BOTTOMLEFT", inset + radius, inset)
  bottomEdge:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -(inset + radius), inset)
  bottomEdge:SetHeight(radius)

  local leftEdge = solid("mid", "TOPLEFT", bounds, "TOPLEFT", inset, -(inset + radius))
  hband(leftEdge, "left")
  leftEdge:SetPoint("BOTTOMLEFT", bounds, "BOTTOMLEFT", inset, inset + radius)
  leftEdge:SetWidth(radius)

  local rightEdge = solid("mid", "TOPRIGHT", bounds, "TOPRIGHT", -inset, -(inset + radius))
  hband(rightEdge, "right")
  rightEdge:SetPoint("BOTTOMRIGHT", bounds, "BOTTOMRIGHT", -inset, inset + radius)
  rightEdge:SetWidth(radius)

  -- Corners: an R×R quad showing one quadrant of a circular mask. The smooth scalable
  -- mask's disc is smaller than its texture, so the mask is enlarged (and re-centred on
  -- the corner circle) until the visible disc has radius R. `corners[point] == false`
  -- leaves that corner square (zone fills that meet a rounded outer frame use this).
  local function corner(point, xoff, yoff)
    local tex = textureParent:CreateTexture(nil, layer, nil, subLevel or 0)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetVertexColor(r, g, b, a)
    tex:SetSize(radius, radius)
    tex:SetPoint(point, bounds, point, xoff, yoff)
    pieces[#pieces + 1] = tex
    local band = (point == "TOPLEFT" or point == "TOPRIGHT") and roles.top or roles.bottom
    band[#band + 1] = tex
    hroles[(point == "TOPLEFT" or point == "BOTTOMLEFT") and "left" or "right"][#hroles[(point == "TOPLEFT" or point == "BOTTOMLEFT") and "left" or "right"] + 1] =
      tex
    if corners and corners[point] == false then
      return
    end
    local mask = textureParent:CreateMaskTexture()
    local frac = UI.SetCircleMask(mask) or 1
    local size = radius * 2 / frac
    local grow = size / 2 - radius
    local sx = (point == "TOPLEFT" or point == "BOTTOMLEFT") and -1 or 1
    local sy = (point == "TOPLEFT" or point == "TOPRIGHT") and 1 or -1
    mask:SetSize(size, size)
    mask:SetPoint(point, bounds, point, xoff + sx * grow, yoff + sy * grow)
    tex:AddMaskTexture(mask)
  end
  corner("TOPLEFT", inset, -inset)
  corner("TOPRIGHT", -inset, -inset)
  corner("BOTTOMLEFT", inset, inset)
  corner("BOTTOMRIGHT", -inset, inset)

  return slice()
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

  -- The fill circle shares the border's centre (radius shrinks by the inset) so the
  -- outline keeps an even thickness around the corners.
  local borderSlice = Build9Slice(frame, frame, radius, "BACKGROUND", border, 0)
  local fillSlice = Build9Slice(frame, frame, max(radius - fillInset, 0), "BORDER", fill, fillInset)

  -- Gradients depend on the frame's height (where the corner rows end), which may not be
  -- known yet (a frame is often sized after it is styled) or may change later. The last
  -- gradient is remembered and re-applied whenever the frame is resized; a flat colour
  -- clears it.
  local lastFill, lastBorder
  frame.cmSetFill = function(_, r, g, b, a)
    lastFill = nil
    fillSlice.SetColor(r, g, b, a)
  end
  frame.cmSetBorder = function(_, r, g, b, a)
    lastBorder = nil
    borderSlice.SetColor(r, g, b, a)
  end
  --- Vertical gradient fill: top and bottom are { r, g, b, a } colours.
  frame.cmSetFillGradient = function(_, top, bottom)
    lastFill = { top, bottom }
    fillSlice.SetGradient(top, bottom)
  end
  --- Horizontal gradient fill: left and right are { r, g, b, a } colours.
  frame.cmSetFillGradientH = function(_, left, right)
    lastFill = { left, right, true }
    fillSlice.SetGradient(left, right, true)
  end
  --- Vertical gradient outline: the border shape sits under the fill, so its colour shows
  --- only in the ring around it.
  frame.cmSetBorderGradient = function(_, top, bottom)
    lastBorder = { top, bottom }
    borderSlice.SetGradient(top, bottom)
  end
  frame:HookScript("OnSizeChanged", function()
    if lastFill then
      fillSlice.SetGradient(lastFill[1], lastFill[2], lastFill[3])
    end
    if lastBorder then
      borderSlice.SetGradient(lastBorder[1], lastBorder[2])
    end
  end)
  return frame
end

--- Soft drop shadow around a window, cut from one pre-blurred texture (Assets/ui/shadow.tga: a
--- rounded box with a gaussian falloff, so the fade is perfectly smooth). It lives in a child
--- frame given a LOWER frame level than the window, so it draws behind the window's own fill
--- (a parent's textures otherwise draw under its child frames). The texture's box matches the
--- window's 10px corner radius, and the shadow is shifted down (light from above).
local SHADOW_SIZE = 128 -- texture is 128x128: the box spans 48..80, so the shadow reaches 48px out
local SHADOW_REACH = 48
local SHADOW_CORNER = 64 -- corner piece: reach + half the box
local SHADOW_OFFSET_Y = -6
function UI.AddWindowShadow(frame)
  if frame.cmShadow then
    return frame.cmShadow
  end
  -- The shadow needs levels below the window; lift low windows (children shift with them).
  if frame:GetFrameLevel() < 4 then
    frame:SetFrameLevel(4)
  end
  local shadow = CreateFrame("Frame", nil, frame)
  shadow:EnableMouse(false)
  shadow:SetFrameLevel(max(frame:GetFrameLevel() - 2, 0))
  -- The shadow starts at the metal frame's outer edge (frame.cmMetalOuter, set by
  -- UI.AddMetalBorder, which must run first), so it falls past the metal, not under it.
  local reach = SHADOW_REACH + (frame.cmMetalOuter or 0)
  shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -reach, reach + SHADOW_OFFSET_Y)
  shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", reach, -reach + SHADOW_OFFSET_Y)

  local function piece(l, r, t, b)
    local tex = shadow:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(CM.Constants.Shadow)
    tex:SetTexCoord(l, r, t, b)
    return tex
  end
  local half = 0.5
  local mid1, mid2 = (SHADOW_CORNER - 1) / SHADOW_SIZE, (SHADOW_CORNER + 1) / SHADOW_SIZE
  local tl = piece(0, half, 0, half)
  local tr = piece(half, 1, 0, half)
  local bl = piece(0, half, half, 1)
  local br = piece(half, 1, half, 1)
  for _, corner in ipairs({ tl, tr, bl, br }) do
    corner:SetSize(SHADOW_CORNER, SHADOW_CORNER)
  end
  tl:SetPoint("TOPLEFT", shadow, "TOPLEFT", 0, 0)
  tr:SetPoint("TOPRIGHT", shadow, "TOPRIGHT", 0, 0)
  bl:SetPoint("BOTTOMLEFT", shadow, "BOTTOMLEFT", 0, 0)
  br:SetPoint("BOTTOMRIGHT", shadow, "BOTTOMRIGHT", 0, 0)

  -- Edges stretch a two-pixel-wide strip from the straight part of the box.
  local top = piece(mid1, mid2, 0, half)
  top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
  top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT", 0, 0)
  local bottom = piece(mid1, mid2, half, 1)
  bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
  local left = piece(0, half, mid1, mid2)
  left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
  left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT", 0, 0)
  local right = piece(half, 1, mid1, mid2)
  right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)

  frame.cmShadow = shadow
  return shadow
end

--- Window background layer: a Blizzard atlas stretched over the window interior with the same
--- rounded corners as the window fill. Drawn as a 9-slice (centre, four edges, four masked
--- corner quads) whose texture coordinates are recomputed from the window size, so the art
--- is stretched once across the whole window and the corners follow the rounded outline.
--- It sits above the window fill and below every child frame (zones, content).
local WINDOW_ART_ATLAS = "evergreen-weeklyrewards-frame-back"
-- Inner shadow over the whole window (dark toward the edges), same stretch and rounding.
local WINDOW_INNER_SHADOW_ATLAS = "evergreen-weeklyrewards-frame-back-shadow"
local function AddWindowArt(frame, atlas, radius, inset, subLevel)
  local info = CM.GetAtlasInfo(atlas)
  local file = info and (info.file or info.filename)
  if not file then
    return
  end
  local left, right = info.leftTexCoord, info.rightTexCoord
  local top, bottom = info.topTexCoord, info.bottomTexCoord
  if radius <= 0 then
    -- Square window: one texture over the whole interior, no corner slicing needed.
    local tex = frame:CreateTexture(nil, "ARTWORK", nil, subLevel or 0)
    tex:SetTexture(file)
    tex:SetTexCoord(left, right, top, bottom)
    tex:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    return
  end
  local pieces = {}
  local function piece(x1, y1, x2, y2)
    -- x1..x2 / y1..y2 are the piece rectangle in window pixels, measured from the top-left.
    local tex = frame:CreateTexture(nil, "ARTWORK", nil, subLevel or 0)
    tex:SetTexture(file)
    pieces[#pieces + 1] = { tex = tex, x1 = x1, y1 = y1, x2 = x2, y2 = y2 }
    return tex
  end
  -- Fractions of the window (0..1) are resolved in refresh(); radius/inset are pixels.
  local c = piece("r", "r", "-r", "-r")
  c:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + radius, -(inset + radius))
  c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + radius), inset + radius)
  local t1 = piece("r", 0, "-r", "r")
  t1:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + radius, -inset)
  t1:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + radius), -inset)
  t1:SetHeight(radius)
  local b1 = piece("r", "-r", "-r", 0)
  b1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + radius, inset)
  b1:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + radius), inset)
  b1:SetHeight(radius)
  local l1 = piece(0, "r", "r", "-r")
  l1:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -(inset + radius))
  l1:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + radius)
  l1:SetWidth(radius)
  local r1 = piece("-r", "r", 0, "-r")
  r1:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -(inset + radius))
  r1:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + radius)
  r1:SetWidth(radius)

  -- Corner quads show one quadrant of a circular mask (same technique as Build9Slice).
  local function corner(point, x1, y1, x2, y2, xoff, yoff)
    local tex = piece(x1, y1, x2, y2)
    tex:SetSize(radius, radius)
    tex:SetPoint(point, frame, point, xoff, yoff)
    local mask = frame:CreateMaskTexture()
    local frac = UI.SetCircleMask(mask) or 1
    local size = radius * 2 / frac
    local grow = size / 2 - radius
    local sx = (point == "TOPLEFT" or point == "BOTTOMLEFT") and -1 or 1
    local sy = (point == "TOPLEFT" or point == "TOPRIGHT") and 1 or -1
    mask:SetSize(size, size)
    mask:SetPoint(point, frame, point, xoff + sx * grow, yoff + sy * grow)
    tex:AddMaskTexture(mask)
  end
  corner("TOPLEFT", 0, 0, "r", "r", inset, -inset)
  corner("TOPRIGHT", "-r", 0, 0, "r", -inset, -inset)
  corner("BOTTOMLEFT", 0, "-r", "r", 0, inset, inset)
  corner("BOTTOMRIGHT", "-r", "-r", 0, 0, -inset, inset)

  -- Resolve a coordinate spec: number = pixels from the start edge, "r" = radius from the
  -- start edge, "-r" = radius back from the end edge, 0 on the far side = the end edge.
  local function resolve(spec, size, isEnd)
    if spec == "r" then
      return inset + radius
    elseif spec == "-r" then
      return size - inset - radius
    elseif spec == 0 then
      return isEnd and (size - inset) or inset
    end
    return spec
  end
  local function refresh()
    local w, h = frame:GetWidth(), frame:GetHeight()
    if not w or not h or w <= 0 or h <= 0 then
      return
    end
    for _, p in ipairs(pieces) do
      local x1 = resolve(p.x1, w, false)
      local x2 = resolve(p.x2, w, true)
      local y1 = resolve(p.y1, h, false)
      local y2 = resolve(p.y2, h, true)
      p.tex:SetTexCoord(
        left + (right - left) * (x1 / w),
        left + (right - left) * (x2 / w),
        top + (bottom - top) * (y1 / h),
        top + (bottom - top) * (y2 / h)
      )
    end
  end
  refresh()
  frame:HookScript("OnSizeChanged", refresh)
end

--- Metal nine-slice border around a window, built from the GenericMetal2 atlases: four fixed-size
--- corners and four tiled edges (a leading underscore in an atlas name means it tiles
--- horizontally, "!" vertically). It lives in a child frame at a high frame level so it draws over
--- the window's own content edges. It sits flush outside the window (inner edge on the window
--- edge) and is the window's only border. If any atlas is missing, no border is drawn.
local METAL = {
  topLeft = "GenericMetal2-NineSlice-CornerTopLeft",
  topRight = "GenericMetal2-NineSlice-CornerTopRight",
  bottomLeft = "GenericMetal2-NineSlice-CornerBottomLeft",
  bottomRight = "GenericMetal2-NineSlice-CornerBottomRight",
  top = "_GenericMetal2-NineSlice-EdgeTop",
  bottom = "_GenericMetal2-NineSlice-EdgeBottom",
  left = "!GenericMetal2-NineSlice-EdgeLeft",
  right = "!GenericMetal2-NineSlice-EdgeRight",
}
local METAL_LEVEL = 120 -- above window content, below the search popup (+150..)
-- The artwork is large; the whole border frame is scaled down (tiling scales with it).
local METAL_SCALE = 0.4
-- The edge atlases carry empty space on their inner side (between the visible metal and the
-- window). This much of it, in screen pixels, is overlapped onto the window so the visible metal
-- sits flush against the window edge.
local METAL_PAD = 16
-- Vertex colour multiplied into the metal artwork so the grey metal reads as copper / bronze.
local METAL_TINT = { 0.95, 0.80, 0.68 }
function UI.AddMetalBorder(frame)
  if frame.cmMetalBorder then
    return frame.cmMetalBorder
  end
  local info = {}
  for key, atlas in pairs(METAL) do
    local atlasInfo = CM.GetAtlasInfo(atlas)
    if not atlasInfo then
      return nil
    end
    info[key] = atlasInfo
  end
  local border = CreateFrame("Frame", nil, frame)
  border:EnableMouse(false)
  border:SetFrameLevel(frame:GetFrameLevel() + METAL_LEVEL)
  border:SetScale(METAL_SCALE)
  border:SetAllPoints(frame)

  -- Flush: the metal sits entirely outside the window, its inner edge on the window edge. Offsets
  -- are the edge thicknesses, in this scaled frame's own units.
  local pad = METAL_PAD / METAL_SCALE
  local edgeL, edgeR = max(info.left.width - pad, 0), max(info.right.width - pad, 0)
  local edgeT, edgeB = max(info.top.height - pad, 0), max(info.bottom.height - pad, 0)
  -- How far the metal reaches past the window on screen (the drop shadow starts out here).
  frame.cmMetalOuter = max(edgeL, edgeR, edgeT, edgeB) * METAL_SCALE

  local function piece(key)
    local tex = border:CreateTexture(nil, "OVERLAY")
    CM.SetAtlas(tex, METAL[key], true)
    tex:SetVertexColor(METAL_TINT[1], METAL_TINT[2], METAL_TINT[3])
    return tex
  end
  local tl, tr, bl, br =
    piece("topLeft"), piece("topRight"), piece("bottomLeft"), piece("bottomRight")
  tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -edgeL, edgeT)
  tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", edgeR, edgeT)
  bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -edgeL, -edgeB)
  br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", edgeR, -edgeB)

  local top = piece("top")
  top:SetHorizTile(true)
  top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0)
  top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
  top:SetHeight(info.top.height)
  local bottom = piece("bottom")
  bottom:SetHorizTile(true)
  bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0)
  bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
  bottom:SetHeight(info.bottom.height)
  local left = piece("left")
  left:SetVertTile(true)
  left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0)
  left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
  left:SetWidth(info.left.width)
  local right = piece("right")
  right:SetVertTile(true)
  right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0)
  right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
  right:SetWidth(info.right.width)

  frame.cmMetalBorder = border
  return border
end

--- The window's inner shadow, continued across a zone (the header band or sidebar). Those zones
--- are separate frames with their own opaque fill, so they hide the window-level shadow behind
--- them; this draws the matching part of the same shadow on the zone itself, as a background
--- texture just above the zone fill (and below the zone's buttons and tabs). It samples the
--- atlas at the zone's position inside `window`, so the shadow reads as one continuous layer
--- across the whole panel.
function UI.AddZoneShadow(zone, window)
  local info = CM.GetAtlasInfo(WINDOW_INNER_SHADOW_ATLAS)
  local file = info and (info.file or info.filename)
  if not file then
    return
  end
  local tex = zone:CreateTexture(nil, "BACKGROUND", nil, -2)
  tex:SetTexture(file)
  tex:SetAllPoints(zone)
  local l, r = info.leftTexCoord, info.rightTexCoord
  local t, b = info.topTexCoord, info.bottomTexCoord
  local function refresh()
    local zl, zt, zr, zb = zone:GetLeft(), zone:GetTop(), zone:GetRight(), zone:GetBottom()
    local wl, wt, wr, wb = window:GetLeft(), window:GetTop(), window:GetRight(), window:GetBottom()
    if not (zl and zt and zr and zb and wl and wt and wr and wb) then
      return
    end
    local w, h = wr - wl, wt - wb
    if w <= 0 or h <= 0 then
      return
    end
    tex:SetTexCoord(
      l + (r - l) * ((zl - wl) / w),
      l + (r - l) * ((zr - wl) / w),
      t + (b - t) * ((wt - zt) / h),
      t + (b - t) * ((wt - zb) / h)
    )
  end
  zone:HookScript("OnSizeChanged", refresh)
  window:HookScript("OnSizeChanged", refresh)
  window:HookScript("OnShow", refresh)
  refresh()
end

--- Window surface (main options window, editors, dialogs): the page fill with a subtle
--- top-to-bottom shade inside a 1px frame drawn with the standard control border. Size the frame
--- before calling so the gradient can be placed correctly.
function UI.StyleWindow(frame)
  local colors = UI.Colors
  -- No border of its own (fully transparent, so the fill is full-bleed): the metal frame is
  -- the window border.
  UI.StyleRounded(frame, colors.windowBg, { 0, 0, 0, 0 }, UI.Radius.window, 0)
  frame:cmSetFillGradient(colors.windowBgTop, colors.windowBgBottom)
  AddWindowArt(frame, WINDOW_ART_ATLAS, UI.Radius.window, 0, 0)
  AddWindowArt(frame, WINDOW_INNER_SHADOW_ATLAS, UI.Radius.window, 0, 1)
  -- Metal first: the drop shadow is placed relative to its outer edge.
  UI.AddMetalBorder(frame)
  UI.AddWindowShadow(frame)
end

--- Background zone (header band, sidebar) drawn as a child frame so it sits above the
--- window fill but below later siblings. `corners` = { TOPLEFT = true, ... } picks which
--- corners are rounded by `radius`; the rest stay square. Caller anchors/sizes the frame.
function UI.CreateZone(parent, color, radius, corners)
  local zone = CreateFrame("Frame", nil, parent)
  zone:EnableMouse(false)
  local rounded = {}
  for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    rounded[point] = (corners and corners[point]) and true or false
  end
  local slice = Build9Slice(zone, zone, radius, "BACKGROUND", color, 0, rounded, -3)
  --- Vertical gradient fill (call after the zone has been sized).
  local lastGradient
  zone.cmSetFillGradient = function(_, top, bottom)
    lastGradient = { top, bottom }
    slice.SetGradient(top, bottom)
  end
  -- Zones are anchor-sized, so their height is often unknown until layout; re-apply then.
  zone:HookScript("OnSizeChanged", function()
    if lastGradient then
      slice.SetGradient(lastGradient[1], lastGradient[2])
    end
  end)
  return zone
end

--- Consume mouse over a top-level window so action bars / units / world behind it
--- do not receive hover (and their GameTooltip does not poke through).
function UI.BlockBehindTooltips(frame)
  if not frame then
    return
  end
  frame:EnableMouse(true)
  if frame.EnableMouseMotion then
    frame:EnableMouseMotion(true)
  end
  if frame.SetPropagateMouseMotion then
    frame:SetPropagateMouseMotion(false)
  end
  if frame.SetPropagateMouseClicks then
    frame:SetPropagateMouseClicks(false)
  end
  frame:HookScript("OnEnter", function()
    if GameTooltip and GameTooltip:IsShown() then
      GameTooltip:Hide()
    end
  end)
end

--- Rounded BACKGROUND hover wash for option rows. Textures are parented to `frame` (so
--- they sit under OVERLAY labels) and sized to `bounds` (a pad frame that may extend
--- past the row). Returns { Show, Hide }.
function UI.CreateRoundedHover(frame, bounds, color, radius)
  radius = radius or UI.Radius.button
  local colors = UI.Colors
  local fill = color or colors.hoverFill
  -- Outline: the theme hover border, or (for a custom tint) the same colour made stronger.
  local border = colors.hoverBorderBottom
  if color then
    border = { color[1], color[2], color[3], min(1, (color[4] or 1) * 4) }
  end
  local ring = Build9Slice(frame, bounds, radius, "BACKGROUND", border, 0, nil, 0)
  local inner = Build9Slice(frame, bounds, max(radius - 1, 0), "BACKGROUND", fill, 1, nil, 1)
  -- Show / Hide / SetColor work with both . and : calls.
  local hover = {}
  function hover.Show()
    ring.Show()
    inner.Show()
  end
  function hover.Hide()
    ring.Hide()
    inner.Hide()
  end
  function hover.SetColor(r, g, b, a)
    inner.SetColor(r, g, b, a)
    ring.SetColor(r, g, b, min(1, (a or 1) * 4))
  end
  -- Default hover uses the shared control outline gradient; it depends on the height, so it
  -- is re-applied when the bounds resize.
  local function applyOutline()
    ring.SetGradient(colors.hoverBorderTop, colors.hoverBorderBottom)
    inner.SetGradient(colors.hoverFillTop, colors.hoverFillBottom)
  end
  if not color then
    applyOutline()
    bounds:HookScript("OnSizeChanged", applyOutline)
  end
  hover.Hide()
  return hover
end

local function Lighten(c, t)
  return { c[1] + (1 - c[1]) * t, c[2] + (1 - c[2]) * t, c[3] + (1 - c[3]) * t, 1 }
end

local function Darken(c, k)
  return { c[1] * k, c[2] * k, c[3] * k, 1 }
end

--- Standard surface for every button-like control (buttons, dropdowns, keybinds, dialog
--- and editor buttons): a subtle vertical gradient fill (lighter on top) inside a 1px
--- outline, so it reads as a pressable button. Default variant is the dark neutral control;
--- "primary" is the accent button and "danger" the red destructive button (Uninstall). `radius` overrides the corner radius
--- (e.g. half the height for a fully rounded pill).
--- Adds frame:cmControlHover(on) to swap the idle/hover gradient, and
--- frame.cmControlText = { idle = {r,g,b}, hover = {r,g,b} } for the label colours.
function UI.StyleControl(frame, variant, radius)
  local colors = UI.Colors
  local primary = variant == "primary"
  local danger = variant == "danger"
  local a = colors.accent
  local w = colors.warning
  local idleTop, idleBottom, hoverTop, hoverBottom, border
  if primary then
    idleTop, idleBottom = Lighten(a, 0.10), Darken(a, 0.88)
    hoverTop, hoverBottom = Lighten(a, 0.22), Darken(a, 0.96)
    border = Darken(a, 0.70)
  elseif danger then
    -- Warning red, kept dark so the white label reads (the old Uninstall look, now a gradient).
    idleTop, idleBottom = Darken(w, 0.50), Darken(w, 0.34)
    hoverTop, hoverBottom = Darken(w, 0.72), Darken(w, 0.52)
    border = Darken(w, 0.6)
  else
    idleTop, idleBottom = colors.controlFillTop, colors.controlFill
    hoverTop, hoverBottom = colors.buttonHoverTop, colors.buttonHover
    border = colors.cardBorder
  end
  UI.StyleRounded(frame, idleBottom, border, radius or UI.Radius.button, 1)
  frame:cmSetFillGradient(idleTop, idleBottom)
  if primary then
    frame:cmSetBorderGradient(Darken(a, 0.82), Darken(a, 0.58))
  elseif danger then
    frame:cmSetBorderGradient(Darken(w, 0.78), Darken(w, 0.5))
  else
    frame:cmSetBorderGradient(colors.controlBorderTop, colors.controlBorderBottom)
  end
  frame.cmControlHover = function(self, on)
    if on then
      self:cmSetFillGradient(hoverTop, hoverBottom)
    else
      self:cmSetFillGradient(idleTop, idleBottom)
    end
  end
  if primary then
    frame.cmControlText = { idle = { 0.10, 0.07, 0.04 }, hover = { 0.10, 0.07, 0.04 } }
  elseif danger then
    frame.cmControlText = { idle = { 1, 1, 1 }, hover = { 1, 1, 1 } }
  else
    frame.cmControlText = {
      idle = { colors.text[1], colors.text[2], colors.text[3] },
      hover = { colors.text[1], colors.text[2], colors.text[3] },
    }
  end
end

--- Standard tab-style button (sidebar tabs, segment bars, editor tabs). A transparent rounded
--- pill that, when selected, shows a gradient fill with a subtle outline, an orange capsule
--- marker inset at the left, and accent text. `label` is the tab's FontString; `markerH` is
--- the capsule height (default: button height - 14). Size the button before calling.
--- Adds button:cmSetTabSelected(bool) and the hover wash for unselected tabs.
function UI.StyleTab(button, label, markerH)
  local colors = UI.Colors
  UI.StyleRounded(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.button, 1)

  local marker = CreateFrame("Frame", nil, button)
  marker:SetFrameLevel(button:GetFrameLevel() + 2)
  marker:SetSize(5, markerH or max((button:GetHeight() or 0) - 14, 8))
  marker:SetPoint("LEFT", button, "LEFT", 6, 0)
  UI.StyleRounded(marker, colors.accent, { 0, 0, 0, 0 }, 2.5)
  marker:cmSetFillGradient(colors.accentTop, colors.accentBottom)
  marker:Hide()

  button.cmTabSelected = false
  function button:cmSetTabSelected(selected)
    self.cmTabSelected = selected and true or false
    marker:SetShown(self.cmTabSelected)
    if self.cmTabSelected then
      self:cmSetFillGradient(colors.tabActiveTop, colors.tabActive)
      self:cmSetBorder(
        colors.tabActiveBorder[1],
        colors.tabActiveBorder[2],
        colors.tabActiveBorder[3],
        1
      )
      label:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3])
    else
      self:cmSetFill(0, 0, 0, 0)
      self:cmSetBorder(0, 0, 0, 0)
      label:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
    end
  end

  button:HookScript("OnEnter", function(self)
    if not self.cmTabSelected then
      self:cmSetFillGradient(colors.hoverFillTop, colors.hoverFillBottom)
      self:cmSetBorderGradient(colors.hoverBorderTop, colors.hoverBorderBottom)
    end
  end)
  button:HookScript("OnLeave", function(self)
    if not self.cmTabSelected then
      self:cmSetFill(0, 0, 0, 0)
      self:cmSetBorder(0, 0, 0, 0)
    end
  end)
end

--- Standard input well (text fields, list boxes, search): darkest fill with the same 1px
--- outline as buttons and selects (cardBorder + controlBorder gradient). Use for anything
--- the user types into or scrolls inside.
function UI.StyleField(frame)
  local colors = UI.Colors
  UI.StyleRounded(frame, colors.inputBg, colors.cardBorder, UI.Radius.button, 1)
  frame:cmSetBorderGradient(colors.controlBorderTop, colors.controlBorderBottom)
end

local SEARCH_ATLAS = "talents-search-suggestion-magnifyingglass"

--- Search / filter box: the standard input well plus a cream magnifier at the left. Works on a Frame or an EditBox;
--- callers add left text insets (~28px) so typing clears the icon, and size it with
--- UI.Sizes.search. Returns the icon texture (hidden if the atlas is missing).
function UI.StyleSearchBox(box)
  local colors = UI.Colors
  UI.StyleField(box)
  local icon = box:CreateTexture(nil, "ARTWORK")
  icon:SetSize(14, 14)
  icon:SetPoint("LEFT", box, "LEFT", 9, 0)
  if CM.GetAtlasInfo(SEARCH_ATLAS) then
    CM.SetAtlas(icon, SEARCH_ATLAS)
    -- Desaturate then tint so the magnifier reads as the theme's cream.
    icon:SetDesaturated(true)
    icon:SetVertexColor(colors.text[1], colors.text[2], colors.text[3])
  else
    icon:Hide()
  end
  return icon
end

--- Dropdown / suggestion popup: the page fill inside a 1px button-style outline, with the same
--- 8px corners as the select and filter boxes it belongs to. (Windows use UI.StyleWindow.)
function UI.StylePopup(frame)
  local colors = UI.Colors
  UI.StyleRounded(frame, colors.windowBg, colors.cardBorder, UI.Radius.button, 1)
  frame:cmSetBorderGradient(colors.controlBorderTop, colors.controlBorderBottom)
end

--- Gradient hairline for dividers. Caller anchors the returned frame and gives it a
--- thickness (height for horizontal, width for vertical).
---   mode "ends": solid in the middle, fading to transparent at both ends.
---   mode "fade": solid at the start (left / top), fading to faint at the end.
function UI.CreateLine(parent, vertical, color, mode)
  local line = CreateFrame("Frame", nil, parent)
  line:EnableMouse(false)
  local r, g, b = color[1], color[2], color[3]
  local a = color[4] or 1
  local solid = CreateColor(r, g, b, a)
  local clear = CreateColor(r, g, b, 0)
  local faint = CreateColor(r, g, b, a * 0.2)

  local function piece(firstPoint, firstRel, secondPoint, secondRel)
    local tex = line:CreateTexture(nil, "ARTWORK")
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetPoint(firstPoint, line, firstRel)
    tex:SetPoint(secondPoint, line, secondRel)
    return tex
  end

  if mode == "fade" then
    local tex = piece("TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
    if vertical then
      -- Vertical gradients take the minimum colour at the bottom.
      tex:SetGradient("VERTICAL", faint, solid)
    else
      tex:SetGradient("HORIZONTAL", solid, faint)
    end
  elseif vertical then
    local top = piece("TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "RIGHT")
    top:SetGradient("VERTICAL", solid, clear)
    local bottom = piece("TOPLEFT", "LEFT", "BOTTOMRIGHT", "BOTTOMRIGHT")
    bottom:SetGradient("VERTICAL", clear, solid)
  else
    local first = piece("TOPLEFT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOM")
    first:SetGradient("HORIZONTAL", clear, solid)
    local second = piece("TOPLEFT", "TOP", "BOTTOMRIGHT", "BOTTOMRIGHT")
    second:SetGradient("HORIZONTAL", solid, clear)
  end
  return line
end

--- Standard hover wiring for a StyleControl button with one label. `isDisabled` (optional)
--- returns true to suppress the hover state.
function UI.WireControlHover(button, label, isDisabled)
  local text = button.cmControlText
  label:SetTextColor(text.idle[1], text.idle[2], text.idle[3])
  button:SetScript("OnEnter", function(self)
    if isDisabled and isDisabled() then
      return
    end
    self:cmControlHover(true)
    label:SetTextColor(text.hover[1], text.hover[2], text.hover[3])
  end)
  button:SetScript("OnLeave", function(self)
    self:cmControlHover(false)
    label:SetTextColor(text.idle[1], text.idle[2], text.idle[3])
  end)
end

--- Creates a card frame (parented, no positioning) styled like a settings group.
function UI.CreateCard(parent)
  local card = CreateFrame("Frame", nil, parent)
  UI.StyleRounded(card, UI.Colors.cardBg, UI.Colors.cardBorder, UI.Radius.card)
  card:cmSetBorderGradient(UI.Colors.controlBorderTop, UI.Colors.controlBorderBottom)
  return card
end

--- Custom window close button ("X") — replaces Blizzard's UIPanelCloseButton art with a
--- flat button in the theme accent yellow. Closes its parent by default; override OnClick
--- for custom behavior. Caller positions it.
function UI.CreateCloseButton(parent, size)
  size = size or 22
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  -- Sit above the title bar drag handle, which overlaps this corner; otherwise the drag
  -- frame swallows clicks and only the sliver past the title bar edge stays clickable.
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  UI.StyleRounded(btn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

  local a = UI.Colors.accent
  local x = UI.CreateFontString(btn, "OVERLAY", size - 4, "GameFontNormalLarge")
  -- The font's multiplication sign sits a little above the middle of its line box; nudge it
  -- down so it is centred on the button (and level with the header icons beside it).
  x:SetPoint("CENTER", btn, "CENTER", 0, -1.5)
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
function UI.CreateIconLinkButton(parent, texturePath, url, tooltip, label, size)
  size = size or 20
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size, size)
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(btn)
  icon:SetTexture(texturePath)
  -- Icons keep their own colours; they sit slightly dimmed and brighten on hover.
  icon:SetAlpha(0.9)

  btn:SetScript("OnEnter", function()
    icon:SetAlpha(1)
  end)
  btn:SetScript("OnLeave", function()
    icon:SetAlpha(0.9)
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

--- Circular alpha mask that stays smooth when scaled (the shipped CircleMaskScalable). Returns the
--- fraction of the mask texture covered by the visible disc (the art leaves a small margin), so
--- callers can size the mask to a wanted radius.
local SCALABLE_DISC_FRAC = 60 / 64

function UI.SetCircleMask(mask)
  CM.SetAtlasMask(mask, "CircleMaskScalable")
  return SCALABLE_DISC_FRAC
end

--- Circular texture: a solid color clipped by CircleMaskScalable (toggle knobs).
function UI.CreateCircle(frame, layer, color)
  local tex = frame:CreateTexture(nil, layer or "ARTWORK")
  tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  local mask = frame:CreateMaskTexture()
  UI.SetCircleMask(mask)
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
    edit:SetFont(path, pixelSize or UI.Fonts.input, flags or "")
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
  -- Optional red note under the value (entry.warning, stacked tips only); created on first use.
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
  tipFrame:cmSetBorderGradient(UI.Colors.controlBorderTop, UI.Colors.controlBorderBottom)

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
--- `content` is a string, a table `{ title?, text?, dim?, lines?, stacked? }` (`dim` draws `text`
--- in the dim colour), or a function returning either. `lines` entries are `{ label, value, kind? }` (`kind = "warn"` uses warning color); they
--- are laid out as label / value columns, or with the label above its value when `stacked` is set
--- (then an entry may also carry `warning`, a note in the warning colour under its value).
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
    if line.warning then
      line.warning:Hide()
    end
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
    local bodyColor = content.dim and UI.Colors.textDim or UI.Colors.text
    tipBody:SetTextColor(bodyColor[1], bodyColor[2], bodyColor[3], 1)
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

        local labelH = max(line.label:GetStringHeight(), UI.Fonts.desc + 2)
        local labelW = line.label:GetStringWidth()
        local stacked = content.stacked == true
        local valueW = stacked and textW or max(48, textW - labelW - 6)
        line.value:ClearAllPoints()
        if stacked then
          -- Label on top (full brightness), its text below in the dim colour.
          local text = UI.Colors.text
          line.label:SetTextColor(text[1], text[2], text[3], 1)
          if not warn then
            valColor = dim
          end
          line.value:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X, -(y + labelH + 1))
        else
          line.value:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X + labelW + 6, -y)
        end
        line.value:SetWidth(valueW)
        line.value:SetText(UI.StripColors(valueText) or valueText)
        line.value:SetTextColor(valColor[1], valColor[2], valColor[3], 1)
        line.value:Show()

        local valueH = line.value:GetStringHeight()
        if valueH < 1 then
          valueH = UI.Fonts.desc + 2
        end
        if stacked then
          y = y + labelH + 1 + valueH
          if entry.warning then
            if not line.warning then
              line.warning =
                UI.CreateFontString(tipFrame, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
              line.warning:SetJustifyH("LEFT")
              line.warning:SetJustifyV("TOP")
              line.warning:SetWordWrap(true)
              if line.warning.SetNonSpaceWrap then
                line.warning:SetNonSpaceWrap(true)
              end
            end
            local red = UI.Colors.warning
            line.warning:ClearAllPoints()
            line.warning:SetPoint("TOPLEFT", tipFrame, "TOPLEFT", TIP_PAD_X, -(y + TIP_GAP))
            line.warning:SetWidth(textW)
            line.warning:SetText(UI.StripColors(tostring(entry.warning)) or tostring(entry.warning))
            line.warning:SetTextColor(red[1], red[2], red[3], 1)
            line.warning:Show()
            local warningH = line.warning:GetStringHeight()
            if warningH < 1 then
              warningH = UI.Fonts.desc + 2
            end
            y = y + TIP_GAP + warningH
          end
          y = y + TIP_GAP + 2
        else
          y = y + max(labelH, valueH) + 2
        end
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

--- Builds the rounded track + draggable thumb (parented to `owner`, positioned by caller).
--- Track and thumb are the same width (UI.Sizes.scrollbar); the thumb is the accent colour.
local function StyleThumbBar(owner, thickness)
  thickness = thickness or UI.Sizes.scrollbar
  local bar = CreateFrame("Frame", nil, owner)
  bar:SetWidth(thickness)
  UI.StyleRounded(bar, UI.Colors.scrollTrack, { 0, 0, 0, 0 }, thickness / 2, 0)

  local thumb = CreateFrame("Frame", nil, bar)
  thumb:SetWidth(thickness)
  thumb:SetHeight(40)
  thumb:SetPoint("TOP", bar, "TOP", 0, 0)
  local a = UI.Colors.accent
  UI.StyleRounded(thumb, { a[1], a[2], a[3], 1 }, { 0, 0, 0, 0 }, thickness / 2, 0)
  thumb:cmSetFillGradient(UI.Colors.accentTop, UI.Colors.accentBottom)
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

--- Shows a popup/menu scroll bar only while its list overflows. Short lists reserve no gutter,
--- so a visible bar would sit outside the popup; scroll updates re-show it, hence the OnShow
--- guard.
function UI.SetMenuBarActive(bar, active)
  bar.cmMenuActive = active
  if not bar.cmMenuGuard then
    bar.cmMenuGuard = true
    bar:HookScript("OnShow", function(self)
      if not self.cmMenuActive then
        self:Hide()
      end
    end)
  end
  if not active then
    bar:Hide()
  end
end

function UI.CreateScrollFrame(parent, thickness)
  local scroll = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  thickness = thickness or UI.Sizes.scrollbar
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

  local bar, thumb = StyleThumbBar(owner, UI.Sizes.scrollbar)
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
  local thickness = UI.Sizes.scrollbar
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

--- Notice for a disabled option row. It spans the option's full width and height, filled
--- with a light layer of the page background colour (so the row does not change colour)
--- and the message centred. The row's control is hidden by the caller; the label and
--- description stay readable through it. The overlay blocks clicks on the row.
--- Call overlay.SetStampText(text) to change the message.
function UI.CreateRowStamp(row, text)
  local colors = UI.Colors
  local overlay = CreateFrame("Frame", nil, row)
  overlay:SetAllPoints(row)
  overlay:SetFrameLevel(row:GetFrameLevel() + 30)
  overlay:EnableMouse(true)

  local bg = colors.windowBg
  -- Fill only (transparent border): StyleRounded's outline is a full-size shape drawn under
  -- the fill, which would show through a translucent fill as an opaque block.
  UI.StyleRounded(overlay, { bg[1], bg[2], bg[3], 0.55 }, { 0, 0, 0, 0 }, UI.Radius.card)

  local stamp = UI.CreateFontString(overlay, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  stamp:SetPoint("CENTER", overlay, "CENTER", 0, 0)
  stamp:SetJustifyH("CENTER")
  stamp:SetWordWrap(true)
  stamp:SetTextColor(colors.accent[1], colors.accent[2], colors.accent[3])

  local function Layout()
    stamp:SetWidth(max((overlay:GetWidth() or 400) - 40, 80))
  end

  overlay.SetStampText = function(message)
    stamp:SetText(UI.StripColors(message) or "")
  end
  overlay:HookScript("OnSizeChanged", Layout)
  Layout()
  overlay.SetStampText(text)

  overlay.stamp = stamp
  overlay:Hide()
  return overlay
end
