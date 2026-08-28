---------------------------------------------------------------------------------------
--  UI/Options/ColorPickerDialog.lua — OPTIONS — themed ColorSelect picker
---------------------------------------------------------------------------------------
--  What it does: CombatMode-styled color picker (hue/sat wheel, value slider, alpha slider,
--  hex field, alpha % field (no labels). Standalone modal via UI.ShowColorPicker;
--  embedded body via UI.CreateEmbeddedColorPicker for editors (no nested modal).
--  Architecture / how it works:
--    • CreateColorPickerBody builds shared ColorSelect chrome on a parent frame.
--    • ShowColorPicker wraps the body with OK/Cancel + baseline restore on cancel.
--    • Embedded instances call onChange live; standalone uses swatchFunc/cancelFunc opts.
--  Does not: Register options controls or persist settings (caller's onChange/set).
--  Related: UI/Options/Draw.lua, UI/Options/OptionsPanel.lua, UI/Options/Widgets.lua,
--  UI/Editors/CrosshairColorsEditor.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame

-- Lua stdlib
local floor = _G.math.floor
local format = _G.string.format
local gsub = _G.string.gsub
local strtrim = _G.strtrim
local tonumber = _G.tonumber
local type = _G.type

local UI = CM.UI
local C = UI.Colors

local WHEEL_SIZE = 120
local SLIDER_W = 32
local SLIDER_GAP = 16
local SLIDER_COL_GAP = 12
local SLIDER_THUMB_W = 32
local SLIDER_THUMB_H = 12
local INPUT_COL_W = 72
local INPUT_ROW_H = 20
local HEX_INPUT_W = 64
local ALPHA_INPUT_W = 36
local INPUT_ROW_GAP = 10
local PICKER_BODY_H = WHEEL_SIZE + INPUT_ROW_GAP + INPUT_ROW_H
local DIALOG_W = 400
local DIALOG_H = 44 + 16 + PICKER_BODY_H + 14 + 28 + 16

local THUMB_ATLAS = "Interface/Buttons/UI-ColorPicker-Buttons"

local dialog
local standalonePicker
local activeOpts
local baseline
local closeReason

local function PickerMountWidth(includeAlpha)
  local w = WHEEL_SIZE + SLIDER_GAP + INPUT_COL_W
  if includeAlpha then
    w = w + SLIDER_COL_GAP + INPUT_COL_W
  end
  return w
end

local function Clamp01(v)
  if v < 0 then
    return 0
  end
  if v > 1 then
    return 1
  end
  return v
end

local function RgbToHex(r, g, b)
  return format(
    "#%02X%02X%02X",
    floor(Clamp01(r) * 255 + 0.5),
    floor(Clamp01(g) * 255 + 0.5),
    floor(Clamp01(b) * 255 + 0.5)
  )
end

local function ParseHex(hex)
  hex = strtrim(hex or "")
  hex = gsub(hex, "^#", "")
  if #hex ~= 6 then
    return nil
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not (r and g and b) then
    return nil
  end
  return r / 255, g / 255, b / 255
end

local function ParseAlphaPercent(text)
  text = strtrim(text or "")
  text = gsub(text, "%%", "")
  local n = tonumber(text)
  if not n then
    return nil
  end
  return Clamp01(n / 100)
end

local function MakeInputBox(parent, width, height)
  height = height or INPUT_ROW_H
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetSize(width, height)
  UI.StyleRounded(box, C.inputBg, C.cardBorder, UI.Radius.control)
  local edit = CreateFrame("EditBox", nil, box)
  edit:SetAutoFocus(false)
  edit:EnableMouse(true)
  UI.SetEditBoxFont(edit, UI.Fonts.desc)
  edit:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  local padX = 6
  local padY = 3
  edit:SetPoint("TOPLEFT", box, "TOPLEFT", padX, -padY)
  edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -padX, padY)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  edit:SetScript("OnEnterPressed", edit.ClearFocus)
  return box, edit
end

--- Shared picker body. Returns API: SetColor, GetColor, SetOnChange, SetHasOpacity,
--- StartPolling, StopPolling, LayoutInParent.
local function CreateColorPickerBody(parent, opts)
  opts = opts or {}
  local picker = {
    hasOpacity = opts.hasOpacity ~= false,
    onChange = opts.onChange,
    suppressUpdates = false,
    pollParent = opts.pollParent,
    pollAccum = 0,
    lastPollR = nil,
    lastPollG = nil,
    lastPollB = nil,
    lastPollA = nil,
  }

  local mount = CreateFrame("Frame", nil, parent)
  mount:SetSize(PickerMountWidth(true), PICKER_BODY_H)
  mount:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  picker.mount = mount

  local function LayoutInParent()
    local parentW = parent:GetWidth()
    if parentW < 1 then
      return
    end
    local mountW = PickerMountWidth(picker.hasOpacity)
    mount:SetWidth(mountW)
    local x = parentW > mountW and (parentW - mountW) / 2 or 0
    mount:ClearAllPoints()
    mount:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
  end
  picker.LayoutInParent = LayoutInParent

  if opts.clipParent ~= false then
    parent:SetClipsChildren(true)
  end

  local colorSelect = CreateFrame("ColorSelect", nil, mount)
  colorSelect:SetSize(PickerMountWidth(true), WHEEL_SIZE)
  colorSelect:SetPoint("TOPLEFT", mount, "TOPLEFT", 0, 0)
  colorSelect:EnableMouse(true)
  colorSelect:SetClipsChildren(true)
  picker.colorSelect = colorSelect

  local wheel = colorSelect:CreateTexture(nil, "ARTWORK")
  wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
  wheel:SetPoint("TOPLEFT", colorSelect, "TOPLEFT", 0, 0)
  colorSelect:SetColorWheelTexture(wheel)

  local wheelThumb = colorSelect:CreateTexture(nil, "OVERLAY")
  wheelThumb:SetTexture(THUMB_ATLAS)
  wheelThumb:SetSize(10, 10)
  wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
  colorSelect:SetColorWheelThumbTexture(wheelThumb)

  local valueColX = WHEEL_SIZE + SLIDER_GAP
  local alphaColX = valueColX + INPUT_COL_W + SLIDER_COL_GAP
  local sliderCenterOffset = (INPUT_COL_W - SLIDER_W) / 2

  local value = colorSelect:CreateTexture(nil, "ARTWORK")
  value:SetSize(SLIDER_W, WHEEL_SIZE)
  value:SetPoint("TOPLEFT", colorSelect, "TOPLEFT", valueColX + sliderCenterOffset, 0)
  colorSelect:SetColorValueTexture(value)

  local valueThumb = colorSelect:CreateTexture(nil, "OVERLAY")
  valueThumb:SetTexture(THUMB_ATLAS)
  valueThumb:SetSize(SLIDER_THUMB_W, SLIDER_THUMB_H)
  valueThumb:SetTexCoord(0.25, 1.0, 0, 0.875)
  colorSelect:SetColorValueThumbTexture(valueThumb)

  local alphaTex = colorSelect:CreateTexture(nil, "ARTWORK")
  alphaTex:SetSize(SLIDER_W, WHEEL_SIZE)
  alphaTex:SetPoint("TOPLEFT", colorSelect, "TOPLEFT", alphaColX + sliderCenterOffset, 0)
  colorSelect:SetColorAlphaTexture(alphaTex)
  picker.alphaTex = alphaTex

  local alphaThumb = colorSelect:CreateTexture(nil, "OVERLAY")
  alphaThumb:SetTexture(THUMB_ATLAS)
  alphaThumb:SetSize(SLIDER_THUMB_W, SLIDER_THUMB_H)
  alphaThumb:SetTexCoord(0.25, 1.0, 0, 0.875)
  colorSelect:SetColorAlphaThumbTexture(alphaThumb)
  picker.alphaThumb = alphaThumb

  local inputY = -(WHEEL_SIZE + INPUT_ROW_GAP)

  local hexCol = CreateFrame("Frame", nil, mount)
  hexCol:SetSize(INPUT_COL_W, INPUT_ROW_H)
  hexCol:SetPoint("TOPLEFT", mount, "TOPLEFT", valueColX, inputY)

  local hexBox
  local hexEdit
  hexBox, hexEdit = MakeInputBox(hexCol, HEX_INPUT_W, INPUT_ROW_H)
  hexBox:SetPoint("CENTER", hexCol, "CENTER")
  hexEdit:SetMaxLetters(7)
  picker.hexEdit = hexEdit

  local alphaCol = CreateFrame("Frame", nil, mount)
  alphaCol:SetSize(INPUT_COL_W, INPUT_ROW_H)
  alphaCol:SetPoint("TOPLEFT", mount, "TOPLEFT", alphaColX, inputY)

  local alphaBox
  local alphaEdit
  alphaBox, alphaEdit = MakeInputBox(alphaCol, ALPHA_INPUT_W, INPUT_ROW_H)
  alphaBox:SetPoint("CENTER", alphaCol, "CENTER")
  alphaEdit:SetMaxLetters(4)
  picker.alphaEdit = alphaEdit

  local function ReadCurrent()
    local r, g, b = colorSelect:GetColorRGB()
    local a = picker.hasOpacity and colorSelect:GetColorAlpha() or 1
    return r, g, b, a
  end

  local function UpdateHexField(r, g, b)
    if not hexEdit or hexEdit:HasFocus() then
      return
    end
    picker.suppressUpdates = true
    hexEdit:SetText(RgbToHex(r, g, b))
    picker.suppressUpdates = false
  end

  local function UpdateAlphaField(a)
    if not alphaEdit or alphaEdit:HasFocus() then
      return
    end
    picker.suppressUpdates = true
    alphaEdit:SetText(tostring(floor(Clamp01(a) * 100 + 0.5)))
    picker.suppressUpdates = false
  end

  local function FireChange()
    if picker.suppressUpdates or not picker.onChange then
      return
    end
    local r, g, b, a = ReadCurrent()
    picker.onChange(r, g, b, a)
  end

  local function SyncFieldsFromPicker()
    local r, g, b, a = ReadCurrent()
    UpdateHexField(r, g, b)
    UpdateAlphaField(a)
    FireChange()
  end

  local function ApplyHexFromEdit()
    if picker.suppressUpdates or not hexEdit then
      return
    end
    local r, g, b = ParseHex(hexEdit:GetText())
    if not r then
      local cr, cg, cb = ReadCurrent()
      UpdateHexField(cr, cg, cb)
      return
    end
    picker.suppressUpdates = true
    colorSelect:SetColorRGB(r, g, b)
    picker.suppressUpdates = false
    SyncFieldsFromPicker()
  end

  local function ApplyAlphaFromEdit()
    if picker.suppressUpdates or not alphaEdit or not picker.hasOpacity then
      return
    end
    local a = ParseAlphaPercent(alphaEdit:GetText())
    if not a then
      UpdateAlphaField(ReadCurrent())
      return
    end
    picker.suppressUpdates = true
    colorSelect:SetColorAlpha(a)
    picker.suppressUpdates = false
    SyncFieldsFromPicker()
  end

  hexEdit:HookScript("OnEditFocusLost", ApplyHexFromEdit)
  hexEdit:HookScript("OnEnterPressed", function(self)
    ApplyHexFromEdit()
    self:ClearFocus()
  end)
  alphaEdit:HookScript("OnEditFocusLost", ApplyAlphaFromEdit)
  alphaEdit:HookScript("OnEnterPressed", function(self)
    ApplyAlphaFromEdit()
    self:ClearFocus()
  end)

  colorSelect:SetScript("OnColorSelect", function()
    SyncFieldsFromPicker()
  end)

  local function PollPicker(_, elapsed)
    if not picker.colorSelect then
      return
    end
    picker.pollAccum = (picker.pollAccum or 0) + elapsed
    if picker.pollAccum < 0.05 then
      return
    end
    picker.pollAccum = 0
    local r, g, b, a = ReadCurrent()
    if
      r == picker.lastPollR
      and g == picker.lastPollG
      and b == picker.lastPollB
      and a == picker.lastPollA
    then
      return
    end
    picker.lastPollR, picker.lastPollG, picker.lastPollB, picker.lastPollA = r, g, b, a
    SyncFieldsFromPicker()
  end
  picker._pollFn = PollPicker

  function picker.SetHasOpacity(show)
    picker.hasOpacity = show ~= false
    if alphaTex then
      if picker.hasOpacity then
        alphaTex:Show()
      else
        alphaTex:Hide()
      end
    end
    if alphaThumb then
      if picker.hasOpacity then
        alphaThumb:Show()
      else
        alphaThumb:Hide()
      end
    end
    if alphaCol then
      if picker.hasOpacity then
        alphaCol:Show()
      else
        alphaCol:Hide()
      end
    end
    local w = PickerMountWidth(picker.hasOpacity)
    colorSelect:SetWidth(w)
    mount:SetWidth(w)
    LayoutInParent()
  end

  function picker.SetColor(r, g, b, a)
    r = Clamp01(r or 1)
    g = Clamp01(g or 1)
    b = Clamp01(b or 1)
    a = Clamp01(a or 1)
    picker.suppressUpdates = true
    colorSelect:SetColorRGB(r, g, b)
    if picker.hasOpacity then
      colorSelect:SetColorAlpha(a)
    else
      colorSelect:SetColorAlpha(1)
    end
    picker.suppressUpdates = false
    UpdateHexField(r, g, b)
    UpdateAlphaField(a)
    picker.lastPollR, picker.lastPollG, picker.lastPollB, picker.lastPollA = r, g, b, a
    picker.pollAccum = 0
  end

  function picker.GetColor()
    return ReadCurrent()
  end

  function picker.SetOnChange(fn)
    picker.onChange = fn
  end

  function picker.StartPolling()
    local host = picker.pollParent
    if host and picker._pollFn then
      host:SetScript("OnUpdate", picker._pollFn)
    end
  end

  function picker.StopPolling()
    local host = picker.pollParent
    if host then
      host:SetScript("OnUpdate", nil)
    end
  end

  picker.SetHasOpacity(picker.hasOpacity)
  LayoutInParent()
  return picker
end

--- Embeds the picker body on `parent` (no OK/Cancel). opts.onChange(r,g,b,a) fires live.
function UI.CreateEmbeddedColorPicker(parent, opts)
  opts = opts or {}
  opts.pollParent = opts.pollParent or parent
  return CreateColorPickerBody(parent, opts)
end

local function MakePillButton(parent, label, onClick)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(96, 28)
  local IDLE = { 0.16, 0.16, 0.16, 1 }
  local HOVER = { 0.26, 0.26, 0.26, 1 }
  UI.StylePill(btn, IDLE, { 0, 0, 0, 0 })
  local text = UI.CreateFontString(btn, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(label)
  text:SetTextColor(C.text[1], C.text[2], C.text[3])
  btn:SetScript("OnEnter", function(self)
    self:cmSetFill(HOVER[1], HOVER[2], HOVER[3], HOVER[4])
    text:SetTextColor(1, 1, 1)
  end)
  btn:SetScript("OnLeave", function(self)
    self:cmSetFill(IDLE[1], IDLE[2], IDLE[3], IDLE[4])
    text:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  btn:SetScript("OnClick", onClick)
  return btn
end

local function HideDialog(reason)
  closeReason = reason or closeReason or "cancel"
  if standalonePicker then
    standalonePicker.StopPolling()
  end
  if dialog then
    dialog:Hide()
  end
end

local function OnDialogHidden()
  local opts = activeOpts
  local pv = baseline
  local reason = closeReason
  activeOpts = nil
  baseline = nil
  closeReason = nil
  if reason ~= "accept" and opts and opts.cancelFunc and pv and standalonePicker then
    standalonePicker.SetColor(pv.r, pv.g, pv.b, pv.opacity or pv.a)
    opts.cancelFunc(pv)
  end
end

local function DoCancel()
  HideDialog("cancel")
end

local function DoAccept()
  HideDialog("accept")
end

local function EnsureStandaloneDialog()
  if dialog then
    return dialog
  end

  dialog = UI.CreateBareWindow("CombatModeColorPickerDialog", "Color", DIALOG_W, DIALOG_H)
  dialog:Hide()

  local content = CreateFrame("Frame", nil, dialog)
  content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -44)
  content:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -16, 16)

  standalonePicker = CreateColorPickerBody(content, {
    pollParent = dialog,
    onChange = function(r, g, b, a)
      if activeOpts and activeOpts.swatchFunc then
        activeOpts.swatchFunc(r, g, b, a)
      end
    end,
  })

  local btnRow = CreateFrame("Frame", nil, content)
  btnRow:SetSize(200, 28)
  btnRow:SetPoint("TOPLEFT", standalonePicker.mount, "BOTTOMLEFT", 0, -14)

  local cancelBtn = MakePillButton(btnRow, "Cancel", DoCancel)
  cancelBtn:SetPoint("TOPRIGHT", btnRow, "TOPRIGHT", 0, 0)
  local okBtn = MakePillButton(btnRow, "OK", DoAccept)
  okBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -8, 0)

  dialog:SetScript("OnHide", OnDialogHidden)

  return dialog
end

--- Opens the themed picker modal. opts: r/g/b/opacity, hasOpacity, swatchFunc(r,g,b,a),
--- cancelFunc(previousValues).
function UI.ShowColorPicker(opts)
  opts = opts or {}
  closeReason = nil
  local win = EnsureStandaloneDialog()
  activeOpts = opts

  local r = Clamp01(opts.r or 1)
  local g = Clamp01(opts.g or 1)
  local b = Clamp01(opts.b or 1)
  local a = Clamp01(opts.opacity or opts.a or 1)
  baseline = { r = r, g = g, b = b, opacity = a, a = a }

  if opts.title and win.titleText then
    win.titleText:SetText(UI.StripColors(opts.title) or "Color")
  elseif win.titleText then
    win.titleText:SetText("Color")
  end

  standalonePicker.SetHasOpacity(opts.hasOpacity ~= false)
  standalonePicker.SetColor(r, g, b, a)
  standalonePicker.StartPolling()

  win:Show()
end

UI.PickerBodyHeight = PICKER_BODY_H
