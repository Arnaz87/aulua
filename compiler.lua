
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
  if type(obj) ~= "table" or level == 0 then
    return tostring(obj) end

  if #obj > 0 then
    local str = "["
    for i = 1, #obj do
      if i > 1 then str = str .. ", " end
      str = str .. tostr(obj[i], level-1, pre)
    end
    return str .. "]"
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
  return t
end
function _m:func (name, ins, outs)
  local f = {_id=#funcs, name=name, ins={}, outs={}, module=self.id}
  function f:id () return self._id end
  for i, t in ipairs(ins) do f.ins[i] = t.id end
  for i, t in ipairs(outs) do f.outs[i] = t.id end
  table.insert(funcs, f)
  return f
end
function module (name)
  -- Positions 0 and 1 are reserved
  local m = {id=#modules+2, name=name}
  setmetatable(m, {__index = _m})
  table.insert(modules, m)
  return m
end

local _f = {}
function _f:id () return self._id end
function _f:reg ()
  local r = {id=#self.regs}
  table.insert(self.regs, r)
  return r
end
function _f:inst (data)
  table.insert(self.code, data)
  return data
end
function _f:lbl ()
  local l = self.lblc + 1
  self.lblc = l
  return l
end
function _f:call (f, ...)
  return self:inst{"call", f=f, args=table.pack(...)}
end
function code (name)
  local f = {
    _id=#funcs,
    name=name,
    regs={},
    code={},
    lblc=0,
    ins={},
    outs={},
    locals={},
  }
  setmetatable(f, {__index = _f})
  table.insert(funcs, f)
  return f
end

constants = {}

function constant (tp, value)
  local data = {_id=#constants, type=tp, value=value, ins={}, outs={0}}
  function data:id () return self._id + #funcs end
  table.insert(constants, data)
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

core_m = module("cobre.core")
int_m = module("cobre.int")
str_m = module("cobre.string")
lua_m = module("lua")
closure_m = module("closure")
closure_m.from = lua_m
record_m = module("cobre.record")

any_t = core_m:type("any")
bin_t = core_m:type("bin")
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
print_f = lua_m:func("_print", {stack_t}, {stack_t})
func_f = lua_m:func("_function", {func_t}, {any_t})
call_f = lua_m:func("call", {any_t, stack_t}, {stack_t})

push_f = lua_m:func("push:Stack", {stack_t, any_t}, {})
next_f = lua_m:func("next:Stack", {stack_t}, {any_t})
stack_f = lua_m:func("newStack", {}, {stack_t})

table_f = lua_m:func("newTable", {}, {any_t})
get_f = lua_m:func("get", {any_t, any_t}, {any_t})
set_f = lua_m:func("set", {any_t, any_t, any_t}, {})

binops = {
  ["+"] = lua_m:func("add", {any_t,any_t}, {any_t}),
  ["-"] = lua_m:func("sub", {any_t,any_t}, {any_t}),
  ["*"] = lua_m:func("mul", {any_t,any_t}, {any_t}),
  ["/"] = lua_m:func("div", {any_t,any_t}, {any_t}),
  [".."] = lua_m:func("concat", {any_t,any_t}, {any_t}),
}

--------------------------------------------------------------------------------
----                                Compile                                 ----
--------------------------------------------------------------------------------

function _f:initUpvals ()
  -- Do not create instructions here because compileUpvals moves them all
  local argmod = module()

  local mod = module()
  mod.base = record_m
  mod.argument = argmod

  self.upvalmod = mod
  self.upvaltype = mod:type("")

  self.upvals = 0
  self.levels = { [self] = self:call() }

  if self.parent then
    self.levels[self.parent] = self.uparg
    self.getparent = self.upvalmod:func("get0", {self.upvaltype}, {self.parent.upvaltype})
  end
end

function _f:compileUpvals ()
  -- Instructions created here will be put at the beggining
  local items = {}
  local types = {}
  local args = {}

  -- Insert instruction to a temporary array
  local oldcode = self.code
  self.code = {}

  if self.parent then
    local parent = self.parent
    local tp = parent.upvaltype
    table.insert(types, tp)
    table.insert(items, {name="0", tp=tp})
    table.insert(args, self.uparg)

    if parent.parent then
      self.levels[parent.parent] = self:call(parent.getparent, self.levels[parent])
      parent = parent.parent
    end
  end

  local nilreg = self:call(nil_f)
  for i = 1, self.upvals do
    local ix = i
    if not self.parent then ix = i-1 end
    table.insert(types, any_t)
    table.insert(items, {name=tostring(ix), tp=any_t})
    table.insert(args, nilreg)
  end

  self.upvalmod.argument.items = items
  local new_f = self.upvalmod:func("new", types, {self.upvaltype})

  self.levels[self].f = new_f
  self.levels[self].args = args

  -- Make space for new code
  table.move(oldcode, 1, #oldcode, #self.code+1, tmp)
  -- Insert new code at the beggining
  table.move(self.code, 1, #self.code, 1, oldcode)
  self.code = oldcode
end

function _f:get_local (name, upval)
  local lcl = self.locals[name]
  if lcl then
    if upval and not lcl.level then
      lcl.level = self

      local ix = self.upvals
      if self.parent then ix = ix+1 end

      lcl.get = self.upvalmod:func("get"..ix, {self.upvaltype}, {any_t})
      lcl.set = self.upvalmod:func("set"..ix, {self.upvaltype, any_t}, {})
      
      self.upvals = self.upvals+1
    end
    return lcl
  end

  if self.parent then
    return self.parent:get_local(name, true)
  end
end

function _f:createFunction (node)
  local fn = code("function")
  fn.node = node
  fn.parent = self
  fn.ins = {stack_t.id, self.upvaltype.id}
  fn.outs = {stack_t.id}

  -- First two registers are the arguments to the function
  local vararg = fn:reg() -- First the argument stack
  local uparg = fn:reg() -- Second the upvalue tuple (currently not supported, always nil)

  fn.locals["..."] = vararg
  fn.uparg = uparg

  fn:initUpvals()

  -- Extract the named arguments and self
  if node.method then
    fn.locals["self"] = fn:call(next_f, vararg)
  end

  for i, argname in ipairs(node.names) do
    fn.locals[argname] = fn:call(next_f, vararg)
  end

  -- Main code
  fn:compileBlock(node.body)

  if node.body[#node.body].type ~= "return" then
    local stackreg = fn:call(stack_f) 
    fn:inst{"end", stackreg}
  end

  fn:compileUpvals()

  -- Create and use the closure and function items
  local argmod = module()
  argmod.items = {{name="0", fn=fn}}

  local mod = module()
  mod.type = "build"
  mod.base = closure_m
  mod.argument = argmod

  local fn_new = mod:func("new", {self.upvaltype}, {func_t})

  -- Generate code in current function to create a runtime closure
  local raw = self:call(fn_new, self.levels[self])
  return self:call(func_f, raw)
end

function _f:compileExpr (node)
  local tp = node.type
  if tp == "const" then
    local f
    if node.value == "nil" then f = nil_f
    elseif node.value == "true" then f = true_f
    elseif node.value == "false" then f = false_f
    end
    return self:call(f)
  elseif tp == "num" then
    local n = tonumber(node.value)
    local raw = constant("int", n)
    local cns = constcall(int_f, raw)
    return self:call(cns)
  elseif tp == "str" then
    local raw = constant("bin", node.value)
    local str = constcall(newstr_f, raw)
    local cns = constcall(str_f, str)
    return self:call(cns)
  elseif tp == "var" then
    local lcl = self:get_local(node.name)
    if lcl then
      return self:inst{"var", lcl}
    else
      if not self.locals["_ENV"] then
        err("local \"_ENV\" not in sight", node)
      end
      err("global values not supported", node)
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
    local reg = self:call(table_f)
    for i, item in ipairs(node.items) do
      if item.type == "indexitem" then
        local key = self:compileExpr(item.key)
        local value = self:compileExpr(item.value)
        self:call(set_f, reg, key, value)
      elseif item.type == "fielditem" then
        local key = self:compileExpr{type="str",value=item.key}
        local value = self:compileExpr(item.value)
        self:call(set_f, reg, key, value)
      else err("Only index items are supported in constructors", node) end
    end
    return reg
  elseif tp == "call" then

    local args = self:call(stack_f)
    for i, v in ipairs(node.values) do
      local arg = self:compileExpr(v)
      self:call(push_f, args, arg)
    end

    local result
    if node.base.type == "var" and node.base.name == "print" then
      result = self:call(print_f, args)
    else
      local f_reg = self:compileExpr(node.base)
      result = self:call(call_f, f_reg, args)
    end

    return self:call(next_f, result)
  else err("expression " .. tp .. " not supported", node) end
end

function _f:compileStmt (node)
  local tp = node.type
  if tp == "local" then
    if (#node.names ~= #node.values) then
      err("different number of names and values is not supported", node)
    end
    for i = 1, #node.names do
      local reg = self:compileExpr(node.values[i])
      self.locals[node.names[i]] = self:inst{"init", reg}
    end
  elseif tp == "call" then self:compileExpr(node)
  elseif tp == "assignment" then
    local ltp = node.lhs[1].type
    if ltp == "var" then
      local lcl = self:get_local(node.lhs[1].name)
      if lcl then
        local right = self:compileExpr(node.values[1])
        self:inst{"set", lcl, right}
      else
        if not self.locals["_ENV"] then
          err("local \"_ENV\" not in sight", node)
        end
        err("global values not supported", node)
      end
    else err("unknown left hand side node " .. ltp, node) end
  else err("statement not supported: " .. tp, node) end
end

function _f:compileBlock (nodes)
  for i, node in ipairs(nodes) do
    self:compileStmt(node)
  end
end

--------------------------------------------------------------------------------
----                                Writing                                 ----
--------------------------------------------------------------------------------

do -- main function
  main_f = code("main")
  main_f:initUpvals()
  main_f:compileBlock(ast)
  main_f:compileUpvals()
  if ast[#ast].type ~= "return" then
    main_f:inst{"end"}
  end
end

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

outfile:write("Cobre 0.5\0")
wint(#modules+1) -- Count the export module, but not the argument module
wbyte(1, 1, 2) -- Export module is a module definition with 1 item, main
wint(main_f:id())
wstr("main")

for _, mod in ipairs(modules) do
  if mod.items then
    wbyte(1) -- define
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
    wbyte(0)
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

  -- Transform
  for i, inst in ipairs(fn.code) do
    if inst[1] == "var" then
      local reg = inst[2]
      if reg.level then
        inst[1] = "call"
        inst.f = reg.get
        inst.args = {fn.levels[reg.level]}
      else
        inst[1] = "dup"
      end
    elseif inst[1] == "set" then
      local reg = inst[2]
      if reg.level then
        inst[1] = "call"
        inst.f = reg.set
        inst.args = {fn.levels[reg.level], inst[3]}
      end
    elseif inst[1] == "init" then
      if inst.level then
        inst[1] = "call"
        inst.f = inst.set
        inst.args = {fn.levels[inst.level], inst[2]}
      else
        inst[1] = "dup"
      end
    end
  end

  local regs = #fn.regs

  wint(#fn.code)
  for i, inst in ipairs(fn.code) do
    local k = inst[1]
    if k == "end" then
      if #inst-1 ~= #fn.outs then
        error(fn.name .. " outputs " .. #fn.outs .. " results, but end instrucion has " .. #inst-1)
      end
      wbyte(0)
      for i=2, #inst do
        wint(inst[i].id)
      end
    elseif k == "dup" then
      wbyte(3) -- For now only locals
      wint(inst[2].id)
      inst.id, regs = regs, regs+1
    elseif k == "call" then
      local f = inst.f
      wint(f:id() + 16)
      if #inst.args ~= #f.ins then
        error(f.name .. " expects " .. #f.ins .. " arguments, but got " .. #inst.args)
      end
      for _, arg in ipairs(inst.args) do
        wint(arg.id)
      end
      if #f.outs > 0 then
        inst.id = regs
        regs = regs + #f.outs
      end
    else error("Unsupported instruction: " .. k) end
  end
end

-- Code
for _, fn in ipairs(funcs) do
  if fn.code then write_code(fn) end
end

wbyte(0) -- metadata

--print(tostr(funcs))
