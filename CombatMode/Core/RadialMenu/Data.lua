---------------------------------------------------------------------------------------
--  Core/RadialMenu/Data.lua — RADIALMENU — wheel storage, layout constants, entry info
---------------------------------------------------------------------------------------
--  What it does: Owns the player's wheels (DB.char.radialMenu.wheels), the shared layout
--  constants (CM.RadialLayout) and the helpers that turn a slice entry into a name / icon /
--  secure action. Every mutation ends in CM.RadialRefresh (re-store the secure attributes).
--  Architecture / how it works:
--    • Wheel = { name = "optional title", count = n, slots = { [1..8] = entry } }, slots may have holes; the wheel
--      shows its filled slots only, compacted in order (like a wheel of 3 = three thirds).
--    • Entry = { kind = "spell" | "item" | "macro" | "action", id = number | string }.
--      "action" ids are keys of CM.RadialActions (Actions.lua).
--    • CM.RadialEntrySecure(entry) → type, value, isMacroText: what the slice's
--      SecureActionButton needs (spell name, "item:ID", macro name, or "/click" text).
--    • CM.RadialCompact(wheel) → the filled entries in order (what the secure side stores).
--  Does not: Draw anything, own secure frames or bindings, or build the editor window.
--  Related: Core/RadialMenu/{Actions,Secure,View,RadialMenu}.lua, UI/Options/Tabs/TabRadialMenu.lua, Constants/DatabaseDefaults.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local CreateFrame = _G.CreateFrame
local GetMacroInfo = _G.GetMacroInfo

-- Lua stdlib
local ipairs = _G.ipairs
local math = _G.math
local type = _G.type

-- Shared by Secure.lua and View.lua. The art is 512 x 512 with its crown (the ring the icons
-- sit in) from 75 to 213 from the middle; OVERLAY cuts each section overlay to slice 1 of n:
-- { width, height, x, y } with x, y the centre from the wheel's (y up).
CM.RadialLayout = {
  MAX_WHEELS = 5,
  MAX_SLICES = 8,
  ART = 512,
  FRAME = 2048, -- secure frame: big enough that the cursor is always over it (aim math)
  ICON_RADIUS = 148,
  -- Highlight colour of the aimed slice per wheel (white art, tinted), so wheels read apart at a glance.
  WHEEL_COLORS = {
    { 0.35, 0.65, 1 },
    { 0.45, 0.85, 0.45 },
    { 0.85, 0.5, 1 },
    { 1, 0.62, 0.25 },
    { 1, 0.45, 0.5 },
  },
  NAME_MAX = 10, -- wheel name length, so titles never need an ellipsis
  SLOT = 46,
  DEAD_ZONE = 50,
  OVERLAY = {
    [1] = { 512, 512, 0, 0 },
    [2] = { 512, 256, 0, 110 },
    [3] = { 512, 256, 0, 130 },
    [4] = { 512, 256, 0, 137 },
    [5] = { 256, 256, 0, 140 },
    [6] = { 256, 256, 0, 142 },
    [7] = { 256, 256, 0, 142 },
    [8] = { 256, 256, 0, 143 },
  },
}

local LAYOUT = CM.RadialLayout

local HEARTHSTONE_ITEM_ID = 6948

