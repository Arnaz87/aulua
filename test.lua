
function ipairs (t)
  local function next (t, i)
    i = i+1
    local v = t[i]
    if v then return i, v end
  end
  return next, t, 0
end

local t = {"a", "b", "c"}

for i, v in ipairs(t) do print(i, v) end

--[[local f, s, var = ipairs(t)
while true do
  local var_1, var_2 = f(s, var)
  if var_1 == nil then break end
  var = var_1
  local i, v = var_1, var_2
  print(i, v)
end]]

--[[local lol = require("lol")
print("from test.lua: " .. lol)

local bottles = 5
 
local function plural (bottles) if bottles == 1 then return '' end return 's' end
while bottles > 0 do
    print (bottles..' bottle'..plural(bottles)..' of beer on the wall')
    print (bottles..' bottle'..plural(bottles)..' of beer')
    print ('Take one down, pass it around')
    bottles = bottles - 1
    print (bottles..' bottle'..plural(bottles)..' of beer on the wall')
    print ()
end]]
