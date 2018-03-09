
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
  {type="local", names={"a", "b", "c"}, line=1, column=1, values={
    {type="num", value="1", line=1, column=13},
    {type="var", name="a", line=1, column=15},
    {type="str", value="foo", line=1, column=17},
    {type="const", value="true", line=1, column=23},
    {type="const", value="false", line=1, column=28},
    {type="const", value="nil", line=1, column=34},
  }}
})

test("do local a, b end", {
  {type="do", line=1, column=1, body={
    {type="local", line=1, column=4, names={"a", "b"}, values={}}
  }}
})

test("do do end end", {
  {type="do", line=1, column=1, body={
    {type="do", line=1, column=4, body={}}
  }}
})

test("while a>b do break end", {
  {type="while", line=1, column=1, cond={
    type="binop", line=1, column=8, op=">",
    left={type="var", name="a", line=1, column=7},
    right={type="var", name="b", line=1, column=9}
  }, body={ {type="break", line=1, column=14} }}
})


test("repeat return until 0", {
  {type="repeat", line=1, column=1,
    cond={type="num", value="0", line=1, column=21},
    body={ {type="return", line=1, column=8, values={}} }
  }
})

test("::a:: goto a return", {
  {type="label", name="a", line=1, column=1},
  {type="goto", name="a", line=1, column=7},
  {type="return", values={}, line=1, column=14}
})

test("if true then local a elseif 2 then local b end", {
  {type="if", line=1, column=1,
    clauses={
      {
        type="clause", cond={
          type="const", value="true", line=1, column=4
        }, body={
          {type="local", names={"a"}, values={}, line=1, column=14}
        }
      },
      {type="clause", cond={type="num", value="2", line=1, column=29}, body={
        {type="local", names={"b"}, values={}, line=1, column=36}
      }}
    },
    els={}
  }
})

test("if 1 then elseif 2 then else local a end", {
  {type="if", line=1, column=1,
    clauses={
      {type="clause", cond={type="num", value="1", line=1, column=4}, body={}},
      {type="clause", cond={type="num", value="2", line=1, column=18}, body={}}
    },
    els={
      {type="local", names={"a"}, values={}, line=1, column=30}
    }
  }
})

test("for a = 1, 2, 3 do end", {{type="numfor", name="a", line=1, column=1,
  init={type="num", value="1", line=1, column=9},
  limit={type="num", value="2", line=1, column=12},
  step={type="num", value="3", line=1, column=15},
  body={},
}})

test("for a in b do break end", {{
  type="genfor", names={"a"}, line=1, column=1,
  values={ {type="var", name="b", line=1, column=10} },
  body={ {type="break", line=1, column=15} }
}})


test("local function a(p) end", {{
  type="localfunc", name="a", line=1, column=1, body={
    type="function", names={"p"}, vararg=false, body={}
  }
}})

test("function a() end", {{
  type="funcstat", method=false, line=1, column=1,
  lhs={type="var", name="a", line=1, column=10}, body={
    type="function", names={}, vararg=false, body={}
  }
}})

test("function a.b:c() end", {{
  type="funcstat", method=true, line=1, column=1, lhs={
    type="field", key="c", line=1, column=14, base={
      type="field", key="b", line=1, column=12, base={
        type="var", name="a", line=1, column=10
      }
    }
  }, body={type="function", names={}, vararg=false, body={}}
}})

test("a, b.c, d[0] = 1,2,...", {{
  type="assignment", line=1, column=1, lhs={
    {type="var", name="a", line=1, column=1},
    {type="field", key="c", line=1, column=6,
      base={type="var", name="b", line=1, column=4}
    },
    {type="index", line=1, column=11,
      key={type="num", value="0", line=1, column=11},
      base={type="var", name="d", line=1, column=9}
    },
  }, values={
    {type="num", value="1", line=1, column=16},
    {type="num", value="2", line=1, column=18},
    {type="vararg", line=1, column=20},
  }
}})

test("b.c[d]:e(3,...)", {
  {type="call", key="e", line=1, column=8,
    values={
      {type="num", value="3", line=1, column=10},
      {type="vararg", line=1, column=12}
    },
    base={type="index", line=1, column=5,
      key={type="var", name="d", line=1, column=5},
      base={type="field", key="c", line=1, column=3,
        base={type="var", name="b", line=1, column=1}
      }
    }
  }
})

