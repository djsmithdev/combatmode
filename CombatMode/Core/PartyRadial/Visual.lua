---------------------------------------------------------------------------------------
--  Core/PartyRadial/Visual.lua — PARTYRADIAL — frames, geometry, slice visuals
---------------------------------------------------------------------------------------
--  What it does: Owns mainFrame / slice SecureActionButton chrome, crosshair-anchored
--  geometry, UpdateSliceVisual / UpdateAllSlices / HighlightSlice, and
--  ApplyVisualConfig / position refresh. Layout sizes come from
--  CM.Constants.PartyRadialLayout.
--  Architecture / how it works:
--    • CM.PartyRadialVisual: CreateMainFrame, CreateSliceFrame, SetSliceMouseEnabled,
--      UpdateMainFramePosition, UpdateSlicePositionsAndSizes, UpdateAllSlices,
--      HighlightSlice, ApplyVisualConfig; exports mouse-angle helpers for Lifecycle.
--    • CreateSliceFrame uses HealthBars.CreateSliceHealthBar; UpdateSliceVisual calls
--      HealthBars + RoleIcons + PartyData.GetVisualPartyData.
--  Does not: Own show/hide fade, freelook hooks, or secure attribute rebuilds.
--  Related: Core/PartyRadial/HealthBars.lua, RoleIcons.lua, PartyData.lua,
--  Lifecycle.lua, Constants/PartyRadial.lua, Core/Crosshair/Crosshair.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local CreateColor = _G.CreateColor
local EvaluateColorFromBoolean = _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorFromBoolean
local GetCursorPosition = _G.GetCursorPosition
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UIParent = _G.UIParent
local UnitExists = _G.UnitExists
local UnitInRange = _G.UnitInRange
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsUnit = _G.UnitIsUnit

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
local math = _G.math
local tostring = _G.tostring
local utf8 = _G.utf8

local HR = CM.PartyRadial
local PartyData = CM.PartyRadialPartyData
local HealthBars = CM.PartyRadialHealthBars
local RoleIcons = CM.PartyRadialRoleIcons
local Visual = {}
CM.PartyRadialVisual = Visual

local function GetState()
  return HR.GetState()
end

local GetVisualPartyData = PartyData.GetVisualPartyData
local UpdateSliceHealthBar = HealthBars.UpdateSliceHealthBar
local ResolveRoleIconAtlas = RoleIcons.ResolveRoleIconAtlas
local UpdateRoleIconLowHealthGlow = RoleIcons.UpdateRoleIconLowHealthGlow
local HB_GLOW_R = HealthBars.HB_GLOW_R
local HB_GLOW_G = HealthBars.HB_GLOW_G
local HB_GLOW_B = HealthBars.HB_GLOW_B

local SECRET_NAME_PLACEHOLDER = "…"

-- Shorten display names by UTF-8 character count (byte :sub breaks Cyrillic/CJK).
-- Secret strings must not be length/sub'd — show a public placeholder instead.
local function TruncateUtf8Name(str, maxChars, keepChars, ellipsis)
  ellipsis = ellipsis or "..."
  if str ~= nil and issecretvalue and issecretvalue(str) then
    return SECRET_NAME_PLACEHOLDER
  end
  if not str or str == "" then
    return str
  end
  if utf8 and utf8.len and utf8.offset then
    local n = utf8.len(str)
    if n and n <= maxChars then
      return str
    end
    local pos = utf8.offset(str, keepChars + 1)
    if pos then
      return str:sub(1, pos - 1) .. ellipsis
    end
    return str
  end
  if #str > maxChars then
    return str:sub(1, keepChars) .. ellipsis
  end
  return str
end

-- Colors used with EvaluateColorFromBoolean to extract tainted boolean values.
-- EvaluateColorFromBoolean(bool, trueColor, falseColor) returns a ColorMixin
-- whose fields reflect the boolean's value without triggering taint errors.
-- Reachable uses alpha; dead role icons fall back to RGB when the dead bool is
-- secret (atlas swap needs a public boolean).
local COLOR_REACHABLE = CreateColor(1, 1, 1, 1.0)
local COLOR_UNREACHABLE = CreateColor(1, 1, 1, 0.4)
local COLOR_ICON_ALIVE = CreateColor(1, 1, 1, 1)
local COLOR_ICON_DEAD = CreateColor(0.45, 0.45, 0.45, 1)

---------------------------------------------------------------------------------------
--                                UTILITY FUNCTIONS                                  --
---------------------------------------------------------------------------------------
local function GetCrosshairAnchorOffsetForUIParent()
  local xf = _G.CombatModeCrosshairFrame
  if xf and xf.GetCenter then
    local cx, cy = xf:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and cy and ux and uy then
      return cx - ux, cy - uy
    end
  end
  return 0, CM.DB.global and CM.DB.global.crosshairY or 50
