
local Lexer = {}
local Lexer_mt = { __index = Lexer }

Lexer.new = function (text)
  self = { text = text, token = nil }
  setmetatable(self, Lexer_mt)
  self.char = self:char_at(1)
  self.token = self:lex()
  return self
end

function Lexer:error(msg)
  if self._error == nil then
    self._error = msg
    self.char = ""
  end
end

-- Consumes n characters and returns them
function Lexer:consume (n)
  if self._error ~= nil then return "" end

  local str = self.text:sub(1, n)
  self.text = self.text:sub(n+1, -1)
  self.char = self:char_at(1)
  return str
end

-- Finds the character at the nth position (base 1)
function Lexer:char_at (i)
  if self._error ~= nil then return "" end
  return self.text:sub(i, i)
end

-- Cheks if a string contains the current character
function Lexer:char_in (str)
  if self.char == "" then return false end
  return str:find(self.char, 1, true) ~= nil
end

-- Checks if the text starts with a string
function Lexer:starts_with (str)
  if self.char == "" then return false end
  return self.text:find(str, 1, true) == 1
end

-- Consume all characters in a set of characters
function Lexer:consume_while_in (patt)
  if self.char == "" then return "" end

  local str = ""
  while self:char_in(patt)
  do str = str .. self:consume(1)
  end

  return str
end

function Lexer:next ()
  --if error ~= nil then return nil end

  if self.token ~= nil then
    local old = self.token
    self.token = self:lex()
    return old
  end
end

KEYWORDS = {
  "and", "break", "do", "else", "elseif", "end",
  "false", "for", "function", "goto", "if", "in",
  "local", "nil", "not", "or", "repeat", "return",
  "then", "true", "until", "while",
}

-- // antes va antes que /, y lo mismo con ... .. . << <= < >> >= > == = :: :
OPS = {
  "&", "~", "|", "<<", ">>", "//",
  "+", "-", "*", "/", "%", "^", "#",
  "==", "~=", "<=", ">=", "<", ">", "=",
  "(", ")", "{", "}", "[", "]", "::",
  ";", ":", ",", "...", "..", ".",
}

LOWER = "abcdefghijklmnopqrstuvwxyz"
UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
DIGITS = "01234567890"
HEXDIGITS = "0123456789abcdefABCDEF"
ALPHA = LOWER .. UPPER .. "_"
ALPHANUM = ALPHA .. DIGITS
WHITESPACE = " \b\n\r\t\v"

function Lexer:skip_whitespace ()
  local str
  while self.char ~= "" do
    self:consume_while_in(WHITESPACE)

    if self:starts_with("--") then
      self:consume(2)
      str = self:long_string()
      if str == nil then
        -- long comment fails, consume all until newline
        while not self:char_in("\n\r") do
          self:consume(1)
        end
      end
    else return end
  end
end

