
local Parser = require("lua_parser.parser")

function show (obj, indent)
  if type(obj) ~= "table" then
    return(tostring(obj))
  end
  indent = indent or ""
  local str = "{\n"
  for k, v in pairs(obj) do
    local pair = tostring(k) .. " = " .. show(v, indent .. "  ")
    str = str .. indent .. "  " .. pair .. "\n"
  end
  return str .. indent .. "}"
end

Parser.open("local r = a + b")
local node = Parser.parse()

print(show(node))