test("a{}'foo'", {
  { type="call", line=1, column=1,
    values={{type="str", value="foo", line=1, column=4}},
    base={type="call", line=1, column=1,
      values={ {type="constructor", items={}, line=1, column=2} },
      base={type="var", name="a", line=1, column=1}
    }
  }
})

test("(a+b):c()", {
  { type="call", key="c", line=1, column=7,
    values={},
    base={type="binop", op="+", line=1, column=3,
      left={type="var", name="a", line=1, column=2},
      right={type="var", name="b", line=1, column=4}
    }
  }
})

test("f(function(a,b,c,...) return c,b,a,... end)", {
  {type="call", base={type="var", name="f", line=1, column=1}, line=1, column=1, values={
    {
      type="function", names={"a", "b", "c"},
      vararg=true, line=1, column=3,
      body={
        {type="return", line=1, column=23, values={
          {type="var", name="c", line=1, column=30},
          {type="var", name="b", line=1, column=32},
          {type="var", name="a", line=1, column=34},
          {type="vararg", line=1, column=36},
        }}
      }
    }
  }}
})

-- WTF!
test("a = 1 + 2 - 3 * 4 / 5 % 6 ^ 7", {
  {type="assignment", line=1, column=1, 
    lhs={{type="var", name="a", line=1, column=1}},
    values={{type="binop", op="-", line=1, column=11,
      left={type="binop", op="+", line=1, column=7,
        left={type="num", value="1", line=1, column=5},
        right={type="num", value="2", line=1, column=9}},
      right={type="binop", op="%", line=1, column=23,
        left={type="binop", op="/", line=1, column=19,
          left={type="binop", op="*", line=1, column=15,
            left={type="num", value="3", line=1, column=13},
            right={type="num", value="4", line=1, column=17}},
          right={type="num", value="5", line=1, column=21}},
        right={type="binop", op="^", line=1, column=27,
          left={type="num", value="6", line=1, column=25},
          right={type="num", value="7", line=1, column=29}},
      }
    }}
  }
})

test("local a = function() end == function() end", {
  {type="local", names={"a"}, line=1, column=1, values={
    {type="binop", op="==", line=1, column=26,
      left={type="function", names={}, vararg=false, body={}, line=1, column=11},
      right={type="function", names={}, vararg=false, body={}, line=1, column=29}
    }
  }}
})

test("local a = {{},{},{{}},}", {
  {type="local", names={"a"}, line=1, column=1, 
    values={
      {type="constructor", line=1, column=11, items={
        {type="item", value={type="constructor", items={}, line=1, column=12}},
        {type="item", value={type="constructor", items={}, line=1, column=15}},
        {type="item",
          value={type="constructor", line=1, column=18, items={
            {type="item", value={type="constructor", items={}, line=1, column=19}}
          }}
        },
      }}
    }
  }
})

test("local a = { a or b, c=1; ['foo']='bar', }", {
  {type="local", names={"a"}, line=1, column=1, 
    values={
      {type="constructor", line=1, column=11, items={
        {type="item", value={
          type="binop", op="or", line=1, column=15,
            left={type="var", name="a", line=1, column=13},
            right={type="var", name="b", line=1, column=18}
          }
        },
        {type="fielditem", key="c", value={type="num", value="1", line=1, column=23}},
        {type="indexitem",
          key={type="str", value="foo", line=1, column=27},
          value={type="str", value="bar", line=1, column=34}
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
    type="funcstat", method=false, line=1, column=1,
    lhs={type="var", name="add", line=1, column=10},
    body={
      type="function", vararg=false,
      names={"a", "b"},
      body={
        {
          type="local", line=2, column=3,
          names={"r"},
          values={
            {
              type="binop", op="+", line=2, column=14,
              left={type="var", name="a", line=2, column=13},
              right={type="var", name="b", line=2, column=15}
            }
          }
        }, {
          type="call", line=3, column=3,
          base={type="var", name="print", line=3, column=3},
          values={
            {type="var", name="r", line=3, column=9}
          }
        }, {
          type="return", line=4, column=3,
          values={
            {type="var", name="r", line=4, column=10}
          }
        }
      }
    }
  }, {
    type="call", line=7, column=1,
    base={type="var", name="add", line=7, column=1},
    values={
      {
        type="binop", op="+", line=7, column=6,
        left={type="num", value="1", line=7, column=5},
        right={type="num", value="2", line=7, column=7}
      }, {
        type="num", value="3", line=7, column=10
      }
    }
  }
})

return Parser, test