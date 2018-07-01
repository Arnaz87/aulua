# Lua cobre compiler

Compiles **Lua 5.3** code to the [Cobre VM](https://github.com/Arnaz87/cobrevm). Written in Lua. It is not yet able to compile itself, and the performance is currently comparable to a 4 year old executing the machine instructions.

**Lisence**: This project is free software, published under the
  [MIT License](https://opensource.org/licenses/MIT)

# Usage

First you need to compile the Cobre library with [Culang](https://github.com/Arnaz87/culang), run `cobre culang lua.cu lua` and optionally `cobre --install lua`. Then, run `lua compiler.lua ` which currently inputs *test.lua* and outputs *out*, which is a cobre module, run with `cobre out`.

# Missing features

- Almost all of the standard library
- Correct module loading, they are executed everytime they are 'require'd
- floats
- the math library
- the utf8 library

- TABLE INDEXING IS FREAKING LINEAR TIME!
- GETTING A TABLE LENGTH IS EXPONENTIAL!
- Please use a proper hashmap implementation.

# Incompatibilities with standard Lua

The project is not finished yet, but these are the main incompatibilities I know will be present in the final version, obvious mistakes and missing features are not counted.

- Varargs are not allowed in the main chunk
- I intend to support Lua 5.4 string coertion style
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
- For performance the tables will be implemented using the standard hashmap provided by the platform, so *next* won't be supported. The *pairs* iterator will work but it won't use the table itself as state, it will use a special iterator value.
