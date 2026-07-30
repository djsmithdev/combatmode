---------------------------------------------------------------------------------------
--  UI/Changelog/ChangelogPanel.lua — CHANGELOG — in-game changelog window
---------------------------------------------------------------------------------------
--  What it does: Builds the changelog viewer (version sidebar + scrollable SimpleHTML
--  body), exposes CM.Config.ShowChangelog and MaybeShowChangelogOnNewVersion, and
--  persists lastSeenChangelogVersion when the user views a new TOC version.
--  Architecture / how it works:
--    • Parses ChangelogText markdown subset (h1/h2/h3/p/br/a); footer compare links
--      skipped.
--    • Uses CM.UI Draw primitives; opened from options footer or Runtime after bump.
--  Does not: Author changelog content (ChangelogData / CHANGELOG.md).
--  Related: UI/Changelog/ChangelogData.lua, UI/Options/Draw.lua,
--  UI/Options/OptionsPanel.lua, Core/Runtime/Runtime.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local ipairs = _G.ipairs
local math = _G.math
local print = _G.print
local string = _G.string
local strlower = _G.strlower
local table = _G.table
local type = _G.type
local UIParent = _G.UIParent

local UI = CM.UI
local C = UI.Colors

local SIDEBAR_W = 118
local WINDOW_W, WINDOW_H = 660, 460
local NAV_BTN_H = 28
local NAV_BTN_GAP = 4
local SECTION_GAP = 10
local CONTENT_PAD_TOP = 8

local changelogFrame

---------------------------------------------------------------------------------------
--  Markdown (subset) → SimpleHTML (warcraft.wiki.gg/wiki/UIOBJECT_SimpleHTML)
---------------------------------------------------------------------------------------
-- Supported tags: h1/h2/h3/p/br/a only. Unknown tags (e.g. <b>) are dropped entirely,
-- so emphasis uses UI |cff…|r escapes. Markdown links become <a href>; Keep a Changelog
-- [Unreleased] section and compare-link definitions at the file footer are skipped in-game.
local H3_SUBSECTION_COLORS = {
  added = "|cffb4b4b4",
  changed = "|cffb4b4b4",
  fixed = "|cffb4b4b4",
  removed = "|cffb4b4b4",
  deprecated = "|cffb4b4b4",
  security = "|cffb4b4b4",
}

-- Emphasized inline text (e.g. **Breaking:**) — must contrast with body grey (white |cff is invisible).
-- Link labels use slash-blue so <a> text is recognizable (SimpleHTML does not style anchors on its own).
local function InlineEmphasisMarkup()
  return UI.AccentMarkup()
end

local function InlineLinkMarkup()
  return UI.Colors.slashMarkup or "|cff69ccf0"
end

local function InlineWarningMarkup()
  local w = UI.Colors.warning
  if w then
    return string.format(
      "|cff%02x%02x%02x",
      math.floor(w[1] * 255 + 0.5),
      math.floor(w[2] * 255 + 0.5),
      math.floor(w[3] * 255 + 0.5)
    )
  end
  return "|cffd15959"
end

local function EscapeHtml(s)
  return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

--- Normalize glyphs many WoW fonts lack (show as empty boxes otherwise).
local function SanitizeChangelogGlyphs(s)
  s = s:gsub("→", ">")
  s = s:gsub("←", "<")
  s = s:gsub("—", "-")
  s = s:gsub("–", "-")
  s = s:gsub("…", "...")
  return s
end

