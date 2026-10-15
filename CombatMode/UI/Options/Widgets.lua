---------------------------------------------------------------------------------------
--  UI/Options/Widgets.lua — OPTIONS — control factories
---------------------------------------------------------------------------------------
--  What it does: Factories for toggles, sliders, dropdowns, keybind capture, text inputs,
--  headers, gaps, Confirm/Notify/ShowCopyLink dialogs, ShowWelcome, and SyncControls registration.
--  Tabs supply get/set closures; widgets stay feature-API agnostic.
--  Architecture / how it works:
--    • UI.Options.controls registry; Options.Sync() refreshes values + disabled state.
--    • Sliders: opts.default; right-click resets to that value. Minus/plus icons
--      step by opts.step (dim until hover) and stop at min/max.
--    • Dropdown menus match the select's laid-out width.
--    • Layout helpers (NewLayout) used by tabs and nested hosts (e.g. Camera/DynamicCam).
--    • charSpecific badge + tooltips for per-character settings.
--    • newFeatureFlag — shared "NEW" atlas badge (Alliance) beside section/option titles;
--      sidebar tabs use the Horde atlas via OptionsPanel.
--  Does not: Call CM feature apply functions except via tab-provided set() callbacks.
--  Related: UI/Options/Draw.lua, UI/Options/ColorPickerDialog.lua,
--  UI/Options/SpellMultiSelect.lua, UI/Options/OptionsPanel.lua,
--  UI/Options/Tabs/TabGeneral.lua, UI/Options/Tabs/TabCrosshair.lua,
--  UI/Options/Tabs/TabClickCasting.lua
--  MakeButton `layout = "row"` — title left, action pill right (e.g. Reaction Colors).
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateColor = _G.CreateColor
local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local C_Texture = _G.C_Texture
local GetCurrentKeyBoardFocus = _G.GetCurrentKeyBoardFocus
local IsMouseButtonDown = _G.IsMouseButtonDown
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local tinsert = _G.table.insert
local tsort = _G.table.sort
local abs = _G.math.abs
local floor = _G.math.floor
local max = _G.math.max
local min = _G.math.min
local strfind = _G.string.find
local strlower = _G.string.lower
local strtrim = _G.string.trim
local tconcat = _G.table.concat
local tremove = _G.table.remove
local tostring = _G.tostring
local type = _G.type

local UI = CM.UI
local C = UI.Colors
local DISABLED_A = C.disabledAlpha or 0.5
UI.Options = UI.Options or {}
local Options = UI.Options
Options.controls = Options.controls or {}
-- Section headers registered by ctx:Header, for the options search: { label, tab, group, header, lastFrame }.
Options.sections = Options.sections or {}

local ROW_H = 30

---------------------------------------------------------------------------------------
--                                 SHARED HELPERS                                    --
---------------------------------------------------------------------------------------
--- Refreshes every registered control (values + enabled state). Cheap; called on
--- panel open and after any set() that could change another control's disabled state.
-- Layouts with rows that can be hidden register a re-flow here (see ctx:Reflow).
Options.reflowHooks = Options.reflowHooks or {}
function Options.AddReflowHook(hook)
  tinsert(Options.reflowHooks, hook)
end

function Options.Sync()
  for _, control in ipairs(Options.controls) do
    if control.Refresh then
      control.Refresh()
    end
    if control.UpdateCharScopeTag then
      control.UpdateCharScopeTag()
    end
  end
  for _, hook in ipairs(Options.reflowHooks) do
    hook()
  end
end

local function Register(control)
  if control.UpdateCharScopeTag then
    local prevRefresh = control.Refresh
    function control.Refresh()
      if prevRefresh then
        prevRefresh()
      end
      control.UpdateCharScopeTag()
    end
  end
  tinsert(Options.controls, control)
  return control
end

local function IsDisabled(opts)
  return type(opts.disabled) == "function" and opts.disabled() or opts.disabled == true
end

--- Shared by SpellMultiSelect.lua (loaded after this file).
Options.RegisterControl = Register
Options.IsDisabled = IsDisabled

--- Full-row hover highlight (mirrors the left sidebar tab hover): a subtle rounded
--- background band shown while the cursor is anywhere over the row or its interactive
--- control(s). Extra args are inner mouse-enabled controls (button/slider/editbox); omit
--- when the row itself is the hit target. Disabled options never show the highlight.
--- MouseIsOver guards prevent flicker when moving between row and child. The highlight
--- is painted as BACKGROUND textures on the row so it never covers the label or control.
local function AddRowHover(row, opts, ...)
  local bounds = CreateFrame("Frame", nil, row)
  -- Keep the wash inside the scroll child. Extending left of the row causes the
  -- ScrollFrame clipping boundary to cut off the left corner masks.
  bounds:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 2)
  bounds:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, -2)
  bounds:EnableMouse(false)

  local hl = UI.CreateRoundedHover(row, bounds)

  local hots = { ... }

  local function show()
    if opts and IsDisabled(opts) then
      hl.Hide()
      return
    end
    hl.Show()
  end
  local function hide()
    if row:IsMouseOver() then
      return
    end
    for i = 1, #hots do
      local hot = hots[i]
      if hot and hot:IsMouseOver() then
        return
      end
    end
    hl.Hide()
  end

  -- Refresh() calls this when a control flips to disabled while the cursor is still over it.
  row.cmClearHover = function()
    hl.Hide()
  end

  row:EnableMouse(true)
  row:HookScript("OnEnter", show)
  row:HookScript("OnLeave", hide)
  for i = 1, #hots do
    local hot = hots[i]
    if hot and hot ~= row then
      hot:HookScript("OnEnter", show)
      hot:HookScript("OnLeave", hide)
    end
  end
end

---------------------------------------------------------------------------------------
--                                 CONFIRM DIALOG                                     --
---------------------------------------------------------------------------------------
local CONFIRM_W = 400
local CONFIRM_PAD = 18
-- Title art at its true display aspect (CM.Constants.TitleAspect).
local CONFIRM_TITLE_W, CONFIRM_TITLE_H = CM.Constants.TitleSize(36)
-- The welcome popup shows the wordmark larger than the other dialogs.
local WELCOME_TITLE_W, WELCOME_TITLE_H = CM.Constants.TitleSize(64)
local CONFIRM_BTN_W = 116
local CONFIRM_BTN_H = UI.Sizes.control
local confirmDialog
local welcomeDialog

--- Wordmark row, horizontally centered under the dialog top edge (no logo).
local function AttachBrandedHeader(dialog, width, height)
  local header = CreateFrame("Frame", nil, dialog)
  header:SetSize(width or CONFIRM_TITLE_W, height or CONFIRM_TITLE_H)
  header:SetPoint("TOP", dialog, "TOP", 0, -CONFIRM_PAD)

  local titleArt = header:CreateTexture(nil, "ARTWORK")
  titleArt:SetTexture(CM.Constants.Title)
  titleArt:SetAllPoints(header)

  return header
end

--- Pill button matching UI.MakeButton, minus the layout row wrapper. `variant` is a UI.StyleControl
--- variant ("primary" / "danger"); nil is the neutral look.
local function CreateDialogButton(parent, label, variant)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(CONFIRM_BTN_W, CONFIRM_BTN_H)
  UI.StyleControl(button, variant)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(UI.StripColors(label) or "")
  UI.WireControlHover(button, text)
  button.text = text
  return button
end

-- Exposed so the setup wizard's windows can reuse the dialog button look.
UI.CreateDialogButton = CreateDialogButton

--- Builds the single reusable confirm window. The full-screen blocker underneath makes
--- the dialog modal without dismissing it on an outside click, so the choice stays
--- explicit; ESC and the No button cancel.
local function BuildConfirmDialog()
  local blocker = CreateFrame("Button", nil, UIParent)
  blocker:SetAllPoints(UIParent)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  blocker:EnableMouse(true)
  blocker:Hide()

  local dim = blocker:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(blocker)
  dim:SetColorTexture(0, 0, 0, 0.55)

  local dialog = CreateFrame("Frame", "CombatModeConfirmDialog", UIParent)
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog:SetFrameLevel(blocker:GetFrameLevel() + 10)
  dialog:SetToplevel(true)
  dialog:SetSize(CONFIRM_W, 120)
  UI.StyleWindow(dialog)
  dialog:Hide()

  -- Branded header mirroring the main options window title bar (logo + wordmark art).
  local header = AttachBrandedHeader(dialog)

  local message = UI.CreateFontString(dialog, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  message:SetPoint("TOP", header, "BOTTOM", 0, -12)
  message:SetWidth(CONFIRM_W - (2 * CONFIRM_PAD))
  message:SetJustifyH("CENTER")
  message:SetJustifyV("TOP")
  message:SetWordWrap(true)
  message:SetTextColor(C.text[1], C.text[2], C.text[3])

  local accept = CreateDialogButton(dialog, _G.YES or "Yes")
  local cancel = CreateDialogButton(dialog, _G.NO or "No")
  cancel:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 5, CONFIRM_PAD)

  accept:SetScript("OnClick", function()
    local handler = dialog.onAccept
    dialog:Hide()
    if handler then
      handler()
    end
  end)
  cancel:SetScript("OnClick", function()
    dialog:Hide()
  end)

  -- Covers every close path (No, Okay, ESC via UISpecialFrames): the blocker never
  -- lingers and onClose fires exactly once regardless of how the dialog was dismissed.
  dialog:SetScript("OnHide", function(self)
    blocker:Hide()
    local onClose = self.onClose
    self.onAccept = nil
    self.onClose = nil
    if onClose then
      onClose()
    end
  end)

  UI.EnableEscClose(dialog, "CombatModeConfirmDialog")

  dialog.blocker = blocker
  dialog.message = message
  dialog.accept = accept
  dialog.cancel = cancel
  return dialog
end

--- Lays out, positions and shows the shared modal. `single` collapses the button row to
--- one centered Okay (UI.Notify); otherwise Yes/No are paired (UI.Confirm).
local function ShowDialog(text, single, onAccept, onClose)
  confirmDialog = confirmDialog or BuildConfirmDialog()
  local dialog = confirmDialog

  dialog.message:SetText(UI.StripColors(text) or "")
  dialog.onAccept = onAccept
  dialog.onClose = onClose

  dialog.accept:ClearAllPoints()
  if single then
    dialog.cancel:Hide()
    dialog.accept.text:SetText(_G.OKAY or "Okay")
    dialog.accept:SetPoint("BOTTOM", dialog, "BOTTOM", 0, CONFIRM_PAD)
  else
    dialog.cancel:Show()
    dialog.accept.text:SetText(_G.YES or "Yes")
    dialog.accept:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -5, CONFIRM_PAD)
  end

  dialog:SetHeight(
    CONFIRM_PAD
      + CONFIRM_TITLE_H
      + 12
      + dialog.message:GetStringHeight()
      + 16
      + CONFIRM_BTN_H
      + CONFIRM_PAD
  )

  -- Centered on the options window when it is open so the choice reads in context.
  local anchor = CM.GetOptionsFrame and CM.GetOptionsFrame()
  dialog:ClearAllPoints()
  if anchor and anchor:IsShown() then
    dialog:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  else
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  dialog.blocker:Show()
  dialog:Show()
  dialog:Raise()
end

--- Themed replacement for Blizzard's StaticPopup confirm: a branded modal window whose
--- body text is stripped of color markup like every other option string.
function UI.Confirm(text, onAccept)
  ShowDialog(text, false, onAccept, nil)
end

--- Single-button informational modal (generic Notify). Prefer UI.ShowWelcome for the
--- first-install greeting — that uses a dedicated frame deferred past load-end UI reset.
function UI.Notify(text, onClose)
  ShowDialog(text, true, nil, onClose)
end

---------------------------------------------------------------------------------------
--                              COPY LINK POPUP                                       --
---------------------------------------------------------------------------------------
-- LaunchURL / CopyToClipboard are protected from addons. Show an EditBox with the URL
-- highlighted so the player can Ctrl+C, then paste in a browser.
local COPY_LINK_W = 360
local COPY_LINK_INPUT_H = 28
local copyLinkDialog

local function BuildCopyLinkDialog()
  local blocker = CreateFrame("Button", nil, UIParent)
  blocker:SetAllPoints(UIParent)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  blocker:SetFrameLevel(9000)
  blocker:EnableMouse(true)
  blocker:Hide()

  local dim = blocker:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(blocker)
  dim:SetColorTexture(0, 0, 0, 0.55)

  local dialog = CreateFrame("Frame", "CombatModeCopyLinkDialog", UIParent)
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog:SetFrameLevel(blocker:GetFrameLevel() + 10)
  dialog:SetToplevel(true)
  dialog:SetSize(COPY_LINK_W, 160)
  UI.StyleWindow(dialog)
  dialog:EnableMouse(true)
  dialog:Hide()

  local header = AttachBrandedHeader(dialog)

  local message = UI.CreateFontString(dialog, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  message:SetPoint("TOP", header, "BOTTOM", 0, -12)
  message:SetWidth(COPY_LINK_W - (2 * CONFIRM_PAD))
  message:SetJustifyH("CENTER")
  message:SetJustifyV("TOP")
  message:SetWordWrap(true)
  message:SetTextColor(C.text[1], C.text[2], C.text[3])

  local box = CreateFrame("Frame", nil, dialog)
  box:SetHeight(COPY_LINK_INPUT_H)
  box:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -12)
  box:SetPoint("TOPRIGHT", message, "BOTTOMRIGHT", 0, -12)
  UI.StyleField(box)

  local edit = CreateFrame("EditBox", nil, box)
  edit:SetAutoFocus(false)
  edit:EnableMouse(true)
  UI.SetEditBoxFont(edit)
  edit:SetTextColor(C.text[1], C.text[2], C.text[3])
  edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -4)
  edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 4)
  edit:SetScript("OnEscapePressed", function()
    dialog:Hide()
  end)
  edit:SetScript("OnEnterPressed", function(self)
    self:HighlightText()
  end)
  -- Keep the URL intact if the player types over it; selection is for Ctrl+C only.
  edit:SetScript("OnTextChanged", function(self, userInput)
    if not userInput then
      return
    end
    local locked = self.cmUrl
    if locked and self:GetText() ~= locked then
      self:SetText(locked)
      self:HighlightText()
    end
  end)
  box:EnableMouse(true)
  box:SetScript("OnMouseDown", function()
    edit:SetFocus()
    edit:HighlightText()
  end)

  local okay = CreateDialogButton(dialog, _G.OKAY or "Okay")
  okay:SetPoint("BOTTOM", dialog, "BOTTOM", 0, CONFIRM_PAD)
  okay:SetScript("OnClick", function()
    dialog:Hide()
  end)

  dialog:SetScript("OnHide", function()
    blocker:Hide()
    edit:ClearFocus()
    edit.cmUrl = nil
  end)
  dialog:SetScript("OnShow", function()
    edit:SetFocus()
    edit:HighlightText()
  end)

  UI.EnableEscClose(dialog, "CombatModeCopyLinkDialog")

  dialog.blocker = blocker
  dialog.message = message
  dialog.edit = edit
  return dialog
