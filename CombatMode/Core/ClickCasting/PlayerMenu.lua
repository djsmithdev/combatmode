---------------------------------------------------------------------------------------
--  Core/ClickCasting/PlayerMenu.lua — CLICKCAST — interact key opens the player menu
---------------------------------------------------------------------------------------
--  What it does: With Mouse Look on and the crosshair on another player, the Interact key opens
--  that player's unit menu (Whisper, Inspect, Invite, Trade...) instead of interacting, once the
--  crosshair has rested on them (Interact.GetDwelledPlayer, 1 s) and only when the key is held
--  0.4 s (HOLD_SECONDS; a short press does nothing). On NPCs,
--  objects, yourself or nothing the key is untouched (INTERACTTARGET / INTERACTMOUSEOVER).
--  Architecture / how it works:
--    • CombatModePlayerMenuButton is a SecureUnitButtonTemplate whose `togglemenu` action opens the
--      unit popup for its `unit` attribute (the same secure path Blizzard's unit frames use; a
--      menu opened from addon code is tainted and entries like raid markers error).
--    • CombatModePlayerMenuBinder (SecureHandlerStateTemplate) owns the key: its `[nocombat] on; off`
--      state driver binds the Interact key to the button with SetBindingClick (override) and
--      clears it again, so combat drops the override securely with no addon code running.
--    • UpdatePlayerMenu runs from the throttled CombatMode_OnUpdate tick (out of combat only):
--      the crosshair candidate is `mouseover` first, then `softinteract`; the first one that
--      exists decides (an NPC under the crosshair keeps the key on Interact). It must be another
--      player (PublicBool(UnitIsPlayer), not UnitIsUnit "player"); anything secret or unknown
--      fails closed. The button's `unit` must be a stable token (party/raid, nameplate or
--      "target"): the menu keeps the id and the crosshair leaves the player once the cursor is
--      free, so `mouseover` / `softinteract` would break Inspect / Trade. A player with no stable
--      token (not targeted, no nameplate) first runs /target (TargetUnit is protected) in the macro.
--    • The key is bound to CombatModePlayerMenuHold (SecureActionButton, AnyDown+AnyUp,
--      useOnKeyDown=false so the action runs on release). PreClick stamps the press time and on
--      release sets macrotext to the armed macro (`/click CombatModePlayerMenuButton`) if held
--      HOLD_SECONDS, else empty. No clock is needed in the secure environment.
--    • The key is the one Interact is bound to in the General tab (global.interactUnit picks
--      the primary command); rebinding it re-arms on the next tick.
--  Does not: Place the menu at the nameplate (Blizzard anchors it at the cursor), open it in
--  combat, or change the Interact binding itself.
--  Related: Core/Crosshair/AssistedHighlight/{Assist,Interact}.lua (player prompt),
--  Core/ClickCasting/BindingOverrides.lua, Core/Runtime/Runtime.lua (tick),
--  UI/Options/Tabs/TabGeneral.lua (Interact keybind), Constants/FrameWatch.lua (cursor unlock)
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- WoW API
local C_NamePlate = _G.C_NamePlate
local CreateFrame = _G.CreateFrame
local GetBindingKey = _G.GetBindingKey
local GetTime = _G.GetTime
local GetNumGroupMembers = _G.GetNumGroupMembers
local InCombatLockdown = _G.InCombatLockdown
local IsInGroup = _G.IsInGroup
local IsInRaid = _G.IsInRaid
local IsMouselooking = _G.IsMouselooking
local RegisterStateDriver = _G.RegisterStateDriver
local UIParent = _G.UIParent
local UnitExists = _G.UnitExists
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local UnregisterStateDriver = _G.UnregisterStateDriver

-- Lua stdlib
local ipairs = _G.ipairs
local issecretvalue = _G.issecretvalue
local math = _G.math
local pcall = _G.pcall
local string = _G.string
local type = _G.type

