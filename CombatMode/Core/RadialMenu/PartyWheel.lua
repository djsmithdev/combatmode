---------------------------------------------------------------------------------------
--  Core/RadialMenu/PartyWheel.lua — RADIALMENU — Party Wheel: hold a helpful spell, flick, release
---------------------------------------------------------------------------------------
--  What it does: Holding a bar key whose spell is on the Party Wheel list (char.partyWheelSpells)
--  opens a wheel of group members; releasing over one casts the spell on them, releasing in the
--  centre after leaving it casts it on yourself; a quick tap (or never leaving the centre) casts it
--  on your living friendly target (an Ally Cycle pick), else on yourself. Unlisted spells on the
--  same key cast as before. A quick tap shows nothing: the wheel is drawn (and the cursor freed)
--  only once the key has been held for REVEAL_DELAY. In a raid the mouse wheel pages through up
--  to 8 members per page.
--  Architecture / how it works:
--    • Frames (all secure): CombatModePartyWheel (SecureHandlerBaseTemplate, the wheel), 8 slice
--      buttons (type spell + unit), a centre slice CombatModePartyWheelSelf (macro
--      /cast [@target,help,nodead][@player]), the key button CombatModePartyWheelKey, a page
--      button and one route button per routed bar binding (CombatModePartyWheelRoute<idx>,
--      macrotext = the key's CM.BuildClickCastMacroText, useOnKeyDown false so a /click delegate
--      fires it; unlisted spells only).
--    • BindingOverrides.ApplyGroundCastKeyOverrides asks CM.PartyWheelPrepareKey for keys whose bar
--      slot can hold a listed spell; those keys click the key button with button "b<idx>" instead of
--      the CombatModeSlot proxy.
--    • Press snippet reads the visible bar button's live slot (ActionButton_CalculateAction maths,
--      so form / page swaps in combat follow) and GetActionInfo; listed spell + group = open the
--      wheel, else forward the press to the route button (follows ActionButtonUseKeyDown).
--      Release: AIM (same maths as Secure.lua) → "s<slot>" casts on that unit, centre → "self";
--      only the key that opened the wheel resolves it. One wheel at a time: frame refs "radial"
--      (here) and "party" (on CombatModeRadialWheel) let each key snippet skip while the other is open.
--    • Harmful-only spells (C_Spell.IsSpellHarmful and not IsSpellHelpful) are never listed:
--      CM.PartyWheelIsEligibleSpell filters the tab's picker and the stored set.
--    • Out of combat only: the allowlist (pw-<spellID>), the pages of unit tokens (pn<k>, pu<k>_<i>:
--      party1..4, or raidN minus the player, 8 per page, max LAYOUT.MAX_WHEELS pages), offline
--      flags (po<k>_<i>: the restricted environment has no UnitIsConnected; a release over an
--      offline slice just closes) and the slice directions. Roster / list / connection changes in
--      combat wait for CM.PartyWheelFlush (regen); the view desaturates offline members live meanwhile.
--    • Hold delay (insecure: the restricted environment has no clock): the secure wheel opens on
--      press, but CM.PartyWheelStartReveal only reports it open (CM.IsPartyWheelOpen, so the view
--      and Mouse Look react) after REVEAL_DELAY; a release before that just casts.
--    • Centre target: the dead zone is a protected motion-only frame (CombatModePartyWheelCentre)
--      whose OnEnter (the cursor coming back) sets pwleft; a centre release then casts
--      "/cast [@player]", else (tap, or never left) "/cast [@target,help,nodead][@player]"
--      through the centre slice.
--    • Insecure readers for View.lua: CM.IsPartyWheelOpen, CM.PartyWheelLeftCentre,
--      CM.PartyWheelGetFrame, CM.PartyWheelCurrent, CM.PartyWheelAimSlot.
--  Does not: Draw (View.lua), bind keys itself (BindingOverrides.lua), or work on left / right
--  click (Mouse Look override bindings stop with Mouse Look, so their release never reaches it).
--  Related: Core/RadialMenu/{Secure,View,RadialMenu}.lua, Core/ClickCasting/BindingOverrides.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua, UI/Options/Tabs/TabRadialMenu.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Spell = _G.C_Spell
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetActionInfo = _G.GetActionInfo
local GetCursorPosition = _G.GetCursorPosition
local GetNumGroupMembers = _G.GetNumGroupMembers
local GetNumSubgroupMembers = _G.GetNumSubgroupMembers
local InCombatLockdown = _G.InCombatLockdown
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local SecureHandlerSetFrameRef = _G.SecureHandlerSetFrameRef
local SecureHandlerWrapScript = _G.SecureHandlerWrapScript
local UIParent = _G.UIParent
local UnitIsUnit = _G.UnitIsUnit

