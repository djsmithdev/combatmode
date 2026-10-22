---------------------------------------------------------------------------------------
--  Core/RadialMenu/View.lua — RADIALMENU — wheel drawing: art, icons, aim highlight
---------------------------------------------------------------------------------------
--  What it does: Draws the open Radial Menu on a plain child frame of the secure wheel: the
--  background art for the slice count, round icon slots with cooldown / count, the highlight on the slice the cursor points at, the wheel name and the wheel page dots.
--  Architecture / how it works:
--    • Art is Assets/radial/radial_[minimal_]{bg,sel,off}_N.tga (N = slice count 1..8); which set, its
--      size and overlay placement come from CM.RadialStyle() (global.radialStyle: Forever / Minimal).
--      Minimal draws one radial_minimal_bg.tga plus a prerendered radial_minimal_div_N.tga (Data.lua
--      helpers), both 1:1 so nothing is resampled. The sel / off textures are slice 1 only (sel white, tinted per wheel), moved and rotated per slice.
--    • Paint() rebuilds from CM.RadialCurrent() (page change, show, cooldown / bag events);
--      OnUpdate only compares CM.RadialAimSlot() and re-highlights when the aim changes.
--    • OnUpdate also animates: a short fade / grow on open and a scale-up on the aimed slice.
--    • Quiet Blizzard UI sounds (SOUNDKIT) on open, close, aiming a new slice (throttled), turning a
--      page, and releasing over a usable slice (Esc / centre / greyed slice = the close sound).
--    • Never writes secure state; the child frame is insecure, so it can be updated in combat.
--  Does not: Decide what a slice does, store wheels, or bind keys (Secure.lua / Data.lua).
--  Related: Core/RadialMenu/{Data,Secure,RadialMenu}.lua, Core/Runtime/EventRouter.lua,
--  Constants/Gameplay.lua (RADIAL_MENU_EVENTS), Constants/Atlas.lua (CircleMaskScalable)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsKeyDown = _G.IsKeyDown
local PlaySound = _G.PlaySound

-- Lua stdlib
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local table = _G.table
local type = _G.type
local unpack = _G.unpack

local LAYOUT = CM.RadialLayout

-- Sounds: quiet Blizzard UI cues (no shipped audio). Fallback ids cover clients without the SOUNDKIT name.
local SOUNDKIT = _G.SOUNDKIT or {}
local SOUNDS = {
  open = SOUNDKIT.IG_MINIMAP_OPEN or 891,
  close = SOUNDKIT.IG_MINIMAP_CLOSE or 892,
  aim = SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115,
  page = SOUNDKIT.IG_CHARACTER_INFO_TAB or 841,
  confirm = SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856,
}
local AIM_SOUND_GAP = 0.05 -- seconds; a fast flick across slices doesn't machine-gun the tick
local lastAimSound = 0

local function PlayRadialSound(kind)
  local id = SOUNDS[kind]
  if id and CM.IsSoundEnabled("soundRadialMenu") then
    PlaySound(id, "SFX")
  end
end

