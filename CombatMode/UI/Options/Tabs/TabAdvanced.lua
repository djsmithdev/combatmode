---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAdvanced.lua — OPTIONS TAB — custom Lua + reticle editors
---------------------------------------------------------------------------------------
--  What it does: Wires the Advanced options tab: force-lock and force-unlock
--  Lua, the crosshair situational appearance and condition, and buttons that open
--  the Reticle Targeting CVar editor and Targeting Macro Prelines editor.
--  Architecture / how it works:
--    • DB.global: customLockCondition, customLockConditionOnce, customCondition,
--      customConditionOnce, crosshairSituationalCondition,
--      crosshairSituationalAppearance. Widgets only read/write those keys.
--    • Force-lock / force-unlock are evaluated by ShouldFreeLookBeOff. The
--      situational snippet is evaluated by the crosshair; appearance and condition
--      set() refresh the crosshair. Both are disabled when the crosshair is off.
--    • Editor buttons call CM.OpenReticleTargetingCVarEditor and
--      CM.OpenTargetingMacroPrelinesEditor.
--  Does not: Evaluate Lua, own frame-watch / mount unlock UI, or own the editor
--      windows.
--  Related: Core/FreeLook/FreeLookController.lua, Core/FreeLook/AutoCursorUnlock.lua,
--  Core/Crosshair/Crosshair.lua, Core/Runtime/UserLuaCondition.lua,
--  UI/Editors/ReticleCVarEditorPanel.lua, UI/Editors/TargetingMacroPrelinesEditor.lua,
--  UI/Options/Tabs/TabGeneral.lua, UI/Options/Tabs/TabAutoCursorUnlock.lua,
--  UI/Options/Tabs/TabCrosshair.lua, UI/Options/Tabs/TabReticleTargeting.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local pairs = _G.pairs
local tinsert = _G.table.insert
local tsort = _G.table.sort

local UI = CM.UI

local appearanceOrder = {}
for name in pairs(CM.Constants.CrosshairAppearanceSelectValues) do
  appearanceOrder[#appearanceOrder + 1] = name
end
tsort(appearanceOrder)
tinsert(appearanceOrder, 1, "Invisible")

local situationalValues = {}
for name in pairs(CM.Constants.CrosshairAppearanceSelectValues) do
  situationalValues[name] = name
end
situationalValues.Invisible = "Invisible"

UI.Options.AddTab({
  id = "advanced",
  label = "Advanced",
  newFeatureFlag = true,
  build = function(ctx)
    ctx:Header({ text = "FORCE LOCK", newFeatureFlag = true })
    ctx:TextInput({
      label = "Custom Condition",
      desc = "Custom Lua code that, while evaluating to true, forces Mouse Look to remain locked.",
      placeholder = [[
local inCombat = InCombatLockdown and InCombatLockdown()
if inCombat then
  return true end
return false
]],
      multiline = 5,
      get = function()
        return CM.DB.global.customLockCondition
      end,
      set = function(input)
        CM.DB.global.customLockCondition = input
      end,
    })
    ctx:Toggle({
      label = "Lock Once",
      desc = "Force Mouse Look to lock only when the condition first becomes true. A manual unlock remains in effect until the condition becomes false and then true again.",
      get = function()
        return CM.DB.global.customLockConditionOnce == true
      end,
      set = function(value)
        CM.DB.global.customLockConditionOnce = value
      end,
    })
    ctx:Gap()
    ctx:Header("FORCE UNLOCK")
    ctx:TextInput({
      label = "Custom Condition",
      desc = "Custom Lua code that, while evaluating to true, forces Mouse Look to remain unlocked.",
      placeholder = [[
local standingStill = GetUnitSpeed and GetUnitSpeed("player") == 0
local onMount = IsMounted and IsMounted() or false
if standingStill and not onMount then
  return true end
return false
]],
      multiline = 5,
      get = function()
        return CM.DB.global.customCondition
      end,
      set = function(input)
        CM.DB.global.customCondition = input
      end,
    })
    ctx:Toggle({
      label = "Unlock Once",
      newFeatureFlag = true,
      desc = "Force Mouse Look to unlock only when the condition first becomes true. A manual lock remains in effect until the condition becomes false and then true again.",
      get = function()
        return CM.DB.global.customConditionOnce == true
      end,
      set = function(value)
        CM.DB.global.customConditionOnce = value
      end,
    })

    ctx:Gap()
    ctx:Header("CROSSHAIR")
    ctx:Dropdown({
      label = "Situational Appearance",
      newFeatureFlag = true,
      desc = "Texture utilized by the crosshair while the Situational Condition returns true.",
      values = situationalValues,
      order = appearanceOrder,
      get = function()
        return CM.DB.global.crosshairSituationalAppearance
            and CM.DB.global.crosshairSituationalAppearance.Name
          or "Invisible"
      end,
      set = function(value)
        if value == "Invisible" then
          CM.DB.global.crosshairSituationalAppearance = CM.Constants.CrosshairSituationalHidden
        else
          CM.DB.global.crosshairSituationalAppearance = CM.Constants.CrosshairTextureObj[value]
        end
        if CM.RefreshCrosshairAppearance then
          CM.RefreshCrosshairAppearance()
        else
          CM.CreateCrosshair()
        end
      end,
      disabled = function()
        return not CM.IsCrosshairEnabled()
      end,
    })
    ctx:TextInput({
      label = "Situational Condition",
      desc = "Custom Lua code that, while evaluating to true, forces the crosshair to use its Situational Appearance.",
      placeholder = [[
local deadOrGhost = UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
if deadOrGhost then
  return true end
return false
]],
      multiline = 5,
      get = function()
        return CM.DB.global.crosshairSituationalCondition
          or CM.Constants.DatabaseDefaults.global.crosshairSituationalCondition
          or ""
      end,
      set = function(input)
        CM.DB.global.crosshairSituationalCondition = input
        if CM.RefreshCrosshairAppearance then
          CM.RefreshCrosshairAppearance()
        end
      end,
      disabled = function()
        return not CM.IsCrosshairEnabled()
      end,
    })

    ctx:Gap()
    ctx:Header("RETICLE TARGETING")
    ctx:Description({
      text = "Modify Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines.",
      warning = "Warning: editing these values could break Reticle Targeting and Target Lock.",
    })
    ctx:ButtonRow({
      {
        label = "Reticle Targeting CVar Editor",
        func = function()
          CM.OpenReticleTargetingCVarEditor()
        end,
      },
      {
        label = "Targeting Macro Prelines Editor",
        func = function()
          CM.OpenTargetingMacroPrelinesEditor()
        end,
      },
    })
  end,
})
