# Lua parser

**Lua 5.3** parser made in *Lua 5.3*.

Intended to be small and simple. My main references for this code were:

- [The original Lua](https://www.lua.org/source/5.3/)
- [Yueliang](http://yueliang.luaforge.net/)
- [LuaMinify](https://github.com/stravant/LuaMinify)

*TODO: Emit the source position in the Parser*

**Lisence**: This is free software, published under the
  [WTFPL](http://www.wtfpl.net/)

## Usage

Copy *lexer.lua* and *parser.lua* into your source directory.

~~~ lua
local Parser = require("parser")

-- Can only read from a string with the lua code
Parser.open("print('hello world')")

-- returns a list of statement nodes
local ast = Parser.parse()
~~~

# AST Structure

- STR: A string
- BOOL: A boolean
- node: An instance of the indicated node
- type?: A value of a type or nothing at all
- [type]: A sequence of zero or more values of a type
- node|node: An instance of any of the nodes (only nodes)
- #category: not a node itself but an union of all the nodes following
  (except for nodes deeper indented)

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

## Complex AST example

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
}
~~~