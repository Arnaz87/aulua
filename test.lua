local _ENV = {}
--local f = function (x) a = x return 8, 9 end
_ENV.a, _ENV["b"] = 1, 2
print(a, b)