end

--- Modal with a read-locked EditBox containing `url`. Player Ctrl+C then pastes outside WoW.
function UI.ShowCopyLink(url, label)
  if type(url) ~= "string" or url == "" then
    return
  end

  copyLinkDialog = copyLinkDialog or BuildCopyLinkDialog()
  local dialog = copyLinkDialog
  local name = (type(label) == "string" and label ~= "") and label or "Link"

  dialog.message:SetText("Copy the " .. name .. " link (Ctrl+C), then paste it in your browser.")
  dialog.edit.cmUrl = url
  dialog.edit:SetText(url)

  dialog:SetHeight(
    CONFIRM_PAD
      + CONFIRM_TITLE_H
      + 12
      + dialog.message:GetStringHeight()
      + 12
      + COPY_LINK_INPUT_H
      + 16
      + CONFIRM_BTN_H
      + CONFIRM_PAD
  )

  local anchor = CM.GetOptionsFrame and CM.GetOptionsFrame()
  dialog:ClearAllPoints()
  if anchor and anchor:IsShown() then
    dialog:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  else
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end

  dialog.blocker:Show()
  dialog:Show()
  dialog:Raise()
  dialog.edit:SetFocus()
  dialog.edit:HighlightText()
end

---------------------------------------------------------------------------------------
--                                 WELCOME MODAL                                      --
---------------------------------------------------------------------------------------
-- Dedicated first-install window (not the shared Confirm/Notify dialog). Kept out of
-- UISpecialFrames so Blizzard's load-end CloseSpecialWindows cannot dismiss it before
-- the player sees it; ESC is handled locally instead.
local WELCOME_W = 440

local function BuildWelcomeDialog()
  local blocker = CreateFrame("Button", nil, UIParent)
  blocker:SetAllPoints(UIParent)
  blocker:SetFrameStrata("FULLSCREEN_DIALOG")
  blocker:SetFrameLevel(9000)
  blocker:EnableMouse(true)
  blocker:Hide()

  local dim = blocker:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(blocker)
  dim:SetColorTexture(0, 0, 0, 0.55)

  local dialog = CreateFrame("Frame", "CombatModeWelcomeDialog", UIParent)
  dialog:SetFrameStrata("FULLSCREEN_DIALOG")
  dialog:SetFrameLevel(blocker:GetFrameLevel() + 10)
  dialog:SetToplevel(true)
  dialog:SetSize(WELCOME_W, 120)
  UI.StyleWindow(dialog)
  dialog:EnableMouse(true)
  dialog:Hide()

  local header = AttachBrandedHeader(dialog, WELCOME_TITLE_W, WELCOME_TITLE_H)

  local message = UI.CreateFontString(dialog, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  message:SetPoint("TOP", header, "BOTTOM", 0, -12)
  message:SetWidth(WELCOME_W - (2 * CONFIRM_PAD))
  message:SetJustifyH("CENTER")
  message:SetJustifyV("TOP")
  message:SetWordWrap(true)
  message:SetTextColor(C.text[1], C.text[2], C.text[3])

  local okay = CreateDialogButton(dialog, _G.OKAY or "Okay")
  okay:SetPoint("BOTTOM", dialog, "BOTTOM", 0, CONFIRM_PAD)
  okay:SetScript("OnClick", function()
    dialog:Hide()
  end)

  dialog:SetScript("OnHide", function(self)
    blocker:Hide()
    local onClose = self.onClose
    self.onClose = nil
    if onClose then
      onClose()
    end
  end)

  -- ESC closes without UISpecialFrames (avoids load-end CloseSpecialWindows race).
  dialog:SetScript("OnShow", function(self)
    self:EnableKeyboard(true)
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(false)
    end
  end)
  dialog:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:Hide()
    end
  end)

  dialog.blocker = blocker
  dialog.message = message
  return dialog
end

--- First-install welcome modal. Call after the loading screen settles (Runtime defers).
--- Keeps inline |cff| color markup so slash-command hints can stay blue/red.
function UI.ShowWelcome(text, onClose)
  welcomeDialog = welcomeDialog or BuildWelcomeDialog()
  local dialog = welcomeDialog

  dialog.message:SetText(text or "")
  dialog.onClose = onClose

  local msgH = dialog.message:GetStringHeight() or 40
  if msgH < 1 then
    msgH = 60
  end
  dialog:SetHeight(CONFIRM_PAD + WELCOME_TITLE_H + 12 + msgH + 16 + CONFIRM_BTN_H + CONFIRM_PAD)

  dialog:ClearAllPoints()
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  dialog.blocker:Show()
  dialog.blocker:Raise()
  dialog:Show()
  dialog:Raise()
end

--- Split-menu-style option row: left ~60% holds the title + helper text stacked
--- tightly; right ~40% holds the interactive control. The text block and the control
--- are vertically centered against each other within the row. `opts.labelInset` is
--- accepted for back-compat but ignored.
local TEXT_FRAC = 0.58
local ROW_PAD_X = 8

--- Round glyph badge (the code-box "?" help button, the character-specific "C"): two stacked
--- discs (UI.CreateCircle) with the button outline gradient on the ring and the button fill
--- gradient on the face, and a cream glyph. `size` is the outer diameter; (dx, dy) nudge the
--- glyph so it looks centred; optional `fontSize` / `color` override the glyph (default: button
--- font size, cream). Returns the badge with badge:SetHover(on) for the lighter fill.
local function CreateGlyphBadge(parent, size, glyph, dx, dy, fontSize, color)
  local function Gradient(tex, top, bottom)
    -- Vertical gradients take the minimum colour at the bottom edge.
    tex:SetGradient(
      "VERTICAL",
      CreateColor(bottom[1], bottom[2], bottom[3], 1),
      CreateColor(top[1], top[2], top[3], 1)
    )
  end
  local badge = {}
  local ring = UI.CreateCircle(parent, "BACKGROUND", C.white)
  ring:SetSize(size, size)
  ring:SetPoint("CENTER", parent, "CENTER", 0, 0)
  Gradient(ring, C.controlBorderTop, C.controlBorderBottom)
  local face = UI.CreateCircle(parent, "ARTWORK", C.white)
  face:SetSize(size - 2, size - 2)
  face:SetPoint("CENTER", parent, "CENTER", 0, 0)
  Gradient(face, C.controlFillTop, C.controlFill)
  local mark = UI.CreateFontString(parent, "OVERLAY", fontSize or UI.Fonts.button, "GameFontNormal")
  mark:SetPoint("CENTER", parent, "CENTER", dx or 0, dy or 0)
  mark:SetJustifyH("CENTER")
  mark:SetText(glyph)
  color = color or C.text
  mark:SetTextColor(color[1], color[2], color[3])
  function badge.SetHover(_, on)
    if on then
      Gradient(face, C.buttonHoverTop, C.buttonHover)
    else
      Gradient(face, C.controlFillTop, C.controlFill)
    end
  end
  badge.ring, badge.face, badge.mark = ring, face, mark
  return badge
end

local SetMenuBarActive = UI.SetMenuBarActive
-- Section headers and the description under them keep their original inset (no row padding).
local HEADER_PAD_X = 4
-- Rule under section headers: Blizzard atlas, height capped so a tall ornament stays a line.
local HEADER_RULE_ATLAS = "evergreen-weeklyrewards-header"
local HEADER_RULE_MAX_H = 8
-- The atlas rule is centred and this fraction of the header width.
local HEADER_RULE_WIDTH_FRAC = 0.6
local ROW_PAD_Y = 4
local CODE_STATUS_H = 18 -- height of a code box's diagnostic strip along its bottom
local CODE_GUTTER_W = 18 -- width of a code box's line-number strip (two digits)
local CODE_STRIP_INSET = 1 -- the strips sit flush against the input well's 1px outline
local CODE_GUTTER_GAP = 5 -- gap between the line-number strip and the code
local TEXT_GAP = 4
local DESC_BELOW_GAP = 6
local CONTROL_GAP = 20
local ICON_GAP = 6
local DEFAULT_ICON_SIZE = 20
local CHAR_SCOPE_MARK = "C"
local CHAR_SCOPE_MARK_W = 14
local CHAR_SCOPE_MARK_GAP = 4
local CHAR_SCOPE_TOOLTIP = "Character-specific option."

-- "NEW" tag for tabs and options: small accent-coloured text, superscript style, at the top
-- right of the label it belongs to. Drawn by the addon so it follows the theme accent.
UI.NewFeatureBadge = {
  size = 8, -- font size
  gap = 3, -- space after the label text
  headerGap = 4,
  lift = 3, -- how far the tag's top sits above the label's top
}

--- NEW tag frame. Caller places it (PlaceNewFeatureBadge, or beside a tab label).
function UI.CreateNewFeatureBadge(parent)
  local badge = CreateFrame("Frame", nil, parent)
  badge:SetFrameLevel(parent:GetFrameLevel() + 5)
  badge:SetSize(22, 10)
  local text = UI.CreateFontString(badge, "OVERLAY", UI.NewFeatureBadge.size, "GameFontNormal")
  text:SetPoint("TOPLEFT", badge, "TOPLEFT", 0, 0)
  text:SetText("NEW")
  text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  badge.text = text
  return badge
end

--- Sit at the top right of the title text (superscript style).
--- When `afterRegion` is shown (e.g. the © hit frame), place after that instead.
--- Optional `gapOverride` (e.g. headerGap) adjusts spacing for section titles.
function UI.PlaceNewFeatureBadge(badge, label, labelW, afterRegion, gapOverride)
  if not badge or not label then
    return
  end
  badge:ClearAllPoints()
  local gap = gapOverride
  if gap == nil then
    gap = UI.NewFeatureBadge.gap
  end
  local lift = UI.NewFeatureBadge.lift
  if afterRegion and afterRegion.IsShown and afterRegion:IsShown() then
    badge:SetPoint("TOPLEFT", afterRegion, "TOPRIGHT", gap, 2)
    return
  end
  local titleW = label:GetStringWidth() or 0
  if labelW and titleW > labelW then
    titleW = labelW
  end
  badge:SetPoint("TOPLEFT", label, "TOPLEFT", titleW + gap, lift)
end

--- Place the © immediately after the title glyphs (not at the right edge of the
--- label's wrap box), vertically centered on the title line.
local function PlaceCharScopeMark(scopeTag, label, labelW)
  local titleW = label:GetStringWidth() or 0
  if titleW > labelW then
    titleW = labelW
  end
  local markX = titleW + CHAR_SCOPE_MARK_GAP
  local maxX = max(labelW - CHAR_SCOPE_MARK_W, 0)
  if markX > maxX then
    markX = maxX
  end
  scopeTag:ClearAllPoints()
  -- LEFT/LEFT centers the mark on the title FontString's height (the title line).
  scopeTag:SetPoint("LEFT", label, "LEFT", markX, 0)
end

local function AddRowLabel(row, text, allowColors, size)
  local label = UI.CreateFontString(row, "OVERLAY", size or UI.Fonts.base, "GameFontHighlight")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X, -ROW_PAD_Y)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWordWrap(true)
  local display = allowColors and text or UI.StripColors(text)
  label:SetText(display or "")
  label:SetTextColor(C.text[1], C.text[2], C.text[3])
  row.label = label
  return label
end

local function CharSpecificEnabled(opts)
  local v = opts and opts.charSpecific
  if type(v) == "function" then
    return v() and true or false
  end
  return v and true or false
end

