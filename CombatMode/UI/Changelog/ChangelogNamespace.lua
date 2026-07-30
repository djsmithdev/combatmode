---------------------------------------------------------------------------------------
--  UI/Changelog/ChangelogNamespace.lua — CHANGELOG — CM.Config init
---------------------------------------------------------------------------------------
--  What it does: Ensures `CM.Config = {}` exists before ChangelogData and ChangelogPanel
--  assign ChangelogText and ShowChangelog APIs. Load-order anchor for UI/Changelog/.
--  Architecture / how it works:
--    • Must load first in Changelog/ (Embeds.xml) before data + panel.
--  Does not: Contain changelog body text or draw the viewer window.
--  Related: UI/Changelog/ChangelogData.lua, UI/Changelog/ChangelogPanel.lua
---------------------------------------------------------------------------------------
local _, CM = ...

CM.Config = CM.Config or {}
