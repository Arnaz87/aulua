
function getstring (s, i)
  i = i or 1
  local t = type(s)
  if t == "number" then s = tostring(s) end
  if type(s) == "string" then return s end
  error("bad argument #"..i.." to 'string.len' (string expected, got " .. t .. ")")
end

function string.len (s) return #getstring(s) end

function string.upper (s)
  s = getstring(s)
  local s2 = ""
  for i = 1, #s do
    local code = s:byte(i)
    if code >= 97 and code <= 122 then
      code = code - 32
    end
    s2 = s2 .. string.char(code)
  end
  return s2
end

function string.lower (s)
  s = getstring(s)
  local s2 = ""
  for i = 1, #s do
    local code = s:byte(i)
    if code >= 65 and code <= 90 then
      code = code + 32
    end
    s2 = s2 .. string.char(code)
  end
  return s2
end

function string.reverse (s)
  s = getstring(s)
  local s2 = ""
  for i = #s, 1, -1 do
    s2 = s2 .. string:sub(i, i)
  end
  return s2
end

function string.rep (s, n, sep)
  sep = sep or ""
  if n < 1 then return "" end
  local r = s
  for i = 2, n do
    r = r .. sep .. s
  end
  return r
end