end

local function GetCrosshairCenterScreenXY()
  local xf = _G.CombatModeCrosshairFrame
  if xf and xf.GetCenter then
    local cx, cy = xf:GetCenter()
    if cx and cy then
      return cx, cy
    end
  end
  if not CM.DB.global then
    return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2
  end
  return UIParent:GetWidth() / 2, UIParent:GetHeight() / 2 + (CM.DB.global.crosshairY or 50)
end

-- Calculate angle and distance from crosshair center to cursor position
local function GetMouseAngleAndDistanceFromCenter()
  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  cursorX, cursorY = cursorX / scale, cursorY / scale

  local centerX, centerY = GetCrosshairCenterScreenXY()

  local dx = cursorX - centerX
  local dy = cursorY - centerY

  -- Distance from center
  local distance = math.sqrt(dx * dx + dy * dy)

  -- Convert to degrees (0 = right, counter-clockwise positive)
  local angle = math.deg(math.atan2(dy, dx))
  if angle < 0 then
    angle = angle + 360
  end

  return angle, distance
end

-- Check if an angle falls within an arc (handles wrap-around at 0/360)
local function IsAngleInArc(angle, arcStart, arcEnd)
  -- Normalize all angles to 0-360
  angle = angle % 360
  arcStart = arcStart % 360
  arcEnd = arcEnd % 360

  if arcStart <= arcEnd then
    return angle >= arcStart and angle < arcEnd
  else
    -- Arc wraps around 0
    return angle >= arcStart or angle < arcEnd
  end
end

-- Get which slice the current mouse angle corresponds to
local function GetSliceFromAngle(angle)
  local sliceArc = CM.Constants.PartyRadialSliceArc
  local halfArc = sliceArc / 2

  for i, sliceData in ipairs(CM.Constants.PartyRadialSlices) do
    local centerAngle = sliceData.angle
    local arcStart = (centerAngle - halfArc) % 360
    local arcEnd = (centerAngle + halfArc) % 360

    if IsAngleInArc(angle, arcStart, arcEnd) then
      return i
    end
  end

  return nil
end

-- Uses fixed base size for positioning (scale is fixed at 1.0 for hit-area stability)
local Layout = CM.Constants.PartyRadialLayout
local BASE_SLICE_SIZE = Layout.baseSliceSize
local CENTER_FIXED_SIZE = Layout.centerFixedSize
local SLICE_RADIUS = Layout.sliceRadius
local SLICE_SCALE = Layout.sliceScale
local ROLE_ICON_SIZE = Layout.roleIconSize
local NAME_FONT_SIZE = Layout.nameFontSize

local function GetSliceInnerAnchor(angleDeg, radius)
  local a = math.rad(angleDeg)
  local x = radius * math.cos(a)
  local y = radius * math.sin(a)
  local h = BASE_SLICE_SIZE / 2
  -- Angle 0 = right, 90 = up; inner = edge/corner toward radial center.
  if angleDeg >= 315 then
    return "TOPLEFT", x - h, y + h
  elseif angleDeg < 45 then
    return "BOTTOMLEFT", x - h, y - h
  elseif angleDeg >= 45 and angleDeg < 135 then
    return "BOTTOM", x, y - h
  elseif angleDeg >= 135 and angleDeg < 225 then
    return "BOTTOMRIGHT", x + h, y - h
  else
    return "TOPRIGHT", x + h, y + h
  end
end

