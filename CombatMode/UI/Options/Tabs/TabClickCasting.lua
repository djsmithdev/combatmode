---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabClickCasting.lua — OPTIONS TAB — click-cast slot overrides
---------------------------------------------------------------------------------------
--  What it does: Wires the eight mouse click-cast slots (base + shift/ctrl/alt) with
--  enable, key, action dropdown (OverrideActions: Clear Target / Focus, Start Attack / Pet Attack + ActionsToProcess;
--  Target Lock lives on its own keybind, not here),
--  Run MACRO picker: a dropdown of the player's macros (icon + Reticle Targeting tag), and useGlobalBindings.
--  Applies via SetNewBinding / ResetBindingOverride.
--  Architecture / how it works:
--    • Reads/writes CM.DB[GetBindingsLocation()].bindings[slot].
--    • char.useGlobalBindings toggles whether char or global bindings table is edited.
--    • Modifier segment UI groups slots.
--  Does not: Build targeting prelines or resolve third-party bar frames.
--  Related: Core/ClickCasting/BindingOverrides.lua, Constants/Gameplay.lua,
--  UI/Options/Widgets.lua,
--  Constants/DatabaseDefaults.lua, Core/Runtime/Runtime.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetMacroInfo = _G.GetMacroInfo

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local floor = _G.math.floor
local max = _G.math.max
local tinsert = _G.table.insert
local unpack = _G.unpack

local UI = CM.UI
local C = UI.Colors

-- Full dropdown value set: the CombatMode override actions (CM.Constants.OverrideActions)
-- first, followed by every standard bindable action (CM.Constants.ActionsToProcess)
-- labeled via Blizzard's BINDING_NAME_* globals. Built lazily so BINDING_NAME_* are ready.
local OVERRIDE_ORDER = {
  "CLEARFOCUS",
  "CLEARTARGET",
  "STARTATTACK",
  "PETATTACK",
  "MACRO",
}
local ACTION_VALUES
local ACTION_ORDER
local ACTION_COLORS -- value -> rgb: Combat Mode's own actions (copper) and changed Blizzard ones (blue)

local MODIFIER_GROUPS = {
  { id = "base", label = "Base", modifier = nil },
  { id = "shift", label = "Shift", modifier = "shift" },
  { id = "ctrl", label = "Ctrl", modifier = "ctrl" },
  { id = "alt", label = "Alt", modifier = "alt" },
}

local function BuildActionValues()
  if ACTION_VALUES then
    return
  end
  ACTION_VALUES = {}
  ACTION_ORDER = {}
  ACTION_COLORS = {}
  for _, id in ipairs(OVERRIDE_ORDER) do
    ACTION_VALUES[id] = CM.Constants.OverrideActions[id]
    ACTION_COLORS[id] = C.accent
    tinsert(ACTION_ORDER, id)
  end
  -- Blizzard actions Combat Mode changes (pings, raid markers): blue, right after our own copper
  -- ones, so both are easy to tell from the plain Blizzard actions below.
  for _, id in ipairs(CM.Constants.BlizzardActionOrder) do
    ACTION_VALUES[id] = _G["BINDING_NAME_" .. id] or id
    ACTION_COLORS[id] = C.slash
    tinsert(ACTION_ORDER, id)
  end
  for _, id in ipairs(CM.Constants.ActionsToProcess) do
    if id ~= "STARTATTACK" and id ~= "PETATTACK" and not ACTION_VALUES[id] then
      local name = _G["BINDING_NAME_" .. id]
      ACTION_VALUES[id] = name or id
      tinsert(ACTION_ORDER, id)
    end
  end
end

-- Fallback label for a stored value that isn't in the built set (e.g. a custom binding).
local function ActionDisplay(value)
  if not value or value == "" then
    return "— none —"
  end
  return value
end

local function Slot(modifier, index)
  return (modifier or "") .. "button" .. index
end

local function Binding(slot)
  return CM.DB[CM.GetBindingsLocation()].bindings[slot]
end

local function CharScopedBindings()
  return not CM.DB.char.useGlobalBindings
end

