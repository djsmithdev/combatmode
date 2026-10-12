---------------------------------------------------------------------------------------
--  UI/Options/LuaCodeBox.lua — OPTIONS — Lua syntax coloring + auto-indent for code boxes
---------------------------------------------------------------------------------------
--  What it does: Attaches to a multiline options EditBox (TextInput with `lua = true`)
--  and displays its text as colored Lua, re-indenting lines as the user types.
--  Architecture / how it works:
--    • The EditBox holds colored text (|cffRRGGBB ... |r, literal "|" as "||"). GetText
--      decodes and SetText encodes, so the widget's get / set / commit see plain code.
--    • Lex(raw) → tokens (comment, string, number, keyword, constant, brace). Encode
--      colors them; Decode reverses it. Caret positions map between raw and colored.
--    • Typed changes (userInput) re-indent by block depth: function / do / then /
--      repeat / else / { open; end / until / elseif / else / } close. Four spaces per level.
--    • UI.FormatLuaCode(raw) gives the same indent + coloring for static text (placeholders).
--    • Tab inserts four spaces at the caret. Our own SetText calls are guarded by `busy`
--      so they do not re-enter OnTextChanged.
--  Does not: Evaluate or validate Lua, touch the saved value (only the displayed text),
--  wrap long lines, or align continuation lines inside parentheses.
--  Related: UI/Options/Draw.lua (UI.CreateMultilineEditScroll),
--  UI/Options/Widgets.lua (UI.MakeTextInput), UI/Options/Tabs/TabAdvanced.lua,
--  Core/Runtime/UserLuaCondition.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local find = _G.string.find
local gsub = _G.string.gsub
local match = _G.string.match
local rep = _G.string.rep
local sub = _G.string.sub
local tconcat = _G.table.concat
local ipairs = _G.ipairs
local max = _G.math.max
local min = _G.math.min

local UI = CM.UI

local INDENT = "    "

local COLORS = {
  comment = "6A9955",
  string = "CE9178",
  number = "B5CEA8",
  keyword = "569CD6",
  constant = "569CD6",
}

local KEYWORDS = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["until"] = true,
  ["while"] = true,
}
local CONSTANTS = { ["true"] = true, ["false"] = true, ["nil"] = true }
local OPENERS = {
  ["function"] = true,
  ["do"] = true,
  ["then"] = true,
  ["repeat"] = true,
  ["else"] = true,
  ["{"] = true,
}
local CLOSERS =
  { ["end"] = true, ["until"] = true, ["else"] = true, ["elseif"] = true, ["}"] = true }

