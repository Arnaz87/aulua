#!/bin/env bash
mkdir -p dist

# 2.2s to build, 25 min to bootstrap

MAIN="lua aulua/init.lua"
if [ "$1" == "bootstrap" ]; then
  MAIN="auro --dir dist aulua"
fi

auro culang lua.cu dist/lua
$MAIN -o dist/ lua_lib/table.lua
$MAIN -o dist/ lua_lib/string.lua
$MAIN -o dist/ lua_lib/pattern.lua
$MAIN -o dist/ lua_lib/math.lua

$MAIN -o dist/ lua_parser/parser.lua
$MAIN -o dist/ lua_parser/lexer.lua
$MAIN -o dist/lua_parser lua_parser/init.lua

$MAIN -o dist/ aulua/helpers.lua
$MAIN -o dist/ aulua/basics.lua
$MAIN -o dist/ aulua/codegen.lua
$MAIN -o dist/ aulua/auro_syntax.lua
$MAIN -o dist/ aulua/write.lua
$MAIN -o dist/ aulua/compile.lua
$MAIN -o dist/aulua aulua/init.lua

if [ "$1" == "install" ]; then
  cd dist
  for a in $(ls); do
    auro --install $a
  done
fi
