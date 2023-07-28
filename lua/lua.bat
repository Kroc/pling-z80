@ECHO OFF
CD %~dp0
ECHO:

SET "BIN_DIR=bin"
SET "LUA_BIN=%BIN_DIR%\lua\lua53.exe"

"%LUA_BIN%" -- "src\pling.lua"
