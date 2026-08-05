---------------------------------------------------------------------------------------
--  UI/Options/SpellMultiSelect.lua — OPTIONS — spell ID pill multi-select
---------------------------------------------------------------------------------------
--  What it does: UI.MakeSpellMultiSelect — type-ahead suggestions from the spellbook,
--  pill chips for selected spells, storage as CSV spell IDs for Reticle Targeting exclude
--  and cast-at-crosshair lists.
--  Architecture / how it works:
--    • Suggestion popup capped (MAX_MATCHES / visible rows); migrates legacy name tokens
--      when resolving.
--    • Runtime membership tests live in TargetingMacroBuilder, not here.
--  Does not: Build click-cast macros or write CVars.
--  Related: UI/Options/Widgets.lua, UI/Options/Tabs/TabReticleTargeting.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local C_Timer = _G.C_Timer
local Enum = _G.Enum
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local max = _G.math.max
local min = _G.math.min
local strfind = _G.string.find
local strlower = _G.string.lower
local strtrim = _G.strtrim
local tconcat = _G.table.concat
local tremove = _G.table.remove
local tonumber = _G.tonumber
local tostring = _G.tostring
local wipe = _G.wipe

local UI = CM.UI
local C = UI.Colors
local Options = UI.Options

local BOX_H = 76
local PILL_H = 20
local PILL_GAP = 4
local PILL_PAD_X = 5
local ICON_SIZE = 14
local BOX_PAD = 6
local MAX_MATCHES = 50 -- how many suggestions to collect
local MAX_VISIBLE_ROWS = 8 -- popup viewport height before scrolling
local SUGGEST_ITEM_H = 22
local MENU_PAD = 4
local BAR_GUTTER = 10
local DEBOUNCE_S = 0.06

---------------------------------------------------------------------------------------
--                              SPELLBOOK INDEX                                      --
---------------------------------------------------------------------------------------
local spellList = {} -- { spellId, name, nameLower, icon }
local spellById = {}
local spellByName = {}
local indexDirty = true
local indexFrame

