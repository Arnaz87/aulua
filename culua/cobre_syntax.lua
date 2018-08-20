

function Function:compile_cu_call (node, base)
  local tp = base.cu_type

  function get_any_module_of (tp)
    if not tp.any_module then
      local arg = module()
      arg.items = {{name="0", tp=tp}}
      tp.any_module = module()
      tp.any_module.base = any_m
      tp.any_module.argument = arg
    end
    return tp.any_module
  end

  if tp == "import" then
    if base.key then err("attempt to index '" .. node.key .. "' on _CU_IMPORT", node) end
    local names = {}
    if #node.values < 1 then err("bad argument #1 for _CU_IMPORT (string literal expected)", node) end
    for i, v in ipairs(node.values) do
      if v.type ~= "str" then
        err("bad argument #" .. i .. " for _CU_IMPORT (string literal expected)", node)
      end
      table.insert(names, v.value)
    end
    local mod = module(table.concat(names, "\x1f"))
    return {cu_type="module", module_id=mod.id}
  elseif tp == "module" then

    -- lua tables are 1-indexed, but cobre module ids start at 2 because 0
    -- and 1 are reserved, so I have to subtract 1
    local mod = modules[base.module_id-1]

    if not node.key then err("attempt to call a cobre module", node)

    elseif node.key == "get_type" then
      if #node.values ~= 1 or node.values[1].type ~= "str" then
        err("bad arguments for get_type (string literal expected)", node)
      end
      local tp = mod:type(node.values[1].value)
      return {cu_type="type", type_id=tp.id}

    elseif node.key == "get_function" then

      function create_type_list (index)
        local const = node.values[index]
        if const.type ~= "constructor" then
          err("bad argument #"..index.." for get_function (table constructor expected)", node)
        end

        local list = {}

        for i, item in ipairs(const.items) do
          if item.type ~= "item" then
            err("bad argument #"..index.." for get_function (field keys are not allowed)", node)
          end
          local value = self:compileExpr(item.value, true)
          if value.cu_type ~= "type" then
            err("bad argument #"..index.." for get_function (cobre type expected at field #"..i..")", node)
          end

          table.insert(list, types[value.type_id+1])
        end

        return list
      end

      if #node.values ~= 3 then err("bad arguments for get_function (3 arguments expected)", node) end

      if node.values[1].type ~= "str" then
        err("bad argument #1 for get_function (string literal expected)", node)
      end

      local name = node.values[1].value
      local ins = create_type_list(2)
      local outs = create_type_list(3)

      local fn = mod:func(name, ins, outs)
      return {cu_type="function", function_id=fn:id()}

    else err("attempt to index '" .. node.key .. "' on a cobre module", node)
    end

  elseif tp == "type" then
    local tp = types[base.type_id+1]
    
    if not node.key then

      if #node.values ~= 1 then
        err("bad arguments for cobre type (one argument expected)", node)
      end

      if not tp.from_any then
        local mod = get_any_module_of(tp)
        tp.from_any = mod:func("get", {any_t}, {tp})
      end

      local value = self:compileExpr(node.values[1])
      local reg = self:inst{tp.from_any, value}
      reg.cu_type = "value"
      reg.type_id = tp.id
      return reg

    elseif node.key == "test" then

      if not tp.test_any then
        local mod = get_any_module_of(tp)
        tp.test_any = mod:func("test", {any_t}, {bool_t})
      end

      if not from_bool_f then
        local mod = get_any_module_of(bool_t)
        from_bool_f = mod:func("new", {bool_t}, {any_t})
      end

      local value = self:compileExpr(node.values[1])
      local r = self:inst{tp.test_any, value}
      return self:inst{from_bool_f, r}

    else err("attempt to index '" .. node.key .. "' on a cobre type", node) end

  elseif tp == "value" then
    local tp = types[base.type_id+1]

    if not node.key then err("attempt to call a cobre value", node)
    elseif node.key == "to_lua_value" then
      if #node.values > 0 then
        err("bad arguments for to_lua_value (no arguments expected)", node)
      end

      if not tp.to_any then
        local mod = get_any_module_of(tp)
        tp.to_any = mod:func("new", {tp}, {any_t})
      end

      return self:inst{tp.to_any, base}

    else err("attempt to index '" .. node.key .. "' on a cobre value", node) end

  elseif tp == "function" then
    if node.key then err("attempt to index '" .. node.key .. "' on a cobre function", node) end
    local fn = funcs[base.function_id+1]

    if #node.values ~= #fn.ins then
      err("bad arguments for cobre type (" .. #fn.ins .. " arguments expected)", node)
    end

    local inst = {fn, cu_type="result", regs={}}
    for i, v in ipairs(node.values) do
      local value = self:compileExpr(v, true)

      local bad_name
      if not value.cu_type then
        bad_name = "lua value"
      elseif value.cu_type ~= "value" then
        bad_name = value.cu_type
      elseif value.type_id ~= fn.ins[i] then
        bad_name = types[value.type_id+1].name
      end

      if bad_name then
        local good_name = types[fn.ins[i]+1].name
        err("bad argument #"..i.." for " .. fn.name .. " (" .. good_name .. " expected but got " .. bad_name .. ")", node)
      end

      table.insert(inst, value)
    end

    for i, tp_id in ipairs(fn.outs) do
      inst.regs[i] = {cu_type="value", type_id=tp_id}
    end

    return self:inst(inst)
  end

  err("unknown cu_type " .. tp, node)
end