local INTERACT_MOUSEOVER = "INTERACTMOUSEOVER"
local INTERACT_TARGET = "INTERACTTARGET"
local BUTTON_NAME = "CombatModePlayerMenuButton"
local HOLD_NAME = "CombatModePlayerMenuHold"
-- Seconds the Interact key must be held to open the menu; a shorter press does nothing.
local HOLD_SECONDS = 0.4
local NEWLINE = string.char(10)
local STATE = "cmplayermenu"
local COND_ON = "[nocombat] on; off"
local COND_OFF = "off"

-- Crosshair candidates, in order. The first that exists decides, so an NPC under the crosshair
-- (or a soft interact NPC with nothing under it) keeps the key on Interact.
local CANDIDATES = { "mouseover", "softinteract" }

-- Public boolean when not secret; nil when unknown/secret (cannot branch on it).
local function PublicBool(value)
  if value == nil then
    return nil
  end
  if issecretvalue and issecretvalue(value) then
    return nil
  end
  return value and true or false
end

local function Exists(unit)
  return PublicBool(UnitExists(unit)) == true
end

local function SameUnit(a, b)
  return Exists(a) and Exists(b) and PublicBool(UnitIsUnit(a, b)) == true
end

-- The button must stay shown (a hidden button makes the click do nothing) and off the mouse so it
-- can never steal a real click.
local menuButton = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureUnitButtonTemplate")
menuButton:SetAttribute("unit", "target")
menuButton:SetAttribute("type1", "togglemenu")
menuButton:SetAttribute("type2", "togglemenu")
menuButton:SetAttribute("*type1", "togglemenu")
menuButton:SetAttribute("*type2", "togglemenu")
menuButton:RegisterForClicks("AnyUp")
menuButton:SetAttribute("useOnKeyDown", false)
menuButton:SetSize(1, 1)
menuButton:SetAlpha(0)
menuButton:EnableMouse(false)
menuButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
menuButton:Show()

-- The key's button. Press records the time; the action runs on release (useOnKeyDown=false)
-- and only when the key was held HOLD_SECONDS. PreClick (insecure, out of combat only: the
-- binder drops the key in combat) swaps the macro: the armed one (/target the player when no
-- stable token names them yet, then click the menu button) or nothing for a short press.
local holdButton = CreateFrame("Button", HOLD_NAME, UIParent, "SecureActionButtonTemplate")
holdButton:SetAttribute("type", "macro")
holdButton:SetAttribute("macrotext", "")
holdButton:RegisterForClicks("AnyDown", "AnyUp")
-- Action buttons act on key down while ActionButtonUseKeyDown is on, which would fire on press.
holdButton:SetAttribute("useOnKeyDown", false)
holdButton:SetSize(1, 1)
holdButton:SetAlpha(0)
holdButton:EnableMouse(false)
holdButton:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
holdButton:Show()

local pressedAt = nil
local armedMacro = ""
holdButton:SetScript("PreClick", function(_, _, down)
  if InCombatLockdown() then
    return
  end
  if down then
    pressedAt = GetTime()
    holdButton:SetAttribute("macrotext", "")
    return
  end
  local held = pressedAt and (GetTime() - pressedAt) >= HOLD_SECONDS
  pressedAt = nil
  holdButton:SetAttribute("macrotext", held and armedMacro or "")
end)

-- Numeric states arrive as numbers, so the snippet compares the strings "on" / "off".
local binder =
  CreateFrame("Frame", "CombatModePlayerMenuBinder", UIParent, "SecureHandlerStateTemplate")
binder:SetAttribute(
  "_onstate-" .. STATE,
  [[
    local key = self:GetAttribute("menukey")
    local button = self:GetAttribute("menubutton")
    if newstate == "on" and key and button then
      self:SetBindingClick(true, key, button, "LeftButton")
    else
      self:ClearBindings()
    end
  ]]
)

local armedCond = nil
local armedKey = nil
local armedSetup = nil
--- Key currently bound to Interact (primary command from global.interactUnit, else the other).
local function GetInteractKey()
  local primary, alternate = INTERACT_MOUSEOVER, INTERACT_TARGET
  if CM.DB and CM.DB.global.interactUnit == "target" then
    primary, alternate = INTERACT_TARGET, INTERACT_MOUSEOVER
  end
  return GetBindingKey(primary) or GetBindingKey(alternate)