local AIM_WIDTH = 120
local NAME_WIDTH = 170 -- fits the longest wheel name (LAYOUT.NAME_MAX) without truncating
local TEXT_COLOR = { 0.945, 0.902, 0.827 }
local ART_PATH = "Interface\\AddOns\\CombatMode\\Assets\\radial\\radial_"
local HIGHLIGHT_ALPHA = 1
-- Wheel page dots (Evoker essence art, 48px canvases padded to 64 in power-of-two TGAs, drawn at
-- native / 2). Every layer shares one canvas, so they stack aligned. The current wheel's dot swaps to
-- the active frame and adds a glow and the fill, in their original colours.
local PIP_SIZE = 24
local PIP_GAP = 0
local PIP_ROW_WIDTH = 90 -- widest the dot row may be (the centre's dead zone is 100 across)
local PIP_Y = -22
local PIP_ACTIVE_GROW = 0.3 -- the current wheel's dot is drawn this much bigger (scale, eased with its mix)
local PIP_COORDS = { 8 / 64, 56 / 64, 8 / 64, 56 / 64 }

local view
local bg
local dividers
local sel
local centerName
local centerAim
local closeIcon
local backdrop
local CLOSE_SIZE = 36
-- Soft dark blob behind the centre texts / pips / close marker so they read over any scene.
local BACKDROP_SIZE = 240
-- Animation numbers follow Blizzard's gamepad radial menu: a 0.15 s cubic ease-out fade / grow on
-- open, and a 1.15x exponential-approach scale on the aimed slice.
local OPEN_DURATION = 0.15
local OPEN_START_SCALE = 0.9
local HOVER_SCALE = 1.15
local HOVER_SPEED = 18
local HOVER_SETTLE = 0.001
local openProgress = 1
local SWAP_DURATION = 0.15
local SWAP_START_SCALE = 0.85
local swapProgress = 1
local swapScale = 1
local lastPage
-- The selected wedge fades in on every aim change (same exponential approach as the hover scale).
local SEL_SPEED = 22
local selAlpha = 0
local selGoal = 0
local centerMix = 0
local centerGoal = 0
-- ...and slides along the ring (shortest way round) from the previous slice to the new one.
local selAngle
local selTarget = 0
local pips = {}
local slots = {}
local offs = {}
local lastAim = -1
local lastCount = 0

local function Wheel()
  return CM.RadialGetWheelFrame and CM.RadialGetWheelFrame()
end

local function ItemCount(id)
  if C_Item and C_Item.GetItemCount then
    return C_Item.GetItemCount(id, false, true) or 0
  end
  return 0
end

local function CreateSlot(parent, index)
  local size = LAYOUT.SLOT
  local slot = CreateFrame("Frame", nil, parent)
  slot:SetSize(size, size)

  local over = CM.RadialBuildSlotChrome(slot)

  slot.iconLabel = CM.RadialCreateIconLabel(over, 10)

  slot.cooldown = CreateFrame("Cooldown", nil, slot, "CooldownFrameTemplate")
  slot.cooldown:SetAllPoints(slot.icon)
  slot.cooldown:SetDrawEdge(false)
  slot.cooldown:SetDrawBling(false)
  slot.cooldown:SetHideCountdownNumbers(false)
  local mask = CM.GetAtlasInfo("CircleMaskScalable")
  if mask and slot.cooldown.SetSwipeTexture then
    slot.cooldown:SetSwipeTexture(mask.file)
  end

  slot.count = over:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 2, -2)

  slot.index = index
  slot.scale = 1
  slot.px, slot.py = 0, 0
  return slot
end

