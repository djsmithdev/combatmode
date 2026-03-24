---------------------------------------------------------------------------------------
--  Config/ConfigNamespace.lua — config module: namespace initialization
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")

CM.Config = CM.Config or {}
