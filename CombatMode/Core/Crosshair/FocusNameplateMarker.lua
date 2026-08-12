---------------------------------------------------------------------------------------
--  Core/Crosshair/FocusNameplateMarker.lua — CROSSHAIR — lock marker on locked nameplate
---------------------------------------------------------------------------------------
--  What it does: On Target Lock (when showTargetLockMarker is on), switches the center
--  reticle to a static base-colored Dot (unreactive) and reverse-explodes a hostile-red
--  hit marker (user's crosshair Appearance Active/-hit texture) onto the focus nameplate
--  health bar center. When the locked unit is casting, the marker smoothly oscillates
--  between hostile red and white at 0.8s intervals — a visual cue without protected APIs. Unlock or toggle-off hides
--  the marker and restores the reactive reticle.
--  Architecture / how it works:
--    • CM.UpdateFocusNameplateMarker / ClearFocusNameplateMarker / OnFocusNameplateMarkerEvent.
--    • Gated by CM.IsTargetLockEnabled (char.reticleTargeting) and
--      CM.DB.global.showTargetLockMarker (default true; ~= false). Off → Clear.
--    • State machine: IDLE → PLATE_ARRIVE → SETTLED (instant clear on unlock).
--    • While focus exists and the marker option is on, center stays on the static Dot
--      even if no nameplate is visible (user feedback that Target Lock is held). Plate
--      arrive still shows the hit marker; unlock / marker-off Clears and restores.
--    • Own OnUpdate (does not use Animations.lua reticle motion channel).
--    • Anchors centered on Blizzard/Platynator health bar (IsVisible + under-plate).
--    • Plate GetWidth/GetAlpha/GetScale probes are secret-safe (issecretvalue) so instance
--      taint cannot error while scanning StatusBars.
--    • Driven by PLAYER_FOCUS_CHANGED + NAME_PLATE_UNIT_ADDED/REMOVED via EventRouter.
--    • Casting flash: OnDriverUpdate checks UnitCastingInfo("focus") per frame during
--      SETTLED. If casting, the marker smoothly oscillates between hostile red and
--      white on a 0.8s cosine wave. If not casting, restores the focus color.
--  Does not: Own focus macros, Target Lock keybind, sounds, or third-party nameplate restyles.
--  Related: Core/Crosshair/Crosshair.lua, Core/Crosshair/Animations.lua,
--  Core/Runtime/EventRouter.lua, Constants/Assets.lua, UI/Options/Tabs/TabGeneral.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local UnitCastingInfo = _G.UnitCastingInfo
local UnitChannelInfo = _G.UnitChannelInfo
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

-- Casting pulse: rhythmic color flash between hostile red and dim inactive while focus casts.
local CASTING_FLASH_PERIOD = 0.8

local PLATE_ADD_DEFER_SEC = 0.05
local SIZE_RETRY_SEC = 0.12
local SIZE_RETRY_MAX = 4

local state = STATE_IDLE
local motionElapsed = 0
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
  local colors = CM.Constants and CM.Constants.CrosshairReactionColors
  local c = colors and colors.focus
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

local function ApplyTexture(tex)
  if not tex then
    return false
  end
  local path = GetMarkerTexturePath()
  local ok = pcall(tex.SetTexture, tex, path)
  if not ok then
    return false
  end
  local r, g, b, a = GetFocusColor()
  tex:SetVertexColor(r, g, b, a)
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
  -- Secret width/height/scale → 0 so the candidate fails IsPlausibleHealthBarSize.
  local w = PublicNumber(region.GetWidth and region:GetWidth(), 0)
  local h = PublicNumber(region.GetHeight and region:GetHeight(), 0)
  local scale = PublicNumber(region.GetScale and region:GetScale(), 1)
  return w * scale, h * scale
end

local function IsPlausibleHealthBarSize(w, h)
  return w >= 16 and h >= 2 and h <= 64
end

local function FindPlatynatorHealthWidget(plate)
  local children = { plate:GetChildren() }
  for i = 1, #children do
    local display = children[i]
    local widgets = display and display.widgets
    if type(widgets) == "table" then
      local best, bestArea = nil, 0
      for j = 1, #widgets do
        local widget = widgets[j]
        if
          widget
          and widget.UpdateHealth
          and widget.statusBar
          and IsUsableRegion(widget)
          and IsUnderPlate(widget, plate)
        then
          local w, h = GetVisualSize(widget)
          if IsPlausibleHealthBarSize(w, h) then
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
      return false
    end
  end
  return nil
end

local function FindBestVisibleStatusBar(frame, depth, best, bestArea)
  if not frame or depth > 6 then
    return best, bestArea
  end
  if frame.IsObjectType and frame:IsObjectType("StatusBar") and IsUsableRegion(frame) then
    local w, h = GetVisualSize(frame)
    if IsPlausibleHealthBarSize(w, h) then
      local area = w * h
      if area > bestArea then
        best = frame
        bestArea = area
      end
    end
  end
  local children = { frame:GetChildren() }
  for i = 1, #children do
    best, bestArea = FindBestVisibleStatusBar(children[i], depth + 1, best, bestArea)
  end
  return best, bestArea
end

--- Returns health-bar anchor, needsRetry.
local function GetIconAnchor(plate)
  if not plate then
    return nil, false
  end
  if plate.IsForbidden and plate:IsForbidden() then
    return nil, false
  end

  local unitFrame = plate.UnitFrame
  if unitFrame and not (unitFrame.IsForbidden and unitFrame:IsForbidden()) then
    local healthBar = unitFrame.healthBar
    if healthBar and IsUsableRegion(healthBar) and IsUnderPlate(healthBar, plate) then
      local w, h = GetVisualSize(healthBar)
      if IsPlausibleHealthBarSize(w, h) then
        return healthBar, false
      end
    end
  end

  local platWidget = FindPlatynatorHealthWidget(plate)
  if platWidget then
    return platWidget, false
  end
  if platWidget == false then
    return nil, true
  end

  local scanned = FindBestVisibleStatusBar(plate, 0, nil, 0)
  if scanned then
    return scanned, false
  end

  if IsUsableRegion(plate) then
    return plate, false
  end
  return nil, false
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

local function AnchorMarkerCentered(anchor)
  local marker = EnsureMarkerFrame()
  marker:SetParent(anchor)
  if marker.SetIgnoreParentScale then
    marker:SetIgnoreParentScale(true)
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
  ApplyTexture(marker.icon)
  return marker
end

local BeginPlateArrive
local StartTransfer

local function SetIdle()
  state = STATE_IDLE
  motionElapsed = 0
  StopDriver()
end

local function OnDriverUpdate(_, elapsed)
  CM.Profile("FNM:OnDriverUpdate", function()
    motionElapsed = motionElapsed + elapsed

    if state == STATE_PLATE_ARRIVE then
      local marker = EnsureMarkerFrame()
      if motionElapsed >= ARRIVE_DURATION then
        marker:SetScale(1)
        marker:SetAlpha(1)
        state = STATE_SETTLED
        motionElapsed = 0
        -- Don't stop — let SETTLED decide if driver stays.
        return
      end
      local t = EaseOutQuad(Clamp01(motionElapsed / ARRIVE_DURATION))
      local scale = ARRIVE_START_SCALE + (1 - ARRIVE_START_SCALE) * t
      local alpha = t
      marker:SetScale(math.max(0.01, scale))
      marker:SetAlpha(alpha)
      return
    end

    if state == STATE_SETTLED then
      local marker = EnsureMarkerFrame()
      -- Check if focus is casting. If the API returns a value (even a secret
      -- one in instances), the unit IS casting — we don't need issecretvalue here.
      local isCasting = false
      local ok, name = pcall(UnitCastingInfo, "focus")
      if ok and name then
        isCasting = true
      end
      if not isCasting then
        local ok2, channelName = pcall(UnitChannelInfo, "focus")
        if ok2 and channelName then
          isCasting = true
        end
      end

      if isCasting then
        -- Smooth oscillation between hostile red and white.
        local t = Clamp01((motionElapsed % CASTING_FLASH_PERIOD) / CASTING_FLASH_PERIOD)
        -- Cosine: 1 at t=0, 0 at t=0.5, 1 at t=1.
        local phase = 0.5 + 0.5 * math.cos(t * 2 * math.pi)
        -- phase=1 (t=0): hostile red (1, 0.2, 0.3). phase=0 (t=0.5): white (1, 1, 1).
        local g = 1 - 0.8 * phase
        local b = 1 - 0.7 * phase
        marker.icon:SetVertexColor(1, g, b, 1)
        -- Keep driver running for continuous flash.
        return
      end

      -- Not casting: restore full focus color.
      local wantR, wantG, wantB, wantA = GetFocusColor()
      marker.icon:SetVertexColor(wantR, wantG, wantB, wantA)
      return
    end
  end)
end

local function StartDriver()
  local driver = EnsureDriver()
  driver:SetScript("OnUpdate", OnDriverUpdate)
end

BeginPlateArrive = function()
  if not activeAnchor then
    SetIdle()
    return
  end
  local marker = AnchorMarkerCentered(activeAnchor)
  marker:SetScale(ARRIVE_START_SCALE)
  marker:SetAlpha(0)
  marker:Show()
  state = STATE_PLATE_ARRIVE
  motionElapsed = 0
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
  SetIdle()
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

StartTransfer = function(plate, anchor)
  waitingForPlate = false
  sizeRetryCount = 0
  activePlate = plate
  activeAnchor = anchor
  SuppressCenterReticle()
  BeginPlateArrive()
end

local function ReanchorSettledIfNeeded(plate, anchor)
  if state ~= STATE_SETTLED then
    return
  end
  if activeAnchor == anchor and activePlate == plate then
    return
  end
  activePlate = plate
  activeAnchor = anchor
  local marker = AnchorMarkerCentered(anchor)
  marker:SetScale(1)
  marker:SetAlpha(1)
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
      SetIdle()
    end
    return
  end

  local anchor, needsRetry = GetIconAnchor(plate)
  if not anchor then
    waitingForPlate = true
    SuppressCenterReticle()
    if needsRetry then
      if sizeRetryCount >= SIZE_RETRY_MAX then
        return
      end
      ScheduleSizeRetry()
      return
    end
    return
  end

  local w = PublicNumber(anchor.GetWidth and anchor:GetWidth(), 0)
  if w < 8 then
    waitingForPlate = true
    SuppressCenterReticle()
    if sizeRetryCount >= SIZE_RETRY_MAX then
      return
    end
    ScheduleSizeRetry()
    return
  end

  waitingForPlate = false

  -- Same plate identity (not GUID — UnitGUID is secret under dungeon taint).
  if state == STATE_SETTLED and activePlate == plate then
    SuppressCenterReticle()
    ReanchorSettledIfNeeded(plate, anchor)
    return
  end

  if state == STATE_PLATE_ARRIVE and activePlate == plate then
    SuppressCenterReticle()
    activePlate = plate
    activeAnchor = anchor
    return
  end

  StartTransfer(plate, anchor)
end

function CM.OnFocusNameplateMarkerEvent(event, unitToken)
  if not IsMarkerEnabled() then
    return
  end

  if event == "NAME_PLATE_UNIT_REMOVED" then
    if unitToken and UnitIsUnit and UnitIsUnit(unitToken, "focus") then
      HideMarkerInstant()
      activePlate = nil
      activeAnchor = nil
      waitingForPlate = true
      SetIdle()
      SuppressCenterReticle()
      return
    end
    if activePlate and C_NamePlate and C_NamePlate.GetNamePlateForUnit and unitToken then
      local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unitToken)
      if ok and plate and plate == activePlate then
        HideMarkerInstant()
        activePlate = nil
        activeAnchor = nil
        waitingForPlate = UnitExists and UnitExists("focus")
        SetIdle()
        if waitingForPlate then
          SuppressCenterReticle()
        else
          RestoreCenterReticle()
        end
      end
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
