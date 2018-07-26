

local Parser = require("lua_parser.parser")
local codegen = require("culua.codegen")
local write = require("culua.write")

--[[ Example usage:

local compile = require("simple")
local function f (byte)
  -- will be called with each byte emited
  -- file:write(string.char(byte))
end
compile("print('hello world')", f, "optional_filename.lua")

--]]

return function (source, f, name)
  Parser.open(source)
  local ast, err = Parser.parse()
  if err then return err end
  codegen(ast, name)
  write(f)
end