--- Attaches opts.desc and installs SetWidthTo. Default layout is the split-menu-style
--- 60/40 split (title+helper left, control right, vertically centered). When
--- `opts.descBelow` is set, the title shares a top band with the control and the helper
--- spans the full row width underneath (used by the narrow sidebar footer).
--- `opts.iconAtlas` / `opts.iconSize` place a texture left of the title.
--- Optional `opts.iconWidth` / `opts.iconHeight` keep non-square atlases (e.g. 52x69
--- mouse icons). Optional `opts.leadingIconTexture` (BLP path) sits to the left of
--- `iconAtlas` (Click Casting Ctrl/Shift/Alt + mouse). When `opts.iconFitText` is set,
--- icons grow to the title+helper block height (width scales with aspect) and are
--- vertically centered against that whole column.
--- `opts.charSpecific` places a blue © to the right of the title (bool or function).
--- `opts.newFeatureFlag` places the Alliance "NEW" badge to the right of the title.
--- `control.widgetH` / `control.widgetFill` / `control.textFrac` behave as elsewhere
--- (multiline inputs use textFrac 0.40 so the box gets ~60%).
local function AttachOptionText(control, row, opts, widgetH)
  -- Horizontal row padding; the narrow sidebar footer passes a smaller `padX`.
  local padX = opts.padX or ROW_PAD_X
  control.widgetH = widgetH or ROW_H
  control.descBelow = opts.descBelow and true or nil
  control.iconFitText = opts.iconFitText and true or nil
  control.charSpecificOpt = opts.charSpecific

  if opts.leadingIconTexture then
    local leadHeight = opts.leadingIconHeight
      or opts.iconHeight
      or opts.iconSize
      or DEFAULT_ICON_SIZE
    local leadWidth = opts.leadingIconWidth or leadHeight
    local lead = row:CreateTexture(nil, "ARTWORK")
    lead:SetTexture(opts.leadingIconTexture)
    lead:SetSize(leadWidth, leadHeight)
    control.leadingIcon = lead
    control.leadingIconWidth = leadWidth
    control.leadingIconHeight = leadHeight
    control.leadingIconAspect = leadHeight > 0 and (leadWidth / leadHeight) or 1
  end

  if opts.iconAtlas then
    local iconHeight = opts.iconHeight or opts.iconSize or DEFAULT_ICON_SIZE
    local iconWidth = opts.iconWidth or opts.iconSize or iconHeight
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas(opts.iconAtlas)
    icon:SetSize(iconWidth, iconHeight)
    control.icon = icon
    control.iconWidth = iconWidth
    control.iconHeight = iconHeight
    control.iconAspect = iconHeight > 0 and (iconWidth / iconHeight) or 1
    -- Legacy square size used as the minimum fit-text height floor.
    control.iconSize = iconHeight
  end

  if opts.charSpecific ~= nil then
    -- Hit frame so the badge can receive mouse for the tooltip.
    local hit = CreateFrame("Frame", nil, row)
    hit:SetSize(CHAR_SCOPE_MARK_W, CHAR_SCOPE_MARK_W)
    hit:EnableMouse(true)
    local badge = CreateGlyphBadge(hit, CHAR_SCOPE_MARK_W, CHAR_SCOPE_MARK, 1, 0, 8, C.textDim)
    hit.mark = badge.mark
    control.scopeTag = hit
    UI.AttachTooltip(hit, CHAR_SCOPE_TOOLTIP)
    hit:HookScript("OnEnter", function()
      badge:SetHover(true)
    end)
    hit:HookScript("OnLeave", function()
      badge:SetHover(false)
    end)
    if not CharSpecificEnabled(opts) then
      hit:Hide()
    end
  end

  if opts.newFeatureFlag then
    control.newFeatureBadge = UI.CreateNewFeatureBadge(row)
  end

  local raw = opts.desc
  if type(raw) == "function" then
    raw = raw()
  end
  local allowColors = opts.descAllowColors and true or false
  local display = allowColors and raw or (raw and UI.StripColors(raw))
  if display and display ~= "" then
    local desc = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)
    desc:SetText(display)
    desc:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    control.desc = desc
  end

  function control.UpdateCharScopeTag()
    local tag = control.scopeTag
    if not tag then
      return
    end
    local show = CharSpecificEnabled(opts)
    local wasShown = tag:IsShown() and true or false
    if show then
      tag:Show()
    else
      tag:Hide()
    end
    -- Click Casting slots flip char/account with Account-Wide Binds; relayout when the
    -- mark appears or disappears so title width stays correct after Options.Sync().
    if (show and true or false) ~= wasShown and not control._layouting and control._layoutWidth then
      control.SetWidthTo(control._layoutWidth)
    end
  end

  local prevSetWidthTo = control.SetWidthTo
  function control.SetWidthTo(width)
    if prevSetWidthTo then
      prevSetWidthTo(width)
    end

    control._layouting = true
    control._layoutWidth = width

    local showScope = CharSpecificEnabled(opts)
    if control.scopeTag then
      if showScope then
        control.scopeTag:Show()
      else
        control.scopeTag:Hide()
      end
    end

    local widget = control.widget
    local icon = control.icon
    local leadingIcon = control.leadingIcon
    local iconHeight = icon and (control.iconHeight or control.iconSize or DEFAULT_ICON_SIZE) or 0
    local iconWidth = icon and (control.iconWidth or control.iconSize or iconHeight) or 0
    local iconAspect = (control.iconAspect and control.iconAspect > 0) and control.iconAspect or 1
    local leadHeight = leadingIcon and (control.leadingIconHeight or DEFAULT_ICON_SIZE) or 0
    local leadWidth = leadingIcon and (control.leadingIconWidth or leadHeight) or 0
    local leadAspect = (control.leadingIconAspect and control.leadingIconAspect > 0)
        and control.leadingIconAspect
      or 1
    local function IconsLead()
      local lead = 0
      if leadingIcon then
        lead = lead + leadWidth + ICON_GAP
      end
      if icon then
        lead = lead + iconWidth + ICON_GAP
      end
      return lead
    end
    local iconLead = IconsLead()
    local iconsHeight = max(iconHeight, leadHeight)
    local scopeTag = control.scopeTag
    local scopeShown = scopeTag and scopeTag:IsShown()
    local h

    local function PlaceIconColumn(topY, textBlockH)
      local x = padX
      if leadingIcon then
        local leadTop = topY + floor(((textBlockH or leadHeight) - leadHeight) / 2)
        leadingIcon:ClearAllPoints()
        leadingIcon:SetPoint("TOPLEFT", row, "TOPLEFT", x, -leadTop)
        x = x + leadWidth + ICON_GAP
      end
      if icon then
        local mouseTop = topY + floor(((textBlockH or iconHeight) - iconHeight) / 2)
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", x, -mouseTop)
      end
    end

    if control.descBelow then
      -- Top band: title left + control right; helper full-width below.
      local labelW = max(width - (2 * padX) - iconLead - CONTROL_GAP - (control.widgetW or 40), 40)
      row.label:SetWidth(labelW)
      local labelH = row.label:GetStringHeight()
      local bandH = max(labelH, control.widgetH, iconsHeight)
      local labelTop = ROW_PAD_Y + floor((bandH - labelH) / 2)
      local widgetTop = ROW_PAD_Y + floor((bandH - control.widgetH) / 2)

      PlaceIconColumn(ROW_PAD_Y + floor((bandH - iconsHeight) / 2), iconsHeight)
      row.label:ClearAllPoints()
      row.label:SetPoint("TOPLEFT", row, "TOPLEFT", padX + iconLead, -labelTop)
      if scopeShown then
        PlaceCharScopeMark(scopeTag, row.label, labelW)
      end
      if control.newFeatureBadge then
        UI.PlaceNewFeatureBadge(
          control.newFeatureBadge,
          row.label,
          labelW,
          scopeShown and scopeTag or nil
        )
      end
      if widget then
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -padX, -widgetTop)
      end

      h = ROW_PAD_Y + bandH
      if control.desc then
        control.desc:ClearAllPoints()
        control.desc:SetWidth(width - (2 * padX))
        control.desc:SetPoint("TOPLEFT", row, "TOPLEFT", padX, -(h + DESC_BELOW_GAP))
        h = h + DESC_BELOW_GAP + control.desc:GetStringHeight()
      end
      h = h + ROW_PAD_Y
    else
      local textFrac = control.textFrac or TEXT_FRAC

      local function MeasureText(lead)
        local textW = max(floor(width * textFrac) - padX - lead, 40)
        row.label:SetWidth(textW)
        local labelH = row.label:GetStringHeight()
        local textH = labelH
        if control.desc then
          control.desc:SetWidth(textW)
          textH = labelH + TEXT_GAP + control.desc:GetStringHeight()
        end
        return textW, labelH, textH
      end

      local textW, _, textH = MeasureText(iconLead)

      -- Grow icons to the title+helper block so they read flush with both lines.
      if (icon or leadingIcon) and control.iconFitText then
        local fitH = floor(textH + 0.5)
        if icon then
          iconHeight = max(control.iconHeight or control.iconSize or DEFAULT_ICON_SIZE, fitH)
          iconWidth = max(1, floor(iconHeight * iconAspect + 0.5))
          icon:SetSize(iconWidth, iconHeight)
        end
        if leadingIcon then
          leadHeight = max(control.leadingIconHeight or DEFAULT_ICON_SIZE, fitH)
          leadWidth = max(1, floor(leadHeight * leadAspect + 0.5))
          leadingIcon:SetSize(leadWidth, leadHeight)
        end
        iconsHeight = max(iconHeight, leadHeight)
        iconLead = IconsLead()
        textW, _, textH = MeasureText(iconLead)
        fitH = floor(textH + 0.5)
        if icon then
          iconHeight = max(iconHeight, fitH)
          iconWidth = max(1, floor(iconHeight * iconAspect + 0.5))
          icon:SetSize(iconWidth, iconHeight)
        end
        if leadingIcon then
          leadHeight = max(leadHeight, fitH)
          leadWidth = max(1, floor(leadHeight * leadAspect + 0.5))
          leadingIcon:SetSize(leadWidth, leadHeight)
        end
        iconsHeight = max(iconHeight, leadHeight)
        iconLead = IconsLead()
      end

      local contentH = max(textH, control.widgetH, iconsHeight)
      h = contentH + (2 * ROW_PAD_Y)

      -- Center the shorter column against the taller one so title/helper and control
      -- share a vertical midpoint. Icons center on the full title+helper block.
      local textTop = ROW_PAD_Y + floor((contentH - textH) / 2)
      local widgetTop = ROW_PAD_Y + floor((contentH - control.widgetH) / 2)

      PlaceIconColumn(textTop, textH)
      row.label:ClearAllPoints()
      row.label:SetPoint("TOPLEFT", row, "TOPLEFT", padX + iconLead, -textTop)
      if scopeShown then
        PlaceCharScopeMark(scopeTag, row.label, textW)
      end
      if control.newFeatureBadge then
        UI.PlaceNewFeatureBadge(
          control.newFeatureBadge,
          row.label,
          textW,
          scopeShown and scopeTag or nil
        )
      end
      if control.desc then
        control.desc:ClearAllPoints()
        control.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -TEXT_GAP)
      end

      if widget then
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -padX, -widgetTop)
        if control.widgetFill then
          widget:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            padX + textW + iconLead + CONTROL_GAP,
            -widgetTop
          )
        end
      end
    end

    row:SetWidth(width)
    row:SetHeight(h)
    control.height = h
    control._layouting = false
    return h
  end

  -- Provisional until the layout pass assigns width.
  local provisional = control.widgetH + (2 * ROW_PAD_Y)
  if control.icon then
    provisional = max(provisional, (control.iconHeight or control.iconSize or 0) + (2 * ROW_PAD_Y))
  end
  if control.desc then
    provisional = provisional + (control.descBelow and (DESC_BELOW_GAP + 28) or 14)
  end
  control.height = provisional
  row:SetHeight(provisional)
end

--- Shared by SpellMultiSelect.lua.
Options.AttachOptionText = AttachOptionText
Options.AddRowHover = AddRowHover

local function SetDescAlpha(control, a)
  if control.desc then
    control.desc:SetAlpha(a)
  end
  if control.icon then
    control.icon:SetAlpha(a)
  end
  if control.scopeTag then
    control.scopeTag:SetAlpha(a)
  end
end

local function ClearHoverIfDisabled(row, disabled)
  if disabled and row.cmClearHover then
    row.cmClearHover()
  end
end

--- Shows or hides a row's disabled notice (control.watermark, see UI.CreateRowStamp). The
--- notice appears only while the row is disabled and `watermarkWhenDisabled` resolves to a
--- message (or `fallback` when the caller wants a default). Returns true while it is shown;
--- callers then hide the row's control so the notice sits where the control was.
local function SyncStamp(control, opts, disabled, fallback)
  local stamp = control.watermark
  if not stamp then
    return false
  end
  local message = opts.watermarkWhenDisabled
  if type(message) == "function" then
    message = message()
  end
  if not (type(message) == "string" and message ~= "") then
    message = fallback
  end
  if disabled and message then
    stamp.SetStampText(message)
    stamp:Show()
    return true
  end
  stamp:Hide()
  return false
end

---------------------------------------------------------------------------------------
--                                    TOGGLE                                         --
---------------------------------------------------------------------------------------
-- Page toggles are 45x22; `opts.compact` (sidebar footer) uses 35x18 (mockup proportions).
local TOGGLE_KNOB_PAD = 3
local TOGGLE_ANIM_DURATION = 0.14

local function Lerp(a, b, t)
  return a + (b - a) * t
end

function UI.MakeToggle(parent, opts)
  -- Wide enough for the ON / OFF label beside the knob.
  local TOGGLE_TRACK_W = opts.compact and 40 or 50
  local TOGGLE_TRACK_H = opts.compact and 18 or 22
  local TOGGLE_TEXT_SIZE = opts.compact and 8 or 9
  local TOGGLE_KNOB = TOGGLE_TRACK_H - 6
  local TOGGLE_KNOB_ON_X = TOGGLE_TRACK_W - TOGGLE_KNOB - TOGGLE_KNOB_PAD

  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label, false, opts.compact and UI.Fonts.small or nil)

  local track = CreateFrame("Frame", nil, row)
  track:SetSize(TOGGLE_TRACK_W, TOGGLE_TRACK_H)

  -- Track: a gradient-filled pill (radius = height / 2) inside a 1px outline in the shared
  -- control border colour.
  UI.StyleRounded(track, C.trackOff, C.cardBorder, TOGGLE_TRACK_H / 2, 1)

  local knob = UI.CreateCircle(track, "OVERLAY", C.white)
  knob:SetSize(TOGGLE_KNOB, TOGGLE_KNOB)
  knob:SetPoint("LEFT", track, "LEFT", TOGGLE_KNOB_PAD, 0)

  -- ON sits left of the knob (knob right when on), OFF sits right of it (knob left when
  -- off). Each fades with the animation: ON in the accent colour, OFF in dim text.
  local onText = UI.CreateFontString(track, "OVERLAY", TOGGLE_TEXT_SIZE, "GameFontNormalSmall")
  onText:SetText("ON")
  onText:SetTextColor(C.toggleOn[1], C.toggleOn[2], C.toggleOn[3])
  onText:SetPoint("CENTER", track, "LEFT", (5 + TOGGLE_KNOB_ON_X - TOGGLE_KNOB_PAD) / 2, 0)
  local offText = UI.CreateFontString(track, "OVERLAY", TOGGLE_TEXT_SIZE, "GameFontNormalSmall")
  offText:SetText("OFF")
  offText:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  offText:SetPoint(
    "CENTER",
    track,
    "LEFT",
    (TOGGLE_KNOB_PAD * 2 + TOGGLE_KNOB + TOGGLE_TRACK_W - 5) / 2,
    0
  )

  local control = {
    frame = row,
    height = ROW_H,
    widget = track,
    widgetH = TOGGLE_TRACK_H,
    widgetW = TOGGLE_TRACK_W,
  }
  local displayT -- nil until first Refresh; 0 = off, 1 = on
  local animFrom, animTo, animElapsed

  local function ApplyToggleVisual(t)
    local x = Lerp(TOGGLE_KNOB_PAD, TOGGLE_KNOB_ON_X, t)
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", track, "LEFT", x, 0)
    -- Same dark gradient track and cream knob in both states; ON differs by the knob on the
    -- right and the accent "ON" label.
    track:cmSetFillGradient(C.trackOffTop, C.trackOff)
    knob:SetColorTexture(0.95, 0.92, 0.87, 1)
    onText:SetAlpha(t)
    offText:SetAlpha(1 - t)
  end

  local function StopToggleAnim()
    track:SetScript("OnUpdate", nil)
    animElapsed = nil
  end

  local function StartToggleAnim(fromT, toT)
    animFrom = fromT
    animTo = toT
    animElapsed = 0
    track:SetScript("OnUpdate", function(_, elapsed)
      animElapsed = (animElapsed or 0) + (elapsed or 0)
      local p = min(1, animElapsed / TOGGLE_ANIM_DURATION)
      local eased = 1 - (1 - p) * (1 - p)
      displayT = Lerp(animFrom, animTo, eased)
      ApplyToggleVisual(displayT)
      if p >= 1 then
        displayT = animTo
        ApplyToggleVisual(displayT)
        StopToggleAnim()
      end
    end)
  end

  function control.Refresh()
    local value = opts.get and opts.get()
    local target = value and 1 or 0
    local disabled = IsDisabled(opts)

    if displayT == nil then
      displayT = target
      ApplyToggleVisual(displayT)
    elseif abs(displayT - target) > 0.001 then
      -- Already easing toward this target (e.g. Options.Sync from another control).
      if not (animElapsed and animTo == target) then
        StartToggleAnim(displayT, target)
      end
    else
      StopToggleAnim()
      displayT = target
      ApplyToggleVisual(displayT)
    end

    local a = disabled and DISABLED_A or 1
    row.label:SetAlpha(a)
    track:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    row:SetEnabled(not disabled)
    if disabled then
      track:Hide()
    else
      track:Show()
    end
    -- Only stamp when watermarkWhenDisabled resolves to a non-empty string so composite
    -- disabled() reasons (e.g. Reticle Targeting off) can grey the row without a false
    -- "DynamicCam" overlay. (The toggle itself is already hidden while disabled.)
    SyncStamp(control, opts, disabled)
  end

  row:SetScript("OnClick", function()
    if IsDisabled(opts) then
      return
    end
    -- Captured up front so a confirmed toggle applies the value the user actually clicked.
    local newValue = not (opts.get and opts.get())
    local function apply()
      if opts.set then
        opts.set(newValue)
      end
      Options.Sync()
    end
    if opts.confirm then
      UI.Confirm(opts.confirmText or "Are you sure?", apply)
    else
      apply()
    end
  end)
  AddRowHover(row, opts)
  AttachOptionText(control, row, opts, 20)

  -- Optional stamp over the row while disabled (string or function returning string/nil).
  local markOpt = opts.watermarkWhenDisabled
  local markInitial = type(markOpt) == "function" and markOpt() or markOpt
  if type(markInitial) == "string" and markInitial ~= "" then
    control.watermark = UI.CreateRowStamp(row, markInitial)
  elseif type(markOpt) == "function" then
    control.watermark = UI.CreateRowStamp(row, "Inactive")
  end

  return Register(control)
