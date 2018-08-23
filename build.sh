#!/bin/env bash
mkdir -p dist

MAIN=culua/init.lua

cobre culang lua.cu dist/lua
lua $MAIN -o dist/ lua_lib/table.lua
lua $MAIN -o dist/ lua_lib/string.lua
lua $MAIN -o dist/ lua_lib/pattern.lua

lua $MAIN -o dist/ lua_parser/parser.lua
lua $MAIN -o dist/ lua_parser/lexer.lua
lua $MAIN -o dist/lua_parser lua_parser/init.lua

lua $MAIN -o dist/ culua/helpers.lua
lua $MAIN -o dist/ culua/basics.lua
lua $MAIN -o dist/ culua/codegen.lua
lua $MAIN -o dist/ culua/cobre_syntax.lua
lua $MAIN -o dist/ culua/write.lua
lua $MAIN -o dist/ culua/compile.lua
lua $MAIN -o dist/culua culua/init.lua

if [ "$1" == "install" ]; then
  cd dist
  for a in $(ls); do
    cobre --install $a
  done
fi
