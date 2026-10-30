---------------------------------------------------------------------------------------
--  Core/RadialMenu/View.lua — RADIALMENU — wheel drawing: art, icons, aim highlight
---------------------------------------------------------------------------------------
--  What it does: Draws the open Radial Menu / Party Wheel on a plain child frame of the secure
--  wheel: the background art for the slice count, round icon slots with cooldown / count, the
--  highlight on the slice the cursor points at, the wheel name and the wheel page dots.
--  Architecture / how it works:
--    • Art is Assets/radial/radial_[minimal_]{bg,sel,off}_N.tga (N = slice count 1..8); which set,
--      its size and overlay placement come from CM.RadialStyle() (global.radialStyle: Forever /
--      Minimal). Minimal draws one radial_minimal_bg.tga plus a prerendered radial_minimal_div_N.tga
--      (Data.lua helpers), both 1:1 so nothing is resampled. The sel / off textures are slice 1
--      only (sel white, tinted per wheel), moved and rotated per slice.
--    • Paint() rebuilds from CM.RadialCurrent() (page change, show, cooldown / bag events);
--      OnUpdate only compares CM.RadialAimSlot() and re-highlights when the aim changes.
--    • OnUpdate also animates: a short fade / grow on open and a scale-up on the aimed slice.
--    • Quiet Blizzard UI sounds (SOUNDKIT) on open, close, aiming a new slice (throttled), turning a
--      page, and releasing over a usable slice (Esc / centre / greyed slice = the close sound).
--    • Never writes secure state; the child frame is insecure, so it can be updated in combat.
--    • Two sources share the one view (SOURCES): the Radial Menu and the Party Wheel
--      (PartyWheel.lua). CM.RadialViewShown(kind) re-parents it to that wheel.
--    • Party entries ({ kind = "unit" }) draw the member's portrait (class circle icon in a raid,
--      IsRaidGroup; no cooldown, the centre shows it; inner black shadow, SetInnerShadow) and a
--      unit plate: a health ring (radial_health_{ring,fill,half,spark}.tga) as the portrait's
--      border (SetSlotRing), the role icon on its bottom notch, the raid marker on its top and the
--      class-coloured first name under it (AllyCycleTarget.GetDisplayName; "Dead" / "Offline").
--    • The ring's fill is two halves behind rotating half-plane masks. Secret health (instances)
--      turns them through UnitHealthPercent curves (SetRotation takes secrets, SetCooldown does
--      not) and steps; public health is plain math and eases toward each reading. Repainted on
--      that unit's UNIT_HEALTH / UNIT_MAXHEALTH (view-local events while the wheel is open) and
--      every HEALTH_INTERVAL (range, dead, offline).
--    • Ally HUD parity: out-of-range members dimmed (AllyCycleTarget.GetRangeAlpha), the low-HP
--      pulsing glow (AllyCycleHealthBar.GetGlowColor / GlowPulseAlpha; alpha may be secret),
--      offline members desaturated and unselectable. The aimed wedge takes the member's class colour.
--    • The Party Wheel centre is a circle slot with the spell's icon + cooldown and the Assist
--      HUD's breathing glow and proc FlipBook (AssistedHighlightMotion), swapped (SetCenterAim) for
--      your own unit plate while the cursor rests there (it casts, so no cancel X).
--  Does not: Decide what a slice does, store wheels, or bind keys (Secure.lua / Data.lua).
--  Related: Core/RadialMenu/{Data,Secure,PartyWheel,RadialMenu}.lua,
--  Core/AllyCycle/{HealthBar,Target}.lua,
--  Core/Crosshair/AssistedHighlight/Motion.lua,
--  Core/Runtime/EventRouter.lua,
--  Constants/Gameplay.lua (RADIAL_MENU_EVENTS), Constants/Atlas.lua (CircleMaskScalable)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_Item = _G.C_Item
local C_Spell = _G.C_Spell
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local IsInRaid = _G.IsInRaid
local IsKeyDown = _G.IsKeyDown
local IsMouseButtonDown = _G.IsMouseButtonDown
local PlaySound = _G.PlaySound
local UnitClass = _G.UnitClass
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitHealthPercent = _G.UnitHealthPercent
local CreateCurve = _G.C_CurveUtil and _G.C_CurveUtil.CreateCurve

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
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
-- Party Wheel centre: a circle slot with the spell's icon, or your portrait while the
-- cursor rests in the centre (releasing there casts with the normal targeting).
local centerSlot
local centerSpell
local centerPlate = false -- the centre slot shows your unit plate (page dots move below it)
-- Party Wheel centre spell icon effects, as on the Assist HUD (AssistedHighlight/Motion.lua):
-- breathing inner glow (Assist HUD cyan) + the proc FlipBook (its own blue art, untinted) played
-- once in reverse per open / spell change.
local centerFx
local centerFxSpell
local centerFxPhase = 0
-- Glow size per px of visible icon, as on the Assist HUD (Assist.lua): a 40 px icon with a 56 px
-- shell; its Delve mask is 0.85 * 56 across and shows a 39/64 circle, under a 0.9 * 56 glow (unmasked,
-- its bright rim just outside the visible icon). Our icon shows a 58/64 circle (CircleMaskScalable).
local CENTRE_FX_GLOW_PER_VISIBLE = 0.9 / (0.85 * 39 / 64)
local CENTRE_ICON_VISIBLE = 58 / 64
-- Party Wheel portraits and the centre spell icon: an inner black shadow, the Assist HUD glow
-- (spell-glow.blp: opaque out to 160 of 256 px) tinted black, that opaque edge INNER_SHADOW_SCALE
-- times the icon so the dark band fills out to the frame; the icon's circle mask trims the rest.
local INNER_SHADOW_RIM = 160 / 256
local INNER_SHADOW_SCALE = 1.15
local INNER_SHADOW_ALPHA = 0.85
local CENTRE_FX_PROC_FILL = 60 / 86 -- PROC_ATLAS frames: the slash spans ~60 of 86 px
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
-- Party Wheel centre, spell icon <-> your portrait: shrink and fade out, swap at the midpoint, grow
-- back in. centerSwapT runs 0..1 (1 = idle); centerShownAim is what the slot shows now.
local CENTRE_SWAP_DURATION = 0.18
local CENTRE_SWAP_SCALE = 0.7
local centerSwapT = 1
local centerShownAim
local centerSwapTo
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
local lastLeftCentre -- Party Wheel: CM.PartyWheelLeftCentre() as last painted
local lastCount = 0

