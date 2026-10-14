---------------------------------------------------------------------------------------
--  UI/Options/LuaCodeBox.lua — OPTIONS — Lua syntax coloring, auto-indent, diagnostics and name suggestions for code boxes
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
--    • UI.FormatLuaCode(raw) gives the same indent + coloring (incl. Blizzard names) for static
--      text (placeholders).
--    • Tab inserts four spaces at the caret. Our own SetText calls are guarded by `busy`
--      so they do not re-enter OnTextChanged.
--    • Diagnostics: once typing pauses (DIAGNOSE_DELAY), the code is compiled with
--      loadstring (compile only, never run) and a syntax error is reported with its line.
--      Blizzard API names (issecurevariable) are tinted yellow so they stand out; names that
--      are not in the live game API are tinted red and listed, with a "did you mean"
--      suggestion. Only names used as calls / chains / right after and, or,
--      not, if, return… are checked, locals, parameters and assigned names are skipped, and
--      only C_* / Enum members are checked one level deep, so it stays quiet when unsure.
--      The optional `onStatus(text|nil)` callback receives the one-line message to show.
--    • Line numbers (optional gutter passed by the widget): one per logical line, blank rows for the
--      rows a wrapped line spills onto (measured with a hidden FontString), scrolling with the editor.
--    • Suggestions: while typing a name (2+ letters, or after `C_Foo.` / `Enum.`) a popup lists
--      matching live global names / members, Blizzard names in yellow. Up / Down choose, Tab,
--      Enter or a click accepts, Escape or moving the caret sideways closes it. Names being
--      declared (local / function), member access on other tables, strings and comments get
--      none. Key handling logs through CM.DebugPrint (Debug Mode) to help diagnose input.
--  Does not: Run the code, touch the saved value (only the displayed text), judge logic,
--  know combat restrictions (a name can exist and still be protected), wrap long lines,
--  or align continuation lines inside parentheses.
--  Related: UI/Options/Draw.lua (UI.CreateMultilineEditScroll),
--  UI/Options/Widgets.lua (UI.MakeTextInput), UI/Options/Tabs/TabAdvanced.lua,
--  Core/Runtime/UserLuaCondition.lua
---------------------------------------------------------------------------------------
local _, CM = ...
local _G = _G

-- Lua stdlib
local byte = _G.string.byte
local find = _G.string.find
local floor = _G.math.floor
local gmatch = _G.string.gmatch
local gsub = _G.string.gsub
local lower = _G.string.lower
local match = _G.string.match
local rep = _G.string.rep
local sub = _G.string.sub
local tconcat = _G.table.concat
local tostring = _G.tostring
local tsort = _G.table.sort
local upper = _G.string.upper
local abs = _G.math.abs
local ipairs = _G.ipairs
local issecurevariable = _G.issecurevariable
local loadstring = _G.loadstring
local max = _G.math.max
local min = _G.math.min
local pairs = _G.pairs
local pcall = _G.pcall
local type = _G.type
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UIParent = _G.UIParent

local UI = CM.UI

local INDENT = "    "
local DIAGNOSE_DELAY = 0.6 -- seconds of typing pause before compile + API checks run
local MAX_MARKS = 30 -- unknown names listed / tinted
local MAX_API_MARKS = 200 -- emphasized Blizzard names
local MAX_SUGGESTIONS = 8 -- rows in the suggestion popup
local SUGGEST_ROW_H = 22 -- same row height as the search dropdown and menus

