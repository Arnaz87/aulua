
local Parser = require("lua_parser.parser")

-- Receives a string with lua code and returns the parsed statement list
-- In case of error, returns nil and the error message
return function (src)
  Parser.open(src)
  return Parser.parse()
end