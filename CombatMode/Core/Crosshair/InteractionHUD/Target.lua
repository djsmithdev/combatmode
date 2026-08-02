---------------------------------------------------------------------------------------
--  Core/Crosshair/InteractionHUD/Target.lua — CROSSHAIR — softinteract identity
---------------------------------------------------------------------------------------
--  What it does: Resolves soft-interact presence, unit name (secret-string safe), and
--  unable-cursor dimming via SetUnitCursorTexture for the Interaction HUD.
--  Architecture / how it works:
--    • CM.InteractionHUDTarget: HasTarget, GetUnitName, IsSecretValue, GetCursorDim.
--    • GetCursorDim applies softinteract cursor art onto the host icon and returns
--      (dimAlpha, inRange) — unable art dims to 0.5 / out of range.
--  Does not: Own cluster chrome, fade/range motion, SoftTarget CVar writes.
--  Related: Core/Crosshair/InteractionHUD/{Visual,HUD}.lua, Constants/Reticle.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
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

local Target = {}
CM.InteractionHUDTarget = Target

local IH_ICON = 26
local IH_CURSOR_UNABLE = (CM.Constants and CM.Constants.InteractionHUDUnableCursor) or {}

Target.IH_ICON = IH_ICON

function Target.IsSecretValue(v)
  return v ~= nil and issecretvalue and issecretvalue(v)
end

function Target.HasTarget()
  return UnitGUID("softinteract") ~= nil
    or UnitExists("softinteract")
    or UnitIsGameObject("softinteract")
end

function Target.GetUnitName()
  local name = UnitName("softinteract")
  if name then
    if Target.IsSecretValue(name) then
      return name
    end
    if name ~= "" then
      return name
    end
  end
  if UnitNameUnmodified then
    name = UnitNameUnmodified("softinteract")
    if name then
      if Target.IsSecretValue(name) then
        return name
      end
      if name ~= "" then
        return name
      end
    end
  end
  if GetUnitName then
    name = GetUnitName("softinteract", false)
    if name then
      if Target.IsSecretValue(name) then
        return name
      end
      if name ~= "" then
        return name
      end
    end
  end
end

--- SetUnitCursorTexture("softinteract") → file id/path; dim when "unable" art.
--- @return number dimAlpha, boolean inRange
function Target.GetCursorDim(icon)
  if not icon then
    return 0.9, true
  end
  if not SetUnitCursorTexture(icon, "softinteract") then
    icon:SetAtlas("mechagon-projects")
  end
  icon:SetSize(IH_ICON, IH_ICON)
  local filePath = icon:GetTextureFilePath()
  if type(filePath) ~= "string" or (filePath and strfind(filePath, "FileData")) then
    filePath = tostring(icon:GetTextureFileID())
  end
  if not filePath then
    return 0.9, true
  end
  if IH_CURSOR_UNABLE[filePath] or (type(filePath) == "string" and strfind(filePath, "Unable")) then
    return 0.5, false
  end
  return 0.9, true
end
