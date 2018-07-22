
local compiler = require("simple")

--[[if _CU_VERSION then
  function string.format (fmt, num)
    local letters = "0123456789abcdef"
    local str = ""
    repeat
      local floor = num // 16
      local index = num - (floor*16) + 1
      local digit = letters:sub(index, index)
      str = digit .. str
      num = floor
    until num == 0
    return str
  end
end

function hex (x)
  local s = string.format("%x", x)
  if #s < 2 then s = "0" .. s end
  return s
end

text = ""
local i = 1
local c = 1

compiler("local x = 5", function (byte)
  text = text .. " " .. hex(byte)
  --if i % 8 == 0 then
  if c == 8 then
    text = text .. "\n"
    c = 0
  end
  i = i+1
  c = c+1
end)

print(text)]]

local text = ""
compiler("print(42)", function (byte)
  text = text .. string.char(byte)
end)
print(text)
