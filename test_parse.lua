
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

-- Based on
-- https://github.com/stravant/LuaMinify/blob/master/tests/test_parser.lua

local source = [=[
;
; end                                   -- FAIL
local                                   -- FAIL
local;                                  -- FAIL
local =                                 -- FAIL
local end                               -- FAIL
local a
local a;
local a, b, c
local a; local b local c;
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
do break end                  -- Semantic Error
;; do end ;;
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
repeat break break until 0    -- Semantic Error
repeat do end until 0
repeat do return end until 0
repeat do break end until 0
break                         -- Semantic Error
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
return ...,1,2
if                                      -- FAIL LOUD
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
if 1 then break end           -- Semantic Error
if 1 then return end
if 1 then return return end             -- FAIL
if 1 then end; if 1 then end;
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

return Parser, test