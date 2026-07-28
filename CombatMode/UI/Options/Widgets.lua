---------------------------------------------------------------------------------------
--  UI/Options/Widgets.lua — OPTIONS TOOLKIT — control factories
---------------------------------------------------------------------------------------
--  Owns the reusable option controls for the custom options window: toggle switch,
--  slider (accent fill + eased value transitions), dropdown (custom high-strata popup
--  w/ filter + scroll), keybind capture, text/multiline input, pill button, section
--  header, and wrapped description. Every value control exposes :Refresh()
--  (re-pulls get()/disabled()) and auto-registers with CM.UI.Options for the central
--  SyncControls pass. Confirmation dialogs route through UI.Confirm / UI.Notify
--  (CombatModeConfirmDialog; body text is stripped of color markup). The first-install
--  greeting uses a dedicated UI.ShowWelcome modal (CombatModeWelcomeDialog) that keeps
--  inline |cff| colors for slash-command hints and is not registered in UISpecialFrames,
--  so Blizzard's load-end CloseSpecialWindows cannot dismiss it.
--
--  All text renders at the fixed UI.Fonts.base size with inline color markup stripped
--  (UI.StripColors); UI.MakeHeader is the sole exception (larger + accent yellow), and
--  toggles use accent yellow when on / grey when off with a short knob/track ease on change.
--  Option rows follow a WaypointUI-style 60/40 split: title + muted helper text
--  (`opts.desc`) stack tightly in the left column, and the interactive control sits in
--  the right column (vertically centered). `opts.charSpecific = true` places a blue ©
--  mark to the right of the title (tooltip: character-specific option).
--
--  Consumes UI/Options/Draw.lua primitives + theme tokens. Contains no feature logic:
--  controls call the get/set/disabled closures supplied by the tab builders, which in
--  turn call existing CM.* feature APIs and CM.DB fields.
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetCurrentKeyBoardFocus = _G.GetCurrentKeyBoardFocus
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
local tostring = _G.tostring
local type = _G.type

local UI = CM.UI
local C = UI.Colors
UI.Options = UI.Options or {}
local Options = UI.Options
Options.controls = Options.controls or {}

local ROW_H = 30

---------------------------------------------------------------------------------------
--                                 SHARED HELPERS                                    --
---------------------------------------------------------------------------------------
--- Refreshes every registered control (values + enabled state). Cheap; called on
--- panel open and after any set() that could change another control's disabled state.
function Options.Sync()
  for _, control in ipairs(Options.controls) do
    if control.Refresh then
      control.Refresh()
    end
    if control.UpdateCharScopeTag then
      control.UpdateCharScopeTag()
    end
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

  local hl = UI.CreateRoundedHover(row, bounds, C.tabHover, UI.Radius.control)

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
local CONFIRM_HEADER_H = 24
local CONFIRM_TITLE_W = 95
local CONFIRM_TITLE_H = 22
local CONFIRM_BTN_W = 116
local CONFIRM_BTN_H = 24
local confirmDialog
local welcomeDialog

--- Logo + wordmark row, horizontally centered under the dialog top edge.
local function AttachBrandedHeader(dialog)
  local header = CreateFrame("Frame", nil, dialog)
  header:SetSize(CONFIRM_HEADER_H + 8 + CONFIRM_TITLE_W, CONFIRM_HEADER_H)
  header:SetPoint("TOP", dialog, "TOP", 0, -CONFIRM_PAD)

  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetTexture(CM.Constants.Logo)
  logo:SetSize(CONFIRM_HEADER_H, CONFIRM_HEADER_H)
  logo:SetPoint("LEFT", header, "LEFT", 0, 0)

  local titleArt = header:CreateTexture(nil, "ARTWORK")
  titleArt:SetTexture(CM.Constants.Title)
  titleArt:SetSize(CONFIRM_TITLE_W, CONFIRM_TITLE_H)
  titleArt:SetPoint("LEFT", logo, "RIGHT", 8, 0)

  return header
end