end

---------------------------------------------------------------------------------------
--                                    SLIDER                                         --
---------------------------------------------------------------------------------------
local SLIDER_ANIM_DURATION = 0.14
-- − / + steppers: full accent at rest, brighter on hover, dim when the value is at its limit.
local STEP_ICON_ALPHA = 0.85
local STEP_ICON_ALPHA_DISABLED = 0.35
local SLIDER_TRACK_H = 5
local SLIDER_THUMB_SIZE = 16

function UI.MakeSlider(parent, opts)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  -- Right-column host aligns with dropdowns/buttons. The value readout sits at the host's
  -- left edge (so its left aligns with the other controls) and the slider fills the rest.
  local host = CreateFrame("Frame", nil, row)
  host:SetHeight(22)

  -- Value readout: like the mockup there is no number beside the slider. It appears above
  -- the knob while hovering or dragging (anchored once the knob exists, below).
  local valueText = UI.CreateFontString(host, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  valueText:SetJustifyH("CENTER")
  valueText:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  valueText:Hide()

  local function MakeStepButton(atlas)
    local button = CreateFrame("Button", nil, host)
    button:SetSize(18, 18)
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas(atlas, true)
    local iconH = icon:GetHeight() or 16
    local iconW = icon:GetWidth() or 16
    if iconH > 0 then
      local scale = 12 / iconH
      icon:SetSize(iconW * scale, 12)
    end
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    -- Desaturate then tint so the atlas glyph reads as the theme's white.
    icon:SetDesaturated(true)
    icon:SetVertexColor(C.text[1], C.text[2], C.text[3])
    icon:SetAlpha(STEP_ICON_ALPHA)
    button.icon = icon
    button:SetScript("OnEnter", function()
      if button:IsEnabled() then
        icon:SetAlpha(1)
      end
    end)
    button:SetScript("OnLeave", function()
      icon:SetAlpha(button:IsEnabled() and STEP_ICON_ALPHA or STEP_ICON_ALPHA_DISABLED)
    end)
    return button
  end

  local minus = MakeStepButton("common-icon-minus")
  minus:SetPoint("LEFT", host, "LEFT", 0, 0)
  local plus = MakeStepButton("common-icon-plus")
  plus:SetPoint("RIGHT", host, "RIGHT", 0, 0)

  local slider = CreateFrame("Slider", nil, host)
  slider:SetOrientation("HORIZONTAL")
  -- Continuous thumb while dragging; we snap the committed value to `step` ourselves.
  slider:SetObeyStepOnDrag(false)
  slider:SetHeight(SLIDER_THUMB_SIZE)
  slider:SetPoint("LEFT", minus, "RIGHT", 6, 0)
  slider:SetPoint("RIGHT", plus, "LEFT", -6, 0)
  slider:SetMinMaxValues(opts.min or 0, opts.max or 1)
  slider:SetValueStep(opts.step or 1)

  -- Track and fill are rounded bars (the shared renderer, radius = half the bar height).
  -- They are child frames below the slider's own level: the knob is a texture on the
  -- slider, and a frame's textures draw under its child frames, so the bars must sit
  -- beneath the slider rather than inside it.
  local trackBar = CreateFrame("Frame", nil, host)
  trackBar:SetFrameLevel(max(slider:GetFrameLevel() - 2, 0))
  trackBar:SetHeight(SLIDER_TRACK_H)
  trackBar:SetPoint("LEFT", slider, "LEFT", 0, 0)
  trackBar:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  UI.StyleRounded(trackBar, C.sliderTrack, { 0, 0, 0, 0 }, SLIDER_TRACK_H / 2)

  local fill = CreateFrame("Frame", nil, host)
  fill:SetFrameLevel(max(slider:GetFrameLevel() - 1, 0))
  fill:SetHeight(SLIDER_TRACK_H)
  fill:SetPoint("LEFT", trackBar, "LEFT", 0, 0)
  fill:SetWidth(SLIDER_TRACK_H)
  UI.StyleRounded(fill, C.toggleOn, { 0, 0, 0, 0 }, SLIDER_TRACK_H / 2)
  fill:cmSetFillGradientH(C.accentBottom, C.accentTop)

  -- Knob: the same cream circle (UI.CreateCircle) as the toggle knob, used as the slider's
  -- thumb texture so the slider positions it.
  local THUMB_SIZE = SLIDER_THUMB_SIZE
  local thumb = UI.CreateCircle(slider, "OVERLAY", { 0.95, 0.92, 0.87, 1 })
  thumb:SetSize(THUMB_SIZE, THUMB_SIZE)
  slider:SetThumbTexture(thumb)

  valueText:SetPoint("BOTTOM", thumb, "TOP", 0, 6)
  slider:HookScript("OnEnter", function()
    valueText:Show()
  end)
  slider:HookScript("OnLeave", function()
    if not slider.cmDragging then
      valueText:Hide()
    end
  end)

  local control = {
    frame = row,
    height = ROW_H,
    widget = host,
    widgetH = 22,
    widgetFill = true,
  }
  local suppress = false
  local displayValue
  local committedValue
  local animFrom, animTo, animElapsed
  local userActive = false
  local rightClicking = false

  local function stepRound(value)
    local step = opts.step or 1
    local minV = opts.min or 0
    local maxV = opts.max or 1
    local snapped = floor((value / step) + 0.5) * step
    -- Avoid float drift past the configured bounds.
    if snapped < minV then
      return minV
    end
    if snapped > maxV then
      return maxV
    end
    return snapped
  end

  local function UpdateFill(val)
    local minV, maxV = slider:GetMinMaxValues()
    local width = slider:GetWidth() or 0
    if width <= 0 or maxV <= minV then
      fill:SetWidth(1)
      return
    end
    local pct = (val - minV) / (maxV - minV)
    if pct < 0 then
      pct = 0
    elseif pct > 1 then
      pct = 1
    end
    -- The thumb stays inside the slider frame, so its centre travels from half a thumb
    -- in from each end. The fill runs from the track's left end to the thumb centre.
    local thumbW = thumb:GetWidth() or THUMB_SIZE
    local travel = width - thumbW
    if travel < 0 then
      travel = 0
    end
    local fillW = (pct * travel) + (thumbW / 2)
    -- A bar narrower than its own rounded ends would draw inside-out; the knob covers it.
    if fillW <= SLIDER_TRACK_H then
      fill:Hide()
    else
      fill:Show()
      fill:SetWidth(fillW)
    end
  end

  local function StopSliderAnim()
    slider:SetScript("OnUpdate", nil)
    animElapsed = nil
  end

  local function ApplyStep(button, active)
    button:SetEnabled(active)
    local alpha = active and STEP_ICON_ALPHA or STEP_ICON_ALPHA_DISABLED
    if active and button:IsMouseOver() then
      alpha = 1
    end
    button.icon:SetAlpha(alpha)
  end

  local function UpdateSteppers(val)
    local disabled = IsDisabled(opts)
    local minV = opts.min or 0
    local maxV = opts.max or 1
    local stepped = stepRound(val or 0)
    local atMin = abs(stepped - minV) < 0.0001
    local atMax = abs(stepped - maxV) < 0.0001
    ApplyStep(minus, not disabled and not atMin)
    ApplyStep(plus, not disabled and not atMax)
  end

  local function ApplyDisplay(val, writeWidget)
    displayValue = val
    if writeWidget then
      suppress = true
      slider:SetValue(val)
      suppress = false
    end
    valueText:SetText(tostring(stepRound(val)))
    UpdateFill(val)
    UpdateSteppers(val)
  end

  local function CommitStepped(raw, sync)
    local stepped = stepRound(raw)
    if committedValue ~= nil and abs(committedValue - stepped) < 0.0001 then
      if sync then
        Options.Sync()
      end
      return
    end
    committedValue = stepped
    if opts.set then
      opts.set(stepped)
    end
    if sync then
      Options.Sync()
    end
  end

  local function Nudge(direction)
    if IsDisabled(opts) then
      return
    end
    StopSliderAnim()
    userActive = false
    local current = committedValue
    if current == nil then
      current = stepRound((opts.get and opts.get()) or displayValue or opts.min or 0)
    end
    local stepped = stepRound(current + (direction * (opts.step or 1)))
    ApplyDisplay(stepped, true)
    CommitStepped(stepped, true)
  end

  minus:SetScript("OnClick", function()
    Nudge(-1)
  end)
  plus:SetScript("OnClick", function()
    Nudge(1)
  end)

  local function ResetToDefault()
    if IsDisabled(opts) or opts.default == nil then
      return
    end
    StopSliderAnim()
    userActive = false
    local stepped = stepRound(opts.default)
    ApplyDisplay(stepped, true)
    CommitStepped(stepped, true)
  end

  local function StartSliderAnim(fromV, toV)
    animFrom = fromV
    animTo = toV
    animElapsed = 0
    slider:SetScript("OnUpdate", function(_, elapsed)
      animElapsed = (animElapsed or 0) + (elapsed or 0)
      local p = min(1, animElapsed / SLIDER_ANIM_DURATION)
      local eased = 1 - (1 - p) * (1 - p)
      local val = Lerp(animFrom, animTo, eased)
      ApplyDisplay(val, true)
      if p >= 1 then
        ApplyDisplay(animTo, true)
        StopSliderAnim()
      end
    end)
  end

  slider:HookScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      -- The slider widget sets its value from the cursor before this hook.
      -- Mark the click so OnValueChanged does not keep that position.
      rightClicking = true
      ResetToDefault()
      return
    end
    if button ~= "LeftButton" then
      rightClicking = true
      return
    end
    StopSliderAnim()
    userActive = true
    slider.cmDragging = true
    valueText:Show()
  end)
  slider:HookScript("OnMouseUp", function(_, button)
    if button ~= "LeftButton" then
      if button == "RightButton" then
        rightClicking = true
        ResetToDefault()
      end
      userActive = false
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          rightClicking = false
        end)
      else
        rightClicking = false
      end
      return
    end
    rightClicking = false
    userActive = false
    slider.cmDragging = false
    if not slider:IsMouseOver() then
      valueText:Hide()
    end
    -- Snap thumb + fill to the committed step when the drag ends.
    local stepped = stepRound(displayValue or slider:GetValue() or 0)
    ApplyDisplay(stepped, true)
    CommitStepped(stepped, true)
  end)
  slider:HookScript("OnSizeChanged", function()
    if displayValue ~= nil then
      UpdateFill(displayValue)
    end
  end)

  slider:SetScript("OnValueChanged", function(_, value)
    if suppress then
      return
    end
    -- The slider widget moves the thumb for every mouse button. A right click
    -- must not keep that cursor position; put the value back on the default.
    if
      IsMouseButtonDown("RightButton") or (rightClicking and not IsMouseButtonDown("LeftButton"))
    then
      rightClicking = true
      ResetToDefault()
      return
    end
    displayValue = value
    valueText:SetText(tostring(stepRound(value)))
    UpdateFill(value)
    UpdateSteppers(value)
    -- Live-commit stepped values while dragging so feature previews update, without
    -- snapping the thumb (Refresh skips SetValue while userActive).
    CommitStepped(value, true)
  end)

  function control.Refresh()
    local value = (opts.get and opts.get()) or opts.min or 0
    value = stepRound(value)
    local disabled = IsDisabled(opts)
    committedValue = value

    if not userActive then
      if displayValue == nil then
        ApplyDisplay(value, true)
      elseif abs(displayValue - value) > 0.0001 and not (animElapsed and animTo == value) then
        StartSliderAnim(displayValue, value)
      end
    end

    slider:SetEnabled(not disabled)
    local a = disabled and DISABLED_A or 1
    row.label:SetAlpha(a)
    valueText:SetAlpha(a)
    slider:SetAlpha(a)
    UpdateSteppers(value)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    -- Like the toggle, the whole slider (track, knob, − / +) is hidden while disabled.
    host:SetShown(not disabled)
    SyncStamp(control, opts, disabled)
  end

  AddRowHover(row, opts, slider)
  AttachOptionText(control, row, opts, 22)

  -- Optional stamp over the row while disabled (string or function returning string/nil).
  local markOpt = opts.watermarkWhenDisabled
  local markInitial = type(markOpt) == "function" and markOpt() or markOpt
  if type(markInitial) == "string" and markInitial ~= "" then
    control.watermark = UI.CreateRowStamp(row, markInitial)
  elseif type(markOpt) == "function" then
    control.watermark = UI.CreateRowStamp(row, "Unavailable")
  end

  return Register(control)
end

