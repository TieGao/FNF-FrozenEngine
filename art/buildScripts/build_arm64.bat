@echo off
color 0a
rem ARM64 builds MUST go through the wrapper (VS2019 vcvarsall amd64_arm64 + NO_AUTO_MSVC).
rem Bare hxcpp arm64 setup is broken on this machine - see J:\LuaJIT-arm64\ for wrappers.
rem Output: export-arm64\release\windows\bin (kept separate from x64 export\).
call J:\LuaJIT-arm64\fe_build_arm64.cmd
explorer.exe "J:\FNF-FrozenEngine\export-arm64\release\windows\bin"
