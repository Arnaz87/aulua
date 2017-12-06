
local Parser = require("parser")

local loud = false

local function tostr (obj)
  if type(obj) ~= "table" then
    return tostring(obj) end

  if #obj > 0 then
    local str = "["
    for i = 1, #obj do
      if i > 1 then str = str .. ", " end
      str = str .. tostr(obj[i])
    end
    return str .. "]"
  end

  local first = true
  local str = "{"
  for k, v in pairs(obj) do
    if k ~= "type" then
      if first then first = false
      else str = str .. ", " end
      str = str .. k .. "=" .. tostr(v)
    end
  end

  local tp = (obj.type or ""):upper()
  if tp ~= "" and str == "{" then
    return tp
  else
    return tp .. str .. "}"
  end
end

local function eq (t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table"
    then return t1 == t2 end

  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if not eq(v1,v2) then
      return false end
  end

  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if not eq(v1,v2) then
      return false end
  end

  return true
end

-- Based on
-- https://github.com/stravant/LuaMinify/blob/master/tests/test_parser.lua

local source = [=[
----- Empty chunk -----
;
; end                                   -- FAIL
----- Simple local -----
local                                   -- FAIL
local;                                  -- FAIL
local =                                 -- FAIL
local end                               -- FAIL
local a
local a;
local a, b, c
local a; local b local c;
local a =                              -- FAIL
local a = 1
local a local b = a
local a, b = 1, 2
local a, b, c = 1, 2, 3
local a, b, c = 1
local a = 1, 2, 3
local a, local                          -- FAIL
local 1                                 -- FAIL
local "foo"                             -- FAIL
local a = local                         -- FAIL
local a, b, =                           -- FAIL
local a, b = 1, local                   -- FAIL
local a, b = , local                    -- FAIL
----- Do statement -----
do                                      -- FAIL
end                                     -- FAIL
do end
do ; end
do 1 end                                -- FAIL
do "foo" end                            -- FAIL
do local a, b end
do local a local b end
do local a; local b; end
do local a = 1 end
do do end end
do do end; end
do do do end end end
do do do end; end; end
do do do return end end end
do end do                               -- FAIL
do end end                              -- FAIL
do return end
do return return end                    -- FAIL
do break end
;; do end ;;
----- While statement -----
while                                   -- FAIL
while do                                -- FAIL
while =                                 -- FAIL
while 1 do                              -- FAIL
while 1 do end
while 1 do local a end
while 1 do local a local b end
while 1 do local a; local b; end
while 1 do 2 end                        -- FAIL
while 1 do "foo" end                    -- FAIL
while true do end
while 1 do ; end
while 1 do while                        -- FAIL
while 1 end                             -- FAIL
while 1 2 do                            -- FAIL
while 1 = 2 do                          -- FAIL
while 1 do return end
while 1 do return return end            -- FAIL
while 1 do do end end
while 1 do do return end end
while 1 do break end
while 1 do break break end
while 1 do do break end end
----- Repeat statement -----
repeat                                  -- FAIL
repeat until                            -- FAIL
repeat until 0
repeat until false
repeat until local                      -- FAIL
repeat end                              -- FAIL
repeat 1                                -- FAIL
repeat =                                -- FAIL
repeat local a until 1
repeat local a local b until 0
repeat local a; local b; until 0
repeat ; until 1
repeat 2 until 1                        -- FAIL
repeat "foo" until 1                    -- FAIL
repeat return until 0
repeat return return until 0            -- FAIL
repeat break until 0
repeat break break until 0
repeat do end until 0
repeat do return end until 0
repeat do break end until 0
----- Return & break -----
break
break 5                                 -- FAIL
break break
break return
return break                            -- FAIL
return
return;
return return                           -- FAIL
return 1
return local                            -- FAIL
return "foo"
return 1,                               -- FAIL
return 1,2,3
return a,b,c,d
return 1,2;
return ...
return 1,a,...
return 1,...,2
return ...,1,2
----- Label & goto -----
::                                      -- FAIL
::a                                     -- FAIL
::a::
::5::                                   -- FAIL
::a, b::                                -- FAIL
::a b::                                 -- FAIL
::a:: ::                                -- FAIL
:: ::a::                                -- FAIL
::a:: ::b::
::a::; ::b::;
::a:: return
goto                                    -- FAIL
goto a
goto 5                                  -- FAIL
goto a, b                               -- FAIL
goto a goto b
goto a; goto b;
goto a ::b::
::a:: goto b ::c::
----- If statement -----
if                                      -- FAIL
elseif                                  -- FAIL
else                                    -- FAIL
then                                    -- FAIL
if then                                 -- FAIL
if 1                                    -- FAIL
if 1 then                               -- FAIL
if 1 else                               -- FAIL
if 1 then else                          -- FAIL
if 1 then elseif                        -- FAIL
if 1 then end
if 1 then local a end
if 1 then local a local b end
if 1 then local a; local b; end
if 1 then else end
if 1 then local a else local b end
if 1 then local a; else local b; end
if 1 then elseif 2                      -- FAIL
if 1 then elseif 2 then                 -- FAIL
if 1 then elseif 2 then end
if 1 then local a elseif 2 then local b end
if 1 then local a; elseif 2 then local b; end
if 1 then elseif 2 then else end
if 1 then else if 2 then end end
if 1 then else if 2 then end            -- FAIL
if 1 then break end
if 1 then return end
if 1 then return return end             -- FAIL
if 1 then end; if 1 then end;
----- Numeric for -----
for                                     -- FAIL
for do                                  -- FAIL
for end                                 -- FAIL
for 1                                   -- FAIL
for a                                   -- FAIL
for true                                -- FAIL
for =                                   -- FAIL
for a =                                 -- FAIL
for a, b =                              -- FAIL
for a = do                              -- FAIL
for a = 1, do                           -- FAIL
for a = p, q, do                        -- FAIL
for a = p q do                          -- FAIL
for a = b do end                        -- FAIL
for a = 1, 2, 3, 4 do end               -- FAIL
for a = p, q do end
for a = 1, 2 do end
for a = 1, 2 do local a local b end
for a = 1, 2 do local a; local b; end
for a = 1, 2 do 3 end                   -- FAIL
for a = 1, 2 do "foo" end               -- FAIL
for a = p, q, r do end
for a = 1, 2, 3 do end
for a = p, q do break end
for a = p, q do break break end
for a = 1, 2 do return end
for a = 1, 2 do return return end       -- FAIL
for a = p, q do do end end
for a = p, q do do break end end
for a = p, q do do return end end
----- Generic for -----
for a, in                               -- FAIL
for a in                                -- FAIL
for a do                                -- FAIL
for a in do                             -- FAIL
for a in b do                           -- FAIL
for a in b end                          -- FAIL
for a in b, do                          -- FAIL
for a in b do end
for a in b do local a local b end
for a in b do local a; local b; end
for a in b do 1 end                     -- FAIL
for a in b do "foo" end                 -- FAIL
for a b in                              -- FAIL
for a, b, c in p do end
for a, b, c in p, q, r do end
for a in 1 do end
for a in true do end
for a in "foo" do end
for a in b do break end
for a in b do break break end
for a in b do return end
for a in b do return return end         -- FAIL
for a in b do do end end
for a in b do do break end end
for a in b do do return end end
----- Local function -----
local function                          -- FAIL
local function 1                        -- FAIL
local function end                      -- FAIL
local function a                        -- FAIL
local function a end                    -- FAIL
local function a( end                   -- FAIL
local function a() end
local function a(1                      -- FAIL
local function a(1) end                 -- FAIL
local function a("foo"                  -- FAIL
local function a(p                      -- FAIL
local function a(p,)                    -- FAIL
local function a(p) end
local function a(p q) end               -- FAIL
local function a(p,q,) end              -- FAIL
local function a(p,q,r) end
local function a(p,q,1) end             -- FAIL
local function a(p) do                  -- FAIL
local function a(p) 1 end               -- FAIL
local function a(p) return end
local function a(p) break end
local function a(p) return return end   -- FAIL
local function a(p) do end end
local function a.b() end                -- FAIL
local function a:b() end                -- FAIL
local function a.b:c() end              -- FAIL
local function a[b]() end               -- FAIL
local function a(...) end
local function a(p,...) end
local function a(...,p) end             -- FAIL
local function a(p,q,r,...) end
local function a() local a local b end
local function a() local a; local b; end
local function a() end; local function a() end;
----- Function statement -----
function                                -- FAIL
function 1                              -- FAIL
function end                            -- FAIL
function a                              -- FAIL
function a end                          -- FAIL
function a( end                         -- FAIL
function a() end
function a(1                            -- FAIL
function a("foo"                        -- FAIL
function a(1) end                       -- FAIL
function a(p                            -- FAIL
function a(p,)                          -- FAIL
function a(p q                          -- FAIL
function a(p) end
function a(p,q,) end                    -- FAIL
function a(p,q,r) end
function a(p,q,1) end                   -- FAIL
function a(p) do                        -- FAIL
function a(p) 1 end                     -- FAIL
function a(p) return end
function a(p) break end
function a(p) return return end         -- FAIL
function a(p) do end end
function a.(                            -- FAIL
function a.1                            -- FAIL
function a.b() end
function a.b,                           -- FAIL
function a.b.(                          -- FAIL
function a.b.c.d() end
function a:                             -- FAIL
function a:1                            -- FAIL
function a:b() end
function a:b:                           -- FAIL
function a:b.                           -- FAIL
function a.b.c:d() end
function a(...) end
function a(...,                         -- FAIL
function a(p,...) end
function a(p,q,r,...) end
function a(p,...,q) end                 -- FAIL
function a() local a local b end
function a() local a; local b; end
function a() end; function a() end;
function a:b:c() end                    -- FAIL
function a[b].c() end                   -- FAIL
function a(b).c end                     -- FAIL
function a(b).c() end                   -- FAIL
----- Assignment -----
a                                       -- FAIL
a,                                      -- FAIL
a,b,c                                   -- FAIL
a,b =                                   -- FAIL
a = 1
a = 1,2,3
a, = 1                                  -- FAIL
a,b,c = 1
a,b,c = 1,2,3
a.b = 1
a.b.c = 1
a[b] = 1
a[b][4] = 1
a.b[c] = 1
a[b].c = 1
(a)[b].c = 1
(4).c = 1
("foo")["bar"] = 1
a.b, c[d] = 1,2,3
0 = 1                                   -- FAIL
"foo" = 1                               -- FAIL
true = 1                                -- FAIL
(a) = 1                                 -- FAIL
(a.b[1]) = 1                            -- FAIL
{} = 1                                  -- FAIL
a:b() = 1                               -- FAIL
a() = 1                                 -- FAIL
a.b:c() = 1                             -- FAIL
a[b]() = 1                              -- FAIL
a,2 = 1                                 -- FAIL
a,(b) = 1                               -- FAIL
a,b,(c.d) = 1                           -- FAIL
a = a b                                 -- FAIL
a = 1 2                                 -- FAIL
a = a = 1                               -- FAIL
----- Function calls ----- LOUD
a(                                      -- FAIL
a()
a(1)
a(1,)                                   -- FAIL
a(1,2,3)
1()                                     -- FAIL
a()()
a.b()
a[b]()
a.1                                     -- FAIL
a.b                                     -- FAIL
a[b]                                    -- FAIL
a.b.(                                   -- FAIL
a.b.c()
a[b][c]()
a[b].c()
a.b[c]()
a:b()
a:b                                     -- FAIL
a:1                                     -- FAIL
a.b:c()
a[b]:c()
a:b:                                    -- FAIL
a:b():c()
a:b().c[d]:e()
a:b()[c].d:e()
(a)()
()()                                    -- FAIL
(1)()
("foo")()
(true)()
(a)()()
(a.b)()
(a[b])()
(a).b()
(a)[b]()
(a):b()
(a).b[c]:d()
(a)[b].c:d()
(a):b():c()
(a):b().c[d]:e()
(a):b()[c].d:e()
----- More function calls -----
a"foo"
a[[foo]]
a.b"foo"
a[b]"foo"
a:b"foo"
a{}
a.b{}
a[b]{}
a:b{}
a()"foo"
a"foo"()
a"foo".b()
a"foo"[b]()
a"foo":c()
a"foo""bar"
a"foo"{}
(a):b"foo".c[d]:e"bar"
(a):b"foo"[c].d:e"bar"
a(){}
a{}()
a{}.b()
a{}[b]()
a{}:c()
a{}"foo"
a{}{}
(a):b{}.c[d]:e{}
(a):b{}[c].d:e{}
]=]

local function FAIL (line, msg)
  print("\x1b[1;31m[FAIL]\x1b[0;39m", line, "\x1b[31m" .. msg .. "\x1b[39m")
end

local function PASS (line, msg)
  print("\x1b[1;32m[PASS]\x1b[0;39m", line, "\x1b[1;30m" .. msg .. "\x1b[0;39m")
end

local ix=1
while ix < #source do
  local nix = source:find("\n", ix) or #source+1
  local line = source:sub(ix, nix-1)

  if line:find("LOUD") ~= nil then loud = true end
  if line:find("QUIT") ~= nil then break end

  local fail = line:find("FAIL") ~= nil

  Parser.open(line)
  local parsed = Parser.program()

  if fail then
    if parsed then
      FAIL(line, tostr(parsed))
    elseif loud then
      PASS(line, Parser.error)
    end
  else
    if not parsed then
      FAIL(line, Parser.error)
    elseif loud then
      PASS(line, tostr(parsed))
    end
  end

  ix=nix+1
end

--[[
local function test (meth, str, expected)
  Parser.open(str)
  local node = Parser[meth]()
  if eq(node, expected) then
    print("CORRECT", str)
  else
    print("FAIL", str)
    if Parser.error then print("\t" .. Parser.error)
    else print("\tGOT", tostr(node)) end
  end
end

test("expr", "45", {type="num", value="45"})
test("expr", "nil", {type="nil"})
]]

return Parser, test