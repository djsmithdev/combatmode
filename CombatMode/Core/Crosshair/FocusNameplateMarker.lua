---------------------------------------------------------------------------------------
--  Core/Crosshair/FocusNameplateMarker.lua — CROSSHAIR — lock marker on locked nameplate
---------------------------------------------------------------------------------------
--  What it does: On Target Lock (when showTargetLockMarker is on), switches the center
--  reticle to a static base-colored Dot (unreactive) and reverse-explodes a hostile-red
--  hit marker (user's crosshair Appearance Active/-hit texture) onto the focus nameplate
--  health bar center. Once settled, the marker color-pulses between the hostile
--  reaction tint and white. Unlock or toggle-off hides the marker and restores the reactive reticle.
--  Architecture / how it works:
--    • CM.UpdateFocusNameplateMarker / ClearFocusNameplateMarker / OnFocusNameplateMarkerEvent.
--    • Gated by CM.IsTargetLockEnabled (char.reticleTargeting) and
--      CM.DB.global.showTargetLockMarker (default true; ~= false). Off → Clear.
--    • State machine: IDLE → PLATE_ARRIVE → SETTLED (instant clear on unlock).
--      Phases are sequential and own different channels: arrive = scale/alpha only
--      (focus/hostile tint from GetCrosshairReactionColor); settled = vertex-color pulse
--      between that tint and white (scale/alpha held at 1).
--    • Marker parents to the nameplate root with SetIgnoreParentAlpha so Platynator/
--      Blizzard health-bar alpha does not multiply with our arrive fade or color pulse.
--    • While focus exists and the marker option is on, center stays on the static Dot
--      even if no nameplate is visible. Unlock / marker-off Clears and restores.
--    • Marker tint uses CM.GetCrosshairReactionColor("focus") → effective hostile.
--    • Anchors centered on Blizzard/Platynator health bar (IsVisible + under-plate).
--      Platynator is preferred over UnitFrame.healthBar; widgets iterated with pairs
--      (array or map). Secret bar sizes are treated as plausible, not rejected.
--    • Plate GetWidth/GetAlpha/GetScale probes are secret-safe (issecretvalue) so instance
--      taint cannot error while scanning StatusBars.
--    • Driven by PLAYER_FOCUS_CHANGED + NAME_PLATE_UNIT_ADDED/REMOVED via EventRouter.
--    • Arrive runs once per lock session; plate recycle ResumeSettled (no re-arrive).
--      flashElapsed also survives recycle. True unlock clears the session.
--  Does not: Own focus macros, Target Lock keybind, sounds, or third-party nameplate restyles.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/EventRouter.lua, Constants/Assets.lua, UI/Options/Tabs/TabGeneral.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UnitExists = _G.UnitExists
local UnitIsUnit = _G.UnitIsUnit
local UIParent = _G.UIParent

local C_NamePlate = _G.C_NamePlate
local C_Timer = _G.C_Timer

-- Lua stdlib
local math = _G.math
local pcall = _G.pcall
local type = _G.type
local issecretvalue = _G.issecretvalue

local STATE_IDLE = 0
local STATE_PLATE_ARRIVE = 1
local STATE_SETTLED = 2

local function IsMarkerEnabled()
  if CM.IsTargetLockEnabled and not CM.IsTargetLockEnabled() then
    return false
  end
  local g = CM.DB and CM.DB.global
  return not g or g.showTargetLockMarker ~= false
end

local MARKER_SIZE = 24
local ARRIVE_DURATION = 0.25
local ARRIVE_START_SCALE = 1.4

-- Settled idle: color pulse only (arrive owns scale/alpha; never overlap those channels).
local MARKER_FLASH_PERIOD = 0.8

local PLATE_ADD_DEFER_SEC = 0.05
local SIZE_RETRY_SEC = 0.12
local SIZE_RETRY_MAX = 4

local state = STATE_IDLE
local motionElapsed = 0 -- arrive progress only
local flashElapsed = 0 -- survives plate recycle while still locked
local lockSessionActive = false -- true after first plate show until unlock/clear
local activePlate
local activeAnchor
local pendingPlateAdd
local sizeRetryCount = 0
local waitingForPlate = false

local markerFrame
local driverFrame

-- Public number for compares/arithmetic; secret measures (e.g. tainted StatusBar
-- GetWidth/GetAlpha) fall back so we never branch on secret values under taint.
local function PublicNumber(value, fallback)
  if type(value) ~= "number" then
    return fallback
  end
  if issecretvalue and issecretvalue(value) then
    return fallback
  end
  return value
end

local function Clamp01(value)
  return math.max(0, math.min(1, value))
end

local function EaseOutQuad(progress)
  local inv = 1 - progress
  return 1 - inv * inv
end

local function GetFocusColor()
  local c = CM.GetCrosshairReactionColor("focus")
  if type(c) == "table" then
    return c[1] or 1, c[2] or 0, c[3] or 1, c[4] or 1
  end
  return 1, 0, 1, 1
end

local function GetMarkerTexturePath()
  local appearance = CM.DB and CM.DB.global and CM.DB.global.crosshairAppearance
  if type(appearance) == "table" and type(appearance.Active) == "string" then
    return appearance.Active
  end
  local obj = CM.Constants
    and CM.Constants.CrosshairTextureObj
    and CM.Constants.CrosshairTextureObj.Default
  if type(obj) == "table" and type(obj.Active) == "string" then
    return obj.Active
  end
  return "Interface\\AddOns\\CombatMode\\assets\\crosshairDefault-hit.blp"
end

local function ApplyTexture(tex, resetColor)
  if not tex then
    return false
  end
  local path = GetMarkerTexturePath()
  local ok = pcall(tex.SetTexture, tex, path)
  if not ok then
    return false
  end
  -- Skip color reset while the settled flash owns vertex color (reanchor mid-combat).
  if resetColor ~= false then
    local r, g, b, a = GetFocusColor()
    tex:SetVertexColor(r, g, b, a)
  end
  return true
end

local function GetPlateForFocus()
  if not (UnitExists and UnitExists("focus")) then
    return nil
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
    return nil
  end
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "focus")
  if not ok or not plate then
    return nil
  end
  return plate
