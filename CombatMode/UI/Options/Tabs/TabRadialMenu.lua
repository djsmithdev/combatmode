---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabRadialMenu.lua — OPTIONS TAB — Radial Menu
---------------------------------------------------------------------------------------
--  What it does: Radial Menu keybind plus a visual wheel editor inside the tab: the wheel's title
--  sits on top with arrows either side to page through your wheels (click the title to rename it),
--  a "-" / "+" disc in the wheel's centre removes a wheel / opens a preset menu (Interface, Emotes,
--  Misc, Blank Wheel) to add one, and an accent "Add Slice" slice on the wheel adds a slice.
--  Right-click a slice removes it (never the last); drag a slice onto another to reorder; click it
--  to pick a UI action from a searchable dropdown, or drop a spell, item, toy, mount or macro on it.
--  Architecture / how it works:
--    • Reads and writes only through Core/RadialMenu/Data.lua (CM.RadialCreateWheel,
--      CM.RadialSetSlot, CM.RadialAddSlice...), which re-store the secure wheel (queued in combat).
--    • The wheel row is a custom frame (ctx:PlaceFrame) with a pool of 8 slice buttons; it
--      redraws from the DB on every Options.Sync (registered as a control).
--    • No master toggle: an unbound key disables the radial menu.
--  Does not: Store wheels (Core/RadialMenu/Data.lua) or draw the in-game wheel (View.lua).
--  Related: Core/RadialMenu/{Data,Actions}.lua, UI/Options/OptionsPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local ClearCursor = _G.ClearCursor
local CreateColor = _G.CreateColor
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetCursorInfo = _G.GetCursorInfo
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local math = _G.math
local select = _G.select
local tostring = _G.tostring
local type = _G.type

local UI = CM.UI
local C = UI.Colors
local LAYOUT = CM.RadialLayout

local BIND_NAME = "Combat Mode - Radial Menu"
local WHEELS_LABEL = "Radial Menu Wheels"
local ART_PATH = "Interface\\AddOns\\CombatMode\\Assets\\radial\\radial_bg_"
local SEL_PATH = "Interface\\AddOns\\CombatMode\\Assets\\radial\\radial_sel_"
local WEDGE_ALPHA = 0.7
local HUB_GLYPH_SIZE = 18
local HUB_ALPHA_DIM = 0.4
local EDITOR_SCALE = 0.7
local AREA = 360
local TITLE_W = 140
local TITLE_H = 32
local ARROW_SIZE = 20
-- Ring the wheel art's slices span, from the middle (art pixels, scaled by EDITOR_SCALE).
local RING_INNER = 60
local RING_OUTER = 215
local SLICE_BTN = 40

local selected = 1

local function Say(text)
  print(CM.Constants.BasePrintMsg .. "|cff909090: " .. text .. "|r")
end

local function CurrentWheel()
  return CM.RadialGetWheels()[selected]
end

local function Resync()
  UI.Options.Sync()
end

---------------------------------------------------------------------------------------
-- Slice action menu (the options dropdown, opened beside a slice)
---------------------------------------------------------------------------------------
local CLEAR_ID = "__clear"
local menuValues, menuOrder = { [CLEAR_ID] = "Clear Slice" }, {}
local menuHeaders = {
  __ui = "UI Actions",
  __emote = "Emotes",
  __command = "Commands",
  __marker = "Markers",
  __slice = "Slice",
}
for header, title in pairs(menuHeaders) do
  menuValues[header] = title