--- Neutral pill button matching UI.MakeButton, minus the layout row wrapper.
local function CreateDialogButton(parent, label)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(CONFIRM_BTN_W, CONFIRM_BTN_H)
  local idle = { 0.16, 0.16, 0.16, 1 }
  UI.StylePill(button, idle, C.cardBorder)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(UI.StripColors(label) or "")
  text:SetTextColor(C.text[1], C.text[2], C.text[3])

  button:SetScript("OnEnter", function(self)
    self:cmSetFill(0.26, 0.26, 0.26, 1)
    text:SetTextColor(1, 1, 1)
  end)
  button:SetScript("OnLeave", function(self)
    self:cmSetFill(idle[1], idle[2], idle[3], 1)
    text:SetTextColor(C.text[1], C.text[2], C.text[3])
  end)
  button.text = text
  return button
end

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
  UI.StyleRounded(dialog, C.windowBg, C.windowBorder, UI.Radius.window)
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
      + CONFIRM_HEADER_H
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
  UI.StyleRounded(dialog, C.windowBg, C.windowBorder, UI.Radius.window)
  dialog:EnableMouse(true)
  dialog:Hide()

  local header = AttachBrandedHeader(dialog)

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
  dialog:SetHeight(CONFIRM_PAD + CONFIRM_HEADER_H + 12 + msgH + 16 + CONFIRM_BTN_H + CONFIRM_PAD)

  dialog:ClearAllPoints()
  dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

  dialog.blocker:Show()
  dialog.blocker:Raise()
  dialog:Show()
  dialog:Raise()
end

--- WaypointUI-style option row: left ~60% holds the title + helper text stacked
--- tightly; right ~40% holds the interactive control. The text block and the control
--- are vertically centered against each other within the row. `opts.labelInset` is
--- accepted for back-compat but ignored.
local TEXT_FRAC = 0.58
local ROW_PAD_X = 10
local ROW_PAD_Y = 4
local TEXT_GAP = 1
local DESC_BELOW_GAP = 6
local CONTROL_GAP = 20
local ICON_GAP = 6
local DEFAULT_ICON_SIZE = 20
local CHAR_SCOPE_MARK = "©"
local CHAR_SCOPE_MARK_SIZE = 11
local CHAR_SCOPE_MARK_W = 12
local CHAR_SCOPE_MARK_GAP = 3
-- Same blue as slash-command hints (|cff69ccf0).
local CHAR_SCOPE_MARK_COLOR = { 0.412, 0.800, 0.941 }
local CHAR_SCOPE_TOOLTIP = "Character-specific option."

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

local function AddRowLabel(row, text)
  local label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X, -ROW_PAD_Y)
  label:SetJustifyH("LEFT")
  label:SetJustifyV("TOP")
  label:SetWordWrap(true)
  label:SetText(UI.StripColors(text) or "")
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

