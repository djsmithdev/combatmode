---------------------------------------------------------------------------------------
--  UI/Options/FrameMultiSelect.lua — OPTIONS — frame name pill multi-select
---------------------------------------------------------------------------------------
--  What it does: UI.MakeFrameMultiSelect — pill chips of frame names (Blizzard and addon
--  windows) that can be typed with suggestions or picked straight from the screen with the
--  inspect button. Used for the Auto Unlock "Extra Frames" list; stored as a comma-separated
--  list of frame names. Thin wrapper around
--  UI.MakePillMultiSelect in Widgets.lua (token-keyed chips instead of spell IDs).
--  Architecture / how it works:
--    • Index: one EnumerateFrames() sweep, built on first use and rebuilt whenever the field is
--      focused again after a while (addons load frames lazily). Only named top-level frames are
--      kept (parented to UIParent): those are the windows; nested buttons would be noise.
--    • Blizzard vs addon: issecurevariable(_G, name) is true for Blizzard globals. Each suggestion
--      shows "Blizzard" / "Addon" (plus "open" when the frame is visible right now) at its right.
--    • Icons: a Blizzard frame gets the WoW logo; an addon's frame gets that addon's icon from the
--      AddOns list (IconAtlas / IconTexture metadata). The owning addon comes from the taint
--      issecurevariable(_G, name) reports for the frame's global. Shown on chips, suggestion rows
--      and the picker popup; frames that do not exist (yet) have no icon.
--    • Frames Combat Mode already watches are left out of the suggestions.
--    • Picker (inspect button): polls GetMouseFoci every frame, dims the screen around the
--      window under the cursor (its top-most named ancestor below UIParent, same dim + outline
--      as the setup wizard's tour: UI.CreateDimHole) and shows its name in a banner. Left
--      click adds it, right click / Esc cancels. Same approach as WeakAuras' frame chooser: it
--      watches the mouse buttons rather than covering the screen, so the clicked frame also
--      receives the click.

--  Does not: Evaluate visibility for the unlock itself (Core/FreeLook/AutoCursorUnlock.lua).
--  Related: UI/Options/Widgets.lua (UI.MakePillMultiSelect), UI/Options/MountMultiSelect.lua,
--  Constants/FrameWatch.lua, UI/Options/Tabs/TabAutoCursorUnlock.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local EnumerateFrames = _G.EnumerateFrames
local CreateFrame = _G.CreateFrame
local C_AddOns = _G.C_AddOns
local GetMouseFoci = _G.GetMouseFoci
local GetTime = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsMouseButtonDown = _G.IsMouseButtonDown
local issecurevariable = _G.issecurevariable
local pcall = _G.pcall
local ResetCursor = _G.ResetCursor
local SetCursor = _G.SetCursor
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local tonumber = _G.tonumber
local max = _G.math.max
local min = _G.math.min
local sort = _G.table.sort
local strfind = _G.string.find
local strlower = _G.string.lower
local strsub = _G.string.sub
local strtrim = _G.strtrim

local UI = CM.UI

local MAX_MATCHES = 50
local REBUILD_AFTER_S = 5 -- re-sweep when the field is used again after this long

local frameList = {} -- { name, nameLower, blizzard }
local builtAt

local function Safe(fn, ...)
  local ok, a, b = pcall(fn, ...)
  if ok then
    return a, b
  end
end

local function IsOwnFrame(name)
  return strsub(name, 1, 10) == "CombatMode"
end

local BLIZZARD_ICON_ATLAS = "friends-icon-addFriend-logo-WoW"
local FALLBACK_ADDON_ICON = CM.Constants.UnknownAddonIcon -- addon without an icon
local iconCache = {} -- frame name -> { atlas = } / { icon = } (false: no icon)

--- The icon of the addon `addon` as the AddOns list shows it, or nil.
local function AddonIcon(addon)
  local metadata = C_AddOns and C_AddOns.GetAddOnMetadata
  if not (metadata and type(addon) == "string") then
    return nil
  end
  local atlas = Safe(metadata, addon, "IconAtlas")
  if type(atlas) == "string" and atlas ~= "" then
    return { atlas = atlas }
  end
  local texture = Safe(metadata, addon, "IconTexture")
  if type(texture) == "string" and texture ~= "" then
    return { icon = tonumber(texture) or texture }
  end
  return nil
end

--- Icons remembered across sessions (global.frameIcons): a chip's frame often does not exist yet
--- after a reload (it is created when its window is first opened), so its icon is saved while the
--- frame is known and read back when it is not.
local function SavedIcons()
  local global = CM.DB and CM.DB.global
  if not global then
    return nil
  end
  global.frameIcons = global.frameIcons or {}
  return global.frameIcons
end

local addonNames -- folder names of every installed addon, longest first

--- Best guess for a frame that does not exist yet: the addon whose folder name starts the frame's
--- name ("WeakAurasOptions" -> WeakAuras).
local function GuessAddonIcon(name)
  local info = C_AddOns and C_AddOns.GetAddOnInfo
  local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()
  if not (info and count) then
    return nil
  end
  if not addonNames then
    addonNames = {}
    for i = 1, count do
      local addon = Safe(info, i)
      if type(addon) == "string" and #addon >= 4 then
        addonNames[#addonNames + 1] = addon
      end
    end
    sort(addonNames, function(a, b)
      return #a > #b
    end)
  end
  local lower = strlower(name)
  for _, addon in ipairs(addonNames) do
    if strsub(lower, 1, #addon) == strlower(addon) then
      return AddonIcon(addon) or { icon = FALLBACK_ADDON_ICON }
    end
  end
  return nil
end

--- { atlas } / { icon } for the frame named `name`. Blizzard globals are "secure"; for an addon's,
--- issecurevariable's second result names the addon. `remember` (chips) saves a live result and,
--- while the frame does not exist, falls back to the saved icon, then to a guess from the name.
local function IconFor(name, remember)
  local icon = iconCache[name]
  if not icon and _G[name] ~= nil then
    local secure, taint = issecurevariable(_G, name)
    if secure then
      icon = { atlas = BLIZZARD_ICON_ATLAS }
    else
      icon = AddonIcon(taint) or { icon = FALLBACK_ADDON_ICON }
    end
    iconCache[name] = icon
  end
  local saved = remember and SavedIcons()
  if icon then
    if saved and saved[name] == nil then
      saved[name] = icon
    end
    return icon
  end
  if saved and saved[name] then
    return saved[name]
  end
  if remember then
    return GuessAddonIcon(name)
  end
  return nil
end

local function RebuildIndex()
  frameList = {}
  local seen = {}
  local frame = EnumerateFrames()
  while frame do
    local name = frame.GetName and Safe(frame.GetName, frame)
    if
      type(name) == "string"
      and name ~= ""
      and not seen[name]
      and not IsOwnFrame(name)
      and Safe(frame.GetParent, frame) == UIParent
    then
      seen[name] = true
      frameList[#frameList + 1] = {
        name = name,
        nameLower = strlower(name),
        blizzard = issecurevariable and issecurevariable(_G, name) or false,
      }
    end
    frame = EnumerateFrames(frame)
  end
  sort(frameList, function(a, b)
    return a.nameLower < b.nameLower
  end)
  builtAt = GetTime()
end

local function EnsureIndex()
  if not builtAt or GetTime() - builtAt > REBUILD_AFTER_S then
    RebuildIndex()
  end
end

-- Names Combat Mode already watches on its own (never worth suggesting).
local function WatchedByDefault()
  local set = {}
  for _, name in ipairs(CM.Constants.FramesToCheck or {}) do
    set[strlower(name)] = true
  end
  return set
end

local function IsOpen(name)
  local frame = _G[name]
  return frame and Safe(frame.IsVisible, frame) == true or false
end

local function ToEntry(info, open)
  local kind = info.blizzard and "Blizzard" or "Addon"
  local icon = IconFor(info.name)
  return {
    token = info.name,
    name = info.name,
    icon = icon and icon.icon,
    atlas = icon and icon.atlas,
    detail = open and (kind .. " \194\183 " .. UI.Colors.successMarkup .. "open|r") or kind,
  }
end

local function ResolveFrameToken(token)
  token = strtrim(token or "")
  if token == "" then
    return nil
  end
  local icon = IconFor(token, true)
  return { token = token, name = token, icon = icon and icon.icon, atlas = icon and icon.atlas }
end

local function FilterSuggestions(query, _, selectedNames)
  query = strlower(strtrim(query or ""))
  local out = {}
  -- Nothing typed: no suggestions, and no frame sweep either.
  if query == "" then
    return out
  end

  EnsureIndex()
  local watched = WatchedByDefault()

  -- Names that start with the query first, then the ones that merely contain it.
  local contains = {}
  for _, info in ipairs(frameList) do
    if not selectedNames[info.nameLower] and not watched[info.nameLower] then
      local at = strfind(info.nameLower, query, 1, true)
      if at == 1 then
        out[#out + 1] = ToEntry(info, IsOpen(info.name))
      elseif at then
        contains[#contains + 1] = info
      end
    end
  end
  for _, info in ipairs(contains) do
    if #out >= MAX_MATCHES then
      break
    end
    out[#out + 1] = ToEntry(info, IsOpen(info.name))
  end
  while #out > MAX_MATCHES do
    out[#out] = nil
  end
  return out
end

---------------------------------------------------------------------------------------
--                                  FRAME PICKER                                     --
---------------------------------------------------------------------------------------
local picker -- { frame, hole, banner, label }
local PICKER_PAD = 3 -- gap between the hovered window and the dim
local PICKER_LEVEL = 8000
local BANNER_W = 340
local BANNER_PAD = 14
local BANNER_ICON = 20
local INSPECT_ICON = { atlas = "decor-controls-inspect-default" } -- shown while nothing is hovered
local BANNER_IDLE_TITLE = "Pick a frame"
local pickerOnPick
local pickerName
local pickerIconFor -- frame name whose icon the popup currently shows
local pickerArmed -- becomes true once the left button has been seen up (ignores the opening click)

--- The window under `region`: its top-most global-named ancestor below UIParent, plus that name.
--- Nil over the game world, or over any Combat Mode frame.
local function WindowAt(region)
  local best, bestName
  local node = region
  while node and node ~= UIParent do
    local name = node.GetName and Safe(node.GetName, node)
    if type(name) == "string" and name ~= "" and _G[name] == node then
      if name == "WorldFrame" or IsOwnFrame(name) then
        return nil
      end
      best, bestName = node, name
    end
    node = node.GetParent and Safe(node.GetParent, node) or nil
  end
  return best, bestName
end

local function StopPicker()
  if not picker then
    return
  end
  picker.frame:Hide()
  picker.hole.SetShown(false)
  picker.banner:Hide()
  pickerOnPick, pickerName = nil, nil
  ResetCursor()
end

local function BuildPicker()
  local C = UI.Colors
  local frame = CreateFrame("Frame", "CombatModeFramePicker", UIParent)
  frame:SetAllPoints(UIParent)
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(PICKER_LEVEL)
  frame:EnableMouse(false)
  frame:Hide()
  -- Same dim + outline as the setup wizard's tour: everything but the hovered window is dimmed.
  local hole = UI.CreateDimHole(frame, PICKER_LEVEL)

  -- Same popup look as the setup wizard's balloon: window chrome, cream title over a fading rule.
  local banner = CreateFrame("Frame", nil, UIParent)
  banner:SetFrameStrata("TOOLTIP")
  banner:SetFrameLevel(110)
  banner:SetWidth(BANNER_W)
  banner:SetPoint("TOP", UIParent, "TOP", 0, -90)
  banner:EnableMouse(false)
  UI.StyleWindow(banner)
  banner:Hide()
  local label = UI.CreateFontString(banner, "OVERLAY", UI.Fonts.header, "GameFontNormalLarge")
  -- OVERLAY, above the window chrome (an ARTWORK texture can end up under its decoration).
  local bannerIcon = banner:CreateTexture(nil, "OVERLAY", nil, 7)
  bannerIcon:SetSize(BANNER_ICON, BANNER_ICON)
  -- Icon and title share one vertical centre line (the middle of the 22px title row).
  bannerIcon:SetPoint("LEFT", banner, "TOPLEFT", BANNER_PAD, -(BANNER_PAD + 11))
  label:SetPoint("LEFT", bannerIcon, "RIGHT", 6, 0)
  label:SetWidth(BANNER_W - 2 * BANNER_PAD - BANNER_ICON - 6)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)
  label:SetTextColor(C.text[1], C.text[2], C.text[3])
  local rule = UI.CreateLine(banner, false, C.headerRule, "fade")
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", banner, "TOPLEFT", BANNER_PAD, -(BANNER_PAD + 22 + 6))
  rule:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -BANNER_PAD, 0)
  local hint = UI.CreateFontString(banner, "OVERLAY", UI.Fonts.base, "GameFontHighlight")
  hint:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -10)
  hint:SetWidth(BANNER_W - 2 * BANNER_PAD)
  hint:SetJustifyH("LEFT")
  hint:SetWordWrap(true)
  hint:SetText("Click a frame to add it to the list. Right-click or press Esc to cancel.")
  hint:SetTextColor(C.text[1], C.text[2], C.text[3])
  -- Title row + rule + hint, plus padding.
  banner:SetHeight(BANNER_PAD + 22 + 6 + 1 + 10 + hint:GetStringHeight() + BANNER_PAD)
  label:SetText(BANNER_IDLE_TITLE)

  --- Shows `icon` ({ atlas } or { icon }) in the title row; `key` says what it stands for so it is
  --- only reapplied when that changes.
  local function SetBannerIcon(key, icon)
    if pickerIconFor == key then
      return
    end
    pickerIconFor = key
    if icon.atlas then
      CM.SetAtlas(bannerIcon, icon.atlas)
    else
      bannerIcon:SetTexture(icon.icon)
      bannerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
  end
  SetBannerIcon(BANNER_IDLE_TITLE, INSPECT_ICON)

  frame:SetScript("OnUpdate", function()
    if IsMouseButtonDown("RightButton") then
      StopPicker()
      return
    end
    local leftDown = IsMouseButtonDown("LeftButton")
    if not leftDown then
      pickerArmed = true
    elseif pickerArmed and pickerName then
      local name, onPick = pickerName, pickerOnPick
      StopPicker()
      if onPick then
        onPick(name)
      end
      return
    end

    SetCursor("CAST_CURSOR")
    local foci = GetMouseFoci and GetMouseFoci()
    local target, name
    if foci and foci[1] then
      target, name = WindowAt(foci[1])
    end
    local l, r, t, b
    if target then
      l, r, t, b = target:GetLeft(), target:GetRight(), target:GetTop(), target:GetBottom()
    end
    if target and l and r and t and b then
      local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
      hole.Layout(
        max(l * scale - PICKER_PAD, 0),
        min(r * scale + PICKER_PAD, UIParent:GetWidth()),
        min(t * scale + PICKER_PAD, UIParent:GetHeight()),
        max(b * scale - PICKER_PAD, 0)
      )
      label:SetText(name)
      label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
      SetBannerIcon(name, IconFor(name) or INSPECT_ICON)
      pickerName = name
    else
      hole.Layout() -- nothing under the cursor: dim the whole screen
      label:SetText(BANNER_IDLE_TITLE)
      label:SetTextColor(C.text[1], C.text[2], C.text[3])
      SetBannerIcon(BANNER_IDLE_TITLE, INSPECT_ICON)
      pickerName = nil
    end
  end)
  -- Esc cancels; every other key still reaches the game so windows can be opened by keybind.
  frame:SetScript("OnKeyDown", function(self, key)
    if InCombatLockdown() then
      return
    end
    if key == "ESCAPE" then
      self:SetPropagateKeyboardInput(false)
      StopPicker()
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
  frame:SetScript("OnShow", function(self)
    self:EnableKeyboard(true)
    if not InCombatLockdown() then
      self:SetPropagateKeyboardInput(true)
    end
  end)
  frame:SetScript("OnHide", function(self)
    self:EnableKeyboard(false)
  end)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:SetScript("OnEvent", StopPicker)

  picker = { frame = frame, hole = hole, banner = banner, label = label }
end

--- Lets the player click a window on screen; `onPick(frameName)` gets its global name.
local function StartPicker(onPick)
  if InCombatLockdown() then
    return
  end
  if not picker then
    BuildPicker()
  end
  pickerOnPick = onPick
  pickerName = nil
  pickerArmed = false
  picker.banner:Show()
  picker.frame:Show()
end

---------------------------------------------------------------------------------------
--                              MAKE FRAME MULTI-SELECT                              --
---------------------------------------------------------------------------------------
function UI.MakeFrameMultiSelect(parent, opts)
  return UI.MakePillMultiSelect(parent, opts, {
    byToken = true,
    resolveToken = ResolveFrameToken,
    filterSuggestions = FilterSuggestions,
    placeholder = "Type a frame name…",
    pickFrame = StartPicker,
  })
end