local function AddSlot(layout, slot, label, modifier, iconAtlas, leadingIconTexture)
  layout:Toggle({
    label = label,
    desc = "Override this click during Mouse Look.",
    leadingIconTexture = leadingIconTexture,
    iconAtlas = iconAtlas,
    iconFitText = true,
    -- Native mouse atlas is 52x69; keep aspect while fitting row text height.
    iconHeight = 24,
    iconWidth = floor(24 * 52 / 69 + 0.5),
    -- Modifier key BLPs are square; match mouse icon height.
    leadingIconHeight = 24,
    leadingIconWidth = 24,
    get = function()
      return Binding(slot).enabled
    end,
    set = function(value)
      Binding(slot).enabled = value
      if value then
        CM.SetNewBinding(Binding(slot))
      else
        CM.ResetBindingOverride(Binding(slot))
      end
    end,
    disabled = function()
      return modifier == nil
    end,
  })
  layout:Dropdown({
    label = "Action",
    charSpecific = CharScopedBindings,
    values = ACTION_VALUES,
    order = ACTION_ORDER,
    valueColors = ACTION_COLORS,
    display = ActionDisplay,
    get = function()
      return Binding(slot).value
    end,
    set = function(value)
      Binding(slot).value = value
      CM.SetNewBinding(Binding(slot))
    end,
    disabled = function()
      return not Binding(slot).enabled
    end,
  })
  layout:Dropdown({
    label = "Macro",
    -- Re-read each time the menu opens so new / deleted macros show up.
    values = function()
      local values = {}
      for _, macro in ipairs(CM.EnumerateMacros()) do
        values[macro.name] = macro.name
      end
      return values
    end,
    order = function()
      local order = {}
      for _, macro in ipairs(CM.EnumerateMacros()) do
        order[#order + 1] = macro.name
      end
      return order
    end,
    display = function(value)
      if value == nil or value == "" then
        return "Select a macro"
      end
      return value
    end,
    -- Round macro icon on the left; right-hand tag says whether it carries the targeting preline.
    itemInfo = function(id)
      if id == "" then
        return nil
      end
      local _, icon, body = GetMacroInfo(id)
      if not icon then
        return nil
      end
      if CM.IsComposedMacroBody(body) then
        return { icon = icon, detail = "Reticle Targeting", detailColor = C.accent }
      end
      return { icon = icon, detail = "No targeting" }
    end,
    get = function()
      return Binding(slot).macroName
    end,
    set = function(value)
      local binding = Binding(slot)
      binding.macroName = value
      CM.SetNewBinding(binding)
    end,
    -- Only shown once Action is set to Run Macro; rows below move up when hidden.
    hidden = function()
      return Binding(slot).value ~= "MACRO"
    end,
    disabled = function()
      return not Binding(slot).enabled
    end,
  })
end

local function BuildGroupPanel(parent, width, modifier, group, tabSearch)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(width)
  local layout = UI.NewLayout(panel, width)
  layout.y = 0
  -- Base slots have no modifier in their labels, so prefix them for search results.
  layout.search = {
    tab = tabSearch.tab,
    group = group.id,
    prefix = modifier and "" or "Base - ",
  }
  local prefix = ""
  local leadingIconTexture
  if modifier == "shift" then
    prefix = "Shift + "
    leadingIconTexture = CM.Constants.ModifierKeyShift
  elseif modifier == "ctrl" then
    prefix = "Ctrl + "
    leadingIconTexture = CM.Constants.ModifierKeyCtrl
  elseif modifier == "alt" then
    prefix = "Alt + "
    leadingIconTexture = CM.Constants.ModifierKeyAlt
  end
  AddSlot(
    layout,
    Slot(modifier, 1),
    prefix .. "Left Click",
    modifier,
    "newplayertutorial-icon-mouse-leftbutton",
    leadingIconTexture
  )
  layout:Gap(8)
  AddSlot(
    layout,
    Slot(modifier, 2),
    prefix .. "Right Click",
    modifier,
    "newplayertutorial-icon-mouse-rightbutton",
    leadingIconTexture
  )
  layout:Finish()
  --- Height of the rows currently visible (the Macro row only shows for Run MACRO).
  function panel.FitHeight()
    local h = max(1, -layout.y - layout.gap)
    panel:SetHeight(h)
    return h
  end
  -- Collapse the Macro rows that start hidden (bindings are loaded at build time).
  layout:Reflow()
  panel.FitHeight()
  return panel
end

local function BuildSegmentBar(parent, width, groups, onSelect)
  local barH = 34
  local gap = 4
  local n = #groups
  local btnW = (width - gap * (n - 1)) / n
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(width, barH)

  local buttons = {}
  local selectedId = groups[1].id
  local x = 0

  local function Select(id)
    selectedId = id
    for _, button in ipairs(buttons) do
      button:cmSetTabSelected(button.groupId == id)
    end
    onSelect(id)
  end

  for _, group in ipairs(groups) do
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(btnW, barH)
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
    button.groupId = group.id

    local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontNormal")
    label:SetPoint("CENTER", button, "CENTER", 4, 0)
    label:SetText(group.label)
    button.label = label

    -- Same look as the sidebar tabs (selected pill, orange capsule marker, hover wash).
    UI.StyleTab(button, label, 20)

    button:SetScript("OnClick", function()
      Select(group.id)
    end)

    buttons[#buttons + 1] = button
    x = x + btnW + gap
  end

  Select(selectedId)
  return bar, Select
end

UI.Options.AddTab({
  id = "clickcasting",
  label = "Click Casting",
  build = function(ctx)
    BuildActionValues()
    ctx:Header("CLICK CASTING")
    ctx:Description("Assign actions to left and right clicks during Mouse Look.")
    ctx:Toggle({
      label = "Account-Wide Binds",
      desc = "Share Click Casting binds across all characters.",
      charSpecific = true,
      get = function()
        return CM.DB.char.useGlobalBindings
      end,
      set = function(value)
        CM.DB.char.useGlobalBindings = value
        CM.OverrideDefaultButtons()
        UI.Options.Sync()
      end,
    })
    ctx:Gap(8)

    local contentW = ctx.width
    local segmentHost = CreateFrame("Frame", nil, ctx.content)
    segmentHost:SetWidth(contentW)

    local panels = {}
    local panelHost = CreateFrame("Frame", nil, segmentHost)
    for _, group in ipairs(MODIFIER_GROUPS) do
      local panel = BuildGroupPanel(panelHost, contentW, group.modifier, group, ctx.search)
      panel:SetPoint("TOPLEFT", panelHost, "TOPLEFT", 0, 0)
      panel:Hide()
      panel:SetAlpha(1)
      panels[group.id] = panel
    end
    panelHost:SetWidth(contentW)

    local activeGroupId
    local sepGap = 8
    local segmentItem -- the ctx placement record for segmentHost, resized as rows show / hide
    local lastBase -- visible content height last applied to ctx.content (nil while building)

    --- Re-places the rows and grows / shrinks the tab content to the visible height.
    local function Resize()
      ctx:Reflow()
      if lastBase then
        local base = -ctx.y - ctx.gap
        if base ~= lastBase then
          ctx.content:SetHeight(ctx.content:GetHeight() + base - lastBase)
          lastBase = base
        end
      end
    end

    -- Sizes the segment area to the visible panel (the Macro row only shows for Run MACRO).
    local function FitSegments()
      local panel = panels[activeGroupId]
      if not panel then
        return
      end
      local h = panel.FitHeight()
      panelHost:SetHeight(h)
      local total = 34 + sepGap + 1 + sepGap + h
      segmentHost:SetHeight(total)
      if segmentItem and segmentItem.height ~= total then
        segmentItem.height = total
        Resize()
      end
    end

    local function ShowGroup(id)
      if activeGroupId == id then
        local panel = panels[id]
        if panel and panel:IsShown() then
          return
        end
      end

      activeGroupId = id

      for groupId, panel in pairs(panels) do
        if groupId ~= id then
          panel:Hide()
        end
      end

      local incoming = panels[id]
      if incoming then
        incoming:Show()
      end
      FitSegments()
    end

    local bar, selectGroup = BuildSegmentBar(segmentHost, contentW, MODIFIER_GROUPS, ShowGroup)
    bar:SetPoint("TOPLEFT", segmentHost, "TOPLEFT", 0, 0)
    -- Options search uses this to switch segments before scrolling to a result.
    UI.Options.RegisterSegmentSelector("clickcasting", selectGroup)

    -- Hairline under the segment bar so the modifier tabs read separately from the
    -- Left/Right click options below (same treatment as the sidebar footer divider).
    local sep = UI.CreateLine(segmentHost, false, C.divider, "ends")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -sepGap)
    sep:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -sepGap)

    panelHost:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -sepGap)

    FitSegments()
    ctx:PlaceFrame(segmentHost, segmentHost:GetHeight())
    segmentItem = ctx.items[#ctx.items]
    lastBase = -ctx.y - ctx.gap

    -- Hidden Macro rows change the panel height; refit and resize the tab content.
    UI.Options.AddReflowHook(FitSegments)
  end,
})