---------------------------------------------------------------------------------------
--                                   DROPDOWN                                        --
---------------------------------------------------------------------------------------
function UI.MakeDropdown(parent, opts)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  local button = CreateFrame("Button", nil, row, "BackdropTemplate")
  button:SetHeight(UI.Sizes.control)
  UI.StyleControl(button)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
  text:SetPoint("LEFT", button, "LEFT", 8, 0)
  text:SetPoint("RIGHT", button, "RIGHT", -22, 0)
  text:SetJustifyH("LEFT")
  UI.WireControlHover(button, text, function()
    return IsDisabled(opts)
  end)

  -- The atlas arrow is gold; desaturate and tint it to the dim text colour.
  local arrow = button:CreateTexture(nil, "OVERLAY")
  arrow:SetAtlas("UI-Journeys-Delve-Arrow-down-pressed", true)
  arrow:SetDesaturated(true)
  arrow:SetVertexColor(C.textDim[1], C.textDim[2], C.textDim[3])
  local arrowH = arrow:GetHeight() or 14
  local arrowW = arrow:GetWidth() or 14
  if arrowH > 12 and arrowH > 0 then
    local scale = 12 / arrowH
    arrow:SetSize(arrowW * scale, 12)
  end
  arrow:SetPoint("RIGHT", button, "RIGHT", -6, 1)

  local control = {
    frame = row,
    height = ROW_H,
    widget = button,
    widgetH = UI.Sizes.control,
    widgetFill = true,
  }

  local function orderedIds()
    if opts.order then
      return opts.order
    end
    local ids = {}
    for id in pairs(opts.values) do
      tinsert(ids, id)
    end
    tsort(ids)
    return ids
  end

  -- Custom popup menu (FULLSCREEN_DIALOG strata) instead of MenuUtil: the options window
  -- is a top-level HIGH-strata frame, which can render over a MenuUtil context menu and
  -- clip the list. A dedicated high-strata popup guarantees the full list is visible, and
  -- it scrolls + filters so long lists (e.g. every bindable action) stay usable.
  local ITEM_H = 22
  local FILTER_H = UI.Sizes.search
  -- The open menu replaces the select: its top row is the select itself (same height, current
  -- value and a flipped arrow) and the list grows out of it, so it reads as the select expanding.
  local HEADER_H = UI.Sizes.control
  local MENU_PAD = 4
  local BAR_GUTTER = 10
  local FILTER_MIN = 12
  local MAX_ROWS = 12
  local menu
  local selectedTint -- colour of the current value (opts.valueColors), nil for the default

  local function CloseMenu()
    if menu then
      menu:Hide()
      menu.closer:Hide()
    end
  end

  local function EnsureItem(i)
    local item = menu.items[i]
    if item then
      return item
    end
    item = CreateFrame("Button", nil, menu.content)
    item:SetHeight(ITEM_H)
    item.hl = UI.CreateRoundedHover(item, item)
    item.text = UI.CreateFontString(item, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
    item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
    item.text:SetPoint("RIGHT", item, "RIGHT", -8, 0)
    item.text:SetJustifyH("LEFT")
    item.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    item:SetScript("OnEnter", function(self)
      self.hl:Show()
    end)
    item:SetScript("OnLeave", function(self)
      self.hl:Hide()
    end)
    item:SetScript("OnClick", function(self)
      CloseMenu()
      if opts.set then
        opts.set(self.id)
      end
      Options.Sync()
    end)
    menu.items[i] = item
    return item
  end

  local function Populate(filterText)
    local ids = orderedIds()
    filterText = filterText and strlower(filterText) or ""
    local shown = 0
    for _, id in ipairs(ids) do
      local labelText = UI.StripColors(opts.values[id]) or id
      local match = filterText == ""
      if not match then
        match = strfind(strlower(labelText), filterText, 1, true) ~= nil
          or strfind(strlower(id), filterText, 1, true) ~= nil
      end
      if match then
        shown = shown + 1
        local item = EnsureItem(shown)
        item.id = id
        item.text:SetText(labelText)
        local tint = opts.valueColors and opts.valueColors[id] or C.text
        item.text:SetTextColor(tint[1], tint[2], tint[3])
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", menu.content, "TOPLEFT", 0, -(shown - 1) * ITEM_H)
        item:SetPoint("TOPRIGHT", menu.content, "TOPRIGHT", 0, -(shown - 1) * ITEM_H)
        item:Show()
      end
    end
    for i = shown + 1, #menu.items do
      menu.items[i]:Hide()
    end
    menu.content:SetHeight(max(shown * ITEM_H, 1))
    menu.scroll:SetVerticalScroll(0)

    -- Only reserve the scrollbar gutter when the list actually overflows.
    local needsBar = shown > MAX_ROWS
    local gutter = needsBar and BAR_GUTTER or 0
    local menuW = menu:GetWidth()
    local scrollW = menuW - (2 * MENU_PAD) - gutter
    local visibleRows = needsBar and MAX_ROWS or max(shown, 1)
    local listH = visibleRows * ITEM_H
    menu.content:SetWidth(scrollW)
    menu.scroll:SetWidth(scrollW)
    menu.scroll:SetHeight(listH)

    local topPad = HEADER_H + MENU_PAD
    if menu.filter:IsShown() then
      topPad = topPad + FILTER_H + MENU_PAD
    end
    menu:SetHeight(topPad + listH + MENU_PAD)

    SetMenuBarActive(menu.bar, needsBar)
    if menu.scroll.cmUpdate then
      menu.scroll.cmUpdate()
    end
  end

  local function EnsureMenu()
    if menu then
      return
    end
    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetAllPoints(UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:EnableMouse(true)
    closer:Hide()

    menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(closer:GetFrameLevel() + 10)
    menu:SetToplevel(true)
    -- Same surface and outline as the select, stretched over the whole menu.
    UI.StyleRounded(menu, C.controlFill, C.cardBorder, UI.Radius.button, 1)
    menu:cmSetFillGradient(C.controlFillTop, C.controlFill)
    menu:cmSetBorderGradient(C.controlBorderTop, C.controlBorderBottom)
    menu:Hide()
    menu.items = {}
    menu.closer = closer

    -- Header row: the select's current value and an up arrow; clicking it collapses the menu.
    local header = CreateFrame("Button", nil, menu)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", menu, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", menu, "TOPRIGHT", 0, 0)
    header:SetScript("OnClick", CloseMenu)
    local headerText =
      UI.CreateFontString(header, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
    headerText:SetPoint("LEFT", header, "LEFT", 8, 0)
    headerText:SetPoint("RIGHT", header, "RIGHT", -22, 0)
    headerText:SetJustifyH("LEFT")
    headerText:SetTextColor(C.text[1], C.text[2], C.text[3])
    local headerArrow = header:CreateTexture(nil, "OVERLAY")
    headerArrow:SetAtlas("UI-Journeys-Delve-Arrow-down-pressed", true)
    headerArrow:SetDesaturated(true)
    headerArrow:SetVertexColor(C.textDim[1], C.textDim[2], C.textDim[3])
    local ah = headerArrow:GetHeight() or 14
    local aw = headerArrow:GetWidth() or 14
    if ah > 12 and ah > 0 then
      headerArrow:SetSize(aw * (12 / ah), 12)
    end
    headerArrow:SetRotation(math.pi)
    headerArrow:SetPoint("RIGHT", header, "RIGHT", -6, 0)
    menu.header = header
    menu.headerText = headerText

    local rule = UI.CreateLine(menu, false, C.divider, "ends")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -HEADER_H)
    rule:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -HEADER_H)

    local filter = CreateFrame("EditBox", nil, menu)
    filter:SetAutoFocus(false)
    filter:SetHeight(FILTER_H)
    UI.SetEditBoxFont(filter)
    filter:SetTextColor(C.text[1], C.text[2], C.text[3])
    filter:SetTextInsets(28, 8, 0, 0)
    UI.StyleSearchBox(filter)
    filter:SetScript("OnTextChanged", function(self)
      Populate(self:GetText())
    end)
    filter:SetScript("OnEscapePressed", CloseMenu)
    menu.filter = filter

    local scroll, content, bar = UI.CreateScrollFrame(menu)
    menu.scroll = scroll
    menu.content = content
    menu.bar = bar

    closer:SetScript("OnClick", CloseMenu)
    menu:SetScript("OnHide", function()
      closer:Hide()
    end)
  end

  local function OpenMenu()
    EnsureMenu()
    local count = #orderedIds()
    local useFilter = count > FILTER_MIN
    -- Size from the select's laid-out edges. Anchor-sized controls can report
    -- GetWidth() as 0, and a UIParent popup does not share the options frame's
    -- scale, so a raw GetWidth() (or the old 220 minimum) made the list a
    -- different width than the closed control.
    local left = button:GetLeft()
    local right = button:GetRight()
    local menuScale = menu:GetEffectiveScale()
    if not menuScale or menuScale <= 0 then
      menuScale = 1
    end
    local width
    if left and right and right > left then
      local buttonScale = button:GetEffectiveScale() or 1
      width = (right - left) * buttonScale / menuScale
    else
      width = button:GetWidth() or 0
    end

    menu:SetWidth(width)

    menu.headerText:SetText(text:GetText() or "")
    local headerTint = selectedTint or C.text
    menu.headerText:SetTextColor(headerTint[1], headerTint[2], headerTint[3])
    local top = -HEADER_H - MENU_PAD
    if useFilter then
      menu.filter:Show()
      menu.filter:SetText("")
      menu.filter:ClearAllPoints()
      menu.filter:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, top)
      menu.filter:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -MENU_PAD, top)
      top = top - FILTER_H - MENU_PAD
    else
      menu.filter:Hide()
    end

    menu.scroll:ClearAllPoints()
    menu.scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, top)

    menu.bar:ClearAllPoints()
    menu.bar:SetPoint("TOP", menu.scroll, "TOP", 0, 0)
    menu.bar:SetPoint("BOTTOM", menu.scroll, "BOTTOM", 0, 0)
    menu.bar:SetPoint("RIGHT", menu, "RIGHT", -5, 0)

    Populate("")

    menu:ClearAllPoints()
    -- Cover the select exactly; the header row stands in for it.
    menu:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    menu.closer:Show()
    menu:Show()
    menu:Raise()
    if useFilter then
      menu.filter:SetFocus()
    end
  end

  button:SetScript("OnClick", function()
    if IsDisabled(opts) then
      return
    end
    if menu and menu:IsShown() then
      CloseMenu()
    else
      OpenMenu()
    end
  end)

  -- Selected-value text: menu offers opts.values, but the stored value can be outside
  -- that set (e.g. click-cast defaults like ACTIONBUTTON1). opts.display maps those to a
  -- readable label so the dropdown never renders blank.
  local function DisplayText(value)
    if value == nil then
      return ""
    end
    if opts.values[value] then
      return UI.StripColors(opts.values[value]) or ""
    end
    if opts.display then
      return UI.StripColors(opts.display(value) or "") or ""
    end
    return ""
  end

  -- The hover wiring (UI.WireControlHover) reads this table on every enter / leave, so tint it in
  -- place rather than replacing it.
  local textColors = button.cmControlText
  local baseIdle, baseHover = textColors.idle, textColors.hover

  function control.Refresh()
    local value = opts.get and opts.get()
    text:SetText(DisplayText(value))
    -- opts.valueColors tints chosen values (labels are plain text here, markup is stripped).
    selectedTint = opts.valueColors and opts.valueColors[value]
    textColors.idle = selectedTint or baseIdle
    textColors.hover = selectedTint or baseHover
    text:SetTextColor(textColors.idle[1], textColors.idle[2], textColors.idle[3])
    local disabled = IsDisabled(opts)
    button:SetEnabled(not disabled)
    local a = disabled and DISABLED_A or 1
    row.label:SetAlpha(a)
    button:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
  end

  AddRowHover(row, opts, button)
  AttachOptionText(control, row, opts, UI.Sizes.control)
  return Register(control)
end

---------------------------------------------------------------------------------------
--                                   KEYBIND                                         --
---------------------------------------------------------------------------------------
-- Mirrors the AceGUI Keybinding widget capture model:
--   • Left/Right click enters (or cancels) listening — never binds BUTTON1/BUTTON2.
--   • Middle / Button4 / Button5 bind via OnMouseDown as BUTTON3/BUTTON4/BUTTON5.
--   • Mouse wheel and gamepad buttons are also capturable while listening.
--   • ESC clears the binding; lone modifier keys are ignored.
--
-- Keyboard capture uses a shared high-strata sink frame (not the pill button):
--   • SetPropagateKeyboardInput must be called inside OnKeyDown per key (Mainline).
--   • EditBox focus / UISpecialFrames otherwise steal ESC intermittently.
local IGNORE_KEYS = {
  BUTTON1 = true,
  BUTTON2 = true,
  UNKNOWN = true,
  LSHIFT = true,
  RSHIFT = true,
  LCTRL = true,
  RCTRL = true,
  LALT = true,
  RALT = true,
}

local MOUSE_BUTTON_KEYS = {
  MiddleButton = "BUTTON3",
  Button4 = "BUTTON4",
  Button5 = "BUTTON5",
}

--- True for Left/Right mouse (BUTTON1/BUTTON2), including SHIFT-/CTRL-/ALT- variants.
--- Binding those would steal Camera Or Select Or Move / Turn Or Action.
local function IsPrimaryMouseButtonKey(key)
  if type(key) ~= "string" or key == "" then
    return false
  end
  local leaf = key:match("([^%-]+)$") or key
  return leaf == "BUTTON1" or leaf == "BUTTON2"
end

local keybindCaptureFrame
local keybindCaptureOnKey
local keybindCaptureStopPrevious

local function GetKeybindCaptureFrame()
  if keybindCaptureFrame then
    return keybindCaptureFrame
  end
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:Hide()
  frame:SetFrameStrata("TOOLTIP")
  frame:SetFrameLevel(10000)
  frame:EnableMouse(false)
  frame:EnableKeyboard(true)
  if frame.EnableGamePadButton then
    frame:EnableGamePadButton(true)
  end
  frame:SetScript("OnKeyDown", function(self, key)
    -- Must be called from inside OnKeyDown or ESC propagates to TOGGLEGAMEMENU /
    -- UISpecialFrames and EditBoxes instead of clearing the bind.
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(false)
    end
    if keybindCaptureOnKey then
      keybindCaptureOnKey(key)
    end
  end)
  frame:SetScript("OnGamePadButtonDown", function(_, key)
    if keybindCaptureOnKey then
      keybindCaptureOnKey(key)
    end
  end)
  keybindCaptureFrame = frame
  return frame
end

local function ReleaseKeybindCapture(ownerStop)
  if keybindCaptureStopPrevious and keybindCaptureStopPrevious ~= ownerStop then
    local previous = keybindCaptureStopPrevious
    keybindCaptureStopPrevious = nil
    keybindCaptureOnKey = nil
    previous()
  end
  keybindCaptureOnKey = nil
  keybindCaptureStopPrevious = nil
  if keybindCaptureFrame then
    keybindCaptureFrame:Hide()
  end
end

--- Cancels any in-progress keybind capture (e.g. options window closed mid-listen).
function Options.CancelKeybindCapture()
  if not keybindCaptureStopPrevious then
    return
  end
  local stop = keybindCaptureStopPrevious
  keybindCaptureStopPrevious = nil
  keybindCaptureOnKey = nil
  if keybindCaptureFrame then
    keybindCaptureFrame:Hide()
  end
  stop()
end

