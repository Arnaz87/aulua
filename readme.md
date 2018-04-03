# Lua cobre compiler

Compiles **Lua 5.3** code to the [Cobre VM](https://github.com/Arnaz87/cobrevm). Written in Lua. It is not yet able to compile itself.

**Lisence**: This is free software, published under the
  [WTFPL](http://www.wtfpl.net/)

# Usage

First you need to compile the Cobre library with [Culang](https://github.com/Arnaz87/culang), run `cobre culang lua.cu lua` and optionally `cobre --install lua`. Then, run `lua compiler.lua ` which currently inputs *test.lua* and outputs *out*, which is a cobre module, run with `cobre out`.

# Parser

The parser can be used independently from the compiler. My main references for it were:

- [The original Lua](https://www.lua.org/source/5.3/)
- [Yueliang](http://yueliang.luaforge.net/)
- [LuaMinify](https://github.com/stravant/LuaMinify)

To use it, copy *lexer.lua* and *parser.lua* into your source directory.

~~~ lua
local Parser = require("parser")

-- Can only read from a string with the lua code
Parser.open("print('hello world')")

-- returns a list of statement nodes
local ast = Parser.parse()
~~~

## AST Structure

- STR: A string
- BOOL: A boolean
- node: An instance of the indicated node
- type?: A value of a type or nothing at all
- [type]: A sequence of zero or more values of a type
- node|node: An instance of any of the nodes (only nodes)
- #category: not a node itself but an union of all the nodes following
  (not including nodes deeper indented)

~~~
#program: [#statement]

#statement:
  local:  names=[STR] values=[#expr]
  localfunc: name=STR      body=function
  fucstat:   lhs=var|field body=function method=BOOL
  numfor: name=STR    body=[#statement] init=#expr limit=#expr step=#expr?
  genfor: names=[STR] body=[#statement] values=[#expr]
  if: clauses=[clause] els=[#statement]?
    clause: cond=#expr body=[#statement]
  repeat: cond=#expr body=[#statement]
  while:  cond=#expr body=[#statement]
  do:     body=[#statement]
  label:  name=STR
  goto:   name=STR
  return: values=[#expr]
  break:  (empty)
  assignment: lhs=[var|field|index] values=[#expr]
  (call)

#expr:
  const: value=STR (true false nil)
  str:   value=STR
  num:   value=STR
  var:   name=STR
  vararg: (empty)
  unop:  op=STR value=#expr
  binop: op=STR left=#expr right=#expr
  field: base=#expr key=STR
  index: base=#expr key=#expr
  call:  base=#expr values=[#expr] key=STR? (for methods)
  function: names=[STR] vararg=BOOL body=[#statement]
  constructor: items=[indexitem|fielditem|item]
    indexitem: key=#expr value=#expr
    fielditem: key=STR   value=#expr
    item:      value=#expr
~~~

## AST example

~~~ lua
function add (a, b)
  local r = a+b
  print(r)
  return r
end

add(1+2, 3)
~~~

Output AST:

~~~ lua
{
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
}
~~~