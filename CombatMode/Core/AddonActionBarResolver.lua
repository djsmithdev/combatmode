---------------------------------------------------------------------------------------
--  Core/AddonActionBarResolver.lua — Third-party action bar resolver
---------------------------------------------------------------------------------------
-- Resolves multiactionbar bindings (MULTIACTIONBAR*BUTTONn) to the correct
-- third-party addon button frame by matching the underlying Blizzard action-slot id.
--
-- This avoids relying on static addon bar-number assumptions when users use
-- non-standard bar layouts (ElvUI / Bartender4).
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

-- Lua stdlib
local tonumber = _G.tonumber
local pairs = _G.pairs
local pcall = _G.pcall

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

  local actionId = GetButtonActionId(baseFrameName)
  if not actionId then
    return nil
  end

  -- ElvUI: resolve by matching Blizzard action slot id.
  if _G["ElvUI_Bar1Button1"] then
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
    local cached = bt4ActionToButtonCache[actionId]
    if cached then
      return cached
    end

    local bt4BarId = BT4_BINDING_PREFIX_TO_BAR_ID[prefix]
    if bt4BarId then
      local bt4Fast = "BT4Button" .. ((bt4BarId - 1) * 12 + btnIdx)
      if _G[bt4Fast] and GetButtonActionId(bt4Fast) == actionId then
        bt4ActionToButtonCache[actionId] = bt4Fast
        return bt4Fast
      end
    end

    local bt4Name = FindBT4ButtonByAction(actionId, btnIdx)
    if bt4Name then
      bt4ActionToButtonCache[actionId] = bt4Name
      return bt4Name
    end
  end

  return nil
end
