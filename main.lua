
Parser = require("lua_parser.parser")

function help (msg)
  if msg then print(msg) end
  print("usage: culua [options] filename")
  print("Available options are:")
  print("  -o name  output to file 'name'")
  print("           (default is 'filename' as it would be passed to 'require')")
  print("  -v       show version information")
  print("  -h       show this help message")
  os.exit()
end
if #arg == 0 then help() end

local filename
local out_filename

local i = 1
while i <= #arg do
  local a = arg[i]
  if a == "-h" then help()
  elseif a == "-v" then print("culua 0.5")
  elseif a == "-o" then
    if not arg[i+1] then
      help("'-o' needs argument")
    end
    out_filename = arg[i+1]
  elseif a:sub(1, 1) == "-" then
    help("unrecognized option '" .. a .. "'")
  else
    if filename then
      help("needs only one filename")
    end
    filename = a
  end
  i = i+1
end

if not filename then help("needs filename") end
out_filename = out_filename or filename:gsub("[$.]lua$", ""):gsub("[/\\]+", ".")

file = io.open(filename, "r")
contents = file:read("a")
Parser.open(contents)
ast = Parser.parse()
if not ast then print("Error: " .. Parser.error) os.exit(1) end

require("codegen")(ast, filename)
require("write")(out_filename)