local function CreateSliceFrame(sliceIndex)
  local sliceData = CM.Constants.PartyRadialSlices[sliceIndex]
  local angle = sliceData.angle
  local radius = SLICE_RADIUS
  local sliceScale = SLICE_SCALE

  -- Anchor slice by its inner edge to radial center (mainFrame) so SetScale grows
  -- outward from center; otherwise top slices move up and bottom move down asymmetrically.
  local radialCenter = GetState().mainFrame
  local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

  -- Parent to mainFrame so slices inherit position and alpha from the radial center.
  local slice = CreateFrame(
    "Button",
    "CMHealRadialSlice" .. sliceIndex,
    radialCenter,
    "SecureActionButtonTemplate"
  )
  slice:SetFrameStrata("DIALOG")
  slice:SetSize(BASE_SLICE_SIZE, BASE_SLICE_SIZE)
  slice:SetPoint(anchor, radialCenter, "CENTER", offsetX, offsetY)
  slice:SetScale(sliceScale) -- Apply config scale factor
  -- No base "type" attribute: unrecognized button clicks (Mouse4/Mouse5 etc.)
  -- fall through to nil and do nothing. Spell casting is handled by modified
  -- attributes (type1, shift-type2, etc.) set by UpdateSliceActionAttributes().
  -- Previously type="target" here caused Mouse4/5 releases to hard-target the unit.
  -- Register all clicks so Mouse4/Mouse5 don't get silently swallowed by EnableMouse.
  -- Left/right fire spell casting via SecureActionButtonTemplate attributes.
  -- Other buttons are caught by PostClick below to close the radial (tap-to-toggle).
  slice:RegisterForClicks("AnyUp", "AnyDown")
  slice.sliceIndex = sliceIndex

  -- Inner visual frame: a non-secure Frame child used for hover scale animation.
  -- SetScale on SecureActionButtonTemplate is PROTECTED during combat, but SetScale
  -- on a regular Frame child is NOT protected. All visual elements (icon, name, health)
  -- are created inside this inner frame so scaling it zooms the visuals without touching
  -- the protected secure button. The inner frame fills the slice exactly.
  local inner = CreateFrame("Frame", nil, slice)
  inner:SetAllPoints(slice)
  inner:SetFrameLevel(slice:GetFrameLevel() + 1)
  slice.innerFrame = inner
  slice.healthBar = HealthBars.CreateSliceHealthBar(inner)

  -- Role icon (created first so roleIconBG / glow can anchor to it)
  local roleIconSize = ROLE_ICON_SIZE
  slice.roleIcon = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIcon:SetDrawLayer("OVERLAY", 0)
  slice.roleIcon:SetSize(roleIconSize, roleIconSize)
  slice.roleIcon:SetPoint("TOP", inner, "TOP", 0, -4)

  -- Role icon backdrop (Radial_Wheel_BG_Small from interface/radialwheel/uiradialwheel, 189x189)
  -- Centered on role icon, larger so the shadow extends around it.
  slice.roleIconBG = inner:CreateTexture(nil, "BORDER")
  slice.roleIconBG:SetAtlas("Radial_Wheel_BG_Small")
  slice.roleIconBG:SetSize(roleIconSize * 1.5, roleIconSize * 1.5)
  slice.roleIconBG:SetPoint("CENTER", slice.roleIcon, "CENTER", 0, 0)

  -- Low-health inward glow drawn on top of the role icon (same HB_LOW_PCT as bar glow).
  -- Sized slightly under the icon so the circle reads inside the glyph, not as an outer halo.
  -- Gate alpha on texture vertex color (may be secret); breath pulse via glowFrame:SetAlpha.
  local roleIconGlowSize = roleIconSize * 0.88
  local roleIconGlowFrame = CreateFrame("Frame", nil, inner)
  roleIconGlowFrame:SetSize(roleIconGlowSize, roleIconGlowSize)
  roleIconGlowFrame:SetPoint("CENTER", slice.roleIcon, "CENTER", -1, 1)
  roleIconGlowFrame:Hide()
  slice.roleIconGlowFrame = roleIconGlowFrame

  slice.roleIconGlow = roleIconGlowFrame:CreateTexture(nil, "OVERLAY")
  slice.roleIconGlow:SetDrawLayer("OVERLAY", 1)
  slice.roleIconGlow:SetAllPoints()
  slice.roleIconGlow:SetAtlas("dragonflight-landingbutton-circleglow")
  slice.roleIconGlow:SetVertexColor(HB_GLOW_R, HB_GLOW_G, HB_GLOW_B, 1)
  slice.roleIconGlow:SetBlendMode("ADD")
  slice.roleIconGlowBaseA = 0

  -- Mind-controlled / possessed: DeclineMark X fades in/out over the regular role icon.
  slice.roleIconControlled = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIconControlled:SetDrawLayer("OVERLAY", 2)
  slice.roleIconControlled:SetAtlas(
    (CM.Constants.PartyRadialRoleAtlases and CM.Constants.PartyRadialRoleAtlases.controlled)
      or "UI-LFG-DeclineMark"
  )
  slice.roleIconControlled:SetSize(roleIconSize * 0.7, roleIconSize * 0.7)
  slice.roleIconControlled:SetPoint("CENTER", slice.roleIcon, "CENTER", -1, 0)
  slice.roleIconControlled:SetVertexColor(1, 1, 1, 1)
  slice.roleIconControlled:Hide()
  slice.roleIconControlledActive = false

  -- Role icon hover border (UI-LFG-RoleIcon-Incentive from interface/lfgframe/uilfgprompts)
  -- Overlays the role icon for the currently moused-over slice only.
  slice.roleIconBorder = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIconBorder:SetDrawLayer("OVERLAY", 3)
  slice.roleIconBorder:SetAtlas("UI-LFG-RoleIcon-Incentive")
  slice.roleIconBorder:SetSize(roleIconSize, roleIconSize)
  slice.roleIconBorder:SetPoint("TOP", inner, "TOP", 0, -4)
  slice.roleIconBorder:Hide()

  -- Role icon checkmark (UI-LFG-ReadyMark from interface/lfgframe/uilfgprompts)
  -- Overlays the role icon when this slice's unit is the current target.
  slice.roleIconCheckmark = inner:CreateTexture(nil, "OVERLAY")
  slice.roleIconCheckmark:SetDrawLayer("OVERLAY", 4)
  slice.roleIconCheckmark:SetAtlas("UI-LFG-ReadyMark")
  slice.roleIconCheckmark:SetSize(roleIconSize * 0.7, roleIconSize * 0.7) -- smaller so it sits inside the role icon
  slice.roleIconCheckmark:SetPoint("CENTER", slice.roleIcon, "CENTER", 0, 0)
  slice.roleIconCheckmark:Hide()

  -- Name text (below role icon so it doesn't overlap when icon size increases)
  slice.nameText = inner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  slice.nameText:SetPoint("TOP", slice.roleIcon, "BOTTOM", 0, -2)
  slice.nameText:SetTextColor(1, 1, 1, 1)

  -- Smooth scale on hover via innerFrame (combat-safe).
  -- targetScale/scaleStart track the hover animation; applied to innerFrame, not the secure slice.
  slice.targetScale = 1.0 -- inner frame starts at 1.0 (config scale is on the secure slice)
  slice.scaleStart = 1.0
  slice.scaleElapsed = -1 -- -1 = idle, 0+ = animating

  -- Visual feedback on mouse enter/leave: scale slice instead of yellow highlight.
  -- Spell casting uses type="macro" with macrotext="/cast [@unit] Spell"
  -- set by UpdateSliceActionAttributes(), triggered by hardware mouse clicks.
  slice:HookScript("PostClick", function(self, btn, down)
    CM.DebugPrint(
      "Party Radial: PostClick slice "
        .. self.sliceIndex
        .. " btn="
        .. tostring(btn)
        .. " unit="
        .. tostring(self:GetAttribute("unit"))
    )
    -- Close radial on non-left/right clicks (e.g. Mouse4/Mouse5 tap-to-toggle)
    if down and btn ~= "LeftButton" and btn ~= "RightButton" then
      CM.DebugPrint("Party Radial: Slice received " .. tostring(btn) .. ", closing radial")
      HR.Hide()
    end
  end)
  -- Selection is driven by cursor angle in TrackMousePosition (traditional pie-style radial), not OnEnter/OnLeave.
  -- Slices remain clickable for casting.

  -- Keep slices always :Show() so they work in combat (Hide/Show is protected).
  -- mainFrame (parent) uses SetAlpha(0/1) to toggle radial visibility,
  -- which propagates to child slices automatically.
  -- Start with EnableMouse(false) since the radial starts hidden; SetSliceMouseEnabled
  -- toggles this when the radial shows/hides (out of combat only).
  slice:SetAlpha(0)
  slice:EnableMouse(false)

  GetState().sliceFrames[sliceIndex] = slice
  return slice
end

local function SetSliceMouseEnabled(enabled)
  if InCombatLockdown() then
    return -- Can't toggle EnableMouse / hit rects during combat on secure frames
  end
  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice then
      slice:EnableMouse(enabled)
      -- Collapse hit rects when inactive so a free cursor cannot click invisible slices.
      -- SetHitRectInsets is also protected in combat (silently fails on secure frames).
      if slice.SetHitRectInsets then
        if enabled then
          slice:SetHitRectInsets(0, 0, 0, 0)
        else
          local w = slice.GetWidth and slice:GetWidth() or 100
          local h = slice.GetHeight and slice:GetHeight() or 100
          slice:SetHitRectInsets(w, w, h, h)
        end
      end
    end
  end
  if GetState().closeButton then
    GetState().closeButton:EnableMouse(enabled)
  end
end

local function UpdateMainFramePosition()
  if not GetState().mainFrame then
    return
  end
  -- SetPoint on mainFrame is protected during combat (secure descendants), so only
  -- update out of combat. In combat, the position is already set from last Show().
  if not InCombatLockdown() then
    local ox, oy = GetCrosshairAnchorOffsetForUIParent()
    GetState().mainFrame:ClearAllPoints()
    GetState().mainFrame:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
  end
end

-- Update slice positions when layout needs a refresh (fixed radius + scale)
-- SetPoint is protected on secure frames during combat, so we queue updates if needed
local function UpdateSlicePositionsAndSizes()
  if not GetState().sliceFrames or not GetState().mainFrame then
    return
  end

  local config = CM.DB.global.partyRadial
  if not config then
    return
  end

  local radius = SLICE_RADIUS
  local sliceScale = SLICE_SCALE

  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice then
      local sliceData = CM.Constants.PartyRadialSlices[i]
      if sliceData then
        local angle = sliceData.angle
        local anchor, offsetX, offsetY = GetSliceInnerAnchor(angle, radius)

        -- SetScale, ClearAllPoints, SetPoint are all protected on secure frames in combat
        if not InCombatLockdown() then
          slice:SetScale(sliceScale)
          slice:ClearAllPoints()
          slice:SetPoint(anchor, GetState().mainFrame, "CENTER", offsetX, offsetY)
        else
          GetState().pendingUpdate = true
        end
      end
    end
  end
end

local function CreateMainFrame()
  -- Architecture: mainFrame (always shown) → slices (SecureActionButtonTemplate)
  --
  -- mainFrame has secure descendants (slices), so Show/Hide, SetPoint, ClearAllPoints
  -- are ALL protected on it during InCombatLockdown(). We use SetAlpha(0/1) for
  -- visibility toggling (always combat-safe).
  --
  -- Click-through prevention for hidden slices: out of combat, we toggle
  -- EnableMouse(false) + collapsed SetHitRectInsets when hiding, and restore when
  -- showing. In combat both are protected on SecureActionButton frames, so
  -- OnCombatStart pre-arms mouse only when the feature is enabled (combat-open
  -- readiness). While combat + inactive + mouse armed, free-cursor click-steal
  -- remains possible until PLAYER_REGEN_ENABLED disables mouse again.
  local mainFrame = CreateFrame("Frame", "CombatModePartyRadialFrame", UIParent)
  mainFrame:SetFrameStrata("DIALOG")
  mainFrame:SetSize(400, 400)
  local ox, oy = GetCrosshairAnchorOffsetForUIParent()
  mainFrame:SetPoint("CENTER", UIParent, "CENTER", ox, oy)
  mainFrame:SetAlpha(0)
  mainFrame:EnableMouse(false)
  mainFrame:Show()

  -- Wheel background (Radial_Wheel_BG from interface/radialwheel/uiradialwheel), ~30% larger than frame
  local wheelBG = mainFrame:CreateTexture(nil, "BACKGROUND")
  wheelBG:SetAtlas("Radial_Wheel_BG")
  local frameSize = 400
  wheelBG:SetSize(frameSize * 1.3, frameSize * 1.3)
  wheelBG:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  wheelBG:SetShown(CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground)
  GetState().wheelBG = wheelBG

  GetState().mainFrame = mainFrame

  -- Refresh slice visuals (e.g. target checkmark) when the player's target changes
  mainFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
  mainFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_TARGET_CHANGED" and HR.UpdateAllSlices then
      HR.UpdateAllSlices()
    end
  end)

  -- Center arrow: static BG with rotating pointer on top. Fixed size and opacity (not tied to crosshair).
  local centerSize = CENTER_FIXED_SIZE
  local arrowFrame = CreateFrame("Frame", nil, mainFrame)
  arrowFrame:SetSize(centerSize, centerSize)
  arrowFrame:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  arrowFrame:SetFrameStrata("DIALOG")
  arrowFrame:SetFrameLevel(2)
  arrowFrame:SetAlpha(1.0)
  -- Static background (Ping_OVMarker_Pointer_BG from interface/radialwheel/uipingsystem2x, 47x47)
  local centerBGScale = 0.7 -- BG, close icon, and Select_Close use this scale relative to frame
  local arrowBG = arrowFrame:CreateTexture(nil, "BACKGROUND")
  arrowBG:SetAtlas("Ping_OVMarker_Pointer_BG")
  arrowBG:SetSize(centerSize * centerBGScale, centerSize * centerBGScale)
  arrowBG:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  -- Static close icon (Radial_Wheel_Icon_Close from interface/radialwheel/uiradialwheel), always visible
  local centerIconClose = arrowFrame:CreateTexture(nil, "ARTWORK")
  centerIconClose:SetAtlas("Radial_Wheel_Icon_Close")
  centerIconClose:SetSize(centerSize * centerBGScale * 0.5, centerSize * centerBGScale * 0.5) -- half of BG size
  centerIconClose:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  -- Select-close state (Radial_Wheel_Select_Close), shown when cursor over dead center instead of rotating arrow
  local centerSelectClose = arrowFrame:CreateTexture(nil, "ARTWORK")
  centerSelectClose:SetAtlas("Radial_Wheel_Select_Close")
  centerSelectClose:SetSize(centerSize * centerBGScale * 1.15, centerSize * centerBGScale * 1.15) -- slightly larger than BG
  centerSelectClose:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  centerSelectClose:Hide()
  -- Rotating pointer (Ping_OVMarker_Pointer_Assist from interface/radialwheel/uiradialwheel, 75x75)
  local arrowTex = arrowFrame:CreateTexture(nil, "OVERLAY")
  arrowTex:SetAtlas("Ping_OVMarker_Pointer_Assist")
  arrowTex:SetSize(centerSize * 1.25, centerSize * 1.25) -- larger than BG so it extends beyond
  arrowTex:SetPoint("CENTER", arrowFrame, "CENTER", 0, 0)
  GetState().centerArrowFrame = arrowFrame
  GetState().centerArrowTexture = arrowTex
  GetState().centerArrowBG = arrowBG
  GetState().centerBGScale = centerBGScale
  GetState().centerIconClose = centerIconClose
  GetState().centerSelectClose = centerSelectClose

  -- Arrow lock-in animation state (similar to crosshair lock-in animation)
  arrowFrame.arrowLockInElapsed = -1 -- -1 = idle, 0+ = animating
  arrowFrame.arrowLockInIsUnlocking = false
  arrowFrame.arrowLockInStartingScale = 1.0
  arrowFrame.arrowLockInStartingAlpha = 1.0
  arrowFrame.arrowLockInTargetScale = 1.0
  arrowFrame.arrowLockInTargetAlpha = 1.0
  arrowFrame.arrowLockInOriginalScale = 1.0
  arrowFrame.arrowLockInOriginalAlpha = 1.0

  -- Arrow lock-in animation update function (similar to crosshair lock-in)
  local ARROW_LOCK_IN_DURATION = 0.25
  local ARROW_UNLOCK_DURATION = 0.2
  arrowFrame:SetScript("OnUpdate", function(self, elapsed)
    if self.arrowLockInElapsed == -1 then
      return
    end

    local duration = self.arrowLockInIsUnlocking and ARROW_UNLOCK_DURATION or ARROW_LOCK_IN_DURATION
    self.arrowLockInElapsed = self.arrowLockInElapsed + elapsed

    if self.arrowLockInElapsed > duration then
      if self.arrowLockInIsUnlocking then
        -- Unlock phase 1 complete (shrunk), now bounce back to original
        self.arrowLockInIsUnlocking = false
        self.arrowLockInStartingScale = self.arrowLockInTargetScale
        self.arrowLockInStartingAlpha = self.arrowLockInTargetAlpha
        self.arrowLockInTargetScale = self.arrowLockInOriginalScale
        self.arrowLockInTargetAlpha = self.arrowLockInOriginalAlpha
        local remainder = self.arrowLockInElapsed - duration
        self.arrowLockInElapsed = remainder
        duration = ARROW_UNLOCK_DURATION * 0.5
      else
        -- Animation complete
        self.arrowLockInElapsed = -1
        self:SetScale(self.arrowLockInTargetScale)
        self:SetAlpha(self.arrowLockInTargetAlpha)
        return
      end
    end

    local progress = self.arrowLockInElapsed / duration
    local easedProgress = 1 - (1 - progress) * (1 - progress)

    local currentScale = self.arrowLockInStartingScale
      + (self.arrowLockInTargetScale - self.arrowLockInStartingScale) * easedProgress
    self:SetScale(currentScale)

    local currentAlpha = self.arrowLockInStartingAlpha
      + (self.arrowLockInTargetAlpha - self.arrowLockInStartingAlpha) * easedProgress
    self:SetAlpha(currentAlpha)
  end)

  -- Center close button: an invisible secure button covering the dead zone (30px radius).
  -- Clicking the center X clears the current target, closes the radial, and re-engages
  -- mouselook (left/right). ClearTarget must be secure — use macrotext /cleartarget.
  local CENTER_DEAD_ZONE_PX = 30
  local closeBtn = CreateFrame("Button", nil, mainFrame, "SecureActionButtonTemplate")
  closeBtn:SetSize(CENTER_DEAD_ZONE_PX * 2, CENTER_DEAD_ZONE_PX * 2)
  closeBtn:SetPoint("CENTER", mainFrame, "CENTER", 0, 0)
  closeBtn:SetFrameStrata("DIALOG")
  closeBtn:SetFrameLevel(arrowFrame:GetFrameLevel() + 10) -- Above slices so it catches clicks first
  closeBtn:RegisterForClicks("AnyDown")
  closeBtn:SetAttribute("type", "macro")
  closeBtn:SetAttribute("macrotext", "/cleartarget")
  closeBtn:EnableMouse(false) -- Toggled by SetSliceMouseEnabled alongside slices
  closeBtn:HookScript("PostClick", function(_, button)
    if button == "LeftButton" or button == "RightButton" then
      CM.LockFreeLook()
      HR.Hide()
    else
      -- Non-left/right (e.g. Mouse5 tap-to-toggle): just close the radial
      HR.Hide()
    end
  end)
  GetState().closeButton = closeBtn

  -- Create slice frames (parented to mainFrame so they inherit alpha/position).
  for i = 1, 5 do
    CreateSliceFrame(i)
  end
