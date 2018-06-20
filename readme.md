# Lua cobre compiler

Compiles **Lua 5.3** code to the [Cobre VM](https://github.com/Arnaz87/cobrevm). Written in Lua. It is not yet able to compile itself.

**Lisence**: This project is free software, published under the
  [MIT License](https://opensource.org/licenses/MIT)

# Usage

First you need to compile the Cobre library with [Culang](https://github.com/Arnaz87/culang), run `cobre culang lua.cu lua` and optionally `cobre --install lua`. Then, run `lua compiler.lua ` which currently inputs *test.lua* and outputs *out*, which is a cobre module, run with `cobre out`.