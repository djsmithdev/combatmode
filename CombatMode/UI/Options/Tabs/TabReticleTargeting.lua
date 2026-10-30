---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabReticleTargeting.lua — OPTIONS TAB — reticle targeting
---------------------------------------------------------------------------------------
--  What it does: Wires Reticle Targeting enable (reload + ConfigReticleTargeting),
--  enemy-only preline mode, macroInjectionClickCastOnly, exclude / cast-at-crosshair
--  spell multi-selects, and Target Lock (keybinds, Auto Target Lock, marker, autofocus).
--  Also hosts the Reticle Targeting Macros shelf (option below the spell lists).
--  The CVar and macro-preline editors live on Advanced.
--  Architecture / how it works:
--    • DB.char: reticleTargeting, reticleTargetingEnemyOnly, autoTargetLockOnAttack,
--      targetLockBehavior (Target Lock Behavior dropdown: toggle / switch),
--      macroInjectionClickCastOnly, stickyCrosshair, excludeFromTargetingSpells,
--      castAtCursorSpells.
--    • DB.global: showTargetLockMarker, autofocusLockedTarget, reticleOutline (Target Outline:
--      Outline CVars via CM.ApplyReticleOutlineCVars), selectionCircleMode (Selection Circle
--      dropdown: circle / name CVars via CM.ApplyReticleSelectionCircleCVars).
--    • macroInjectionClickCastOnly disabled/forced when ThirdPartyActionBarsActive.
--    • Spell lists stored as spell-ID CSV; membership in TargetingMacroBuilder.
--    • Macros shelf: round icons of ACM-built macros (CM.EnumerateComposedMacros);
--      drag/click = PickupMacro, right-click edits, "+" opens the Macro Composer.
--    • Target Lock keybinds go through TryApplyBindingChange + AssignNamedKeybind.
--  Does not: Own CVar override table UI (ReticleCVarEditor*) or secure proxies.
--  Related: Core/Runtime/CVarManager.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, Core/Crosshair/FocusNameplateMarker.lua,
--  UI/Options/SpellMultiSelect.lua, UI/Options/Tabs/TabAdvanced.lua,
--  UI/Editors/ReticleCVarEditorPanel.lua,
--  UI/Editors/TargetingMacroPrelinesEditor.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local InCombatLockdown = _G.InCombatLockdown
local PickupMacro = _G.PickupMacro

-- Lua stdlib
local floor = _G.math.floor
local max = _G.math.max
local min = _G.math.min
local strtrim = _G.strtrim
local unpack = _G.unpack

local UI = CM.UI
local C = UI.Colors

local SELECTION_CIRCLE_VALUES = {
  target = "Any Hard Target",
  locked = "Locked Target Only",
  soft = "Soft Target (Blizzard)",
  hidden = "Hidden",
}
local SELECTION_CIRCLE_ORDER = { "target", "locked", "soft", "hidden" }

local TARGET_LOCK_BEHAVIOR_VALUES = {
  toggle = "Toggle",
  switch = "Switch Target",
}
local TARGET_LOCK_BEHAVIOR_ORDER = { "toggle", "switch" }

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

-- Reticle Targeting Macros shelf: icons of the player's ACM-built macros. Dragging (or
-- clicking) one picks the real WoW macro up so it can be dropped on an action bar slot.
local SHELF_ICON = 36
local SHELF_GAP = 10
local SHELF_ROW_GAP = 10
local SHELF_ROWS = 2