local COLORS = {
  comment = "6A9955",
  string = "CE9178",
  number = "B5CEA8",
  keyword = "569CD6",
  constant = "569CD6",
  unknown = "F47067",
  api = "E6C84C", -- Blizzard API names, emphasized
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

---------------------------------------------------------------------------------------
--                                    DIAGNOSTICS                                    --
---------------------------------------------------------------------------------------

--- Same text with comments and strings blanked out (newlines kept), so names inside them
--- are ignored and every position still lines up with `raw`.
local function Mask(raw, tokens)
  local parts = {}
  local pos = 1
  for _, t in ipairs(tokens) do
    if t.kind == "comment" or t.kind == "string" then
      parts[#parts + 1] = sub(raw, pos, t.s - 1)
      parts[#parts + 1] = (gsub(sub(raw, t.s, t.e), "[^\n]", " "))
      pos = t.e + 1
    end
  end
  parts[#parts + 1] = sub(raw, pos)
  return tconcat(parts)
end

local STATEMENT_BREAKS =
  { "\n", ";", "%f[%w_]then%f[^%w_]", "%f[%w_]do%f[^%w_]", "%f[%w_]else%f[^%w_]" }

--- Every name the snippet defines itself: locals, function names and parameters, loop
--- variables, and assignment targets. These are never reported as unknown.
local function CollectDeclared(masked)
  local declared = {}

  -- "a, b, c" starting at `i`; returns where the list ended.
  local function NamesFrom(i)
    while true do
      local name, after = match(masked, "^%s*([%a_][%w_]*)()", i)
      if not name then
        return i
      end
      declared[name] = true
      local nextStart = match(masked, "^%s*,()", after)
      if not nextStart then
        return after
      end
      i = nextStart
    end
  end

  for pos in gmatch(masked, "%f[%w_]local%f[^%w_]()") do
    local afterFunction = match(masked, "^%s*function%f[^%w_]()", pos)
    NamesFrom(afterFunction or pos)
  end
  for pos in gmatch(masked, "%f[%w_]for%f[^%w_]()") do
    NamesFrom(pos)
  end
  for chain, params in gmatch(masked, "%f[%w_]function%f[^%w_]([^(]-)%(([^)]*)%)") do
    local first = match(chain, "^%s*([%a_][%w_]*)")
    if first then
      declared[first] = true
    end
    for name in gmatch(params, "[%a_][%w_]*") do
      declared[name] = true
    end
  end
  -- Assignment targets: every name left of a lone "=" in its statement.
  for pos in gmatch(masked, "()=") do
    local before, after = sub(masked, pos - 1, pos - 1), sub(masked, pos + 1, pos + 1)
    if not find(before, "[=~<>]") and after ~= "=" then
      local lineStart = 1
      for _, pattern in ipairs(STATEMENT_BREAKS) do
        local from = 1
        while true do
          local _, stop = find(masked, pattern, from)
          if not stop or stop >= pos then
            break
          end
          lineStart = max(lineStart, stop + 1)
          from = stop + 1
        end
      end
      for s, name in gmatch(sub(masked, lineStart, pos - 1), "()([%a_][%w_]*)") do
        local prevChar = sub(masked, lineStart + s - 2, lineStart + s - 2)
        if prevChar ~= "." and prevChar ~= ":" then
          declared[name] = true
        end
      end
    end
  end
  return declared
end

local USE_AFTER = {
  ["and"] = true,
  ["or"] = true,
  ["not"] = true,
  ["if"] = true,
  ["elseif"] = true,
  ["while"] = true,
  ["until"] = true,
  ["return"] = true,
}

-- Lua's own library: real names, but not Blizzard's, so they are not emphasized.
local LUA_LIBRARY = {}
for name in
  gmatch(
    "_G _VERSION assert collectgarbage error getfenv getmetatable ipairs loadstring next pairs pcall rawequal rawget rawset select setfenv setmetatable tonumber tostring type unpack xpcall string table math os io bit coroutine debug",
    "%S+"
  )
do
  LUA_LIBRARY[name] = true
end

--- True when `tbl[key]` was defined by Blizzard (untainted), not by an addon.
local function IsBlizzard(tbl, key)
  if tbl == _G and LUA_LIBRARY[key] then
    return false
  end
  if issecurevariable then
    return issecurevariable(tbl, key) and true or false
  end
  return true
end

--- Scans the code for API names. Returns two lists of { s, e, ... } ranges:
---   unknown  names the snippet uses that are not in the live game API (with name / namespace
---            / member for the message). Only "uses" are checked (calls, chains, indexing, and
---            bare values right after and / or / not / if / return…), and only the first name
---            of a chain, plus one level into C_* / Enum.
---   apis     names that exist and are Blizzard's, to be emphasized.
--- Locals, parameters, assigned names and `.field` / `:method` accesses are skipped.
local function Scan(masked)
  local declared = CollectDeclared(masked)
  local unknown, apis = {}, {}
  for s, name, e in gmatch(masked, "()([%a_][%w_]*)()") do
    if
      not KEYWORDS[name]
      and not CONSTANTS[name]
      and not declared[name]
      and not find(sub(masked, s - 1, s - 1), "[%w_]")
    then
      local i = s - 1
      while i >= 1 and find(sub(masked, i, i), "%s") do
        i = i - 1
      end
      local prevChar = sub(masked, i, i)
      local isMember = prevChar == ":" or (prevChar == "." and sub(masked, i - 1, i - 1) ~= ".")
      if not isMember then
        local nextChar, nextNext = match(masked, "^%s*(.)(.?)", e)
        local previousWord = match(sub(masked, 1, s - 1), "([%a_][%w_]*)%s*$")
        local isUse = nextChar == "("
          or nextChar == "."
          or nextChar == ":"
          or nextChar == '"'
          or nextChar == "'"
          or nextChar == "{"
          or nextChar == "["
          or (USE_AFTER[previousWord] and not (nextChar == "=" and nextNext ~= "="))
        local value = _G[name]
        if value == nil then
          if isUse and #unknown < MAX_MARKS then
            unknown[#unknown + 1] = { s = s, e = e - 1, name = name, color = COLORS.unknown }
          end
        else
          if #apis < MAX_API_MARKS and IsBlizzard(_G, name) then
            apis[#apis + 1] = { s = s, e = e - 1, color = COLORS.api }
          end
          if type(value) == "table" and (name == "Enum" or find(name, "^C_")) then
            local ms, member, me = match(masked, "^%s*%.%s*()([%a_][%w_]*)()", e)
            if member then
              if value[member] == nil then
                if #unknown < MAX_MARKS then
                  unknown[#unknown + 1] = {
                    s = ms,
                    e = me - 1,
                    name = name .. "." .. member,
                    namespace = name,
                    member = member,
                    color = COLORS.unknown,
                  }
                end
              elseif #apis < MAX_API_MARKS and IsBlizzard(value, member) then
                apis[#apis + 1] = { s = ms, e = me - 1, color = COLORS.api }
              end
            end
          end
        end
      end
    end
  end
  return unknown, apis
end

--- Edit distance between `a` and `b`, or limit + 1 once it is certain to exceed `limit`.
local function Distance(a, b, limit)
  local la, lb = #a, #b
  if abs(la - lb) > limit then
    return limit + 1
  end
  local prev, cur = {}, {}
  for j = 0, lb do
    prev[j] = j
  end
  for i = 1, la do
    cur[0] = i
    local rowMin = i
    local ca = byte(a, i)
    for j = 1, lb do
      local cost = (ca == byte(b, j)) and 0 or 1
      local v = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
      cur[j] = v
      if v < rowMin then
        rowMin = v
      end
    end
    if rowMin > limit then
      return limit + 1
    end
    prev, cur = cur, prev
  end
  return prev[lb]
end

--- The closest real name to `name` among the keys of `pool`, or nil. A different capital
--- letter counts as a match; otherwise it allows 1 typo (2 for names of 5+ letters).
local function Suggest(name, pool)
  local limit = (#name >= 5) and 2 or 1
  local lowerName = lower(name)
  local best, bestDistance
  for key in pairs(pool) do
    if type(key) == "string" and abs(#key - #name) <= limit then
      if lower(key) == lowerName then
        return key
      end
      if byte(lower(key), 1) == byte(lowerName, 1) then
        local d = Distance(key, name, limit)
        if d <= limit and (not bestDistance or d < bestDistance) then
          best, bestDistance = key, d
        end
      end
    end
  end
  return best
end

--- Compiles `raw` (never runs it) and returns "Line N: message" for a syntax error.
local function SyntaxError(raw)
  local func, err = loadstring(raw, "=code")
  if func then
    return nil
  end
  local line, message = match(tostring(err), "^code:(%d+): (.*)$")
  if line then
    return "Line " .. line .. ": " .. message
  end
  return tostring(err)
end

--- One-line status for the code: a syntax error, else the first unknown API name.
local function Describe(raw, unknown)
  if find(raw, "^%s*$") then
    return nil
  end
  local syntax = SyntaxError(raw)
  if syntax then
    return syntax
  end
  local first = unknown[1]
  if not first then
    return nil
  end
  local pool = first.namespace and _G[first.namespace] or _G
  local hint = Suggest(first.member or first.name, pool)
  local text = "Unknown API: " .. first.name
  if hint then
    text = text
      .. " - did you mean "
      .. (first.namespace and (first.namespace .. ".") or "")
      .. hint
      .. "?"
  end
  if #unknown > 1 then
    text = text .. " (+" .. (#unknown - 1) .. " more)"
  end
  return text
end

---------------------------------------------------------------------------------------
--                                    SUGGESTIONS                                    --
---------------------------------------------------------------------------------------

--- What is being typed at the caret: returns the typed `prefix` and the table to complete
--- it from, or nil when nothing should be suggested. Completes global names, and the members
--- of C_* / Enum after a dot. `caret` is the count of characters before the caret.
local function SuggestionContext(raw, caret)
  for _, t in ipairs(Lex(raw)) do
    if (t.kind == "comment" or t.kind == "string") and caret >= t.s and caret < t.e then
      return nil
    end
  end
  local before = sub(raw, 1, caret)
  local word = match(before, "([%a_][%w_]*)$") or ""
  local head = sub(before, 1, #before - #word)
  local namespace = match(head, "([%a_][%w_]*)%.$")
  if namespace then
    local pool = _G[namespace]
    if (namespace == "Enum" or find(namespace, "^C_")) and type(pool) == "table" then
      return word, pool
    end
    return nil
  end
  if word == "" or #word < 2 or find(head, "[%.:]%s*$") then
    return nil
  end
  -- Naming something new (local x / function x): nothing to complete.
  if match(head, "%f[%w_]local%s+$") or match(head, "%f[%w_]function%s+$") then
    return nil
  end
  return word, _G
end

--- Keys of `pool` that start with `prefix` (any capitalization), best first: exact
--- capitalization, then shorter, then alphabetical.
local function Matches(pool, prefix)
  local lowerPrefix = lower(prefix)
  local lowFirst = byte(lowerPrefix, 1)
  local upFirst = byte(upper(prefix), 1)
  local list = {}
  for key in pairs(pool) do
    if type(key) == "string" and #key >= #prefix and match(key, "^[%a_][%w_]*$") then
      local first = byte(key, 1)
      if prefix == "" or first == lowFirst or first == upFirst then
        if sub(lower(key), 1, #lowerPrefix) == lowerPrefix then
          list[#list + 1] = key
        end
      end
    end
  end
  tsort(list, function(a, b)
    local exactA, exactB = sub(a, 1, #prefix) == prefix, sub(b, 1, #prefix) == prefix
    if exactA ~= exactB then
      return exactA
    end
    if #a ~= #b then
      return #a < #b
    end
    return a < b
  end)
  return list
end

--- A literal "|" in colored text must be doubled, or it starts an escape code.
local function Escape(text)
  return (gsub(text, "|", "||"))
end

--- Plain code → colored text the EditBox can display. `marks` (optional) are extra
--- { s, e, color } ranges (unknown API names, emphasized Blizzard names); they never overlap
--- a lexed token.
local function Encode(raw, marks)
  local spans = {}
  for _, t in ipairs(Lex(raw)) do
    if COLORS[t.kind] then
      spans[#spans + 1] = { s = t.s, e = t.e, color = COLORS[t.kind] }
    end
  end
  if marks then
    for _, m in ipairs(marks) do
      spans[#spans + 1] = { s = m.s, e = m.e, color = m.color or COLORS.unknown }
    end
    tsort(spans, function(a, b)
      return a.s < b.s
    end)
  end
  local parts = {}
  local pos = 1
  for _, span in ipairs(spans) do
    if span.s >= pos then
      parts[#parts + 1] = Escape(sub(raw, pos, span.s - 1))
      parts[#parts + 1] = "|cff" .. span.color .. Escape(sub(raw, span.s, span.e)) .. "|r"
      pos = span.e + 1
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
  local _, apis = Scan(Mask(indented, Lex(indented)))
  return Encode(indented, apis) -- Blizzard names are emphasized; placeholders are never flagged
end

--- Attaches highlighting, auto-indent, Tab handling and code diagnostics to a multiline
--- options EditBox. Call before the widget's first SetText. GetText / SetText keep plain-code
--- semantics. `onStatus(text|nil)` (optional) is called with the one-line diagnostic for the
--- current code (syntax error / unknown API name), or nil when there is nothing to report.
--- `anchor` (optional frame) is where the suggestion popup hangs below; defaults to the edit.
--- `gutter` (optional) = { frame, fs, scroll, padRight, padTop, zone }: a clipping strip left of the editor,
--- the FontString that shows the line numbers inside it (kept padRight / padTop from the strip's
--- top-right corner), the ScrollFrame the editor lives in, and the strip behind the numbers (`zone`).
--- The whole gutter hides while the box is empty (only its placeholder hint is showing).
function UI.AttachLuaCodeBox(edit, onStatus, anchor, gutter)
  if edit.cmLuaCodeBox then
    return
  end
  edit.cmLuaCodeBox = true

  local rawGetText = edit.GetText
  local rawSetText = edit.SetText
  local busy = false
  local unknown = {} -- unknown API names found by the last Write
  local settleTimer
  local statusShown = false

  local function Displayed()
    return rawGetText(edit) or ""
  end

  local function SetStatus(text)
    if not onStatus or (text == nil and not statusShown) then
      return
    end
    statusShown = text ~= nil
    onStatus(text)
  end

  -- Line numbers: one per logical line, with blank rows for the extra rows a long line wraps
  -- onto, so each number stays level with the first row of its line.
  local measure
  local function UpdateGutter(raw)
    if not gutter then
      return
    end
    -- Nothing written (only the placeholder hint is showing): no gutter at all.
    local hasCode = raw ~= ""
    gutter.frame:SetShown(hasCode)
    if gutter.zone then
      gutter.zone:SetShown(hasCode)
    end
    if not hasCode then
      return
    end
    local font, size, flags = edit:GetFont()
    if not font then
      return -- the editor font is not set yet; the next write / resize will fill the numbers in
    end
    if not measure then
      measure = gutter.frame:CreateFontString(nil, "OVERLAY")
      measure:SetAlpha(0)
      measure:SetWordWrap(true)
      measure:SetPoint("TOPLEFT", gutter.frame, "TOPLEFT", 0, 0)
    end
    measure:SetFont(font, size, flags)
    gutter.fs:SetFont(font, size, flags)
    measure:SetWidth(max(edit:GetWidth() or 1, 1))
    measure:SetText("A")
    local rowHeight = max(measure:GetStringHeight() or 1, 1)
    local numbers, n = {}, 0
    for line in gmatch(raw .. "\n", "([^\n]*)\n") do
      n = n + 1
      numbers[#numbers + 1] = n
      measure:SetText(line == "" and " " or Escape(line))
      local rowsUsed = max(1, floor((measure:GetStringHeight() or rowHeight) / rowHeight + 0.5))
      for _ = 2, rowsUsed do
        numbers[#numbers + 1] = ""
      end
    end
    gutter.fs:SetText(tconcat(numbers, "\n"))
  end

  local function SyncGutterScroll()
    if gutter then
      gutter.fs:ClearAllPoints()
      gutter.fs:SetPoint(
        "TOPRIGHT",
        gutter.frame,
        "TOPRIGHT",
        -(gutter.padRight or 0),
        (gutter.scroll:GetVerticalScroll() or 0) - (gutter.padTop or 0)
      )
    end
  end

  --- Writes plain code to the EditBox as colored text. `caret` (optional) is the plain
  --- caret position to restore. While `typing`, the word at the caret is not tinted yet
  --- (it is probably unfinished).
  local function Write(raw, caret, typing)
    local apis
    unknown, apis = Scan(Mask(raw, Lex(raw)))
    local marks = {}
    for _, list in ipairs({ unknown, apis }) do
      for _, m in ipairs(list) do
        -- While typing, the word at the caret is probably unfinished: leave it plain for now.
        if not (typing and caret and caret >= m.s - 1 and caret <= m.e) then
          marks[#marks + 1] = m
        end
      end
    end
    local colored = Encode(raw, marks)
    if colored ~= Displayed() then
      busy = true
      rawSetText(edit, colored)
      busy = false
    end
    if caret then
      edit:SetCursorPosition(ColoredOffsetOf(colored, caret))
    end
    UpdateGutter(raw)
  end

  --- Typing paused (or focus left): tint every unknown name and report the first problem.
  local function Settle()
    settleTimer = nil
    local displayed = Displayed()
    local raw = Decode(displayed)
    local caret = edit:HasFocus() and RawCountBefore(displayed, edit:GetCursorPosition()) or nil
    Write(raw, caret, false)
    SetStatus(Describe(raw, unknown))
  end

  local function ScheduleSettle()
    if settleTimer then
      settleTimer:Cancel()
      settleTimer = nil
    end
    if C_Timer and C_Timer.NewTimer then
      settleTimer = C_Timer.NewTimer(DIAGNOSE_DELAY, Settle)
    end
  end

  -- Suggestion popup: opens while typing a name; Up / Down choose, Tab / Enter / a click accepts.
  local popup, rows, moreFs
  local items, itemPool, selected = {}, _G, 1
  local lastCaret = 0
  local shownFor = {} -- { raw, caret } the popup was opened for
  local swallowNewline = false -- Enter just accepted a suggestion: drop the newline it types
  local lastNavKey, lastNavAt -- de-duplicates a key reported by both OnKeyDown and OnArrowPressed

  local function HidePopup()
    items = {}
    if popup then
      popup:Hide()
    end
  end

  local function PopupShown()
    return popup ~= nil and popup:IsShown()
  end

  local function Highlight()
    local colors = UI.Colors
    for i, row in ipairs(rows) do
      if i == selected and row:IsShown() then
        row:cmSetFillGradient(colors.hoverFillTop, colors.hoverFillBottom)
        row:cmSetBorderGradient(colors.hoverBorderTop, colors.hoverBorderBottom)
      else
        row:cmSetFill(0, 0, 0, 0)
        row:cmSetBorder(0, 0, 0, 0)
      end
    end
  end

  local function Accept(index)
    local key = items[index or selected]
    if not key then
      return
    end
    local displayed = Displayed()
    local raw = Decode(displayed)
    -- Clicking a row takes focus from the box and the caret is lost, so while the text is
    -- unchanged use the place the popup was opened for.
    local caret
    if raw == shownFor.raw then
      caret = shownFor.caret
    else
      caret = RawCountBefore(displayed, edit:GetCursorPosition())
    end
    local word = SuggestionContext(raw, caret)
    if not word then
      HidePopup()
      return
    end
    raw = sub(raw, 1, caret - #word) .. key .. sub(raw, caret + 1)
    HidePopup()
    Write(raw, caret - #word + #key, true)
    lastCaret = edit:GetCursorPosition()
    ScheduleSettle()
  end

  local function EnsurePopup()
    if popup then
      return
    end
    local colors = UI.Colors
    popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    UI.StyleField(popup)
    popup:Hide()
    popup:SetScript("OnUpdate", function()
      if not edit:IsVisible() then
        HidePopup()
      end
    end)
    rows = {}
    for i = 1, MAX_SUGGESTIONS do
      local row = CreateFrame("Button", nil, popup)
      row:SetHeight(SUGGEST_ROW_H)
      row:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4 - (i - 1) * SUGGEST_ROW_H)
      row:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4 - (i - 1) * SUGGEST_ROW_H)
      UI.StyleRounded(row, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, UI.Radius.control, 1)
      row.kind = UI.CreateFontString(row, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
      row.kind:SetPoint("RIGHT", row, "RIGHT", -8, 0)
      row.kind:SetTextColor(colors.textDim[1], colors.textDim[2], colors.textDim[3])
      row.text = UI.CreateFontString(row, "OVERLAY", UI.Fonts.button, "GameFontNormal")
      row.text:SetPoint("LEFT", row, "LEFT", 8, 0)
      row.text:SetPoint("RIGHT", row.kind, "LEFT", -8, 0)
      row.text:SetJustifyH("LEFT")
      row.text:SetWordWrap(false) -- a long name ends in "..." instead of running under the type
      row.text:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
      row:SetScript("OnEnter", function()
        selected = i
        Highlight()
      end)
      row:SetScript("OnClick", function()
        Accept(i)
        edit:SetFocus()
        edit:SetCursorPosition(lastCaret)
      end)
      rows[i] = row
    end
    moreFs = UI.CreateFontString(popup, "OVERLAY", UI.Fonts.desc, "GameFontHighlightSmall")
    moreFs:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 12, 5)
    moreFs:SetTextColor(colors.textDim[1], colors.textDim[2], colors.textDim[3])
  end

  local function ShowPopup(list, prefix, pool, raw, caret)
    EnsurePopup()
    items, itemPool, selected = list, pool, 1
    shownFor = { raw = raw, caret = caret }
    local shown = min(#list, MAX_SUGGESTIONS)
    for i, row in ipairs(rows) do
      local key = list[i]
      if i <= shown then
        row.text:SetText(
          "|cff" .. COLORS.api .. sub(key, 1, #prefix) .. "|r" .. sub(key, #prefix + 1)
        )
        row.kind:SetText(type(itemPool[key]))
        row:Show()
      else
        row:Hide()
      end
    end
    local extra = #list - shown
    moreFs:SetText(extra > 0 and ("+" .. extra .. " more - keep typing") or "")
    popup:SetHeight(8 + shown * SUGGEST_ROW_H + (extra > 0 and 14 or 0))
    local host = anchor or edit
    popup:ClearAllPoints()
    -- Same left and right edges as the input it belongs to.
    popup:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -2)
    popup:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, -2)
    Highlight()
    popup:Show()
  end

  --- Up / Down move the highlight, Left / Right close the popup. Returns true if the key was
  --- used. WoW may report an arrow through OnKeyDown, OnArrowPressed or both, so both call this.
  local function HandleNavKey(key)
    if not PopupShown() then
      return false
    end
    if key == "UP" or key == "DOWN" then
      local now = GetTime()
      if lastNavKey == key and lastNavAt == now then
        return true
      end
      lastNavKey, lastNavAt = key, now
      local count = min(#items, MAX_SUGGESTIONS)
      selected = (key == "UP") and ((selected - 2) % count + 1) or (selected % count + 1)
      Highlight()
      CM.DebugPrint(
        "Suggestions: " .. key .. " -> row " .. selected .. " (" .. tostring(items[selected]) .. ")"
      )
      -- The arrow also moves the text caret; once WoW has done that, put it back.
      if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
          if PopupShown() then
            edit:SetCursorPosition(lastCaret)
          end
        end)
      end
      return true
    elseif key == "LEFT" or key == "RIGHT" then
      HidePopup() -- the caret is moving away from the name being typed
    end
    return false
  end

  local function UpdateSuggestions(raw, caret)
    local prefix, pool = SuggestionContext(raw, caret)
    if not prefix then
      HidePopup()
      return
    end
    local list = Matches(pool, prefix)
    if #list == 0 or (#list == 1 and list[1] == prefix) then
      HidePopup()
      return
    end
    ShowPopup(list, prefix, pool, raw, caret)
  end

  edit.GetText = function()
    return Decode(Displayed())
  end

  edit.SetText = function(_, text)
    local raw = text or ""
    if raw ~= Decode(Displayed()) then
      HidePopup() -- the text was replaced from outside
    end
    Write(raw, nil, false)
    SetStatus(Describe(raw, unknown))
  end

  edit:HookScript("OnTextChanged", function(self, userInput)
    if busy then
      return
    end
    local displayed = Displayed()
    local raw = Decode(displayed)
    local caret = RawCountBefore(displayed, self:GetCursorPosition())
    if
      userInput
      and caret > 0
      and sub(raw, caret, caret) == "\n"
      and (swallowNewline or PopupShown())
    then
      -- Enter with the popup open: take back the newline it typed (and insert the name if the
      -- key-down handler has not already).
      local accepted = swallowNewline
      swallowNewline = false
      Write(sub(raw, 1, caret - 1) .. sub(raw, caret + 1), caret - 1, true)
      lastCaret = self:GetCursorPosition()
      if not accepted then
        CM.DebugPrint("Suggestions: Enter accepted via the typed newline")
        Accept()
      end
      return
    end
    if userInput then
      raw, caret = Reindent(raw, caret)
      SetStatus(nil) -- the old message no longer describes this text
      ScheduleSettle()
    end
    Write(raw, caret, userInput)
    lastCaret = self:GetCursorPosition()
    if userInput then
      UpdateSuggestions(raw, caret)
    end
    -- Not user input (e.g. the box re-wrapping when the status line appears): leave the popup.
  end)

  edit:HookScript("OnArrowPressed", function(_, key)
    HandleNavKey(key)
  end)

  edit:HookScript("OnKeyDown", function(_, key)
    if key == "ENTER" or key == "NUMPADENTER" then
      if PopupShown() then
        CM.DebugPrint("Suggestions: Enter accepted via key down")
        swallowNewline = true
        Accept()
        if C_Timer and C_Timer.After then
          C_Timer.After(0.2, function()
            swallowNewline = false
          end)
        end
      end
    else
      HandleNavKey(key)
    end
  end)

  if gutter then
    gutter.scroll:HookScript("OnVerticalScroll", SyncGutterScroll)
    edit:HookScript("OnSizeChanged", function()
      UpdateGutter(Decode(Displayed()))
      SyncGutterScroll()
    end)
  end

  edit:HookScript("OnEscapePressed", HidePopup)
  edit:HookScript("OnHide", HidePopup)

  edit:HookScript("OnEditFocusLost", function()
    if settleTimer then
      settleTimer:Cancel()
    end
    Settle()
    if not (popup and popup:IsMouseOver()) then
      HidePopup()
    end
  end)

  edit:SetScript("OnTabPressed", function(self)
    if PopupShown() then
      CM.DebugPrint("Suggestions: Tab accepted")
      Accept()
      return
    end
    local displayed = Displayed()
    local raw = Decode(displayed)
    local caret = RawCountBefore(displayed, self:GetCursorPosition())
    raw = sub(raw, 1, caret) .. INDENT .. sub(raw, caret + 1)
    Write(raw, caret + #INDENT, true)
    ScheduleSettle()
  end)
end
