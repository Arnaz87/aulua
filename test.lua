
local t = table.pack("a", "b", nil, "c", nil)
print(t.n, #t)
for i = 1, t.n do print(i, t[i]) end

print(table.unpack({"a", "b", nil, nil, "c", nil}))
print(table.unpack({"a", "b", nil, nil, "c", nil}, 2, 5))

print(select("#", 1, 2, 3))
print(select(1, 1, 2, 3))
print(select(3, 1, 2, 3))
print(select("#", select(6, 1, 2, 3)))