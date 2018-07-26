
local compile = require("culua.compile")

function help (msg)
  if msg then print(msg) end
  print("usage: culua [options] filename")
  print("Available options are:")
  print("  -o name  output to file 'name'")
  print("           default is 'filename' as it would be passed to 'require'")
  print("           if it's a directory, the file will be written there with")
  print("             the default filename")
  print("  -v       Show version information")
  print("  -h       Show this help message")
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
    i = i+1
    if not arg[i] then
      help("'-o' needs argument")
    end
    out_filename = arg[i]
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

local default = filename:gsub("[$.]lua$", ""):gsub("[/\\]+", ".")
if not out_filename then
  out_filename = default
elseif out_filename:match("/$") then
  out_filename = out_filename .. default
end

input_file = io.open(filename, "r")
contents = input_file:read("a")
input_file:close()

output_file = io.open(out_filename, "wb")
function callback (byte)
  output_file:write(string.char(byte))
end

local err = compile(contents, callback, filename)
output_file:close()

if err then print("Error: " .. Parser.error) os.exit(1) end