end

local function IsUsableRegion(region)
  if not region then
    return false
  end
  if region.IsForbidden and region:IsForbidden() then
    return false
  end
  if region.IsVisible and not region:IsVisible() then
    return false
  elseif region.IsShown and not region:IsShown() then
    return false
  end
  -- Secret alpha → treat as fully visible (do not reject the region).
  local alpha = PublicNumber(region.GetAlpha and region:GetAlpha(), 1)
  if alpha < 0.05 then
    return false
  end
  return true
end

local function IsUnderPlate(region, plate)
  local node = region
  local guard = 0
  while node and guard < 12 do
    if node == plate then
      return true
    end
    node = node.GetParent and node:GetParent() or nil
    guard = guard + 1
  end
  return false
end

local function GetVisualSize(region)
  -- Secret width/height/scale: do not coerce to 0 (that falsely fails size checks on
  -- third-party plates under taint). Treat unknown as a mid-range bar so Platynator
  -- / custom StatusBars can still be accepted when other heuristics match.
  local rawW = region.GetWidth and region:GetWidth()
  local rawH = region.GetHeight and region:GetHeight()
  local rawScale = region.GetScale and region:GetScale()
  local secretSize = (issecretvalue and (issecretvalue(rawW) or issecretvalue(rawH))) and true
    or false
  local w = PublicNumber(rawW, secretSize and 40 or 0)
  local h = PublicNumber(rawH, secretSize and 8 or 0)
  local scale = PublicNumber(rawScale, 1)
  return w * scale, h * scale, secretSize
end

local function IsPlausibleHealthBarSize(w, h, secretSize)
  if secretSize then
    return true
  end
  return w >= 16 and h >= 2 and h <= 64
end

-- Platynator hangs a display frame (with .widgets) under the nameplate. Widgets may be
-- an array or a map — always iterate with pairs. Returns: statusBarOrWidget | nil.
-- nil = not a Platynator plate or no usable health widget (caller should fall through).
local function FindPlatynatorHealthWidget(plate)
  local children = { plate:GetChildren() }
  for i = 1, #children do
    local display = children[i]
    local widgets = display and display.widgets
    if type(widgets) == "table" then
      local best, bestArea = nil, 0
      for _, widget in pairs(widgets) do
        if
          widget
          and widget.UpdateHealth
          and widget.statusBar
          and IsUsableRegion(widget)
          and IsUnderPlate(widget, plate)
        then
          local w, h, secretSize = GetVisualSize(widget)
          if IsPlausibleHealthBarSize(w, h, secretSize) then
            local area = w * h
            if area > bestArea then
              best = widget
              bestArea = area
            end
          end
        end
      end
      if best then
        if best.statusBar and IsUsableRegion(best.statusBar) then
          return best.statusBar
        end
        return best
      end
      -- Widgets table present but no match yet — do not block StatusBar fallback.
      return nil
    end
  end
  return nil