local function BuildMacroShelf(parent, width, onHeight)
  local perRow = max(1, floor((width + SHELF_GAP) / (SHELF_ICON + SHELF_GAP)))
  local capacity = perRow * SHELF_ROWS
  local rowH = SHELF_ICON + SHELF_ROW_GAP
  local shelf = CreateFrame("Frame", nil, parent)
  shelf:SetSize(width, rowH)

  -- "+" at the end of the list: opens the composer. Standard control surface (gradient fill +
  -- outline), fully rounded, with the same plus glyph as the option sliders' step buttons.
  local plus = CreateFrame("Button", nil, shelf)
  plus:SetSize(SHELF_ICON, SHELF_ICON)
  UI.StyleControl(plus, nil, SHELF_ICON / 2)
  local glyph = plus:CreateTexture(nil, "OVERLAY")
  CM.SetAtlas(glyph, "common-icon-plus", true)
  local glyphH = glyph:GetHeight() or 16
  local glyphW = glyph:GetWidth() or 16
  if glyphH > 0 then
    glyph:SetSize(glyphW * 12 / glyphH, 12)
  end
  glyph:SetPoint("CENTER")
  glyph:SetDesaturated(true)
  glyph:SetVertexColor(C.text[1], C.text[2], C.text[3])
  plus:HookScript("OnEnter", function(self)
    self:cmControlHover(true)
  end)
  plus:HookScript("OnLeave", function(self)
    self:cmControlHover(false)
  end)
  plus:SetScript("OnClick", function()
    CM.OpenComposedMacroEditor()
  end)
  UI.AttachTooltip(plus, {
    title = "Create New Macro",
    text = "Write a macro that starts with your Reticle Targeting preline.",
  })

  local more = UI.CreateFontString(shelf, "OVERLAY", UI.Fonts.small, "GameFontNormal")
  more:SetPoint("BOTTOMRIGHT", shelf, "BOTTOMRIGHT", 0, 0)
  more:SetTextColor(unpack(C.textDim))

  local buttons = {}
  local function Pickup(self)
    if InCombatLockdown() then
      return
    end
    if self.macroName then
      PickupMacro(self.macroName)
    end
  end

  local function GetButton(i)
    local button = buttons[i]
    if button then
      return button
    end
    button = CreateFrame("Button", nil, shelf)
    button:SetSize(SHELF_ICON, SHELF_ICON)
    button:RegisterForDrag("LeftButton")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnDragStart", Pickup)
    button:SetScript("OnClick", function(self, mouseButton)
      if mouseButton == "RightButton" then
        if self.macroName then
          CM.OpenComposedMacroEditor(self.macroName)
        end
      else
        Pickup(self)
      end
    end)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = button:CreateMaskTexture()
    local frac = UI.SetCircleMask(mask) or 1
    mask:SetSize(SHELF_ICON / frac, SHELF_ICON / frac)
    mask:SetPoint("CENTER", icon, "CENTER", 0, 0)
    icon:AddMaskTexture(mask)
    button.icon = icon

    local hover = button:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.18)
    hover:AddMaskTexture(mask)

    UI.AttachTooltip(button, function()
      return {
        title = button.macroName,
        text = InCombatLockdown() and "Unavailable in combat."
          or "Drag to a button on your action bars to use.",
        -- Tooltip strips inline colors; a line label is drawn in the dim description grey.
        lines = not InCombatLockdown() and { { label = "Right-click to edit" } } or nil,
      }
    end)
    buttons[i] = button
    return button
  end

  local function Refresh()
    local list = CM.EnumerateComposedMacros()
    local shown = min(#list, capacity - 1) -- the last slot is always the "+" button
    local function Place(frame, i)
      frame:ClearAllPoints()
      frame:SetPoint(
        "TOPLEFT",
        shelf,
        "TOPLEFT",
        ((i - 1) % perRow) * (SHELF_ICON + SHELF_GAP),
        -floor((i - 1) / perRow) * rowH
      )
    end
    for i = 1, max(#buttons, shown) do
      local macro = list[i]
      if macro and i <= shown then
        local button = GetButton(i)
        Place(button, i)
        button.macroName = macro.name
        button.icon:SetTexture(macro.icon)
        button:Show()
      elseif buttons[i] then
        buttons[i].macroName = nil
        buttons[i]:Hide()
      end
    end
    Place(plus, shown + 1)
    local rows = floor(shown / perRow) + 1
    shelf.visibleHeight = rows * rowH - SHELF_ROW_GAP
    local hidden = #list - shown
    more:SetText(hidden > 0 and ("+" .. hidden .. " more in /macro") or "")
    shelf:SetHeight(shelf.visibleHeight)
    if onHeight then
      onHeight(shelf.visibleHeight)
    end
  end

  UI.Options.RegisterControl({ frame = shelf, height = rowH, Refresh = Refresh })
  Refresh()
  return shelf
end

local MACRO_LABEL = "Reticle Targeting Macros"
local MACRO_DESC =
  "Action buttons that are macros cannot automatically inherit Reticle Targeting logic. To make them adhere to these rules, create them using the Macro Composer tool, then drag them onto your bars."

--- Option row (label + description above, full-width shelf below). Returns the row frame and
--- its height; `onHeight` is called when the shelf grows or shrinks.
local function BuildMacroShelfRow(parent, width, onHeight)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(width)
  local textW = width - 16

  local label = UI.CreateFontString(row, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  label:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
  label:SetJustifyH("LEFT")
  label:SetWidth(textW)
  label:SetText(MACRO_LABEL)
  label:SetTextColor(C.text[1], C.text[2], C.text[3])

  local desc = UI.CreateFontString(row, "OVERLAY", UI.Fonts.small, "GameFontNormal")
  desc:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
  desc:SetWidth(textW)
  desc:SetJustifyH("LEFT")
  desc:SetJustifyV("TOP")
  desc:SetWordWrap(true)
  desc:SetTextColor(unpack(C.textDim))
  desc:SetText(MACRO_DESC)

  local shelf
  local function Measure()
    local head = 4 + label:GetStringHeight() + 4 + desc:GetStringHeight() + 10
    local h = head + (shelf and shelf.visibleHeight or SHELF_ICON) + 4
    row:SetHeight(h)
    return h
  end

  shelf = BuildMacroShelf(row, textW, function()
    onHeight(Measure())
  end)
  shelf:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
  return row, Measure()
end

UI.Options.AddTab({
  id = "reticle",
  label = "Reticle Targeting",
  build = function(ctx)
    ctx:Header("RETICLE TARGETING")
    ctx:Description(
      "Enables aim-based unit targeting and precise placement of ground-targeted spells and AoE abilities."
    )
    ctx:Toggle({
      label = "Enable Reticle Targeting",
      desc = "Aim the crosshair at units to pick targets instead of tab-targeting.",
      charSpecific = true,
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      reload = true,
      get = function()
        return CM.DB.char.reticleTargeting
      end,
      set = function(value)
        CM.DB.char.reticleTargeting = value
        if value then
          CM.ConfigReticleTargeting("combatmode")
        else
          CM.ConfigReticleTargeting("blizzard")
        end
        CM.ReloadUI()
      end,
    })
    ctx:Toggle({
      label = "Ignore Friendlies",
      desc = "Ignore friendly NPCs and Players, and only target hostile units.",
      charSpecific = true,
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      reload = true,
      get = function()
        return CM.DB.char.reticleTargetingEnemyOnly
      end,
      set = function(value)
        CM.DB.char.reticleTargetingEnemyOnly = value
        CM.ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Click Casting Only",
      desc = "Apply reticle targeting logic only to Click Casting binds.",
      charSpecific = true,
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      reload = true,
      get = function()
        return CM.DB.char.macroInjectionClickCastOnly
      end,
      set = function(value)
        CM.DB.char.macroInjectionClickCastOnly = value
        CM.ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting or CM.ThirdPartyActionBarsActive == true
      end,
    })
    ctx:Gap()
    ctx:SpellMultiSelect({
      label = "Excluded Spells",
      desc = "Spells to skip the reticle targeting logic.",
      charSpecific = true,
      get = function()
        return CM.DB.char.excludeFromTargetingSpells or ""
      end,
      set = function(value)
        CM.DB.char.excludeFromTargetingSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:SpellMultiSelect({
      label = "Cast at Crosshair",
      desc = "Ground spells to cast at the crosshair location.",
      charSpecific = true,
      get = function()
        return CM.DB.char.castAtCursorSpells or ""
      end,
      set = function(value)
        CM.DB.char.castAtCursorSpells = value and strtrim(value) or ""
        if CM.RefreshClickCastMacros then
          CM.RefreshClickCastMacros()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })

    -- Macro shelf: an option row whose height follows the icon rows, so the rest of the tab
    -- (and the scroll content) moves when macros wrap onto a second row.
    local shelfItem
    local lastBase -- visible content height last applied to ctx.content (nil while building)
    local shelfRow, shelfH = BuildMacroShelfRow(ctx.content, ctx.width, function(h)
      if shelfItem and shelfItem.height ~= h then
        shelfItem.height = h
        ctx:Reflow()
        if lastBase then
          local base = -ctx.y - ctx.gap
          ctx.content:SetHeight(ctx.content:GetHeight() + base - lastBase)
          lastBase = base
        end
      end
    end)
    ctx:PlaceFrame(shelfRow, shelfH)
    shelfItem = ctx.items[#ctx.items]
    -- Custom row: add the search metadata ctx:Place would have attached.
    if ctx.search then
      UI.Options.RegisterControl({
        frame = shelfRow,
        height = shelfH,
        search = {
          label = MACRO_LABEL,
          desc = MACRO_DESC,
          tab = ctx.search.tab,
          group = ctx.search.group,
          section = ctx.section,
        },
      })
    end

    ctx:Gap()
    ctx:Header("TARGET LOCK")
    ctx:Description({
      text = "Lock onto a target to prevent accidental switching, and cycle between units to prioritize specific enemies.",
      warning = "Warning: Target Lock uses your Focus Target. "
        .. "Anything else that sets your focus will interfere with it.",
    })

    ctx:Keybind({
      label = "Target Lock Keybind",
      desc = "Lock the reticle to a target, preventing it from swapping.",
      get = function()
        return (GetBindingKey("Combat Mode - Toggle Focus Target"))
      end,
      set = function(key)
        CM.TryApplyBindingChange("target lock keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Toggle Focus Target", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Keybind({
      label = "Cycle Lock - Next",
      desc = "Move Target Lock to the next valid nearby target.",
      get = function()
        return GetBindingKey("Combat Mode - Cycle Focus Next")
      end,
      set = function(key)
        CM.TryApplyBindingChange("cycle focus next keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Cycle Focus Next", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Keybind({
      label = "Cycle Lock - Previous",
      desc = "Move Target Lock to the previous valid nearby target.",
      get = function()
        return GetBindingKey("Combat Mode - Cycle Focus Previous")
      end,
      set = function(key)
        CM.TryApplyBindingChange("cycle focus previous keybinding", function()
          CM.AssignNamedKeybind("Combat Mode - Cycle Focus Previous", key)
        end)
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Dropdown({
      label = "Target Lock Behavior",
      desc = "What the Target Lock key does when you press it.",
      helpTooltip = {
        title = "Target Lock Behavior",
        stacked = true,
        lines = {
          {
            label = "Toggle",
            value = "Locks your target, or the unit under the crosshair. Tap again to unlock.",
          },
          {
            label = "Switch Target",
            value = "Locks the unit under the crosshair, replacing any current lock. Tap with nothing under the crosshair to unlock. Aiming at the unit you already locked keeps the lock.",
            warning = "With Ignore Friendlies on, a friendly or dead unit under the crosshair is ignored: the lock stays where it is.",
          },
        },
      },
      values = TARGET_LOCK_BEHAVIOR_VALUES,
      order = TARGET_LOCK_BEHAVIOR_ORDER,
      get = function()
        local mode = CM.DB.char.targetLockBehavior
        return TARGET_LOCK_BEHAVIOR_VALUES[mode] and mode or "toggle"
      end,
      set = function(value)
        CM.DB.char.targetLockBehavior = value
        CM.ApplyToggleFocusTargetBinding()
        -- Click-cast Toggle Focus actions use the same behaviour.
        CM.RefreshClickCastMacros()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Auto Target Lock",
      desc = "Target Lock engages automatically when attacking units.",
      charSpecific = true,
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      reload = true,
      get = function()
        return CM.DB.char.autoTargetLockOnAttack
      end,
      set = function(value)
        CM.DB.char.autoTargetLockOnAttack = value
        CM.ReloadUI()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Target Lock Marker",
      desc = "Show a crosshair marker on the nameplate of the locked target.",
      get = function()
        return CM.DB.global.showTargetLockMarker ~= false
      end,
      set = function(value)
        CM.DB.global.showTargetLockMarker = value
        if CM.ClearFocusNameplateMarker then
          CM.ClearFocusNameplateMarker()
        end
        if value and CM.UpdateFocusNameplateMarker then
          CM.UpdateFocusNameplateMarker()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    ctx:Toggle({
      label = "Focus Locked Target",
      desc = "Pulls the camera toward your locked target, keeping it in focus.",
      watermarkWhenDisabled = function()
        if CM.MotionSicknessProtectionOn and CM.MotionSicknessProtectionOn() == true then
          return "Disabled while Motion Sickness Protection is on"
        end
        return nil
      end,
      get = function()
        return CM.DB.global.autofocusLockedTarget == true
      end,
      set = function(value)
        CM.DB.global.autofocusLockedTarget = value
        if CM.SyncTargetFocusFromFocusUnit then
          CM.SyncTargetFocusFromFocusUnit()
        end
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
          or (CM.MotionSicknessProtectionOn and CM.MotionSicknessProtectionOn() == true)
      end,
    })

    ctx:Gap()
    ctx:Header({ text = "TARGETING INDICATORS" })
    ctx:Description(
      "Visual indicators that highlight targets in the world for easier identification."
    )
    ctx:Toggle({
      label = "Target Outline",
      desc = "Show an outline effect on your target.",
      get = function()
        return CM.DB.global.reticleOutline ~= false
      end,
      set = function(value)
        CM.DB.global.reticleOutline = value
        CM.ApplyReticleOutlineCVars()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting or not CM.IsRetailClient
      end,
      watermarkWhenDisabled = function()
        if not CM.IsRetailClient then
          return "Only available on Retail"
        end
        return nil
      end,
    })
    ctx:Dropdown({
      label = "Selection Circle",
      desc = "Which target gets Blizzard's selection circle underneath their feet.",
      helpTooltip = {
        title = "Selection Circle",
        stacked = true,
        lines = {
          {
            label = "Any Hard Target",
            value = "The circle under whatever you have targeted, enemy or friendly.",
          },
          { label = "Locked Target Only", value = "The circle only under your Target Lock." },
          {
            label = "Soft Target (Blizzard)",
            value = "Let Blizzard control the behaviour of ObjectSelectionCircle and UnitNameFocused.",
            warning = "Blizzard picks the soft target from an arc in front of your character model. It does not take the crosshair position or the Shoulder Offset into account.",
          },
          { label = "Hidden", value = "No selection circle." },
        },
      },
      values = SELECTION_CIRCLE_VALUES,
      order = SELECTION_CIRCLE_ORDER,
      get = function()
        local mode = CM.DB.global.selectionCircleMode
        return SELECTION_CIRCLE_VALUES[mode] and mode or "target"
      end,
      set = function(value)
        CM.DB.global.selectionCircleMode = value
        CM.ApplyReticleSelectionCircleCVars()
      end,
      disabled = function()
        return not CM.DB.char.reticleTargeting
      end,
    })
    lastBase = -ctx.y - ctx.gap
  end,
})