--- Attaches opts.desc and installs SetWidthTo. Default layout is the WaypointUI-style
--- 60/40 split (title+helper left, control right, vertically centered). When
--- `opts.descBelow` is set, the title shares a top band with the control and the helper
--- spans the full row width underneath (used by the narrow sidebar footer).
--- `opts.iconAtlas` / `opts.iconSize` place a texture left of the title.
--- When `opts.iconFitText` is set, the icon grows to the title+helper block height and
--- is vertically centered against that whole column (Click Casting mouse icons).
--- `opts.charSpecific` places a blue © to the right of the title (bool or function).
--- `control.widgetH` / `control.widgetFill` / `control.textFrac` behave as elsewhere
--- (multiline inputs use textFrac 0.40 so the box gets ~60%).
local function AttachOptionText(control, row, opts, widgetH)
  control.widgetH = widgetH or ROW_H
  control.descBelow = opts.descBelow and true or nil
  control.iconFitText = opts.iconFitText and true or nil
  control.charSpecificOpt = opts.charSpecific

  if opts.iconAtlas then
    local iconSize = opts.iconSize or DEFAULT_ICON_SIZE
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetAtlas(opts.iconAtlas)
    icon:SetSize(iconSize, iconSize)
    control.icon = icon
    control.iconSize = iconSize
  end

  if opts.charSpecific ~= nil then
    -- Hit frame so the © can receive mouse for the tooltip (FontStrings cannot).
    local hit = CreateFrame("Frame", nil, row)
    hit:SetSize(CHAR_SCOPE_MARK_W, CHAR_SCOPE_MARK_W)
    hit:EnableMouse(true)
    local mark = UI.CreateFontString(hit, "OVERLAY", CHAR_SCOPE_MARK_SIZE, "GameFontHighlight")
    mark:SetPoint("CENTER")
    mark:SetText(CHAR_SCOPE_MARK)
    mark:SetTextColor(CHAR_SCOPE_MARK_COLOR[1], CHAR_SCOPE_MARK_COLOR[2], CHAR_SCOPE_MARK_COLOR[3])
    hit.mark = mark
    control.scopeTag = hit
    UI.AttachTooltip(hit, CHAR_SCOPE_TOOLTIP)
    if not CharSpecificEnabled(opts) then
      hit:Hide()
    end
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
    local iconSize = icon and (control.iconSize or DEFAULT_ICON_SIZE) or 0
    local iconLead = icon and (iconSize + ICON_GAP) or 0
    local scopeTag = control.scopeTag
    local scopeShown = scopeTag and scopeTag:IsShown()
    local h

    if control.descBelow then
      -- Top band: title left + control right; helper full-width below.
      local labelW = max(width - (2 * ROW_PAD_X) - iconLead - CONTROL_GAP - 40, 40)
      row.label:SetWidth(labelW)
      local labelH = row.label:GetStringHeight()
      local bandH = max(labelH, control.widgetH, iconSize)
      local labelTop = ROW_PAD_Y + floor((bandH - labelH) / 2)
      local widgetTop = ROW_PAD_Y + floor((bandH - control.widgetH) / 2)
      local iconTop = ROW_PAD_Y + floor((bandH - iconSize) / 2)

      if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X, -iconTop)
      end
      row.label:ClearAllPoints()
      row.label:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X + iconLead, -labelTop)
      if scopeShown then
        PlaceCharScopeMark(scopeTag, row.label, labelW)
      end
      if widget then
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -ROW_PAD_X, -widgetTop)
      end

      h = ROW_PAD_Y + bandH
      if control.desc then
        control.desc:ClearAllPoints()
        control.desc:SetWidth(width - (2 * ROW_PAD_X))
        control.desc:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X, -(h + DESC_BELOW_GAP))
        h = h + DESC_BELOW_GAP + control.desc:GetStringHeight()
      end
      h = h + ROW_PAD_Y
    else
      local textFrac = control.textFrac or TEXT_FRAC

      local function MeasureText(lead)
        local textW = max(floor(width * textFrac) - ROW_PAD_X - lead, 40)
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

      -- Grow the icon to the title+helper block so it reads flush with both lines.
      if icon and control.iconFitText then
        iconSize = max(control.iconSize or DEFAULT_ICON_SIZE, floor(textH + 0.5))
        icon:SetSize(iconSize, iconSize)
        iconLead = iconSize + ICON_GAP
        textW, _, textH = MeasureText(iconLead)
        iconSize = max(iconSize, floor(textH + 0.5))
        icon:SetSize(iconSize, iconSize)
        iconLead = iconSize + ICON_GAP
      end

      local contentH = max(textH, control.widgetH, iconSize)
      h = contentH + (2 * ROW_PAD_Y)

      -- Center the shorter column against the taller one so title/helper and control
      -- share a vertical midpoint. Icon centers on the full title+helper block.
      local textTop = ROW_PAD_Y + floor((contentH - textH) / 2)
      local widgetTop = ROW_PAD_Y + floor((contentH - control.widgetH) / 2)
      local iconTop = textTop + floor((textH - iconSize) / 2)

      if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X, -iconTop)
      end
      row.label:ClearAllPoints()
      row.label:SetPoint("TOPLEFT", row, "TOPLEFT", ROW_PAD_X + iconLead, -textTop)
      if scopeShown then
        PlaceCharScopeMark(scopeTag, row.label, textW)
      end
      if control.desc then
        control.desc:ClearAllPoints()
        control.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -TEXT_GAP)
      end

      if widget then
        widget:ClearAllPoints()
        widget:SetPoint("TOPRIGHT", row, "TOPRIGHT", -ROW_PAD_X, -widgetTop)
        if control.widgetFill then
          widget:SetPoint(
            "TOPLEFT",
            row,
            "TOPLEFT",
            ROW_PAD_X + textW + iconLead + CONTROL_GAP,
            -widgetTop
          )
        end
      end
    end

    row:SetHeight(h)
    control.height = h
    control._layouting = false
    return h
  end

  -- Provisional until the layout pass assigns width.
  local provisional = control.widgetH + (2 * ROW_PAD_Y)
  if control.icon then
    provisional = max(provisional, control.iconSize + (2 * ROW_PAD_Y))
  end
  if control.desc then
    provisional = provisional + (control.descBelow and (DESC_BELOW_GAP + 28) or 14)
  end
  control.height = provisional
  row:SetHeight(provisional)