function UI.MakeKeybind(parent, opts)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  local button = CreateFrame("Button", nil, row)
  button:SetHeight(UI.Sizes.control)
  UI.StyleControl(button)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyDown")
  button:EnableMouseWheel(false)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  text:SetTextColor(C.text[1], C.text[2], C.text[3])

  local control = {
    frame = row,
    height = ROW_H,
    widget = button,
    widgetH = UI.Sizes.control,
    widgetFill = true,
  }
  local listening = false
  local NOT_BOUND = _G.NOT_BOUND or "Not Bound"

  local function applyKeybindIdle()
    button:cmControlHover(false)
    if listening then
      text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
      return
    end
    local key = opts.get and opts.get()
    if key and key ~= "" then
      text:SetTextColor(C.text[1], C.text[2], C.text[3])
    else
      text:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    end
  end

  button:SetScript("OnEnter", function(self)
    if IsDisabled(opts) or listening then
      return
    end
    self:cmControlHover(true)
    text:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  button:SetScript("OnLeave", function(self)
    if self:IsMouseOver() then
      return
    end
    applyKeybindIdle()
  end)

  local function stopListening()
    if not listening then
      return
    end
    listening = false
    button:EnableMouseWheel(false)
    if keybindCaptureStopPrevious == stopListening then
      keybindCaptureOnKey = nil
      keybindCaptureStopPrevious = nil
      if keybindCaptureFrame then
        keybindCaptureFrame:Hide()
      end
    end
    control.Refresh()
  end

  local function applyKey(key)
    listening = false
    button:EnableMouseWheel(false)
    if keybindCaptureStopPrevious == stopListening then
      keybindCaptureOnKey = nil
      keybindCaptureStopPrevious = nil
      if keybindCaptureFrame then
        keybindCaptureFrame:Hide()
      end
    end
    -- Defense in depth: never persist LMB/RMB (would unbind camera / turn actions).
    if IsPrimaryMouseButtonKey(key) then
      Options.Sync()
      return
    end
    if opts.set then
      opts.set(key)
    end
    Options.Sync()
  end

  local function captureKey(key)
    if not listening then
      return
    end
    if key == "ESCAPE" then
      applyKey("")
      return
    end
    if IGNORE_KEYS[key] or IsPrimaryMouseButtonKey(key) then
      return
    end
    local keyPressed = key
    if _G.IsShiftKeyDown() then
      keyPressed = "SHIFT-" .. keyPressed
    end
    if _G.IsControlKeyDown() then
      keyPressed = "CTRL-" .. keyPressed
    end
    if _G.IsAltKeyDown() then
      keyPressed = "ALT-" .. keyPressed
    end
    if IsPrimaryMouseButtonKey(keyPressed) then
      return
    end
    applyKey(keyPressed)
  end

  local function startListening()
    -- Only one keybind may listen; cancel any previous row without writing a bind.
    if keybindCaptureStopPrevious and keybindCaptureStopPrevious ~= stopListening then
      ReleaseKeybindCapture(stopListening)
    end
    local focused = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if focused and focused.ClearFocus then
      focused:ClearFocus()
    end
    listening = true
    button:EnableMouseWheel(true)
    keybindCaptureOnKey = captureKey
    keybindCaptureStopPrevious = stopListening
    GetKeybindCaptureFrame():Show()
    text:SetText("> Press key (ESC clears) <")
    text:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  end

  button:SetScript("OnClick", function(_, mouseButton)
    if IsDisabled(opts) then
      return
    end
    -- Left/Right only toggle listen mode (AceGUI parity). Binding them would steal the
    -- click used to open/cancel the capture UI.
    if mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then
      return
    end
    if listening then
      stopListening()
      return
    end
    startListening()
  end)

  button:SetScript("OnMouseDown", function(_, mouseButton)
    if mouseButton == "LeftButton" or mouseButton == "RightButton" then
      return
    end
    local key = MOUSE_BUTTON_KEYS[mouseButton] or mouseButton
    captureKey(key)
  end)

  button:SetScript("OnMouseWheel", function(_, direction)
    captureKey(direction >= 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
  end)

  function control.Refresh()
    if listening then
      return
    end
    local key = opts.get and opts.get()
    if key and key ~= "" then
      text:SetText(key)
    else
      text:SetText(NOT_BOUND)
    end
    local disabled = IsDisabled(opts)
    button:SetEnabled(not disabled)
    local a = disabled and DISABLED_A or 1
    row.label:SetAlpha(a)
    button:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    if not disabled and button:IsMouseOver() then
      button:cmControlHover(true)
      text:SetTextColor(C.text[1], C.text[2], C.text[3])
    else
      applyKeybindIdle()
    end
  end

  AddRowHover(row, opts, button)
  AttachOptionText(control, row, opts, UI.Sizes.control)
  return Register(control)
end

---------------------------------------------------------------------------------------
--                                  TEXT INPUT                                       --
---------------------------------------------------------------------------------------
function UI.MakeTextInput(parent, opts)
  local multiline = opts.multiline
  local lines = type(multiline) == "number" and multiline or (multiline and 6 or 1)
  local boxHeight = multiline and (lines * 17 + 12) or 26
  local row = CreateFrame("Frame", nil, parent)
  AddRowLabel(row, opts.label, opts.labelAllowColors and true or false, opts.labelSize)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetHeight(boxHeight)
  UI.StyleField(box)

  local edit
  local helpBtn
  -- Code boxes keep a line-number strip on the left, so their editor starts further right.
  local scrollLeft = (multiline and opts.lua)
      and (CODE_STRIP_INSET + CODE_GUTTER_W + CODE_GUTTER_GAP)
    or 8
  if multiline then
    local scrollRight = opts.helpUrl and 26 or 16
    local barTop = opts.helpUrl and 28 or 6
    local scroll, mlEdit, bar = UI.CreateMultilineEditScroll(box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", scrollLeft, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -scrollRight, 6)
    bar:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -barTop)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 6)
    edit = mlEdit
    if opts.lua then
      -- Both strips are flush against the well's outline (inside it) and share its corner curve on
      -- the outer corners; their inner corners are square.
      local stripRadius = max(UI.Radius.button - CODE_STRIP_INSET, 0)

      -- Line numbers: a slightly lighter strip down the left edge of the well.
      local gutterZone =
        UI.CreateZone(box, C.inputStrip, stripRadius, { TOPLEFT = true, BOTTOMLEFT = true })
      gutterZone:SetWidth(CODE_GUTTER_W)
      gutterZone:SetPoint("TOPLEFT", box, "TOPLEFT", CODE_STRIP_INSET, -CODE_STRIP_INSET)
      gutterZone:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", CODE_STRIP_INSET, CODE_STRIP_INSET)
      -- The numbers live in a frame that clips them to the editor's visible rows and scrolls
      -- them with it.
      local gutterClip = CreateFrame("Frame", nil, box)
      gutterClip:SetPoint("TOPRIGHT", scroll, "TOPLEFT", -CODE_GUTTER_GAP, 0)
      gutterClip:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMLEFT", -CODE_GUTTER_GAP, 0)
      gutterClip:SetFrameLevel(gutterZone:GetFrameLevel() + 2) -- numbers above the strip fill
      gutterClip:SetWidth(CODE_GUTTER_W)
      gutterClip:SetClipsChildren(true)
      local gutterFs =
        UI.CreateFontString(gutterClip, "OVERLAY", UI.Fonts.input, "GameFontHighlightSmall")
      gutterFs:SetPoint("TOPRIGHT", gutterClip, "TOPRIGHT", -4, 0)
      gutterFs:SetJustifyH("RIGHT")
      gutterFs:SetJustifyV("TOP")
      gutterFs:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 0.8)

      -- One-line diagnostic (syntax error / unknown API name) in a reddish strip along the bottom
      -- of the well; the editor and the numbers shrink to make room while it is shown.
      local statusZone =
        UI.CreateZone(box, C.errorStrip, stripRadius, { BOTTOMLEFT = true, BOTTOMRIGHT = true })
      statusZone:SetFrameLevel(gutterClip:GetFrameLevel() + 2) -- above the numbers
      statusZone:SetHeight(CODE_STATUS_H)
      statusZone:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", CODE_STRIP_INSET, CODE_STRIP_INSET)
      statusZone:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -CODE_STRIP_INSET, CODE_STRIP_INSET)
      statusZone:Hide()
      local statusFs =
        UI.CreateFontString(statusZone, "OVERLAY", UI.Fonts.input, "GameFontNormalSmall")
      statusFs:SetPoint("LEFT", statusZone, "LEFT", 8, 0)
      statusFs:SetPoint("RIGHT", statusZone, "RIGHT", -8, 0)
      statusFs:SetJustifyH("LEFT")
      statusFs:SetWordWrap(false)
      statusFs:SetTextColor(C.errorStripText[1], C.errorStripText[2], C.errorStripText[3])

      UI.AttachLuaCodeBox(
        edit,
        function(text)
          local bottom = 6
          if text then
            statusFs:SetText(text)
            statusZone:Show()
            bottom = CODE_STRIP_INSET + CODE_STATUS_H + 4
          else
            statusZone:Hide()
          end
          scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -scrollRight, bottom)
          bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, bottom)
        end,
        box,
        {
          frame = gutterClip,
          zone = gutterZone,
          fs = gutterFs,
          scroll = scroll,
          padRight = 4,
          padTop = 0,
        }
      )
    end
    UI.SetEditBoxFont(edit)
    edit:SetTextColor(C.text[1], C.text[2], C.text[3])
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    -- Clicking the chrome around the edit (padding / rounded fill) also focuses it.
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function()
      if not IsDisabled(opts) then
        edit:SetFocus()
      end
    end)
  else
    edit = CreateFrame("EditBox", nil, box)
    edit:SetAutoFocus(false)
    edit:EnableMouse(true)
    UI.SetEditBoxFont(edit)
    edit:SetTextColor(C.text[1], C.text[2], C.text[3])
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -4)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 4)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
  end

  if multiline and type(opts.helpUrl) == "string" and opts.helpUrl ~= "" then
    -- Sits in the corner of the code box, above the scrollbar. Clicks stay on
    -- this button so they do not focus the editor.
    helpBtn = CreateFrame("Button", nil, box)
    helpBtn:SetSize(20, 20)
    helpBtn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -3, -4)
    helpBtn:SetFrameLevel(box:GetFrameLevel() + 20)
    if helpBtn.SetPropagateMouseClicks then
      helpBtn:SetPropagateMouseClicks(false)
    end
    -- Round "?" badge (same look as the character-specific "C"); the glyph is nudged to look
    -- centred in the circle.
    local help = CreateGlyphBadge(helpBtn, 20, "?", 2, 0, nil, C.textDim)
    helpBtn:SetScript("OnEnter", function()
      help:SetHover(true)
    end)
    helpBtn:SetScript("OnLeave", function()
      help:SetHover(false)
    end)
    helpBtn:SetScript("OnClick", function()
      if UI.ShowCopyLink then
        UI.ShowCopyLink(opts.helpUrl, "WoW API Documentation")
      end
    end)
    UI.AttachTooltip(helpBtn, opts.helpTooltip or "WoW API Documentation", "ANCHOR_RIGHT")
  end

  if type(opts.maxLetters) == "number" and opts.maxLetters > 0 and edit.SetMaxLetters then
    edit:SetMaxLetters(opts.maxLetters)
  end

  local control = {
    frame = row,
    height = boxHeight + (2 * ROW_PAD_Y),
    widget = box,
    widgetH = boxHeight,
    widgetFill = true,
    -- Multiline boxes get the larger column (~60%); single-line keeps the default split.
    textFrac = multiline and 0.40 or nil,
  }

  -- Optional inert placeholder: a dim overlay FontString shown only while the edit is
  -- empty. It is never part of GetText()/commit, so it cannot be saved as a real value.
  local placeholderFs
  local placeholderText = opts.placeholder and UI.StripColors(opts.placeholder) or nil
  if placeholderText and placeholderText ~= "" then
    placeholderFs = UI.CreateFontString(box, "OVERLAY", UI.Fonts.input, "GameFontHighlightSmall")
    placeholderFs:SetPoint("TOPLEFT", box, "TOPLEFT", scrollLeft + 2, -8)
    placeholderFs:SetPoint(
      "TOPRIGHT",
      box,
      "TOPRIGHT",
      multiline and (opts.helpUrl and -26 or -16) or -10,
      -8
    )
    placeholderFs:SetJustifyH("LEFT")
    placeholderFs:SetJustifyV("TOP")
    placeholderFs:SetWordWrap(true)
    if opts.lua and UI.FormatLuaCode then
      -- Code boxes: placeholder gets the same indentation and syntax colors as typed code,
      -- dimmed as a whole so it still reads as a hint.
      placeholderFs:SetText(UI.FormatLuaCode(placeholderText))
      placeholderFs:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 1)
      placeholderFs:SetAlpha(0.7)
    else
      placeholderFs:SetText(placeholderText)
      placeholderFs:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 0.7)
    end
  end

  local function updatePlaceholder()
    if not placeholderFs then
      return
    end
    if edit:GetText() == "" then
      placeholderFs:Show()
    else
      placeholderFs:Hide()
    end
  end

  -- Validation mirrors AceConfig: a string result is an error message and the value
  -- is NOT committed (Sync restores the displayed value from get()).
  local function commit()
    local value = edit:GetText()
    if opts.validate then
      local result = opts.validate(value)
      if type(result) == "string" then
        print(CM.Constants.BasePrintMsg .. "|cff909090: " .. result .. "|r")
        Options.Sync()
        return
      end
    end
    if opts.set then
      opts.set(value)
    end
    Options.Sync()
  end

  edit:HookScript("OnEditFocusLost", commit)
  edit:HookScript("OnTextChanged", updatePlaceholder)

  function control.Refresh()
    if not edit:HasFocus() then
      edit:SetText((opts.get and opts.get()) or "")
    end
    updatePlaceholder()
    local disabled = IsDisabled(opts)
    if edit.SetEnabled then
      edit:SetEnabled(not disabled)
    elseif disabled then
      edit:Disable()
    else
      edit:Enable()
    end
    edit:EnableMouse(not disabled)
    local a = disabled and DISABLED_A or 1
    row.label:SetAlpha(a)
    box:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    -- The field keeps showing (dimmed) unless a notice replaces it. A disabled field with a
    -- watermark option but no message falls back to "Inactive".
    local stamped = SyncStamp(control, opts, disabled, "Inactive")
    box:SetShown(not stamped)
  end

  -- Optional DynamicCam-style stamp over the whole row while this field is inactive
  -- (e.g. preline editor: only the active Auto Lock / Ignore Friendlies field is editable).
  local markOpt = opts.watermarkWhenDisabled
  local markInitial = type(markOpt) == "function" and markOpt() or markOpt
  if type(markInitial) == "string" and markInitial ~= "" then
    control.watermark = UI.CreateRowStamp(row, markInitial)
  elseif type(markOpt) == "function" then
    control.watermark = UI.CreateRowStamp(row, "Inactive")
  end

  -- Box chrome must accept mouse so hover fires over padding; edit covers the inner area.
  box:EnableMouse(true)
  AddRowHover(row, opts, box, edit)
  AttachOptionText(control, row, opts, boxHeight)
  return Register(control)
end

---------------------------------------------------------------------------------------
--                                    BUTTON                                         --
---------------------------------------------------------------------------------------
--- Default: label on the pill. `layout = "row"` matches toggles/dropdowns (title left,
--- `buttonLabel` pill right, optional `desc` under the title).
local function MakeOptionRowButton(parent, opts)
  local btnH = opts.height or UI.Sizes.control
  local buttonText = opts.buttonLabel or "Edit"

  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  local button = CreateFrame("Button", nil, row)
  button:SetHeight(btnH)
  button:EnableMouse(true)
  UI.StyleControl(button)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  text:SetText(UI.StripColors(buttonText) or "Edit")

  local function applyButtonIdle()
    button:cmControlHover(false)
    text:SetTextColor(
      button.cmControlText.idle[1],
      button.cmControlText.idle[2],
      button.cmControlText.idle[3]
    )
  end

  UI.WireControlHover(button, text, function()
    return IsDisabled(opts)
  end)

  button:SetScript("OnClick", function()
    if IsDisabled(opts) then
      return
    end
    if not opts.func then
      return
    end
    if opts.confirm then
      UI.Confirm(opts.confirmText or "Are you sure?", opts.func)
    else
      opts.func()
    end
  end)

  local control = {
    frame = row,
    height = ROW_H,
    button = button,
    widget = button,
    widgetH = btnH,
    widgetFill = true,
  }

  if opts.disabled then
    function control.Refresh()
      local disabled = IsDisabled(opts)
      button:SetEnabled(not disabled)
      local a = disabled and DISABLED_A or 1
      row.label:SetAlpha(a)
      button:SetAlpha(a)
      text:SetAlpha(a)
      SetDescAlpha(control, a)
      ClearHoverIfDisabled(row, disabled)
      if disabled then
        applyButtonIdle()
      end
    end
    Register(control)
    control.Refresh()
  end

  AddRowHover(row, opts, button)
  AttachOptionText(control, row, opts, btnH)
  return control
