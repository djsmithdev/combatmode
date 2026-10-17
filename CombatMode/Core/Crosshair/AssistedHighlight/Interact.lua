---------------------------------------------------------------------------------------
--  Core/Crosshair/AssistedHighlight/Interact.lua — CROSSHAIR — softinteract identity
---------------------------------------------------------------------------------------
--  What it does: Resolves soft-interact presence, unit name (secret-string safe), the
--  interact key text, and unable-cursor range state for the interaction mode of the
--  Combat Assist HUD (Assist.lua).
--  Architecture / how it works:
--    • CM.AssistedHighlightInteract: HasTarget, GetUnitName, IsSecretValue,
--      ApplyCursorTexture, GetInteractKeyText.
--    • HasTarget uses UnitExists / issecretvalue-aware GUID presence (no GUID ~= nil).
--    • ApplyCursorTexture stamps the softinteract cursor art onto the host icon and
--      returns inRange — unable art means out of range. Texture path/id probes skip
--      secrets (no strfind / table-key under taint).
--    • includeLowPriority=true so quest/loot soft icons still resolve when world quest
--      effects already decorate the NPC (otherwise SetUnitCursorTexture fails and the
--      HUD fell back to the mechagon-projects gear atlas).
--    • GetInteractKeyText reads the key bound to the primary interact command
--      (global.interactUnit), falling back to the alternate; nil when unbound.
--  Does not: Own HUD chrome, fade/motion, SoftTarget CVar writes, or key binding edits.
--  Related: Core/Crosshair/AssistedHighlight/{Assist,Keybinds}.lua,
--  UI/Options/Tabs/TabGeneral.lua (interact keybind)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetUnitName = _G.GetUnitName
local SetUnitCursorTexture = _G.SetUnitCursorTexture
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitName = _G.UnitName
local UnitNameUnmodified = _G.UnitNameUnmodified

-- Lua stdlib
local issecretvalue = _G.issecretvalue
local strfind = _G.string.find
local tostring = _G.tostring
local type = _G.type

local Interact = {}
CM.AssistedHighlightInteract = Interact

local INTERACT_TARGET = "INTERACTTARGET"
local INTERACT_MOUSEOVER = "INTERACTMOUSEOVER"

-- Soft-interact "unable" cursor file ids (icon dims when out of range).
local CURSOR_UNABLE = {
  ["4675695"] = true,
  ["4675705"] = true,
  ["4675693"] = true,
  ["4675702"] = true,
  ["4675694"] = true,
  ["4675720"] = true,
  ["4675725"] = true,
  ["4675677"] = true,
}

function Interact.IsSecretValue(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end

function Interact.HasTarget()
  -- Prefer UnitExists; never compare UnitGUID under instance taint (secret values).
  if UnitExists("softinteract") then
    return true
  end
  local guid = UnitGUID and UnitGUID("softinteract")
  if issecretvalue and issecretvalue(guid) then
    return true
  end
  if guid then
    return true
  end
  local isObj = UnitIsGameObject and UnitIsGameObject("softinteract")
  if Interact.IsSecretValue(isObj) then
    return false
  end
  return isObj and true or false
end

local function UsableName(name)
  if not name then
    return nil
  end
  if Interact.IsSecretValue(name) or name ~= "" then
    return name
  end
  return nil
end

function Interact.GetUnitName()
  local name = UsableName(UnitName("softinteract"))
  if name then
    return name
  end
  if UnitNameUnmodified then
    name = UsableName(UnitNameUnmodified("softinteract"))
    if name then
      return name
    end
  end
  if GetUnitName then
    return UsableName(GetUnitName("softinteract", false))
  end
end

-- The game's cursor art is applied to this hidden texture first, just to read which icon it picked.
local probe
local function Probe()
  if not probe then
    local host = CreateFrame("Frame")
    host:Hide()
    probe = host:CreateTexture()
  end
  return probe
end

--- Draws the softinteract cursor icon on `icon`; returns inRange (false for "unable" art). Our
--- shipped, re-centered copy is used when we have the icon the game picked (the game's own art is
--- not centered on its canvas), otherwise the game's art is applied directly.
--- Path / id probes are secret-safe (no strfind / table-key on secrets under taint).
function Interact.ApplyCursorTexture(icon)
  if not icon then
    return true
  end
  local source = Probe()
  if not SetUnitCursorTexture(source, "softinteract", nil, true) then
    CM.SetAtlas(icon, "mechagon-projects")
    return true
  end
  local filePath = source:GetTextureFilePath()
  if Interact.IsSecretValue(filePath) then
    SetUnitCursorTexture(icon, "softinteract", nil, true)
    return true
  end
  local shipped = type(filePath) == "string" and CM.GetCursorIconFile(filePath)
  if shipped then
    icon:SetTexture(shipped)
    icon:SetTexCoord(0, 1, 0, 1)
  else
    SetUnitCursorTexture(icon, "softinteract", nil, true)
  end
  if type(filePath) ~= "string" or strfind(filePath, "FileData") then
    local fileId = source:GetTextureFileID()
    if Interact.IsSecretValue(fileId) then
      return true
    end
    filePath = tostring(fileId)
  end
  if type(filePath) ~= "string" then
    return true
  end
  if CURSOR_UNABLE[filePath] or strfind(filePath:lower(), "unable", 1, true) then
    return false
  end
  return true
end

--- Key bound to Interact, formatted like the keyboard badge; nil when unbound.
function Interact.GetInteractKeyText()
  local g = CM.DB and CM.DB.global
  local primary, alternate = INTERACT_MOUSEOVER, INTERACT_TARGET
  if g and g.interactUnit == "target" then
    primary, alternate = INTERACT_TARGET, INTERACT_MOUSEOVER
  end
  local key = GetBindingKey(primary) or GetBindingKey(alternate)
  local Keybinds = CM.AssistedHighlightKeybinds
  if not (key and Keybinds and Keybinds.FormatKeybindText) then
    return nil
  end
  return Keybinds.FormatKeybindText(key)
end
