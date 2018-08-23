
local intmod = _CU_IMPORT("cobre", "int")
local inttp = intmod:get_type("int")
local int = inttp
--print(int) -- ERROR

local n = int(4)
--print(n) -- ERROR

n = int(5)
--n = 6 -- ERROR

print(n:to_lua_value())

--n = intmod:get_type("float")(5) -- ERROR

local string_mod = _CU_IMPORT("cobre", "string")

local string = string_mod:get_type("string")
local char = string_mod:get_type("char")

local concat = string_mod:get_function("concat", {string, string}, {string})
local addch = string_mod:get_function("add", {string, char}, {string})
local charat = string_mod:get_function("charat", {string, int}, {char, int})

local system = _CU_IMPORT("cobre", "system")
local println = system:get_function("println", {string}, {})

local li = 0

local xd = string("xd")
local ch, i = charat(xd, int(0))
--ch, li = charat(xd, i) -- ERROR

xd = addch(xd, ch)

ch, i = charat(xd, i)
xd = addch(xd, ch)

println(xd)
print(i:to_lua_value())

local t = string:test("xd")
--print(t) -- ERROR
if t then print("Is a string") end