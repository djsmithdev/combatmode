---------------------------------------------------------------------------------------
--  UI/Options/MountMultiSelect.lua — OPTIONS — mount spell ID pill multi-select
---------------------------------------------------------------------------------------
--  What it does: UI.MakeMountMultiSelect — type-ahead suggestions from the mount journal,
--  pill chips for selected mounts, storage as CSV spell IDs for Auto Cursor Unlock
--  mount list.  Thin wrapper around UI.MakePillMultiSelect in SpellMultiSelect.lua.
--  Architecture / how it works:
--    • Indexes the mount journal via C_MountJournal.GetMountIDs / GetMountInfoByID.
--    • Only shows collected mounts in suggestions.
--    • Migrates any legacy mountCheck toggle by seeding the default vendor mounts.
--  Does not: Evaluate visibility or call MouselookStop.
--  Related: UI/Options/SpellMultiSelect.lua, UI/Options/Widgets.lua,
--  Core/FreeLook/AutoCursorUnlock.lua, Constants/FrameWatch.lua,
--  UI/Options/Tabs/TabAutoCursorUnlock.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local C_MountJournal = _G.C_MountJournal

-- Lua stdlib
local ipairs = _G.ipairs
local strfind = _G.string.find
local strlower = _G.string.lower
local strtrim = _G.strtrim
local tonumber = _G.tonumber
local tostring = _G.tostring
local wipe = _G.wipe

local UI = CM.UI

---------------------------------------------------------------------------------------
--                              MOUNT JOURNAL INDEX                                  --
---------------------------------------------------------------------------------------
local mountList = {} -- { spellId, name, nameLower, icon }
local mountBySpellId = {}
local mountByName = {}
local indexDirty = true
local indexFrame

local function AddMountToIndex(spellId, name, icon)
  if not spellId or spellId <= 0 or not name or name == "" then
    return
  end
  if mountBySpellId[spellId] then
    return
  end
  local entry = {
    spellId = spellId,
    name = name,
    nameLower = strlower(name),
    icon = icon,
  }
  mountList[#mountList + 1] = entry
  mountBySpellId[spellId] = entry
  if not mountByName[entry.nameLower] then
    mountByName[entry.nameLower] = entry
  end
end

local function RebuildMountIndex()
  wipe(mountList)
  wipe(mountBySpellId)
  wipe(mountByName)

  if not (C_MountJournal and C_MountJournal.GetMountIDs) then
    indexDirty = false
    return
  end

  local mountIDs = C_MountJournal.GetMountIDs()
  if not mountIDs then
    indexDirty = false
    return
  end

  for _, mountID in ipairs(mountIDs) do
    local name, spellID, icon, _, _, _, _, _, _, _, isCollected =
      C_MountJournal.GetMountInfoByID(mountID)
    if spellID and spellID > 0 and isCollected then
      AddMountToIndex(spellID, name, icon)
    end
  end

  indexDirty = false
end

local function EnsureMountIndex()
  if indexDirty then
    RebuildMountIndex()
  end
  if not indexFrame then
    indexFrame = CreateFrame("Frame")
    indexFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    indexFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    indexFrame:SetScript("OnEvent", function()
      indexDirty = true
    end)
  end
end

local function ResolveMountToken(token)
  token = strtrim(token or "")
  if token == "" then
    return nil
  end
  EnsureMountIndex()

  local id = tonumber(token)
  if id and id > 0 then
    local fromIndex = mountBySpellId[id]
    if fromIndex then
      return {
        token = tostring(id),
        spellId = fromIndex.spellId,
        name = fromIndex.name,
        icon = fromIndex.icon,
      }
    end
    -- Try to look up a mount the player may not have collected yet.
    local mountID = C_MountJournal.GetMountFromSpell and C_MountJournal.GetMountFromSpell(id)
    if mountID and mountID > 0 then
      local name, spellID, icon = C_MountJournal.GetMountInfoByID(mountID)
      if spellID and spellID > 0 then
        return {
          token = tostring(spellID),
          spellId = spellID,
          name = name or tostring(spellID),
          icon = icon,
        }
      end
    end
    -- Keep unknown IDs so manual entries still work.
    return { token = tostring(id), spellId = id, name = tostring(id), icon = nil }
  end

  local fromBook = mountByName[strlower(token)]
  if fromBook then
    return {
      token = tostring(fromBook.spellId),
      spellId = fromBook.spellId,
      name = fromBook.name,
      icon = fromBook.icon,
    }
  end
  -- Unresolved name: show as text-only until the user removes it.
  return { token = token, spellId = nil, name = token, icon = nil }
end

local function FilterSuggestions(query, selectedIds, selectedNames)
  EnsureMountIndex()
  query = strtrim(query or "")
  local out = {}
  if query == "" then
    return out
  end

  local asId = tonumber(query)
  if asId and asId > 0 then
    local entry = ResolveMountToken(tostring(asId))
    if entry and entry.spellId and not selectedIds[entry.spellId] then
      out[#out + 1] = entry
    end
  end

  local q = strlower(query)
  for _, m in ipairs(mountList) do
    if #out >= 50 then -- MAX_MATCHES
      break
    end
    if not selectedIds[m.spellId] and not selectedNames[m.nameLower] then
      if strfind(m.nameLower, q, 1, true) then
        local dup = false
        for _, existing in ipairs(out) do
          if existing.spellId == m.spellId then
            dup = true
            break
          end
        end
        if not dup then
          out[#out + 1] = {
            token = tostring(m.spellId),
            spellId = m.spellId,
            name = m.name,
            icon = m.icon,
          }
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------
--                              MAKE MOUNT MULTI-SELECT                             --
---------------------------------------------------------------------------------------
function UI.MakeMountMultiSelect(parent, opts)
  return UI.MakePillMultiSelect(parent, opts, {
    resolveToken = ResolveMountToken,
    filterSuggestions = FilterSuggestions,
    placeholder = "Type mount name or spell ID…",
  })
end
