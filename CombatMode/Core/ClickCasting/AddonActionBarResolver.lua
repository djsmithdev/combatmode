---------------------------------------------------------------------------------------
--  Core/ClickCasting/AddonActionBarResolver.lua — CLICKCAST — ElvUI/BT4 button resolve
---------------------------------------------------------------------------------------
--  What it does: Maps ACTIONBUTTON / MULTIACTIONBAR1–7 slot ids to third-party action-bar
--  button frame names (ElvUI, Bartender4, Dominos) and applies third-party policy that
--  forces macroInjectionClickCastOnly when those addons are loaded.
--  Architecture / how it works:
--    • Action-slot bases from CM.Constants.ClickCastBars (MultiBar5–7 = 145/157/169).
--    • Per-refresh caches: action id → button frame name; ClearAddonButtonCaches on
--      binding refresh.
--    • ResolveAddonMultiBarButtonFrameByBase — BT4 non-sequential bar ids + dynamic scan.
--    • ApplyThirdPartyActionBarPolicy — sets ThirdPartyActionBarsActive + forces
--      click-cast-only injection when needed.
--  Does not: SetOverrideBinding or build macrotext.
--  Related: Core/ClickCasting/BindingOverrides.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua,
--  UI/Options/Tabs/TabReticleTargeting.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local ipairs = _G.ipairs
local tonumber = _G.tonumber
local pairs = _G.pairs
local pcall = _G.pcall
local tostring = _G.tostring
local cAddOns = _G.C_AddOns

-- Bartender uses non-sequential bar ids (see Bartender4 ActionBars.lua).
-- Kept as a fast-path only; final selection is validated by action id.
local BT4_BINDING_PREFIX_TO_BAR_ID = {
  MULTIACTIONBAR1BUTTON = 6,
  MULTIACTIONBAR2BUTTON = 5,
  MULTIACTIONBAR3BUTTON = 3,
  MULTIACTIONBAR4BUTTON = 4,
  MULTIACTIONBAR5BUTTON = 13,
  MULTIACTIONBAR6BUTTON = 14,
  MULTIACTIONBAR7BUTTON = 15,
}

-- Upper bound for scanning BT4Button* frames on cache miss.
local BT4_DYNAMIC_SCAN_MAX = 240

-- Per-refresh caches: addon action-id -> resolved button frame name.
local elvActionToButtonCache = {}
local bt4ActionToButtonCache = {}

local IsAddOnLoadedLegacy = _G.IsAddOnLoaded
local THIRD_PARTY_ACTION_BAR_ADDONS = {
  "Bartender4",
  "Dominos",
  "ElvUI",
}

local function IsAddonLoadedByName(addonName)
  if cAddOns and cAddOns.IsAddOnLoaded then
    return cAddOns.IsAddOnLoaded(addonName) == true
  end
  if IsAddOnLoadedLegacy then
    return IsAddOnLoadedLegacy(addonName) == true
  end
  return false
end

local function DetectThirdPartyActionBars()
  for _, addonName in ipairs(THIRD_PARTY_ACTION_BAR_ADDONS) do
    if IsAddonLoadedByName(addonName) then
      return true, addonName
    end
  end
  return false, nil
end

-- Public policy helper: if supported third-party bars are detected, force
-- click-cast-only macro injection and expose a runtime flag used by Config UI.
function CM.ApplyThirdPartyActionBarPolicy()
  local hasThirdPartyBars, detectedBarAddon = DetectThirdPartyActionBars()
  CM.ThirdPartyActionBarsActive = hasThirdPartyBars
  if hasThirdPartyBars and CM.DB and CM.DB.char then
    CM.DB.char.macroInjectionClickCastOnly = true
    CM.DebugPrint(
      "Third-party action bar detected ("
        .. tostring(detectedBarAddon)
        .. "); forcing macroInjectionClickCastOnly=true."
    )
  end
end

local function GetButtonActionId(frameName)
  if not frameName or frameName == "" then
    return nil
  end
  local f = _G[frameName]
  if not f then
    return nil
  end
  local raw = f.GetAttribute and f:GetAttribute("action") or f.action
  local n = raw and tonumber(raw)
  if n and n > 0 then
    return n
  end
  return nil
end

-- For Blizzard MULTIACTIONBAR1–7 bindings, compute the canonical action-slot id
-- from the binding prefix and button index (avoids ambiguous MultiBar* action attrs).
local MULTIACTIONBAR_PREFIX_TO_ACTION_BASE = {}
do
  local bars = CM.Constants and CM.Constants.ClickCastBars
  if bars then
    for _, bar in ipairs(bars) do
      if bar.bind and bar.bind:match("^MULTIACTIONBAR") and bar.actionBase then
        MULTIACTIONBAR_PREFIX_TO_ACTION_BASE[bar.bind] = bar.actionBase
      end
    end
  else
    MULTIACTIONBAR_PREFIX_TO_ACTION_BASE = {
      MULTIACTIONBAR3BUTTON = 25,
      MULTIACTIONBAR4BUTTON = 37,
      MULTIACTIONBAR2BUTTON = 49,
      MULTIACTIONBAR1BUTTON = 61,
      MULTIACTIONBAR5BUTTON = 145,
      MULTIACTIONBAR6BUTTON = 157,
      MULTIACTIONBAR7BUTTON = 169,
    }
  end
