
function f (...)
  local t = {...}
  print(#t, ...)
end
f("a", "b", "c")

assert(not(200 < 21))
assert("200" < "21")
--print("200" < 21)