end

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

---------------------------------------------------------------------------------------
--                                    TOGGLE                                         --
---------------------------------------------------------------------------------------
local TOGGLE_TRACK_W = 40
local TOGGLE_TRACK_H = 20
local TOGGLE_KNOB = 14
local TOGGLE_KNOB_PAD = 3
local TOGGLE_KNOB_ON_X = TOGGLE_TRACK_W - TOGGLE_KNOB - TOGGLE_KNOB_PAD
local TOGGLE_ANIM_DURATION = 0.14

local function Lerp(a, b, t)
  return a + (b - a) * t
end

function UI.MakeToggle(parent, opts)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  local track = CreateFrame("Frame", nil, row)
  track:SetSize(TOGGLE_TRACK_W, TOGGLE_TRACK_H)
  -- Full stadium pill: corner radius = half track height (StylePill uses control radius 3).
  UI.StyleRounded(track, C.trackOff, C.cardBorder, TOGGLE_TRACK_H / 2)

  local knob = UI.CreateCircle(track, "OVERLAY", C.white)
  knob:SetSize(TOGGLE_KNOB, TOGGLE_KNOB)
  knob:SetPoint("LEFT", track, "LEFT", TOGGLE_KNOB_PAD, 0)

  local control = { frame = row, height = ROW_H, widget = track, widgetH = TOGGLE_TRACK_H }
  local displayT -- nil until first Refresh; 0 = off, 1 = on
  local animFrom, animTo, animElapsed

  local function ApplyToggleVisual(t)
    local x = Lerp(TOGGLE_KNOB_PAD, TOGGLE_KNOB_ON_X, t)
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", track, "LEFT", x, 0)
    track:cmSetFill(
      Lerp(C.trackOff[1], C.accent[1], t),
      Lerp(C.trackOff[2], C.accent[2], t),
      Lerp(C.trackOff[3], C.accent[3], t),
      1
    )
    track:cmSetBorder(
      Lerp(C.cardBorder[1], C.accent[1] * 0.75, t),
      Lerp(C.cardBorder[2], C.accent[2] * 0.75, t),
      Lerp(C.cardBorder[3], C.accent[3] * 0.75, t),
      1
    )
    knob:SetColorTexture(0.95, 0.95, 0.95, 1)
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

    local a = disabled and 0.4 or 1
    row.label:SetAlpha(a)
    track:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    row:SetEnabled(not disabled)
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

  return Register(control)
end

---------------------------------------------------------------------------------------
--                                    SLIDER                                         --
---------------------------------------------------------------------------------------
local SLIDER_ANIM_DURATION = 0.14