-- First-run wheels: UI panels, emotes and a misc wheel left nearly empty to show it can grow.
local function PresetWheels()
  -- Entries are action ids (strings) or ready-made { kind, id } slots.
  local function Wheel(name, entries)
    local slots = {}
    for i, entry in ipairs(entries) do
      slots[i] = type(entry) == "table" and entry or { kind = "action", id = entry }
    end
    return { name = name, count = #entries, slots = slots }
  end
  -- Interface: the first eight panels this client has, in this order (Retail gets the full list).
  local panels = {}
  for _, id in ipairs({
    "character",
    "talents",
    "bags",
    "professions",
    "questlog",
    "calendar",
    "groupfinder",
    "gamemenu",
    "spellbook",
    "achievements",
    "social",
    "map",
    "guild",
  }) do
    if CM.RadialActions.IsAvailable(id) and #panels < 8 then
      panels[#panels + 1] = id
    end
  end
  local misc = {}
  for _, id in ipairs({ "readycheck", "roll", "wm6", "wm3", "wm7" }) do
    if CM.RadialActions.IsAvailable(id) then
      misc[#misc + 1] = id
    end
  end
  misc[#misc + 1] = { kind = "item", id = HEARTHSTONE_ITEM_ID }
  return {
    Wheel("Interface", panels),
    Wheel("Emotes", {
      "emote_hello",
      "emote_thank",
      "emote_bye",
      "emote_cheer",
      "emote_sit",
      "emote_dance",
      "emote_cry",
      "emote_ready",
    }),
    Wheel("Misc", misc),
  }
end

local function RadialDb()
  local char = CM.DB and CM.DB.char
  if not char then
    return nil
  end
  if type(char.radialMenu) ~= "table" then
    char.radialMenu = { wheels = {} }
  end
  if type(char.radialMenu.wheels) ~= "table" then
    char.radialMenu.wheels = {}
  end
  -- Seeded once per character, so deleting every wheel later doesn't bring the presets back.
  if not char.radialMenu.presetsSeeded then
    char.radialMenu.presetsSeeded = true
    if #char.radialMenu.wheels == 0 then
      char.radialMenu.wheels = PresetWheels()
    end
  end
  return char.radialMenu
end

function CM.RadialGetWheels()
  local db = RadialDb()
  return db and db.wheels or {}
end

local function Changed()
  if CM.RadialRefresh then
    CM.RadialRefresh()
  end
end

--- New empty wheel (4 slices) appended, or inserted before `atIndex`; returns its index.
function CM.RadialCreateWheel(atIndex)
  local db = RadialDb()
  if not db or #db.wheels >= LAYOUT.MAX_WHEELS then
    return nil
  end
  local index = math.max(1, math.min(atIndex or (#db.wheels + 1), #db.wheels + 1))
  table.insert(db.wheels, index, { name = "Wheel " .. index, count = 4, slots = {} })
  Changed()
  return index
end

--- r, g, b highlight colour of wheel `index`.
function CM.RadialWheelColor(index)
  local color = LAYOUT.WHEEL_COLORS[index] or LAYOUT.WHEEL_COLORS[1]
  return color[1], color[2], color[3]
end

--- Wheel title shown in the editor and in the middle of the open wheel.
function CM.RadialWheelName(wheel, index)
  local name = wheel and wheel.name
  if type(name) == "string" and name ~= "" then
    return name:sub(1, LAYOUT.NAME_MAX)
  end
  return "Wheel " .. (index or 1)
end

--- Blank names fall back to "Wheel <index>".
function CM.RadialRenameWheel(index, name)
  local wheel = CM.RadialGetWheels()[index]
  if not wheel then
    return
  end
  name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
  wheel.name = name ~= "" and name:sub(1, LAYOUT.NAME_MAX) or nil
  Changed()
end

--- Slices the editor shows for a wheel (1..MAX_SLICES); empty ones are left out of the live wheel.
function CM.RadialSliceCount(wheel)
  if not wheel then
    return 0
  end
  local count = wheel.count
  if type(count) ~= "number" then
    count = 0
    for slot = 1, LAYOUT.MAX_SLICES do
      if wheel.slots and wheel.slots[slot] then
        count = slot
      end
    end
  end
  return math.max(1, math.min(LAYOUT.MAX_SLICES, count))
end

function CM.RadialAddSlice(index)
  local wheel = CM.RadialGetWheels()[index]
  local count = CM.RadialSliceCount(wheel)
  if not wheel or count >= LAYOUT.MAX_SLICES then
    return false
  end
  wheel.count = count + 1
  Changed()
  return true
end

--- Removes slice `slot` and shifts the later ones down. A wheel always keeps at least one slice.
function CM.RadialRemoveSlice(index, slot)
  local wheel = CM.RadialGetWheels()[index]
  local count = CM.RadialSliceCount(wheel)
  if not wheel or count <= 1 or slot < 1 or slot > count then
    return false
  end
  wheel.slots = wheel.slots or {}
  for i = slot, count - 1 do
    wheel.slots[i] = wheel.slots[i + 1]
  end
  wheel.slots[count] = nil
  wheel.count = count - 1
  Changed()
  return true
end

--- Entry for whatever the cursor carries (spell, item / toy, macro, mount), or nil.
function CM.RadialEntryFromCursor()
  local kind, a, b, c = _G.GetCursorInfo()
  local function known(id)
    return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
  end
  if kind == "spell" then
    local id = type(c) == "number" and c or (type(b) == "number" and b or nil)
    if id and known(id) then
      return { kind = "spell", id = id }
    end
  elseif kind == "item" then
    if type(a) == "number" then
      return { kind = "item", id = a }
    end
  elseif kind == "macro" then
    local name = type(a) == "number" and GetMacroInfo(a) or nil
    if name then
      return { kind = "macro", id = name }
    end
  elseif kind == "mount" then
    local mounts = _G.C_MountJournal
    local mountId = type(a) == "number" and a or nil
    if mounts and mountId and mounts.GetMountInfoByID then
      local _, spellId = mounts.GetMountInfoByID(mountId)
      if type(spellId) == "number" and known(spellId) then
        return { kind = "spell", id = spellId }
      end
    end
  end
  return nil
end

function CM.RadialDeleteWheel(index)
  local db = RadialDb()
  if not db or not db.wheels[index] then
    return
  end
  table.remove(db.wheels, index)
  Changed()
end

local function ValidEntry(entry)
  if type(entry) ~= "table" then
    return false
  end
  if entry.kind == "spell" or entry.kind == "item" then
    return type(entry.id) == "number"
  end
  if entry.kind == "macro" or entry.kind == "action" then
    return type(entry.id) == "string" and entry.id ~= ""
  end
  return false
end

--- entry = nil empties the slot.
function CM.RadialSetSlot(index, slot, entry)
  local wheel = CM.RadialGetWheels()[index]
  if not wheel or type(slot) ~= "number" or slot < 1 or slot > LAYOUT.MAX_SLICES then
    return
  end
  if entry ~= nil and not ValidEntry(entry) then
    return
  end
  wheel.slots = wheel.slots or {}
  wheel.slots[slot] = entry and { kind = entry.kind, id = entry.id } or nil
  Changed()
end

function CM.RadialMoveSlot(index, from, to)
  local wheel = CM.RadialGetWheels()[index]
  if not wheel or not wheel.slots then
    return
  end
  if from < 1 or to < 1 or from > LAYOUT.MAX_SLICES or to > LAYOUT.MAX_SLICES then
    return
  end
  wheel.slots[from], wheel.slots[to] = wheel.slots[to], wheel.slots[from]
  Changed()
end

--- The wheel's filled slots, in order, no holes.
function CM.RadialCompact(wheel)
  local list = {}
  if wheel and wheel.slots then
    for slot = 1, LAYOUT.MAX_SLICES do
      local entry = wheel.slots[slot]
      if ValidEntry(entry) then
        list[#list + 1] = entry
      end
    end
  end
  return list
end

--- Slice `i` of `n`: clockwise from 12 o'clock; direction x right, y up.
function CM.RadialSlotDir(i, n)
  local a = (i - 1) * 2 * math.pi / n
  return math.sin(a), math.cos(a)
end

function CM.RadialSlotAngle(i, n)
  return (i - 1) * 2 * math.pi / n
end

local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(id)
  end
  return _G.GetSpellInfo and (_G.GetSpellInfo(id))
end

local function SpellIcon(id)
  if C_Spell and C_Spell.GetSpellTexture then
    return (C_Spell.GetSpellTexture(id))
  end
  return _G.GetSpellTexture and (_G.GetSpellTexture(id))
end

--- name, icon (file id / path) for an entry; nil name when unknown.
function CM.RadialEntryInfo(entry)
  if not entry then
    return nil, nil
  end
  if entry.kind == "spell" then
    return SpellName(entry.id) or ("spell:" .. entry.id), SpellIcon(entry.id)
  elseif entry.kind == "item" then
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
    return name or ("item:" .. entry.id), icon
  elseif entry.kind == "macro" then
    local _, icon = GetMacroInfo(entry.id)
    return entry.id, icon
  elseif entry.kind == "action" then
    local action = CM.RadialActions and CM.RadialActions.byId[entry.id]
    if action then
      return action.label, action.icon, action.iconText
    end
    return entry.id, nil
  end
  return nil, nil
end

-- Slot art (radial_slot_{border,disc}.tga): 108px images on 128px canvases. The disc spans 80 of the
-- 108px, so the art is drawn 108/80 larger than the slot to make the disc the slot's size; the border
-- carries its own soft shadow. The icon sits just under the border's body.
local SLOT_ART_PATH = "Interface\\AddOns\\CombatMode\\Assets\\radial\\radial_slot_"
local SLOT_ART_SCALE = 108 / 80
local SLOT_ART_COORD = 108 / 128
local SLOT_ICON_SCALE = 0.92

--- Round slot chrome shared by the wheel and the editor: dark disc behind, border (with shadow) over
--- everything. Sets host.icon (circle-masked) and host.border; returns a frame above the icon /
--- cooldown for the border, labels and counts. `host` must already have its size.
function CM.RadialBuildSlotChrome(host)
  local size = host:GetWidth()
  local art = size * SLOT_ART_SCALE

  local disc = host:CreateTexture(nil, "BACKGROUND", nil, -1)
  disc:SetTexture(SLOT_ART_PATH .. "disc.tga")
  disc:SetTexCoord(0, SLOT_ART_COORD, 0, SLOT_ART_COORD)
  disc:SetSize(art, art)
  disc:SetPoint("CENTER")

  host.icon = host:CreateTexture(nil, "ARTWORK")
  host.icon:SetSize(size * SLOT_ICON_SCALE, size * SLOT_ICON_SCALE)
  host.icon:SetPoint("CENTER")
  host.iconMask = host:CreateMaskTexture()
  host.iconMask:SetAllPoints(host.icon)
  CM.SetAtlasMask(host.iconMask, "CircleMaskScalable")
  host.icon:AddMaskTexture(host.iconMask)

  local over = CreateFrame("Frame", nil, host)
  over:SetAllPoints()
  over:SetFrameLevel(host:GetFrameLevel() + 6)
  host.over = over
  host.border = over:CreateTexture(nil, "ARTWORK")
  host.border:SetTexture(SLOT_ART_PATH .. "border.tga")
  host.border:SetTexCoord(0, SLOT_ART_COORD, 0, SLOT_ART_COORD)
  host.border:SetSize(art, art)
  host.border:SetPoint("CENTER")
  return over
end

--- Paints an entry icon on a texture. The sentinel "portrait" draws the player's 2D portrait, "text" a
--- dark disc with `text` written on `label` (a FontString from CM.RadialCreateIconLabel); anything else
--- is a file path / id.
function CM.RadialCreateIconLabel(parent, size)
  local label = parent:CreateFontString(nil, "OVERLAY")
  CM.ApplyOutlineSlug(label, (_G.GameFontNormalSmall:GetFont()), size)
  label:SetPoint("CENTER")
  label:SetWidth(size * 4.5)
  label:SetMaxLines(1)
  label:SetTextColor(0.95, 0.9, 0.8, 1)
  return label
end

function CM.RadialSetIcon(texture, icon, label, text)
  texture:SetTexCoord(0, 1, 0, 1)
  if label then
    label:SetText(text or "")
  end
  if icon == "text" then
    texture:SetColorTexture(0.1, 0.09, 0.08, 1)
  elseif icon == "portrait" then
    if _G.SetPortraitTexture then
      _G.SetPortraitTexture(texture, "player")
    end
  else
    texture:SetTexture(icon or 134400)
  end
end

--- type, value, isMacroText for the slice's SecureActionButton (nil when it can't be built).
function CM.RadialEntrySecure(entry)
  if not entry then
    return nil
  end
  if entry.kind == "spell" then
    return "spell", SpellName(entry.id) or entry.id, false
  elseif entry.kind == "item" then
    return "item", "item:" .. entry.id, false
  elseif entry.kind == "macro" then
    return "macro", entry.id, false
  elseif entry.kind == "action" then
    local action = CM.RadialActions and CM.RadialActions.byId[entry.id]
    if not action then
      return nil
    end
    local text = CM.RadialActions.MacroText(action)
    if not text then
      return nil
    end
    return "macro", text, true
  end
  return nil
end
