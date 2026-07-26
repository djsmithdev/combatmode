---------------------------------------------------------------------------------------
--  Config/ConfigChangelogPanel.lua — in-game changelog window (About + post-update)
---------------------------------------------------------------------------------------
--  Owns: markdown subset → SimpleHTML, CM.UI window (UI.CreateBareWindow) + custom thumb
--  scrollbar (UI.CreateScrollFrame), CM.Config.ShowChangelog /
--  CM.Config.MaybeShowChangelogOnNewVersion, CM.DB.global.lastSeenChangelogVersion when shown.
--  Data: CM.Config.ChangelogText from ConfigChangelogData.lua (sync from CHANGELOG.md via
--  scripts/sync-changelog-to-lua.ps1). Callers: ConfigAbout.lua (View Changelog), Core/Runtime.lua
--  (ScheduleChangelogIfNewVersion on login / after welcome popup).
---------------------------------------------------------------------------------------
local _G = _G
local LibStub = _G.LibStub
local CM = LibStub("AceAddon-3.0"):GetAddon("CombatMode")

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local math = _G.math
local strlower = _G.strlower

local UI = CM.UI

local changelogFrame

---------------------------------------------------------------------------------------
--  Markdown (subset) → SimpleHTML (warcraft.wiki.gg/wiki/UIOBJECT_SimpleHTML)
---------------------------------------------------------------------------------------
-- Single |cff…|r wrap per heading line; nested pipes inside SimpleHTML break parsing.
-- Minimal theme: version headings take the accent yellow, subsections stay neutral grey.
local VERSION_DATE_HEADING_COLOR = "|cffffcd3c"
local H3_SUBSECTION_COLORS = {
  added = "|cffb4b4b4",
  changed = "|cffb4b4b4",
  fixed = "|cffb4b4b4",
}

local function EscapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