--- Splits Lua source into the tokens we color or indent by. Whitespace, operators and
--- plain identifiers are skipped. Positions are 1-based and inclusive.
local function Lex(src)
  local tokens = {}
  local len = #src
  local i = 1

  local function Push(kind, s, e, v)
    tokens[#tokens + 1] = { kind = kind, s = s, e = e, v = v }
  end

  while i <= len do
    local c = sub(src, i, i)
    if sub(src, i, i + 1) == "--" then
      local eq = match(src, "^%[(=*)%[", i + 2)
      local e
      if eq then
        local _, closeEnd = find(src, "]" .. eq .. "]", i + 4 + #eq, true)
        e = closeEnd or len
      else
        local nl = find(src, "\n", i, true)
        e = nl and (nl - 1) or len
      end
      Push("comment", i, e)
      i = e + 1
    elseif c == "[" and match(src, "^%[=*%[", i) then
      local eq = match(src, "^%[(=*)%[", i)
      local _, closeEnd = find(src, "]" .. eq .. "]", i + 2 + #eq, true)
      local e = closeEnd or len
      Push("string", i, e)
      i = e + 1
    elseif c == '"' or c == "'" then
      -- Quoted strings end at the matching quote or at the end of the line.
      local j = i + 1
      while j <= len do
        local ch = sub(src, j, j)
        if ch == "\\" then
          j = j + 2
        elseif ch == c or ch == "\n" then
          break
        else
          j = j + 1
        end
      end
      local stop = sub(src, j, j)
      local e = (stop == "\n") and (j - 1) or min(j, len)
      Push("string", i, e)
      i = e + 1
    elseif match(c, "%d") or (c == "." and match(src, "^%.%d", i)) then
      local num = match(src, "^0[xX]%x+", i)
        or match(src, "^%d+%.?%d*[eE][-+]?%d+", i)
        or match(src, "^%d*%.?%d+", i)
        or match(src, "^%d+%.?", i)
      local e = i + #num - 1
      Push("number", i, e)
      i = e + 1
    elseif match(c, "[%a_]") then
      local word = match(src, "^[%w_]+", i)
      local e = i + #word - 1
      if KEYWORDS[word] then
        Push("keyword", i, e, word)
      elseif CONSTANTS[word] then
        Push("constant", i, e, word)
      end
      i = e + 1
    elseif c == "{" or c == "}" then
      Push("brace", i, i, c)
      i = i + 1
    else
      i = i + 1
    end
  end

  return tokens
end

--- A literal "|" in colored text must be doubled, or it starts an escape code.
local function Escape(text)
  return (gsub(text, "|", "||"))
end

--- Plain code → colored text the EditBox can display.
local function Encode(raw)
  local parts = {}
  local pos = 1
  for _, t in ipairs(Lex(raw)) do
    local color = COLORS[t.kind]
    if color then
      parts[#parts + 1] = Escape(sub(raw, pos, t.s - 1))
      parts[#parts + 1] = "|cff" .. color .. Escape(sub(raw, t.s, t.e)) .. "|r"
      pos = t.e + 1
    end
  end
  parts[#parts + 1] = Escape(sub(raw, pos))
  return tconcat(parts)
end

--- Colored text → plain code (inverse of Encode).
local function Decode(colored)
  local out = {}
  local i = 1
  local len = #colored
  while i <= len do
    if sub(colored, i, i) ~= "|" then
      local nextBar = find(colored, "|", i, true) or (len + 1)
      out[#out + 1] = sub(colored, i, nextBar - 1)
      i = nextBar
    else
      local nx = sub(colored, i + 1, i + 1)
      if nx == "|" then
        out[#out + 1] = "|"
        i = i + 2
      elseif nx == "c" then
        i = i + 10
      elseif nx == "r" then
        i = i + 2
      else
        out[#out + 1] = "|"
        i = i + 1
      end
    end
  end
  return tconcat(out)
end

--- Plain caret (0-based count of visible characters) → colored caret (0-based byte offset).
local function ColoredOffsetOf(colored, rawPos)
  local raw, i = 0, 1
  local len = #colored
  while i <= len and raw < rawPos do
    if sub(colored, i, i) == "|" then
      local nx = sub(colored, i + 1, i + 1)
      if nx == "c" then
        i = i + 10
      elseif nx == "r" then
        i = i + 2
      else
        raw = raw + 1
        i = i + ((nx == "|") and 2 or 1)
      end
    else
      raw = raw + 1
      i = i + 1
    end
  end
  return i - 1
end

--- Colored caret (0-based byte offset) → plain caret (visible characters before it).
local function RawCountBefore(colored, pos)
  local raw, i = 0, 1
  local len = #colored
  while i <= len and i - 1 < pos do
    if sub(colored, i, i) == "|" then
      local nx = sub(colored, i + 1, i + 1)
      if nx == "c" then
        i = i + 10
      elseif nx == "r" then
        i = i + 2
      else
        raw = raw + 1
        i = i + ((nx == "|") and 2 or 1)
      end
    else
      raw = raw + 1
      i = i + 1
    end
  end
  return raw
end

--- Re-indents every line of `raw` by block depth. `caret` is a 0-based count of plain
--- characters before the caret; returns the new plain text and new caret.
local function Reindent(raw, caret)
  local tokens = Lex(raw)
  local count = #tokens
  local ti = 1
  local depth = 0
  local spanEnd = 0 -- furthest end of a token that started on an earlier line
  local out = {}
  local shift = 0 -- length change applied to text before the current line
  local caretIdx = caret + 1 -- 1-based index of the character right after the caret
  local newCaretIdx
  local len = #raw
  local lineStart = 1

  while true do
    local nl = find(raw, "\n", lineStart, true)
    local lineEnd = nl and (nl - 1) or len
    local lead = match(raw, "^[ \t]*", lineStart)
    local leadLen = #lead
    local insideSpan = spanEnd >= lineStart
    local startDepth = depth

    local firstTok = tokens[ti]
    local dedentFirst = false
    if not insideSpan and firstTok and firstTok.s <= lineEnd then
      if firstTok.kind == "keyword" or firstTok.kind == "brace" then
        dedentFirst = CLOSERS[firstTok.v] == true
      end
    end

    while ti <= count and tokens[ti].s <= lineEnd do
      local t = tokens[ti]
      if t.e > spanEnd then
        spanEnd = t.e
      end
      if t.kind == "keyword" or t.kind == "brace" then
        if CLOSERS[t.v] then
          depth = max(0, depth - 1)
        end
        if OPENERS[t.v] then
          depth = depth + 1
        end
      end
      ti = ti + 1
    end

    local newLead = lead
    if not insideSpan then
      local base = startDepth - (dedentFirst and 1 or 0)
      newLead = rep(INDENT, max(0, base))
      -- Blank lines only keep indentation where the caret is (Enter); elsewhere they are trimmed.
      local blank = lineStart + leadLen > lineEnd
      local caretHere = caretIdx >= lineStart and caretIdx <= lineEnd + 1
      if blank and not caretHere then
        newLead = ""
      end
    end

    local delta = #newLead - leadLen
    if not newCaretIdx and caretIdx <= lineEnd + 1 then
      if caretIdx >= lineStart + leadLen then
        newCaretIdx = caretIdx + shift + delta
      else
        newCaretIdx = lineStart + shift + #newLead
      end
    end

    out[#out + 1] = newLead .. sub(raw, lineStart + leadLen, lineEnd)
    if nl then
      out[#out + 1] = "\n"
    end
    shift = shift + delta

    if not nl then
      break
    end
    lineStart = nl + 1
  end

  return tconcat(out), (newCaretIdx or (caretIdx + shift)) - 1
end

--- Plain code → re-indented, colored text for read-only display (code-box placeholders).
function UI.FormatLuaCode(raw)
  local indented = Reindent(raw or "", 0)
  return Encode(indented)
end

--- Attaches highlighting, auto-indent and Tab handling to a multiline options EditBox.
--- Call before the widget's first SetText. GetText / SetText keep plain-code semantics.
function UI.AttachLuaCodeBox(edit)
  if edit.cmLuaCodeBox then
    return
  end
  edit.cmLuaCodeBox = true

  local rawGetText = edit.GetText
  local rawSetText = edit.SetText
  local busy = false

  local function Displayed()
    return rawGetText(edit) or ""
  end

  --- Writes plain code to the EditBox as colored text. `caret` (optional) is the plain
  --- caret position to restore.
  local function Write(raw, caret)
    local colored = Encode(raw)
    if colored ~= Displayed() then
      busy = true
      rawSetText(edit, colored)
      busy = false
    end
    if caret then
      edit:SetCursorPosition(ColoredOffsetOf(colored, caret))
    end
  end

  edit.GetText = function()
    return Decode(Displayed())
  end

  edit.SetText = function(_, text)
    Write(text or "", nil)
  end

  edit:HookScript("OnTextChanged", function(self, userInput)
    if busy then
      return
    end
    local displayed = Displayed()
    local raw = Decode(displayed)
    local caret = RawCountBefore(displayed, self:GetCursorPosition())
    if userInput then
      raw, caret = Reindent(raw, caret)
    end
    Write(raw, caret)
  end)

  edit:SetScript("OnTabPressed", function(self)
    local displayed = Displayed()
    local raw = Decode(displayed)
    local caret = RawCountBefore(displayed, self:GetCursorPosition())
    raw = sub(raw, 1, caret) .. INDENT .. sub(raw, caret + 1)
    Write(raw, caret + #INDENT)
  end)
end
