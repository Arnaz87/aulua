
-- Lua magic to not pollute the global namespace
_ENV = setmetatable({}, {__index = _ENV})

Lexer = { }

function Lexer.open (src)
  Lexer.error = nil
  source = src
  char = src:sub(1,1)
  eof = char == ""
  pos = {line=1, col=1}
  saved_pos = nil
end

function err (msg)
  Lexer.error = pos.line .. ":" .. pos.col .. ":" .. msg
  error(Lexer.error)
end

function check (patt, exact)
  if exact then
    if source:sub(1, #patt) == patt
    then return patt end
  else return source:match("^" .. patt) end
end

function match (patt, exact)
  local matched = check(patt, exact)
  if matched and #matched > 0 then

    ---- Advance lines
    -- TODO: Counts non unix lines as well
    local ix -- last index
    local nix = matched:find("\n")
    while nix do
      pos.line = pos.line+1
      ix = nix+1
      nix = matched:find("\n", ix)
    end

    ---- Get last line and advance columns
    local ln = matched
    if ix then
      ln = matched:sub(ix)
      pos.col = 1
    end
    pos.col = pos.col + #ln

    ---- Remove matched from source
    source = source:sub(#matched+1, -1)
    if source == "" then eof = true end
  end
  return matched
end

function match_nl ()
  return match("\n\r") or match("\r\n") or match("[\n\r]")
end

function TK (type, value)
  return {
    type = type,
    value = value,
    line = saved_pos.line,
    column = saved_pos.col
  }
end

local KEYWORDS = [[
  | and break do else elseif end false for function goto if in |
  | local nil not or repeat return then true until while |
]]

-- These operators have to respect their relative order:
-- // /
-- ... .. .
-- << <= <
-- >> >= >
-- == =
-- :: :
-- ~= ~
local OPS = {
  "==", "~=", "<=", ">=", "<<", ">>", "=",
  "&", "~", "|", "<", ">", "//",
  "+", "-", "*", "/", "%", "^", "#",
  "(", ")", "{", "}", "[", "]", "::",
  ";", ":", ",", "...", "..", ".",
}

function long_string ()
  local sep
  if match("%[%[") then
    sep = ""
  elseif check("%[=+") then
    match("%[")
    sep = match("=+")

    if not match("%[") then
      err("invalid long string delimiter")
    end
  else return nil end

  local endtag = "]"..sep.."]"

  match_nl() -- Skip starting newline

  str = ""
  while not eof do
    local tag = match("%]=*%]?")
    if tag then
      if tag == endtag then return str
      else str = str .. tag end
    end
    str = str .. match("[^%]]*")
  end

  err("unfinished long string")
end

function get_hex ()
  if check("[a-fA-F%d]") then
    local ch = match("."):lower()
    if ch >= "a" then     -- 'a' == 97
      return ch:byte() - 97 + 10
    else                  -- '0' == 48
      return ch:byte() - 48
    end
  else err("hexadecimal digit expected") end
end

-- Get the next token
function lex ()
  -------------------------------------------------- Skip Whitespace
  while char ~= "" do
    match("[ \b\n\r\t\v]*")

    if match("--", true) then
      str = long_string()
      if str == nil then
        match("[^\n\r]*")
      end
    else break end
  end

  --- Record token position
  saved_pos = { line = pos.line, col = pos.col }

  if eof then return nil end

  local buff

  -------------------------------------------------- String

  local str = long_string()

  if not str and check("['\"]") then
    local delimiter = match(".")
    str = ""
    while true do
      if match(delimiter, true)
        then break

      elseif eof or check("[\n\r]") then
        err("unfinished string")

      ----------------------------------------------  Escape sequences
      elseif match("\\") then

        local tbl = { a="\a", b="\b", f="\f", n="\n", r="\r", t="\t", v="\v" }

        local esc
        if check("[abfnrtv]") then
          esc = tbl[match(".")]
          
        elseif check("['\"\\]") then
          esc = match(".")

        elseif match_nl() then
          esc = "\n"

        elseif check("%d") then
          local n = tonumber(match("%d%d?%d?"))
          if n > 265 then err("decimal escape too large") end
          esc = string.char(n)

        elseif match("x") then
          local code = get_hex()*16 + get_hex()
          esc = string.char(code)

        elseif match("u") then
          if not match("{") then err("missing {") end

          local code = 0
          repeat
            if eof then err("unfinished string") end

            code = code*16 + get_hex()

            if code > 0x10FFFF then
              err("UTF-8 value too large")
            end
          until match("}")

          esc = utf8.char(code)
        elseif match("z") then
          -- Skip whitespace
          match("[ \b\n\r\t\v]*")
          esc = ""
        else
          err("invalid escape sequence")
        end

        str = str .. esc
      ----------------------------------------------  End escape secuences 

      else
        str = str .. match(".")
      end
    end
  end

  if str then
    return TK("STR", str)
  end

  -------------------------------------------------- Number

  local num = match("0[xX]")  -- hexadecimal
  if num then
    -- no digits guaranteed yet
    num = num .. match("[a-fA-F%d]*%.?[a-fA-F%d]*")
    if num == "0x" or num == "0x."
    then err("malformed number")
    elseif check("[pP]") then
      num = num .. match("[pP][%+%-]?")
      if check("%d") then
        num = num .. match("%d+")
      else err("malformed number") end
    end
    return TK("NUM", num)
  end

  if check("%.?%d") then      -- decimal
    -- at least une digit is already guaranteed
    num = match("%d*%.?%d*")
    if check("[eE]") then
      num = num .. match("[eE][%+%-]?")
      if check("%d") then
        num = num .. match("%d+")
      else err("malformed number") end
    end
    return TK("NUM", num)
  end

  -------------------------------------------------- Variable / Keyword


  local name = match("[_%a][_%w]*")

  if name then
    if KEYWORDS:find(' '..name..' ') ~= nil then
      return TK(name)
    end
    return TK("NAME", name)
  end

  -------------------------------------------------- Symbols / Operators

  for i, op in pairs(OPS) do
    if match(op, true) then
      local tk = TK(op)
      return tk
    end
  end

  -------------------------------------------------- Failure
  err("Unrecognized token " .. check("."))
end

function Lexer.next ()
  local trace

  -- Cobre doesn't yet support protected calls
  if not xpcall then xpcall = function (f) return true, f() end end

  status, tk = xpcall(lex, function (msg)
    if Lexer.error == nil then
      trace = debug.traceback(
        "\x1b[31mFATAL\x1b[39m " .. msg
      )
    end
  end)

  if trace then error(trace) end

  if status then return tk
  elseif Lexer.error
  then return nil, tk
  else error(tk) end
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

return Lexer