local function Build()
  local wheel = Wheel()
  if view or not wheel then
    return
  end
  view = CreateFrame("Frame", "CombatModeRadialView", wheel)
  view:SetSize(LAYOUT.ART, LAYOUT.ART)
  view:SetPoint("CENTER", wheel, "CENTER", 0, 0)
  view:SetFrameLevel(wheel:GetFrameLevel() + 1)

  bg = view:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("CENTER")
  dividers = CM.RadialCreateDividers(view)

  backdrop = view:CreateTexture(nil, "BACKGROUND", nil, 1)
  backdrop:SetTexture(ART_PATH .. "backdrop.tga")
  backdrop:SetVertexColor(0, 0, 0)
  backdrop:SetSize(BACKDROP_SIZE, BACKDROP_SIZE)
  backdrop:SetPoint("CENTER")

  sel = view:CreateTexture(nil, "BORDER")
  sel:Hide()

  for i = 1, LAYOUT.MAX_SLICES do
    offs[i] = view:CreateTexture(nil, "BORDER", nil, 1)
    offs[i]:Hide()
    slots[i] = CreateSlot(view, i)
    slots[i]:Hide()
  end

  -- Same look as the Assist HUD's name text: its font, outline + slug and cream colour.
  centerName = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  centerName:SetPoint("CENTER", view, "CENTER", 0, 22)
  centerAim = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  centerAim:SetPoint("CENTER", view, "CENTER", 0, 0)
  -- Cancel marker: shown while the cursor rests in the dead zone, where releasing closes the wheel.
  closeIcon = CreateFrame("Frame", nil, view)
  closeIcon:SetSize(CLOSE_SIZE, CLOSE_SIZE)
  closeIcon:SetPoint("CENTER")
  local closeX = closeIcon:CreateTexture(nil, "ARTWORK")
  closeX:SetAllPoints()
  closeX:SetTexture(ART_PATH .. "close_x.tga")
  closeX:SetTexCoord(0, 0.75, 0, 0.75)
  closeIcon:Hide()

  for i = 1, LAYOUT.MAX_WHEELS do
    local pip = CreateFrame("Frame", nil, view)
    pip:SetSize(PIP_SIZE, PIP_SIZE)
    local function Layer(layer, level, file)
      local tex = pip:CreateTexture(nil, layer, nil, level)
      tex:SetAllPoints()
      tex:SetTexture(ART_PATH .. file)
      tex:SetTexCoord(unpack(PIP_COORDS))
      return tex
    end
    pip.off = Layer("ARTWORK", 0, "pip_off.tga")
    pip.active = Layer("ARTWORK", 1, "pip_active.tga")
    pip.glow = Layer("BACKGROUND", 0, "pip_glow.tga")
    pip.fill = Layer("OVERLAY", 0, "pip_fill.tga")
    pip:Hide()
    pips[i] = pip
  end
  for label, size in pairs({ [centerName] = 18, [centerAim] = 12 }) do
    label:SetWidth(label == centerName and NAME_WIDTH or AIM_WIDTH)
    label:SetWordWrap(false)
    CM.ApplyOutlineSlug(label, (_G.GameFontNormalSmall:GetFont()), size)
    label:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3], 1)
  end
end

local function PaintPipMix(pip, mix)
  pip.mix = mix
  pip.off:SetAlpha(1 - mix)
  pip.active:SetAlpha(mix)
  pip.glow:SetAlpha(mix)
  pip.fill:SetAlpha(mix)
  -- Anchor offsets are in the pip's own scaled units: divide by the scale to stay centred in place.
  local scale = 1 + PIP_ACTIVE_GROW * mix
  pip:SetScale(scale)
  if pip.px then
    pip:ClearAllPoints()
    pip:SetPoint("CENTER", view, "CENTER", pip.px / scale, PIP_Y / scale)
  end
end

