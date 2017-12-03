
local token, source, char, _err


local Lexer = { }
setmetatable(Lexer, {
  __index = function (self, name)
    if name == "token"
      then return token
    elseif name == "err"
      then return _err
    end
  end
})

function Lexer.open (src)
  _err = nil
  source = src
  char = src:sub(1,1)
end

-- Lexer error function
local function err (msg)
  if _err == nil then
    _err = msg
    char = ""
  end
end

-- Finds the character at the nth position (base 1)
local function char_at (i)
  if _err ~= nil then return "" end
  return source:sub(i, i)
end

-- Checks if the text starts with a string
local function starts_with (str)
  if char == "" then return false end
  return source:find(str, 1, true) == 1
end

-- Consumes n characters and returns them
local function consume (n)
  if _err ~= nil then return "" end

  -- Remove a newline combination as a single character
  if n==1 and (starts_with("\r\n") or starts_with("\n\r"))
  then n = 2 end

  local str = source:sub(1, n)
  source = source:sub(n+1, -1)
  char = char_at(1)
  return str
end

-- Cheks if a string contains the current character
local function char_in (str)
  if char == "" then return false end
  return str:find(char, 1, true) ~= nil
end

-- Consume all characters in a set of characters
local function consume_while_in (patt)
  if char == "" then return "" end

  local str = ""
  while char_in(patt)
  do str = str .. consume(1)
  end

  return str
end

local KEYWORDS = {
  "and", "break", "do", "else", "elseif", "end",
  "false", "for", "function", "goto", "if", "in",
  "local", "nil", "not", "or", "repeat", "return",
  "then", "true", "until", "while",
}

-- // antes va antes que /, y lo mismo con ... .. . << <= < >> >= > == = :: :
local OPS = {
  "&", "~", "|", "<<", ">>", "//",
  "+", "-", "*", "/", "%", "^", "#",
  "==", "~=", "<=", ">=", "<", ">", "=",
  "(", ")", "{", "}", "[", "]", "::",
  ";", ":", ",", "...", "..", ".",
}

local LOWER = "abcdefghijklmnopqrstuvwxyz"
local UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local DIGITS = "01234567890"
local HEXDIGITS = "0123456789abcdefABCDEF"
local ALPHA = LOWER .. UPPER .. "_"
local ALPHANUM = ALPHA .. DIGITS
local WHITESPACE = " \b\n\r\t\v"

local function long_string ()
  if not starts_with("[")
    then return nil end
  i = 2
  while char_at(i) == "="
    do i = i+1 end
  count = i-2
  if char_at(i) ~= "[" then
    if count == 0 then return nil
    else return err("invalid long string delimiter") end
  end
  consume(count + 2)
  str = ""
  while char ~= "" do
    if char == "]" then
      tag = consume(1)

      n_count = 0
      while char == "=" do
        tag = tag .. consume(1)
        n_count = n_count+1
      end

      if char == "]" and count == n_count then
        consume(1)
        return str
      else
        str = str .. tag
      end
    else
      str = str .. consume(1)
    end
  end
  err("unfinished long string")
end

local function skip_whitespace ()
  local str
  while char ~= "" do
    consume_while_in(WHITESPACE)

    if starts_with("--") then
      consume(2)
      str = long_string()
      if str == nil then
        -- long comment fails, consume all until a newline
        while char ~= "" and not char_in("\n\r") do
          consume(1)
        end
      end
    else return end
  end
end

-- Its own function rather than in string because it's too long
local function escape_sequence ()

  local function get_hex ()
    if char_in(HEXDIGITS) then
      local char = consume(1):lower()
      if char >= "a" then
        return char:byte() - string.byte("a") + 10
      else
        return char:byte() - string.byte("0")
      end
    else
      err("hexadecimal digit expected")
      return 0
    end
  end

  local tbl = { a="\a", b="\b", f="\f", n="\n", r="\r", t="\t", v="\v" }

  if tbl[char] ~= nil then
    return tbl[consume(1)]
  elseif char_in("'\\\"\n\r") then
    return consume(1)
  elseif char == "x" then
    consume(1)
    local code = get_hex()*16 + get_hex()
    return string.char(code)
  elseif char == "u" then
    if consume(2) ~= "u{" then
      return err("missing {")
    end

    local code = 0
    repeat
      if char == "" then
        return err("unfinished string")
      end

      code = code*16 + get_hex()
      if code > 0x10FFFF then
        return err("UTF-8 value too large")
      end
    until char == "}"
    consume(1)

    return utf8.char(code)
  elseif char == "z" then
    consume(1)
    consume_while_in(WHITESPACE)
    return ""
  end
