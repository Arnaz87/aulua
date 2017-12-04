local Lexer = require("lexer")

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
    if Lexer.error then
      print("FAIL with", Lexer.error, str)
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

  if not Lexer.error then
    print("FAIL: expected error for code:", str)
  elseif loud then
    print("CORRECT error: ", Lexer.error)
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

-- Quick sketch to test token positions
Lexer.open([=[

do
x = "\n" .. "\
x" -- XD
  f --[[
  long comment
]] [[long
str]]
    break
end
]=])

local function pos (line, col)
  local tk = Lexer.next()
  if not tk then
    print("FAIL expected token")
  elseif tk.line ~= line or tk.column ~= col then
    print("FAIL " .. tk_str(tk) .. "(" .. tk.line .. ":" .. tk.column ..
      ") expected (" .. line .. ":" .. col .. ")")
  elseif loud then
    print("PASS " .. tk_str(tk) .. "(" .. tk.line .. ":" .. tk.column .. ")")
  end
end

-- This must fail and make all the others fail as well
-- pos(2, 3)

-- The positions of each of the tokens in the currently open Lexer
-- The contents of the content don't matter, as they were tested already
pos(2, 1)
pos(3, 1)
pos(3, 3)
pos(3, 5)
pos(3, 10)
pos(3, 13)
pos(5, 3)
pos(7, 4)
pos(9, 5)
pos(10, 1)