--- Inline: `` `code` `` and **bold** as plain escaped text (no |c sequences inside SimpleHTML — they break XHTML parsing and can yield a blank document).
local function ProcessInline(raw)
  local segments = {}
  local pos = 1
  while pos <= #raw do
    local tick = raw:find("`", pos, true)
    if not tick then
      segments[#segments + 1] = EscapeHtml(raw:sub(pos))
      break
    end
    segments[#segments + 1] = EscapeHtml(raw:sub(pos, tick - 1))
    local tick2 = raw:find("`", tick + 1, true)
    if not tick2 then
      segments[#segments + 1] = EscapeHtml(raw:sub(tick))
      break
    end
    local code = EscapeHtml(raw:sub(tick + 1, tick2 - 1))
    segments[#segments + 1] = code
    pos = tick2 + 1
  end
  local s = table.concat(segments)
  repeat
    local n
    s, n = s:gsub("%*%*(.-)%*%*", "%1", 1)
  until n == 0
  return s
end

--- `https://...` and `http://...` into anchors (must stay inside <p>/<h*>).
local function LinkifyUrls(s)
  return (
    s:gsub("(https?://[%w%.%-%?&=/+#%%:~]+)", function(url)
      local esc = EscapeHtml(url)
      return '<a href="' .. esc .. '">' .. esc .. "</a>"
    end)
  )
end

local function PushBlock(out, tag, content)
  if content == "" then
    return
  end
  out[#out + 1] = "<"
  out[#out + 1] = tag
  out[#out + 1] = ">"
  out[#out + 1] = LinkifyUrls(content)
  out[#out + 1] = "</"
  out[#out + 1] = tag
  out[#out + 1] = ">"
end

local function ChangelogMarkdownToSimpleHtml(md)
  if not md or md == "" then
    return "<html><body><p></p></body></html>"
  end
  local normalized = md:gsub("\r\n", "\n"):gsub("\r", "\n")
  local out = { "<html><body>" }
  local text = normalized .. "\n"
  for line in text:gmatch("([^\n]*)\n") do
    local t = line:match("^%s*(.-)%s*$") or ""
    if t == "" then
      out[#out + 1] = "<br/>"
    elseif t:match("^%-%-%-+%s*$") then
      out[#out + 1] = "<br/><br/>"
    elseif t:match("^#%s+") and not t:match("^##") then
      PushBlock(out, "h1", ProcessInline(t:match("^#%s+(.+)$") or ""))
    elseif t:match("^##%s+") and not t:match("^###") then
      local h2Text = ProcessInline(t:match("^##%s+(.+)$") or "")
      PushBlock(out, "h2", VERSION_DATE_HEADING_COLOR .. h2Text .. "|r")
    elseif t:match("^###%s+") then
      local innerRaw = t:match("^###%s+(.+)$") or ""
      local h3Text = ProcessInline(innerRaw)
      local key = strlower((innerRaw:match("^%s*(.-)%s*$") or ""))
      local c = H3_SUBSECTION_COLORS[key]
      if c then
        PushBlock(out, "h3", c .. h3Text .. "|r")
      else
        PushBlock(out, "h3", h3Text)
      end
    elseif t:match("^%-%s+") then
      local rest = t:match("^%-%s+(.+)$") or ""
      PushBlock(out, "p", "• " .. ProcessInline(rest))
    else
      PushBlock(out, "p", ProcessInline(t))
    end
  end
  out[#out + 1] = "</body></html>"
  return table.concat(out)
end

local function LayoutChangelogContent()
  if not changelogFrame or not changelogFrame.scroll or not changelogFrame.body then
    return
  end
  local scroll = changelogFrame.scroll
  local scrollChild = changelogFrame.scrollChild
  local body = changelogFrame.body
  local sw = scroll:GetWidth()
  if sw < 80 then
    return
  end
  scrollChild:SetWidth(sw)
  local textW = sw - 16
  body:SetWidth(textW)
  local html = ChangelogMarkdownToSimpleHtml(CM.Config.ChangelogText or "")
  body:SetText(html)
  local textH = body:GetContentHeight()
  body:SetHeight(math.max(textH, 1))
  local padV = 16
  scrollChild:SetHeight(math.max(textH + padV, scroll:GetHeight()))
  scroll:SetVerticalScroll(0)
  if scroll.cmUpdate then
    scroll.cmUpdate()
  end
end

local function EnsureChangelogFrame()
  if changelogFrame then
    return changelogFrame
  end

  local frame = UI.CreateBareWindow("CombatModeChangelogFrame", CM.METADATA["TITLE"], 540, 460)
  frame:SetFrameLevel(200)
  frame:Hide()

  local scroll, scrollChild = UI.CreateScrollFrame(frame)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -44)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 14)
  scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
  scrollChild:SetWidth(1)

  local body = CreateFrame("SimpleHTML", nil, scrollChild)
  body:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -8)
  local h2Font = _G.GameFontHighlightMedium or _G.GameFontHighlight
  body:SetFontObject("h1", _G.GameFontNormalLarge)
  body:SetFontObject("h2", h2Font)
  body:SetFontObject("h3", _G.GameFontHighlight)
  body:SetFontObject("p", _G.GameFontHighlightSmall)

  frame.scroll = scroll
  frame.scrollChild = scrollChild
  frame.body = body

  scroll:HookScript("OnSizeChanged", function()
    LayoutChangelogContent()
  end)

  frame:SetScript("OnShow", function()
    LayoutChangelogContent()
    C_Timer.After(0, LayoutChangelogContent)
  end)

  changelogFrame = frame
  return frame
end

function CM.Config.ShowChangelog()
  local f = EnsureChangelogFrame()
  f:Show()
  f:Raise()
  LayoutChangelogContent()
  C_Timer.After(0, LayoutChangelogContent)
  if CM.DB and CM.DB.global and CM.METADATA["VERSION"] and CM.METADATA["VERSION"] ~= "" then
    CM.DB.global.lastSeenChangelogVersion = CM.METADATA["VERSION"]
  end
end

--- Shows the changelog once per addon version (after upgrades). Safe to call from login;
--- skips if already seen. With Debug Mode on, always shows so the panel can be verified
--- without wiping SavedVariables / changing the TOC version.
function CM.Config.MaybeShowChangelogOnNewVersion()
  if not CM.DB or not CM.DB.global then
    return
  end
  if CM.DB.global.debugMode then
    CM.Config.ShowChangelog()
    return
  end
  local current = CM.METADATA["VERSION"] or ""
  if current == "" then
    return
  end
  if CM.DB.global.lastSeenChangelogVersion == current then
    return
  end
  CM.Config.ShowChangelog()
end
