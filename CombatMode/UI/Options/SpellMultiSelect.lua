---------------------------------------------------------------------------------------
--  UI/Options/SpellMultiSelect.lua — OPTIONS — spell ID pill multi-select
---------------------------------------------------------------------------------------
--  What it does: UI.MakeSpellMultiSelect — type-ahead suggestions from the spellbook,
--  pill chips for selected spells, storage as CSV spell IDs for Reticle Targeting exclude
--  and cast-at-crosshair lists.
--  Architecture / how it works:
--    • Suggestion popup capped (MAX_MATCHES / visible rows); migrates legacy name tokens
--      when resolving. Spellbook index build skips when C_SpellBook.GetSpellBookItemInfo
--      is unavailable (pet-spell scan is guarded — warlock pet books could otherwise
--      crash options open).
--    • Runtime membership tests live in TargetingMacroBuilder, not here.
--  Does not: Build click-cast macros or write CVars.
--  Related: UI/Options/Widgets.lua, UI/Options/Tabs/TabReticleTargeting.lua,
--  Core/ClickCasting/TargetingMacroBuilder.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local C_Spell = _G.C_Spell
local C_SpellBook = _G.C_SpellBook
local Enum = _G.Enum

-- Lua stdlib
local ipairs = _G.ipairs
local strfind = _G.string.find
local strlower = _G.string.lower
local strtrim = _G.string.trim
local tonumber = _G.tonumber
local tostring = _G.tostring
local wipe = _G.wipe

local UI = CM.UI

local MAX_MATCHES = 50

---------------------------------------------------------------------------------------
--                              SPELLBOOK INDEX                                      --
---------------------------------------------------------------------------------------
local spellList = {} -- { spellId, name, nameLower, icon }
local spellById = {}
local spellByName = {}
local indexDirty = true
local indexFrame