-- Lua stdlib
local ipairs = _G.ipairs
local math = _G.math
local next = _G.next
local pairs = _G.pairs
local pcall = _G.pcall
local tonumber = _G.tonumber
local type = _G.type
local wipe = _G.wipe

local LAYOUT = CM.RadialLayout
local PAGE_SIZE = 8
-- Highest action slot a paged main-bar button can show (bonus, vehicle, override pages included).
local MAX_PAGES = 15

local Wheel
local KeyButton
local PageButton
local Slices = {}
local RouteButtons = {} -- [idx] = route button
local storedSpells = {} -- spellIDs written as pw-<id>, so the next store can clear them
-- Seconds the key must be held before the wheel is drawn and the cursor freed (a tap shows nothing).
local REVEAL_DELAY = 0.15
local revealed = false
local revealTimer

---------------------------------------------------------------------------------------
-- Snippets (restricted environment)
---------------------------------------------------------------------------------------
local APPLY = [[
  local cur = owner:GetAttribute("rcur") or 1
  local n = owner:GetAttribute("pn" .. cur) or 0
  owner:SetAttribute("rcurn", n)
  local spell = owner:GetAttribute("pwspell")
  for i = 1, 8 do
    local b = owner:GetFrameRef("slice" .. i)
    local u = nil
    if i <= n then
      u = owner:GetAttribute("pu" .. cur .. "_" .. i)
    end
    b:SetAttribute("unit", u)
    b:SetAttribute("spell", u and spell or nil)
    b:SetAttribute("type", u and "spell" or nil)
  end
]]

local HIDE = [[
  owner:Hide()
  owner:ClearBindings()
]]

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

