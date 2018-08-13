
--[[ Depends on the functions:
  - ipairs
  - string.sub
  - string.byte
  - string.lower
  - table.insert
]]

-- Provides string.find, string.match
-- TODO: Captures, string.gmatch, string.gsub, remove string.charat

function string:charat(i) return self:sub(i, i) end

-- Basic classes
local function digit (code) return code >= 48 and code <= 57 end
local function lower (code) return code >= 97 and code <= 122 end
local function upper (code) return code >= 65 and code <= 90 end
local function letter (code) return lower(code) or upper(code) end
local function space (code) return code == 9 or code == 10 or code == 32 end
local function control (code) return code < 32 or code == 127 end
local function printable (code) return not control(code) and not space(code) end
local function alphanum (code) return letter(code) or digit(code) end
local function punctuation (code) return printable(code) and not alphanum(code) end
local function hex (code) return digit(code) or (code >= 65 and code <= 70) or (code >= 97 and code <= 102) end

local function all () return true end

local function complement (item)
  return function (code)
    return not item(code)
  end
end

local function make_range (_a, _b)
  local a, b = _a:byte(), _b:byte()
  return function (code)
    return code >= a and code <= b
  end
end

local function make_charset (str)
  local bytes = {str:byte(1, #str)}
  return function (code)
    for _, c in ipairs(bytes) do
      if code == c then return true end
    end
    return false
  end
end

local function try_escape_class (patt, i)
  if patt:charat(i) ~= "%" then return end

  local item
  local char = patt:charat(i+1)
  local c = char:lower()
  if     c == "a" then item=letter
  elseif c == "c" then item=control
  elseif c == "d" then item=digit
  elseif c == "g" then item=printable
  elseif c == "l" then item=lower
  elseif c == "p" then item=punctuation
  elseif c == "s" then item=space
  elseif c == "u" then item=upper
  elseif c == "w" then item=alphanum
  elseif c == "x" then item=hex end

  if item then
    if c ~= char then
      item = complement(item)
    end
    return item, i+2
  else
    return make_charset(char), i+2
  end
end

local function parse_set (patt, i)
  local ch = patt:charat(i)

  if ch == "^" then
    local set, _i = parse_set(patt, i+1)
    return complement(set), _i
  end

  local charset = ""
  local set = {}

  while ch and ch ~= "]" do
    local class, _i = try_escape_class(patt, i, true)
    if class then i = _i
    elseif patt:charat(i+1) == "-" then
      class = make_range(ch, patt:charat(i+2))
      i = i+2
    else
      charset = charset .. ch
      i = i+1
    end

    if class then table.insert(set, class) end
    ch = patt:sub(i, i)
  end

  if charset ~= "" then
    table.insert(set, make_charset(charset))
  end

  if ch == "]" then
    local f = function (code)
      for _, class in ipairs(set) do
        if class(code) then return true end
      end
      return false
    end
    return f, i+1
  end
end

local function parse_class (patt, i)
  local ch = patt:charat(i)
  if ch == "[" then
    return parse_set(patt, i+1)
  elseif ch == "." then
    return all, i+1
  else
    return try_escape_class(patt, i)
  end
end

-- Basic Items
local function string_item (patt, next)
  return function (str, i, captures)
    local section = str:sub(i, i + #patt - 1)
    if section == patt then
      return next(str, i+#patt, captures)
    end
  end
end
local function class_item (class, next)
  return function (str, i, captures)
    if i > #str then return end
    if class(str:byte(i)) then
      return next(str, i+1, captures)
    end
  end
end
local function end_item (str, i) return i-1 end

-- repetitions
local function more_or_zero (class, next)
  return function (str, i, captures)
    local n = i
    while n <= #str and class(str:byte(n)) do
      n = n+1
    end

    while n >= i do
      local result = next(str, n, captures)
      if result then return result end
      n = n-1
    end
  end
end
local function zero_or_more (class, next)
  return function (str, i, captures)
    while true do
      local result = next(str, i, captures)
      if result then return result end
      if i <= #str and class(str:byte(i)) then i = i+1
      else return end
    end
  end
end
local function one_or_zero (class, next)
  return function (str, i, captures)
    if class(str:byte(i)) then
      local result = next(str, i+1, captures)
      if result then return result end
    end
    return next(str, i, captures)
  end
end

-- captures

local function capture_pos (index, next)
  return function (str, i, captures)
    captures[index] = i
    return next(str, i, captures)
  end
end

local function capture_start (index, next)
  return function (str, i, captures)
    captures[index] = {start=i}
    return next(str, i, captures)
  end
end

local function capture_end (index, next)
  return function (str, i, captures)
    captures[index]["end"] = i - 1
    return next(str, i, captures)
  end
end


local function parse_pattern (patt, i)
  local seq = {}
  local function push (type, value)
    table.insert(seq, {type=type, value=value})
  end

  local capture_index = 1
  local index_stack = {}

  local str = ""
  while i <= #patt do
    if patt:sub(i, i+1) == "()" then
      push("()", capture_index)
      capture_index = capture_index + 1
      i = i+2
    elseif patt:charat(i) == "(" then
      push("(", capture_index)
      table.insert(index_stack, capture_index)
      capture_index = capture_index + 1
      i = i+1
    elseif patt:charat(i) == ")" then
      push(")", table.remove(index_stack))
      i = i+1
    else
      local class, _i = parse_class(patt, i)

      if class then
        if str ~= "" then
          push("string", str)
          str = ""
        end
        i = _i
      else
        class = patt:charat(i)
        i = i+1
      end

      local ch = patt:charat(i)
      if ch == "+" or ch == "*" or ch == "-" or ch == "?" then
        if type(class) == "string" then
          class = make_charset(class)
        end
        push(ch, class)
        i = i+1
      elseif type(class) == "string" then
        str = str .. class
      else push("class", class) end
    end
  end

  if str ~= "" then
    push("string", str)
  end

  local item = end_item
  for i = #seq, 1, -1 do
    local obj = seq[i]
    if obj.type == "string" then
      item = string_item(obj.value, item)
    elseif obj.type == "class" then
      item = class_item(obj.value, item)
    elseif obj.type == "*" then
      item = more_or_zero(obj.value, item)
    elseif obj.type == "+" then
      item = more_or_zero(obj.value, item)
      item = class_item(obj.value, item)
    elseif obj.type == "-" then
      item = zero_or_more(obj.value, item)
    elseif obj.type == "?" then
      item = one_or_zero(obj.value, item)
    elseif obj.type == "()" then
      item = capture_pos(obj.value, item)
    elseif obj.type == "(" then
      item = capture_start(obj.value, item)
    elseif obj.type == ")" then
      item = capture_end(obj.value, item)
    end
  end

  return item
end

local function find (str, patt, init)
  local captures = {}
  local pattern = parse_pattern(patt, 1)
  return pattern(str, init or 1)
end

--[[
-- classes
assert(find("a", "."))
assert(find("a", "%l"))
assert(not find("a", "%d"))
assert(find("a", "[abc]"))
assert(find("b", "[abc]"))
assert(not find("d", "[abc]"))
assert(not find("a", "[^abc]"))
assert(find("e", "[b-e]"))
assert(not find("a", "[b-e]"))
assert(find("a", "[%d%l]"))
assert(find("v", "[%duvz]"))
assert(not find("a", "[%dxyz]"))
-- strings
assert(not find("a", "abc"))
assert(find("abcd", "abc"))
assert(find("a3cb", "a%wc"))
assert(not find("ab3c", "a%wc"))

-- repetitions
assert(find("abc3", "%l") == 1)
assert(find("abc3", "%l*") == 3)
assert(find("3", "%l*") == 0)
assert(find("abc3", "%l+") == 3)
assert(find("a1b2", "%w+%d") == 4)
assert(find("a1b2", "%w-%d") == 2)
assert(not find("3", "%l+"))
assert(find("a0", ".?%d") == 2)
assert(find("0", ".?%d") == 1)

local function capt (str, patt, expected)
  local captures = {}
  local pattern = parse_pattern(patt, 1)
  pattern(str, 1, captures)

  if #captures ~= #expected then goto err end
  for i = 1, #captures do
    local c = captures[i]
    if type(c) == "table" then
      c = str:sub(c.start, c["end"])
    end
    if c ~= expected[i] then goto err end
  end

  do return end
  ::err::
  error("failed " .. str .. " with pattern " .. patt)
end

capt("abc", "%w", {})
capt("abc", "()%w()()", {1, 2, 2})
capt("abc", "(%w)", {"a"})
capt("abcd", ".(%w).(%w)", {"b", "d"})
capt("abc", "(%w(%w))", {"ab", "b"})
--]]

local function finish_captures (captures, str)
  for i = 1, #captures do
    local c = captures[i]
    if type(c) == "table" then
      captures[i] = str:sub(c.start, c["end"])
    end
  end
  return table.unpack(captures)
end

function string:find (patt, init, plain)

  if not patt then
    error("bad argument #1 to 'string.find' (value expected)")
  elseif type(patt) == "number" then
    patt = tostring(patt)
  elseif type(patt) ~= "string" then
    error("bad argument #1 to 'string.find' (string expected, got " .. type(patt) .. ")")
  end

  local orig_init = init

  if init == nil then init = 1 end
  init = tonumber(init)
  if not init then
    error("bad argument #2 to 'string.find' (number expected, got " .. type(orig_init) .. ")")
  end

  if init < 0 then init = #self + 1 + init end
  if init < 1 then init = 1 end

  if plain then
    for i = init, #self + 1 - #patt do
      local j = i + #patt - 1
      local sub = self:sub(i, j)
      if sub == patt then return i, j end
    end
  else
    local max_start = #self
    if patt:charat(1) == "^" then
      max_start = 1
      patt = patt:sub(2, -1)
    end

    local min_end = 0
    if patt:charat(-1) == "$" and patt:charat(-2) ~= "%" then
      min_end = #self
      patt = patt:sub(1, -2)
    end

    local pattern = parse_pattern(patt, 1)
    local captures = {}
    for i = init, max_start do
      local endpos = pattern(self, i, captures)
      if endpos and endpos >= min_end then
        return i, endpos, finish_captures(captures, self)
      end
    end
  end
end

function string:match (patt, init, plain)
  local r = {self:find(patt, init, plain)}
  if #r > 2 then
    return table.unpack(r, 3)
  elseif #r > 0 then
    return self:sub(r[1], r[2])
  end
end

function string.gsub (s, patt, repl, max_count)
  local function sep (a, b, ...) return a, b, {...} end

  local f
  if type(repl) == "function" then
    function f (_, ...) return repl(...) end
  elseif type(repl) == "table" then
    function f (_, k) return repl[k] end
  elseif type(repl) == "string" then
    function f (...)
      local arg = {...}
      local t = {["%"] = "%%"}
      for i = 1, #arg do
        t[tostring(i-1)] = arg[i]
      end
      return repl:gsub("%%([%d%%])", t)
    end
  else error("bad argument #3 to 'string.gsub' (string/function/table expected)") end

  local i, r, count = 1, "", 0

  while i < #s and (not max_count or count < max_count) do
    local j, j2, captures = sep(s:find(patt, i))
    if not j then break end

    r = r .. s:sub(i, j-1) .. f(s:sub(j, j2), table.unpack(captures))
    i = j2+1
    count = count+1
  end

  r = r .. s:sub(i)
  return r, count
end

--[[
assert(("abcd"):find("%w") == 1)
assert(("abcd"):find("^%w") == 1)
assert(("abcd"):find("%w$") == 4)
assert(("abcd"):find("^%w$") == nil)
assert(("ab2c"):find("%w%d") == 2)
assert(("ab2c"):find("^%w%d") == nil)
assert(("a$"):find("%w$") == nil)
assert(("a$b"):find("%w%$") == 1)
do
  local a, b = ("+ -"):find("^[ \b\n\r\t\v]*")
  assert(a == 1) assert(b == 0)
end

print(("abc"):find("%w%w"))
print(("abc"):find("%w(%w)"))
print(("abc"):find("(()%w(%w))"))
print(("abc"):match("%w%w"))
print(("abc"):match("(()%w(%w))"))
]]