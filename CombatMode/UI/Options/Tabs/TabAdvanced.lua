---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAdvanced.lua — OPTIONS TAB — custom Lua + reticle editors
---------------------------------------------------------------------------------------
--  What it does: Wires the Advanced options tab: force-lock and force-unlock
--  Lua, the crosshair situational appearance and condition, and buttons that open
--  the Reticle Targeting CVar editor and Targeting Macro Prelines editor, and
--  the Sounds toggles (one per feature that plays cues).
--  Architecture / how it works:
--    • DB.global: customLockCondition, customLockConditionOnce, customCondition,
--      customConditionOnce, crosshairSituationalCondition,
--      crosshairSituationalAppearance, soundMouseLook, soundTargetLock,
--      soundRadialMenu, soundAllyCycle. Widgets only read/write those keys;
--      the sound sites check them through CM.IsSoundEnabled (Runtime.lua).
--    • Force-lock / force-unlock are evaluated by ShouldFreeLookBeOff. The
--      situational snippet is evaluated by the crosshair; appearance and condition
--      set() refresh the crosshair. Both are disabled when the crosshair is off.
--    • Situational Appearance is a row (one clickable tile per state, "Hidden" when a state is hidden) that opens
--      CM.OpenCrosshairTextureEditor("situational").
--    • Editor buttons call CM.OpenReticleTargetingCVarEditor and
--      CM.OpenTargetingMacroPrelinesEditor. Code boxes include a ? that opens
--      the API docs copy-link popup.
--  Does not: Evaluate Lua, own frame-watch / mount unlock UI, or own the editor
--      windows.
--  Related: Core/FreeLook/FreeLookController.lua, Core/FreeLook/AutoCursorUnlock.lua,
--  Core/Crosshair/Crosshair.lua, Core/Runtime/UserLuaCondition.lua,
--  UI/Editors/ReticleCVarEditorPanel.lua, UI/Editors/TargetingMacroPrelinesEditor.lua, UI/Editors/CrosshairTextureEditor.lua,
--  UI/Options/Tabs/TabGeneral.lua, UI/Options/Tabs/TabAutoCursorUnlock.lua,
--  UI/Options/Tabs/TabCrosshair.lua, UI/Options/Tabs/TabReticleTargeting.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib

local UI = CM.UI

local API_DOCS_URL = "https://warcraft.wiki.gg/wiki/World_of_Warcraft_API"

UI.Options.AddTab({
  id = "advanced",
  label = "Advanced",
  newFeatureFlag = true,
  build = function(ctx)
    ctx:Header({ text = "SOUNDS", newFeatureFlag = true })
    ctx:Description("Control the sound cues used by some of the other features.")
    for _, sound in ipairs({
      {
        key = "soundMouseLook",
        label = "Mouse Look Sounds",
        desc = "Play a cue when Mouse Look turns on and off.",
      },
      {
        key = "soundTargetLock",
        label = "Target Lock Sounds",
        desc = "Play cues when a Target Lock is set, cleared or cycled.",
      },
      {
        key = "soundRadialMenu",
        label = "Radial Menu Sounds",
        desc = "Play cues when interacting with Radial Menu wheels.",
      },
      {
        key = "soundAllyCycle",
        label = "Ally Cycle Sounds",
        desc = "Play a cue when Ally Cycle moves to another ally.",
      },
    }) do
      ctx:Toggle({
        label = sound.label,
        desc = sound.desc,
        get = function()
          return CM.DB.global[sound.key] ~= false
        end,
        set = function(value)
          CM.DB.global[sound.key] = value
        end,
      })
    end

    ctx:Gap()
    ctx:Header({ text = "FORCE LOCK" })
    ctx:Description(
      "An advanced option that keeps Mouse Look enabled for as long as a custom Lua condition is true."
    )
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
      lua = true,
      helpUrl = API_DOCS_URL,
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
    ctx:Description(
      "The opposite of Force Lock: keeps Mouse Look off for as long as a custom Lua condition is true."
    )
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
      lua = true,
      helpUrl = API_DOCS_URL,
      get = function()
        return CM.DB.global.customCondition
      end,
      set = function(input)
        CM.DB.global.customCondition = input
      end,
    })
    ctx:Toggle({
      label = "Unlock Once",
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
    ctx:Description(
      "Swaps the crosshair's appearance for as long as a custom Lua condition is true."
    )
    ctx:Button({
      layout = "row",
      label = "Situational Appearance",
      newFeatureFlag = true,
      desc = "Textures utilized by the crosshair while the Situational Condition returns true.",
      tiles = {
        { slot = "base", caption = "Inactive", tint = "base" },
        { slot = "active", caption = "Active", tint = "hostile" },
      },
      previews = function()
        local appearance =
          CM.Constants.NormalizeCrosshairAppearance(CM.DB.global.crosshairSituationalAppearance)
        if not appearance or appearance.Hidden then
          return { base = "", active = "" }
        end
        return { base = appearance.Base, active = appearance.Active }
      end,
      func = function(slot)
        CM.OpenCrosshairTextureEditor("situational", slot)
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
      lua = true,
      helpUrl = API_DOCS_URL,
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
      text = "Modify Action Combat Mode's default Reticle Targeting CVars and Targeting Macro Prelines.",
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
