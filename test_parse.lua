
local Parser = require("parser")

local loud = false
local showtrace = false

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

local function FAIL (line, msg)
  print("\x1b[1;31m[FAIL]\x1b[0;39m", line, "\x1b[31m" .. msg .. "\x1b[39m")
end

local function PASS (line, msg)
  print("\x1b[1;32m[PASS]\x1b[0;39m", line, "\x1b[1;30m" .. msg .. "\x1b[0;39m")
end

for line in io.lines("test_parse.txt") do
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
      if showtrace then print(Parser.trace) end
    elseif loud then
      PASS(line, tostr(parsed))
    end
  end
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