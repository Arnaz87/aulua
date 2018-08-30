
--[[
print("x", "x / 2", "x // 2", "x / -2", "x // -2")
for x = 3, -3, -1 do
  print(x, x/2, x//2, x/-2, x//-2)
end
]]

print("x", "% 3", "% -3", "fmod 3", "fmod -3")
for x = 4, -4, -1 do
  print(x, x%3, x%-3, math.fmod(x, 3), math.fmod(x, -3))
end