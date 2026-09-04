---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabCamera.lua — OPTIONS TAB — Action Camera situations + vignette
---------------------------------------------------------------------------------------
--  What it does: Wires Action Camera preset toggle (reload), actionCamMouselookDisable,
--  max zoom, vertical pitch, vignette, and a three-segment panel (Base / Mounted / Combat)
--  for per-situation camera settings. Target Focus Enemy CVar follows UnitExists("focus")
--  (Target Lock / cycle / auto-lock). Reactive zoom is always on when Action Camera
--  is enabled; zoom scroll speed and situation transition duration are hardcoded.
--  Architecture / how it works:
--    • When DynamicCam is loaded, a single host watermark covers the whole Action Camera
--      block (no per-control greying or row stamps).
--    • Shared controls (Enable Preset, Disable with Mouse Look, Max Zoom, Vertical Pitch,
--      Vignette) sit above the Base / Combat / Mounted segment bar. Vignette is gated on
--      the Action Camera preset (UI + runtime); it is not a standalone effect.
--    • Vignette fade-with-mouselook is derived from actionCamMouselookDisable — no separate
--      toggle; Vignette.lua reads actionCamera + actionCamMouselookDisable at runtime.
--    • Segment bar pattern matches TabClickCasting (BuildSegmentBar / StyleSegment / ShowGroup
--      with UI.FadeAlpha crossfade).
--    • Per-segment sliders read/write CM.DB.global.actionCameraProfiles[id].*
--      and call CM.ActionCamera.ApplyProfile(id) immediately if that profile is active.
--    • DB: global.actionCamera, actionCamMouselookDisable, actionCameraMaxZoom,
--      actionCameraDynamicPitch, vignette; actionCameraProfiles.{base,mounted,combat}.
--  Does not: Own CVar preset tables (Constants/CVars), freelook lock, or easing math.
--  Related: Core/ActionCamera/SituationDriver.lua, Core/ActionCamera/Transition.lua,
--  Core/ActionCamera/ReactiveZoom.lua, Constants/ActionCamera.lua,
--  Core/Runtime/CVarManager.lua, Constants/DatabaseDefaults.lua, Core/Vignette.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local ReloadUI = _G.ReloadUI

local UI = CM.UI
local C = UI.Colors

local RELOAD_CONFIRM = "A UI Reload is required when making this change. Proceed?"

-- -----------------------------------------------------------------------
-- Segment bar (same pattern as TabClickCasting)
-- -----------------------------------------------------------------------

local SEGMENT_FADE = 0.16

