fi = io.open("test.lua")
s = fi:read(10)

fo = io.open("lol", "w")
fo:write(s)
