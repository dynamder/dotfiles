@echo off
rem Emacs treesit builds a grammar in two steps:
rem   cc -fPIC -c -I. parser.c
rem   cc -fPIC -shared *.o -o libtree-sitter-<lang>.dll
rem zig cc emits COFF objects as *.obj, which the *.o glob misses, so
rem rename the object produced by a -c compile.
setlocal enabledelayedexpansion
set "SRC="
set "HASO="
for %%a in (%*) do (
    if /i "%%~xa"==".c"   set "SRC=%%~na"
    if /i "%%~xa"==".cc"  set "SRC=%%~na"
    if /i "%%~xa"==".cxx" set "SRC=%%~na"
    if /i "%%~a"=="-o"    set "HASO=1"
)
zig cc -target x86_64-windows-gnu %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" exit /b %RC%
if not defined HASO if defined SRC if exist "%SRC%.obj" move /y "%SRC%.obj" "%SRC%.o" >nul 2>&1
exit /b 0