end

local function UpdateSliceVisual(sliceIndex)
  local slice = GetState().sliceFrames[sliceIndex]
  local config = CM.DB.global.partyRadial

  -- Find member assigned to this slice
  local memberData = nil
  for _, member in ipairs(GetVisualPartyData()) do
    if member.sliceIndex == sliceIndex then
      memberData = member
      break
    end
  end

  local isPlaceholder = memberData and memberData.isPreview
  if not memberData or (not isPlaceholder and not UnitExists(memberData.unitId)) then
    -- Use alpha only (not Hide/Show or EnableMouse) to avoid protected frame errors in combat
    slice:SetAlpha(0)
    return
  end

  -- Show visually via alpha (combat-safe)
  slice:SetAlpha(1)

  -- Determine if unit is reachable (in range).
  -- Dim out-of-range slices via innerFrame alpha so the user can see at a glance
  -- who can be targeted. Player is always reachable (you can always heal yourself).
  --
  -- UnitInRange returns tainted booleans in combat — boolean tests (if/and/or/tostring)
  -- all propagate taint and error. C_CurveUtil.EvaluateColorFromBoolean (added 12.0.0)
  -- accepts a tainted boolean and returns a ColorMixin whose fields reflect the boolean
  -- without triggering taint errors. We encode reachable=alpha 1.0, unreachable=alpha 0.4
  -- in the colors, then apply the .a field via SetAlpha (which accepts secret numbers).
  if slice.innerFrame and EvaluateColorFromBoolean then
    if isPlaceholder or memberData.unitId == "player" then
      slice.innerFrame:SetAlpha(1.0)
    else
      local inRange = UnitInRange(memberData.unitId)
      local rangeColor = EvaluateColorFromBoolean(inRange, COLOR_REACHABLE, COLOR_UNREACHABLE)
      slice.innerFrame:SetAlpha(rangeColor.a)
    end
  end

  -- Update name (class-coloured; show "You" for the player; font/size with drop shadow; always shown)
  local fontSize = NAME_FONT_SIZE
  -- Always use drop shadow (no outline); locale-safe font (same as GameFontNormalSmall resolution)
  CM.SetFontStringFromTemplate(slice.nameText, fontSize, _G.GameFontNormalSmall)
  slice.nameText:SetShadowColor(0, 0, 0, 1)
  slice.nameText:SetShadowOffset(1, -1)
  local displayName = (not isPlaceholder and memberData.unitId == "player") and "You"
    or (memberData.name or "Unknown")
  if issecretvalue and issecretvalue(displayName) then
    displayName = SECRET_NAME_PLACEHOLDER
  else
    displayName = TruncateUtf8Name(displayName, 10, 9, "...")
  end
  local color = (memberData.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[memberData.class])
      and RAID_CLASS_COLORS[memberData.class]
    or { r = 1, g = 1, b = 1 }
  slice.nameText:SetTextColor(color.r, color.g, color.b, 1)
  slice.nameText:SetText(displayName)
  slice.nameText:Show()
  UpdateSliceHealthBar(slice, config, memberData, sliceIndex, isPlaceholder)

  -- Update role icon backdrop (centered on role icon, extends beyond for shadow)
  local size = ROLE_ICON_SIZE
  slice.roleIconBG:SetSize(size * 1.5, size * 1.5)

  -- Update role icon (always shown when role is known)
  slice.roleIcon:SetSize(size, size)
  if slice.roleIconGlowFrame then
    slice.roleIconGlowFrame:SetSize(size * 0.88, size * 0.88)
  end
  if slice.roleIconControlled then
    slice.roleIconControlled:SetSize(size * 0.7, size * 0.7)
  end
  if slice.roleIconBorder then
    slice.roleIconBorder:SetSize(size, size)
  end
  if slice.roleIconCheckmark then
    local checkSize = size * 0.7 -- smaller so it sits inside the role icon
    slice.roleIconCheckmark:SetSize(checkSize, checkSize)
  end

  local atlas, usedDisabledAtlas, showControlledOverlay = ResolveRoleIconAtlas(
    memberData.role,
    memberData.unitId,
    memberData.class,
    isPlaceholder,
    memberData
  )
  if atlas then
    slice.roleIcon:SetAtlas(atlas)
    if slice.roleIcon.SetDesaturated then
      slice.roleIcon:SetDesaturated(false)
    end
    -- Disabled atlases already encode dead; keep vertex white.
    -- When dead bool is secret we could not swap to Disabled — grey the normal atlas.
    if usedDisabledAtlas or showControlledOverlay or isPlaceholder or not UnitIsDeadOrGhost then
      slice.roleIcon:SetVertexColor(1, 1, 1, 1)
    elseif EvaluateColorFromBoolean then
      local isDead = UnitIsDeadOrGhost(memberData.unitId)
      local iconColor = EvaluateColorFromBoolean(isDead, COLOR_ICON_DEAD, COLOR_ICON_ALIVE)
      slice.roleIcon:SetVertexColor(iconColor.r, iconColor.g, iconColor.b, iconColor.a)
    else
      -- Pre-12 fallback: PublicBool before branching (do not truth-test secret dead).
      local deadPublic = RoleIcons.PublicBool
        and RoleIcons.PublicBool(UnitIsDeadOrGhost(memberData.unitId))
      if deadPublic == true then
        slice.roleIcon:SetVertexColor(0.45, 0.45, 0.45, 1)
      else
        slice.roleIcon:SetVertexColor(1, 1, 1, 1)
      end
    end
    slice.roleIcon:Show()
    slice.roleIconBG:Show()
    slice.roleIconControlledActive = showControlledOverlay and true or false
    if slice.roleIconControlled then
      if showControlledOverlay then
        slice.roleIconControlled:Show()
      else
        slice.roleIconControlled:Hide()
      end
    end
    UpdateRoleIconLowHealthGlow(slice, memberData, isPlaceholder, true)
    -- Show checkmark when this slice's unit is the current target
    if slice.roleIconCheckmark then
      if not isPlaceholder and UnitIsUnit(memberData.unitId, "target") then
        slice.roleIconCheckmark:Show()
      else
        slice.roleIconCheckmark:Hide()
      end
    end
  else
    slice.roleIcon:Hide()
    slice.roleIconBG:Hide()
    slice.roleIconControlledActive = false
    if slice.roleIconControlled then
      slice.roleIconControlled:Hide()
    end
    UpdateRoleIconLowHealthGlow(slice, memberData, isPlaceholder, false)
    if slice.roleIconCheckmark then
      slice.roleIconCheckmark:Hide()
    end
  end