end

--- The crosshair's unit when it is another player, else nil (NPC, object, yourself, nothing, secret).
local function GetPlayerUnderCrosshair()
  for _, unit in ipairs(CANDIDATES) do
    if Exists(unit) then
      if
        PublicBool(UnitIsPlayer(unit)) == true and PublicBool(UnitIsUnit(unit, "player")) == false
      then
        return unit
      end
      return nil
    end
  end
  return nil
end

-- Shared with the Interaction HUD, which shows the same player's prompt.
CM.GetPlayerUnderCrosshair = GetPlayerUnderCrosshair

--- A token that keeps naming the same player after the crosshair moves off them: group member,
--- nameplate, hard target; the candidate itself when none matches.
local function StableToken(unit)
  if IsInGroup() then
    local prefix, count = "party", 4
    if IsInRaid() then
      prefix, count = "raid", math.min(GetNumGroupMembers(), 40)
    end
    for i = 1, count do
      local token = prefix .. i
      if SameUnit(token, unit) then
        return token
      end
    end
  end
  if C_NamePlate and C_NamePlate.GetNamePlates then
    local ok, plates = pcall(C_NamePlate.GetNamePlates)
    if ok and type(plates) == "table" then
      for _, plate in ipairs(plates) do
        local token = plate.namePlateUnitToken
        if type(token) == "string" and SameUnit(token, unit) then
          return token
        end
      end
    end
  end
  if SameUnit("target", unit) then
    return "target"
  end
  return unit
end

local function SetCond(cond)
  if armedCond == cond then
    return
  end
  armedCond = cond
  RegisterStateDriver(binder, STATE, cond)
end

--- Gives the Interact key back to its normal binding. Safe to call every tick.
function CM.DisarmPlayerMenu()
  if InCombatLockdown() or armedCond == COND_OFF or armedCond == nil then
    return
  end
  armedKey = nil
  armedSetup = nil
  SetCond(COND_OFF)
end

--- Arms the Interact key for the player under the crosshair, or disarms it. Out of combat only
--- (attributes and drivers are protected); in combat the `[nocombat]` driver has already dropped it.
function CM.UpdatePlayerMenu()
  if InCombatLockdown() then
    return
  end
  local key = IsMouselooking() and GetInteractKey() or nil
  local unit, dwelled = nil, false
  if key then
    -- Same aim-and-hold rule as the Interaction HUD's player prompt (Interact.lua).
    local Interact = CM.AssistedHighlightInteract
    unit, dwelled = Interact.GetDwelledPlayer()
  end
  if not unit or not dwelled then
    CM.DisarmPlayerMenu()
    return
  end

  -- Only a token that outlives the crosshair can open the menu. For anyone else one press
  -- targets them (a macro /target; TargetUnit is protected) and clicks the menu button, whose
  -- unit is then "target".
  local token = StableToken(unit)
  if token == unit then
    -- If the click ever fails, the next tick sees "target" as the stable token.
    armedMacro = "/target " .. unit .. NEWLINE .. "/click " .. BUTTON_NAME
    if armedSetup ~= armedMacro then
      armedSetup = armedMacro
      menuButton:SetAttribute("unit", "target")
    end
  else
    armedMacro = "/click " .. BUTTON_NAME
    if armedSetup ~= token then
      armedSetup = token
      menuButton:SetAttribute("unit", token)
    end
  end

  local armed = key
  if armed ~= armedKey then
    armedKey = armed
    binder:SetAttribute("menukey", key)
    binder:SetAttribute("menubutton", HOLD_NAME)
    -- The snippet only runs on a state change: drop the driver so the new key is bound again.
    if armedCond then
      UnregisterStateDriver(binder, STATE)
      -- The driver only sets the attribute when the state differs from the stored one, so
      -- without this "on" -> "on" never fires the snippet and the new button is not bound.
      binder:SetAttribute("state-" .. STATE, "off")
      armedCond = nil
    end
  end
  SetCond(COND_ON)
end
