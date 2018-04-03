local a = {[1]=3,[2]=4,a=42,[3]=5,[4]=6}
local f = function () print(5) end
f(42)
print(a, a[0], a[1] + a[2], a[3+1] + a.a, f)
