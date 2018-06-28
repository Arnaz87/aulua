
require("helpers")
require("basics")

function Function:create_upval_info ()
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

function Function:build_upvals ()
  -- Here, after compiling the code, we know which locals are used in closure
  -- functions, so we can now describe the actual contents of the upval module
  -- and type. Check Function:create_upval_info for more information

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

function Function:get_vararg ()
  if self.vararg then return self.vararg
  else error("cannot use '...' outside a vararg function") end
end

function Function:get_local (name, as_upval)
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

function Function:get_level_ancestor (level)
  while self do
    if self.level == level then
      return self
    end
    self = self.parent
  end
  error("Could not find ancestor of level " .. level)
end

function Function:createFunction (node)
  local fn = code("function")
  fn.node = node
  fn.parent = self
  fn.level = self.level + 1
  fn.ins = {stack_t.id, self.upval_type.id}
  fn.outs = {stack_t.id}

  -- The first two registers are the two function arguments
  local args = {reg=0}
  if node.vararg then fn.vararg = args end
  fn.upval_arg = {reg=1}

  fn:create_upval_info()

  if node.method then
    table.insert(node.names, 1, "self")
  end

  for _, argname in ipairs(node.names) do
    local arg = fn:inst{next_f, args}
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

function Function:compile_require (node)
  -- Return if not a proper require
  if node.key
  or node.base.type ~= "var"
  or node.base.name ~= "require"
  or self:get_local("require")
  then return end

  if #node.values ~= 1 then
    error("lua:" .. node.line .. ": require expects exactly one argument")
  end

  if node.values[1].type ~= "str" then
    error("lua:" .. node.line .. ": module name can only be a string literal")
  end

  local mod = module(node.values[1].value)
  local fn = mod:func("lua_main", {any_t}, {stack_t})

  local env = self:get_local(".ENV")
  -- TODO: the modules are being executed everytime they are required, they
  -- should be executed once the first time and their first result should be
  -- saved in package.loaded for subsequent uses
  return self:inst{fn, env}
end

function Function:compile_call (node)
  local req = self:compile_require(node)
  if req then return req end

  local base = self:compileExpr(node.base)
  local f_reg = base
  if node.key then
    local key = self:compileExpr{type="str", value=node.key}
    f_reg = self:inst{get_f, base, key}
  end

  local args = self:call(stack_f)
  if node.key then
    self:inst{push_f, args, base}
  end
  for i, v in ipairs(node.values) do
    -- If the last argument is a function call,
    -- append its result stack to the argument
    local is_last = i == #node.values
    if is_last and v.type == "call" then
      local result = self:compile_call(v)
      self:inst{append_f, args, result}
    elseif is_last and v.type == "vararg" then
      self:inst{append_f, args, self:get_vararg()}
    else
      local arg = self:compileExpr(v)
      self:inst{push_f, args, arg}
    end
  end

  return self:inst{call_f, f_reg, args}
end

function Function:compileExpr (node)
  local tp = node.type
  if tp == "const" then
    local f
    if node.value == "nil" then f = nil_f
    elseif node.value == "true" then f = true_f
    elseif node.value == "false" then f = false_f
    end
    return self:inst{f}
  elseif tp == "num" then
    local cns = constant(tonumber(node.value))
    return self:inst{cns}
  elseif tp == "str" then
    local cns = constant(node.value)
    return self:inst{cns}
  elseif tp == "vararg" then
    return self:inst{first_f, self:get_vararg()}
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
  elseif tp == "unop" then
    local f = unops[node.op]
    local a = self:compileExpr(node.value)
    return self:call(f, a)
  elseif tp == "binop" then
    if node.op == "and" or node.op == "or" then
      local lbl = self:lbl()
      local a = self:compileExpr(node.left)
      local r = self:inst{"var", a}
      if node.op == "or" then
        self:inst{"jif", lbl, r}
      else
        self:inst{"nif", lbl, r}
      end
      local b = self:compileExpr(node.right)
      self:inst{"set", r, b}
      self:inst{"label", lbl}
      return r
    else
      local f = binops[node.op]
      local a = self:compileExpr(node.left)
      local b = self:compileExpr(node.right)
      return self:call(f, a, b)
    end
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
    local result = self:compile_call(node)
    return self:inst{first_f, result}
  else err("expression " .. tp .. " not supported", node) end
