
local t = {"a", "b", "c", "d", "e"}
local function show ()
  print("{" .. table.concat(t, ", ") .. "}")
end

show()
remove(t)
show()
remove(t, 2)
show()
