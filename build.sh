#!/bin/env bash
mkdir -p dist
lua main.lua -o dist/ lua_lib/table.lua
lua main.lua -o dist/ lua_lib/string.lua
lua main.lua -o dist/ lua_lib/pattern.lua
cobre culang lua.cu dist/lua