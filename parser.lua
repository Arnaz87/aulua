
-- Lua magic to not pollute the global namespace
_ENV = setmetatable({}, {__index = _ENV})

Lexer = require("lexer")

Parser = {}

--------------------------------------------------------------------------------
----                                General                                 ----
--------------------------------------------------------------------------------

function Parser.open (text)
  Lexer.open(text)
  token = Lexer:next()
  Parser.error = nil
end

function err (msg)
  local pos = "<eof>"
  if token then
    pos = token.line .. ":" .. token.column
  end
  Parser.error = pos .. ": " .. msg
  error(Parser.error)
end

function grave (msg)
  msg = "\x1b[1;31m[| " .. msg .. " |]\x1b[0;39m"
  err(msg)
end

function next ()
  if token == nil then return nil end
  local old = token
  token = _lookahead or Lexer.next()
  _lookahead = nil

  -- Propagate lexer errors
  if Lexer.error then
    Parser.error = Lexer.error
    error(Parser.error)
  end

  return old
end

function check (...)
  if token == nil then return false end
  local types = table.pack(...)
  for i, tp in pairs(types) do
    if token.type == tp
    then return true end
  end
  return false
end

function check_not (...)
  return token and not check(...)
end

function try (...)
  if check(...) then
    return next()
  else return nil end
end

function expect (...)
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

function match (what, who)
  local tk = try(what)
  if tk then return tk end
  local where = who.line .. ":" .. who.column
  err(what .. " expected (to close " .. who.type .. " at " .. where .. ")")
end

function get_name ()
  local tk = expect("NAME")
  if tk then return tk.value
  else return nil end
end

function lookahead ()
  _lookahead = _lookahead or Lexer.next()
  return _lookahead
end

--------------------------------------------------------------------------------
----                              Expressions                               ----
--------------------------------------------------------------------------------

function Parser.singlevar ()
  local nm = get_name()
  return { type="var", name=nm }
end

function Parser.primaryexp ()
  if check("(") then
    local tk = expect("(")

    local expr = Parser.expr()
    assert(expr)

    match(")", tk)
    return expr
  elseif check("NAME") then
    return Parser.singlevar()
  end
  err("unexpected symbol") -- TODO: Not very helpful
end

function constructor ()
  local tk = expect("{")
  local fields = {}

  while check_not("}") do
    if try("[") then
      local key = Parser.expr()
      expect("]")
      expect("=")
      local value = Parser.expr()
      table.insert(fields, { type="key", key=key, value=value })

    elseif check("NAME") and lookahead() and lookahead().type == "=" then
      local name = get_name()
      expect("=")
      local value = Parser.expr()
      table.insert(fields, { type="namekey", name=name, value=value })

    else
      local exp = Parser.expr()
      table.insert(fields, { type="value", value=exp })
    end
  end
  match("}", tk)

  return { type = "constructor", fields=fields }
end

function funcargs (exp, method)
  local args = {}

  if check("STR") then
    args = { Parser.simpleexp() }
  elseif check("{") then
    args = { constructor() }
  else
    local tk = expect("(")
    if check_not(")") then
      args = Parser.explist()
    end
    match(")", tk)
  end

  return {type="call", expr=exp, args=args}
end

function Parser.suffixedexp ()
  local exp = Parser.primaryexp()
  while true do
    if check(".") then
      exp = fieldsel(exp)

    elseif try("[") then
      local index = Parser.expr()
      expect("]")
      exp = {type="index", expr=exp, index=index}

    elseif check(":") then
      exp = fieldsel(exp, true)
      exp = funcargs(exp, true)

    elseif check("(", "{", "STR") then
      exp = funcargs(exp)

    else return exp end
  end
end

function Parser.simpleexp ()
  if check("NUM") then
    return { type = "num", value = next().value }
  elseif check("true", "false", "nil") then
    return { type = next().type }
  elseif try("...") then
    return { type = "varargs" }
  elseif check("STR") then
    return { type="str", value = next().value }
  elseif check("{") then
    return constructor()
  elseif check("function") then
    local kw = next()
    return Parser.funcbody(kw)
  else
    return Parser.suffixedexp()
  end
end

