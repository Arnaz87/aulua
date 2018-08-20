# Lua cobre compiler

Compiles **Lua 5.3** code to the [Cobre VM](https://github.com/Arnaz87/cobrevm). Written in Lua. It can compile itself already.

You can play with it [here](http://arnaud.com.ve/cobre/), working with the Javascript [implementation](https://github.com/Arnaz87/cobreweb) of Cobre.

**Lisence**: This project is free software, published under the
  [MIT License](https://opensource.org/licenses/MIT)

# Usage

First you need [Culang](https://github.com/Arnaz87/culang) installed to compile the core library, then run `bash build.sh install`, this will compile all source files into cobre modules, both lua and culang code, and install them in the system.

Once installed, the command `cobre culua test.lua` will compile test.lua into a cobre module `test`, then you can run `cobre test` to execute it. `lua culua/init.lua test.lua` can be used instead, before installing the cobre modules.

# Missing features

- Almost all of the standard library
- Correct module loading, they are executed everytime they are `require`d
- floats
- the math library
- the utf8 library
- string comparison
- table equality
- full userdata equality
- Varargs are not allowed in the main chunk

# Incompatibilities with standard Lua

The project is not finished yet, but these are the main incompatibilities I know will be present in the final version, obvious mistakes and missing features are not counted.

- I intend to support Lua 5.4 string coercion style
- require is an intrinsic and only accepts literal strings
- \_ENV is not an upvalue but a local of the module scope (I don't know if it's even an incompatibility)
- label safety is not checked by the compiler, that is one can jump to a label with uninitialized locals. Cobre is suposed to check though, but error messages may be a bit less pretty
- I don't intend to support the debug library
- Cobre doesn't support runtime loading yet, so these won't exist for a while:
  + dofile
  + load
  + loadfile
  + the package library
- Multithreading isn't supported either, with these:
  + pcall
  + xpcall
  + the coroutine library
- Garbage collection is out of lua's control
- There are two kinds of userdata, different from those of standard Lua: full userdata are values boxed by lua that have metatables and equality, while light userdata is any non builtin lua type, they can't be compared (unlike standard lua's, these are not pointers) and can't have metatables.
- All values can be valid keys in tables except for light userdata because they can't be compared.
- Each table mantains the state of one iterator, so that a generic for loop is as performant as possible, but performance will degrade significantly if the *next* function is used arbitrarily or if many loops run over the same object simultaneously.
- Assigning a value on a table while it's being iterated, even if it's an already existing key, is an error.
- Table length is average case constant but worst case linear (instead of logarithmic)

# Cobre interoperability

This implementation has special semantics for cobre interop. Special cobre values cannot be used at runtime and the compiler prevents any such usage.

The function _\_CU\_IMPORT_ is a local of the module scope, it receives a list of string literals and joins them with the unit separator character, and then imports the global module with that name and returns it.

The method _get\_type_ of cobre modules receives a string literal and imports that type from the module.

The method _get\_function_ of cobre modules receives the function name as a string literal, and two table literals with only implicit indices and cobre types as values, being the input and output types of the function respectively.

Cobre types can be called with regular lua expressions to convert them to vtyped cobre values, although it can error.

The _test_ method of cobre types can be used to ensure an expression is indeed of that type before converting it to avoid errors.

Cobre functions can only be called with typed cobre values and return typed values as well.

Typed values can neither be used in regular lua expressions, but unlike other special values, they are concrete runtime values and can be saved in locals and even upvalues.

Regular locals can only hold lua values, but locals which are assigned a typed value on declaration become typed locals, and only values of the type of the first value can be assigned to it subsequently.

The method _to\_lua\_value_ of typed values convert them to regular lua values, which are cobre values of type _any_.

The function _\_CU\_MODULE_ accepts as argument a table literal, in which all indices are string literals and all values are either cobre modules, cobre types or cobre functions, and returns a cobre module.

The method _build_ of cobre modules accepts a cobre module and returns another cobre module.

The _get\_module_ method of cobre modules accepts a string literal and imports the module with that name in the target module.
