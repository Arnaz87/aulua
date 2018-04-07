--local a = {["a"]=2}
local a = 10
local f = function () print(a) end
f()
a = 11
f()
print(a)