end

function UI.MakeButton(parent, opts)
  if opts.layout == "row" then
    return MakeOptionRowButton(parent, opts)
  end

  local btnH = opts.height or UI.Sizes.control
  local btnW = opts.pixelWidth or 200
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(btnH)

  local button = CreateFrame("Button", nil, row)
  button:SetHeight(btnH)
  button:SetWidth(btnW)
  button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  -- Standard control surface; opts.danger (Uninstall) is the red danger variant.
  UI.StyleControl(button, opts.danger and "danger" or nil)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.button, "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(UI.StripColors(opts.label) or "")
  UI.WireControlHover(button, text)
  button:SetScript("OnClick", function()
    if not opts.func then
      return
    end
    if opts.confirm then
      UI.Confirm(opts.confirmText or "Are you sure?", opts.func)
    else
      opts.func()
    end
  end)

  local control = { frame = row, height = btnH, isButton = true, button = button }
  if opts.disabled then
    function control.Refresh()
      local disabled = IsDisabled(opts)
      button:SetEnabled(not disabled)
      local a = disabled and DISABLED_A or 1
      button:SetAlpha(a)
      SetDescAlpha(control, a)
      ClearHoverIfDisabled(row, disabled)
    end
    Register(control)
  end

  -- Buttons keep the label on the button itself; helper text stacks tightly underneath.
  local raw = opts.desc
  if type(raw) == "function" then
    raw = raw()
  end
  local plain = raw and UI.StripColors(raw)
  if plain and plain ~= "" then
    local desc = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 4, -TEXT_GAP)
    desc:SetJustifyH("LEFT")
    desc:SetJustifyV("TOP")
    desc:SetWordWrap(true)
    desc:SetText(plain)
    desc:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    control.desc = desc
  end

  function control.SetWidthTo(width)
    if opts.width == "full" then
      button:SetWidth(width)
    end
    local h = btnH
    if control.desc then
      control.desc:SetWidth(max(button:GetWidth(), width) - 8)
      h = btnH + TEXT_GAP + control.desc:GetStringHeight() + 4
    end
    row:SetWidth(width)
    row:SetHeight(h)
    control.height = h
    return h
  end
  return control
end

---------------------------------------------------------------------------------------
--                              HEADER & DESCRIPTION                                 --
---------------------------------------------------------------------------------------
--- Section title: uppercase cream text over a full-width accent rule (mockup style).
--- Accepts a string or `{ text = "...", newFeatureFlag = true, fontSize = n }` (NEW badge, size).
function UI.MakeHeader(parent, textOrOpts)
  local text = textOrOpts
  local newFeature = false
  local fontSize = UI.Fonts.header
  if type(textOrOpts) == "table" then
    text = textOrOpts.text or textOrOpts.label
    fontSize = textOrOpts.fontSize or fontSize
    newFeature = textOrOpts.newFeatureFlag and true or false
  end

  -- Rule under the title: the header atlas across the full width (capped to stay a line), or
  -- the fading accent hairline when the atlas is not available. The atlas has a centre
  -- ornament, so the title sits above its full height instead of on it.
  local atlasInfo = C_Texture
    and C_Texture.GetAtlasInfo
    and C_Texture.GetAtlasInfo(HEADER_RULE_ATLAS)
  local ruleH = atlasInfo and min(max(atlasInfo.height or 8, 1), HEADER_RULE_MAX_H) or 0
  local headerH = atlasInfo and (ruleH + 24) or 28
  local titleY = atlasInfo and (ruleH + 4) or 5

  local headerRule
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(headerH)
  local fs = UI.CreateFontString(frame, "OVERLAY", fontSize, "GameFontNormalLarge")
  fs:SetPoint("BOTTOM", frame, "BOTTOM", 0, titleY)
  fs:SetText((UI.StripColors(text) or ""):upper())
  fs:SetTextColor(C.text[1], C.text[2], C.text[3])

  local badge
  if newFeature then
    badge = UI.CreateNewFeatureBadge(frame)
    UI.PlaceNewFeatureBadge(badge, fs, nil, nil, UI.NewFeatureBadge.headerGap)
  end

  if atlasInfo then
    local rule = frame:CreateTexture(nil, "ARTWORK")
    rule:SetAtlas(HEADER_RULE_ATLAS, false)
    rule:SetHeight(ruleH)
    rule:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
    rule:SetWidth(200)
    headerRule = rule
  else
    local line = UI.CreateLine(frame, false, C.headerRule, "fade")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  end

  local control = { frame = frame, height = headerH, label = fs, badge = badge }
  -- Re-seat the badge after layout width is known (string width is reliable then).
  function control.SetWidthTo(width)
    if headerRule and width and width > 0 then
      headerRule:SetWidth(width * HEADER_RULE_WIDTH_FRAC)
    end
    if badge then
      UI.PlaceNewFeatureBadge(badge, fs, nil, nil, UI.NewFeatureBadge.headerGap)
    end
    return control.height
  end
  return control
end

function UI.MakeDescription(parent, textOrOpts)
  local text = textOrOpts
  local color = C.textDim
  local warningText
  local warningColor = C.warning
  local allowColors = false
  if type(textOrOpts) == "table" then
    text = textOrOpts.text
    if textOrOpts.color then
      color = textOrOpts.color
    end
    if textOrOpts.allowColors then
      allowColors = true
    end
    if textOrOpts.warning and textOrOpts.warning ~= "" then
      warningText = textOrOpts.warning
      if textOrOpts.warningColor then
        warningColor = textOrOpts.warningColor
      end
    end
  end

  local frame = CreateFrame("Frame", nil, parent)
  local fs = UI.CreateFontString(frame, "OVERLAY", UI.Fonts.sectionDesc, "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", frame, "TOPLEFT", HEADER_PAD_X, 0)
  fs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -HEADER_PAD_X, 0)
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(true)
  local display = allowColors and text or UI.StripColors(text)
  fs:SetText(display or "")
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)

  local warningFs
  if warningText then
    -- Keep warning in the same description block so layout ITEM_GAP does not split the lines.
    warningFs =
      UI.CreateFontString(frame, "OVERLAY", UI.Fonts.sectionDesc, "GameFontHighlightSmall")
    warningFs:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    warningFs:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -2)
    warningFs:SetJustifyH("LEFT")
    warningFs:SetWordWrap(true)
    warningFs:SetText(UI.StripColors(warningText) or "")
    warningFs:SetTextColor(warningColor[1], warningColor[2], warningColor[3], warningColor[4] or 1)
  end

  local control = { frame = frame, height = 20 }
  -- Height depends on final width; recomputed by the layout once width is known.
  function control.SetWidthTo(width)
    fs:SetWidth(width - 8)
    local h = fs:GetStringHeight()
    if warningFs then
      warningFs:SetWidth(width - 8)
      h = h + 2 + warningFs:GetStringHeight()
    end
    h = h + 6
    frame:SetHeight(h)
    control.height = h
    return h
  end
  return control
end

---------------------------------------------------------------------------------------
--                              PILL MULTI-SELECT FACTORY                             --
---------------------------------------------------------------------------------------
--  Builds a pill-based multi-select control with type-ahead suggestions. The
--  `resolver` table must expose:
--    resolveToken(token)        -> { token, spellId, name, icon } or nil
--    filterSuggestions(query, selectedIds, selectedNames) -> { entry, ... }
--    placeholder                -> string (edit box placeholder)
--    byToken (optional)         -> true when chips are identified and stored by their text
--                                  `token` (frame names) instead of a numeric `spellId`
--    pickFrame (optional)       -> function(onPick): adds a magnifier button at the box's top
--                                  right that calls it; onPick(token) adds the picked entry
--  An entry may carry `icon` (texture path / file ID) or `atlas` (atlas name) for its chip and
--  suggestion row, and a suggestion may carry `detail`: a short dim label shown at the row's right.
--  Public wrappers (MakeSpellMultiSelect, MakeMountMultiSelect, MakeFrameMultiSelect) pass the
--  right resolver.
--  Related: UI/Options/SpellMultiSelect.lua, UI/Options/MountMultiSelect.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua, UI/Options/Tabs/TabAutoCursorUnlock.lua
---------------------------------------------------------------------------------------
local PILL_BOX_H = 93
local PILL_H = 24
local PILL_GAP = 7
local PILL_PAD_X = 6
local PILL_ICON_SIZE = 18
local PILL_TEXT_SIZE = UI.Fonts.input
local PILL_BOX_PAD = 8
local PILL_MAX_VISIBLE_ROWS = 8
local PILL_SUGGEST_ITEM_H = 22
local PILL_MENU_PAD = 4
local PILL_BAR_GUTTER = 10
local PILL_DEBOUNCE_S = 0.06

