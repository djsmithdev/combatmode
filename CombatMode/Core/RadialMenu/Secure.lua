---------------------------------------------------------------------------------------
--  Core/RadialMenu/Secure.lua — RADIALMENU — secure wheel: open, aim, use, cycle (combat safe)
---------------------------------------------------------------------------------------
--  What it does: Holds every protected piece of the Radial Menu: the wheel frame (a
--  SecureHandlerBaseTemplate), 8 slice buttons (SecureActionButtonTemplate, one per slice),
--  the key button the Radial Menu keybind clicks, and the mouse-wheel page button. Holding
--  the key shows the wheel; releasing it uses the slice the cursor points at; the mouse wheel
--  turns to the next/previous wheel while it is open.
--  Architecture / how it works:
--    • The player's wheels are written to attributes OUT OF COMBAT (CM.RadialStore): per wheel k
--      rn<k> (slice count), rt<k>_<i> / rv<k>_<i> (type / value), plus rx<n>_<i> / ry<n>_<i>
--      (direction of slice i of n). Combat only reads them; edits made in combat are queued
--      (CM.TryApplyBindingChange) and stored on PLAYER_REGEN_ENABLED.
--    • Restricted snippets (wrapped OnClick on the key button): press = position the wheel at the
--      crosshair, point the 8 slice buttons at the current wheel, show it and take MOUSEWHEEL +
--      ESCAPE while open; release = AIM (owner:GetMousePosition(), exact angle by dot product,
--      dead zone → none) then return "s<slot>" so the key button clicks that slice button.
--      The slice button's post body closes the wheel. Pre-bodies return (newbutton, message).
--    • The insecure side only reads: CM.IsRadialMenuOpen, CM.RadialCurrent, CM.RadialAimSlot;
--      the wheel calls Wheel:RadialChanged() when the page turns (View repaints).
--  Does not: Draw anything (View.lua), edit wheels (Data.lua), or define UI actions (Actions.lua).
--  Related: Core/RadialMenu/{Data,Actions,View,RadialMenu}.lua, Core/AllyCycle/Cycle.lua,
--  Core/Runtime/BindingQueue.lua, Core/FreeLook/FreeLookController.lua, Bindings.xml
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local ClearOverrideBindings = _G.ClearOverrideBindings
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetCursorPosition = _G.GetCursorPosition
local InCombatLockdown = _G.InCombatLockdown
local SecureHandlerSetFrameRef = _G.SecureHandlerSetFrameRef
local SecureHandlerWrapScript = _G.SecureHandlerWrapScript
local SetOverrideBindingClick = _G.SetOverrideBindingClick
local UIParent = _G.UIParent

-- Lua stdlib
local ipairs = _G.ipairs
local select = _G.select
local type = _G.type
local wipe = _G.wipe

local LAYOUT = CM.RadialLayout
local BIND_NAME = "Combat Mode - Radial Menu"

local Wheel
local KeyButton
local PageButton
local Slices = {}
local OverrideOwner = CreateFrame("Frame", "CombatModeRadialOverrideOwner", UIParent)

-- Insecure mirror of what was stored: lists[k] = { dbIndex = n, entries = { filtered entries } }.
local lists = {}

---------------------------------------------------------------------------------------
-- Snippets (restricted environment: no GetCursorPosition, math is limited, no string.format)
---------------------------------------------------------------------------------------
local APPLY = [[
  local cur = owner:GetAttribute("rcur") or 1
  local n = owner:GetAttribute("rn" .. cur) or 0
  owner:SetAttribute("rcurn", n)
  for i = 1, 8 do
    local b = owner:GetFrameRef("slice" .. i)
    local t = nil
    local v = nil
    if i <= n then
      t = owner:GetAttribute("rt" .. cur .. "_" .. i)
      v = owner:GetAttribute("rv" .. cur .. "_" .. i)
    end
    b:SetAttribute("spell", t == "spell" and v or nil)
    b:SetAttribute("item", t == "item" and v or nil)
    b:SetAttribute("macro", t == "macro" and v or nil)
    b:SetAttribute("macrotext", t == "macrotext" and v or nil)
    b:SetAttribute("type", (t == "macrotext") and "macro" or t)
  end
]]

local HIDE = [[
  owner:Hide()
  owner:ClearBindings()
]]

-- slot = slice index the cursor points at (0 = none: outside the frame or inside the dead zone).
local AIM = [[
  local slot = 0
  local n = owner:GetAttribute("rcurn") or 0
  local mx, my = owner:GetMousePosition()
  if n > 0 and mx then
    local dx = (mx - 0.5) * owner:GetWidth()
    local dy = (my - 0.5) * owner:GetHeight()
    local dead = owner:GetAttribute("rdead") or 50
    if dx * dx + dy * dy > dead * dead then
      local best = -100000000
      for i = 1, n do
        local dot = dx * owner:GetAttribute("rx" .. n .. "_" .. i) + dy * owner:GetAttribute("ry" .. n .. "_" .. i)
        if dot > best then
          slot = i
          best = dot
        end
      end
    end
  end
]]