end

local function FindBestVisibleStatusBar(frame, depth, best, bestArea)
  if not frame or depth > 6 then
    return best, bestArea
  end
  -- Aura/buff containers and other addon widgets under the plate can be forbidden;
  -- touching them (IsObjectType, GetChildren) errors under addon taint.
  if frame.IsForbidden and frame:IsForbidden() then
    return best, bestArea
  end
  local okType, isStatusBar = pcall(function()
    return frame.IsObjectType and frame:IsObjectType("StatusBar")
  end)
  if okType and isStatusBar and IsUsableRegion(frame) then
    local w, h, secretSize = GetVisualSize(frame)
    if IsPlausibleHealthBarSize(w, h, secretSize) then
      local area = w * h
      if area > bestArea then
        best = frame
        bestArea = area
      end
    end
  end
  local okKids, children = pcall(function()
    return { frame:GetChildren() }
  end)
  if okKids and children then
    for i = 1, #children do
      best, bestArea = FindBestVisibleStatusBar(children[i], depth + 1, best, bestArea)
    end
  end
  return best, bestArea
end

--- Returns health-bar anchor (or nil).
local function GetIconAnchor(plate)
  if not plate then
    return nil
  end
  if plate.IsForbidden and plate:IsForbidden() then
    return nil
  end

  -- Prefer Platynator (and other custom plates) before Blizzard UnitFrame: with
  -- nameplate addons loaded, UnitFrame.healthBar may still exist but be the wrong
  -- (hidden/unused) bar — anchoring there makes the marker invisible.
  local platWidget = FindPlatynatorHealthWidget(plate)
  if platWidget then
    return platWidget
  end

  local unitFrame = plate.UnitFrame
  if unitFrame and not (unitFrame.IsForbidden and unitFrame:IsForbidden()) then
    local healthBar = unitFrame.healthBar
    if healthBar and IsUsableRegion(healthBar) and IsUnderPlate(healthBar, plate) then
      local w, h, secretSize = GetVisualSize(healthBar)
      if IsPlausibleHealthBarSize(w, h, secretSize) then
        return healthBar
      end
    end
  end

  local scanned = FindBestVisibleStatusBar(plate, 0, nil, 0)
  if scanned then
    return scanned
  end

  if IsUsableRegion(plate) then
    return plate
  end
  return nil
end

local function EnsureMarkerFrame()
  if markerFrame then
    return markerFrame
  end
  markerFrame = CreateFrame("Frame", "CombatModeFocusNameplateLock", UIParent)
  markerFrame:EnableMouse(false)
  markerFrame.icon = markerFrame:CreateTexture(nil, "ARTWORK", nil, 0)
  markerFrame.icon:SetAllPoints(markerFrame)
  markerFrame:Hide()
  return markerFrame
end

local function EnsureDriver()
  if driverFrame then
    return driverFrame
  end
  driverFrame = CreateFrame("Frame", "CombatModeFocusNameplateAnimDriver", UIParent)
  return driverFrame
end

local function StopDriver()
  if driverFrame then
    driverFrame:SetScript("OnUpdate", nil)
  end
end

local function HideMarkerInstant()
  if markerFrame then
    markerFrame:Hide()
    markerFrame:SetScale(1)
    markerFrame:SetAlpha(1)
  end
end

-- Parent to nameplate root (not the health StatusBar): bar alpha fades from
-- Platynator/Blizzard would otherwise multiply with our color pulse.
local function AnchorMarkerCentered(plate, anchor, resetColor)
  local marker = EnsureMarkerFrame()
  local parent = plate or UIParent
  marker:SetParent(parent)
  if marker.SetIgnoreParentScale then
    marker:SetIgnoreParentScale(true)
  end
  if marker.SetIgnoreParentAlpha then
    marker:SetIgnoreParentAlpha(true)
  end
  local strata = anchor.GetFrameStrata and anchor:GetFrameStrata() or "BACKGROUND"
  if strata == "BACKGROUND" then
    strata = "LOW"
  end
  marker:SetFrameStrata(strata)
  marker:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 50)
  marker:ClearAllPoints()
  marker:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  marker:SetSize(MARKER_SIZE, MARKER_SIZE)
  ApplyTexture(marker.icon, resetColor)
  return marker