--- Makes a spell / mount icon round: zooms in slightly (hides the icon's own square border)
--- and clips it to a circle. Used by the chips in the list and by the suggestion menu rows.
local function RoundIcon(host, icon, size)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local mask = host:CreateMaskTexture()
  local frac = UI.SetCircleMask(mask) or 1
  mask:SetSize(size / frac, size / frac)
  mask:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon:AddMaskTexture(mask)
end

--- Sets a chip / row icon from an entry: an atlas, or a texture (zoomed like RoundIcon does).
local function ApplyEntryIcon(tex, e)
  if e.atlas then
    tex:SetAtlas(e.atlas)
  else
    tex:SetTexture(e.icon)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
end

function UI.MakePillMultiSelect(parent, opts, resolver)
  local row = CreateFrame("Frame", nil, parent)
  -- AddRowLabel is Widgets-local; use AttachOptionText path via a label we create here.
  local label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWordWrap(true)
  label:SetText(UI.StripColors(opts.label) or "")
  label:SetTextColor(C.text[1], C.text[2], C.text[3])
  row.label = label

  local box = CreateFrame("Frame", nil, row)
  box:SetHeight(PILL_BOX_H)
  UI.StyleField(box)
  box:EnableMouse(true)
  box:SetClipsChildren(true)

  -- ScrollFrame inside the fixed box for pill overflow, with the bar inset on the right
  -- (mirrors the multiline edit layout pattern).  Use the 5px bar thickness that
  -- CreateMultilineEditScroll uses.
  local pillScroll, pillContent, pillBar = UI.CreateScrollFrame(box)
  pillScroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
  -- Boxes with a pick button keep their pills clear of it.
  -- Same layout as the code box with its "?" icon: the icon sits in the corner and the scrollbar
  -- starts below it.
  pillScroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", resolver.pickFrame and -26 or -18, 6)
  pillBar:SetPoint(
    "TOPRIGHT",
    box,
    "TOPRIGHT",
    resolver.pickFrame and -4 or -6,
    resolver.pickFrame and -28 or -8
  )
  pillBar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", resolver.pickFrame and -4 or -6, 8)

  local control = {
    frame = row,
    height = PILL_BOX_H + 8,
    widget = box,
    widgetH = PILL_BOX_H,
    widgetFill = true,
    textFrac = 0.40,
  }

  local entries = {}
  local pillFrames = {}
  local suppressCommit = false
  local debounceToken = 0
  local pickingSuggestion = false
  local suggestMenu
  local suggestCloser
  local suggestItems = {}
  local pickButton

  local edit = CreateFrame("EditBox", nil, pillContent)
  edit:SetAutoFocus(false)
  edit:SetHeight(PILL_H)
  UI.SetEditBoxFont(edit)
  edit:SetTextColor(C.text[1], C.text[2], C.text[3])
  edit:SetTextInsets(2, 2, 0, 0)
  if edit.SetPlaceholderText then
    edit:SetPlaceholderText(resolver.placeholder)
  end

  local function SelectedMaps()
    local ids, names = {}, {}
    for _, e in ipairs(entries) do
      if e.spellId then
        ids[e.spellId] = true
      end
      if e.name then
        names[strlower(e.name)] = true
      end
      if e.token then
        names[strlower(e.token)] = true
      end
    end
    return ids, names
  end

  local function IsAlreadySelected(entry)
    local ids, names = SelectedMaps()
    if entry.spellId and ids[entry.spellId] then
      return true
    end
    if entry.name and names[strlower(entry.name)] then
      return true
    end
    if entry.token and names[strlower(entry.token)] then
      return true
    end
    return false
  end

  local function ParseCsvToEntries(csv)
    local out = {}
    if not csv or csv == "" then
      return out
    end
    for part in tostring(csv):gmatch("[^,]+") do
      local entry = resolver.resolveToken(part)
      if entry then
        out[#out + 1] = entry
      end
    end
    return out
  end

  local function EntriesToCsv(list)
    local parts = {}
    local seen = {}
    for _, e in ipairs(list) do
      if resolver.byToken then
        local key = e.token and strlower(e.token)
        if key and not seen[key] then
          seen[key] = true
          parts[#parts + 1] = e.token
        end
      elseif e.spellId and e.spellId > 0 and not seen[e.spellId] then
        seen[e.spellId] = true
        parts[#parts + 1] = tostring(e.spellId)
      end
    end
    return tconcat(parts, ", ")
  end

  local function Commit()
    if suppressCommit then
      return
    end
    if opts.set then
      opts.set(EntriesToCsv(entries))
    end
    Options.Sync()
  end

  local function CloseSuggest()
    if suggestMenu then
      suggestMenu:Hide()
    end
    if suggestCloser then
      suggestCloser:Hide()
    end
  end

  local function LayoutPills()
    local boxW = pillScroll:GetWidth() or box:GetWidth()
    if boxW < 40 then
      boxW = 200
    end
    local maxW = boxW - PILL_BOX_PAD * 2
    local x, y = PILL_BOX_PAD, PILL_BOX_PAD

    for i, pill in ipairs(pillFrames) do
      if i > #entries then
        pill:Hide()
      else
        local e = entries[i]
        local name = e.name or e.token or ""
        pill.text:SetText(name)
        local hasIcon = e.icon or e.atlas
        if hasIcon then
          ApplyEntryIcon(pill.icon, e)
          pill.icon:Show()
          pill.text:ClearAllPoints()
          pill.text:SetPoint("LEFT", pill.icon, "RIGHT", 3, 0)
        else
          pill.icon:Hide()
          pill.text:ClearAllPoints()
          pill.text:SetPoint("LEFT", pill, "LEFT", PILL_PAD_X, 0)
        end
        local textW = pill.text:GetStringWidth() or 0
        local w = PILL_PAD_X * 2 + 12 + textW -- × button space
        if hasIcon then
          w = w + PILL_ICON_SIZE + 3
        end
        w = min(w, maxW)
        pill:SetSize(w, PILL_H)
        if x + w > maxW + 0.5 and x > PILL_BOX_PAD then
          x = PILL_BOX_PAD
          y = y + PILL_H + PILL_GAP
        end
        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", pillContent, "TOPLEFT", x, -y)
        pill:Show()
        x = x + w + PILL_GAP
      end
    end

    local editMin = 60
    if x + editMin > maxW + 0.5 and x > PILL_BOX_PAD then
      x = PILL_BOX_PAD
      y = y + PILL_H + PILL_GAP
    end
    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", pillContent, "TOPLEFT", x, -y)
    edit:SetPoint("RIGHT", pillContent, "RIGHT", -PILL_BOX_PAD, 0)
    edit:SetHeight(PILL_H)

    -- Size the scroll content to the total pill height. The fixed box clips it.
    local contentH = max(y + PILL_H + PILL_BOX_PAD, PILL_BOX_H)
    pillContent:SetSize(boxW, contentH)
    if pillScroll.cmUpdate then
      pillScroll.cmUpdate()
    end
  end

  local function EnsurePill(i)
    local pill = pillFrames[i]
    if pill then
      return pill
    end
    pill = CreateFrame("Frame", nil, pillContent)
    -- Fully rounded chip: corner radius is half the chip height.
    UI.StyleControl(pill, nil, PILL_H / 2)
    pill:SetHeight(PILL_H)

    local icon = pill:CreateTexture(nil, "ARTWORK")
    icon:SetSize(PILL_ICON_SIZE, PILL_ICON_SIZE)
    -- Concentric with the rounded end: the gap to the left edge matches the gap above/below.
    icon:SetPoint("LEFT", pill, "LEFT", (PILL_H - PILL_ICON_SIZE) / 2, 0)
    RoundIcon(pill, icon, PILL_ICON_SIZE)
    pill.icon = icon

    local text = UI.CreateFontString(pill, "OVERLAY", PILL_TEXT_SIZE, "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetTextColor(C.text[1], C.text[2], C.text[3])
    pill.text = text

    local remove = CreateFrame("Button", nil, pill)
    remove:SetSize(14, 14)
    remove:SetPoint("RIGHT", pill, "RIGHT", -5, 0)
    local rx = UI.CreateFontString(remove, "OVERLAY", PILL_TEXT_SIZE, "GameFontHighlightSmall")
    rx:SetAllPoints()
    rx:SetJustifyH("CENTER")
    rx:SetText("×")
    rx:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    remove:SetScript("OnEnter", function()
      rx:SetTextColor(C.warning[1], C.warning[2], C.warning[3])
    end)
    remove:SetScript("OnLeave", function()
      rx:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    end)
    pill.remove = remove
    text:SetPoint("RIGHT", remove, "LEFT", -2, 0)

    pillFrames[i] = pill
    return pill
  end

  function control._reflowPills()
    for i = 1, #entries do
      local pill = EnsurePill(i)
      local idx = i
      pill.remove:SetScript("OnClick", function()
        if Options.IsDisabled(opts) then
          return
        end
        if idx <= #entries then
          tremove(entries, idx)
          control._reflowPills()
          Commit()
        end
      end)
    end
    LayoutPills()
  end

  local function AddEntry(entry)
    if not entry or IsAlreadySelected(entry) then
      return false
    end
    if resolver.byToken then
      if not entry.token or entry.token == "" then
        return false
      end
      entries[#entries + 1] = {
        token = entry.token,
        name = entry.name or entry.token,
        icon = entry.icon,
        atlas = entry.atlas,
      }
    else
      if not entry.spellId or entry.spellId <= 0 then
        return false
      end
      entries[#entries + 1] = {
        token = tostring(entry.spellId),
        spellId = entry.spellId,
        name = entry.name or tostring(entry.spellId),
        icon = entry.icon,
      }
    end
    edit:SetText("")
    control._reflowPills()
    Commit()
    return true
  end

  local function PickSuggestion(entry)
    if not entry or Options.IsDisabled(opts) then
      return
    end
    pickingSuggestion = true
    CloseSuggest()
    AddEntry(entry)
    edit:SetFocus()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        pickingSuggestion = false
      end)
    else
      pickingSuggestion = false
    end
  end

  -- Inspect button at the top right: pick a frame straight from the screen instead of typing it.
  if resolver.pickFrame then
    pickButton = CreateFrame("Button", nil, box)
    pickButton:SetSize(20, 20)
    pickButton:SetPoint("TOPRIGHT", box, "TOPRIGHT", -3, -4)
    pickButton:SetFrameLevel(box:GetFrameLevel() + 5)
    local pickIcon = pickButton:CreateTexture(nil, "ARTWORK")
    pickIcon:SetAllPoints()
    pickIcon:SetAtlas("decor-controls-inspect-default")
    pickIcon:SetAlpha(0.75)
    pickButton:SetScript("OnEnter", function()
      pickIcon:SetAlpha(1)
    end)
    pickButton:SetScript("OnLeave", function()
      pickIcon:SetAlpha(0.75)
    end)
    pickButton:SetScript("OnClick", function()
      if Options.IsDisabled(opts) then
        return
      end
      CloseSuggest()
      resolver.pickFrame(function(token)
        local entry = resolver.resolveToken(token)
        if entry then
          AddEntry(entry)
        end
      end)
    end)
    UI.AttachTooltip(pickButton, "Pick a frame on screen", "ANCHOR_TOP")
  end

  local function EnsureSuggestMenu()
    if suggestMenu then
      return
    end
    suggestCloser = CreateFrame("Button", nil, UIParent)
    suggestCloser:SetAllPoints(UIParent)
    suggestCloser:SetFrameStrata("FULLSCREEN_DIALOG")
    suggestCloser:EnableMouse(true)
    suggestCloser:Hide()
    suggestCloser:SetScript("OnMouseDown", function()
      if not pickingSuggestion then
        CloseSuggest()
      end
    end)

    suggestMenu = CreateFrame("Frame", nil, UIParent)
    suggestMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    suggestMenu:SetFrameLevel(suggestCloser:GetFrameLevel() + 10)
    suggestMenu:SetToplevel(true)
    UI.StylePopup(suggestMenu)
    suggestMenu:Hide()
    suggestMenu:EnableMouse(true)
    suggestMenu:SetScript("OnHide", function()
      suggestCloser:Hide()
    end)

    local scroll, content, bar = UI.CreateScrollFrame(suggestMenu)
    -- Let clicks reach suggestion buttons (ScrollFrame mouse can eat them otherwise).
    scroll:EnableMouse(false)
    suggestMenu.scroll = scroll
    suggestMenu.content = content
    suggestMenu.bar = bar
    scroll:SetPoint("TOPLEFT", suggestMenu, "TOPLEFT", PILL_MENU_PAD, -PILL_MENU_PAD)
  end

  local function OpenSuggest(matches)
    EnsureSuggestMenu()
    local shown = #matches
    if shown == 0 then
      CloseSuggest()
      return
    end

    local width = max(box:GetWidth(), 180)
    suggestMenu:SetWidth(width)
    local needsBar = shown > PILL_MAX_VISIBLE_ROWS
    local visible = needsBar and PILL_MAX_VISIBLE_ROWS or shown
    local gutter = needsBar and PILL_BAR_GUTTER or 0
    local scrollW = width - PILL_MENU_PAD * 2 - gutter
    local listH = visible * PILL_SUGGEST_ITEM_H

    suggestMenu.content:SetWidth(scrollW)
    suggestMenu.scroll:SetWidth(scrollW)
    suggestMenu.scroll:SetHeight(listH)
    suggestMenu.bar:ClearAllPoints()
    suggestMenu.bar:SetPoint("TOP", suggestMenu.scroll, "TOP", 0, 0)
    suggestMenu.bar:SetPoint("BOTTOM", suggestMenu.scroll, "BOTTOM", 0, 0)
    suggestMenu.bar:SetPoint("RIGHT", suggestMenu, "RIGHT", -5, 0)
    SetMenuBarActive(suggestMenu.bar, needsBar)

    for i = 1, shown do
      local item = suggestItems[i]
      if not item then
        item = CreateFrame("Button", nil, suggestMenu.content)
        item:SetHeight(PILL_SUGGEST_ITEM_H)
        item.hl = UI.CreateRoundedHover(item, item)
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(PILL_ICON_SIZE, PILL_ICON_SIZE)
        item.icon:SetPoint("LEFT", item, "LEFT", 6, 0)
        RoundIcon(item, item.icon, PILL_ICON_SIZE)
        item.detail = UI.CreateFontString(item, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
        item.detail:SetPoint("RIGHT", item, "RIGHT", -8, 0)
        item.detail:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
        item.text = UI.CreateFontString(item, "OVERLAY", UI.Fonts.button, "GameFontHighlightSmall")
        item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
        item.text:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        item.text:SetJustifyH("LEFT")
        item.text:SetWordWrap(false)
        item.text:SetTextColor(C.text[1], C.text[2], C.text[3])
        item:SetScript("OnEnter", function(self)
          self.hl:Show()
        end)
        item:SetScript("OnLeave", function(self)
          self.hl:Hide()
        end)
        -- OnMouseDown beats EditBox focus-loss closing the menu before OnClick.
        item:SetScript("OnMouseDown", function(self)
          if self.entry then
            PickSuggestion(self.entry)
          end
        end)
        suggestItems[i] = item
      end
      local m = matches[i]
      item.entry = m
      item.text:SetText(m.name or m.token)
      item.detail:SetText(m.detail or "")
      -- The name ends before the dim detail label (when there is one) so they never overlap.
      local textRight = m.detail and item.detail or item
      local textRightPad = m.detail and -8 or -6
      local textRightPoint = m.detail and "LEFT" or "RIGHT"
      if m.icon or m.atlas then
        ApplyEntryIcon(item.icon, m)
        item.icon:Show()
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
      else
        item.icon:Hide()
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
      end
      item.text:SetPoint("RIGHT", textRight, textRightPoint, textRightPad, 0)
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", suggestMenu.content, "TOPLEFT", 0, -(i - 1) * PILL_SUGGEST_ITEM_H)
      item:SetPoint("TOPRIGHT", suggestMenu.content, "TOPRIGHT", 0, -(i - 1) * PILL_SUGGEST_ITEM_H)
      item:Show()
    end
    for i = shown + 1, #suggestItems do
      suggestItems[i]:Hide()
    end

    suggestMenu.content:SetHeight(max(shown * PILL_SUGGEST_ITEM_H, 1))
    suggestMenu.scroll:SetVerticalScroll(0)
    if suggestMenu.scroll.cmUpdate then
      suggestMenu.scroll.cmUpdate()
    end

    suggestMenu:SetHeight(PILL_MENU_PAD * 2 + listH)
    suggestMenu:ClearAllPoints()
    suggestMenu:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
    suggestCloser:Show()
    suggestMenu:Show()
    suggestMenu:Raise()
  end

  local function RefreshSuggestions()
    if Options.IsDisabled(opts) or not edit:HasFocus() then
      CloseSuggest()
      return
    end
    local ids, names = SelectedMaps()
    local matches = resolver.filterSuggestions(edit:GetText(), ids, names)
    OpenSuggest(matches)
  end

  local function ScheduleSuggest()
    debounceToken = debounceToken + 1
    local token = debounceToken
    if C_Timer and C_Timer.After then
      C_Timer.After(PILL_DEBOUNCE_S, function()
        if token == debounceToken then
          RefreshSuggestions()
        end
      end)
    else
      RefreshSuggestions()
    end
  end

  edit:SetScript("OnTextChanged", function(_, userInput)
    if userInput then
      ScheduleSuggest()
    end
  end)
  edit:SetScript("OnEditFocusGained", function()
    ScheduleSuggest()
  end)
  edit:SetScript("OnEditFocusLost", function()
    -- Delay so suggestion OnMouseDown can set pickingSuggestion first.
    if C_Timer and C_Timer.After then
      C_Timer.After(0.05, function()
        if pickingSuggestion or edit:HasFocus() then
          return
        end
        CloseSuggest()
        -- Clicking away dismisses suggestions only -- never auto-add a partial match.
        edit:SetText("")
      end)
    elseif not pickingSuggestion then
      CloseSuggest()
      edit:SetText("")
    end
  end)
  edit:SetScript("OnEscapePressed", function(self)
    if suggestMenu and suggestMenu:IsShown() then
      CloseSuggest()
    else
      self:ClearFocus()
    end
  end)
  edit:SetScript("OnEnterPressed", function(self)
    local ids, names = SelectedMaps()
    local matches = resolver.filterSuggestions(self:GetText(), ids, names)
    if matches[1] then
      PickSuggestion(matches[1])
    else
      local leftover = strtrim(self:GetText() or "")
      if leftover ~= "" then
        local entry = resolver.resolveToken(leftover)
        if entry and (entry.spellId or resolver.byToken) then
          PickSuggestion(entry)
        end
      else
        CloseSuggest()
      end
    end
  end)
  edit:SetScript("OnKeyDown", function(self)
    -- Must run inside OnKeyDown on Mainline or movement binds (W/A/S/D) still fire.
    if self.SetPropagateKeyboardInput then
      self:SetPropagateKeyboardInput(false)
    end
  end)

  box:SetScript("OnMouseDown", function()
    if not Options.IsDisabled(opts) then
      edit:SetFocus()
    end
  end)

  function control.Refresh()
    if edit:HasFocus() then
      return
    end
    suppressCommit = true
    local raw = (opts.get and opts.get()) or ""
    entries = ParseCsvToEntries(raw)
    control._reflowPills()
    -- Migrate legacy name tokens → ID CSV when the options UI loads the control.
    local normalized = EntriesToCsv(entries)
    if opts.set and strtrim(raw) ~= normalized then
      opts.set(normalized)
    end
    suppressCommit = false
    local disabled = Options.IsDisabled(opts)
    if edit.SetEnabled then
      edit:SetEnabled(not disabled)
    end
    box:SetAlpha(disabled and (C.disabledAlpha or 0.5) or 1)
    if pickButton then
      pickButton:SetEnabled(not disabled)
    end
    if row.label then
      row.label:SetAlpha(disabled and (C.disabledAlpha or 0.5) or 1)
    end
    if disabled then
      CloseSuggest()
    end
  end

  -- After width is known, reflow pills inside the box.
  Options.AttachOptionText(control, row, opts, PILL_BOX_H)
  local prevSetWidthTo = control.SetWidthTo
  function control.SetWidthTo(width)
    if prevSetWidthTo then
      prevSetWidthTo(width)
    end
    LayoutPills()
    return control.height
  end

  Options.AddRowHover(row, opts, box, edit)
  control._reflowPills()
  return Options.RegisterControl(control)
end