-- Get the next token
function Lexer.lex ()
  self:skip_whitespace()

  local str = self:long_string()
  if str ~= nil then
    return { type = "STR", value = str}
  end

  str = self:string()
  if str ~= nil then
    return { type = "STR", value = str}
  end

  num = self:number()
  if num ~= nil then
    return { type = "NUM", value = num}
  end

  local name = self:name()
  if name ~= nil then
    -- Check if the name is a keyword
    for i, kw in pairs(KEYWORDS) do
      if name == kw then
        return { type = kw }
      end
    end
    return { type = "NAME", value = name }
  end

  -- After everything failed, look for operators
  for i, op in pairs(OPS) do
    if self:starts_with(op) then
      self:consume(#op)
      return { type = op }
    end
  end
end

function Lexer:long_string ()
  if not self:starts_with("[")
    then return nil end
  i = 2
  while self:char_at(i) == "="
    do i = i+1 end
  count = i-2
  if self:char_at(i) ~= "[" then
    if count == 0 then return nil
    else return self:error("invalid long string delimiter") end
  end
  self:consume(count + 2)
  str = ""
  while self.char ~= "" do
    if self.char == "]" then
      tag = self:consume(1)

      n_count = 0
      while self.char == "=" do
        tag = tag .. self:consume(1)
        n_count = n_count+1
      end

      if self.char == "]" and count == n_count then
        self:consume(1)
        return str
      else
        str = str .. tag
      end
    else
      str = str .. self:consume(1)
    end
  end
  self:error("unfinished long string")
end

function Lexer:string ()

  local function get_hex ()
    if self:char_in(HEXDIGITS) then
      local char = self:consume(1):lower()
      if char >= "a" then
        return char:byte() - string.byte("a") + 10
      else
        return char:byte() - string.byte("0")
      end
    else
      self:error("hexadecimal digit expected")
      return 0
    end
  end

  if not self:char_in("'\"")
  then return nil end

  local delimiter = self:consume(1)

  local str = ""
  while self.char ~= "" do
    if self.char == delimiter then
      self:consume(1)
      return str
    elseif self:char_in("\n\r") then
      return self:error("unfinished string")

    elseif self.char == "\\" then
      self:consume(1)

      local esc = ({
        a="\a", b="\b", f="\f", n="\n", r="\r", t="\t", v="\v"
      })[self.char]
      if self:char_in("'\"\\") then esc = self.char end

      if self.char == "x" then
        self:consume(1)
        local code = get_hex()*16 + get_hex()
        str = str .. string.char(code)

      elseif self.char == "u" then
        if self:consume(2) ~= "u{" then
          return self:error("missing {")
        end

        local code = 0
        repeat
          if self.char == "" then
            return self:error("unfinished string")
          end

          code = code*16 + get_hex()
          if code > 0x10FFFF then
            return self:error("UTF-8 value too large")
          end
        until self.char == "}"
        self:consume(1)

        str = str .. utf8.char(code)
      elseif self.char == "z" then
        self:consume(1)
        self:consume_while_in(WHITESPACE)
      elseif esc == nil then
        self:error("invalid escape sequence")
      else
        self:consume(1)
        str = str .. esc
      end
    else
      -- Any non special character
      str = str .. self:consume(1)
    end
  end
  self:error("unfinished string")
end

function Lexer:name ()
  if not self:char_in(ALPHA)
  then return nil end
  
  local str =  self:consume(1)
  str = str .. self:consume_while_in(ALPHANUM)
  return str
end

function Lexer:number ()

  -- Is the first character a point and the next a digit
  local is_point =
    self.char == "." and
    self:char_at(2) ~= "" and
    DIGITS:find(self:char_at(2), 1, true) ~= nil

  -- Quit if it's not a digit nor a point
  if not (self:char_in(DIGITS) or is_point)
  then return nil end

  local digits, exp, str

  if self:starts_with("0x") or self:starts_with("0X") then
    str = self:consume(2)
    digits = HEXDIGITS
    exp = "pP"
  else
    str = ""
    digits = DIGITS
    exp = "eE"
  end

  str = str .. self:consume_while_in(digits)
  if self.char == "." then
    str = str .. self:consume(1) .. self:consume_while_in(digits)
  end

  -- There must be significant digits
  if str == "0x" or str == "0X" or str == ""
  then self:error("malformed significant digits") end

  if self:char_in(exp) then
    str = str .. self:consume(1)
    if self:char_in("+-") then
      str = str .. self:consume(1) end
    -- Exponent is always decimal
    local exp = self:consume_while_in(DIGITS)
    if exp == "" then self:error("malformed exponent")
    else str = str .. exp end
  end

  return str
end




-------------------
--    Testing    --
-------------------

local function TEST ()
  local function STR (str) return { type = "STR", value = str } end
  local function NUM (val) return { type = "NUM", value = val } end
  local function NAME (str) return { type = "NAME", value = str } end
  local function KW (str) return { type = str } end

  local function tk_str (tk)
    if tk == nil
    then return "NIL"
    end

    if tk.type == "STR"
    or tk.type == "NAME"
    or tk.type == "NUM"
    then return tk.type .. "(" .. tk.value .. ")"
    else return tk.type end
  end

  local function test (str, ...)
    local lex = Lexer.new(str)
    local fail = false
    local msg = ""
    local toks = table.pack(...)
    
    local i = 1
    while lex.token ~= nil or i <= #toks do
      local tk = lex:next()
      local _tk = toks[i]

      if  tk == nil
      or _tk == nil
      or tk.type  ~= _tk.type
      or tk.value ~= _tk.value
      then fail = true end

      msg = msg .. "\t" .. tk_str(_tk) .. "\t\t" .. tk_str(tk) .. "\n"
      i = i+1
    end

    if fail then
      print("FAIL:", str)
      print("\tEXPECTED\t\tTOKEN")
      print(msg)
    else
      print("CORRECT ", str)
    end
  end

  local function test_error (str)
    local lex = Lexer.new(str)
    while lex.token ~= nil do
      lex:next()
    end

    if lex._error then
      print("CORRECT error: ", lex._error)
      print("\tfor code:", str)
    else
      print("FAIL: expected error for code:", str)
    end
  end

  --[=[ Check Failure
    test("+ -", KW("+"), KW("if"))

    test("[[45]]", STR("56"))

    test_error("[[2]]")
    test("+ +", KW("+"))
    test("+", KW("+"), KW("+"))
  --]=]

  test("+ -", KW("+"), KW("-"))
  test(' "45" ', STR("45") )
  test_error("[=45")
  test("ifs", NAME("ifs"))
  test("if", KW("if"))
  test("if s", KW("if"), NAME("s"))
  test("xo+", NAME("xo"), KW("+"))
  test("_F", NAME("_F"))
  test("else", KW("else"))
  test("elseif", KW("elseif"))
  test("-- comentario\nfoo", NAME("foo"))
  test("--[=[comentario\n]]largo]=]+", KW("+"))

  test("0", NUM("0"))
  test("27", NUM("27"))
  test("27.5", NUM("27.5"))
  test(".002", NUM(".002"))
  test("2E3", NUM("2E3"))
  test("5E-3", NUM("5E-3"))
  test("5E+1", NUM("5E+1"))
  test(". 2", KW("."), NUM("2"))
  test("2 .", NUM("2"), KW("."))
  test("0x4", NUM("0x4"))

  test_error("0x")
  test_error("0xP1")
  test_error("0E")
  test_error("0E+")
  test("0xAP2A", NUM("0xAP2"), NAME("A"))
  test("08FF", NUM("08"), NAME("FF"))

  test(".A", KW("."), NAME("A"))

  test(".", KW("."))
  test(". .", KW("."), KW("."))
  test("..", KW(".."))
  test("...", KW("..."))
  test("....", KW("..."), KW("."))
  test(".. ..", KW(".."), KW(".."))
  test(".0.1..2.", NUM(".0"), NUM(".1"), KW(".."), NUM("2."))

  test(">>> >=> =>> <=>",
    KW(">>"), KW(">"),
    KW(">="), KW(">"),
    KW("="), KW(">>"),
    KW("<="), KW(">")
  )

  test("\"ho'la\" 'ho\"la'", STR("ho'la"), STR('ho"la'))
  test_error("'ho\nla'")
  test("'ho\\\nla'", STR("ho\nla"))
  test_error('"ho\\kla"')
  test('"a\\x62c"', STR("abc"))
  test_error('"l\\x6m"')

  test('"a\\u{62}c"', STR("abc"))
  test_error('"a\\u{62o}c"')
  test_error('"a\\u{62"')
  test_error('"a\\u{fffffffff}c"')
  test_error('"a\\u{}cde"')

  test('"a \\z  \n\t  b"', STR("a b"))


  test([[
  -- Stops the lexer and reports an error
  function Lexer:error(msg)
    self._error = msg
    self.char = ""
  end
  ]],
    KW("function"), NAME("Lexer"), KW(":"), NAME("error"),
      KW("("), NAME("msg"), KW(")"),
    NAME("self"), KW("."), NAME("_error"), KW("="), NAME("msg"),
    NAME("self"), KW("."), NAME("char"), KW("="), STR(""),
    KW("end")
  )
end

TEST()

return Lexer