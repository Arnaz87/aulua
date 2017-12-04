
local Lexer = require("lexer")

local Parser = {}

local token

function Parser.open (text)
  Lexer.open(text)
  token = Lexer:next()
  Parser.error = nil
end

local function err (msg)
  if not Parser.error then
    local pos = " before end of file"
    if token then
      pos = " at " .. Lexer.get_position(token)
    end
    Parser.error = msg .. pos
    token = nil
  end
end

local function grave (msg)
  msg = "\x1b[1;31m[| " .. msg .. " |]\x1b[0;39m"
  err(msg)
end

local function next ()
  if token == nil then return nil end
  local old = token
  token = Lexer.next()
  return old
end

local function check (...)
  if token == nil then return false end
  local types = table.pack(...)
  for i, tp in pairs(types) do
    if token.type == tp
    then return true end
  end
  return false
end

local function try (...)
  if check(...) then
    return next()
  else return nil end
end

local function expect (...)
  local tk = try(...)
  if tk then return tk end

  local types = table.pack(...)

  local str = ""
  for i = 1, #types do
    if i > 1 then str = str .. " or " end
    str = str .. types[i]:lower()
  end

  err(str .. " expected")
end

local function match (what, who)
  local tk = try(what)
  if tk then return tk end
  where = where or "?"
  err(what .. " expected (to close " .. who.type .. " at " .. Lexer.get_position(who) .. ")")
end

function Parser.simpleexp ()
  if check("NUM") then
    return { type = "num", value = next().value }
  elseif check("true", "false", "nil") then
    return { type = next().type }
  elseif try("...") then
    return { type = "varargs" }
  elseif check("NAME") then
    return { type="var", value = next().value }
  elseif check("STR") then
    return { type="str", value = next().value }
  end
end

function Parser.expr ()
  local exp = Parser.simpleexp()
  if exp then return exp
  else err("Invalid Expression") end
end

function Parser.prymaryexp ()
  if try("(") then
    local expr = Parser.expr()
    assert(expr)

    if not try(")") then
      return err(") expected") end -- TODO: Indicate position of (
  elseif check("NAME") then
    return { type="var", value = next().value }
  end
  err("unexpected symbol")
end

function Parser.suffixedexp ()
  local exp = Parser.primaryexp()
end

function Parser.explist ()
  local list = {}
  repeat
    local expr = Parser.expr()
    table.insert(list, expr)
  until not try(",")
  return list
end

function Parser.forstat ()
  local kw = expect("for")

  local tk = expect("NAME")
  if not tk then return end

  if try("=") then
    local name = tk.value
    local init = Parser.expr()
    expect(",")
    local limit = Parser.expr()
    local step
    if try(",") then
      step = Parser.expr()
    end

    expect("do")
    local body = Parser.statlist()
    match("end", kw)
    return {
      type="numfor", name=name, body=body,
      init=init, limit=limit, step=step
    }
  elseif check(",", "in") then
    local names = {tk.value}
    while try(",") do
      tk = expect("NAME")
      if not tk then return end
      table.insert(names, tk.value)
    end
    expect("in")
    local explist = Parser.explist()
    expect("do")
    local body = Parser.statlist()
    match("end", kw)
    return  {type="genfor", vars=names, explist=explist, body=body}
  else expect("=", ",", "in") end
end

function Parser.ifstat ()
  local kw = expect("if")
  local clauses = {}

  local cond = Parser.expr()
  expect("then")
  local body = Parser.statlist()
  table.insert(clauses, {
    type="clause", cond=cond, body=body
  })

  while try("elseif") do
    cond = Parser.expr()
    expect("then")
    body = Parser.statlist()
    table.insert(clauses, {
      type="clause", cond=cond, body=body
    })
  end

  if try("else") then
    body = Parser.statlist()
    table.insert(clauses, {
      type="clause", body=body
    })
  end

  match("end", kw)

  return { type="if", clauses=clauses }
end

function Parser.statement ()
  if try(";") then return nil

  elseif check("if") then
    return Parser.ifstat()

  elseif check("while") then
    local kw = next()
    local cond = Parser.expr()
    expect("do")
    local body = Parser.statlist()
    match("end", kw)
    return { type = "while", cond = cond, body = body }

  elseif check("do") then
    local kw = next()
    local body = Parser.statlist()
    match("end", kw)
    return { type = "do", body = body }

  elseif check("for") then
    return Parser.forstat()

  elseif check("repeat") then
    local kw = next()
    local body = Parser.statlist()
    match("until", kw)
    local cond = Parser.expr()
    return { type = "repeat", cond = cond, body = body }

  elseif try("local") then
    if try("function") then
      return err("Local function not yet supported")
    else
      local names = {}
      repeat
        local var = expect("NAME")
        if not var then return end
        table.insert(names, var.value)
      until not try(",")

      local explist = nil
      if try("=") then
        explist = Parser.explist()
      end

      return {type="local", names=names, explist=explist}
    end

  elseif try("return") then
    local list
    if token and not check(";", "end", "else", "elseif", "until") then
      list = Parser.explist()
    end
    try(";") -- Optional ;
    return { type = "return", arguments = list }

  elseif try("break") then
    return { type = "break" }

  else err("ivalid statement") end
end

function Parser.statlist ()
  local statlist = {}
  while token and not check("end", "else", "elseif", "until") do
    local stat = Parser.statement()
    if stat then
      table.insert(statlist, stat)
      if stat.type == "return" then break end
    end
  end
  return statlist
end

function Parser.program ()
  local statlist = Parser.statlist()
  if not Parser.error and not token
    then return statlist
  else err("end of file expected") end
end

return Parser