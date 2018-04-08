--local _ENV = _ENV
local x = 3+4
local f = function ()
  local g = function () print(32) end
  return g()
end
local a = f()
print(a)