-- What the view draws: the Radial Menu, or the Party Wheel (PartyWheel.lua). Both share this one
-- view; it is re-parented to whichever wheel opened. Current() = k, total, entries, title.
local SOURCES = {
  radial = {
    Frame = function()
      return CM.RadialGetWheelFrame and CM.RadialGetWheelFrame()
    end,
    Current = function()
      local k, total, entries, wheel = CM.RadialCurrent()
      return k, total, entries, wheel and CM.RadialWheelName(wheel, k) or ""
    end,
    Aim = function()
      return CM.RadialAimSlot()
    end,
    centreCloses = true,
  },
  party = {
    Frame = function()
      return CM.PartyWheelGetFrame and CM.PartyWheelGetFrame()
    end,
    Current = function()
      return CM.PartyWheelCurrent()
    end,
    Aim = function()
      return CM.PartyWheelAimSlot()
    end,
    LeftCentre = function()
      return CM.PartyWheelLeftCentre()
    end,
    -- Releasing in the centre casts with the normal targeting, so it is not a cancel.
    centreCloses = false,
    -- The centre holds a circle slot instead of text, so the page dots sit below it.
    pipY = -38,
    -- ...and further down while the centre shows your unit plate (its name ends ~52 below).
    pipPlateY = -64,
  },
}
local source = SOURCES.radial
-- Party Wheel unit plate: a health ring around the portrait, the role icon on its bottom notch and
-- the name under that.
-- The ring art's 96 px; its inner edge (68 / 96) sits on the slot's border. Keep RING_SIZE * 4 / 3
-- a whole even number so the canvas and both fill halves land on whole pixels.
local RING_SIZE = 66
local RING_ICON = math.floor(RING_SIZE * 70 / 96) -- portrait fills the ring's opening, edge under the frame
-- 12 o'clock: a mask edge lying on a half's own edge (the canvas centre line) fades that column,
-- a faint line where the halves meet. Past 50% the left mask turns RING_TOP_OVERSHOOT radians
-- further (over RING_TOP_RAMP of health) and the right one stops that short of 0, so at the top
-- only the halves' crisp texture edges meet; the sliver this costs is at 6 o'clock, under the role
-- icon. (No patch over the line: the plate's range alpha applies per texture, so any overlap shows
-- brighter.)
local RING_TOP_OVERSHOOT = 0.04
local RING_TOP_RAMP = 0.02
local RING_SPARK_EDGE = 0.01 -- spark fades out this close to empty / full
-- Health changes ease in (exponential approach, about the Ally HUD bar's ExponentialEaseOut).
local RING_EASE_SPEED = 8
local RING_EASE_SETTLE = 0.0005
local RING_CANVAS_SCALE = 128 / 96 -- ring TGAs are the 96 px art centred on a 128 canvas
local RING_ROLE_INSET = 5 -- role icon centre, up from the ring's bottom edge
local PLATE_Y = -1 -- gap between the role icon and the name
local PLATE_WIDTH = 96 -- name width (adjacent slices of 8 are ~113 px apart)
local PLATE_NAME_SIZE = 11
local PLATE_ROLE_SIZE = 20
local HEALTH_INTERVAL = 0.2 -- seconds between health repaints while the Party Wheel is open
local RANGE_ALPHA = 0.4 -- out-of-range members' portrait and plate
local OFFLINE_TEXT = _G.PLAYER_OFFLINE or "Offline" -- replaces an offline member's name
local DEAD_TEXT = _G.DEAD or "Dead" -- replaces a dead member's name
local PLATE_MARKER_SIZE = 18 -- raid marker on the ring's top
local LOW_GLOW_SIZE = RING_SIZE * 2 -- the slot's selected-glow art at the ring's own glow size
local healthElapsed = 0
local lowGlowPhase = 0
local PaintHealthRing -- defined with the unit plate

local function Wheel()
  return source.Frame()
end

-- May be secret (UnitInRange): only ever handed to SetAlpha.
local function MemberRangeAlpha(unit)
  return CM.AllyCycleTarget.GetRangeAlpha(unit, false, RANGE_ALPHA)
end

-- Raids show class icons instead of portraits (many small faces read worse than class at a glance).
local function IsRaidGroup()
  return IsInRaid and IsInRaid() and true or false
end

-- Class circle icon for a class token; false when it can't be drawn (secret / unknown class).
local function SetClassIcon(icon, classFile)
  if issecretvalue and issecretvalue(classFile) then
    return false
  end
  local coords = type(classFile) == "string"
    and _G.CLASS_ICON_TCOORDS
    and _G.CLASS_ICON_TCOORDS[classFile]
  if not coords then
    return false
  end
  icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
  icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  return true
end

-- Portrait: the unit's 2D portrait in a party, its class circle icon in a raid (the portrait
-- when the class can't be read).
local function SetMemberPortrait(icon, unit)
  if IsRaidGroup() and SetClassIcon(icon, select(2, UnitClass(unit))) then
    return
  end
  icon:SetTexCoord(0, 1, 0, 1)
  _G.SetPortraitTexture(icon, unit)
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

  -- Over the icon (same frame, so the icon's circle mask clips it), under the cooldown.
  local shadow = slot:CreateTexture(nil, "ARTWORK", nil, 1)
  if
    not pcall(shadow.SetTexture, shadow, CM.Constants.AssistedSpellIconGlow, nil, nil, "TRILINEAR")
  then
    shadow:SetTexture(CM.Constants.AssistedSpellIconGlow)
  end
  shadow:SetVertexColor(0, 0, 0, INNER_SHADOW_ALPHA)
  shadow:SetPoint("CENTER", slot.icon, "CENTER")
  shadow:AddMaskTexture(slot.iconMask)
  shadow:Hide()
  slot.innerShadow = shadow

  slot.index = index
  slot.scale = 1
  slot.px, slot.py = 0, 0
  return slot
end

--- Shows the inner shadow sized to the slot's current icon (call after SetSlotRing), or hides it.
local function SetInnerShadow(slot, shown)
  local shadow = slot.innerShadow
  if shown then
    local size = slot.icon:GetWidth() * INNER_SHADOW_SCALE / INNER_SHADOW_RIM
    shadow:SetSize(size, size)
  end
  shadow:SetShown(shown)
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

  centerSlot = CreateSlot(view, 0)
  centerSlot:SetPoint("CENTER")
  centerSlot:Hide()

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
    local y = centerPlate and source.pipPlateY or source.pipY or PIP_Y
    pip:ClearAllPoints()
    pip:SetPoint("CENTER", view, "CENTER", pip.px / scale, y / scale)
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
    elseif entry.kind == "unit" then
      -- Party Wheel: a left / missing / offline member can't be cast on (dead ones can: resurrections).
      unusable = not _G.UnitExists(entry.unit) or entry.offline or false
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
    local spellId = entry.kind == "spell" and entry.id or (entry.kind == "unit" and entry.spell)
    if spellId and C_Spell and C_Spell.GetSpellCooldown then
      -- Values may be secret in combat: handed straight to the Cooldown widget, never compared.
      local info = C_Spell.GetSpellCooldown(spellId)
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

-- Health ring fill: radial_health_fill.tga in two halves (left = first half of health, clockwise
-- from the bottom; right = second half). Each half is masked by radial_health_half.tga (a half-plane:
-- right half opaque, CLAMP so any rotation still covers the canvas) rotated about the ring's centre.
-- Health can be secret and Cooldown:SetCooldown rejects secrets from addon code, but
-- Texture:SetRotation takes them: numeric curves map health % straight to each mask's angle, so
-- health never meets Lua math. Negative radians turn clockwise.
local RING_CURVE_POINTS = {
  -- left half: the mask turns 0 -> -pi over the first half of health, then RING_TOP_OVERSHOOT on.
  left = {
    { 0, 0 },
    { 0.5, -math.pi },
    { 0.5 + RING_TOP_RAMP, -math.pi - RING_TOP_OVERSHOOT },
    { 1, -math.pi - RING_TOP_OVERSHOOT },
  },
  -- right half: the mask starts flipped (pi) and turns pi -> RING_TOP_OVERSHOOT over the second half.
  right = { { 0, math.pi }, { 0.5, math.pi }, { 1, RING_TOP_OVERSHOOT } },
  -- spark at the fill's edge: drawn at the bottom, turned the whole sweep (0 -> -2pi); its alpha
  -- fades out within RING_SPARK_EDGE of empty or full.
  spark = { { 0, 0 }, { 1, -2 * math.pi } },
  sparkAlpha = { { 0, 0 }, { RING_SPARK_EDGE, 1 }, { 1 - RING_SPARK_EDGE, 1 }, { 1, 0 } },
}
local ringCurves

local function RingCurves()
  if ringCurves == nil then
    ringCurves = false
    if CreateCurve and UnitHealthPercent then
      ringCurves = {}
      for side, points in pairs(RING_CURVE_POINTS) do
        local curve = CreateCurve()
        for _, p in ipairs(points) do
          curve:AddPoint(p[1], p[2])
        end
        ringCurves[side] = curve
      end
    end
  end
  return ringCurves or nil
end

-- Health 0..1 as a public number, or nil while it is secret (then only the curves can draw it).
local function PublicHealthPct(unit)
  local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
  if issecretvalue and (issecretvalue(health) or issecretvalue(maxHealth)) then
    return nil
  end
  if type(health) == "number" and type(maxHealth) == "number" and maxHealth > 0 then
    return math.max(0, math.min(1, health / maxHealth))
  end
  return 0
end

-- Mask angles, spark angle and alpha for a public health fraction (same shapes as the curves).
local function RingAnglesFromPct(pct)
  local topTurn = math.max(0, math.min(1, (pct - 0.5) / RING_TOP_RAMP))
  return -math.min(pct, 0.5) * 2 * math.pi - RING_TOP_OVERSHOOT * topTurn,
    math.pi - math.max(pct - 0.5, 0) * 2 * (math.pi - RING_TOP_OVERSHOOT),
    -pct * 2 * math.pi,
    math.max(0, math.min(1, pct / RING_SPARK_EDGE, (1 - pct) / RING_SPARK_EDGE))
end

-- Draws the ring. The angles and colour may be secret (curves): only passed to widget setters.
local function ApplyRing(plate, left, right, spark, sparkAlpha, r, g, b, a)
  plate.maskL:SetRotation(left)
  plate.maskR:SetRotation(right)
  plate.spark:SetRotation(spark)
  plate.spark:SetAlpha(sparkAlpha)
  -- The fill TGA is grey (shaded darker on the left, lighter on the right), tinted with the health colour.
  -- Offline: the Ally HUD bar's offline look, the dead colour desaturated (its edge spark is
  -- hidden by PaintHealthRing).
  local offline = plate.offline or false
  if offline then
    r, g, b, a = CM.AllyCycleHealthBar.GetDeadColor()
  end
  plate.fillL:SetDesaturated(offline)
  plate.fillR:SetDesaturated(offline)
  if r then
    plate.fillL:SetVertexColor(r, g, b, a)
    plate.fillR:SetVertexColor(r, g, b, a)
  end
end

-- The ring at the shown (eased) health: angles and the Ally HUD bar's colour for that health.
local function ApplyRingPct(plate, pct)
  local left, right, spark, sparkAlpha = RingAnglesFromPct(pct)
  local r, g, b, a = CM.AllyCycleHealthBar.GetFillColor(nil, pct)
  ApplyRing(plate, left, right, spark, sparkAlpha, r, g, b, a)
end

--- Reads the unit's health (every HEALTH_INTERVAL) and draws its ring. Public health becomes the
--- goal the ring eases to (StepHealthRing, like the Ally HUD bar's interpolation); a new unit or
--- a fresh open (shownPct nil) starts on it. Secret health (instances) can't be eased from addon
--- code (curves only evaluate secrets when untainted), so the ring is drawn by curves and steps.
function PaintHealthRing(slot, unit)
  local plate = slot.plate
  local dead = CM.AllyCycleTarget.IsDead(unit)
  plate.offline = CM.AllyCycleTarget.IsOffline(unit)
  slot.applyDead(dead)
  -- Out of range dims the portrait and its plate (refreshed with the health).
  local alpha = MemberRangeAlpha(unit)
  slot.icon:SetAlpha(alpha)
  slot.innerShadow:SetAlpha(alpha)
  plate:SetAlpha(alpha)
  local shown = false
  local pct = not dead and PublicHealthPct(unit) or nil
  plate.goalPct = pct
  if pct then
    shown = true
    if plate.shownPct == nil then
      plate.shownPct = pct
    end
    ApplyRingPct(plate, plate.shownPct)
  else
    plate.shownPct = nil
    local curves = not dead and RingCurves()
    if curves then
      shown = true
      local r, g, b, a = CM.AllyCycleHealthBar.GetFillColor(unit)
      ApplyRing(
        plate,
        UnitHealthPercent(unit, true, curves.left),
        UnitHealthPercent(unit, true, curves.right),
        UnitHealthPercent(unit, true, curves.spark),
        UnitHealthPercent(unit, true, curves.sparkAlpha),
        r,
        g,
        b,
        a
      )
    end
  end
  plate.fillL:SetShown(shown)
  plate.fillR:SetShown(shown)
  plate.spark:SetShown(shown and not plate.offline)
  -- Ally HUD parity: the low-HP glow (its curve's alpha may be secret: vertex colour only; the
  -- pulse is its holder frame's alpha, stepped in OnUpdate) and the raid marker.
  local grey = dead or plate.offline
  if grey then
    plate.lowGlow:Hide()
  else
    local HealthBar = CM.AllyCycleHealthBar
    local r, g, b, a = HealthBar.GetGlowColor(unit)
    plate.lowGlow:SetVertexColor(r, g, b, a)
    plate.lowGlowFrame:SetAlpha(HealthBar.GlowPulseAlpha(lowGlowPhase))
    plate.lowGlow:Show()
  end
  local Target = CM.AllyCycleTarget
  local hasMarker = Target.ApplyRaidMarker(plate.marker, Target.GetRaidTargetIndex(unit))
  plate.marker:SetShown(hasMarker)
  plate.marker:SetDesaturated(grey or false)
end

--- The low-HP glows' shared pulse (every frame while the Party Wheel is open).
local function StepLowGlows(elapsed)
  local HealthBar = CM.AllyCycleHealthBar
  lowGlowPhase = (lowGlowPhase + elapsed / HealthBar.GetGlowPeriod()) % 1
  local alpha = HealthBar.GlowPulseAlpha(lowGlowPhase)
  for i = 1, lastCount do
    local plate = slots[i].plate
    if plate and plate:IsShown() then
      plate.lowGlowFrame:SetAlpha(alpha)
    end
  end
  if centerSlot and centerSlot.plate then
    centerSlot.plate.lowGlowFrame:SetAlpha(alpha)
  end
end

--- Eases each shown ring toward its goal health (every frame while the Party Wheel is open).
local function StepHealthRing(slot, elapsed)
  local plate = slot.plate
  local goal, shownPct = plate and plate.goalPct, plate and plate.shownPct
  if not goal or not shownPct or shownPct == goal or not plate:IsShown() then
    return
  end
  shownPct = shownPct + (goal - shownPct) * math.min(1, elapsed * RING_EASE_SPEED)
  if math.abs(goal - shownPct) < RING_EASE_SETTLE then
    shownPct = goal
  end
  plate.shownPct = shownPct
  ApplyRingPct(plate, shownPct)
end

--- UNIT_HEALTH / UNIT_MAXHEALTH while the Party Wheel is open: repaints that member's ring at
--- once (the HEALTH_INTERVAL loop alone would leave it up to 0.2 s behind, which shows as steps
--- where health is secret and can't be eased). The loop still refreshes range / dead state.
local function OnHealthEvent(_, _, unit)
  if type(unit) ~= "string" or (issecretvalue and issecretvalue(unit)) then
    return
  end
  for i = 1, lastCount do
    local slot = slots[i]
    local plate = slot.plate
    if plate and plate:IsShown() and plate.unit == unit then
      PaintHealthRing(slot, unit)
    end
  end
  if centerPlate and unit == "player" then
    PaintHealthRing(centerSlot, "player")
  end
end

local HEALTH_EVENTS = { "UNIT_HEALTH", "UNIT_MAXHEALTH" }

-- Health events are only wanted while the Party Wheel is open.
local function SetHealthEvents(on)
  for _, event in ipairs(HEALTH_EVENTS) do
    if on then
      view:RegisterEvent(event)
    else
      view:UnregisterEvent(event)
    end
  end
  view:SetScript("OnEvent", on and OnHealthEvent or nil)
end

-- One half of the fill art (u0..u1 of the canvas) with its own rotating half-plane mask.
local function BuildRingHalf(plate, u0, u1, point)
  local fill = plate:CreateTexture(nil, "ARTWORK", nil, 1)
  fill:SetTexture(ART_PATH .. "health_fill.tga")
  fill:SetTexCoord(u0, u1, 0, 1)
  fill:SetPoint("TOP" .. point, plate, "TOP" .. point)
  fill:SetPoint("BOTTOM" .. point, plate, "BOTTOM" .. point)
  fill:SetWidth(plate:GetWidth() / 2)
  local mask = plate:CreateMaskTexture()
  mask:SetTexture(ART_PATH .. "health_half.tga", "CLAMP", "CLAMP")
  mask:SetAllPoints(plate)
  fill:AddMaskTexture(mask)
  fill:Hide()
  return fill, mask
end

-- Party Wheel: the unit plate around the portrait: the health ring (radial_health_ring.tga frame,
-- masked fill halves on top, inside its channel, in the art's own colours), the role icon on the
-- ring's bottom notch and the class-coloured name under it
-- (names come from AllyCycleTarget.GetDisplayName). Dead / offline members grey out through applyDead,
-- their name replaced with "Dead" / "Offline".
local function BuildPlate(slot)
  local canvas = RING_SIZE * RING_CANVAS_SCALE
  local plate = CreateFrame("Frame", nil, slot)
  plate:SetSize(canvas, canvas)
  plate:SetPoint("CENTER", slot, "CENTER", 0, 0)
  -- Above the chrome's `over` frame (+6), so the aimed glow sits behind the ring.
  plate:SetFrameLevel(slot:GetFrameLevel() + 7)
  -- Low HP: the Ally HUD bar's red pulsing glow, as the slot's glow art around the ring.
  -- A texture's SetAlpha is its vertex alpha, so the pulse goes on a holder frame (as in HealthBar)
  -- and the curve's 0 / 1 (maybe secret) stays in the vertex colour.
  plate.lowGlowFrame = CreateFrame("Frame", nil, plate)
  plate.lowGlowFrame:SetAllPoints()
  plate.lowGlowFrame:SetFrameLevel(plate:GetFrameLevel() - 1) -- behind the ring, like the aimed glow
  plate.lowGlow = plate.lowGlowFrame:CreateTexture(nil, "BACKGROUND")
  plate.lowGlow:SetTexture(ART_PATH .. "slot_border_selected.tga")
  plate.lowGlow:SetDesaturated(true)
  plate.lowGlow:SetBlendMode("ADD")
  plate.lowGlow:SetSize(LOW_GLOW_SIZE, LOW_GLOW_SIZE)
  plate.lowGlow:SetPoint("CENTER")
  plate.lowGlow:Hide()
  plate.ring = plate:CreateTexture(nil, "ARTWORK")
  plate.ring:SetTexture(ART_PATH .. "health_ring.tga")
  plate.ring:SetAllPoints()
  plate.fillL, plate.maskL = BuildRingHalf(plate, 0, 0.5, "LEFT")
  plate.fillR, plate.maskR = BuildRingHalf(plate, 0.5, 1, "RIGHT")
  -- The spark TGA is the Ally HUD bar's widgetstatusbar-spark standing across the band's bottom
  -- (where the fill starts), 1.5x the bar's proportions (6 px wide, band + 4 px tall on screen)
  -- on the band's middle, turned with the sweep.
  plate.spark = plate:CreateTexture(nil, "ARTWORK", nil, 3)
  plate.spark:SetTexture(ART_PATH .. "health_spark.tga", "CLAMP", "CLAMP")
  plate.spark:SetBlendMode("ADD")
  plate.spark:SetAllPoints()
  plate.spark:Hide()
  local top = CreateFrame("Frame", nil, plate)
  top:SetAllPoints()
  top:SetFrameLevel(plate:GetFrameLevel() + 2)
  plate.role = top:CreateTexture(nil, "OVERLAY")
  plate.role:SetSize(PLATE_ROLE_SIZE, PLATE_ROLE_SIZE)
  plate.role:SetPoint("CENTER", plate, "CENTER", 0, -RING_SIZE / 2 + RING_ROLE_INSET)
  -- Raid marker on the ring's top, mirroring the role icon at the bottom.
  plate.marker = top:CreateTexture(nil, "OVERLAY")
  plate.marker:SetSize(PLATE_MARKER_SIZE, PLATE_MARKER_SIZE)
  plate.marker:SetPoint("CENTER", plate, "CENTER", 0, RING_SIZE / 2 - RING_ROLE_INSET)
  plate.marker:Hide()
  plate.name = top:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  plate.name:SetPoint("TOP", plate.role, "BOTTOM", 0, PLATE_Y)
  plate.name:SetWidth(PLATE_WIDTH)
  plate.name:SetJustifyH("CENTER")
  plate.name:SetWordWrap(false)
  if CM.SetFontStringFromTemplate then
    CM.SetFontStringFromTemplate(plate.name, PLATE_NAME_SIZE, _G.GameFontNormalSmall)
  end
  if CM.ApplyOutlineSlug then
    CM.ApplyOutlineSlug(plate.name)
  end
  slot.plate = plate
  -- Dead or offline (plate.offline, set first by PaintHealthRing): portrait, ring, role and name grey.
  slot.applyDead = function(dead)
    slot.dead = dead
    local grey = dead or plate.offline or false
    slot.icon:SetDesaturated(grey or slot.unusable or false)
    plate.role:SetDesaturated(grey)
    plate.ring:SetDesaturated(grey)
    if grey then
      plate.name:SetTextColor(0.55, 0.55, 0.55, 1)
    else
      plate.name:SetTextColor(plate.r or 1, plate.g or 1, plate.b or 1, 1)
    end
    -- The name gives way to the state (Blizzard's localized strings); displayName may be secret,
    -- so it only ever goes to SetText.
    if plate.offline then
      plate.name:SetText(OFFLINE_TEXT)
    elseif dead then
      plate.name:SetText(DEAD_TEXT)
    else
      plate.name:SetText(plate.displayName)
    end
  end
end

local function PaintUnitPlate(slot, unit)
  local Target = CM.AllyCycleTarget
  if not CM.AllyCycleHealthBar or not Target then
    return
  end
  if not slot.plate then
    BuildPlate(slot)
  end
  local plate = slot.plate
  plate.displayName = Target.GetDisplayName(unit)
  plate.name:SetText(plate.displayName)
  plate.r, plate.g, plate.b = Target.GetClassRGB(unit)
  plate.name:SetTextColor(plate.r, plate.g, plate.b, 1)
  local atlas = Target.GetRoleAtlas(unit)
  if atlas then
    CM.SetAtlas(plate.role, atlas)
    plate.role:Show()
  else
    plate.role:Hide()
  end
  -- A new unit, or a plate shown again (the centre's), starts on the health instead of easing.
  if plate.unit ~= unit or not plate:IsShown() then
    plate.shownPct = nil
  end
  plate.unit = unit
  plate:Show()
  PaintHealthRing(slot, unit)
end

-- Page dots follow the centre plate: re-anchor them when it comes or goes.
local function SetCenterPlate(shown)
  if centerPlate == shown then
    return
  end
  centerPlate = shown
  for _, pip in ipairs(pips) do
    if pip:IsShown() then
      PaintPipMix(pip, pip.mix or 0)
    end
  end
end

-- Builds the centre's glow (fx frame, over the icon and its cooldown, under the slot border) and
-- the proc FlipBook (on the chrome's `over` frame, above the border). The glow keeps the Assist
-- HUD's proportions to the visible icon; the slash reaches the slot border.
local function BuildCenterFx()
  local Motion = CM.AssistedHighlightMotion
  if centerFx or not Motion then
    return centerFx
  end
  local icon = centerSlot.icon
  local glowSize = icon:GetWidth() * CENTRE_ICON_VISIBLE * CENTRE_FX_GLOW_PER_VISIBLE
  local procSize = centerSlot:GetWidth() / CENTRE_FX_PROC_FILL
  centerFx = CreateFrame("Frame", nil, centerSlot)
  centerFx:SetAllPoints()
  centerFx:SetFrameLevel(centerSlot:GetFrameLevel() + 3)
  local glow = centerFx:CreateTexture(nil, "ARTWORK")
  if
    not pcall(glow.SetTexture, glow, CM.Constants.AssistedSpellIconGlow, nil, nil, "TRILINEAR")
  then
    glow:SetTexture(CM.Constants.AssistedSpellIconGlow)
  end
  glow:SetSize(glowSize, glowSize)
  glow:SetPoint("CENTER", icon, "CENTER")
  glow:SetVertexColor(Motion.ASSIST_COLOR_R, Motion.ASSIST_COLOR_G, Motion.ASSIST_COLOR_B, 1)
  centerFx.glow = glow
  local proc = centerSlot.over:CreateTexture(nil, "OVERLAY", nil, 2)
  proc:SetBlendMode("ADD")
  CM.SetAtlas(proc, Motion.PROC_ATLAS, false)
  proc:SetSize(procSize, procSize)
  proc:SetPoint("CENTER", icon, "CENTER")
  proc:Hide()
  centerFx.proc = proc
  local anim = centerSlot.over:CreateAnimationGroup()
  anim:SetLooping("NONE")
  anim:SetToFinalAlpha(true)
  local flip = anim:CreateAnimation("FlipBook")
  flip:SetTarget(proc)
  flip:SetOrder(0)
  Motion.ApplyProcFlipSettings(flip)
  anim:SetScript("OnFinished", function()
    proc:Hide()
  end)
  centerFx.anim = anim
  return centerFx
end

-- Shows the centre effects with the spell icon (playing the FlipBook each time the icon appears: on
-- open, on a spell change, and when the cursor leaves the centre), or hides them while the centre
-- shows your plate.
local function PaintCenterFx(spell)
  local fx = spell and BuildCenterFx() or centerFx
  if not fx then
    return
  end
  fx:SetShown(spell ~= nil)
  if not spell then
    fx.anim:Stop()
    fx.proc:Hide()
    centerFxSpell = nil -- replay when the spell icon comes back
    return
  end
  if spell ~= centerFxSpell then
    centerFxSpell = spell
    fx.anim:Stop()
    -- Re-apply the atlas: a finished FlipBook leaves the last frame's texcoords behind.
    CM.SetAtlas(fx.proc, CM.AssistedHighlightMotion.PROC_ATLAS, false)
    fx.proc:Show()
    fx.anim:Play(true)
  end
end

--- Party Wheel centre: the spell's icon (with its cooldown) while a slice is aimed; while the
--- cursor rests in the centre, your portrait in the same unit plate as the members' (health
--- ring, role, name). Hidden for the Radial Menu.
local function PaintCenterSlot(aimCentre)
  if not centerSlot then
    return
  end
  if source ~= SOURCES.party or not centerSpell then
    centerSlot:Hide()
    SetCenterPlate(false)
    return
  end
  centerSlot.SetSlotArt(nil)
  centerSlot.iconLabel:SetText("")
  centerSlot.count:SetText("")
  if aimCentre then
    centerSlot.cooldown:Clear()
    SetMemberPortrait(centerSlot.icon, "player")
    centerSlot.icon:SetDesaturated(false)
    centerSlot.SetSlotRing(RING_ICON, RING_SIZE)
    SetInnerShadow(centerSlot, true)
    PaintUnitPlate(centerSlot, "player")
    centerSlot.SetSlotState("selected")
    PaintCenterFx(nil)
  else
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(centerSpell)
    CM.RadialSetIcon(centerSlot.icon, icon, centerSlot.iconLabel)
    centerSlot.icon:SetDesaturated(false)
    PaintCooldown(centerSlot, { kind = "unit", spell = centerSpell })
    centerSlot.SetSlotRing(nil)
    SetInnerShadow(centerSlot, true)
    if centerSlot.plate then
      centerSlot.plate:Hide()
    end
    centerSlot.SetSlotState("normal")
    -- After SetSlotRing(nil): the effects are sized off the spell icon.
    PaintCenterFx(centerSpell)
  end
  centerSlot:Show()
  SetCenterPlate(centerSlot.plate ~= nil and centerSlot.plate:IsShown())
end

--- Shows the spell icon (false) or your portrait (true) in the centre: instantly on open, otherwise
--- through the swap animation run by the update (StepCenterSwap).
local function SetCenterAim(aimCentre, instant)
  if instant or centerShownAim == nil or not (centerSlot and centerSlot:IsShown()) then
    centerShownAim, centerSwapTo, centerSwapT = aimCentre, aimCentre, 1
    if centerSlot then
      centerSlot:SetAlpha(1)
      centerSlot:SetScale(1)
    end
    PaintCenterSlot(aimCentre)
    return
  end
  if centerSwapT < 1 then
    if aimCentre ~= centerSwapTo and centerSwapT >= 0.5 then
      -- Already swapped and growing back: shrink out again from where it is.
      centerSwapT = 1 - centerSwapT
    end
    centerSwapTo = aimCentre
    if centerSwapT >= 0.5 then
      PaintCenterSlot(aimCentre) -- growing back in: keep it current (spell change, repaint)
    end
    return
  end
  if aimCentre == centerShownAim then
    PaintCenterSlot(aimCentre)
    return
  end
  centerSwapTo = aimCentre
  centerSwapT = 0
end

local function StepCenterSwap(elapsed)
  centerSwapT = math.min(1, centerSwapT + elapsed / CENTRE_SWAP_DURATION)
  if centerSwapT >= 0.5 and centerShownAim ~= centerSwapTo then
    centerShownAim = centerSwapTo
    PaintCenterSlot(centerShownAim)
  end
  local k = math.abs(1 - 2 * centerSwapT) -- 1 -> 0 at the swap -> 1
  local eased = 1 - (1 - k) ^ 3
  centerSlot:SetAlpha(eased)
  centerSlot:SetScale(CENTRE_SWAP_SCALE + (1 - CENTRE_SWAP_SCALE) * eased)
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
local CLOSE_BACKDROP = { 0.42, 0.06, 0.05 }
local CENTRE_BACKDROP_SCALE = 0.45 -- Party Wheel: your class colour, dimmed like the close red
local SPELL_BACKDROP = { 0.08, 0.36, 0.1 } -- Party Wheel: green behind the spell icon (a slice aimed)

local function ApplyCenter(mix)
  centerMix = mix
  -- Party Wheel: the centre casts (normal targeting), so no cancel marker; the backdrop is
  -- green behind the spell icon and crossfades to your class colour while you aim the centre.
  local closeMix = source.centreCloses and mix or 0
  closeIcon:SetShown(closeMix > 0)
  closeIcon:SetAlpha(closeMix)
  local r, g, b = unpack(CLOSE_BACKDROP)
  if source.centreCloses then
    r, g, b = r * mix, g * mix, b * mix
  else
    local cr, cg, cb = 1, 1, 1
    if CM.AllyCycleTarget then
      cr, cg, cb = CM.AllyCycleTarget.GetClassRGB("player")
    end
    local s, gr, gg, gb = CENTRE_BACKDROP_SCALE, unpack(SPELL_BACKDROP)
    r = gr + (cr * s - gr) * mix
    g = gg + (cg * s - gg) * mix
    b = gb + (cb * s - gb) * mix
  end
  backdrop:SetVertexColor(r, g, b)
  for i = 1, #pips do
    pips[i]:SetAlpha(1 - mix)
  end
end

local function Highlight(aim, n)
  local first = lastAim == -1
  -- Paint() re-runs this on every cooldown / usable event: tick only when the aim moved.
  local moved = aim ~= lastAim
  lastAim = aim
  if not first and moved and aim >= 1 then
    local now = GetTime()
    if now - lastAimSound >= AIM_SOUND_GAP then
      lastAimSound = now
      PlayRadialSound("aim")
    end
  end
  local party = source == SOURCES.party
  -- Party Wheel: the centre is "you" only after the cursor left it (CM.PartyWheelLeftCentre); until
  -- then a centre release casts on your friendly target, so the spell icon stays.
  local center = aim < 1 and (not party or source.LeftCentre())
  centerGoal = center and 1 or 0
  if first then
    ApplyCenter(centerGoal)
  end
  -- Party Wheel: no centre texts, the centre slot shows the spell or (centre aimed) you.
  centerName:SetShown(aim >= 1 and not party)
  centerAim:SetShown(not party)
  SetCenterAim(center, first)
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
  local k, _, entries = source.Current()
  local entry = aim >= 1 and entries[aim] or nil
  local unusable = entry and SliceUnusable(entry)
  -- A slice that can't be used right now (combat lockdown, cooldown, no group...) highlights grey.
  if entry and entry.kind == "unit" and CM.AllyCycleTarget then
    -- Party Wheel: the member's class colour (white when the class is hidden), desaturated
    -- (luminance) when they can't be picked. GetClassRGB is public.
    local r, g, b = CM.AllyCycleTarget.GetClassRGB(entry.unit)
    if unusable then
      local l = 0.299 * r + 0.587 * g + 0.114 * b
      r, g, b = l, l, l
    end
    sel:SetVertexColor(r, g, b)
  elseif unusable then
    sel:SetVertexColor(0.6, 0.6, 0.6)
  else
    sel:SetVertexColor(CM.RadialWheelColor(k))
  end
  if party then
    centerAim:SetText("")
  else
    local name = entry and CM.RadialEntryInfo(entry) or nil
    SetAbbreviated(centerAim, name, AIM_WIDTH)
  end
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
  local k, total, entries, title = source.Current()
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
    centerSpell = nil
    PaintCenterSlot(false)
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
      if entry.kind == "unit" then
        SetMemberPortrait(slot.icon, entry.unit)
        slot.iconLabel:SetText("")
        slot.SetSlotArt(nil)
        -- The health ring is the portrait's border: no circle slot, only its glow when aimed.
        slot.SetSlotRing(RING_ICON, RING_SIZE)
        SetInnerShadow(slot, true)
        PaintUnitPlate(slot, entry.unit)
        -- The spell's cooldown shows once, on the centre icon, not on every portrait.
        slot.cooldown:Clear()
      else
        local _, icon, iconText, art = CM.RadialEntryInfo(entry)
        CM.RadialSetIcon(slot.icon, icon, slot.iconLabel, iconText)
        slot.SetSlotRing(nil)
        SetInnerShadow(slot, false)
        slot.icon:SetAlpha(1) -- unit slots dim out of range
        slot.SetSlotArt(art)
        if slot.plate then
          slot.plate:Hide()
        end
        PaintCooldown(slot, entry)
      end
      local unusable = SliceUnusable(entry)
      slot.unusable = unusable
      if entry.kind == "item" then
        local count = ItemCount(entry.id)
        slot.count:SetText(count > 1 and count or "")
      else
        slot.count:SetText("")
      end
      slot.icon:SetDesaturated(unusable or (entry.kind == "unit" and slot.dead) or false)
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
  centerName:SetText(title or "")
  -- Party Wheel title = the spell name (PartyWheelCurrent), drawn as the centre slot's icon.
  centerSpell = source == SOURCES.party and title or nil
  PaintPips(k, total)
  Highlight(source.Aim(), n)
end

--- Repaint when open (page turned, cooldown / bag events, store finished).
function CM.RadialViewRefresh()
  if CM.IsRadialMenuOpen and CM.IsRadialMenuOpen() then
    Paint()
  end
end

--- Called by the façade when a wheel is shown / hidden. `kind` = "radial" (default) | "party".
function CM.RadialViewShown(kind)
  source = SOURCES[kind] or SOURCES.radial
  Build()
  if not view then
    return
  end
  local wheel = Wheel()
  if wheel and view:GetParent() ~= wheel then
    view:SetParent(wheel)
    view:ClearAllPoints()
    view:SetPoint("CENTER", wheel, "CENTER", 0, 0)
    view:SetFrameLevel(wheel:GetFrameLevel() + 1)
  end
  healthElapsed = 0
  for i = 0, LAYOUT.MAX_SLICES do
    local slot = i == 0 and centerSlot or slots[i]
    if slot and slot.plate then
      slot.plate.shownPct = nil
    end
  end
  centerFxSpell = nil -- replay the centre FlipBook on every open
  lastAim = -1
  centerShownAim = nil
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
  SetHealthEvents(source == SOURCES.party)
  view:SetScript("OnUpdate", function(_, elapsed)
    local aim = source.Aim()
    -- The centre zone's OnEnter can land a frame after the aim reaches the centre.
    local left = source == SOURCES.party and source.LeftCentre()
    if aim ~= lastAim or left ~= lastLeftCentre then
      lastLeftCentre = left
      Highlight(aim, lastCount)
    end
    if source == SOURCES.party then
      if centerFx and centerFx:IsShown() then
        local Motion = CM.AssistedHighlightMotion
        centerFxPhase = (centerFxPhase + elapsed / Motion.GLOW_CYCLE_DURATION) % 1
        centerFx.glow:SetAlpha(Motion.GlowBreathAlpha(centerFxPhase))
      end
      healthElapsed = healthElapsed + elapsed
      if healthElapsed >= HEALTH_INTERVAL then
        healthElapsed = 0
        for i = 1, lastCount do
          local slot = slots[i]
          if slot.plate and slot.plate:IsShown() then
            PaintHealthRing(slot, slot.plate.unit)
          end
        end
        if centerPlate then
          PaintHealthRing(centerSlot, "player")
        end
      end
      for i = 1, lastCount do
        StepHealthRing(slots[i], elapsed)
      end
      if centerPlate then
        StepHealthRing(centerSlot, elapsed)
      end
      StepLowGlows(elapsed)
    end
    if centerSwapT < 1 and centerSlot then
      StepCenterSwap(elapsed)
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

function CM.RadialViewHidden(kind)
  if (SOURCES[kind] or SOURCES.radial) ~= source then
    return
  end
  if view then
    view:SetScript("OnUpdate", nil)
    SetHealthEvents(false)
    -- Stays invisible until the next open fades it in (the Party Wheel's frame shows before that).
    view:SetAlpha(0)
  end
  -- Released over a usable slice = used it; Esc, the centre or a greyed slice = just closed
  -- (the Party Wheel's centre casts, so it confirms too).
  local entry
  -- Esc or right-click cancels (Secure.lua / PartyWheel.lua bindings while open).
  local escaped = IsKeyDown("ESCAPE") or (IsMouseButtonDown and IsMouseButtonDown("RightButton"))
  if lastAim >= 1 and not escaped then
    local _, _, entries = source.Current()
    entry = entries[lastAim]
  end
  local centreCast = lastAim < 1 and not escaped and not source.centreCloses
  if centreCast or (entry and not SliceUnusable(entry)) then
    PlayRadialSound("confirm")
  else
    PlayRadialSound("close")
  end
end
