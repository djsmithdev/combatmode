---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabClickCasting.lua — OPTIONS TAB — click-cast slot overrides
---------------------------------------------------------------------------------------
--  What it does: Wires the eight mouse click-cast slots (base + shift/ctrl/alt) with
--  enable, key, action dropdown (OverrideActions + ActionsToProcess), optional macro
--  name, and useGlobalBindings. Applies via SetNewBinding / ResetBindingOverride.
--  Architecture / how it works:
--    • Reads/writes CM.DB[GetBindingsLocation()].bindings[slot].
--    • char.useGlobalBindings toggles whether char or global bindings table is edited.
--    • Modifier segment UI groups slots; Party Radial notes may appear when enabled.
--  Does not: Build targeting prelines or resolve third-party bar frames.
--  Related: Core/ClickCasting/BindingOverrides.lua, Constants/Gameplay.lua,
--  Core/PartyRadial/PartyRadial.lua, UI/Options/Widgets.lua,
--  Constants/DatabaseDefaults.lua, Core/Runtime/Runtime.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame

-- Lua stdlib
local ipairs = _G.ipairs
local pairs = _G.pairs
local floor = _G.math.floor
local max = _G.math.max
local tinsert = _G.table.insert

local UI = CM.UI
local C = UI.Colors

-- Full dropdown value set: the CombatMode override actions (CM.Constants.OverrideActions)
-- first, followed by every standard bindable action (CM.Constants.ActionsToProcess)
-- labeled via Blizzard's BINDING_NAME_* globals. Built lazily so BINDING_NAME_* are ready.
local OVERRIDE_ORDER =
  { "CLEARFOCUS", "CLEARTARGET", "TOGGLEFOCUSANY", "TOGGLEFOCUSENEMY", "MACRO" }
local ACTION_VALUES
local ACTION_ORDER

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
  for _, id in ipairs(OVERRIDE_ORDER) do
    ACTION_VALUES[id] = CM.Constants.OverrideActions[id]
    tinsert(ACTION_ORDER, id)
  end
  for _, id in ipairs(CM.Constants.ActionsToProcess) do
    if not ACTION_VALUES[id] then
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

local function OnBindingChanged()
  if CM.PartyRadial and CM.PartyRadial.OnBindingChanged then
    CM.PartyRadial.OnBindingChanged()
  end
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
      OnBindingChanged()
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
    display = ActionDisplay,
    get = function()
      return Binding(slot).value
    end,
    set = function(value)
      Binding(slot).value = value
      CM.SetNewBinding(Binding(slot))
      OnBindingChanged()
    end,
    disabled = function()
      return not Binding(slot).enabled
    end,
  })
  layout:TextInput({
    label = "Macro Name",
    desc = "Macro to run for this click.",
    get = function()
      return Binding(slot).macroName
    end,
    set = function(value)
      Binding(slot).macroName = value
      CM.SetNewBinding(Binding(slot))
    end,
    validate = function(value)
      if value ~= "" and not CM.MacroExists(value) then
        Binding(slot).macroName = ""
        return "No macro found with that name."
      end
      return true
    end,
    disabled = function()
      return not Binding(slot).enabled or Binding(slot).value ~= "MACRO"
    end,
  })
end

local function BuildGroupPanel(parent, width, modifier)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(width)
  local layout = UI.NewLayout(panel, width)
  layout.y = 0
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
  panel:SetHeight(-layout.y + 8)
  return panel
end

local SEGMENT_FADE = 0.16

local function StyleSegment(button, selected)
  if selected then
    button:cmSetFill(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
    button:cmSetBorder(0, 0, 0, 0)
    button.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  else
    button:cmSetFill(0, 0, 0, 0)
    button:cmSetBorder(0, 0, 0, 0)
    button.label:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  end
end

local function BuildSegmentBar(parent, width, groups, onSelect)
  local barH = 28
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
      StyleSegment(button, button.groupId == id)
    end
    onSelect(id)
  end

  for _, group in ipairs(groups) do
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(btnW, barH)
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
    UI.StyleRounded(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)
    button.groupId = group.id

    local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(group.label)
    button.label = label

    button:SetScript("OnClick", function()
      Select(group.id)
    end)
    button:SetScript("OnEnter", function(self)
      if self.groupId ~= selectedId then
        self:cmSetFill(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
      end
    end)
    button:SetScript("OnLeave", function(self)
      StyleSegment(self, self.groupId == selectedId)
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
    local hostH = 0
    for _, group in ipairs(MODIFIER_GROUPS) do
      local panel = BuildGroupPanel(panelHost, contentW, group.modifier)
      panel:SetPoint("TOPLEFT", panelHost, "TOPLEFT", 0, 0)
      panel:Hide()
      panel:SetAlpha(1)
      panels[group.id] = panel
      hostH = max(hostH, panel:GetHeight() or 0)
    end
    panelHost:SetSize(contentW, hostH)

    local activeGroupId
    local fadeGen = 0

    local function ShowGroup(id)
      if activeGroupId == id then
        local panel = panels[id]
        if panel and panel:IsShown() and panel:GetAlpha() >= 0.99 then
          return
        end
      end

      fadeGen = fadeGen + 1
      local gen = fadeGen
      local previousId = activeGroupId
      local previous = previousId and panels[previousId]
      local incoming = panels[id]
      activeGroupId = id

      for groupId, panel in pairs(panels) do
        if groupId ~= id and groupId ~= previousId then
          panel:SetScript("OnUpdate", nil)
          panel:Hide()
          panel:SetAlpha(1)
        end
      end

      if not incoming then
        return
      end

      local function FinishOutgoing(panel)
        if not panel or panel == incoming then
          return
        end
        panel:SetScript("OnUpdate", nil)
        panel:Hide()
        panel:SetAlpha(1)
      end

      incoming:SetScript("OnUpdate", nil)
      incoming:SetAlpha(0)
      incoming:Show()

      if previous and previous ~= incoming and previous:IsShown() then
        UI.FadeAlpha(previous, 0, SEGMENT_FADE, function()
          if gen ~= fadeGen then
            return
          end
          FinishOutgoing(previous)
        end)
      else
        FinishOutgoing(previous)
      end

      UI.FadeAlpha(incoming, 1, SEGMENT_FADE)
    end

    local bar = BuildSegmentBar(segmentHost, contentW, MODIFIER_GROUPS, ShowGroup)
    bar:SetPoint("TOPLEFT", segmentHost, "TOPLEFT", 0, 0)

    -- Hairline under the segment bar so the modifier tabs read separately from the
    -- Left/Right click options below (same treatment as the sidebar footer divider).
    local sepGap = 8
    local sep = segmentHost:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.06)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -sepGap)
    sep:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -sepGap)

    panelHost:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -sepGap)

    segmentHost:SetHeight(bar:GetHeight() + sepGap + 1 + sepGap + hostH)
    ctx:PlaceFrame(segmentHost, segmentHost:GetHeight())
  end,
})