function UI.MakeSlider(parent, opts)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_H)
  AddRowLabel(row, opts.label)

  -- Right-column host aligns with dropdowns/buttons. The value readout sits at the host's
  -- left edge (so its left aligns with the other controls) and the slider fills the rest.
  local host = CreateFrame("Frame", nil, row)
  host:SetHeight(22)

  local valueText = UI.CreateFontString(host, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  valueText:SetPoint("LEFT", host, "LEFT", 0, 0)
  valueText:SetWidth(34)
  valueText:SetJustifyH("LEFT")
  valueText:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

  local slider = CreateFrame("Slider", nil, host)
  slider:SetOrientation("HORIZONTAL")
  -- Continuous thumb while dragging; we snap the committed value to `step` ourselves.
  slider:SetObeyStepOnDrag(false)
  slider:SetHeight(16)
  slider:SetPoint("LEFT", valueText, "RIGHT", 4, 0)
  slider:SetPoint("RIGHT", host, "RIGHT", 0, 0)
  slider:SetMinMaxValues(opts.min or 0, opts.max or 1)
  slider:SetValueStep(opts.step or 1)

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(C.trackOff[1], C.trackOff[2], C.trackOff[3], 1)
  track:SetHeight(4)
  track:SetPoint("LEFT", slider, "LEFT", 0, 0)
  track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)

  -- Accent fill from the left edge up to the thumb (follows continuous drag position).
  local fill = slider:CreateTexture(nil, "ARTWORK")
  fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.85)
  fill:SetHeight(4)
  fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
  fill:SetWidth(1)

  -- Custom circular knob (solid fill + circular alpha mask) — no Blizzard slider art.
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(0.88, 0.88, 0.88, 1)
  thumb:SetSize(16, 16)
  local thumbMask = slider:CreateMaskTexture()
  thumbMask:SetTexture(
    "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE",
    "CLAMPTOBLACKADDITIVE"
  )
  thumbMask:SetAllPoints(thumb)
  thumb:AddMaskTexture(thumbMask)
  slider:SetThumbTexture(thumb)

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
    fill:SetWidth(max(1, width * pct))
  end

  local function StopSliderAnim()
    slider:SetScript("OnUpdate", nil)
    animElapsed = nil
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

  slider:HookScript("OnMouseDown", function()
    StopSliderAnim()
    userActive = true
  end)
  slider:HookScript("OnMouseUp", function()
    userActive = false
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
    displayValue = value
    valueText:SetText(tostring(stepRound(value)))
    UpdateFill(value)
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
    local a = disabled and 0.4 or 1
    row.label:SetAlpha(a)
    valueText:SetAlpha(a)
    slider:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
  end

  AddRowHover(row, opts, slider)
  AttachOptionText(control, row, opts, 22)
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
  button:SetHeight(22)
  UI.StylePill(button, C.trackOff, C.cardBorder)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
  text:SetPoint("LEFT", button, "LEFT", 8, 0)
  text:SetPoint("RIGHT", button, "RIGHT", -18, 0)
  text:SetJustifyH("LEFT")
  text:SetTextColor(C.text[1], C.text[2], C.text[3])

  local arrow = button:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
  arrow:SetSize(14, 14)
  arrow:SetPoint("RIGHT", button, "RIGHT", -3, -2)
  arrow:SetVertexColor(0.62, 0.62, 0.62)

  local control = {
    frame = row,
    height = ROW_H,
    widget = button,
    widgetH = 22,
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
  local MENU_PAD = 4
  local BAR_GUTTER = 10
  local FILTER_MIN = 12
  local MAX_ROWS = 12
  local menu

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
    local hl = item:CreateTexture(nil, "BACKGROUND")
    hl:SetAllPoints(item)
    hl:SetColorTexture(1, 1, 1, 0.09)
    hl:Hide()
    item.hl = hl
    item.text = UI.CreateFontString(item, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
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
    UI.StyleRounded(menu, C.windowBg, C.windowBorder, UI.Radius.window)
    menu:Hide()
    menu.items = {}
    menu.closer = closer

    local filter = CreateFrame("EditBox", nil, menu)
    filter:SetAutoFocus(false)
    filter:SetHeight(22)
    UI.SetEditBoxFont(filter)
    filter:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    filter:SetTextInsets(8, 8, 0, 0)
    UI.StyleRounded(filter, C.inputBg, C.cardBorder, UI.Radius.control)
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
    local width = max(button:GetWidth(), 220)
    local scrollW = width - (2 * MENU_PAD) - BAR_GUTTER

    menu.content:SetWidth(scrollW)

    local top = -MENU_PAD
    if useFilter then
      menu.filter:Show()
      menu.filter:SetText("")
      menu.filter:ClearAllPoints()
      menu.filter:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, top)
      menu.filter:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -MENU_PAD, top)
      top = top - 22 - MENU_PAD
    else
      menu.filter:Hide()
    end

    local visibleRows = count > MAX_ROWS and MAX_ROWS or count
    local listH = max(visibleRows * ITEM_H, ITEM_H)

    menu.scroll:ClearAllPoints()
    menu.scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, top)
    menu.scroll:SetWidth(scrollW)
    menu.scroll:SetHeight(listH)

    menu.bar:ClearAllPoints()
    menu.bar:SetPoint("TOP", menu.scroll, "TOP", 0, 0)
    menu.bar:SetPoint("BOTTOM", menu.scroll, "BOTTOM", 0, 0)
    menu.bar:SetPoint("LEFT", menu.scroll, "RIGHT", 2, 0)

    Populate("")

    menu:SetSize(width, -top + listH + MENU_PAD)
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -2)
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

  function control.Refresh()
    local value = opts.get and opts.get()
    text:SetText(DisplayText(value))
    local disabled = IsDisabled(opts)
    button:SetEnabled(not disabled)
    local a = disabled and 0.4 or 1
    row.label:SetAlpha(a)
    button:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
  end

  AddRowHover(row, opts, button)
  AttachOptionText(control, row, opts, 22)
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
  button:SetHeight(22)
  UI.StylePill(button, C.trackOff, C.cardBorder)
  button:EnableMouse(true)
  button:RegisterForClicks("AnyDown")
  button:EnableMouseWheel(false)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  text:SetTextColor(C.text[1], C.text[2], C.text[3])

  local control = {
    frame = row,
    height = ROW_H,
    widget = button,
    widgetH = 22,
    widgetFill = true,
  }
  local listening = false
  local NOT_BOUND = _G.NOT_BOUND or "Not Bound"

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
      text:SetTextColor(C.text[1], C.text[2], C.text[3])
    else
      text:SetText(NOT_BOUND)
      text:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
    end
    local disabled = IsDisabled(opts)
    button:SetEnabled(not disabled)
    local a = disabled and 0.4 or 1
    row.label:SetAlpha(a)
    button:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
  end

  AddRowHover(row, opts, button)
  AttachOptionText(control, row, opts, 22)
  return Register(control)
