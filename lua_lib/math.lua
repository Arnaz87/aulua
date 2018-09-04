-- This library only works with culua, in no other lua implementation

local float_module = _AU_IMPORT("auro", "float")
local float = float_module:get_type("float")

local cu_math = _AU_IMPORT("auro", "math")

function getarg (x, name, i)
  if not i then i = 1 end
  local n = math.tofloat(x)

  if n then return n else
    error("bad argument #"..i.." to "..name.." (number expected, got "..type(x)")")
  end
end

local cu_pi = cu_math:get_function("pi", {}, {float})()
local cu_e = cu_math:get_function("e", {}, {float})()
local cu_inf = float_module:get_function("infinity", {}, {float})()

math.pi = cu_pi:to_lua_value()
math.huge = cu_inf:to_lua_value()
local lua_e = cu_e:to_lua_value()


function math.deg (rad) return (rad / math.pi) * 180 end
function math.rad (deg) return (deg / 180) * math.pi end

function math.max (x, ...)
  local ys = {...}
  for _, y in ipairs(ys) do
    if y > x then x = y end
  end
  return x
end

function math.min (x, ...)
  local ys = {...}
  for _, y in ipairs(ys) do
    if y < x then x = y end
  end
  return x
end

function math.abs (_n)
  local n = tonumber(_n)
  if not n then error("bad argument #1 to abs (number expected, got " .. type(_n) .. ")") end
  if n < 0 then return -n else return n end
end

function math.ceil (n)
  n = getarg(n, "ceil")
  local fn = cu_math:get_function("ceil", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.floor (n)
  n = getarg(n, "floor")
  local fn = cu_math:get_function("floor", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.fmod (a, b)
  a = getarg(a, "fmod", 1)
  b = getarg(b, "fmod", 2)
  local fn = cu_math:get_function("mod", {float, float}, {float})
  return fn(float(a), float(b)):to_lua_value()
end

function math.modf (n)
  n = getarg(n, "modf")
  local trunc = cu_math:get_function("trunc", {float}, {float})
  local int = trunc(float(n)):to_lua_value()
  return int, math.tofloat(n-int)
end

function math.exp (n)
  n = getarg(n, "exp")
  local fn = cu_math:get_function("exp", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.sqrt (n)
  n = getarg(n, "sqrt")
  local fn = cu_math:get_function("sqrt", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.log (x, b)
  x = getarg(x, "log")
  if not b then b = lua_e
  else b = getarg(b, "log", 2) end
  local fn = cu_math:get_function("log", {float, float}, {float})
  return fn(float(x), float(b)):to_lua_value()
end



function math.sin (n)
  n = getarg(n, "sin")
  local fn = cu_math:get_function("sin", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.cos (n)
  n = getarg(n, "cos")
  local fn = cu_math:get_function("cos", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.tan (n)
  n = getarg(n, "tan")
  local fn = cu_math:get_function("tan", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.asin (n)
  n = getarg(n, "asin")
  local fn = cu_math:get_function("sin", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.acos (n)
  n = getarg(n, "acos")
  local fn = cu_math:get_function("cos", {float}, {float})
  return fn(float(n)):to_lua_value()
end

function math.atan (y, x)
  y = getarg(y, "atan")

  if x then x = getarg(x, "atan", 2)
  else x = math.tofloat(1) end

  local fn = cu_math:get_function("atan2", {float, float}, {float})
  return fn(float(y), float(x)):to_lua_value()
end