
function showmeta (x) print(x, getmetatable(x)) end

local x = {}
local t = {}
showmeta(x)
print(setmetatable(x, t))
showmeta(x)
showmeta("hola")
showmeta(1)