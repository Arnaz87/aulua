
function tostr (obj, level, pre)
  level = level or 1
  pre = pre or ""
  if type(obj) ~= "table" or level == 0 then return tostring(obj) end

  if #obj > 0 then
    local str = "["
    for i = 1, #obj do
      if i > 1 then str = str .. "," end
      str = str .. "\n" .. pre .. "  " .. tostr(obj[i], level-1, pre .. "  ")
    end

    for k, v in pairs(obj) do
      if type(k) ~= "number" then
        str = str .. ",\n" .. pre .. "  " .. tostring(k) .. " = " .. tostr(v, level-1, pre .. "  ")
      end
    end

    return str .. "\n" .. pre .. "]"
  end

  local first = true
  local str = "{"
  for k, v in pairs(obj) do
    if first then first = false
    else str = str .. "," end
    str = str .. "\n" .. pre .. "  " .. tostring(k) .. " = " .. tostr(v, level-1, pre .. "  ")
  end
  str = str .. "\n" .. pre .. "}"
  if first then return "[]" end
  return str
end

function err (msg, node)
  if node then
    msg = msg .. ", at " .. node.line .. ":" .. node.column
  end
  error(msg)
end