local function AddSpellToIndex(spellId, name, icon)
  if not spellId or spellId <= 0 or not name or name == "" then
    return
  end
  if spellById[spellId] then
    return
  end
  local entry = {
    spellId = spellId,
    name = name,
    nameLower = strlower(name),
    icon = icon,
  }
  spellList[#spellList + 1] = entry
  spellById[spellId] = entry
  if not spellByName[entry.nameLower] then
    spellByName[entry.nameLower] = entry
  end
end

local function IsPassiveSpell(spellId, slot, bank)
  if slot and bank and C_SpellBook.IsSpellBookItemPassive then
    if C_SpellBook.IsSpellBookItemPassive(slot, bank) then
      return true
    end
  end
  if spellId and C_Spell and C_Spell.IsSpellPassive then
    return C_Spell.IsSpellPassive(spellId) and true or false
  end
  return false
end

local function RebuildSpellIndex()
  wipe(spellList)
  wipe(spellById)
  wipe(spellByName)
  if not (C_SpellBook and Enum and Enum.SpellBookSpellBank) then
    indexDirty = false
    return
  end

  local GetSpellBookItemInfo = C_SpellBook.GetSpellBookItemInfo
  if not GetSpellBookItemInfo then
    indexDirty = false
    return
  end

  local playerBank = Enum.SpellBookSpellBank.Player
  local petBank = Enum.SpellBookSpellBank.Pet
  local spellType = Enum.SpellBookItemType and Enum.SpellBookItemType.Spell

  local numLines = C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetNumSpellBookSkillLines()
    or 0
  for i = 1, numLines do
    local line = C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookSkillLineInfo(i)
    if line and not line.offSpecID and line.numSpellBookItems and line.itemIndexOffset then
      for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
        local info = GetSpellBookItemInfo(slot, playerBank)
        if info and (not spellType or info.itemType == spellType) then
          local spellId = info.spellID or info.actionID
          if not IsPassiveSpell(spellId, slot, playerBank) then
            local name = info.name
            local icon = info.iconID
            if (not name or name == "") and spellId and C_Spell and C_Spell.GetSpellInfo then
              local si = C_Spell.GetSpellInfo(spellId)
              if si then
                name = si.name
                icon = icon or si.iconID
              end
            end
            AddSpellToIndex(spellId, name, icon)
          end
        end
      end
    end
  end

  local numPet = C_SpellBook.HasPetSpells and C_SpellBook.HasPetSpells()
  if numPet and numPet > 0 and petBank then
    for slot = 1, numPet do
      local info = GetSpellBookItemInfo(slot, petBank)
      if info then
        local spellId = info.spellID or info.actionID
        if not IsPassiveSpell(spellId, slot, petBank) then
          local name = info.name
          local icon = info.iconID
          if (not name or name == "") and spellId and C_Spell and C_Spell.GetSpellInfo then
            local si = C_Spell.GetSpellInfo(spellId)
            if si then
              name = si.name
              icon = icon or si.iconID
            end
          end
          AddSpellToIndex(spellId, name, icon)
        end
      end
    end
  end

  indexDirty = false
end

local function EnsureSpellIndex()
  if indexDirty then
    RebuildSpellIndex()
  end
  if not indexFrame then
    indexFrame = CreateFrame("Frame")
    indexFrame:RegisterEvent("SPELLS_CHANGED")
    indexFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    indexFrame:SetScript("OnEvent", function()
      indexDirty = true
    end)
  end
end

local function ResolveSpellToken(token)
  token = strtrim(token or "")
  if token == "" then
    return nil
  end
  EnsureSpellIndex()

  local idText = token:gsub("^#", "")
  local id = tonumber(idText)
  if id and id > 0 then
    local fromBook = spellById[id]
    if fromBook then
      return {
        token = tostring(id),
        spellId = fromBook.spellId,
        name = fromBook.name,
        icon = fromBook.icon,
      }
    end
    if C_Spell and C_Spell.GetSpellInfo then
      local si = C_Spell.GetSpellInfo(id)
      if si and si.name then
        return {
          token = tostring(id),
          spellId = id,
          name = si.name,
          icon = si.iconID,
        }
      end
    end
    -- Keep unknown IDs so whitelist/blacklist by id still works.
    return { token = tostring(id), spellId = id, name = tostring(id), icon = nil }
  end

  local fromBook = spellByName[strlower(token)]
  if fromBook then
    return {
      token = tostring(fromBook.spellId),
      spellId = fromBook.spellId,
      name = fromBook.name,
      icon = fromBook.icon,
    }
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local si = C_Spell.GetSpellInfo(token)
    local spellId = si and (si.spellID or si.spellId)
    if si and si.name and spellId then
      return {
        token = tostring(spellId),
        spellId = spellId,
        name = si.name,
        icon = si.iconID,
      }
    end
  end
  -- Unresolved legacy name: show as text-only until the user removes it.
  return { token = token, spellId = nil, name = token, icon = nil }
end

local function FilterSuggestions(query, selectedIds, selectedNames)
  EnsureSpellIndex()
  query = strtrim(query or "")
  local out = {}
  if query == "" then
    return out
  end

  local idText = query:gsub("^#", "")
  local asId = tonumber(idText)
  if asId and asId > 0 and not IsPassiveSpell(asId) then
    local entry = ResolveSpellToken(tostring(asId))
    if
      entry
      and entry.spellId
      and not selectedIds[entry.spellId]
      and not IsPassiveSpell(entry.spellId)
    then
      out[#out + 1] = entry
    end
  end

  local q = strlower(query)
  for _, sp in ipairs(spellList) do
    if #out >= MAX_MATCHES then
      break
    end
    if not selectedIds[sp.spellId] and not selectedNames[sp.nameLower] then
      if strfind(sp.nameLower, q, 1, true) then
        -- Skip if already added via ID resolve
        local dup = false
        for _, existing in ipairs(out) do
          if existing.spellId == sp.spellId then
            dup = true
            break
          end
        end
        if not dup then
          out[#out + 1] = {
            token = tostring(sp.spellId),
            spellId = sp.spellId,
            name = sp.name,
            icon = sp.icon,
          }
        end
      end
    end
  end
  return out
end

---------------------------------------------------------------------------------------
--                              MAKE SPELL MULTI-SELECT                              --
---------------------------------------------------------------------------------------
function UI.MakeSpellMultiSelect(parent, opts)
  return UI.MakePillMultiSelect(parent, opts, {
    resolveToken = ResolveSpellToken,
    filterSuggestions = FilterSuggestions,
    placeholder = "Type spell name or ID…",
  })
end
