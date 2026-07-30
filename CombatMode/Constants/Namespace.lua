---------------------------------------------------------------------------------------
--  Constants/Namespace.lua — CONSTANTS — CM.Constants table init
---------------------------------------------------------------------------------------
--  What it does: Creates the empty `CM.Constants = {}` table that every later Constants/*
--  module fills. Exists solely so load order can assign into a shared table without each
--  file needing to create it.
--  Architecture / how it works:
--    • Must be the first script under Constants/ in Embeds.xml (before CVars, Assets,
--      Gameplay, DatabaseDefaults, PartyRadial, FrameWatch, Reticle).
--    • Consumers read `CM.Constants.*`; nothing here registers events or touches DB.
--  Does not: Define any constant data, defaults, or runtime APIs.
--  Related: Constants/CVars.lua, Constants/Assets.lua, Constants/Gameplay.lua,
--  Constants/DatabaseDefaults.lua, Constants/FrameWatch.lua, Constants/PartyRadial.lua,
--  Constants/Reticle.lua, Core/Runtime/Runtime.lua
---------------------------------------------------------------------------------------
local _, CM = ...

CM.Constants = {}
