
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
    Parser.error = msg
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

  if #types == 1 then
    return err(types[1]:lower() .. " expected")
  end

  local str = "("
  for i = 1, #types do
    if i > 1 then str = str .. " | " end
    str = str .. types[i]:lower()
  end

  err(str .. ") expected")
end

local function match (what, who, where)
  local tk = try(what)
  if tk then return tk end
  where = where or "?"
  err(what .. " expected (to close " .. who .. " at " .. where .. ")")
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
  grave("Expressions are not fully supported")
end

function Parser.expr ()
  return Parser.simpleexp()
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
  if true then
    return grave("For not yet supported")
  end
  expect("for")

  local tk = expect("NAME")
  if not tk then return end

  if check(",") then
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
    expect("end")
    return  {type="genfor", vars=names, explist=explist, body=body}
  end
end

function Parser.ifstat ()
  expect("if")
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

  match("end", "if")

  return { type="if", clauses=clauses }
end

function Parser.statement ()
  if try(";") then return nil

  elseif check("if") then
    return Parser.ifstat()

  elseif try("while") then
    local cond = Parser.expr()
    expect("do")
    local body = Parser.statlist()
    match("end", "while")
    return { type = "while", cond = cond, body = body }

  elseif try("do") then
    local body = Parser.statlist()
    match("end", "do")
    return { type = "do", body = body }

  elseif check("for") then
    return Parser.forstat()

  elseif try("repeat") then
    local body = Parser.statlist()
    match("until", "repeat")
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