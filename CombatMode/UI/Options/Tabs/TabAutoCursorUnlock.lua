---------------------------------------------------------------------------------------
--  UI/Options/Tabs/TabAutoCursorUnlock.lua — OPTIONS TAB — Auto Unlock
---------------------------------------------------------------------------------------
--  Registers the "Auto Unlock" tab: frame watching, vendor-mount unlock, the
--  frame watchlist, and the custom Lua unlock condition. Feature behavior lives in
--  Core/AutoCursorUnlock.lua; this tab only wires get/set/disabled to CM.DB.
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
      desc = "Automatically disables Mouse Look and releases the cursor when certain interface panels are opened.",
      get = function()
        return CM.DB.global.frameWatching
      end,
      set = function(value)
        CM.DB.global.frameWatching = value
      end,
    })
    ctx:Toggle({
      label = "Unlock While On Vendor Mount",
      desc = "Keeps the cursor unlocked while a vendor mount is being used.",
      get = function()
        return CM.DB.global.mountCheck
      end,
      set = function(value)
        CM.DB.global.mountCheck = value
      end,
    })
    ctx:TextInput({
      label = "Frame Watchlist (comma separated, case sensitive)",
      desc = "Expand the list of Blizzard panels or AddOn frames that trigger a Cursor Unlock.\nUse /fstack to check frame names.",
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
      desc = "Create your own custom condition that forces a Cursor Unlock by entering Lua that evaluates to True if the cursor should be freed, False otherwise.",
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