-- The Radial Menu key (both edges): press opens, release uses the aimed slice.
local KEY_PRE = [[
  local owner = owner or self
  if button == "ESC" then
    if owner:IsShown() then
      ]] .. HIDE .. [[
    end
    return false
  end
  if down then
    self:SetAttribute("useOnKeyDown", true)
    if (owner:GetAttribute("rtotal") or 0) < 1 then
      return false
    end
    owner:ClearAllPoints()
    owner:SetPoint("CENTER", "$parent", "CENTER", 0, owner:GetAttribute("ryoff") or 0)
    ]] .. APPLY .. [[
    owner:Show()
    owner:SetBindingClick(true, "MOUSEWHEELUP", "CombatModeRadialPage", "UP")
    owner:SetBindingClick(true, "MOUSEWHEELDOWN", "CombatModeRadialPage", "DOWN")
    owner:SetBindingClick(true, "ESCAPE", "CombatModeRadialKey", "ESC")
    owner:CallMethod("RadialChanged")
    return false
  end
  if not owner:IsShown() then
    return false
  end
  ]] .. AIM .. [[
  if slot < 1 then
    ]] .. HIDE .. [[
    return false
  end
  self:SetAttribute("useOnKeyDown", false)
  return "s" .. slot, true
]]

-- Mouse wheel while open: previous / next wheel. Wheel binds may send a down AND an up; act on
-- whichever arrives first and swallow its pair.
local PAGE_PRE = [[
  local owner = owner or self
  if not owner:IsShown() then
    return false
  end
  if down then
    self:SetAttribute("rseen", true)
  elseif self:GetAttribute("rseen") then
    self:SetAttribute("rseen", nil)
    return false
  end
  local total = owner:GetAttribute("rtotal") or 0
  if total < 2 then
    return false
  end
  local cur = owner:GetAttribute("rcur") or 1
  if button == "UP" then
    cur = cur - 1
  else
    cur = cur + 1
  end
  if cur < 1 then
    cur = total
  elseif cur > total then
    cur = 1
  end
  owner:SetAttribute("rcur", cur)
  ]] .. APPLY .. [[
  owner:CallMethod("RadialChanged")
  return false
]]

---------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------
if SecureHandlerWrapScript then
  Wheel = CreateFrame("Frame", "CombatModeRadialWheel", UIParent, "SecureHandlerBaseTemplate")
  Wheel:SetSize(LAYOUT.FRAME, LAYOUT.FRAME)
  Wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  Wheel:SetFrameStrata("DIALOG")
  Wheel:EnableMouse(false)
  Wheel:Hide()
  Wheel:SetAttribute("rcur", 1)
  Wheel:SetAttribute("rtotal", 0)
  Wheel.RadialChanged = function()
    if CM.RadialViewRefresh then
      CM.RadialViewRefresh()
    end
  end

  KeyButton = CreateFrame("Button", "CombatModeRadialKey", UIParent, "SecureActionButtonTemplate")
  KeyButton:RegisterForClicks("AnyDown", "AnyUp")
  KeyButton:SetAttribute("useOnKeyDown", true)
  KeyButton:SetAttribute("type", "click")
  KeyButton:Hide()

  PageButton = CreateFrame("Button", "CombatModeRadialPage", UIParent, "SecureActionButtonTemplate")
  PageButton:RegisterForClicks("AnyDown", "AnyUp")
  PageButton:Hide()

  for i = 1, LAYOUT.MAX_SLICES do
    local slice =
      CreateFrame("Button", "CombatModeRadialSlice" .. i, Wheel, "SecureActionButtonTemplate")
    slice:SetSize(1, 1)
    slice:SetPoint("CENTER", Wheel, "CENTER", 0, 0)
    slice:RegisterForClicks("AnyUp")
    slice:SetAttribute("useOnKeyDown", false)
    slice:SetAttribute("checkselfcast", false)
    slice:SetAttribute("checkfocuscast", false)
    slice:SetAttribute("checkmouseovercast", false)
    slice:EnableMouse(false)
    -- Pre: leave the click alone and hand "true" to the post body, which closes the wheel.
    SecureHandlerWrapScript(slice, "OnClick", Wheel, "return nil, true", HIDE)
    SecureHandlerSetFrameRef(Wheel, "slice" .. i, slice)
    KeyButton:SetAttribute("*clickbutton-s" .. i, slice)
    Slices[i] = slice
  end

  SecureHandlerWrapScript(KeyButton, "OnClick", Wheel, KEY_PRE)
  SecureHandlerWrapScript(PageButton, "OnClick", Wheel, PAGE_PRE)
end

