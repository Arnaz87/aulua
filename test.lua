
print(math.type(2), math.type(2.0), math.type(4/2))

print(2, 2.0, 4/2, 2==2.0, 2==4/2, 2=="2")

assert(2 == 2)
assert(2 == 2.0)
assert(2 == 4/2)
assert(2 ~= "2")
assert("2" == "2")
assert("2" ~= " 2")

assert(2 < 3.0)
assert("a" < "b")
assert(1.01 >= 1)

local t = {[2]=true}

assert(t[2])
assert(t[2.0])
assert(t[4/2])
assert(not t["2"])
assert(not t[2.01])

local u = t
local v = {}
print(t, u, v)
print(u == t, t == {})

local f1 = io.open("test")
local f2 = io.open("out")
local f3 = io.open("test")
print(f1, f2, f3)
print(f1 == f1, f1 == f2, f1 == f3)