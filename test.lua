
local compiler = require("culua.compile")

local text = ""
compiler("print(42)", function (byte)
  text = text .. string.char(byte)
end)
print(text)
