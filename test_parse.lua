
local Parser = require("parser")


local function tostr (obj)
  if type(obj) ~= "table" then
    return tostring(obj) end

  if #obj > 0 then
    local str = "["
    for i = 1, #obj do
      if i > 1 then str = str .. ", " end
      str = str .. tostr(obj[i])
    end
    return str .. "]"
  end

  local first = true
  local str = "{"
  for k, v in pairs(obj) do
    if k ~= "type" then
      if first then first = false
      else str = str .. ", " end
      str = str .. k .. "=" .. tostr(v)
    end
  end

  local tp = (obj.type or ""):upper()
  if tp ~= "" and str == "{" then
    return tp
  else
    return tp .. str .. "}"
  end
end

local function eq (t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table"
    then return t1 == t2 end

  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if not eq(v1,v2) then
      return false end
  end

  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if not eq(v1,v2) then
      return false end
  end

  return true
end

local function FAIL (line, msg)
  print("\x1b[1;31m[FAIL]\x1b[0;39m", line, "\x1b[31m" .. msg .. "\x1b[39m")
end

local function PASS (line, msg)
  print("\x1b[1;32m[PASS]\x1b[0;39m", line, "\x1b[1;30m" .. msg .. "\x1b[0;39m")
end






local loud = false
local showtrace = false

for line in io.lines("test_parse.txt") do
  if line:find("LOUD") ~= nil then loud = true end
  if line:find("QUIT") ~= nil then break end

  local fail = line:find("FAIL") ~= nil

  Parser.open(line)
  local parsed = Parser.parse()

  if fail then
    if parsed then
      FAIL(line, tostr(parsed))
    elseif loud then
      PASS(line, Parser.error)
    end
  else
    if not parsed then
      FAIL(line, Parser.error)
      if showtrace then print(Parser.trace) end
    elseif loud then
      PASS(line, tostr(parsed))
    end
  end
end






loud = false

local function test (str, expected)
  Parser.open(str)
  local node = Parser.parse()
  if eq(node, expected) then
    if loud then
      PASS(str, tostr(node))
    end
  else
    local msg = "Incorrect AST"
    if Parser.error then msg = Parser.error end
    FAIL(str, msg)
    if not Parser.error then
      print("\t[NEED]", tostr(expected))
      print("\t[GOT]", tostr(node))
    end
  end
end




test("local a,b,c=1,a,'foo',true,false,nil", {
  {type="local", names={"a", "b", "c"}, values={
    {type="num", value="1"},
    {type="var", name="a"},
    {type="str", value="foo"},
    {type="const", value="true"},
    {type="const", value="false"},
    {type="const", value="nil"},
  }}
})

test("do local a, b end", {
  {type="do", body={
    {type="local", names={"a", "b"}, values={}}
  }}
})

test("do do end end", {
  {type="do", body={
    {type="do", body={}}
  }}
})

test("while a>b do break end", {
  {type="while", cond={
    type="binop",
    op=">",
    left={type="var", name="a"},
    right={type="var", name="b"}
  }, body={ {type="break"} }}
})


test("repeat return until 0", {
  {type="repeat",
    cond={type="num", value="0"},
    body={ {type="return", values={}} }
  }
})

test("::a:: goto a return", {
  {type="label", name="a"},
  {type="goto", name="a"},
  {type="return", values={}}
})

test("if true then local a elseif 2 then local b end", {
  {type="if",
    clauses={
      {type="clause", cond={type="const", value="true"}, body={
        {type="local", names={"a"}, values={}}
      }},
      {type="clause", cond={type="num", value="2"}, body={
        {type="local", names={"b"}, values={}}
      }}
    },
    els={}
  }
})

test("if 1 then elseif 2 then else local a end", {
  {type="if",
    clauses={
      {type="clause", cond={type="num", value="1"}, body={}},
      {type="clause", cond={type="num", value="2"}, body={}}
    },
    els={
      {type="local", names={"a"}, values={}}
    }
  }
})

test("for a = 1, 2, 3 do end", {{type="numfor", name="a",
  init={type="num", value="1"},
  limit={type="num", value="2"},
  step={type="num", value="3"},
  body={},
}})

test("for a in b do break end", {{
  type="genfor", names={"a"},
  values={ {type="var", name="b"} },
  body={ {type="break"} }
}})


test("local function a(p) end", {{
  type="localfunc", name="a", body={
    type="function", names={"p"}, vararg=false, body={}
  }
}})

test("function a() end", {{
  type="funcstat", lhs={type="var", name="a"}, method=false, body={
    type="function", names={}, vararg=false, body={}
  }
}})

test("function a.b:c() end", {{
  type="funcstat", method=true, lhs={
    type="field", key="c", base={
      type="field", key="b", base={
        type="var", name="a"
      }
    }
  }, body={type="function", names={}, vararg=false, body={}}
}})

test("a, b.c, d[0] = 1,2,...", {{
  type="assignment", lhs={
    {type="var", name="a"},
    {type="field", key="c",
      base={type="var", name="b"}
    },
    {type="index",
      key={type="num", value="0"},
      base={type="var", name="d"}
    },
  }, values={
    {type="num", value="1"},
    {type="num", value="2"},
    {type="vararg"},
  }
}})

test("b.c[d]:e(3,...)", {
  {type="call", key="e",
    values={{type="num", value="3"}, {type="vararg"}},
    base={type="index", key={type="var", name="d"},
      base={type="field", key="c",
        base={type="var", name="b"}
      }
    }
  }
})

test("a{}'foo'", {
  { type="call",
    values={{type="str", value="foo"}},
    base={type="call",
      values={ {type="constructor", items={}} },
      base={type="var", name="a"}
    }
  }
})

test("(a+b):c()", {
  { type="call", key="c",
    values={},
    base={type="binop", op="+",
      left={type="var", name="a"},
      right={type="var", name="b"}
    }
  }
})

test("f(function(a,b,c,...) return c,b,a,... end)", {
  {type="call", base={type="var", name="f"}, values={
    {type="function", names={"a", "b", "c"}, vararg=true, body={
      {type="return", values={
        {type="var", name="c"},
        {type="var", name="b"},
        {type="var", name="a"},
        {type="vararg"},
      }}
    }}
  }}
})


test("f(function(a,b,c,...) return c,b,a,... end)", {
  {type="call", base={type="var", name="f"}, values={
    {type="function", names={"a", "b", "c"}, vararg=true, body={
      {type="return", values={
        {type="var", name="c"},
        {type="var", name="b"},
        {type="var", name="a"},
        {type="vararg"},
      }}
    }}
  }}
})

-- WTF!
test("a = 1 + 2 - 3 * 4 / 5 % 6 ^ 7", {
  {type="assignment", lhs={{type="var", name="a"}}, 
    values={{type="binop", op="-",
      left={type="binop", op="+",
        left={type="num", value="1"},
        right={type="num", value="2"}},
      right={type="binop", op="%",
        left={type="binop", op="/",
          left={type="binop", op="*",
            left={type="num", value="3"},
            right={type="num", value="4"}},
          right={type="num", value="5"}},
        right={type="binop", op="^",
          left={type="num", value="6"},
          right={type="num", value="7"}},
      }
    }}
  }
})

test("local a = function() end == function() end", {
  {type="local", names={"a"}, values={
    {type="binop", op="==",
      left={type="function", names={}, vararg=false, body={}},
      right={type="function", names={}, vararg=false, body={}}
    }
  }}
})

test("local a = {{},{},{{}},}", {
  {type="local", names={"a"}, 
    values={
      {type="constructor", items={
        {type="item", value={type="constructor", items={}}},
        {type="item", value={type="constructor", items={}}},
        {type="item",
          value={type="constructor", items={
            {type="item", value={type="constructor", items={}}}
          }}
        },
      }}
    }
  }
})

test("local a = { a or b, c=1; ['foo']='bar', }", {
  {type="local", names={"a"}, 
    values={
      {type="constructor", items={
        {type="item", value={
          type="binop", op="or",
            left={type="var", name="a"},
            right={type="var", name="b"}
          }
        },
        {type="fielditem", key="c", value={type="num", value="1"}},
        {type="indexitem",
          key={type="str", value="foo"},
          value={type="str", value="bar"}
        },
      }}
    }
  }
})

-- Example in the readme
test([[
function add (a, b)
  local r = a+b
  print(r)
  return r
end

add(1+2, 3)
]], {
  {
    type="funcstat", method=false,
    lhs={type="var", name="add"},
    body={
      type="function", vararg=false,
      names={"a", "b"},
      body={
        {
          type="local",
          names={"r"},
          values={
            {
              type="binop", op="+",
              left={type="var", name="a"},
              right={type="var", name="b"}
            }
          }
        }, {
          type="call",
          base={type="var", name="print"},
          values={
            {type="var", name="r"}
          }
        }, {
          type="return",
          values={
            {type="var", name="r"}
          }
        }
      }
    }
  }, {
    type="call",
    base={type="var", name="add"},
    values={
      {
        type="binop", op="+",
        left={type="num", value="1"},
        right={type="num", value="2"}
      }, {
        type="num", value="3"
      }
    }
  }
})

return Parser, test