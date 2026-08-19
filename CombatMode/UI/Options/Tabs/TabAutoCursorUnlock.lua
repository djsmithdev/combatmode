---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAutoCursorUnlock.lua — OPTIONS TAB — frame watch / conditions
---------------------------------------------------------------------------------------
--  What it does: DB-only wiring for Auto Unlock: frameWatching, mount multi-select, extra
--  watchlist frame names, and customCondition expression. No direct freelook calls —
--  predicates read these keys each update.
--  Architecture / how it works:
--    • DB.global.frameWatching, mountsToUnlock (CSV → table), watchlist, customCondition.
--    • Vendor Mounts now uses the mount multi-select instead of a toggle. The default
--      list is seeded with known vendor mounts; users can add any mount they own.
--    • Extra Frames disabled when frameWatching is off.
--  Does not: Evaluate visibility or call MouselookStop.
--  Related: Core/FreeLook/AutoCursorUnlock.lua, Constants/FrameWatch.lua,
--  Constants/DatabaseDefaults.lua, Core/FreeLook/FreeLookController.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local gmatch = _G.string.gmatch
local tconcat = _G.table.concat
local tinsert = _G.table.insert

local UI = CM.UI

UI.Options.AddTab({
  id = "autocursorunlock",
  label = "Auto Unlock",
  build = function(ctx)
    ctx:Header("AUTO UNLOCK")
    ctx:Toggle({
      label = "Enable Auto Unlock",
      desc = "Release the cursor when UI panels open.",
      get = function()
        return CM.DB.global.frameWatching
      end,
      set = function(value)
        CM.DB.global.frameWatching = value
      end,
    })
    ctx:MountMultiSelect({
      label = "Unlock Mounts",
      desc = "Mounts that force a cursor unlock while mounted.",
      get = function()
        return CM.DB.global.mountsToUnlock
      end,
      set = function(value)
        CM.DB.global.mountsToUnlock = value
      end,
    })
    ctx:Gap()
    ctx:TextInput({
      label = "Extra Frames",
      desc = "Extra frame names that trigger an auto unlock.\nUse "
        .. UI.SlashWrap("/fstack")
        .. " to find names.",
      descAllowColors = true,
      multiline = 4,
      get = function()
        return tconcat(CM.DB.global.watchlist or {}, ", ")
      end,
      set = function(input)
        CM.DB.global.watchlist = {}
        for value in gmatch(input, "[^,]+") do
          value = value:gsub("^%s*(.-)%s*$", "%1")
          tinsert(CM.DB.global.watchlist, value)
        end
      end,
      disabled = function()
        return CM.DB.global.frameWatching ~= true
      end,
    })
    ctx:Gap()
    ctx:TextInput({
      label = "Custom Condition",
      desc = "Custom Lua code checked during Mouse Look. Return true to trigger an auto unlock.",
      placeholder = "local isStill = GetUnitSpeed('player') == 0\nlocal onMount = IsMounted()\nreturn not onMount and isStill",
      multiline = 4,
      get = function()
        return CM.DB.global.customCondition
      end,
      set = function(input)
        CM.DB.global.customCondition = input
      end,
    })
  end,
})