end

local function UpdateAllSlices()
  for i = 1, 5 do
    UpdateSliceVisual(i)
  end
end

local function HighlightSlice(sliceIndex)
  -- Start scale transition on the inner visual frame: grow selected by 10%, others back to 1.0.
  -- The inner frame is a regular (non-secure) Frame, so SetScale is always combat-safe.
  -- Hover scale is on innerFrame (slice frame itself stays at fixed SLICE_SCALE).
  local BASE_INNER = 1.0
  local HOVER_INNER = 1.1

  for i = 1, 5 do
    local slice = GetState().sliceFrames[i]
    if slice and slice.innerFrame then
      slice.scaleStart = slice.innerFrame:GetScale()
      if i == sliceIndex and slice:GetAlpha() > 0 then
        slice.targetScale = HOVER_INNER
      else
        slice.targetScale = BASE_INNER
      end
      slice.scaleElapsed = 0
    end
    -- Show role icon incentive border only on the moused-over slice
    if slice and slice.roleIconBorder then
      if sliceIndex and i == sliceIndex and slice:GetAlpha() > 0 then
        slice.roleIconBorder:Show()
      else
        slice.roleIconBorder:Hide()
      end
    end
  end
end

local function ApplyVisualConfig()
  if not GetState().mainFrame then
    return
  end
  UpdateSlicePositionsAndSizes()
  if GetState().wheelBG then
    GetState().wheelBG:SetShown(
      CM.DB.global.partyRadial and CM.DB.global.partyRadial.showBackground
    )
  end
  if GetState().isActive or GetState().optionsPreviewActive then
    UpdateAllSlices()
  end
end

Visual.GetCrosshairAnchorOffsetForUIParent = GetCrosshairAnchorOffsetForUIParent
Visual.GetCrosshairCenterScreenXY = GetCrosshairCenterScreenXY
Visual.GetMouseAngleAndDistanceFromCenter = GetMouseAngleAndDistanceFromCenter
Visual.GetSliceFromAngle = GetSliceFromAngle
Visual.GetSliceInnerAnchor = GetSliceInnerAnchor
Visual.CreateSliceFrame = CreateSliceFrame
Visual.CreateMainFrame = CreateMainFrame
Visual.SetSliceMouseEnabled = SetSliceMouseEnabled
Visual.UpdateMainFramePosition = UpdateMainFramePosition
Visual.UpdateSlicePositionsAndSizes = UpdateSlicePositionsAndSizes
Visual.UpdateSliceVisual = UpdateSliceVisual
Visual.UpdateAllSlices = UpdateAllSlices
Visual.HighlightSlice = HighlightSlice
Visual.ApplyVisualConfig = ApplyVisualConfig
