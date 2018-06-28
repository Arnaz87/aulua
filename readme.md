# Lua cobre compiler

Compiles **Lua 5.3** code to the [Cobre VM](https://github.com/Arnaz87/cobrevm). Written in Lua. It is not yet able to compile itself.

**Lisence**: This project is free software, published under the
  [MIT License](https://opensource.org/licenses/MIT)

# Usage

First you need to compile the Cobre library with [Culang](https://github.com/Arnaz87/culang), run `cobre culang lua.cu lua` and optionally `cobre --install lua`. Then, run `lua compiler.lua ` which currently inputs *test.lua* and outputs *out*, which is a cobre module, run with `cobre out`.

# Missing features

- Almost all of the standard library
- Correct module loading, they are executed everytime they are 'require'd

# Incompatibilities with standard Lua

For now, these are the main incompatibilities I know of, obvious mistakes and missing feature are not counted.

- Varargs are allowed everywhere, in standard Lua they are allowed in the main scope but not inside non-vararg functions
- I intend to support Lua 5.4 string coertion style
- require is an intrinsic and only accepts literal strings
- \_ENV is not an upvalue but a local of the module scope (I don't know if it's even an incompatibility)
- label safety is not checked by the compiler, that is one can jump to a label with uninitialized locals. Cobre is suposed to check though, but error messages may be a bit less pretty
- I don't intend to support the debug library