end

local function string ()

  if not char_in("'\"")
  then return nil end

  local delimiter = consume(1)

  local str = ""
  while char ~= "" do
    if char == delimiter then
      consume(1)
      return str
    elseif char_in("\n\r") then
      return err("unfinished string")
    elseif char == "\\" then
      consume(1)

      local esc = escape_sequence()
      if esc == nil then
        return err("invalid escape sequence")
      else
        str = str .. esc
      end
    else
      -- Any non special character
      str = str .. consume(1)
    end
  end
  err("unfinished string")
end

local function name ()
  if not char_in(ALPHA)
  then return nil end
  
  local str =  consume(1)
  str = str .. consume_while_in(ALPHANUM)
  return str
end

local function number ()

  -- Is the first character a point and the next a digit
  local is_point =
    char == "." and
    char_at(2) ~= "" and
    DIGITS:find(char_at(2), 1, true) ~= nil

  -- Quit if it's not a digit nor a point
  if not (char_in(DIGITS) or is_point)
  then return nil end

  local digits, exp, str

  if starts_with("0x") or starts_with("0X") then
    str = consume(2)
    digits = HEXDIGITS
    exp = "pP"
  else
    str = ""
    digits = DIGITS
    exp = "eE"
  end

  str = str .. consume_while_in(digits)
  if char == "." then
    str = str .. consume(1) .. consume_while_in(digits)
  end

  -- There must be significant digits
  if str == "0x" or str == "0X" or str == ""
  then err("malformed significant digits") end

  if char_in(exp) then
    str = str .. consume(1)
    if char_in("+-") then
      str = str .. consume(1) end
    -- Exponent is always decimal
    local exp = consume_while_in(DIGITS)
    if exp == "" then err("malformed exponent")
    else str = str .. exp end
  end

  return str
end

-- Get the next token
function Lexer.next ()
  if _err then return nil end

  skip_whitespace()

  local str = long_string()
  if str ~= nil then
    return { type = "STR", value = str}
  end

  str = string()
  if str ~= nil then
    return { type = "STR", value = str}
  end

  num = number()
  if num ~= nil then
    return { type = "NUM", value = num}
  end

  local name = name()
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
    if starts_with(op) then
      consume(#op)
      return { type = op }
    end
  end
end


-------------------
--    Testing    --
-------------------

do
  local loud = false

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
    Lexer.open(str)
    local fail = false
    local msg = ""
    local toks = table.pack(...)
    
    local i = 1
    local tk  = Lexer.next()

    while token ~= nil or i <= #toks do
      local _tk = toks[i]

      if  tk == nil
      or _tk == nil
      or tk.type  ~= _tk.type
      or tk.value ~= _tk.value
      then fail = true end

      msg = msg .. "\t" .. tk_str(_tk) .. "\t\t" .. tk_str(tk) .. "\n"

      i = i+1
      tk = Lexer.next()
    end

    if fail then
      if Lexer.err then
        print("FAIL with", Lexer.err, str)
      else print("FAIL:", str) end
      print("\tEXPECTED\t\tTOKEN")
      print(msg)
    elseif loud then
      print("CORRECT ", str)
    end
  end

  local function test_error (str)
    Lexer.open(str)
    repeat
      local tk = Lexer.next()
    until tk == nil

    if not Lexer.err then
      print("FAIL: expected error for code:", str)
    elseif loud then
      print("CORRECT error: ", Lexer.err)
      print("\tfor code:", str)
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

  test("+ --Hola\n", KW("+"))
  test("+ --Hola", KW("+"))
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
  test_error('"ho\\kla"')
  test('"a\\x62c"', STR("abc"))
  test_error('"l\\x6m"')

  test('"a\\u{62}c"', STR("abc"))
  test_error('"a\\u{62o}c"')
  test_error('"a\\u{62"')
  test_error('"a\\u{fffffffff}c"')
  test_error('"a\\u{}cde"')

  test('"a \\z  \n\t  b"', STR("a b"))

  test("'ho\\\nla'", STR("ho\nla"))
  test("'ho\\\n\rla'", STR("ho\n\rla"))
  test_error("'ho\\\n\nla'")


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

return Lexer