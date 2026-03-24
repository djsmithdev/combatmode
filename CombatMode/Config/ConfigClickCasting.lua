---------------------------------------------------------------------------------------
--  Config/ConfigClickCasting.lua — Click casting (base and modifier overrides)
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local AceAddon = LibStub("AceAddon-3.0")
local CM = AceAddon:GetAddon("CombatMode")
local U = CM.Config.OptionsUI
local Spacing, Header, Description = U.Spacing, U.Header, U.Description
local GetButtonOverrideGroup = U.GetButtonOverrideGroup

CM.Config.ClickCastingOptions = {
  name = CM.METADATA["TITLE"],
  handler = CM,
  type = "group",
  childGroups = "tab",
  args = {
    header = Header("clicks", 1),
    description = Description("clicks", 2),
    globalKeybind = {
      type = "toggle",
      name = "Use Account-Wide Click Bindings |cff3B73FF©|r",
      desc =
      "|cff3B73FF© Character-based option|r\n\nUse your account-wide shared Combat Mode keybinds on this character.\n\n|cffffd700Default:|r |cffE52B50Off|r",
      width = "full",
      order = 3,
      set = function(_, value)
        CM.DB.char.useGlobalBindings = value
        CM.OverrideDefaultButtons()
      end,
      get = function() return CM.DB.char.useGlobalBindings end
    },
    spacing = Spacing("full", 4),
    unmodifiedGroup = GetButtonOverrideGroup(nil, 5),
    shiftGroup = GetButtonOverrideGroup("shift", 6),
    ctrlGroup = GetButtonOverrideGroup("ctrl", 7),
    altGroup = GetButtonOverrideGroup("alt", 8)
  }
}
