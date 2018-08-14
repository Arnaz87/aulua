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