end

local function SetIdle(resetFlash)
  state = STATE_IDLE
  motionElapsed = 0
  if resetFlash then
    flashElapsed = 0
    lockSessionActive = false
  end
  StopDriver()
end

local function ApplyFocusColor(marker)
  local r, g, b, a = GetFocusColor()
  marker.icon:SetVertexColor(r, g, b, a)
end

local function ApplyFlashColor(marker)
  local t = Clamp01((flashElapsed % MARKER_FLASH_PERIOD) / MARKER_FLASH_PERIOD)
  -- Cosine: 1 at t=0, 0 at t=0.5, 1 at t=1.
  local phase = 0.5 + 0.5 * math.cos(t * 2 * math.pi)
  local fr, fg, fb, fa = GetFocusColor()
  -- phase=1: focus (hostile) tint; phase=0: white highlight.
  local mix = 1 - phase
  marker.icon:SetVertexColor(fr + (1 - fr) * mix, fg + (1 - fg) * mix, fb + (1 - fb) * mix, fa)
end

local function OnDriverUpdate(_, elapsed)
  CM.Profile("FNM:OnDriverUpdate", function()
    if state == STATE_PLATE_ARRIVE then
      motionElapsed = motionElapsed + elapsed
      local marker = EnsureMarkerFrame()
      if motionElapsed >= ARRIVE_DURATION then
        marker:SetScale(1)
        marker:SetAlpha(1)
        state = STATE_SETTLED
        motionElapsed = 0
        flashElapsed = 0
        ApplyFlashColor(marker)
        return
      end
      local t = EaseOutQuad(Clamp01(motionElapsed / ARRIVE_DURATION))
      local scale = ARRIVE_START_SCALE + (1 - ARRIVE_START_SCALE) * t
      marker:SetScale(math.max(0.01, scale))
      marker:SetAlpha(t)
      -- Fixed color during arrive — pulse starts only after settle.
      ApplyFocusColor(marker)
      return
    end

    if state == STATE_SETTLED then
      flashElapsed = flashElapsed + elapsed
      ApplyFlashColor(EnsureMarkerFrame())
    end
  end)
end

local function StartDriver()
  local driver = EnsureDriver()
  driver:SetScript("OnUpdate", OnDriverUpdate)
end

local function BeginPlateArrive(plate, anchor)
  activePlate = plate
  activeAnchor = anchor
  waitingForPlate = false
  sizeRetryCount = 0
  local marker = AnchorMarkerCentered(plate, anchor, true)
  marker:SetScale(ARRIVE_START_SCALE)
  marker:SetAlpha(0)
  marker:Show()
  state = STATE_PLATE_ARRIVE
  motionElapsed = 0
  flashElapsed = 0
  lockSessionActive = true
  ApplyFocusColor(marker)
  StartDriver()
end

-- Plate recycled while still locked: snap settled without replaying arrive.
local function ResumeSettled(plate, anchor)
  activePlate = plate
  activeAnchor = anchor
  waitingForPlate = false
  sizeRetryCount = 0
  local marker = AnchorMarkerCentered(plate, anchor, false)
  marker:SetScale(1)
  marker:SetAlpha(1)
  marker:Show()
  state = STATE_SETTLED
  motionElapsed = 0
  lockSessionActive = true
  ApplyFlashColor(marker)
  StartDriver()
end

local function SuppressCenterReticle()
  if CM.SetFocusLockReticleSuppressed then
    CM.SetFocusLockReticleSuppressed(true)
  end
end

local function RestoreCenterReticle()
  if CM.SetFocusLockReticleSuppressed then
    CM.SetFocusLockReticleSuppressed(false)
  end
end

local function DismissMarkerInstant()
  waitingForPlate = false
  pendingPlateAdd = nil
  sizeRetryCount = 0
  RestoreCenterReticle()
  HideMarkerInstant()
  activePlate = nil
  activeAnchor = nil
  SetIdle(true)
end

local function ScheduleSizeRetry()
  if sizeRetryCount >= SIZE_RETRY_MAX then
    -- Exhausted retries: Dot stays while focus remains; plate ADD can retry later.
    SuppressCenterReticle()
    waitingForPlate = true
    return
  end
  if not (C_Timer and C_Timer.After) then
    return
  end
  sizeRetryCount = sizeRetryCount + 1
  C_Timer.After(SIZE_RETRY_SEC, function()
    if UnitExists and UnitExists("focus") and waitingForPlate then
      CM.UpdateFocusNameplateMarker()
    end
  end)
