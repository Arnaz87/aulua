#!/bin/env bash
mkdir -p dist

MAIN=aulua/init.lua

auro culang lua.cu dist/lua
lua $MAIN -o dist/ lua_lib/table.lua
lua $MAIN -o dist/ lua_lib/string.lua
lua $MAIN -o dist/ lua_lib/pattern.lua
lua $MAIN -o dist/ lua_lib/math.lua

lua $MAIN -o dist/ lua_parser/parser.lua
lua $MAIN -o dist/ lua_parser/lexer.lua
lua $MAIN -o dist/lua_parser lua_parser/init.lua

lua $MAIN -o dist/ aulua/helpers.lua
lua $MAIN -o dist/ aulua/basics.lua
lua $MAIN -o dist/ aulua/codegen.lua
lua $MAIN -o dist/ aulua/auro_syntax.lua
lua $MAIN -o dist/ aulua/write.lua
lua $MAIN -o dist/ aulua/compile.lua
lua $MAIN -o dist/aulua aulua/init.lua

if [ "$1" == "install" ]; then
  cd dist
  for a in $(ls); do
    auro --install $a
  done
fi
