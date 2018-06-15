local step = 2
function f (x)
  return function ()
    print(x)
    x = x + step
  end
end

g1 = f(1)
g2 = f(2)

g1()
g1()
g1()
g2()
g2()