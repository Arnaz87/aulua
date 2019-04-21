# Lua auro compiler

Compiles **Lua 5.4** code to the [Cobre VM](https://github.com/Arnaz87/aurovm). Written in itself in 6K lines of code.

You can play with it [here](http://arnaud.com.ve/auro/), working with the Javascript [implementation](https://github.com/Arnaz87/auroweb) of Cobre.

**Lisence**: This project is free software, published under the
  [MIT License](https://opensource.org/licenses/MIT)

# Usage

First you need [Culang](https://github.com/Arnaz87/culang) installed to compile the core library, then run `bash build.sh install`, this will compile all source files into auro modules, both lua and culang code, and install them in the system.

Once installed, the command `auro aulua test.lua` will compile test.lua into an auro module `test`, then you can run `auro test` to execute it. `lua aulua/init.lua test.lua` can be used instead, before installing the auro modules.

# Missing features

- Almost all of the standard library
- Correct module loading, they are executed everytime they are `require`d
- the utf8 library
- string comparison
- table equality
- full userdata equality
- Varargs are not allowed in the main chunk
- a few math functions

# Incompatibilities with standard Lua

The project is not finished yet, but these are the main incompatibilities I know will be present in the final version, obvious mistakes and missing features are not counted.

- As this is 5.4, the only incompatibility ith 5.3 are the string coercion rules, they are not built in the language but instead implemented by the string metamethods
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
- There's `file:writebytes`, because the standard lua way to write binary files is making strings out of the bytes, but auro has no guarantees on string encoding (neither does standard lua, but in practice it's well known what it does).

# Cobre interoperability

This implementation has special semantics for auro interop. Special auro values cannot be used at runtime and the compiler prevents any such usage.

The function _\_AU\_IMPORT_ is a local of the module scope, it receives a list of string literals and joins them with the unit separator character, and then imports the global module with that name and returns it.

The method _get\_type_ of auro modules receives a string literal and imports that type from the module.

The method _get\_function_ of auro modules receives the function name as a string literal, and two table literals with only implicit indices and auro types as values, being the input and output types of the function respectively.

Cobre types can be called with regular lua expressions to convert them to typed auro values, although it can error.

The _test_ method of auro types can be used to ensure an expression is indeed of that type before converting it to avoid errors, it returns a _bool_ typed value.

Cobre values of type _bool_ can be used as conditions in _if_, _while_ and _repeat_ statements, but not in logical expressions.

Cobre functions can only be called with typed auro values and return typed values as well.

Typed values can neither be used in regular lua expressions, but unlike other special values, they are concrete runtime values and can be saved in locals and even upvalues.

Regular locals can only hold lua values, but locals which are assigned a typed value on declaration become typed locals, and only values of the type of the first value can be assigned to it subsequently.

The method _to\_lua\_value_ of typed values convert them to regular lua values, which are auro values of type _any_.

The following are not yet implemented

The function _\_AU\_MODULE_ accepts as argument a table literal, in which all indices are string literals and all values are either auro modules, auro types or auro functions, and returns a auro module.

The method _build_ of auro modules accepts an argument auro module and returns another auro module.

The _get\_module_ method of auro modules accepts a string literal and imports the module with that name in the target module.

The function _\_AU\_VALUE_ converts a lua value to a auro value with type _any_. It does not actually do any conversion because lua values are of type any, but this way lua values themselves can be passed to auro functions.

The function _\_AU\_EXPORT_ accepts a string and and an auro module, function or type, and exports it with the given name. The export is in the 

The function _\_AU\_FUNCTION_ accepts two table sequence literals containint auro types, inputs and outputs respectively, and a lua function expression, and returns an auro function. The function expression, when compiled, does not have access to upvalues, it's arguments are auro values and must return auro values as well. The resulting auro function accepts an additional argument of type any which is the lua environment.