end

local function ComputeMultiActionBarActionId(prefix, btnIdx)
  local base = MULTIACTIONBAR_PREFIX_TO_ACTION_BASE[prefix]
  if not base or not btnIdx or btnIdx < 1 or btnIdx > 12 then
    return nil
  end
  return base + (btnIdx - 1)
end

-- Scan ElvUI_Bar1..12 × Button1..12 for a button whose action slot matches actionId.
-- Prefer shown frames; tie-break by slot index (btnIdx) when multiple match.
local function FindButtonByAction(actionId, btnIdx, enumerateCandidates)
  local preferredShown
  local anyShown
  local preferredHidden
  local any

  local function consider(name, slot)
    local f = _G[name]
    if not f then
      return
    end

    local aid = GetButtonActionId(name)
    if aid ~= actionId then
      return
    end

    any = any or name
    local ok, shown = pcall(function()
      return f:IsShown()
    end)
    shown = ok and shown
    if shown then
      anyShown = anyShown or name
      if slot == btnIdx then
        preferredShown = name
      end
    elseif slot == btnIdx then
      preferredHidden = name
    end
  end

  enumerateCandidates(consider)

  if preferredShown then
    return preferredShown
  end
  if anyShown then
    return anyShown
  end
  if preferredHidden then
    return preferredHidden
  end
  return any
end

local function FindElvUIButtonByAction(actionId, btnIdx)
  local function enumerateCandidates(consider)
    for bar = 1, 12 do
      for slot = 1, 12 do
        local name = "ElvUI_Bar" .. bar .. "Button" .. slot
        consider(name, slot)
      end
    end
  end
  return FindButtonByAction(actionId, btnIdx, enumerateCandidates)
end

-- Scan BT4Button1..N for matching action id (slot within 12-bar row used as tie-breaker).
local function FindBT4ButtonByAction(actionId, btnIdx)
  local function enumerateCandidates(consider)
    for i = 1, BT4_DYNAMIC_SCAN_MAX do
      local name = "BT4Button" .. i
      local slot = ((i - 1) % 12) + 1
      consider(name, slot)
    end
  end
  return FindButtonByAction(actionId, btnIdx, enumerateCandidates)
end

-- Public: invalidate caches each refresh cycle so mapping stays correct after bar/page changes.
function CM.ClearAddonButtonCaches()
  for k in pairs(elvActionToButtonCache) do
    elvActionToButtonCache[k] = nil
  end
  for k in pairs(bt4ActionToButtonCache) do
    bt4ActionToButtonCache[k] = nil
  end
end

-- Public resolver:
-- @param prefix multiactionbar binding prefix, e.g. MULTIACTIONBAR2BUTTON
-- @param btnIdx binding slot index (1..12)
-- @param baseFrameName Blizzard base button frame name (e.g. MultiBarBottomRightButton6)
function CM.ResolveAddonMultiBarButtonFrameByBase(prefix, btnIdx, baseFrameName)
  if not prefix or not btnIdx or not baseFrameName then
    return nil
  end

  -- Bartender safety: for MULTIACTIONBAR1–7 we can compute the canonical action-slot id
  -- without relying on `MultiBar*ButtonN`'s `action` attribute.
  local expectedActionId = ComputeMultiActionBarActionId(prefix, btnIdx)
  local actionId = GetButtonActionId(baseFrameName)

  -- ElvUI: resolve by matching Blizzard action slot id.
  if _G["ElvUI_Bar1Button1"] then
    if not actionId then
      return nil
    end
    local cached = elvActionToButtonCache[actionId]
    if cached then
      return cached
    end

    local elvName = FindElvUIButtonByAction(actionId, btnIdx)
    if elvName then
      elvActionToButtonCache[actionId] = elvName
      return elvName
    end
  end

  -- Bartender: BT4_BINDING_PREFIX_TO_BAR_ID fast path, validated by action id; else full scan.
  if _G["BT4Button1"] then
    -- Under Bartender, Blizzard multibar frames can report action ids that collide with bar 1.
    -- For MULTIACTIONBAR1–7, prefer the canonical action-slot id computed from prefix+slot.
    local want = expectedActionId or actionId
    if not want then
      return nil
    end
    local bt4Key = want

    local cached = bt4ActionToButtonCache[bt4Key]
    if cached then
      return cached
    end

    local bt4BarId = BT4_BINDING_PREFIX_TO_BAR_ID[prefix]
    if bt4BarId then
      local bt4Fast = "BT4Button" .. ((bt4BarId - 1) * 12 + btnIdx)
      if _G[bt4Fast] and GetButtonActionId(bt4Fast) == want then
        bt4ActionToButtonCache[bt4Key] = bt4Fast
        return bt4Fast
      end
    end

    local bt4Name = FindBT4ButtonByAction(want, btnIdx)
    if bt4Name then
      bt4ActionToButtonCache[bt4Key] = bt4Name
      return bt4Name
    end
  end

  return nil
end
