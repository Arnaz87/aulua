
--[[ Simply use it like this:
  local compile = require("simple")
  local function f (byte)
    -- do something with the byte, it's an integer
    -- file:write(string.char(byte))
  end
  compile("print('hello world')", f, "optional filename")
--]]

local Parser = require("lua_parser.parser")
local codegen = require("codegen")
local write = require("write")

return function (source, f, name)
  Parser.open(source)
  local ast = Parser.parse()
  codegen(ast, name)
  write(f)
end