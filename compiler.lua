
-- Lua magic to not pollute the global namespace
_ENV = setmetatable({}, {__index = _ENV})

Parser = require("parser")

file = io.open("test.lua", "r")
contents = file:read("a")
Parser.open(contents)
ast = Parser.parse()
if not ast then print("Error: " .. Parser.error) os.exit(1) end

function tostr (obj, pre)
  pre = pre or ""
  if type(obj) ~= "table" then
    return tostring(obj) end

  if #obj > 0 then
    local str = "["
    for i = 1, #obj do
      if i > 1 then str = str .. ", " end
      str = str .. tostr(obj[i], pre)
    end
    return str .. "]"
  end

  local first = true
  local str = "{"
  for k, v in pairs(obj) do
    if first then first = false
    else str = str .. "," end
    str = str .. "\n" .. pre .. "  " .. k .. " = " .. tostr(v, pre .. "  ")
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

core_m = module("cobre.core")
int_m = module("cobre.int")
str_m = module("cobre.string")
lua_m = module("lua")
closure_m = module("closure")
closure_m.from = lua_m

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

function _f:createFunction (node)
  local fn = code("function")
  fn.node = node
  fn.parent = self
  fn.ins = {stack_t.id, any_t.id}
  fn.outs = {stack_t.id}

  -- First two registers are the arguments to the function
  local vararg = fn:reg() -- First the argument stack
  local upvals = fn:reg() -- Second the upvalues (currently not supported nil)

  fn.locals["..."] = vararg
  fn.upvalreg = upvals

  -- Extract the named arguments and self
  if node.method then
    local reg = fn:reg()
    fn:inst{"call", next_f, vararg}
    fn.locals["self"] = reg
  end

  for i, argname in ipairs(node.names) do
    local reg = fn:reg()
    fn:inst{"call", next_f, vararg}
    fn.locals[argname] = reg
  end

  fn:compileBlock(node.body)

  local stackreg = fn:reg()
  fn:inst{"call", stack_f}
  fn:inst{"end", stackreg}

  local argmod = module()
  argmod.items = {{name="0", fn=fn}}

  local mod = module()
  mod.type = "build"
  mod.base = closure_m
  mod.argument = argmod

  local fn_new = mod:func("new", {any_t}, {func_t})

  local upvals = self:reg()
  self:inst{"call", nil_f}
  local raw = self:reg()
  self:inst{"call", fn_new, upvals}
  local reg = self:reg()
  self:inst{"call", func_f, raw}
  return reg
end

function _f:compileExpr (node)
  local tp = node.type
  if tp == "const" then
    local reg = self:reg()
    local f
    if node.value == "nil" then f = nil_f
    elseif node.value == "true" then f = true_f
    elseif node.value == "false" then f = false_f
    end
    self:inst{"call", f}
    return reg
  elseif tp == "num" then
    local n = tonumber(node.value)
    local raw = constant("int", n)
    local cns = constcall(int_f, raw)
    local reg = self:reg()
    self:inst{"call", cns}
    return reg
  elseif tp == "str" then
    local raw = constant("bin", node.value)
    local str = constcall(newstr_f, raw)
    local cns = constcall(str_f, str)
    local reg = self:reg()
    self:inst{"call", cns}
    return reg
  elseif tp == "var" then
    local lcl = self.locals[node.name]
    if lcl then
      local reg = self:reg()
      self:inst{"var", lcl}
      return reg
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
    local reg = self:reg()
    self:inst{"call", f, a, b}
    return reg
  elseif tp == "index" then
    local base = self:compileExpr(node.base)
    local key = self:compileExpr(node.key)
    local reg = self:reg()
    self:inst{"call", get_f, base, key}
    return reg
  elseif tp == "field" then
    local key = {type="str", value=node.key}
    return self:compileExpr{type="index", base=node.base, key=key}
  elseif tp == "function" then
    return self:createFunction(node)
  elseif tp == "constructor" then
    local reg = self:reg()
    self:inst{"call", table_f}
    for i, item in ipairs(node.items) do
      if item.type == "indexitem" then
        local key = self:compileExpr(item.key)
        local value = self:compileExpr(item.value)
        self:inst{"call", set_f, reg, key, value}
      elseif item.type == "fielditem" then
        local key = self:compileExpr{type="str",value=item.key}
        local value = self:compileExpr(item.value)
        self:inst{"call", set_f, reg, key, value}
      else err("Only index items are supported in constructors", node) end
    end
    return reg
  elseif tp == "call" then

    local args = self:reg()
    self:inst{"call", stack_f}
    for i, v in ipairs(node.values) do
      local arg = self:compileExpr(v)
      self:inst{"call", push_f, args, arg}
    end

    local result
    if node.base.type == "var" and node.base.name == "print" then
      result = self:reg()
      self:inst{"call", print_f, args}
    else
      local f_reg = self:compileExpr(node.base)
      result = self:reg()
      self:inst{"call", call_f, f_reg, args}
    end

    local reg = self:reg()
    self:inst{"call", next_f, result}
    return reg
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
      self.locals[node.names[i]] = reg
    end
  elseif tp == "call" then self:compileExpr(node)
  else err("statement not supported: " .. tp, node) end
end

function _f:compileBlock (nodes)
  for i, node in ipairs(nodes) do
    self:compileStmt(node)
  end
end

main_f = code("main")
main_f:compileBlock(ast)
main_f:inst{"end"}

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
    wbyte(1)
    wint(#mod.items)
    for _, item in ipairs(mod.items) do
      if item.fn then
        wbyte(2)
        wint(item.fn:id())
      else err("Unknown item kind " .. v.type) end
      wstr(item.name)
    end
  elseif mod.base and mod.argument then
    wbyte(4)
    wint(mod.base.id)
    wint(mod.argument.id)
  elseif mod.from then
    wbyte(3)
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
  else print("???") end
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
    elseif k == "var" then
      -- Special instruction, the actual cobre instructions emited depends
      -- on wether the name is a local value or an upvalue.
      -- The sequence of instructions emited MUST USE EXACTLY ONE register
      wbyte(3) -- For now only locals
      wint(inst[2].id)
    elseif k == "call" then
      local f = inst[2]
      wint(f:id() + 16)
      if #inst-2 ~= #f.ins then
        error(f.name .. " expects " .. #f.ins .. " arguments, but got " .. #inst-2)
      end
      for i = 3, #inst do
        wint(inst[i].id)
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