local function AddSpellToIndex(spellId, name, icon)
  if not spellId or spellId <= 0 or not name or name == "" then
    return
  end
  if spellById[spellId] then
    return
  end
  local entry = {
    spellId = spellId,
    name = name,
    nameLower = strlower(name),
    icon = icon,
  }
  spellList[#spellList + 1] = entry
  spellById[spellId] = entry
  if not spellByName[entry.nameLower] then
    spellByName[entry.nameLower] = entry
  end
end

local function IsPassiveSpell(spellId, slot, bank)
  if slot and bank and C_SpellBook.IsSpellBookItemPassive then
    if C_SpellBook.IsSpellBookItemPassive(slot, bank) then
      return true
    end
  end
  if spellId and C_Spell and C_Spell.IsSpellPassive then
    return C_Spell.IsSpellPassive(spellId) and true or false
  end
  return false
end

local function RebuildSpellIndex()
  wipe(spellList)
  wipe(spellById)
  wipe(spellByName)
  if not (C_SpellBook and Enum and Enum.SpellBookSpellBank) then
    indexDirty = false
    return
  end

  local playerBank = Enum.SpellBookSpellBank.Player
  local petBank = Enum.SpellBookSpellBank.Pet
  local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell

  local numLines = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()
    or 0
  for i = 1, numLines do
    local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
    if line and not line.offSpecID and line.numSpellBookItems and line.itemIndexOffset then
      for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local info = C_SpellBook.GetSpellBookItemInfo(slot, playerBank)
        if info and (not spellType or info.itemType == spellType) then
          local spellId = info.spellID or info.actionID
          if not IsPassiveSpell(spellId, slot, playerBank) then
            local name = info.name
            local icon = info.iconID
            if (not name or name == "") and spellId and C_Spell and C_Spell.GetSpellInfo then
              local si = C_Spell.GetSpellInfo(spellId)
              if si then
                name = si.name
                icon = icon or si.iconID
              end
            end
            AddSpellToIndex(spellId, name, icon)
          end
        end
      end
    end
  end

  local numPet = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells()
  if numPet and numPet > 0 then
    for slot = 1, numPet do
      local info = C_SpellBook.GetSpellBookItemInfo(slot, petBank)
      if info then
        local spellId = info.spellID or info.actionID
        if not IsPassiveSpell(spellId, slot, petBank) then
          local name = info.name
          local icon = info.iconID
          if (not name or name == "") and spellId and C_Spell and C_Spell.GetSpellInfo then
            local si = C_Spell.GetSpellInfo(spellId)
            if si then
              name = si.name
              icon = icon or si.iconID
            end
          end
          AddSpellToIndex(spellId, name, icon)
        end
      end
    end
  end

  indexDirty = false
end

local function EnsureSpellIndex()
  if indexDirty then
    RebuildSpellIndex()
  end
  if not indexFrame then
    indexFrame = CreateFrame("Frame")
    indexFrame:RegisterEvent("SPELLS_CHANGED")
    indexFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    indexFrame:SetScript("OnEvent", function()
      indexDirty = true
    end)
  end
end

local function ResolveSpellToken(token)
  token = strtrim(token or "")
  if token == "" then
    return nil
  end
  EnsureSpellIndex()

  local idText = token:gsub("^#", "")
  local id = tonumber(idText)
  if id and id > 0 then
    local fromBook = spellById[id]
    if fromBook then
      return {
        token = tostring(id),
        spellId = fromBook.spellId,
        name = fromBook.name,
        icon = fromBook.icon,
      }
    end
    if C_Spell and C_Spell.GetSpellInfo then
      local si = C_Spell.GetSpellInfo(id)
      if si and si.name then
        return {
          token = tostring(id),
          spellId = id,
          name = si.name,
          icon = si.iconID,
        }
      end
    end
    -- Keep unknown IDs so whitelist/blacklist by id still works.
    return { token = tostring(id), spellId = id, name = tostring(id), icon = nil }
  end

  local fromBook = spellByName[strlower(token)]
  if fromBook then
    return {
      token = tostring(fromBook.spellId),
      spellId = fromBook.spellId,
      name = fromBook.name,
      icon = fromBook.icon,
    }
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local si = C_Spell.GetSpellInfo(token)
    local spellId = si and (si.spellID or si.spellId)
    if si and si.name and spellId then
      return {
        token = tostring(spellId),
        spellId = spellId,
        name = si.name,
        icon = si.iconID,
      }
    end
  end
  -- Unresolved legacy name: show as text-only until the user removes it.
  return { token = token, spellId = nil, name = token, icon = nil }
end

local function ParseCsvToEntries(csv)
  local entries = {}
  if not csv or csv == "" then
    return entries
  end
  for part in tostring(csv):gmatch("[^,]+") do
    local entry = ResolveSpellToken(part)
    if entry then
      entries[#entries + 1] = entry
    end
  end
  return entries
end

local function EntriesToCsv(entries)
  local parts = {}
  local seen = {}
  for _, e in ipairs(entries) do
    if e.spellId and e.spellId > 0 and not seen[e.spellId] then
      seen[e.spellId] = true
      parts[#parts + 1] = tostring(e.spellId)
    end
  end
  return tconcat(parts, ", ")
end

local function FilterSuggestions(query, selectedIds, selectedNames)
  EnsureSpellIndex()
  query = strtrim(query or "")
  local out = {}
  if query == "" then
    return out
  end

  local idText = query:gsub("^#", "")
  local asId = tonumber(idText)
  if asId and asId > 0 and not IsPassiveSpell(asId) then
    local entry = ResolveSpellToken(tostring(asId))
    if
      entry
      and entry.spellId
      and not selectedIds[entry.spellId]
      and not IsPassiveSpell(entry.spellId)
    then
      out[#out + 1] = entry
    end
  end

  local q = strlower(query)
  for _, sp in ipairs(spellList) do
    if #out >= MAX_MATCHES then
      break
    end
    if not selectedIds[sp.spellId] and not selectedNames[sp.nameLower] then
      if strfind(sp.nameLower, q, 1, true) then
        -- Skip if already added via ID resolve
        local dup = false
        for _, existing in ipairs(out) do
          if existing.spellId == sp.spellId then
            dup = true
            break
          end
        end
        if not dup then
          out[#out + 1] = {
            token = tostring(sp.spellId),
            spellId = sp.spellId,
            name = sp.name,
            icon = sp.icon,
          }
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------
--                              MAKE SPELL MULTI-SELECT                              --
---------------------------------------------------------------------------------------
function UI.MakeSpellMultiSelect(parent, opts)
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
  box:SetHeight(BOX_H)
  UI.StyleRounded(box, C.inputBg, C.cardBorder, UI.Radius.control)
  box:EnableMouse(true)
  box:SetClipsChildren(true)

  local control = {
    frame = row,
    height = BOX_H + 8,
    widget = box,
    widgetH = BOX_H,
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

  local edit = CreateFrame("EditBox", nil, box)
  edit:SetAutoFocus(false)
  edit:SetHeight(PILL_H)
  UI.SetEditBoxFont(edit)
  edit:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  edit:SetTextInsets(2, 2, 0, 0)
  if edit.SetPlaceholderText then
    edit:SetPlaceholderText(opts.placeholder or "Type spell name or ID…")
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
    local boxW = box:GetWidth()
    if boxW < 40 then
      boxW = 200
    end
    local maxW = boxW - BOX_PAD * 2
    local x, y = BOX_PAD, BOX_PAD

    for i, pill in ipairs(pillFrames) do
      if i > #entries then
        pill:Hide()
      else
        local e = entries[i]
        local name = e.name or e.token or ""
        pill.text:SetText(name)
        if e.icon then
          pill.icon:SetTexture(e.icon)
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
        if e.icon then
          w = w + ICON_SIZE + 3
        end
        w = min(w, maxW)
        pill:SetSize(w, PILL_H)
        if x + w > maxW + 0.5 and x > BOX_PAD then
          x = BOX_PAD
          y = y + PILL_H + PILL_GAP
        end
        pill:ClearAllPoints()
        pill:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
        pill:Show()
        x = x + w + PILL_GAP
      end
    end

    local editMin = 60
    if x + editMin > maxW + 0.5 and x > BOX_PAD then
      x = BOX_PAD
      y = y + PILL_H + PILL_GAP
    end
    edit:ClearAllPoints()
    edit:SetPoint("TOPLEFT", box, "TOPLEFT", x, -y)
    edit:SetPoint("RIGHT", box, "RIGHT", -BOX_PAD, 0)
    edit:SetHeight(PILL_H)
  end

  local function EnsurePill(i)
    local pill = pillFrames[i]
    if pill then
      return pill
    end
    pill = CreateFrame("Frame", nil, box)
    UI.StyleRounded(pill, C.trackOff, C.cardBorder, UI.Radius.control)
    pill:SetHeight(PILL_H)

    local icon = pill:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", pill, "LEFT", PILL_PAD_X, 0)
    pill.icon = icon

    local text = UI.CreateFontString(pill, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    text:SetJustifyH("LEFT")
    text:SetTextColor(C.text[1], C.text[2], C.text[3])
    pill.text = text

    local remove = CreateFrame("Button", nil, pill)
    remove:SetSize(12, 12)
    remove:SetPoint("RIGHT", pill, "RIGHT", -3, 0)
    local rx = UI.CreateFontString(remove, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
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
    if not entry or not entry.spellId or entry.spellId <= 0 or IsAlreadySelected(entry) then
      return false
    end
    entries[#entries + 1] = {
      token = tostring(entry.spellId),
      spellId = entry.spellId,
      name = entry.name or tostring(entry.spellId),
      icon = entry.icon,
    }
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
    UI.StyleRounded(suggestMenu, C.windowBg, C.windowBorder, UI.Radius.window)
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
    scroll:SetPoint("TOPLEFT", suggestMenu, "TOPLEFT", MENU_PAD, -MENU_PAD)
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
    local needsBar = shown > MAX_VISIBLE_ROWS
    local visible = needsBar and MAX_VISIBLE_ROWS or shown
    local gutter = needsBar and BAR_GUTTER or 0
    local scrollW = width - MENU_PAD * 2 - gutter
    local listH = visible * SUGGEST_ITEM_H

    suggestMenu.content:SetWidth(scrollW)
    suggestMenu.scroll:SetWidth(scrollW)
    suggestMenu.scroll:SetHeight(listH)
    suggestMenu.bar:ClearAllPoints()
    suggestMenu.bar:SetPoint("TOP", suggestMenu.scroll, "TOP", 0, 0)
    suggestMenu.bar:SetPoint("BOTTOM", suggestMenu.scroll, "BOTTOM", 0, 0)
    suggestMenu.bar:SetPoint("LEFT", suggestMenu.scroll, "RIGHT", 2, 0)

    for i = 1, shown do
      local item = suggestItems[i]
      if not item then
        item = CreateFrame("Button", nil, suggestMenu.content)
        item:SetHeight(SUGGEST_ITEM_H)
        local hl = item:CreateTexture(nil, "BACKGROUND")
        hl:SetAllPoints(item)
        hl:SetColorTexture(1, 1, 1, 0.09)
        hl:Hide()
        item.hl = hl
        item.icon = item:CreateTexture(nil, "ARTWORK")
        item.icon:SetSize(ICON_SIZE, ICON_SIZE)
        item.icon:SetPoint("LEFT", item, "LEFT", 6, 0)
        item.text = UI.CreateFontString(item, "OVERLAY", UI.Fonts.base, "GameFontHighlightSmall")
        item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
        item.text:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        item.text:SetJustifyH("LEFT")
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
      if m.icon then
        item.icon:SetTexture(m.icon)
        item.icon:Show()
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", item.icon, "RIGHT", 6, 0)
        item.text:SetPoint("RIGHT", item, "RIGHT", -6, 0)
      else
        item.icon:Hide()
        item.text:ClearAllPoints()
        item.text:SetPoint("LEFT", item, "LEFT", 8, 0)
        item.text:SetPoint("RIGHT", item, "RIGHT", -6, 0)
      end
      item:ClearAllPoints()
      item:SetPoint("TOPLEFT", suggestMenu.content, "TOPLEFT", 0, -(i - 1) * SUGGEST_ITEM_H)
      item:SetPoint("TOPRIGHT", suggestMenu.content, "TOPRIGHT", 0, -(i - 1) * SUGGEST_ITEM_H)
      item:Show()
    end
    for i = shown + 1, #suggestItems do
      suggestItems[i]:Hide()
    end

    suggestMenu.content:SetHeight(max(shown * SUGGEST_ITEM_H, 1))
    suggestMenu.scroll:SetVerticalScroll(0)
    if suggestMenu.scroll.cmUpdate then
      suggestMenu.scroll.cmUpdate()
    end

    suggestMenu:SetHeight(MENU_PAD * 2 + listH)
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
    local matches = FilterSuggestions(edit:GetText(), ids, names)
    OpenSuggest(matches)
  end

  local function ScheduleSuggest()
    debounceToken = debounceToken + 1
    local token = debounceToken
    if C_Timer and C_Timer.After then
      C_Timer.After(DEBOUNCE_S, function()
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
        -- Clicking away dismisses suggestions only — never auto-add a partial match.
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
    local matches = FilterSuggestions(self:GetText(), ids, names)
    if matches[1] then
      PickSuggestion(matches[1])
    else
      local leftover = strtrim(self:GetText() or "")
      if leftover ~= "" then
        local entry = ResolveSpellToken(leftover)
        if entry and entry.spellId then
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
    if row.label then
      row.label:SetAlpha(disabled and (C.disabledAlpha or 0.5) or 1)
    end
    if disabled then
      CloseSuggest()
    end
  end

  -- After width is known, reflow pills inside the box.
  local prevSetWidthTo
  Options.AttachOptionText(control, row, opts, BOX_H)
  prevSetWidthTo = control.SetWidthTo
  function control.SetWidthTo(width)
    local h = prevSetWidthTo and prevSetWidthTo(width) or control.height
    LayoutPills()
    return h
  end

  Options.AddRowHover(row, opts, box, edit)
  control._reflowPills()
  return Options.RegisterControl(control)
end
