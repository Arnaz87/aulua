
local o = {"a", "b"}
o[0] = "foo"
o[32] = "bar"

for k, v in pairs(o) do print(k, v) end