---------------------------------------------------------------------------------------
-- Insecure state readers
---------------------------------------------------------------------------------------
function CM.IsRadialMenuOpen()
  return Wheel ~= nil and Wheel:IsShown()
end

function CM.RadialGetWheelFrame()
  return Wheel
end

--- k, total, entries (filtered, as stored), wheel (DB table) for the page showing now.
function CM.RadialCurrent()
  if not Wheel then
    return 0, 0, {}, nil
  end
  local total = #lists
  local k = Wheel:GetAttribute("rcur") or 1
  if k < 1 or k > total then
    k = 1
  end
  local list = lists[k]
  if not list then
    return 0, 0, {}, nil
  end
  return k, total, list.entries, CM.RadialGetWheels()[list.dbIndex]
end

--- Slice (1..n) the cursor points at; 0 = none. Same maths as the AIM snippet.
function CM.RadialAimSlot()
  if not Wheel or not Wheel:IsShown() then
    return 0
  end
  local _, _, entries = CM.RadialCurrent()
  local n = #entries
  if n < 1 then
    return 0
  end
  local left, bottom, width, height = Wheel:GetRect()
  if not left then
    return 0
  end
  local es = Wheel:GetEffectiveScale()
  if not es or es == 0 then
    return 0
  end
  local cx, cy = GetCursorPosition()
  local dx = cx / es - (left + width / 2)
  local dy = cy / es - (bottom + height / 2)
  local dead = CM.RadialStyle().dead
  if dx * dx + dy * dy <= dead * dead then
    return 0
  end
  local slot, best = 0, -1e9
  for i = 1, n do
    local ux, uy = CM.RadialSlotDir(i, n)
    local dot = dx * ux + dy * uy
    if dot > best then
      slot, best = i, dot
    end
  end
  return slot
end

---------------------------------------------------------------------------------------
-- Store (out of combat only)
---------------------------------------------------------------------------------------
local function StoreDirections()
  for n = 1, LAYOUT.MAX_SLICES do
    for i = 1, n do
      local x, y = CM.RadialSlotDir(i, n)
      Wheel:SetAttribute("rx" .. n .. "_" .. i, x)
      Wheel:SetAttribute("ry" .. n .. "_" .. i, y)
    end
  end
end

local function CrosshairYOffset()
  local g = CM.DB and CM.DB.global
  return (g and g.crosshairY) or 0
end

local function StoreImpl()
  if not Wheel or InCombatLockdown() then
    return
  end
  StoreDirections()
  wipe(lists)
  for dbIndex, wheel in ipairs(CM.RadialGetWheels()) do
    local entries = {}
    for _, entry in ipairs(CM.RadialCompact(wheel)) do
      if CM.RadialEntrySecure(entry) then
        entries[#entries + 1] = entry
      end
    end
    if #entries > 0 then
      lists[#lists + 1] = { dbIndex = dbIndex, entries = entries }
    end
  end
  for k = 1, LAYOUT.MAX_WHEELS do
    local list = lists[k]
    local n = list and #list.entries or 0
    Wheel:SetAttribute("rn" .. k, n)
    for i = 1, LAYOUT.MAX_SLICES do
      local kind, value, isText
      if i <= n then
        kind, value, isText = CM.RadialEntrySecure(list.entries[i])
      end
      Wheel:SetAttribute("rt" .. k .. "_" .. i, kind and (isText and "macrotext" or kind) or nil)
      Wheel:SetAttribute("rv" .. k .. "_" .. i, kind and value or nil)
    end
  end
  Wheel:SetAttribute("rtotal", #lists)
  local cur = Wheel:GetAttribute("rcur") or 1
  if cur < 1 or cur > #lists then
    Wheel:SetAttribute("rcur", 1)
  end
  Wheel:SetAttribute("rdead", CM.RadialStyle().dead)
  Wheel:SetAttribute("ryoff", CrosshairYOffset())
  Wheel:Execute([[ local owner = self ]] .. APPLY)
  if CM.RadialViewRefresh then
    CM.RadialViewRefresh()
  end
end

local function ApplyBindingImpl()
  ClearOverrideBindings(OverrideOwner)
  if not KeyButton or not GetBindingKey then
    return
  end
  for _, key in ipairs({ GetBindingKey(BIND_NAME) }) do
    SetOverrideBindingClick(OverrideOwner, false, key, KeyButton:GetName(), "LeftButton")
  end
end

local function ApplyAll()
  StoreImpl()
  ApplyBindingImpl()
end

--- Re-store the wheels and rebind the key (queued while in combat).
function CM.RadialRefresh()
  if not Wheel then
    return
  end
  if CM.TryApplyBindingChange then
    CM.TryApplyBindingChange("radial menu", ApplyAll)
  elseif not InCombatLockdown() then
    ApplyAll()
  end
end

function CM.RadialIsBound()
  return GetBindingKey ~= nil and GetBindingKey(BIND_NAME) ~= nil
end
