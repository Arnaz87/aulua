
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
  return function (str, i)
    local section = str:sub(i, i + #patt - 1)
    if section == patt then
      return next(str, i+#patt)
    end
  end
end
local function class_item (class, next)
  return function (str, i)
    if i > #str then return end
    if class(str:byte(i)) then
      return next(str, i+1)
    end
  end
end
local function end_item (str, i) return i-1 end

-- repetitions
local function more_or_zero (class, next)
  return function (str, i)
    local n = i
    while n <= #str and class(str:byte(n)) do
      n = n+1
    end

    while n >= i do
      local result = next(str, n)
      if result then return result end
      n = n-1
    end
  end
end
local function zero_or_more (class, next)
  return function (str, i)
    while true do
      local result = next(str, i)
      if result then return result end
      if i <= #str and class(str:byte(i)) then i = i+1
      else return end
    end
  end
end
local function one_or_zero (class, next)
  return function (str, i)
    if class(str:byte(i)) then
      local result = next(str, i+1)
      if result then return result end
    end
    return next(str, i)
  end
end


local function parse_pattern (patt, i)
  local seq = {}
  local function push (type, value)
    table.insert(seq, {type=type, value=value})
  end

  local str = ""
  while i <= #patt do
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
    end
  end

  return item
end

local function find (str, patt, init)
  local captures = {}
  local pattern = parse_pattern(patt, 1)
  return pattern(str, init or 1)
end

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

--string.charat = nil

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
    for i = init, #self do
      local sub = self:sub(patt, i, i + #patt)
      if sub == patt then return i, i + #patt end
    end
  else
    local pattern = parse_pattern(patt, 1)
    for i = init, #self do
      local endpos = pattern(self, i)
      if endpos then return i, endpos end
    end
  end
end

function string:match (patt, init)
  local a, b = self:find(patt, init)
  if a then return self:sub(a, b) end
end

