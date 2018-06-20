
-- Lua magic to not pollute the global namespace
_ENV = setmetatable({}, {__index = _ENV})

Lexer = require("parser/lexer")

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

function next ()
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
  if not token then return false end
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

-- Returns a function tht when applied to a table, returns that table with
-- additional "line" and "column" fields with the current token's position
function get_pos ()
  local line = 0
  local column = 0
  if token then
    line = token.line
    column = token.column
  end
  return function (tk)
    tk.line=line
    tk.column=column
    return tk
  end
end

--------------------------------------------------------------------------------
----                              Expressions                               ----
--------------------------------------------------------------------------------

function Parser.singlevar ()
  local pos = get_pos()
  local nm = get_name()
  return pos{ type="var", name=nm }
end

function constructor ()
  local pos = get_pos()
  local tk = expect("{")
  local items = {}

  while check_not("}") do
    if try("[") then
      local key = Parser.expr()
      expect("]")
      expect("=")
      local value = Parser.expr()
      table.insert(items, { type="indexitem", key=key, value=value })

    elseif check("NAME") and lookahead() and lookahead().type == "=" then
      local name = get_name()
      expect("=")
      local value = Parser.expr()
      table.insert(items, { type="fielditem", key=name, value=value })

    else
      local exp = Parser.expr()
      table.insert(items, { type="item", value=exp })
    end

    try(",", ";") -- Skip separators
  end
  match("}", tk)

  return pos{ type = "constructor", items=items }
end

function funcargs (exp, method)
  local args = {}

  local ln, col = exp.line, exp.column

  local key
  if try(":") then
    if token then
      ln = token.line
      col = token.column
    end
    key = get_name()
  end

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

  return {type="call", base=exp, values=args, key=key, line=ln, column=col}
end

function Parser.suffixedexp (msgerr)

  ------------------------- Primary expression
  local exp, parens = nil, false
  if check("(") then
    local tk = expect("(")
    exp = Parser.expr()
    match(")", tk)
    parens = true
  elseif check("NAME") then
    exp = Parser.singlevar()
  else err(msgerr or "syntax error") end

  ------------------------- Suffixes
  while true do
    if check(".") then
      exp = fieldsel(exp)
      parens = false

    elseif try("[") then
      local pos = get_pos()
      local index = Parser.expr()
      expect("]")
      exp = pos{type="index", base=exp, key=index}
      parens = false

    elseif check(":", "(", "{", "STR") then
      exp = funcargs(exp)
      parens = false

    else return exp, parens end
  end
end

function Parser.simpleexp ()
  local pos = get_pos()
  if check("NUM") then
    return pos{ type = "num", value = next().value }
  elseif check("true", "false", "nil") then
    return pos{ type = "const", value = next().type }
  elseif try("...") then
    return pos{ type = "vararg" }
  elseif check("STR") then
    return pos{ type="str", value = next().value }
  elseif check("{") then
    return constructor()
  elseif check("function") then
    local kw = next()
    return pos(Parser.funcbody(kw))
  else
    return Parser.suffixedexp("invalid expression")
  end
end