end

local function StartTransfer(plate, anchor)
  SuppressCenterReticle()
  if lockSessionActive then
    ResumeSettled(plate, anchor)
    return
  end
  BeginPlateArrive(plate, anchor)
end

local function ReanchorIfNeeded(plate, anchor)
  if state ~= STATE_PLATE_ARRIVE and state ~= STATE_SETTLED then
    return
  end
  if activeAnchor == anchor and activePlate == plate then
    return
  end
  activePlate = plate
  activeAnchor = anchor
  -- Preserve current scale/alpha mid-arrive; only re-parent/point.
  local marker = AnchorMarkerCentered(plate, anchor, false)
  marker:Show()
end

function CM.ClearFocusNameplateMarker()
  DismissMarkerInstant()
end

function CM.UpdateFocusNameplateMarker()
  if not IsMarkerEnabled() then
    CM.ClearFocusNameplateMarker()
    return
  end

  if not (UnitExists and UnitExists("focus")) then
    CM.ClearFocusNameplateMarker()
    return
  end

  local plate = GetPlateForFocus()
  if not plate then
    waitingForPlate = true
    -- Locked with no plate on screen — Dot still shows lock state.
    SuppressCenterReticle()
    if state == STATE_PLATE_ARRIVE or state == STATE_SETTLED then
      HideMarkerInstant()
      activePlate = nil
      activeAnchor = nil
      -- Keep lockSessionActive + flashElapsed; plate ADD will ResumeSettled.
      state = STATE_IDLE
      motionElapsed = 0
      StopDriver()
    end
    return
  end

  local anchor = GetIconAnchor(plate)
  if not anchor then
    waitingForPlate = true
    SuppressCenterReticle()
    return
  end

  local rawW = anchor.GetWidth and anchor:GetWidth()
  -- Secret width: accept and continue (same as GetVisualSize secretSize path).
  if not (issecretvalue and issecretvalue(rawW)) then
    local w = PublicNumber(rawW, 0)
    if w < 8 then
      waitingForPlate = true
      SuppressCenterReticle()
      if sizeRetryCount >= SIZE_RETRY_MAX then
        return
      end
      ScheduleSizeRetry()
      return
    end
  end

  waitingForPlate = false

  -- Same plate identity (not GUID — UnitGUID is secret under dungeon taint).
  if (state == STATE_SETTLED or state == STATE_PLATE_ARRIVE) and activePlate == plate then
    SuppressCenterReticle()
    ReanchorIfNeeded(plate, anchor)
    return
  end

  StartTransfer(plate, anchor)
end

function CM.OnFocusNameplateMarkerEvent(event, unitToken)
  if not IsMarkerEnabled() then
    return
  end

  if event == "NAME_PLATE_UNIT_REMOVED" then
    local focusStillLocked = UnitExists and UnitExists("focus")
    local isFocusPlate = unitToken and UnitIsUnit and UnitIsUnit(unitToken, "focus")
    if
      not isFocusPlate
      and activePlate
      and C_NamePlate
      and C_NamePlate.GetNamePlateForUnit
      and unitToken
    then
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
      if ok and plate and plate == activePlate then
        isFocusPlate = true
      end
    end
    if isFocusPlate then
      HideMarkerInstant()
      activePlate = nil
      activeAnchor = nil
      waitingForPlate = focusStillLocked and true or false
      -- Keep flashElapsed / lockSessionActive while still locked so plate recycle
      -- does not replay arrive or restart the pulse phase.
      state = STATE_IDLE
      motionElapsed = 0
      StopDriver()
      if waitingForPlate then
        SuppressCenterReticle()
      else
        RestoreCenterReticle()
        lockSessionActive = false
        flashElapsed = 0
      end
      return
    end
    return
  end

  if UnitExists and UnitExists("focus") then
    if event == "NAME_PLATE_UNIT_ADDED" and unitToken and UnitIsUnit then
      if not UnitIsUnit(unitToken, "focus") then
        return
      end
      if C_Timer and C_Timer.After then
        pendingPlateAdd = true
        sizeRetryCount = 0
        C_Timer.After(PLATE_ADD_DEFER_SEC, function()
          if not pendingPlateAdd then
            return
          end
          pendingPlateAdd = nil
          CM.UpdateFocusNameplateMarker()
        end)
        return
      end
    end
    sizeRetryCount = 0
    CM.UpdateFocusNameplateMarker()
  end
end