--- Inline markdown → SimpleHTML-safe text: [label](url), `code`, **bold**, then HTML-escape.
local function ProcessInline(raw)
  raw = SanitizeChangelogGlyphs(raw or "")
  local parts = {}
  local pos = 1
  local len = #raw

  local function takePlain(from, to)
    if to >= from then
      parts[#parts + 1] = EscapeHtml(raw:sub(from, to))
    end
  end

  while pos <= len do
    local linkStart, linkEnd, linkText, linkUrl =
      raw:find("%[([^%]]+)%]%((https?://[^%s%)]+)%)", pos)
    local tickStart = raw:find("`", pos, true)
    local boldStart, boldEnd, boldText = raw:find("%*%*([^*]+)%*%*", pos)

    local nextKind, nextAt = nil, len + 1
    if linkStart and linkStart < nextAt then
      nextKind, nextAt = "link", linkStart
    end
    if tickStart and tickStart < nextAt then
      nextKind, nextAt = "code", tickStart
    end
    if boldStart and boldStart < nextAt then
      nextKind, nextAt = "bold", boldStart
    end

    if not nextKind then
      takePlain(pos, len)
      break
    end

    takePlain(pos, nextAt - 1)

    if nextKind == "link" then
      -- Color lives inside <a> so the label reads as a link; href stays the click token.
      parts[#parts + 1] = '<a href="'
        .. EscapeHtml(linkUrl)
        .. '">'
        .. InlineLinkMarkup()
        .. EscapeHtml(linkText)
        .. "|r</a>"
      pos = linkEnd + 1
    elseif nextKind == "code" then
      local tick2 = raw:find("`", tickStart + 1, true)
      if not tick2 then
        takePlain(tickStart, len)
        break
      end
      -- Inline code: slightly brighter than body so names/ids stand out.
      parts[#parts + 1] = InlineLinkMarkup()
        .. EscapeHtml(raw:sub(tickStart + 1, tick2 - 1))
        .. "|r"
      pos = tick2 + 1
    else
      local esc = EscapeHtml(boldText)
      local mark = InlineEmphasisMarkup()
      if strlower(boldText):match("^breaking") then
        mark = InlineWarningMarkup()
      end
      parts[#parts + 1] = mark .. esc .. "|r"
      pos = boldEnd + 1
    end
  end

  return table.concat(parts)
end

--- Bare https?:// URLs not already turned into <a href>.
local function LinkifyBareUrls(s)
  local out = {}
  local pos = 1
  while pos <= #s do
    local aOpen = s:find("<a%s+href=", pos)
    local urlStart, urlEnd = s:find("https?://[%w%.%-%?&=/+#%%:~]+", pos)
    if aOpen and (not urlStart or aOpen <= urlStart) then
      local aClose = s:find("</a>", aOpen, true)
      if not aClose then
        out[#out + 1] = s:sub(pos)
        break
      end
      out[#out + 1] = s:sub(pos, aClose + 3)
      pos = aClose + 4
    elseif urlStart then
      out[#out + 1] = s:sub(pos, urlStart - 1)
      local url = s:sub(urlStart, urlEnd)
      out[#out + 1] = '<a href="'
        .. EscapeHtml(url)
        .. '">'
        .. InlineLinkMarkup()
        .. EscapeHtml(url)
        .. "|r</a>"
      pos = urlEnd + 1
    else
      out[#out + 1] = s:sub(pos)
      break
    end
  end
  return table.concat(out)
end

local function PushBlock(out, tag, content)
  if content == "" then
    return
  end
  out[#out + 1] = "<"
  out[#out + 1] = tag
  out[#out + 1] = ">"
  out[#out + 1] = LinkifyBareUrls(content)
  out[#out + 1] = "</"
  out[#out + 1] = tag
  out[#out + 1] = ">"
end

--- Keep a Changelog `## [1.2.3] - date` / `## [Unreleased]` → display without brackets.
local function FormatH2Title(raw)
  raw = raw:match("^%s*(.-)%s*$") or raw
  return (raw:gsub("^%[(.-)%]", "%1"))
end

local function IsUnreleasedHeading(rawTitle)
  local title = FormatH2Title(rawTitle or "")
  return strlower(title) == "unreleased"
end

--- `4.0.1 - 2026-07-27` → version + optional date for the nav label / tooltip.
local function ParseVersionHeading(rawTitle)
  local inner = FormatH2Title(rawTitle or "")
  local ver, date = inner:match("^(.-)%s+%-%s+(.+)$")
  if ver then
    ver = ver:match("^%s*(.-)%s*$") or ver
    date = date:match("^%s*(.-)%s*$") or date
    return ver, date
  end
  return inner, nil
end

local function WrapHtml(parts)
  return "<html><body>" .. table.concat(parts) .. "</body></html>"
end

--- Parse Keep a Changelog markdown into a preamble HTML doc plus per-version HTML docs.
--- [Unreleased] (heading + body) is omitted for the in-game viewer.
local function ChangelogMarkdownToParts(md)
  if not md or md == "" then
    return WrapHtml({}), {}
  end
  local normalized = SanitizeChangelogGlyphs(md:gsub("\r\n", "\n"):gsub("\r", "\n"))
  local preambleParts = {}
  local sections = {}
  local currentParts = preambleParts
  local skipUnreleased = false
  local text = normalized .. "\n"

  local function AppendLine(parts, t)
    if t == "" then
      parts[#parts + 1] = "<br/>"
    elseif t:match("^%-%-%-+%s*$") then
      parts[#parts + 1] = "<br/><br/>"
    elseif not t:match("^%[.-%]:%s*https?://") then
      -- Skip markdown reference-link definitions (compare URLs); not useful in-game.
      if t:match("^#%s+") and not t:match("^##") then
        PushBlock(parts, "h1", ProcessInline(t:match("^#%s+(.+)$") or ""))
      elseif t:match("^###%s+") then
        local innerRaw = t:match("^###%s+(.+)$") or ""
        local h3Text = ProcessInline(innerRaw)
        local key = strlower((innerRaw:match("^%s*(.-)%s*$") or ""))
        local c = H3_SUBSECTION_COLORS[key]
        if c then
          PushBlock(parts, "h3", c .. h3Text .. "|r")
        else
          PushBlock(parts, "h3", h3Text)
        end
      elseif t:match("^%-%s+") then
        local rest = t:match("^%-%s+(.+)$") or ""
        PushBlock(parts, "p", "• " .. ProcessInline(rest))
      else
        PushBlock(parts, "p", ProcessInline(t))
      end
    end
  end

  for line in text:gmatch("([^\n]*)\n") do
    local t = line:match("^%s*(.-)%s*$") or ""
    if t:match("^##%s+") and not t:match("^###") then
      local rawTitle = t:match("^##%s+(.+)$") or ""
      skipUnreleased = IsUnreleasedHeading(rawTitle)
      if skipUnreleased then
        currentParts = nil
      else
        local version, date = ParseVersionHeading(rawTitle)
        local parts = {}
        sections[#sections + 1] = {
          version = version,
          date = date,
          parts = parts,
        }
        currentParts = parts
        PushBlock(parts, "h2", UI.AccentWrap(ProcessInline(FormatH2Title(rawTitle))))
      end
    elseif not skipUnreleased and currentParts then
      AppendLine(currentParts, t)
    end
  end

  for _, sec in ipairs(sections) do
    sec.html = WrapHtml(sec.parts)
    sec.parts = nil
  end
  return WrapHtml(preambleParts), sections
end

local function ApplySimpleHtmlFonts(body)
  local h2Font = _G.GameFontHighlightMedium or _G.GameFontHighlight
  body:SetFontObject("h1", _G.GameFontNormalLarge)
  body:SetFontObject("h2", h2Font)
  body:SetFontObject("h3", _G.GameFontHighlight)
  body:SetFontObject("p", _G.GameFontHighlightSmall)
end

local function WireSimpleHtmlLinks(body)
  body:SetScript("OnHyperlinkClick", function(_, link)
    if type(link) == "string" and link ~= "" then
      print(CM.Constants.BasePrintMsg .. "|cff69ccf0" .. link .. "|r")
    end
  end)
  body:SetScript("OnHyperlinkEnter", function(self, link)
    if type(link) ~= "string" or link == "" then
      return
    end
    UI.ShowTooltip(self, {
      title = link,
      text = "Click to print URL to chat",
    }, "ANCHOR_RIGHT")
  end)
  body:SetScript("OnHyperlinkLeave", function()
    UI.HideTooltip()
  end)
end

local function AcquireHtmlBlock(pool, parent, index)
  local block = pool[index]
  if block then
    block:SetParent(parent)
    block:Show()
    return block
  end
  block = CreateFrame("SimpleHTML", nil, parent)
  ApplySimpleHtmlFonts(block)
  WireSimpleHtmlLinks(block)
  pool[index] = block
  return block
end

local function HideExtraBlocks(pool, used)
  for i = used + 1, #pool do
    pool[i]:Hide()
  end
end

local function SetNavButtonSelected(button, selected)
  button.selected = selected
  if selected then
    button:cmSetFill(C.tabActive[1], C.tabActive[2], C.tabActive[3], C.tabActive[4])
    button.label:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
  else
    button:cmSetFill(0, 0, 0, 0)
    button.label:SetTextColor(0.56, 0.56, 0.56)
  end
end

local function SelectVersion(index, instant)
  if not changelogFrame then
    return
  end
  local frame = changelogFrame
  local offsets = frame.versionOffsets
  if not offsets or not offsets[index] then
    return
  end
  frame.selectedVersion = index
  for i, btn in ipairs(frame.navButtons or {}) do
    SetNavButtonSelected(btn, i == index)
  end
  local scroll = frame.scroll
  local y = offsets[index] - CONTENT_PAD_TOP
  if y < 0 then
    y = 0
  end
  if scroll.cmScrollTo then
    -- Dot call: cmScrollTo is a plain closure, not a method (self would break ClampScroll).
    scroll.cmScrollTo(y, instant and true or false)
  else
    scroll:SetVerticalScroll(y)
    if scroll.cmUpdate then
      scroll.cmUpdate()
    end
  end
end

--- Highlight the version whose section top is nearest above the viewport.
local function SyncNavFromScroll()
  if not changelogFrame or changelogFrame.suppressNavSync then
    return
  end
  local offsets = changelogFrame.versionOffsets
  local buttons = changelogFrame.navButtons
  if not offsets or not buttons or #offsets == 0 then
    return
  end
  local scrollY = changelogFrame.scroll:GetVerticalScroll() or 0
  local best = 1
  for i = 1, #offsets do
    if offsets[i] - CONTENT_PAD_TOP <= scrollY + 12 then
      best = i
    else
      break
    end
  end
  if changelogFrame.selectedVersion == best then
    return
  end
  changelogFrame.selectedVersion = best
  for i, btn in ipairs(buttons) do
    SetNavButtonSelected(btn, i == best)
  end
end

local function RebuildNavButtons(frame, sections)
  local keyParts = {}
  for i, sec in ipairs(sections) do
    keyParts[i] = sec.version or ""
  end
  local key = table.concat(keyParts, "\n")
  if frame.navVersionKey == key and frame.navButtons and #frame.navButtons == #sections then
    return
  end
  frame.navVersionKey = key

  for _, btn in ipairs(frame.navButtons or {}) do
    btn:Hide()
    btn:SetParent(UIParent)
  end
  frame.navButtons = {}

  local navChild = frame.navChild
  local btnW = SIDEBAR_W - 24
  local y = 0
  for i, sec in ipairs(sections) do
    local button = CreateFrame("Button", nil, navChild)
    button:SetSize(btnW, NAV_BTN_H)
    button:SetPoint("TOPLEFT", navChild, "TOPLEFT", 0, -y)
    UI.StyleRounded(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control)

    local label = UI.CreateFontString(button, "OVERLAY", UI.Fonts.nav, "GameFontNormal")
    label:SetPoint("LEFT", button, "LEFT", 10, 0)
    label:SetText(sec.version or "")
    button.label = label
    SetNavButtonSelected(button, false)

    button:SetScript("OnClick", function()
      frame.suppressNavSync = true
      SelectVersion(i, false)
      C_Timer.After(0.2, function()
        if changelogFrame then
          changelogFrame.suppressNavSync = false
        end
      end)
    end)
    button:SetScript("OnEnter", function(self)
      if not self.selected then
        self:cmSetFill(C.tabHover[1], C.tabHover[2], C.tabHover[3], C.tabHover[4])
      end
      if sec.date and sec.date ~= "" then
        UI.ShowTooltip(self, sec.date, "ANCHOR_RIGHT")
      end
    end)
    button:SetScript("OnLeave", function(self)
      if not self.selected then
        self:cmSetFill(0, 0, 0, 0)
      end
      UI.HideTooltip()
    end)

    frame.navButtons[i] = button
    y = y + NAV_BTN_H + NAV_BTN_GAP
  end
  navChild:SetWidth(btnW)
  navChild:SetHeight(math.max(y - NAV_BTN_GAP, 1))
  if frame.navScroll.cmUpdate then
    frame.navScroll.cmUpdate()
  end
end

local function LayoutChangelogContent()
  if not changelogFrame or not changelogFrame.scroll or not changelogFrame.scrollChild then
    return
  end
  local frame = changelogFrame
  local scroll = frame.scroll
  local scrollChild = frame.scrollChild
  local sw = scroll:GetWidth()
  if sw < 80 then
    return
  end

  local textW = sw - 16
  local preambleHtml, sections = ChangelogMarkdownToParts(CM.Config.ChangelogText or "")
  RebuildNavButtons(frame, sections)

  frame.htmlBlocks = frame.htmlBlocks or {}
  local pool = frame.htmlBlocks
  local used = 0
  local cursorY = CONTENT_PAD_TOP
  local offsets = {}

  local function PlaceBlock(html)
    used = used + 1
    local block = AcquireHtmlBlock(pool, scrollChild, used)
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -cursorY)
    block:SetWidth(textW)
    block:SetText(html or WrapHtml({}))
    local textH = math.max(block:GetContentHeight() or 0, 1)
    block:SetHeight(textH)
    local top = cursorY
    cursorY = cursorY + textH + SECTION_GAP
    return top, textH
  end

  -- Preamble (title + intro) stays above version sections; not linked from the nav.
  if preambleHtml and preambleHtml ~= WrapHtml({}) then
    local bare = preambleHtml:match("^<html><body>(.*)</body></html>$")
    if bare and bare:match("%S") then
      PlaceBlock(preambleHtml)
    end
  end

  for i, sec in ipairs(sections) do
    local top = PlaceBlock(sec.html)
    offsets[i] = top
  end

  HideExtraBlocks(pool, used)
  if cursorY > CONTENT_PAD_TOP then
    cursorY = cursorY - SECTION_GAP
  end
  scrollChild:SetWidth(sw)
  scrollChild:SetHeight(math.max(cursorY + CONTENT_PAD_TOP, scroll:GetHeight()))
  frame.versionOffsets = offsets

  local keep = frame.selectedVersion
  if keep and offsets[keep] then
    SelectVersion(keep, true)
  else
    SelectVersion(1, true)
  end
  if scroll.cmUpdate then
    scroll.cmUpdate()
  end
end

local function EnsureChangelogFrame()
  if changelogFrame then
    return changelogFrame
  end

  local frame = UI.CreateBareWindow(
    "CombatModeChangelogFrame",
    CM.METADATA["TITLE"] .. " - Changelog",
    WINDOW_W,
    WINDOW_H
  )
  frame:SetFrameLevel(200)
  frame:Hide()

  local divider = frame:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, 0.06)
  divider:SetWidth(1)
  divider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W - 4, -40)
  divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDEBAR_W - 4, 12)

  local versionHeader = UI.MakeHeader(frame, "Version")
  versionHeader.frame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -40)
  versionHeader.frame:SetWidth(SIDEBAR_W - 24)

  local navScroll, navChild = UI.CreateScrollFrame(frame)
  navScroll:SetPoint("TOPLEFT", versionHeader.frame, "BOTTOMLEFT", 0, -6)
  navScroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)
  navScroll:SetWidth(SIDEBAR_W - 20)
  navScroll.cmScrollBar:SetPoint("TOPLEFT", navScroll, "TOPRIGHT", 2, 0)
  navScroll.cmScrollBar:SetPoint("BOTTOMLEFT", navScroll, "BOTTOMRIGHT", 2, 0)
  navChild:SetWidth(SIDEBAR_W - 24)

  local scroll, scrollChild = UI.CreateScrollFrame(frame)
  scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_W, -40)
  scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 14)
  scroll.cmScrollBar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 6, 0)
  scroll.cmScrollBar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 6, 0)
  scrollChild:SetWidth(1)

  scroll:HookScript("OnVerticalScroll", function()
    SyncNavFromScroll()
  end)

  frame.navScroll = navScroll
  frame.navChild = navChild
  frame.scroll = scroll
  frame.scrollChild = scrollChild
  frame.navButtons = {}
  frame.htmlBlocks = {}
  frame.versionOffsets = {}
  frame.selectedVersion = nil

  scroll:HookScript("OnSizeChanged", function()
    LayoutChangelogContent()
  end)

  frame:SetScript("OnShow", function()
    frame.selectedVersion = 1
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