end
for _, section in ipairs({
  { "__ui", nil },
  { "__emote", "emote" },
  { "__command", "command" },
  { "__marker", "marker" },
}) do
  menuOrder[#menuOrder + 1] = section[1]
  for _, action in ipairs(CM.RadialActions.list) do
    if action.group == section[2] and CM.RadialActions.IsAvailable(action) then
      menuValues[action.id] = action.label
      menuOrder[#menuOrder + 1] = action.id
    end
  end
end
menuOrder[#menuOrder + 1] = "__slice"
menuOrder[#menuOrder + 1] = CLEAR_ID

local sliceMenu
local menuSlot
-- The slice whose dropdown is open keeps its wedge lit; the wheel row registers how to repaint.
local pinnedSlot
local onPinChange

local function SetPinnedSlot(slot)
  pinnedSlot = slot
  if onPinChange then
    onPinChange()
  end
end

local function OpenSliceMenu(slot, anchor)
  if not sliceMenu then
    local host = CreateFrame("Frame", nil, UIParent)
    host:Hide()
    sliceMenu = UI.MakeDropdown(host, {
      label = "Slice",
      values = menuValues,
      order = menuOrder,
      headers = menuHeaders,
      get = function()
        local wheel = CurrentWheel()
        local entry = wheel and wheel.slots and wheel.slots[menuSlot]
        return entry and entry.kind == "action" and entry.id or nil
      end,
      set = function(id)
        CM.RadialSetSlot(selected, menuSlot, id ~= CLEAR_ID and { kind = "action", id = id } or nil)
        Resync()
      end,
    })
    sliceMenu.onClosed = function()
      SetPinnedSlot(nil)
    end
  end
  menuSlot = slot
  local wheel = CurrentWheel()
  local entry = wheel and wheel.slots and wheel.slots[slot]
  -- OpenAt closes a menu that is already open (firing onClosed), so pin after it.
  sliceMenu.OpenAt(anchor, entry and (CM.RadialEntryInfo(entry)) or "Choose an action", 220)
  SetPinnedSlot(slot)
end

-- "+" menu: the preset wheels (CM.RadialPresetList) and a blank one.
local BLANK_ID = "__blank"
local wheelMenu

local function OpenWheelMenu(anchor)
  if not wheelMenu then
    local host = CreateFrame("Frame", nil, UIParent)
    host:Hide()
    local headers = { __presets = "Presets" }
    local values, order =
      { [BLANK_ID] = "New Wheel", __presets = "Presets" }, { BLANK_ID, "__presets" }
    for _, preset in ipairs(CM.RadialPresetList()) do
      values[preset.key] = preset.label
      order[#order + 1] = preset.key
    end
    wheelMenu = UI.MakeDropdown(host, {
      label = "Wheel",
      values = values,
      order = order,
      headers = headers,
      valueColors = { [BLANK_ID] = C.accent },
      get = function()
        return nil
      end,
      set = function(key)
        local index = CM.RadialCreateWheel(nil, key ~= BLANK_ID and key or nil)
        if index then
          selected = index
        else
          Say("You can have up to " .. LAYOUT.MAX_WHEELS .. " wheels.")
        end
        Resync()
      end,
    })
  end
  wheelMenu.OpenAt(anchor, false, 160)
end

---------------------------------------------------------------------------------------
-- Wheel row
---------------------------------------------------------------------------------------
local function ApplyDrop(slot)
  if not GetCursorInfo() then
    return false
  end
  local entry = CM.RadialEntryFromCursor()
  if not entry then
    Say("That can't go on a wheel. Use a spell, item, toy, mount or macro.")
    return true
  end
  ClearCursor()
  CM.RadialSetSlot(selected, slot, entry)
  Resync()
  return true
end

local function BuildSliceButton(area, slot)
  local button = CreateFrame("Button", nil, area)
  button:SetSize(SLICE_BTN, SLICE_BTN)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local over = CM.RadialBuildSlotChrome(button)

  button.iconLabel = CM.RadialCreateIconLabel(over, 11)

  -- Same plus glyph as the option sliders' step buttons.
  button.plus = over:CreateTexture(nil, "OVERLAY")
  CM.SetAtlas(button.plus, "common-icon-plus", true)
  local plusH = button.plus:GetHeight() or 16
  local plusW = button.plus:GetWidth() or 16
  if plusH > 0 then
    button.plus:SetSize(plusW * 12 / plusH, 12)
  end
  button.plus:SetPoint("CENTER")
  button.plus:SetDesaturated(true)
  button.plus:SetVertexColor(C.text[1], C.text[2], C.text[3])

  button.slot = slot
  button:SetScript("OnEnter", function(self)
    local wheel = CurrentWheel()
    local entry = wheel and wheel.slots and wheel.slots[self.slot]
    if entry then
      UI.ShowTooltip(self, {
        title = (CM.RadialEntryInfo(entry)),
        text = "Drag a spell, item, toy, mount or macro here, or click to change the action.",
        warning = "Right-click to remove this slice.",
      }, "ANCHOR_RIGHT")
    else
      UI.ShowTooltip(self, {
        title = "Empty Slice",
        text = "Drag a spell, item, toy, mount or macro here, or click to set an action. Empty slices are left out of the wheel.",
        warning = "Right-click to remove this slice.",
      }, "ANCHOR_RIGHT")
    end
  end)
  button:SetScript("OnLeave", function()
    UI.HideTooltip()
  end)
  button:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
      if not CM.RadialRemoveSlice(selected, self.slot) then
        Say("A wheel needs at least one slice.")
      end
      UI.HideTooltip()
      Resync()
    elseif not ApplyDrop(self.slot) then
      OpenSliceMenu(self.slot, self)
    end
  end)
  button:SetScript("OnReceiveDrag", function(self)
    ApplyDrop(self.slot)
  end)
  return button
end

local function Tooltip(button, text)
  UI.AttachTooltip(button, text, "ANCHOR_TOP")
end

-- Page arrow: the Ally Cycle HUD's cycle arrow (housing floor arrow), turned to point sideways.
local function MakeArrow(parent, side)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(24, 24)
  local icon = button:CreateTexture(nil, "ARTWORK")
  CM.SetAtlas(icon, "housing-floor-arrow-up-default", false)
  icon:SetSize(ARROW_SIZE, ARROW_SIZE)
  icon:SetPoint("CENTER")
  icon:SetRotation(side == "left" and math.pi / 2 or -math.pi / 2)
  icon:SetAlpha(0.75)
  button:HookScript("OnEnter", function()
    icon:SetAlpha(1)
  end)
  button:HookScript("OnLeave", function()
    icon:SetAlpha(0.75)
  end)
  return button
end

local function BuildTitle(row)
  local title = CreateFrame("Button", nil, row)
  title:SetSize(TITLE_W, TITLE_H)
  title:SetPoint("TOP", row, "TOP", 0, 0)
  title.text = UI.CreateFontString(title, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  title.text:SetPoint("CENTER")
  title.text:SetWidth(TITLE_W - 8)
  title.text:SetTextColor(C.text[1], C.text[2], C.text[3])
  Tooltip(title, "Click to rename this wheel")

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetAllPoints(title)
  box:SetFrameLevel(title:GetFrameLevel() + 5)
  UI.StyleField(box)
  box:Hide()
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, 0)
  edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 0)
  edit:SetAutoFocus(false)
  edit:SetMaxLetters(LAYOUT.NAME_MAX)
  edit:SetFontObject(_G.GameFontHighlight)
  edit:SetJustifyH("CENTER")
  edit:SetTextColor(C.text[1], C.text[2], C.text[3])
  edit:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)
  edit:SetScript("OnEscapePressed", function(self)
    box:Hide()
    self:ClearFocus()
  end)
  edit:SetScript("OnEditFocusLost", function(self)
    if box:IsShown() then
      box:Hide()
      CM.RadialRenameWheel(selected, self:GetText())
      Resync()
    end
  end)
  title:SetScript("OnClick", function()
    local wheel = CurrentWheel()
    edit:SetText(wheel and CM.RadialWheelName(wheel, selected) or "")
    box:Show()
    edit:SetFocus()
    edit:HighlightText()
  end)
  return title
end

local function PlaceAt(frame, area, dx, dy, radius)
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", area, "CENTER", dx * radius, dy * radius)
end

local function BuildWheelRow(ctx)
  local row = CreateFrame("Frame", nil, ctx.content)
  local wheelTop = TITLE_H + 8
  local hintTop = wheelTop + AREA + 8
  local height = hintTop + 34
  row:SetHeight(height)

  -- Title with the page arrows either side; clicking the title renames the wheel.
  local title = BuildTitle(row)
  local prev = MakeArrow(row, "left")
  prev:SetPoint("RIGHT", title, "LEFT", -8, 0)
  Tooltip(prev, "Previous wheel")
  prev:SetScript("OnClick", function()
    selected = math.max(1, selected - 1)
    Resync()
  end)
  local nextButton = MakeArrow(row, "right")
  nextButton:SetPoint("LEFT", title, "RIGHT", 8, 0)
  Tooltip(nextButton, "Next wheel")
  nextButton:SetScript("OnClick", function()
    selected = math.min(#CM.RadialGetWheels(), selected + 1)
    Resync()
  end)

  -- The wheel: background art, the slices, and the accent "Add Slice" slice in the next position.
  local area = CreateFrame("Frame", nil, row)
  area:SetSize(AREA, AREA)
  area:SetPoint("TOP", row, "TOP", 0, -wheelTop)

  local bg = area:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(LAYOUT.ART * EDITOR_SCALE, LAYOUT.ART * EDITOR_SCALE)
  bg:SetPoint("CENTER")

  -- The next free slice itself lights up in the accent colour (the in-game highlight art, tinted)
  -- and carries the "Add Slice" label; the button is just its click area.
  local wedge = area:CreateTexture(nil, "BORDER")
  wedge:SetAlpha(WEDGE_ALPHA)
  wedge:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])

  -- A hovered slice "activates" its wedge like the live wheel does, in this wheel's own highlight
  -- colour (the accent stays the Add Slice wedge's).
  local shownCount = 0
  local hoverWedge = area:CreateTexture(nil, "BORDER", nil, 1)
  hoverWedge:Hide()

  -- Reorder drag state: `preview[position] = source slot` shows the wheel as it would end up.
  local Update, preview, dragFrom, dragTo
  -- The lit wedge turns to its slice; while a slice is dragged it glides there (wedgeCur chases
  -- wedgeTarget) instead of jumping.
  local wedgeCur, wedgeTarget
  local function ApplyWedge()
    local o = LAYOUT.OVERLAY[shownCount]
    if not (o and wedgeCur) then
      return
    end
    local a = wedgeCur
    local x = o[3] * math.cos(a) + o[4] * math.sin(a)
    local y = -o[3] * math.sin(a) + o[4] * math.cos(a)
    hoverWedge:SetTexture(SEL_PATH .. shownCount .. ".tga")
    hoverWedge:SetVertexColor(CM.RadialWheelColor(selected))
    hoverWedge:SetSize(o[1] * EDITOR_SCALE, o[2] * EDITOR_SCALE)
    hoverWedge:ClearAllPoints()
    hoverWedge:SetPoint("CENTER", area, "CENTER", x * EDITOR_SCALE, y * EDITOR_SCALE)
    hoverWedge:SetRotation(-a)
    hoverWedge:Show()
  end

  local function ShowHoverWedge(slot)
    if not LAYOUT.OVERLAY[shownCount] then
      return
    end
    wedgeTarget = CM.RadialSlotAngle(slot, shownCount)
    if not (dragFrom and hoverWedge:IsShown() and wedgeCur) then
      wedgeCur = wedgeTarget
    end
    ApplyWedge()
  end

  local buttons = {}
  for slot = 1, LAYOUT.MAX_SLICES do
    buttons[slot] = BuildSliceButton(area, slot)
    -- The whole slice is the click target (see `hit` below), not just the icon.
    buttons[slot]:EnableMouse(false)
  end
  -- One mouse target over the whole ring: the slice under the cursor (nearest slice direction) is
  -- hovered, clicked and dropped on, forwarding to that slice's button (or the Add Slice slice).
  local liveCount = 0
  local addIndex
  local addSlice
  local hit = CreateFrame("Button", nil, area)
  hit:SetAllPoints(area)
  hit:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local hovered
  local inside = false

  local function SliceAtCursor()
    local cx, cy = _G.GetCursorPosition()
    local ax, ay = area:GetCenter()
    local scale = area:GetEffectiveScale()
    if not (cx and ax and scale) or shownCount < 1 then
      return nil
    end
    local dx, dy = cx / scale - ax, cy / scale - ay
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < RING_INNER * EDITOR_SCALE or dist > RING_OUTER * EDITOR_SCALE then
      return nil
    end
    local best, bestDot
    for slot = 1, shownCount do
      local sx, sy = CM.RadialSlotDir(slot, shownCount)
      local dot = sx * dx + sy * dy
      if not bestDot or dot > bestDot then
        best, bestDot = slot, dot
      end
    end
    return best
  end

  local function HoverTarget(slot)
    if slot and slot == addIndex then
      return addSlice
    end
    return slot and slot <= liveCount and buttons[slot] or nil
  end

  -- Lit wedge: the slice whose dropdown is open, else the hovered one (never the Add Slice slice).
  local function PaintWedge()
    local slot = dragTo or pinnedSlot or hovered
    if slot and slot <= liveCount and slot ~= addIndex then
      ShowHoverWedge(slot)
    else
      hoverWedge:Hide()
      wedgeCur = nil
    end
  end
  onPinChange = PaintWedge

  -- Glide animation: slice buttons and the lit wedge ease toward their targets while reordering.
  local glide = CreateFrame("Frame", nil, area)
  glide:SetScript("OnUpdate", function(_, elapsed)
    local k = 1 - math.exp(-20 * elapsed)
    for slot = 1, liveCount do
      local button = buttons[slot]
      if button.cx and (button.cx ~= button.tx or button.cy ~= button.ty) then
        if math.abs(button.tx - button.cx) + math.abs(button.ty - button.cy) < 0.3 then
          button.cx, button.cy = button.tx, button.ty
        else
          button.cx = button.cx + (button.tx - button.cx) * k
          button.cy = button.cy + (button.ty - button.cy) * k
        end
        button:ClearAllPoints()
        button:SetPoint("CENTER", area, "CENTER", button.cx, button.cy)
      end
    end
    if wedgeCur and wedgeTarget and wedgeCur ~= wedgeTarget then
      local twoPi = math.pi * 2
      local diff = (wedgeTarget - wedgeCur + math.pi) % twoPi - math.pi
      if math.abs(diff) < 0.003 then
        wedgeCur = wedgeTarget
      else
        wedgeCur = wedgeCur + diff * k
      end
      ApplyWedge()
    end
  end)

  local function SetHovered(slot)
    if slot == hovered then
      return
    end
    local old = HoverTarget(hovered)
    if old and old.GetScript and old:GetScript("OnLeave") then
      old:GetScript("OnLeave")(old)
    end
    hovered = slot
    local new = HoverTarget(slot)
    if new and new:GetScript("OnEnter") then
      new:GetScript("OnEnter")(new)
    end
    PaintWedge()
  end

  hit:SetScript("OnEnter", function()
    inside = true
  end)
  hit:SetScript("OnLeave", function()
    inside = false
    SetHovered(nil)
  end)
  hit:SetScript("OnUpdate", function()
    if dragFrom then
      -- The dragged slice trades places with its neighbours, one step at a time along the
      -- shortest way round the wheel, until it reaches the slice under the cursor. Going past
      -- the first or last slice wraps to the other end as a single swap.
      local to = SliceAtCursor()
      if to and to <= liveCount and to ~= dragTo then
        while dragTo ~= to do
          local forward = (to - dragTo) % liveCount
          local step = forward <= liveCount - forward and 1 or -1
          local nextPos = (dragTo - 1 + step) % liveCount + 1
          preview[dragTo], preview[nextPos] = preview[nextPos], preview[dragTo]
          dragTo = nextPos
        end
        Update()
      end
    elseif inside then
      SetHovered(SliceAtCursor())
    end
  end)
  hit:SetScript("OnClick", function(_, mouseButton)
    local target = HoverTarget(hovered)
    if target and target:GetScript("OnClick") then
      target:GetScript("OnClick")(target, mouseButton)
    end
  end)
  hit:SetScript("OnReceiveDrag", function()
    local target = HoverTarget(hovered)
    if target and target ~= addSlice then
      ApplyDrop(target.slot)
    end
  end)

  -- Drag a filled slice around the wheel to reorder: its wedge stays lit while the other slices
  -- shift out of the way (preview); releasing keeps the new order.
  local function EndDrag()
    dragFrom, dragTo, preview = nil, nil, nil
  end
  hit:RegisterForDrag("LeftButton")
  hit:SetScript("OnDragStart", function()
    local slot = SliceAtCursor()
    local wheel = CurrentWheel()
    local entry = slot and slot <= liveCount and wheel and wheel.slots and wheel.slots[slot]
    if not entry then
      return
    end
    SetHovered(nil)
    UI.HideTooltip()
    dragFrom, dragTo = slot, slot
    preview = {}
    for i = 1, liveCount do
      preview[i] = i
    end
    PaintWedge()
  end)
  hit:SetScript("OnDragStop", function()
    local order = preview
    EndDrag()
    if order then
      CM.RadialReorderSlots(selected, order)
    end
    Resync()
  end)
  hit:SetScript("OnHide", EndDrag)

  addSlice = CreateFrame("Button", nil, area)
  addSlice:EnableMouse(false)
  addSlice:SetSize(90, 56)
  addSlice.text = UI.CreateFontString(addSlice, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  addSlice.text:SetPoint("CENTER")
  addSlice.text:SetWidth(84)
  addSlice.text:SetText("Add Slice")
  addSlice.text:SetTextColor(1, 1, 1)
  addSlice:SetScript("OnEnter", function()
    wedge:SetAlpha(1)
  end)
  addSlice:SetScript("OnLeave", function()
    wedge:SetAlpha(WEDGE_ALPHA)
  end)
  addSlice:SetScript("OnClick", function()
    if not CM.RadialAddSlice(selected) then
      Say("A wheel holds up to " .. LAYOUT.MAX_SLICES .. " slices.")
    end
    Resync()
  end)

  -- Wheel management in the middle of the wheel: a disc split in two halves with the regular
  -- button look (gradient fill + outline, brighter while hovered): "-" on the left removes this
  -- wheel, "+" on the right adds one.
  -- Sits in the hole of the wheel art (about 105px across), a bit smaller than the hole.
  local HUB = 76
  local hub = CreateFrame("Frame", nil, area)
  hub:SetSize(HUB, HUB)
  hub:SetPoint("CENTER", area, "CENTER", 0, 0)
  hub:SetFrameLevel(area:GetFrameLevel() + 5)
  local function Gradient(texture, top, bottom)
    texture:SetGradient(
      "VERTICAL",
      CreateColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1),
      CreateColor(top[1], top[2], top[3], top[4] or 1)
    )
  end
  local function MakeHalf(side, glyph, tip)
    local half = CreateFrame("Button", nil, hub)
    half:SetSize(HUB / 2, HUB)
    half:SetPoint(side, hub, side, 0, 0)
    -- Both textures are cut to the disc by masks spanning the whole hub.
    local border = half:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(1, 1, 1, 1)
    Gradient(border, C.controlBorderTop, C.controlBorderBottom)
    border.mask = half:CreateMaskTexture()
    border.mask:SetSize(HUB, HUB)
    border.mask:SetPoint("CENTER", hub, "CENTER", 0, 0)
    CM.SetAtlasMask(border.mask, "CircleMaskScalable")
    border:AddMaskTexture(border.mask)
    local fill = half:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", half, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", half, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(1, 1, 1, 1)
    fill.mask = half:CreateMaskTexture()
    fill.mask:SetSize(HUB - 2, HUB - 2)
    fill.mask:SetPoint("CENTER", hub, "CENTER", 0, 0)
    CM.SetAtlasMask(fill.mask, "CircleMaskScalable")
    fill:AddMaskTexture(fill.mask)
    half.fill = fill
    function half:SetHover(on)
      if on then
        Gradient(fill, C.buttonHoverTop, C.buttonHover)
      else
        Gradient(fill, C.controlFillTop, C.controlFill)
      end
    end
    half:SetHover(false)
    -- The same plus / minus glyphs as the option sliders' step buttons.
    local icon = half:CreateTexture(nil, "OVERLAY")
    CM.SetAtlas(icon, glyph == "+" and "common-icon-plus" or "common-icon-minus", true)
    local iconH = icon:GetHeight() or 16
    local iconW = icon:GetWidth() or 16
    if iconH > 0 then
      icon:SetSize(iconW * HUB_GLYPH_SIZE / iconH, HUB_GLYPH_SIZE)
    end
    icon:SetPoint("CENTER", half, "CENTER", side == "LEFT" and 1 or -1, 0)
    icon:SetDesaturated(true)
    icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
    half.icon = icon
    half:HookScript("OnEnter", function(self)
      self:SetHover(true)
    end)
    half:HookScript("OnLeave", function(self)
      self:SetHover(false)
    end)
    UI.AttachTooltip(half, tip, "ANCHOR_TOP")
    return half
  end
  local removeWheel = MakeHalf(
    "LEFT",
    "-",
    { title = "Remove Wheel", text = "Deletes this wheel and all of its slices." }
  )
  removeWheel:SetScript("OnClick", function()
    if #CM.RadialGetWheels() <= 1 then
      Say("You need at least one wheel.")
      return
    end
    UI.Confirm("Remove this wheel and all of its slices?", function()
      CM.RadialDeleteWheel(selected)
      Resync()
    end)
  end)
  local addWheel =
    MakeHalf("RIGHT", "+", { title = "Add Wheel", text = "Pick a preset wheel or a blank one." })
  addWheel:SetScript("OnClick", function(self)
    if #CM.RadialGetWheels() >= LAYOUT.MAX_WHEELS then
      Say("You can have up to " .. LAYOUT.MAX_WHEELS .. " wheels.")
      return
    end
    OpenWheelMenu(self)
  end)

  local hint = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
  hint:SetPoint("TOP", row, "TOP", 0, -hintTop)
  hint:SetWidth(AREA + 80)
  hint:SetJustifyH("CENTER")
  hint:SetWordWrap(true)
  hint:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  hint:SetText(
    "Click a slice to choose its action, or drop a spell, item, toy, mount or macro on it.\nDrag a slice to reorder it. Right-click a slice to remove it."
  )

  function Update()
    local wheels = CM.RadialGetWheels()
    local total = #wheels
    selected = math.max(1, math.min(selected, total))
    local wheel = wheels[selected]
    title.text:SetText(CM.RadialWheelName(wheel, selected))
    prev:SetAlpha(selected > 1 and 1 or 0.35)
    nextButton:SetAlpha(selected < total and 1 or 0.35)
    addWheel.dim = total >= LAYOUT.MAX_WHEELS
    addWheel:SetAlpha(addWheel.dim and HUB_ALPHA_DIM or 1)
    removeWheel.dim = total <= 1
    removeWheel:SetAlpha(removeWheel.dim and HUB_ALPHA_DIM or 1)

    -- One extra position while there is room: the Add Slice slice.
    local n = CM.RadialSliceCount(wheel)
    local canAdd = n < LAYOUT.MAX_SLICES
    local shown = canAdd and (n + 1) or n
    shownCount = shown
    liveCount = n
    addIndex = canAdd and (n + 1) or nil
    hovered = nil
    PaintWedge()
    bg:SetTexture(ART_PATH .. shown .. ".tga")
    local radius = LAYOUT.ICON_RADIUS * EDITOR_SCALE
    for slot = 1, LAYOUT.MAX_SLICES do
      local button = buttons[slot]
      if slot > n then
        button:Hide()
        button.cx = nil
      else
        -- While reordering, each button glides to the position it would end up in.
        local pos = slot
        if preview then
          for position, source in ipairs(preview) do
            if source == slot then
              pos = position
            end
          end
        end
        local dx, dy = CM.RadialSlotDir(pos, shown)
        button.tx, button.ty = dx * radius, dy * radius
        if not (preview and button.cx) then
          button.cx, button.cy = button.tx, button.ty
          button:ClearAllPoints()
          button:SetPoint("CENTER", area, "CENTER", button.cx, button.cy)
        end
        local entry = wheel.slots and wheel.slots[slot]
        local _, icon, iconText = CM.RadialEntryInfo(entry)
        if entry and icon then
          CM.RadialSetIcon(button.icon, icon, button.iconLabel, iconText)
          button.plus:Hide()
        elseif entry then
          button.iconLabel:SetText("")
          button.icon:SetColorTexture(0, 0, 0, 0) -- the slot disc shows through
          button.plus:Hide()
        else
          button.iconLabel:SetText("")
          button.icon:SetColorTexture(0, 0, 0, 0) -- the slot disc shows through
          button.plus:Show()
        end
        button:Show()
      end
    end
    if canAdd then
      local dx, dy = CM.RadialSlotDir(n + 1, shown)
      PlaceAt(addSlice, area, dx, dy, radius)
      addSlice:Show()
      local o = LAYOUT.OVERLAY[shown]
      if o then
        local a = CM.RadialSlotAngle(n + 1, shown)
        local x = o[3] * math.cos(a) + o[4] * math.sin(a)
        local y = -o[3] * math.sin(a) + o[4] * math.cos(a)
        wedge:SetTexture(SEL_PATH .. shown .. ".tga")
        wedge:SetSize(o[1] * EDITOR_SCALE, o[2] * EDITOR_SCALE)
        wedge:ClearAllPoints()
        wedge:SetPoint("CENTER", area, "CENTER", x * EDITOR_SCALE, y * EDITOR_SCALE)
        wedge:SetRotation(-a)
        wedge:Show()
      end
    else
      addSlice:Hide()
      wedge:Hide()
    end
  end

  UI.Options.RegisterControl({ frame = row, height = height, Refresh = Update })
  Update()
  return row, height
end

---------------------------------------------------------------------------------------
-- Tab
---------------------------------------------------------------------------------------
UI.Options.AddTab({
  id = "radialmenu",
  label = "Radial Menu",
  newFeatureFlag = true,
  build = function(ctx)
    if #CM.RadialGetWheels() == 0 then
      CM.RadialCreateWheel()
    end

    ctx:Header({ text = "RADIAL MENU", newFeatureFlag = true })

    ctx:Description({
      text = "Create custom wheels for spells, items, macros, emotes, and interface shortcuts. Access them directly in Mouse Look: hold the keybind, move your mouse toward the desired slice, then release to activate it. Scroll up or down while the menu is open to switch between wheels.",
    })

    ctx:Keybind({
      label = "Radial Menu Keybind",
      desc = "Hold to open the radial menu, aim at a slice, then release to activate it.",
      get = function()
        return GetBindingKey(BIND_NAME)
      end,
      set = function(key)
        CM.TryApplyBindingChange("radial menu keybinding", function()
          CM.AssignNamedKeybind(BIND_NAME, key)
          CM.RadialRefresh()
        end)
      end,
    })

    ctx:Gap()
    local row, height = BuildWheelRow(ctx)
    ctx:PlaceFrame(row, height)
    -- Custom row: add the search metadata ctx:Place would have attached (also what the wizard focuses).
    if ctx.search then
      UI.Options.RegisterControl({
        frame = row,
        height = height,
        search = {
          label = WHEELS_LABEL,
          desc = "Edit the slices of each wheel, rename wheels and add or remove wheels.",
          tab = ctx.search.tab,
          group = ctx.search.group,
          section = ctx.section,
        },
      })
    end
  end,
})
