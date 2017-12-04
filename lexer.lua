
local source, char, curr_pos, saved_pos


local Lexer = { }

function Lexer.open (src)
  Lexer.error = nil
  source = src
  char = src:sub(1,1)
  pos = {line=1, col=1}
  saved_pos = nil
end

-- Lexer error function
local function err (msg)
  if not Lexer.error then
    Lexer.error = msg .. " at line " .. pos.line .. ", column " .. pos.col
    char = ""
  end
end

-- Finds the character at the nth position (base 1)
local function char_at (i)
  if Lexer.error ~= nil then return "" end
  return source:sub(i, i)
end

-- Checks if the text starts with a string
local function starts_with (str)
  if char == "" then return false end
  return source:find(str, 1, true) == 1
end

-- Consumes n characters and returns them
local function consume (n)
  if Lexer.error ~= nil then return "" end

  -- Remove a newline combination as a single character
  if n==1 and (starts_with("\r\n") or starts_with("\n\r"))
  then n = 2 end

  local str = source:sub(1, n)

  -- Find last newline
  -- TODO: account for \r
  local ix
  local nix = str:find("\n")
  while nix do
    pos.line = pos.line+1
    ix = nix+1
    nix = str:find("\n", ix)
  end


  local ln = str
  if ix then
    ln = str:sub(ix)
    pos.col = 1
  end
  pos.col = pos.col + #ln

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

local function TK (type, value)
  return {
    type = type,
    value = value,
    line = saved_pos.line,
    column = saved_pos.col
  }
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
  if Lexer.error then return nil end

  skip_whitespace()

  -- Any token read will have this position
  saved_pos = { line = pos.line, col = pos.col }

  local str = long_string()
  if str ~= nil then
    return TK("STR", str)
  end

  str = string()
  if str ~= nil then
    return TK("STR", str)
  end

  num = number()
  if num ~= nil then
    return TK("NUM", num)
  end

  local name = name()
  if name ~= nil then
    -- Check if the name is a keyword
    for i, kw in pairs(KEYWORDS) do
      if name == kw then
        return TK(kw)
      end
    end
    return TK("NAME", name)
  end

  -- After everything failed, look for operators
  for i, op in pairs(OPS) do
    if starts_with(op) then
      consume(#op)
      return TK(op)
    end
  end
end

-- Get all tokens
function Lexer.tokens ()
  local tokens = {}
  local tk = Lexer.next()
  while tk ~= nil do
    table.insert(tokens, tk)
    tk = Lexer.next()
  end
  if not Lexer.error then
    return tokens end
end

-- Gets a string with a token's position
function Lexer.get_position (token)
  return "line " .. token.line .. ", column " .. token.column
end

return Lexer