local function StyleSegment(button, selected)
  if selected then
    button:cmSetFill(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
    button:cmSetBorder(0, 0, 0, 0)
    button.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  else
    button:cmSetFill(0, 0, 0, 0)
    button:cmSetBorder(0, 0, 0, 0)
    button.label:SetTextColor(C.textDim[1], C.textDim[2], C.textDim[3])
  end
end

local function BuildSegmentBar(parent, width, groups, onSelect)
  local barH = 28
  local gap = 4
  local n = #groups
  local btnW = (width - gap * (n - 1)) / n
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(width, barH)

  local buttons = {}
  local selectedId = groups[1].id
  local x = 0

  local function Select(id)
    selectedId = id
    for _, button in _G.ipairs(buttons) do
      StyleSegment(button, button.groupId == id)
    end
    onSelect(id)
  end

  for _, group in _G.ipairs(groups) do
    local button = CreateFrame("Button", nil, bar)
    button:SetSize(btnW, barH)
    button:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
    UI.StyleRounded(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)
    button.groupId = group.id

    local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.base, "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetText(group.label)
    button.label = label

    button:SetScript("OnClick", function()
      Select(group.id)
    end)
    button:SetScript("OnEnter", function(self)
      if self.groupId ~= selectedId then
        self:cmSetFill(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
      end
    end)
    button:SetScript("OnLeave", function(self)
      StyleSegment(self, self.groupId == selectedId)
    end)

    buttons[#buttons + 1] = button
    x = x + btnW + gap
  end

  Select(selectedId)
  return bar, Select
end

-- -----------------------------------------------------------------------
-- Per-situation panel builder
-- -----------------------------------------------------------------------

local function IsACDisabled()
  -- DynamicCam uses a single host watermark instead of greying every control.
  return not CM.DynamicCam and CM.DB.global.actionCamera ~= true
end

-- Write a value to the active profile and apply live if it matches the current situation.
local function SetProfileValue(id, key, value)
  -- Ensure the top-level profiles table exists.
  if type(CM.DB.global.actionCameraProfiles) ~= "table" then
    CM.DB.global.actionCameraProfiles = {}
  end
  local profiles = CM.DB.global.actionCameraProfiles
  -- Ensure this specific profile sub-table exists (seed from defaults if needed).
  if type(profiles[id]) ~= "table" then
    local def = CM.Constants.ActionCameraProfileDefaults
    local src = (def and def[id]) or (def and def.base) or {}
    local copy = {}
    for k, v in _G.pairs(src) do
      copy[k] = v
    end
    profiles[id] = copy
  end
  profiles[id][key] = value
  -- Live-apply if this is the currently active situation.
  if CM.ActionCamera and CM.ActionCamera.GetActiveId and CM.ActionCamera.GetActiveId() == id then
    if CM.ActionCamera.ApplyProfile then
      CM.ActionCamera.ApplyProfile(id, false)
    end
  end
end

local function GetProfileValue(id, key, default)
  local profiles = CM.DB.global.actionCameraProfiles
  if profiles and profiles[id] then
    local v = profiles[id][key]
    if v ~= nil then
      return v
    end
  end
  -- Fallback to defaults constant.
  local def = CM.Constants.ActionCameraProfileDefaults
  if def and def[id] then
    return def[id][key]
  end
  return default
end

local function BuildSituationPanel(parent, width, id)
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetWidth(width)
  local layout = UI.NewLayout(panel, width)
  layout.y = 0

  layout:Slider({
    label = "Field of View",
    desc = "The camera's field of view in this situation.",
    min = 50,
    max = 90,
    step = 1,
    get = function()
      return GetProfileValue(id, "fov", 75)
    end,
    set = function(value)
      SetProfileValue(id, "fov", value)
    end,
    disabled = IsACDisabled,
  })
  layout:Slider({
    label = "Initial Zoom",
    desc = "The distance the camera zooms to when the situation starts.",
    min = 0,
    max = 39,
    step = 1,
    get = function()
      return GetProfileValue(id, "setZoom", 0) or 0
    end,
    set = function(value)
      -- Store nil for 0 so the transition skips the zoom command.
      SetProfileValue(id, "setZoom", value > 0 and value or nil)
    end,
    disabled = IsACDisabled,
  })
  layout:Slider({
    label = "Shoulder Offset",
    desc = "Camera's horizontal position relative to character's shoulder.",
    min = -2,
    max = 2,
    step = 0.1,
    get = function()
      return GetProfileValue(id, "shoulder", 1.2)
    end,
    set = function(value)
      SetProfileValue(id, "shoulder", value)
    end,
    disabled = IsACDisabled,
  })
  layout:Slider({
    label = "Head Tracking Strength",
    desc = "How strongly the camera follows the character's head movement.",
    min = 0,
    max = 2,
    step = 0.1,
    get = function()
      return GetProfileValue(id, "headTracking", 1)
    end,
    set = function(value)
      SetProfileValue(id, "headTracking", value)
    end,
    disabled = IsACDisabled,
  })

  layout:Finish()
  panel:SetHeight(-layout.y + 8)
  return panel
end

-- -----------------------------------------------------------------------
-- Tab registration
-- -----------------------------------------------------------------------

local SITUATION_GROUPS = {
  { id = "base", label = "Base" },
  { id = "combat", label = "Combat" },
  { id = "mounted", label = "Mounted" },
}

UI.Options.AddTab({
  id = "camera",
  label = "Action Camera",
  build = function(ctx)
    ctx:Header("ACTION CAMERA")

    -- Plain host (no card chrome) so DynamicCam can stamp the whole block.
    local host = CreateFrame("Frame", nil, ctx.content)
    host:SetWidth(ctx.width)
    local topLayout = UI.NewLayout(host, ctx.width)
    topLayout.y = 0

    -- Shared controls above segment bar.
    topLayout:Toggle({
      label = "Action Camera Preset",
      desc = "Use Combat Mode's curated settings for a more dynamic & immersive camera.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.global.actionCamera
      end,
      set = function(value)
        CM.DB.global.actionCamera = value
        if value then
          CM.ConfigActionCamera("combatmode")
        else
          CM.ConfigActionCamera("blizzard")
        end
        ReloadUI()
      end,
    })
    topLayout:Toggle({
      label = "Disable with Mouse Look",
      desc = "Automatically turns off Action Camera effects with Mouse Look.",
      confirm = true,
      confirmText = RELOAD_CONFIRM,
      get = function()
        return CM.DB.global.actionCamMouselookDisable
      end,
      set = function(value)
        CM.DB.global.actionCamMouselookDisable = value
        ReloadUI()
      end,
      disabled = function()
        return IsACDisabled()
      end,
    })
    topLayout:Toggle({
      label = "Vignette Effect",
      desc = "Darkens the edges of the screen for a more focused view.",
      get = function()
        return CM.DB.global.vignette
      end,
      set = function(value)
        CM.SetVignetteEnabled(value)
      end,
      disabled = function()
        return IsACDisabled()
      end,
    })
    topLayout:Toggle({
      label = "Dynamic Pitch",
      desc = "Allows the camera to dynamically tilt up and down as you move it.",
      get = function()
        return CM.DB.global.actionCameraDynamicPitch ~= false
      end,
      set = function(value)
        CM.DB.global.actionCameraDynamicPitch = value
        if CM.ActionCamera and CM.ActionCamera.ApplySharedCVars then
          CM.ActionCamera.ApplySharedCVars()
        end
      end,
      disabled = function()
        return IsACDisabled()
      end,
    })
    topLayout:Slider({
      label = "Max Zoom Distance",
      desc = "Sets how far the camera can zoom away from the character.",
      min = 15,
      max = 39,
      step = 1,
      get = function()
        return CM.DB.global.actionCameraMaxZoom or 20
      end,
      set = function(value)
        CM.DB.global.actionCameraMaxZoom = value
        if CM.ActionCamera and CM.ActionCamera.ApplySharedCVars then
          CM.ActionCamera.ApplySharedCVars()
        end
      end,
      disabled = function()
        return IsACDisabled()
      end,
    })

    -- Segment bar host — sits directly below the shared controls.
    local segHostY = topLayout.y - 8
    topLayout:Finish()

    local segY = segHostY

    -- Build all three situation panels first (ShowGroup defined below).
    local panels = {}
    for _, group in _G.ipairs(SITUATION_GROUPS) do
      local panel = BuildSituationPanel(host, ctx.width, group.id)
      panel:Hide()
      panels[group.id] = panel
    end

    local function ShowGroup(id)
      for _, group in _G.ipairs(SITUATION_GROUPS) do
        local panel = panels[group.id]
        if group.id == id then
          panel:Show()
          UI.FadeAlpha(panel, 1, SEGMENT_FADE)
        else
          -- Must Hide() inactive panels — WoW frames at alpha 0 still receive
          -- mouse input, so fading alone lets the wrong slider capture clicks.
          panel:Hide()
          panel:SetAlpha(0)
        end
      end
    end

    local segBar = BuildSegmentBar(host, ctx.width, SITUATION_GROUPS, ShowGroup)
    segBar:SetPoint("TOPLEFT", host, "TOPLEFT", 0, segY - 4)

    -- Hairline under the preset tabs (same treatment as Click Casting).
    local sepGap = 8
    local sep = host:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 1, 1, 0.06)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", segBar, "BOTTOMLEFT", 0, -sepGap)
    sep:SetPoint("TOPRIGHT", segBar, "BOTTOMRIGHT", 0, -sepGap)

    for _, panel in _G.pairs(panels) do
      panel:ClearAllPoints()
      panel:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -sepGap)
    end
    ShowGroup("base")

    -- Compute host height from tallest panel.
    local tallest = 0
    for _, panel in _G.pairs(panels) do
      local h = panel:GetHeight()
      if h > tallest then
        tallest = h
      end
    end
    local hostH = -segHostY + 4 + 28 + sepGap + 1 + sepGap + tallest
    host:SetHeight(hostH)
    ctx:PlaceFrame(host, hostH)

    if CM.DynamicCam then
      UI.CreateWatermark(host, "Control relinquished to DynamicCam"):Show()
    end
  end,
})