priority = {
  -- [1]: left, [2]: right
  ["+"]={10, 10},
  ["-"]={10, 10},
  ["*"]={11, 11},
  ["%"]={11, 11},
  ["^"]={14, 13}, -- right associative
  ["/"]={11, 11},
  ["//"]={11, 11},
  ["&"]={6, 6},
  ["|"]={4, 4},
  ["~"]={5, 5},
  ["<<"]={7, 7},
  [">>"]={7, 7},
  [".."]={9, 8}, -- right associative
  ["<"]={3, 3},
  [">"]={3, 3},
  ["=="]={3, 3},
  ["~="]={3, 3},
  ["<="]={3, 3},
  [">="]={3, 3},
  ["and"]={2, 2},
  ["or"]={1, 1}
}
unary_priority = 12

function Parser.expr (limit)
  limit = limit or 0

  local left
  if check("not", "-", "~", "#") then
    left = {
      type = "unop",
      op = next().type,
      expr = Parser.expr(unary_priority)
    }
  else left = Parser.simpleexp() end

  local prio = token and priority[token.type]
  while prio and prio[1] > limit do
    local op = next().type
    local right = Parser.expr(prio[2])
    left = {type = "binop", op=op, left=left, right=right}
    prio = token and priority[token.type]
  end

  if left then return left
  else err("Invalid Expression") end
end

function Parser.explist ()
  local list = {}
  repeat
    local expr = Parser.expr()
    table.insert(list, expr)
  until not try(",")
  return list
end

-- Parameters and statlist
function Parser.funcbody (kw)
  local vararg = false
  local names = {}
  expect("(")

  if not check(")") then
    repeat
      if check("NAME") then
        table.insert(names, get_name())
      elseif try("...") then
        vararg = true
        break
      else expect("NAME", "...") end
    until not try(",")
  end
  expect(")")

  local body = Parser.statlist()
  match("end", kw)
  return {type = "function", vararg = vararg, args = names, body = body}
end

function fieldsel (value, method)
  if method then expect(":")
  else expect(".") end

  local name = get_name()
  return {type="fieldsel", val=value, name=name}
end

--------------------------------------------------------------------------------
----                               Statements                               ----
--------------------------------------------------------------------------------

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

  local els
  if try("else") then
    els = Parser.statlist()
  end

  match("end", kw)

  return { type="if", clauses=clauses, els=els }
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

  elseif check("function") then
    local kw = expect("function")

    local name , method = Parser.singlevar()
    while check(".") do
      name = fieldsel(name)
    end
    if check(":") then
      name = fieldsel(name, true)
      method = true
    end
    
    local body = Parser.funcbody(kw)

    return { type = "funcstat", name = name, body = body, method = method }

  elseif try("local") then
    if check("function") then
      local kw = expect("function")
      local name = get_name()
      local body = Parser.funcbody(kw)
      return { type = "localfunc", name = name, body = body}
    else
      local names = {}

      repeat table.insert(names, get_name())
      until not try(",")

      local explist = nil
      if try("=") then
        explist = Parser.explist()
      end

      return { type = "local", names=names, explist=explist }
    end

  elseif try("::") then
    local name = get_name()
    expect("::")
    return {type = "label", name = name}

  elseif try("return") then
    local list
    if check_not(";", "end", "else", "elseif", "until") then
      list = Parser.explist()
    end
    try(";") -- Optional ;
    return { type = "return", arguments = list }

  elseif try("break") then
    return { type = "break" }

  elseif try("goto") then
    local name = get_name()
    return { type = "goto", label = name}

  else
    local expr = Parser.suffixedexp()
    if expr.type == "call" then return expr
    else -- If it's not a call, it can be a var, index, fieldsel or parenthesis
      local vars = {expr}
      while try(",") do
        expr = Parser.suffixedexp()
        table.insert(vars, expr)
      end
      expect("=")

      local explist = Parser.explist()

      return {type = "assignment", vars = vars, explist = explist}
    end
  end
end

function Parser.statlist ()
  local statlist = {}
  while check_not("end", "else", "elseif", "until") do
    local stat = Parser.statement()
    if stat then
      table.insert(statlist, stat)
      if stat.type == "return" then break end
    end
  end
  return statlist
end

function parse_program ()
  local statlist = Parser.statlist()
  if token then err("end of file expected") end
  return statlist
end

function Parser.program ()

  local trace

  status, prog = xpcall(parse_program, function (msg)
    if Parser.error == nil then
      trace = debug.traceback(msg, 2)
    end
  end)

  if trace then
    --print("\x1b[31mInternal Parser Error\x1b[39m")
    print(trace)
    os.exit(1)
  end

  if status then return prog
  elseif Parser.error
  then return nil, tk
  else error(tk) end
end

return Parser