-- Action slot the visible bar button would use right now (Blizzard's ActionButton_CalculateAction).
local LIVE_SLOT = [[
  local actionSlot = nil
  local bar = owner:GetFrameRef("bar" .. idx)
  if bar then
    local id = bar:GetID()
    if id and id > 0 then
      local page = bar:GetEffectiveAttribute("actionpage")
      if not page then
        page = GetActionBarPage()
        if HasVehicleActionBar() then
          page = GetVehicleBarIndex()
        elseif HasOverrideActionBar() then
          page = GetOverrideBarIndex()
        elseif HasTempShapeshiftActionBar() then
          page = GetTempShapeshiftBarIndex()
        elseif HasBonusActionBar() and page == 1 then
          page = GetBonusBarIndex()
        end
      end
      actionSlot = id + (page - 1) * 12
    else
      actionSlot = bar:GetAttribute("action")
    end
  end
]]

-- The routed key (both edges): button = "b<idx>" from the override binding, "ESC" while open
-- (Esc or right-click: cancel, so the release finds the wheel hidden and casts nothing).
local KEY_PRE = [[
  local owner = owner or self
  if button == "ESC" then
    if owner:IsShown() then
      ]] .. HIDE .. [[
    end
    return false
  end
  local idx = tonumber(strsub(button, 2))
  if not idx then
    return false
  end
  if down then
    if owner:IsShown() then
      return false
    end
    local spell = nil
    local radial = owner:GetFrameRef("radial")
    -- One wheel at a time: with the Radial Menu open the key casts as usual.
    if (owner:GetAttribute("ptotal") or 0) > 0 and not (radial and radial:IsShown()) then
      ]] .. LIVE_SLOT .. [[
      if actionSlot then
        local kind, sid = GetActionInfo(actionSlot)
        if kind == "spell" and sid then
          spell = owner:GetAttribute("pw-" .. sid)
        end
      end
    end
    if not spell then
      -- Not a Party Wheel spell: the key works as before (press or release per ActionButtonUseKeyDown).
      owner:SetAttribute("pwfwd", idx)
      self:SetAttribute("useOnKeyDown", nil)
      return "r" .. idx
    end
    owner:SetAttribute("pwfwd", nil)
    owner:SetAttribute("pwidx", idx)
    owner:SetAttribute("pwspell", spell)
    owner:SetAttribute("pwleft", nil)
    self:SetAttribute("useOnKeyDown", true)
    owner:ClearAllPoints()
    owner:SetPoint("CENTER", "$parent", "CENTER", 0, owner:GetAttribute("ryoff") or 0)
    ]] .. APPLY .. [[
    owner:Show()
    owner:SetBindingClick(true, "MOUSEWHEELUP", "CombatModePartyWheelPage", "UP")
    owner:SetBindingClick(true, "MOUSEWHEELDOWN", "CombatModePartyWheelPage", "DOWN")
    owner:SetBindingClick(true, "ESCAPE", "CombatModePartyWheelKey", "ESC")
    owner:SetBindingClick(true, "BUTTON2", "CombatModePartyWheelKey", "ESC")
    owner:CallMethod("PartyWheelChanged")
    return false
  end
  local fwd = owner:GetAttribute("pwfwd")
  if fwd then
    owner:SetAttribute("pwfwd", nil)
    return "r" .. fwd
  end
  if not owner:IsShown() then
    return false
  end
  local route = owner:GetAttribute("pwidx") or idx
  if route ~= idx then
    -- Another wheel key released while this one holds the wheel: only the opener resolves it.
    return false
  end
  ]] .. AIM .. [[
  self:SetAttribute("useOnKeyDown", false)
  if slot > 0 then
    local cur = owner:GetAttribute("rcur") or 1
    local unit = owner:GetAttribute("pu" .. cur .. "_" .. slot)
    -- po<k>_<i>: offline when stored (no UnitIsConnected in here); releasing on one just closes.
    if unit and UnitExists(unit) and not owner:GetAttribute("po" .. cur .. "_" .. slot) then
      return "s" .. slot, true
    end
    ]] .. HIDE .. [[
    return false
  end
  -- Back in the centre after leaving it (pwleft, the centre zone's OnEnter): you; a tap or a release
  -- that never left: your living friendly target (an Ally Cycle pick), else you.
  local spell = owner:GetAttribute("pwspell")
  if not spell then
    ]] .. HIDE .. [[
    return false
  end
  local cond = owner:GetAttribute("pwleft") and "[@player] " or "[@target,help,nodead][@player] "
  owner:GetFrameRef("self"):SetAttribute("macrotext", "/cast " .. cond .. spell)
  return "self", true
]]

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
  local total = owner:GetAttribute("ptotal") or 0
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
  owner:CallMethod("PartyWheelChanged")
  return false
]]

