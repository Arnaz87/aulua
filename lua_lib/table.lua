
function ipairs (t)
  local function nxt (t, i)
    i = i+1
    local v = t[i]
    if v then return i, v end
  end
  return nxt, t, 0
end

function pairs (t)
  local function nxt (t, k)
    k = next(t, k)
    return k, t[k]
  end
  return nxt, t, nil
end

local function getstr (s, default, index, fname)
  local _tp = type(s)
  if s == nil and default then return default end
  if _tp == "number" then s = tostring(s) end
  if type(s) == "string" then return s end
  error("bad argument #" .. index .. " for '" .. fname .. " (expected string, got " .. _tp .. ")")
end

local function getnum (n, default, index, fname)
  local _tp = type(i)
  if n == nil and default then return default end
  if _tp == "string" then n = tonumber(n) end
  if type(n) == "number" then return n end
  error("bad argument #" .. index .. " for '" .. fname .. " (expected number, got " .. _tp .. ")")
end

function table:concat (sep, i, j)
  if type(self) ~= "table" then
    error("bad argument #1 for 'table.concat' (expected table, got " .. type(self) .. ")")
  end

  sep = getstr(sep, "", 1, "table.concat")
  i = getnum(i, 1, 2, "table.concat")
  j = getnum(j, #self, 3, "table.concat")
  if j > #self then j = #self end
  if i > j then return "" end

  local str = self[i]
  for x = i+1, j do
    str = str .. sep
    str = str .. self[x]
  end
  return str
end

function table:insert (pos, value)
  if value == nil then
    value = pos
    pos = #self+1
  end
  pos = getnum(pos, nil, 2, "table.insert")

  if pos <= #self then
    for i = #self, pos, -1 do
      self[i+1] = self[i]
    end
  end
  self[pos] = value
end

function table.move (a1, f, e, t , a2)
  a2 = a2 or a1
  if t > e or t <= f then
    while f <= e do
      a2[t] = a1[f]
      t, f = t+1, f+1
    end
  else
    t = t + (e-f)
    while e >= f do
      a2[t] = a1[e]
      t, e = t-1, e-1
    end
  end
  return a2
end

function table:remove (pos)
  local len = #self
  if not pos then pos = len end

  -- The manual says that this removes the last element,
  -- but the implementation does nothing
  if pos == len+1 then return end -- follow the implementation
  if pos > len then error("bad argument #1 to 'table.remove' (position out of bounds)") end

  local v = self[pos]
  if pos < len then
    table.move(self, pos+1, len, pos)
  end
  self[len] = nil
  return v
end
