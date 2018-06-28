
modules = {}
types = {}
funcs = {}

Module = {}
Module.__index = Module

function Module:type (name)
  local t = {id=#types, name=name, module=self.id}
  table.insert(types, t)
  setmetatable(t, {
    __tostring = function (f)
      return self:fullname() .. "." .. name
    end
  })
  return t
end

function Module:func (name, ins, outs)
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

function Module:fullname ()
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
  setmetatable(m, Module)
  table.insert(modules, m)
  return m
end

Function = {}
Function.__index = Function
function Function:id () return self._id end
function Function:reg ()
  local r = {id=#self.regs}
  table.insert(self.regs, r)
  setmetatable(r, {
    __tostring = function (slf) return "reg_" .. slf.id end
  })
  return r
end
function Function:inst (data)
  setmetatable(data, {
    __tostring = function (self)
    if self.reg then return "reg_" .. self.reg
      else return tostring(self.inst) end
    end
  })
  table.insert(self.code, data)
  return data
end
function Function:lbl ()
  local l = self.label_count + 1
  self.label_count = l
  return l
end
function Function:call (...)
  return self:inst{...}
end
function Function:push_scope ()
  self.scope = { locals={}, labels={} }
  table.insert(self.scopes, self.scope)
end
function Function:pop_scope ()
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
  setmetatable(f, Function)
  table.insert(funcs, f)
  f:push_scope()
  return f
end
function Function:__tostring ()
  return ":lua:" .. (self.name or "")
end

constants = {}

function raw_const (tp, value)
  local data = {_id=#constants, type=tp, value=value, ins={}, outs={0}}
  function data:id () return self._id + #funcs end
  table.insert(constants, data)
  setmetatable(data, {
    __tostring = function (self) return "cns_" .. self:id() end
  })
  return data
end

function const_call (f, ...)
  local data = raw_const("call")
  data.f = f
  data.args = table.pack(...)
  return data
end

constant_cache = {}
function constant (value)
  local cns = constant_cache[value]
  if cns then return cns end
  if type(value) == "string" then
    local raw = raw_const("bin", value)
    local str = const_call(rawstr_f, raw)
    cns = const_call(anystr_f, str)
  elseif type(value) == "number" then
    local raw = raw_const("int", value)
    cns = const_call(anyint_f, raw)
  end
  constant_cache[value] = cns
  return cns
end

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

rawstr_f = str_m:func("new", {bin_t}, {string_t})
anyint_f = lua_m:func("int", {int_t}, {any_t})
anystr_f = lua_m:func("string", {string_t}, {any_t})

nil_f = lua_m:func("nil", {}, {any_t})
true_f = lua_m:func("true", {}, {any_t})
false_f = lua_m:func("false", {}, {any_t})
bool_f = lua_m:func("tobool", {any_t}, {bool_t})
func_f = lua_m:func("function", {func_t}, {any_t})
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

unops = {
  ["not"] = lua_m:func("not", {any_t}, {any_t}),
  ["-"] = lua_m:func("neg", {any_t}, {any_t}),
  ["#"] = lua_m:func("length", {any_t}, {any_t}),
}
