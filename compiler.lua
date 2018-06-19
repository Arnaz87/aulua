
-- Lua magic to not pollute the global namespace
_ENV = setmetatable({}, {__index = _ENV})

Parser = require("parser")

file = io.open("test.lua", "r")
contents = file:read("a")
Parser.open(contents)
ast = Parser.parse()
if not ast then print("Error: " .. Parser.error) os.exit(1) end

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

--------------------------------------------------------------------------------
----                                 Basics                                 ----
--------------------------------------------------------------------------------

modules = {}
types = {}
funcs = {}

local _m = {}
function _m:type (name)
  local t = {id=#types, name=name, module=self.id}
  table.insert(types, t)
  setmetatable(t, {
    __tostring = function (f)
      return self:fullname() .. "." .. name
    end
  })
  return t
end
function _m:func (name, ins, outs)
  local f = {_id=#funcs, name=name, ins={}, outs={}, module=self.id}
  function f:id () return self._id end
  for i, t in ipairs(ins) do f.ins[i] = t.id end
  for i, t in ipairs(outs) do f.outs[i] = t.id end
  table.insert(funcs, f)
  setmetatable(f, {
    __tostring = function (f)
      return self:fullname() .. "." .. name
    end
  })
  return f
end
function _m:fullname ()
  if self.base then
    local args = {}
    for _, item in ipairs(self.argument.items) do
      args[#args] = item.name .. "=" .. tostring(item.tp or item.fn or "¿?")
    end
    return self.base.name .. "(" .. table.concat(args, " ") .. ")"
  else return self.name or "<unknown>" end
end
function module (name)
  -- Positions 0 and 1 are reserved
  local m = {id=#modules+2, name=name}
  setmetatable(m, {__index = _m})
  table.insert(modules, m)
  return m
end

local scope_count = 0

local _f = {}
_f.__index = _f
function _f:id () return self._id end
function _f:reg ()
  local r = {id=#self.regs}
  table.insert(self.regs, r)
  setmetatable(r, {
    __tostring = function (slf) return "reg_" .. slf.id end
  })
  return r
end
function _f:inst (data)
  table.insert(self.code, data)
  return data
end
function _f:lbl ()
  local l = self.label_count + 1
  self.label_count = l
  return l
end
function _f:call (...)
  return self:inst{...}
end
function _f:push_scope ()
  self.scope = { locals={}, labels={}, id=scope_count }
  table.insert(self.scopes, self.scope)
  scope_count = scope_count+1
end
function _f:pop_scope ()
  table.remove(self.scopes)
  self.scope = self.scopes[#self.scopes]
end
function code (name)
  local f = {
    _id=#funcs,
    name=name,
    regs={},
    code={},
    label_count=0,
    labels={},
    ins={},
    outs={},
    upvals={},
    scopes={},
    loops={},
  }
  setmetatable(f, _f)
  table.insert(funcs, f)
  f:push_scope()
  return f
end
function _f:__tostring ()
  return ":lua:" .. (self.name or "")
end

constants = {}

function constant (tp, value)
  local data = {_id=#constants, type=tp, value=value, ins={}, outs={0}}
  function data:id () return self._id + #funcs end
  table.insert(constants, data)
  setmetatable(data, {
    __tostring = function (self) return "cns_" .. self:id() end
  })
  return data
end

function constcall (f, ...)
  local data = constant("call")
  data.f = f
  data.args = table.pack(...)
  return data
end

--------------------------------------------------------------------------------
----                                Imports                                 ----
--------------------------------------------------------------------------------

int_m = module("cobre\x1fint")
bool_m = module("cobre\x1fbool")
str_m = module("cobre\x1fstring")
lua_m = module("lua")
closure_m = module("closure")
closure_m.from = lua_m
record_m = module("cobre\x1frecord")
any_m = module("cobre\x1fany")
buffer_m = module("cobre\x1fbuffer")

any_t = any_m:type("any")
bool_t = bool_m:type("bool")
bin_t = buffer_m:type("buffer")
int_t = int_m:type("int")
string_t = str_m:type("string")
stack_t = lua_m:type("Stack")
func_t = lua_m:type("Function")

newstr_f = str_m:func("new", {bin_t}, {string_t})
str_f = lua_m:func("_string", {string_t}, {any_t})

int_f = lua_m:func("_int", {int_t}, {any_t})
nil_f = lua_m:func("nil", {}, {any_t})
true_f = lua_m:func("_true", {}, {any_t})
false_f = lua_m:func("_false", {}, {any_t})
bool_f = lua_m:func("tobool", {any_t}, {bool_t})
func_f = lua_m:func("_function", {func_t}, {any_t})
call_f = lua_m:func("call", {any_t, stack_t}, {stack_t})

global_f = lua_m:func("create_global", {}, {any_t})

stack_f = lua_m:func("newStack", {}, {stack_t})
push_f = lua_m:func("push\x1dStack", {stack_t, any_t}, {})
next_f = lua_m:func("next\x1dStack", {stack_t}, {any_t})
getstack_f = lua_m:func("get\x1dStack", {stack_t}, {int_t})
append_f = lua_m:func("append\x1dStack", {stack_t, stack_t}, {})

table_f = lua_m:func("newTable", {}, {any_t})
get_f = lua_m:func("get", {any_t, any_t}, {any_t})
set_f = lua_m:func("set", {any_t, any_t, any_t}, {})

binops = {
  ["+"] = lua_m:func("add", {any_t,any_t}, {any_t}),
  ["-"] = lua_m:func("sub", {any_t,any_t}, {any_t}),
  ["*"] = lua_m:func("mul", {any_t,any_t}, {any_t}),
  ["/"] = lua_m:func("div", {any_t,any_t}, {any_t}),
  [".."] = lua_m:func("concat", {any_t,any_t}, {any_t}),
  ["=="] = lua_m:func("eq", {any_t,any_t}, {any_t}),
  ["~="] = lua_m:func("ne", {any_t,any_t}, {any_t}),
  ["<"] = lua_m:func("lt", {any_t,any_t}, {any_t}),
  [">"] = lua_m:func("gt", {any_t,any_t}, {any_t}),
  ["<="] = lua_m:func("le", {any_t,any_t}, {any_t}),
  [">="] = lua_m:func("ge", {any_t,any_t}, {any_t}),
}

--------------------------------------------------------------------------------
----                                Compile                                 ----
--------------------------------------------------------------------------------

function _f:create_upval_info ()
  -- Every function has an upval type, which is a record with all the upvalues

  -- The upval type has to be known beforehand to pass it to children closure
  -- functions, but cannot be construted yet because the locals used as
  -- upvalues have to be known, we have to call build_upvals after codegen

  -- The record module, it is a functor that receives argmod as an argument
  self.upval_module = module()
  self.upval_module.base = record_m
  
  -- For each field in the record type, the argument module has that field's
  -- type named as an item named with the base10 representation of the
  -- 0-indexed position of that field
  local argmod = module()
  argmod.items = {}
  self.upval_module.argument = argmod

  -- Get the actual type from that module
  self.upval_type = self.upval_module:type("")

  -- The record constructor function, it receives all it's field's values as arguments
  self.upval_new_fn = self.upval_module:func("new", {}, {self.upval_type})

  -- This instruction will be before all compiled code but after the code
  -- generated by build_upvals
  self.upval_new_call = self:inst{self.upval_new_fn}

  -- The parent's upval object is this' first field, to give closures access
  -- to any ancestry upvalue
  if self.parent then
    local parent_type = self.parent.upval_type

    table.insert(argmod.items, {name = "0", tp = parent_type})
    table.insert(self.upval_new_fn.ins, parent_type.id)
    table.insert(self.upval_new_call, self.upval_arg)

    -- Function to extract the parent's upvalues from this one's
    self.parent_upval_getter = self.upval_module:func(
      "get0", {self.upval_type}, {parent_type}
    )
  end

  self.upval_accessors = {}
end

function _f:build_upvals ()
  -- Here, after compiling the code, we know which locals are used in closure
  -- functions, so we can now describe the actual contents of the upval module
  -- and type. Check _f:create_upval_info for more information

  local argitems = self.upval_module.argument.items

  -- This code will be prepended to the already compiled code
  local oldcode = self.code
  self.code = {}

  -- Assign a register to each ancestor level upvalues
  self.upval_level_regs = { [self.level] = self.upval_new_call }

  if self.parent then
    local reg = self.upval_arg
    self.upval_level_regs[self.parent.level] = reg

    local ancestor = self.parent
    while ancestor.parent do
      local reg = self:inst{ancestor.parent_upval_getter, reg}
      self.upval_level_regs[ancestor.parent.level] = reg
      ancestor = ancestor.parent
    end
  end

  local nil_reg = self:inst{nil_f}

  for _, reg in ipairs(self.upvals) do
    local id = reg.upval_id

    -- Add a field to the type, by adding the corresponging item to the argument
    table.insert(argitems, { name = tostring(id), tp = any_t })

    -- Add the argument type to the constructor function
    table.insert(self.upval_new_fn.ins, any_t.id)

    -- Add a nil value to the upvalue constructor call
    table.insert(self.upval_new_call, nil_reg)
  end

  -- Append the old code to the end of the current code
  table.move(oldcode, 1, #oldcode, #self.code+1, self.code)
end

function _f:get_local (name, as_upval)
  local lcl
  for i = #self.scopes, 1, -1 do
    lcl = self.scopes[i].locals[name]
    if lcl then break end
  end

  if lcl then
    if as_upval and not lcl.is_upval then
      local id = #self.upvals

      -- Because the first "upvalue" is the parents upvalue object
      if self.parent then id = id+1 end

      lcl.is_upval = true
      lcl.upval_level = self.level
      lcl.upval_id = id

      self.upval_accessors[id] = {
        getter = self.upval_module:func("get"..id, {self.upval_type}, {any_t}),
        setter = self.upval_module:func("set"..id, {self.upval_type, any_t}, {})
      }

      table.insert(self.upvals, lcl)
    end
    return lcl
  end

  if self.parent then
    return self.parent:get_local(name, true)
  end
end

function _f:get_level_ancestor (level)
  while self do
    if self.level == level then
      return self
    end
    self = self.parent
  end
  error("Could not find ancestor of level " .. level)
end

function _f:createFunction (node)
  local fn = code("function")
  fn.node = node
  fn.parent = self
  fn.level = self.level + 1
  fn.ins = {stack_t.id, self.upval_type.id}
  fn.outs = {stack_t.id}

  -- The first two registers are the two function arguments
  local vararg = {reg=0}
  fn.vararg = vararg
  fn.upval_arg = {reg=1}

  fn:create_upval_info()

  if node.method then
    table.insert(node.names, 1, "self")
  end

  for _, argname in ipairs(node.names) do
    local arg = fn:inst{next_f, vararg}
    fn.scope.locals[argname] = fn:inst{"local", arg}
  end

  fn:compileBlock(node.body)

  if #node.body == 0 or node.body[#node.body].type ~= "return" then
    local stackreg = fn:call(stack_f)
    fn:inst{"end", stackreg}
  end

  fn:build_upvals()
  fn:transform()

  -- Create and use the closure and function items
  local argmod = module()
  argmod.items = {{name="0", fn=fn}}

  local mod = module()
  mod.base = closure_m
  mod.argument = argmod

  local fn_new = mod:func("new", {self.upval_type}, {func_t})
  --local fn_new = mod:func("new", {self.any_t}, {func_t})


  -- Generate code in current function to create a runtime closure
  local raw = self:call(fn_new, self.upval_new_call)
  --local raw = self:call(fn_new, self:inst{nil_f})
  return self:call(func_f, raw)
end

function _f:compileCall (node)
  local base = self:compileExpr(node.base)
  local f_reg = base
  if node.key then
    local key = self:compileExpr{type="str", value=node.key}
    f_reg = self:call(get_f, base, key)
  end

  local args = self:call(stack_f)
  if node.key then
    self:call(push_f, args, base)
  end
  for i, v in ipairs(node.values) do
    -- If the last argument is a function call,
    -- append its result stack to the argument
    if i == #node.values and v.type == "call" then
      local result = self:compileCall(v)
      self:call(append_f, args, result)
    else
      local arg = self:compileExpr(v)
      self:call(push_f, args, arg)
    end
  end

  return self:call(call_f, f_reg, args)
end

function _f:compileExpr (node)
  local tp = node.type
  if tp == "const" then
    local f
    if node.value == "nil" then f = nil_f
    elseif node.value == "true" then f = true_f
    elseif node.value == "false" then f = false_f
    end
    return self:inst{f}
  elseif tp == "num" then
    local n = tonumber(node.value)
    local raw = constant("int", n)
    local cns = constcall(int_f, raw)
    return self:inst{cns}
  elseif tp == "str" then
    local raw = constant("bin", node.value)
    local str = constcall(newstr_f, raw)
    local cns = constcall(str_f, str)
    return self:inst{cns}
  elseif tp == "var" then
    local lcl = self:get_local(node.name)
    if lcl then
      return self:inst{"var", lcl}
    else
      local env = self:get_local("_ENV")
      if not env then err("local \"_ENV\" not in sight", node) end
      local base = self:inst{"var", env}
      local key = self:compileExpr{type="str", value=node.name}
      return self:call(get_f, base, key)
    end
  elseif tp == "binop" then
    local f = binops[node.op]
    local a = self:compileExpr(node.left)
    local b = self:compileExpr(node.right)
    return self:call(f, a, b)
  elseif tp == "index" then
    local base = self:compileExpr(node.base)
    local key = self:compileExpr(node.key)
    return self:call(get_f, base, key)
  elseif tp == "field" then
    local key = {type="str", value=node.key}
    return self:compileExpr{type="index", base=node.base, key=key}
  elseif tp == "function" then
    return self:createFunction(node)
  elseif tp == "constructor" then
    local table = self:call(table_f)
    local n = 1
    for _, item in ipairs(node.items) do
      local key
      if item.type == "indexitem" then
        key = self:compileExpr(item.key)
      elseif item.type == "fielditem" then
        key = self:compileExpr{type="str",value=item.key}
      elseif item.type == "item" then
        key = self:compileExpr{type="num", value=n}
        n = n+1
      end
      local value = self:compileExpr(item.value)
      self:call(set_f, table, key, value)
    end
    return table
  elseif tp == "call" then
    local result = self:compileCall(node)
    return self:call(next_f, result)
  else err("expression " .. tp .. " not supported", node) end
end

function _f:assign (vars, values)
  local last = math.max(#vars, #values)
  local stack

  for i = 1, last do
    local var, value, reg = vars[i], values[i]

    if i == #values and value.type == "call" then
      stack = self:compileCall(value)
    end

    if stack then
      reg = self:call(next_f, stack)
    elseif value then
      reg = self:compileExpr(value)
    else reg = self:call(nil_f) end

    if var then
      if var.lcl then
        self.scope.locals[var.lcl] = self:inst{"local", reg}
      elseif var.base then
        self:call(set_f, var.base, var.key, reg)
      else
        local lcl = self:get_local(var)
        if lcl then
          self:inst{"set", lcl, reg}
        else
          local env = self:get_local("_ENV")
          if not env then err("local \"_ENV\" not in sight", node) end

          local base = self:inst{"var", env}
          local key = self:compileExpr{type="str", value=var}
          self:call(set_f, base, key, reg)
        end
      end
    end
  end
end

function _f:compileLhs (node)
  if node.type == "var" then return node.name
  elseif node.type == "index" then
    return {
      base = self:compileExpr(node.base),
      key = self:compileExpr(node.key)
    }
  elseif node.type == "field" then
    return {
      base = self:compileExpr(node.base),
      key = self:compileExpr{type="str", value=node.key}
    }
  else error("wtf") end
end

function _f:compileStmt (node)
  local tp = node.type
  if tp == "local" then
    local vars = {}
    for i, name in ipairs(node.names) do
      vars[i] = {lcl=name}
    end
    self:assign(vars, node.values)
  elseif tp == "call" then self:compileExpr(node)
  elseif tp == "assignment" then
    local vars = {}
    for i, var in ipairs(node.lhs) do
      vars[i] = self:compileLhs(var)
    end
    self:assign(vars, node.values)
  elseif tp == "return" then

    local stack = self:call(stack_f)
    for i, v in ipairs(node.values) do
      if i == #node.values and v.type == "call" then
        local result = self:compileCall(v)
        self:call(append_f, stack, result)
      else
        local arg = self:compileExpr(v)
        self:call(push_f, stack, arg)
      end
    end

    self:inst{"end", stack}
  elseif tp == "funcstat" then
    if node.method then
      table.insert(node.body.names, 1, "self")
    end
    self:assign({self:compileLhs(node.lhs)}, {node.body})
  elseif tp == "localfunc" then
    self:assign({{lcl=node.name}}, {node.body})
  elseif tp == "do" then
    self:push_scope()
    self:compileBlock(node.body)
    self:pop_scope()
  elseif tp == "if" then
    local if_end = self:lbl()
    for _, clause in ipairs(node.clauses) do
      local clause_end = self:lbl()
      local cond = self:compileExpr(clause.cond)
      self:inst{"nif", clause_end, cond}

      self:push_scope()
      self:compileBlock(clause.body)
      self:pop_scope()

      self:inst{"jmp", if_end}
      self:inst{"label", clause_end}
    end
    if node.els then
      self:push_scope()
      self:compileBlock(node.els)
      self:pop_scope()
    end
    self:inst{"label", if_end}
  elseif tp == "while" then
    local start = self:lbl()
    local endl = self:lbl()
    
    self:inst{"label", start} 
    local cond = self:compileExpr(node.cond)
    self:inst{"nif", endl, cond}
    
    table.insert(self.loops, endl)
    self:push_scope()
    self:compileBlock(node.body)
    self:pop_scope()
    table.remove(self.loops)

    self:inst{"jmp", start}
    self:inst{"label", endl}

  elseif tp == "repeat" then
    local start = self:lbl()
    local endl = self:lbl()

    table.insert(self.loops, endl)
    self:push_scope()

    self:inst{"label", start} 
    self:compileBlock(clause.body)
    local cond = self:compileExpr(clause.cond)
    self:inst{"jif", start, cond}
    self:inst{"label", endl}

    self:pop_scope()
    table.remove(self.loops)
  elseif tp == "break" then
    self:inst{"jmp", self.loops[#self.loops]}
  elseif tp == "label" then
    self:inst{"label", node.name}
  elseif tp == "goto" then
    -- TODO: Lua label restrictions:
    -- * only jump to labels in current or outer blocks
    --     (no visible label 'label-name' for <goto> at line N)
    -- * locals cannot be declared between a forward goto and it's label
    --     (<goto label-name> at line N jumps into the scope of local 'x')
    -- * labels are per block, not per function like currently
    -- Currently, the VM will crash on certain cases of the second restriction
    self:inst{"jmp", node.name, line=node.line}
  else err("statement not supported: " .. tp, node) end
end

function _f:compileBlock (nodes)
  for i, node in ipairs(nodes) do
    self:compileStmt(node)
  end
end

function _f:transform ()
  local oldcode = self.code
  self.code = {}
  self.labels = {}

  local regcount = #self.ins
  function reginc ()
    local r = regcount
    regcount = r+1
    return r
  end

  for _, inst in ipairs(oldcode) do
    local f = inst[1]
    if f == "local" then
      local arg = inst[2]
      if inst.is_upval then
        local reg = self.upval_level_regs[self.level]
        local setter = self.upval_accessors[inst.upval_id].setter
        self:inst{setter, reg, arg}
      elseif arg[1] == "var" and not arg.is_upval then
        self:inst{"dup", arg[1]}
        inst.reg = reginc()
      elseif arg.reg then
        inst.reg = arg.reg
      else print("argument does not have register") end
    elseif f == "var" then
      local var = inst[2]
      if var.is_upval then
        local reg = self.upval_level_regs[var.upval_level]
        local owner = self:get_level_ancestor(var.upval_level)
        local getter = owner.upval_accessors[var.upval_id].getter
        self:inst{getter, reg}
        inst.reg = reginc()
      else
        inst.reg = inst[2].reg
      end
    elseif f == "set" then
      local var, arg = inst[2], inst[3]
      if var.is_upval then
        local reg = self.upval_level_regs[var.upval_level]
        local owner = self:get_level_ancestor(var.upval_level)
        local setter = owner.upval_accessors[var.upval_id].setter
        self:inst{setter, reg, arg}
      else self:inst(inst) end
    elseif f == "label" then
      self.labels[inst[2]] = #self.code
    elseif f == "jif" or f == "nif" then
      inst[3] = self:inst{bool_f, inst[3]}
      inst[3].reg = reginc()
      self:inst(inst)
    elseif type(f) == "table" then

      if #inst-1 ~= #f.ins then
        error(tostring(f) .. " expects " .. #f.ins .. " arguments, but got " .. #inst-1)
      end

      if #f.outs == 1 then
        inst.reg = reginc()
      elseif #f.outs > 1 then
        error("Function with multiple returns?")
      end
      self:inst(inst)
    else self:inst(inst) end
  end
end

do -- main function
  lua_main = code("lua_main")
  lua_main.ins = {any_t.id}
  lua_main.outs = {stack_t.id}
  lua_main.level = 1

  lua_main:create_upval_info()
  lua_main.scope.locals["_ENV"] = lua_main:inst{"local", {reg=0}}
  lua_main.vararg = lua_main:inst{stack_f}

  lua_main:compileBlock(ast)
  if #ast == 0 or ast[#ast].type ~= "return" then
    local stack = lua_main:call(stack_f)
    lua_main:inst{"end", stack}
  end

  lua_main:build_upvals()
  lua_main:transform()

  main = code("main")
  local global = main:inst{global_f, reg=0}
  main:inst{lua_main, global, reg=1}
  main:inst{"end"}
end

--print(tostr(lua_main.code, 3))

--------------------------------------------------------------------------------
----                                Writing                                 ----
--------------------------------------------------------------------------------

-- [[

outfile = io.open("out", "wb")


function wbyte (...)
  outfile:write(string.char(...))
end

function wint (n)
  function f (n)
    if n > 0 then
      f(n >> 7)
      wbyte((n & 0x7f) | 0x80)
    end
  end
  f(n >> 7)
  wbyte(n & 0x7f)
end

function wstr (str)
  wint(#str)
  outfile:write(str)
end

outfile:write("Cobre 0.6\0")
wint(#modules+1) -- Count the export module, but not the argument module
wbyte(2, 2) -- Export module is a module definition with 2 items

wbyte(2) -- First item
wint(lua_main:id())
wstr("lua_main")

wbyte(2) -- First item
wint(main:id())
wstr("main")

for _, mod in ipairs(modules) do
  if mod.items then
    wbyte(2) -- define
    wint(#mod.items)
    for _, item in ipairs(mod.items) do
      if item.fn then
        wbyte(2)
        wint(item.fn:id())
      elseif item.tp then
        wbyte(1)
        wint(item.tp.id)
      else err("Unknown item kind for " .. tostr(item)) end
      wstr(item.name)
    end
  elseif mod.base and mod.argument then
    wbyte(4)-- build
    wint(mod.base.id)
    wint(mod.argument.id)
  elseif mod.from then
    wbyte(3) -- use
    wint(mod.from.id)
    wstr(mod.name)
  else -- import by default
    wbyte(1)
    wstr(mod.name)
  end
end

wint(#types)
for i, tp in ipairs(types) do
  wint(tp.module + 1)
  wstr(tp.name)
end

wint(#funcs)
for _, fn in ipairs(funcs) do
  if fn.code then
    wbyte(1)
  elseif fn.module then
    wint(fn.module + 2)
  else error("???") end
  wint(#fn.ins)
  for _, t in ipairs(fn.ins) do wint(t) end
  wint(#fn.outs)
  for _, t in ipairs(fn.outs) do wint(t) end
  if fn.module then wstr(fn.name) end
end

wint(#constants)
for i, cns in ipairs(constants) do
  if cns.type == "int" then
    wbyte(1)
    wint(cns.value)
  elseif cns.type == "bin" then
    wbyte(2)
    wstr(cns.value)
  elseif cns.type == "call" then
    if #cns.args ~= #cns.f.ins then
      error(cns.f.name .. " expects " .. #cns.f.ins .. " arguments, but got " .. #cns.args)
    end
    wint(cns.f:id() + 16)
    for i, v in ipairs(cns.args) do
      wint(v:id())
    end
  else error("constant " .. cns.type .. " not supported") end
end

function write_code (fn)

  local newcode = {}
  local regcount = 0

  local regs = #fn.regs

  local function getlbl (name, line)
    local lbl = fn.labels[name]
    if not lbl then
      error("no visible label '" .. name .. "' for <goto> at line " .. line)
    end
    return lbl
  end

  wint(#fn.code)
  for i, inst in ipairs(fn.code) do
    local f = inst[1]
    if f == "end" then
      if #inst-1 ~= #fn.outs then
        error(fn.name .. " outputs " .. #fn.outs .. " results, but end instrucion has " .. #inst-1)
      end
      wbyte(0)
      for i=2, #inst do
        wint(inst[i].reg)
      end
    elseif f == "dup" then
      wbyte(3)
      wint(inst[2].reg)
      inst.reg, regs = regs, regs+1
    elseif f == "set" then
      wbyte(4)
      wint(inst[2].reg)
      wint(inst[3].reg)
    elseif f == "jmp" then
      wbyte(5)
      wint(getlbl(inst[2], inst.line))
    elseif f == "jif" then
      wbyte(6)
      wint(getlbl(inst[2]))
      wint(inst[3].reg)
    elseif f == "nif" then
      wbyte(7)
      wint(getlbl(inst[2]))
      wint(inst[3].reg)
    elseif type(f) == "table" then
      -- Function call
      wint(f:id() + 16)
      for i = 2, #inst do
        wint(inst[i].reg)
      end
    else error("Unsupported instruction: " .. f) end
  end
end

-- Code
for _, fn in ipairs(funcs) do
  if fn.code then write_code(fn) end
end

wbyte(0) -- metadata

--print(tostr(funcs))

-- ]]