priority = {
  -- [1]: left, [2]: right
  ["+"]={10, 10},
  ["-"]={10, 10},
  ["*"]={11, 11},
  ["%"]={11, 11},
  ["/"]={11, 11},
  ["//"]={11, 11},
  ["^"]={14, 13}, -- right associative
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
    local pos = get_pos()
    left = pos{
      type = "unop",
      op = next().type,
      expr = Parser.expr(unary_priority)
    }
  else left = Parser.simpleexp() end

  local prio = token and priority[token.type]
  while prio and prio[1] > limit do
    local pos = get_pos()
    local op = next().type
    local right = Parser.expr(prio[2])
    left = pos{type = "binop", op=op, left=left, right=right}
    prio = token and priority[token.type]
  end
  return left
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
  return {type = "function", vararg = vararg, names = names, body = body}
end

function fieldsel (base, method)
  if method then expect(":")
  else expect(".") end

  local pos = get_pos()
  local name = get_name()
  return pos{type="field", base=base, key=name}
end

--------------------------------------------------------------------------------
----                               Statements                               ----
--------------------------------------------------------------------------------

-- Statements that start with an expression: assignment and calls
function Parser.exprstat ()
  local pos = get_pos()
  local expr, parens = Parser.suffixedexp("invalid statement")

  if not parens and expr.type == "call" then return expr
  else
    local lhs = {expr}
    while try(",") do
      local _paren
      expr, _paren = Parser.suffixedexp("invalid statement")
      if _paren then parens = true end
      table.insert(lhs, expr)
    end

    expect("=")

    if parens then err("assignment to a parenthesized expression") end
    for i, exp in pairs(lhs) do
      if  exp.type ~= "var"
      and exp.type ~= "field"
      and exp.type ~= "index"
      then err("assignment to a non lvalue expression")
      end
    end

    local values = Parser.explist()
    return pos{type = "assignment", lhs = lhs, values = values}
  end
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
    local values = Parser.explist()
    expect("do")
    local body = Parser.statlist()
    match("end", kw)
    return  {type="genfor", names=names, values=values, body=body}
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

  local els= {}
  if try("else") then
    els = Parser.statlist()
  end

  match("end", kw)

  return { type="if", clauses=clauses, els=els }
end

function Parser.statement ()
  local pos = get_pos()
  if try(";") then return nil

  elseif check("if") then
    return pos(Parser.ifstat())

  elseif check("while") then
    local kw = next()
    local cond = Parser.expr()
    expect("do")
    local body = Parser.statlist()
    match("end", kw)
    return pos{ type = "while", cond = cond, body = body }

  elseif check("do") then
    local kw = next()
    local body = Parser.statlist()
    match("end", kw)
    return pos{ type = "do", body = body }

  elseif check("for") then
    return pos(Parser.forstat())

  elseif check("repeat") then
    local kw = next()
    local body = Parser.statlist()
    match("until", kw)
    local cond = Parser.expr()
    return pos{ type = "repeat", cond = cond, body = body }

  elseif check("function") then
    local kw = expect("function")

    local lhs , method = Parser.singlevar(), false
    while check(".") do
      lhs = fieldsel(lhs)
    end
    if check(":") then
      lhs = fieldsel(lhs, true)
      method = true
    end
    
    local body = Parser.funcbody(kw)

    return pos{ type = "funcstat", lhs = lhs, body = body, method = method }

  elseif try("local") then
    if check("function") then
      local kw = expect("function")
      local name = get_name()
      local body = Parser.funcbody(kw)
      return pos{ type = "localfunc", name = name, body = body}
    else
      local names = {}

      repeat table.insert(names, get_name())
      until not try(",")

      local values = {}
      if try("=") then
        values = Parser.explist()
      end

      return pos{ type = "local", names=names, values=values }
    end

  elseif try("::") then
    local name = get_name()
    expect("::")
    return pos{type = "label", name = name}

  elseif try("return") then
    local list = {}
    if check_not(";", "end", "else", "elseif", "until") then
      list = Parser.explist()
    end
    try(";") -- Optional ;
    return pos{ type = "return", values = list }

  elseif try("break") then
    return pos{ type = "break" }

  elseif try("goto") then
    local name = get_name()
    return pos{ type = "goto", name = name}

  else
    return Parser.exprstat()

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

--------------------------------------------------------------------------------
----                               Interface                                ----
--------------------------------------------------------------------------------

function parse_program ()
  local statlist = Parser.statlist()
  if token then err("end of file expected") end
  return statlist
end

function Parser.parse ()

  local trace

  status, prog = xpcall(parse_program, function (msg)
    if Parser.error == nil then
      trace = debug.traceback(msg, 2)
    else
      Parser.trace = debug.traceback(msg, 4)
    end
  end)

  if trace then
    print(trace)
    os.exit(1)
  end

  if status then return prog
  elseif Parser.error
  then return nil, tk
  else error(tk) end
end

return Parser