end

---------------------------------------------------------------------------------------
--                                  TEXT INPUT                                       --
---------------------------------------------------------------------------------------
function UI.MakeTextInput(parent, opts)
  local multiline = opts.multiline
  local lines = type(multiline) == "number" and multiline or (multiline and 6 or 1)
  local boxHeight = multiline and (lines * 16 + 12) or 24
  local row = CreateFrame("Frame", nil, parent)
  AddRowLabel(row, opts.label)

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetHeight(boxHeight)
  UI.StyleRounded(box, C.inputBg, C.cardBorder, UI.Radius.control)

  local edit
  if multiline then
    local scroll, mlEdit, bar = UI.CreateMultilineEditScroll(box)
    scroll:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -12, 6)
    bar:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -6)
    bar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -4, 6)
    edit = mlEdit
    UI.SetEditBoxFont(edit)
    edit:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
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
    edit:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -4)
    edit:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 4)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
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
    placeholderFs = UI.CreateFontString(box, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    placeholderFs:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -8)
    placeholderFs:SetPoint("TOPRIGHT", box, "TOPRIGHT", multiline and -16 or -10, -8)
    placeholderFs:SetJustifyH("LEFT")
    placeholderFs:SetJustifyV("TOP")
    placeholderFs:SetWordWrap(true)
    placeholderFs:SetText(placeholderText)
    placeholderFs:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3], 0.7)
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
    local a = disabled and 0.4 or 1
    row.label:SetAlpha(a)
    box:SetAlpha(a)
    SetDescAlpha(control, a)
    ClearHoverIfDisabled(row, disabled)
    if control.watermark then
      if disabled then
        control.watermark:Show()
      else
        control.watermark:Hide()
      end
    end
  end

  -- Optional DynamicCam-style stamp over the whole row while this field is inactive
  -- (e.g. preline editor: only one of the two fields is active at a time).
  if opts.watermarkWhenDisabled and opts.watermarkWhenDisabled ~= "" then
    control.watermark = UI.CreateWatermark(row, opts.watermarkWhenDisabled, UI.Fonts.nav)
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
function UI.MakeButton(parent, opts)
  local btnH = opts.height or 24
  local btnW = opts.pixelWidth or 200
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(btnH)

  local button = CreateFrame("Button", nil, row)
  button:SetHeight(btnH)
  button:SetWidth(btnW)
  button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  -- Flat neutral button by default. opts.danger uses the warning red for uninstall-style actions.
  -- Accent yellow stays reserved for section titles and selected-tab labels.
  local IDLE = opts.danger
      and {
        C.warning[1] * 0.35,
        C.warning[2] * 0.35,
        C.warning[3] * 0.35,
        1,
      }
    or { 0.16, 0.16, 0.16, 1 }
  local HOVER = opts.danger
      and {
        C.warning[1] * 0.55,
        C.warning[2] * 0.55,
        C.warning[3] * 0.55,
        1,
      }
    or { 0.26, 0.26, 0.26, 1 }
  local TEXT = opts.danger and { C.warning[1], C.warning[2], C.warning[3] }
    or { C.text[1], C.text[2], C.text[3] }
  UI.StylePill(button, IDLE, opts.danger and {
    C.warning[1] * 0.6,
    C.warning[2] * 0.6,
    C.warning[3] * 0.6,
    1,
  } or C.cardBorder)

  local text = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(UI.StripColors(opts.label) or "")
  text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

  button:SetScript("OnEnter", function(self)
    self:cmSetFill(HOVER[1], HOVER[2], HOVER[3], HOVER[4] or 1)
    text:SetTextColor(1, 1, 1)
  end)
  button:SetScript("OnLeave", function(self)
    self:cmSetFill(IDLE[1], IDLE[2], IDLE[3], IDLE[4] or 1)
    text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
  end)
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
      local a = disabled and 0.4 or 1
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

  AddRowHover(row, opts, button)

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
--- Section title: the one place with a larger font, always in the theme accent (yellow).
function UI.MakeHeader(parent, text)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetHeight(26)
  local fs = UI.CreateFontString(frame, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  fs:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
  fs:SetText(UI.StripColors(text) or "")
  fs:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  local line = frame:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.07)
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  line:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  return { frame = frame, height = 26 }
end

function UI.MakeDescription(parent, textOrOpts)
  local text = textOrOpts
  local color = C.textDim
  local warningText
  local warningColor = C.warning
  if type(textOrOpts) == "table" then
    text = textOrOpts.text
    if textOrOpts.color then
      color = textOrOpts.color
    end
    if textOrOpts.warning and textOrOpts.warning ~= "" then
      warningText = textOrOpts.warning
      if textOrOpts.warningColor then
        warningColor = textOrOpts.warningColor
      end
    end
  end

  local frame = CreateFrame("Frame", nil, parent)
  local fs = UI.CreateFontString(frame, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 0)
  fs:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 0)
  fs:SetJustifyH("LEFT")
  fs:SetText(UI.StripColors(text) or "")
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)

  local warningFs
  if warningText then
    -- Keep warning in the same description block so layout ITEM_GAP does not split the lines.
    warningFs = UI.CreateFontString(frame, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
    warningFs:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
    warningFs:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -2)
    warningFs:SetJustifyH("LEFT")
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