end

function Function:assign (vars, values)
  local last = math.max(#vars, #values)
  local stack

  for i = 1, last do
    local var, value, reg = vars[i], values[i]

    if i == #values then
      if value.type == "call" then
        stack = self:compile_call(value)
      elseif value.type == "vararg" then
        stack = self:inst{copystack_f, self:get_vararg()}
      end
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

function Function:compileLhs (node)
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

function Function:compile_numfor (node)
  -- TODO: Check that variables are numbers
  local start = self:lbl()
  local endl = self:lbl()
  local body = self:lbl()

  table.insert(self.loops, endl)
  self:push_scope()

  local var = self:inst{"local", self:compileExpr(node.init)}
  local limit = self:inst{"local", self:compileExpr(node.limit)}
  local step
  if node.step then
    step = self:compileExpr(node.step)
  else
    step = self:compileExpr{type="num", value="1"}
  end
  local step = self:inst{"local", step}

  self.scope.locals[node.name] = var

  local is_neg = self:inst{binops["<"], step, self:compileExpr{type="num", value="0"}}

  self:inst{"label", start}

  -- Jump to negative condition if step is negative
  local neg_lbl = self:lbl()
  self:inst{"jif", neg_lbl, is_neg}

  local cond = self:inst{binops[">"], var, limit}
  self:inst{"jif", endl, cond}
  self:inst{"jmp", body}

  -- Condition if step is negative
  self:inst{"label", neg_lbl}
  cond = self:inst{binops["<"], var, limit}
  self:inst{"jif", endl, cond}

  self:inst{"label", body}
  self:compileBlock(node.body)

  -- Increment var by step and repeat
  local inc = self:inst{binops["+"], var, step}
  self:inst{"set", var, inc}
  self:inst{"jmp", start}
  self:inst{"label", endl}

  self:pop_scope()
  table.remove(self.loops)
end

function Function:compile_genfor (node)
  local start = self:lbl()
  local endl = self:lbl()

  table.insert(self.loops, endl)
  self:push_scope()

  self:assign({
    {lcl=".f"}, {lcl=".s"}, {lcl=".var"}
  }, node.values)

  local next = self.scope.locals[".f"]
  local state = self.scope.locals[".s"]
  local var = self.scope.locals[".var"]

  self:inst{"label", start}

  local args = self:inst{stack_f}
  self:inst{push_f, args, state}
  self:inst{push_f, args, var}
  local results = self:inst{call_f, next, args}

  for i, name in ipairs(node.names) do
    local value = self:inst{next_f, results}
    self.scope.locals[name] = self:inst{"local", value}
    if i == 1 then self:inst{"set", var, value} end
  end

  local cond = self:inst{binops["=="], var, self:inst{nil_f}}
  self:inst{"jif", endl, cond}
  self:compileBlock(node.body)
  self:inst{"jmp", start}

  self:inst{"label", endl}
  self:pop_scope()
  table.remove(self.loops)
end

function Function:compileStmt (node)
  local tp = node.type
  if tp == "local" then
    local vars = {}
    for i, name in ipairs(node.names) do
      vars[i] = {lcl=name}
    end
    self:assign(vars, node.values)
  elseif tp == "call" then self:compile_call(node)
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
        local result = self:compile_call(v)
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
    self:compileBlock(node.body)
    local cond = self:compileExpr(node.cond)
    self:inst{"jif", start, cond}
    self:inst{"label", endl}

    self:pop_scope()
    table.remove(self.loops)
  elseif tp == "numfor" then
    self:compile_numfor(node)
  elseif tp == "genfor" then
    self:compile_genfor(node)
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

function Function:compileBlock (nodes)
  for i, node in ipairs(nodes) do
    self:compileStmt(node)
  end
end

function Function:transform ()
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
        self:inst{"dup", arg}
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

return function (ast)
  lua_main = code("lua_main")
  lua_main.ins = {any_t.id}
  lua_main.outs = {stack_t.id}
  lua_main.level = 1

  lua_main:create_upval_info()
  lua_main.scope.locals["_ENV"] = lua_main:inst{"local", {reg=0}}
  -- true ENV, cannot be assigned because a lua identifier with a point is not
  -- valid. To be used when requiring
  lua_main.scope.locals[".ENV"] = lua_main:inst{"local", {reg=0}}

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