--- Shows one dot per wheel (none for a single wheel), the current one filled.
local function PaintPips(k, total)
  local shown = total > 1 and math.min(total, #pips) or 0
  -- More wheels, smaller dots: they always fit one row inside the centre.
  local size = shown > 0 and math.min(PIP_SIZE, math.floor(PIP_ROW_WIDTH / shown)) or PIP_SIZE
  local width = shown * size + math.max(shown - 1, 0) * PIP_GAP
  for i = 1, #pips do
    local pip = pips[i]
    if i <= shown then
      pip:SetSize(size, size)
      pip.px = -width / 2 + size / 2 + (i - 1) * (size + PIP_GAP)
      -- The current dot crossfades between its idle and active art and grows (eased in the update).
      pip.goal = i == k and 1 or 0
      PaintPipMix(pip, pip.mix or pip.goal)
      pip:Show()
    else
      pip:Hide()
    end
  end
end

local function PlaceOverlayAt(tex, kind, n, a)
  local style = CM.RadialStyle()
  local o = style.overlay[n]
  if not o or (kind == "off" and not style.off) then
    tex:Hide()
    return
  end
  local x = o[3] * math.cos(a) + o[4] * math.sin(a)
  local y = -o[3] * math.sin(a) + o[4] * math.cos(a)
  tex:SetTexture(ART_PATH .. style.art .. kind .. "_" .. n .. ".tga")
  tex:SetSize(o[1], o[2])
  tex:ClearAllPoints()
  tex:SetPoint("CENTER", view, "CENTER", x, y)
  tex:SetRotation(-a)
  tex:Show()
end

-- Cooldown longer than the global cooldown that is still running. Secret values (combat) can't be
-- compared, so those report false and the Cooldown widget's swipe is the only cue.
local function OnRealCooldown(start, duration)
  local isSecret = _G.issecretvalue
  if type(start) ~= "number" or type(duration) ~= "number" then
    return false
  end
  if isSecret and (isSecret(start) or isSecret(duration)) then
    return false
  end
  return start > 0 and duration > 1.5 and start + duration > _G.GetTime()
end

--- True when the slice can't be used right now: unusable spell / item, a running cooldown, no items
--- left, or a UI action that is blocked in combat.
local function SliceUnusable(entry)
  local isSecret = _G.issecretvalue
  local unusable = false
  pcall(function()
    if entry.kind == "spell" then
      if C_Spell and C_Spell.IsSpellUsable then
        local usable = C_Spell.IsSpellUsable(entry.id)
        if not (isSecret and isSecret(usable)) and usable == false then
          unusable = true
        end
      end
      local info = C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(entry.id)
      if info and OnRealCooldown(info.startTime, info.duration) then
        unusable = true
      end
    elseif entry.kind == "item" then
      if ItemCount(entry.id) < 1 then
        unusable = true
      elseif C_Item and C_Item.IsUsableItem then
        local usable = C_Item.IsUsableItem(entry.id)
        if not (isSecret and isSecret(usable)) and usable == false then
          unusable = true
        end
      end
      if C_Item and C_Item.GetItemCooldown then
        local start, duration = C_Item.GetItemCooldown(entry.id)
        if OnRealCooldown(start, duration) then
          unusable = true
        end
      end
    elseif entry.kind == "action" then
      local action = CM.RadialActions and CM.RadialActions.byId[entry.id]
      if
        action
        and (
          (action.noCombat and _G.InCombatLockdown()) or (action.needsGroup and not _G.IsInGroup())
        )
      then
        unusable = true
      end
    end
  end)
  return unusable
end

-- Anchor offsets are in the slot's own (scaled) units: divide by the scale to keep it centred in place.
local function PlaceSlot(slot)
  local scale = slot.scale * swapScale
  slot:SetScale(scale)
  slot:ClearAllPoints()
  slot:SetPoint("CENTER", view, "CENTER", slot.px / scale, slot.py / scale)
end

-- Turning to another wheel: the slices and the wheel name fade in while growing from SWAP_START_SCALE.
local function ApplySwap(eased)
  swapScale = SWAP_START_SCALE + (1 - SWAP_START_SCALE) * eased
  for i = 1, lastCount do
    slots[i]:SetAlpha(eased)
    PlaceSlot(slots[i])
  end
  centerName:SetAlpha(eased)
end

local function PaintCooldown(slot, entry)
  local cd = slot.cooldown
  local ok = pcall(function()
    if entry.kind == "spell" and C_Spell and C_Spell.GetSpellCooldown then
      -- Values may be secret in combat: handed straight to the Cooldown widget, never compared.
      local info = C_Spell.GetSpellCooldown(entry.id)
      if info then
        cd:SetCooldown(info.startTime, info.duration)
        return
      end
    elseif entry.kind == "item" and C_Item and C_Item.GetItemCooldown then
      local start, duration = C_Item.GetItemCooldown(entry.id)
      if start then
        cd:SetCooldown(start, duration)
        return
      end
    end
    cd:Clear()
  end)
  if not ok then
    cd:Clear()
  end
end

local FILLER =
  { of = true, the = true, a = true, an = true, ["and"] = true, to = true, ["for"] = true }

--- UTF-8 continuation bytes are 128..191: characters are counted by skipping them.
local function CharLength(word)
  local count = 0
  for i = 1, #word do
    local byte = word:byte(i)
    if byte < 128 or byte > 191 then
      count = count + 1
    end
  end
  return count
end

--- First `count` UTF-8 characters of `word`.
local function Prefix(word, count)
  local seen = 0
  for i = 1, #word do
    local byte = word:byte(i)
    if byte < 128 or byte > 191 then
      seen = seen + 1
      if seen > count then
        return word:sub(1, i - 1)
      end
    end
  end
  return word
end

local function Fits(label, text, maxWidth)
  label:SetText(text)
  return label:GetStringWidth() <= maxWidth
end

--- Sets `text` on `label`; when it is too wide, shortens it instead of ellipsizing: drops filler
--- words ("of", "the"...), then abbreviates the longest word (Fortifying -> Fort.) until it fits.
local function SetAbbreviated(label, text, maxWidth)
  text = text or ""
  if Fits(label, text, maxWidth) then
    return
  end
  local words = {}
  for word in text:gmatch("%S+") do
    words[#words + 1] = word
  end
  if #words > 1 then
    local kept = { words[1] }
    for i = 2, #words do
      if not FILLER[words[i]:lower()] then
        kept[#kept + 1] = words[i]
      end
    end
    words = kept
  end
  while not Fits(label, table.concat(words, " "), maxWidth) do
    local longest, length = nil, 0
    for i, word in ipairs(words) do
      local chars = CharLength(word)
      if not word:find("%.$") and chars > length and chars > 3 then
        longest, length = i, chars
      end
    end
    if not longest then
      break
    end
    words[longest] = Prefix(words[longest], math.max(1, math.ceil(length / 2))) .. "."
  end
  local short = table.concat(words, " ")
  if not Fits(label, short, maxWidth) then
    -- Still too wide: keep initials of the later words, then cut the first word.
    for i = 2, #words do
      words[i] = Prefix(words[i], 1) .. "."
    end
    short = table.concat(words, " ")
    while not Fits(label, short, maxWidth) and CharLength(words[1]) > 1 do
      words[1] = Prefix(words[1], CharLength(words[1]) - 1)
      short = table.concat(words, " ")
    end
  end
end

-- Aimed slice name: the item's quality colour, else cream.
local function AimColor(entry)
  if entry and entry.kind == "item" and C_Item and C_Item.GetItemQualityByID then
    local quality = C_Item.GetItemQualityByID(entry.id)
    local color = quality and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    if color then
      return color.r, color.g, color.b
    end
  end
  return TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3]
end

-- Centre state, 0 (aiming a slice) .. 1 (aiming the centre): the close marker fades in on
-- a backdrop that turns red while the page dots fade out; eased in the update.
local function ApplyCenter(mix)
  centerMix = mix
  closeIcon:SetShown(mix > 0)
  closeIcon:SetAlpha(mix)
  backdrop:SetVertexColor(0.42 * mix, 0.06 * mix, 0.05 * mix)
  for i = 1, #pips do
    pips[i]:SetAlpha(1 - mix)
  end
end

local function Highlight(aim, n)
  local first = lastAim == -1
  lastAim = aim
  if not first and aim >= 1 then
    local now = GetTime()
    if now - lastAimSound >= AIM_SOUND_GAP then
      lastAimSound = now
      PlayRadialSound("aim")
    end
  end
  local center = aim < 1
  centerGoal = center and 1 or 0
  if first then
    ApplyCenter(centerGoal)
  end
  centerName:SetShown(aim >= 1)
  if aim >= 1 and aim <= n then
    selTarget = CM.RadialSlotAngle(aim, n)
    selGoal = HIGHLIGHT_ALPHA
    if not selAngle then
      -- Coming from the centre: appear on the slice and fade in.
      selAngle = selTarget
      selAlpha = 0
      sel:SetAlpha(0)
    end
    PlaceOverlayAt(sel, "sel", n, selAngle)
  else
    -- Leaving the ring: fade out where it is (the update hides it once invisible).
    selGoal = 0
    if not selAngle then
      sel:Hide()
    end
  end
  local k, _, entries = CM.RadialCurrent()
  local entry = aim >= 1 and entries[aim] or nil
  local unusable = entry and SliceUnusable(entry)
  -- A slice that can't be used right now (combat lockdown, cooldown, no group...) highlights grey.
  if unusable then
    sel:SetVertexColor(0.6, 0.6, 0.6)
  else
    sel:SetVertexColor(CM.RadialWheelColor(k))
  end
  local name = entry and CM.RadialEntryInfo(entry) or nil
  SetAbbreviated(centerAim, name, AIM_WIDTH)
  local r, g, b = AimColor(entry)
  if unusable then
    r, g, b = 0.6, 0.6, 0.6
  end
  centerAim:SetTextColor(r, g, b, 1)
  local accent = CM.UI and CM.UI.Colors and CM.UI.Colors.accent or { 0.816, 0.541, 0.322 }
  centerName:SetTextColor(accent[1], accent[2], accent[3], 1)
  -- Slot art: the aimed usable slice lights up (brown disc + glow ring), unusable ones go grey.
  for i = 1, n do
    local slot = slots[i]
    if slot.unusable then
      slot.SetSlotState("disabled")
    elseif i == aim then
      slot.SetSlotState("selected")
    else
      slot.SetSlotState("normal")
    end
  end
end

local function PlaceOverlay(tex, kind, n, i)
  PlaceOverlayAt(tex, kind, n, CM.RadialSlotAngle(i, n))
end

local function Paint()
  Build()
  if not view then
    return
  end
  local k, total, entries, wheel = CM.RadialCurrent()
  local n = #entries
  lastCount = n
  if n < 1 then
    bg:Hide()
    CM.RadialPlaceDividers(dividers, view, 0, 1)
    backdrop:Hide()
    sel:Hide()
    for i = 1, LAYOUT.MAX_SLICES do
      slots[i]:Hide()
      offs[i]:Hide()
    end
    centerName:SetText("")
    centerAim:SetText("")
    PaintPips(0, 0)
    return
  end
  if lastPage and lastPage ~= k and openProgress >= 1 then
    swapProgress = 0
    ApplySwap(0)
    PlayRadialSound("page")
  end
  lastPage = k
  CM.RadialPaintBackground(bg, n, 1)
  CM.RadialPlaceDividers(dividers, view, n, 1)
  bg:Show()
  backdrop:Show()
  for i = 1, LAYOUT.MAX_SLICES do
    local slot = slots[i]
    local entry = entries[i]
    if i <= n and entry then
      local dx, dy = CM.RadialSlotDir(i, n)
      slot.px, slot.py = LAYOUT.ICON_RADIUS * dx, LAYOUT.ICON_RADIUS * dy
      PlaceSlot(slot)
      local _, icon, iconText, art = CM.RadialEntryInfo(entry)
      CM.RadialSetIcon(slot.icon, icon, slot.iconLabel, iconText)
      slot.SetSlotArt(art)
      PaintCooldown(slot, entry)
      local unusable = SliceUnusable(entry)
      slot.unusable = unusable
      if entry.kind == "item" then
        local count = ItemCount(entry.id)
        slot.count:SetText(count > 1 and count or "")
      else
        slot.count:SetText("")
      end
      slot.icon:SetDesaturated(unusable)
      if unusable then
        PlaceOverlay(offs[i], "off", n, i)
      else
        offs[i]:Hide()
      end
      slot:Show()
    else
      slot:Hide()
      offs[i]:Hide()
    end
  end
  centerName:SetText(wheel and CM.RadialWheelName(wheel, k) or "")
  PaintPips(k, total)
  Highlight(CM.RadialAimSlot(), n)
end

--- Repaint when open (page turned, cooldown / bag events, store finished).
function CM.RadialViewRefresh()
  if CM.IsRadialMenuOpen and CM.IsRadialMenuOpen() then
    Paint()
  end
end

--- Called by the façade when the wheel is shown / hidden.
function CM.RadialViewShown()
  Build()
  if not view then
    return
  end
  lastAim = -1
  selAngle = nil
  lastPage = nil
  PlayRadialSound("open")
  swapProgress = 1
  swapScale = 1
  for i = 1, LAYOUT.MAX_SLICES do
    slots[i]:SetAlpha(1)
  end
  centerName:SetAlpha(1)
  for i = 1, #pips do
    pips[i].mix = nil
  end
  -- Opening: fade in while growing from OPEN_START_SCALE (Blizzard's gamepad radial feel).
  openProgress = 0
  view:SetAlpha(0)
  view:SetScale(OPEN_START_SCALE)
  for i = 1, LAYOUT.MAX_SLICES do
    slots[i].scale = 1
  end
  Paint()
  view:SetScript("OnUpdate", function(_, elapsed)
    local aim = CM.RadialAimSlot()
    if aim ~= lastAim then
      Highlight(aim, lastCount)
    end
    if openProgress < 1 then
      openProgress = math.min(1, openProgress + elapsed / OPEN_DURATION)
      local eased = 1 - (1 - openProgress) ^ 3
      view:SetAlpha(eased)
      view:SetScale(OPEN_START_SCALE + (1 - OPEN_START_SCALE) * eased)
    end
    if swapProgress < 1 then
      swapProgress = math.min(1, swapProgress + elapsed / SWAP_DURATION)
      ApplySwap(1 - (1 - swapProgress) ^ 3)
    end
    for i = 1, #pips do
      local pip = pips[i]
      if pip.mix and pip.mix ~= pip.goal then
        local mix = pip.mix + (pip.goal - pip.mix) * math.min(1, elapsed * SEL_SPEED)
        PaintPipMix(pip, math.abs(pip.goal - mix) < HOVER_SETTLE and pip.goal or mix)
      end
    end
    if centerMix ~= centerGoal then
      local mix = centerMix + (centerGoal - centerMix) * math.min(1, elapsed * SEL_SPEED)
      ApplyCenter(math.abs(centerGoal - mix) < HOVER_SETTLE and centerGoal or mix)
    end
    if selAngle and selAngle ~= selTarget then
      local twoPi = 2 * math.pi
      local delta = (selTarget - selAngle + math.pi) % twoPi - math.pi
      if math.abs(delta) < 0.002 then
        selAngle = selTarget
      else
        selAngle = selAngle + delta * math.min(1, elapsed * SEL_SPEED)
      end
      PlaceOverlayAt(sel, "sel", lastCount, selAngle)
    end
    if selAlpha ~= selGoal and sel:IsShown() then
      selAlpha = selAlpha + (selGoal - selAlpha) * math.min(1, elapsed * SEL_SPEED)
      if math.abs(selGoal - selAlpha) < HOVER_SETTLE then
        selAlpha = selGoal
      end
      sel:SetAlpha(selAlpha)
      if selAlpha == 0 then
        sel:Hide()
        selAngle = nil
      end
    end
    -- The aimed slice grows, the rest settle back; only slots still moving are touched.
    for i = 1, lastCount do
      local slot = slots[i]
      -- Unusable (disabled) slices never grow.
      local target = (i == aim and not slot.unusable) and HOVER_SCALE or 1
      if slot.scale ~= target then
        slot.scale = slot.scale + (target - slot.scale) * math.min(1, elapsed * HOVER_SPEED)
        if math.abs(target - slot.scale) < HOVER_SETTLE then
          slot.scale = target
        end
        PlaceSlot(slot)
      end
    end
  end)
end

function CM.RadialViewHidden()
  if view then
    view:SetScript("OnUpdate", nil)
  end
  -- Released over a usable slice = used it; Esc, the centre or a greyed slice = just closed.
  local entry
  if lastAim >= 1 and not IsKeyDown("ESCAPE") then
    local _, _, entries = CM.RadialCurrent()
    entry = entries[lastAim]
  end
  if entry and not SliceUnusable(entry) then
    PlayRadialSound("confirm")
  else
    PlayRadialSound("close")
  end
end