---------------------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------------------
if SecureHandlerWrapScript then
  Wheel = CreateFrame("Frame", "CombatModePartyWheel", UIParent, "SecureHandlerBaseTemplate")
  Wheel:SetSize(LAYOUT.FRAME, LAYOUT.FRAME)
  Wheel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  Wheel:SetFrameStrata("DIALOG")
  Wheel:EnableMouse(false)
  Wheel:Hide()
  Wheel:SetAttribute("rcur", 1)
  Wheel:SetAttribute("ptotal", 0)
  Wheel.PartyWheelChanged = function()
    if CM.RadialViewRefresh then
      CM.RadialViewRefresh()
    end
  end

  KeyButton =
    CreateFrame("Button", "CombatModePartyWheelKey", UIParent, "SecureActionButtonTemplate")
  KeyButton:RegisterForClicks("AnyDown", "AnyUp")
  KeyButton:SetAttribute("type", "click")
  KeyButton:Hide()

  PageButton =
    CreateFrame("Button", "CombatModePartyWheelPage", UIParent, "SecureActionButtonTemplate")
  PageButton:RegisterForClicks("AnyDown", "AnyUp")
  PageButton:Hide()

  for i = 1, LAYOUT.MAX_SLICES do
    local slice =
      CreateFrame("Button", "CombatModePartyWheelSlice" .. i, Wheel, "SecureActionButtonTemplate")
    slice:SetSize(1, 1)
    slice:SetPoint("CENTER", Wheel, "CENTER", 0, 0)
    slice:RegisterForClicks("AnyUp")
    slice:SetAttribute("useOnKeyDown", false)
    slice:SetAttribute("checkselfcast", false)
    slice:SetAttribute("checkfocuscast", false)
    slice:SetAttribute("checkmouseovercast", false)
    slice:EnableMouse(false)
    SecureHandlerWrapScript(slice, "OnClick", Wheel, "return nil, true", HIDE)
    SecureHandlerSetFrameRef(Wheel, "slice" .. i, slice)
    KeyButton:SetAttribute("*clickbutton-s" .. i, slice)
    Slices[i] = slice
  end

  -- Centre release / tap: the held spell on your living friendly target (an Ally Cycle pick),
  -- else on yourself. Macrotext set by KEY_PRE on release.
  local selfSlice =
    CreateFrame("Button", "CombatModePartyWheelSelf", Wheel, "SecureActionButtonTemplate")
  selfSlice:SetSize(1, 1)
  selfSlice:SetPoint("CENTER", Wheel, "CENTER", 0, 0)
  selfSlice:RegisterForClicks("AnyUp")
  selfSlice:SetAttribute("useOnKeyDown", false)
  selfSlice:SetAttribute("type", "macro")
  selfSlice:EnableMouse(false)
  SecureHandlerWrapScript(selfSlice, "OnClick", Wheel, "return nil, true", HIDE)
  SecureHandlerSetFrameRef(Wheel, "self", selfSlice)
  KeyButton:SetAttribute("*clickbutton-self", selfSlice)

  -- The dead zone as a protected motion-only frame: its OnEnter marks that the cursor came back
  -- into the centre during this hold (pwleft), so a release there casts on you. The cursor is
  -- freed already inside it, which fires no motion OnEnter (and so no wrapped OnLeave either), so
  -- the first return counts. Mouse Look hides the cursor until the hold delay, so a tap never
  -- enters. Sized by StoreImpl.
  local centreZone =
    CreateFrame("Frame", "CombatModePartyWheelCentre", Wheel, "SecureFrameTemplate")
  centreZone:SetPoint("CENTER", Wheel, "CENTER", 0, 0)
  centreZone:SetSize(100, 100)
  if centreZone.SetMouseClickEnabled then
    centreZone:SetMouseClickEnabled(false)
  end
  centreZone:SetMouseMotionEnabled(true)
  SecureHandlerWrapScript(
    centreZone,
    "OnEnter",
    Wheel,
    [[
    if owner:IsShown() then
      owner:SetAttribute("pwleft", true)
    end
  ]]
  )

  SecureHandlerWrapScript(KeyButton, "OnClick", Wheel, KEY_PRE)
  SecureHandlerWrapScript(PageButton, "OnClick", Wheel, PAGE_PRE)

  -- Each wheel's key snippet checks the other so only one is ever open (Secure.lua loads first).
  local radial = _G.CombatModeRadialWheel
  if radial then
    SecureHandlerSetFrameRef(Wheel, "radial", radial)
    SecureHandlerSetFrameRef(radial, "party", Wheel)
  end
end

