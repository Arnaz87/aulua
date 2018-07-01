
local function x (a) return a or x(5) end
print(x())

--[[function f () return "a", "b", "c" end
local t = {f(), "y", f()}
for i, v in ipairs(t) do print(i, v) end]]