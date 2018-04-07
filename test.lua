--local a = {["a"]=2}
local a = 1
local f = function ()
  local b = 0
  local g = function ()
    b = b+1
    a = a+b
    print(a)
  end
  g()
  g()
  g()
end

print("start", a)
f()
f()
print("end", a)