---------------------------------------------------------------------------------------
-- Spell list (char.partyWheelSpells: spell-ID CSV, edited by the tab's SpellMultiSelect)
---------------------------------------------------------------------------------------
local spellSet = {}
local spellSetSource

--- Spell the Party Wheel can cast on a group member: helpful, or at least not harmful-only.
--- Unknown answers (API missing / error) count as eligible.
function CM.PartyWheelIsEligibleSpell(spellID)
  if type(spellID) ~= "number" or not C_Spell or not C_Spell.IsSpellHarmful then
    return type(spellID) == "number"
  end
  local okHarm, harmful = pcall(C_Spell.IsSpellHarmful, spellID)
  if not okHarm or harmful ~= true then
    return true
  end
  local okHelp, helpful = pcall(C_Spell.IsSpellHelpful, spellID)
  return okHelp and helpful == true
end

--- { [spellID] = true } parsed from the CSV (re-parsed only when the string changes); harmful-only
--- spells are dropped even if an older list still holds them.
local function SpellTable()
  local char = CM.DB and CM.DB.char
  local csv = char and type(char.partyWheelSpells) == "string" and char.partyWheelSpells or ""
  if csv ~= spellSetSource then
    spellSetSource = csv
    wipe(spellSet)
    for id in csv:gmatch("%d+") do
      id = tonumber(id)
      if CM.PartyWheelIsEligibleSpell(id) then
        spellSet[id] = true
      end
    end
  end
  return spellSet
end

function CM.PartyWheelHasSpell(spellID)
  return type(spellID) == "number" and SpellTable()[spellID] == true
end

local function HasAnySpell()
  return next(SpellTable()) ~= nil
end

---------------------------------------------------------------------------------------
-- Key routing (called from BindingOverrides.ApplyGroundCastKeyOverrides, out of combat)
---------------------------------------------------------------------------------------
local function SlotHasListedSpell(slot)
  local ok, kind, id = pcall(GetActionInfo, slot)
  return ok and kind == "spell" and CM.PartyWheelHasSpell(id)
end

-- Every slot this binding can show: all pages of a main-bar button, else its displayed slot.
local function BindingCanShowListedSpell(bindingName)
  local num = bindingName:match("^ACTIONBUTTON(%d+)$")
  if num then
    for page = 1, MAX_PAGES do
      if SlotHasListedSpell(num + (page - 1) * 12) then
        return true
      end
    end
    return false
  end
  local _, _, slot = CM.GetDisplayedActionSlotInfo(bindingName)
  return slot ~= nil and SlotHasListedSpell(slot)
end

--- Keyboard key of `bindingName` (index `idx` in the click-cast binding list) should open the Party
--- Wheel: sets up its route button and bar ref and returns the frame name + button to click, else nil.
function CM.PartyWheelPrepareKey(idx, bindingName, macroText)
  if not KeyButton or InCombatLockdown() or not HasAnySpell() or not macroText then
    return nil
  end
  local barName = CM.GetEffectiveBarButtonFrameName(bindingName)
  local bar = barName and _G[barName]
  if not bar or not BindingCanShowListedSpell(bindingName) then
    return nil
  end
  local route = RouteButtons[idx]
  if not route then
    route = CreateFrame(
      "Button",
      "CombatModePartyWheelRoute" .. idx,
      UIParent,
      "SecureActionButtonTemplate"
    )
    route:RegisterForClicks("AnyUp", "AnyDown")
    route:SetAttribute("type", "macro")
    route:SetAttribute("useOnKeyDown", false)
    route:Hide()
    RouteButtons[idx] = route
    KeyButton:SetAttribute("*clickbutton-r" .. idx, route)
  end
  route:SetAttribute("macrotext", macroText)
  SecureHandlerSetFrameRef(Wheel, "bar" .. idx, bar)
  return KeyButton:GetName(), "b" .. idx
end

---------------------------------------------------------------------------------------
-- Insecure state readers
---------------------------------------------------------------------------------------
local pages = {} -- [k] = { unit tokens }, mirrors the pn / pu attributes

--- Open and held past REVEAL_DELAY: drawn, cursor free. A tap never gets here.
function CM.IsPartyWheelOpen()
  return revealed and Wheel ~= nil and Wheel:IsShown()
end

--- Wheel OnShow (RadialMenu.lua): calls onReveal once the key is still held after REVEAL_DELAY.
function CM.PartyWheelStartReveal(onReveal)
  if revealTimer then
    revealTimer:Cancel()
  end
  revealed = false
  revealTimer = C_Timer.NewTimer(REVEAL_DELAY, function()
    revealTimer = nil
    if Wheel and Wheel:IsShown() then
      revealed = true
      onReveal()
    end
  end)
end

--- Wheel OnHide: true when it had been revealed (so the view and Mouse Look need closing).
function CM.PartyWheelStopReveal()
  if revealTimer then
    revealTimer:Cancel()
    revealTimer = nil
  end
  local was = revealed
  revealed = false
  return was
end

--- The cursor left the centre during this hold, so a centre release casts on you (View shows
--- your portrait there only then).
function CM.PartyWheelLeftCentre()
  return Wheel ~= nil and Wheel:GetAttribute("pwleft") == true
end

function CM.PartyWheelGetFrame()
  return Wheel
end

--- Disconnected group member (CM.AllyCycleTarget.IsOffline: public false only, secret = online).
local function UnitOffline(unit)
  return CM.AllyCycleTarget.IsOffline(unit)
end

--- k, total, entries ({ kind = "unit", unit, spell = name, offline }), title (spell name) for the
--- page showing now.
function CM.PartyWheelCurrent()
  if not Wheel then
    return 0, 0, {}, nil
  end
  local total = #pages
  local k = Wheel:GetAttribute("rcur") or 1
  if k < 1 or k > total then
    k = 1
  end
  local units = pages[k]
  if not units then
    return 0, 0, {}, nil
  end
  local spell = Wheel:GetAttribute("pwspell")
  local entries = {}
  for i, unit in ipairs(units) do
    -- Offline: as stored (what a release does) or live (dropped in combat, store not caught up).
    local offline = Wheel:GetAttribute("po" .. k .. "_" .. i) == true or UnitOffline(unit)
    entries[i] = { kind = "unit", unit = unit, spell = spell, offline = offline }
  end
  -- pwspell holds the spell name (see StoreImpl), so it is the title as is.
  return k, total, entries, spell
end

--- Slice (1..n) the cursor points at; 0 = centre. Same maths as the AIM snippet.
function CM.PartyWheelAimSlot()
  if not Wheel or not Wheel:IsShown() then
    return 0
  end
  local n = Wheel:GetAttribute("rcurn") or 0
  if n < 1 then
    return 0
  end
  local left, bottom, width, height = Wheel:GetRect()
  local es = Wheel:GetEffectiveScale()
  if not left or not es or es == 0 then
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
local function BuildPages()
  wipe(pages)
  local units = {}
  if IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local unit = "raid" .. i
      if not UnitIsUnit(unit, "player") then
        units[#units + 1] = unit
      end
    end
  elseif IsInGroup() then
    for i = 1, math.min(GetNumSubgroupMembers(), 4) do
      units[#units + 1] = "party" .. i
    end
  end
  for i, unit in ipairs(units) do
    local k = math.floor((i - 1) / PAGE_SIZE) + 1
    if k > LAYOUT.MAX_WHEELS then
      break
    end
    pages[k] = pages[k] or {}
    pages[k][#pages[k] + 1] = unit
  end
end

local function StoreImpl()
  if not Wheel or InCombatLockdown() then
    return
  end
  for n = 1, LAYOUT.MAX_SLICES do
    for i = 1, n do
      local x, y = CM.RadialSlotDir(i, n)
      Wheel:SetAttribute("rx" .. n .. "_" .. i, x)
      Wheel:SetAttribute("ry" .. n .. "_" .. i, y)
    end
  end
  for id in pairs(storedSpells) do
    Wheel:SetAttribute("pw-" .. id, nil)
  end
  wipe(storedSpells)
  -- Value = the spell name: the slices cast by name, like the Radial Menu's spell slices.
  for id in pairs(SpellTable()) do
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    Wheel:SetAttribute("pw-" .. id, name or id)
    storedSpells[id] = true
  end
  BuildPages()
  for k = 1, LAYOUT.MAX_WHEELS do
    local units = pages[k]
    Wheel:SetAttribute("pn" .. k, units and #units or 0)
    for i = 1, LAYOUT.MAX_SLICES do
      local unit = units and units[i] or nil
      Wheel:SetAttribute("pu" .. k .. "_" .. i, unit)
      Wheel:SetAttribute("po" .. k .. "_" .. i, unit and UnitOffline(unit) or nil)
    end
  end
  Wheel:SetAttribute("ptotal", #pages)
  local cur = Wheel:GetAttribute("rcur") or 1
  if cur < 1 or cur > #pages then
    Wheel:SetAttribute("rcur", 1)
  end
  local dead = CM.RadialStyle().dead
  Wheel:SetAttribute("rdead", dead)
  local centreZone = _G.CombatModePartyWheelCentre
  if centreZone then
    centreZone:SetSize(2 * dead, 2 * dead)
  end
  local g = CM.DB and CM.DB.global
  Wheel:SetAttribute("ryoff", (g and g.crosshairY) or 0)
end

local pendingStore, pendingRebind = false, false

--- Re-store roster and spell list. `rebind` also re-applies the bar key overrides, needed when the
--- spell list changes which keys are routed. In combat both wait (silently: roster changes are
--- frequent) for CM.PartyWheelFlush on PLAYER_REGEN_ENABLED.
function CM.PartyWheelRefresh(rebind)
  if not Wheel then
    return
  end
  if InCombatLockdown() then
    pendingStore = true
    pendingRebind = pendingRebind or rebind == true
    return
  end
  StoreImpl()
  if rebind and CM.ApplyGroundCastKeyOverrides then
    CM.ApplyGroundCastKeyOverrides()
  end
end

function CM.PartyWheelFlush()
  if not pendingStore or InCombatLockdown() then
    return
  end
  local rebind = pendingRebind
  pendingStore, pendingRebind = false, false
  CM.PartyWheelRefresh(rebind)
end
