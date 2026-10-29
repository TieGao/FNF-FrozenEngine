@echo off
color 0a
cd ..
@echo on
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
REM 每行都带 || exit /b 1：haxelib 装挂了必须立刻停。半装的库（典型是 luahscript
REM 只剩一个空目录）在后面的编译里表现为 Type not found，CI 还会把这份坏状态存进
REM 缓存、之后每轮都命中它。
haxelib git flixel https://github.com/TieGao/flixel --skip-dependencies || exit /b 1
haxelib git flixel-addons https://github.com/TieGao/flixel-addons --skip-dependencies || exit /b 1
haxelib install flixel-tools 1.5.1 --skip-dependencies || exit /b 1
haxelib install hscript-iris 1.1.3 --skip-dependencies || exit /b 1
haxelib install tjson 1.4.0 --skip-dependencies || exit /b 1
haxelib install hxdiscord_rpc 1.2.4 --skip-dependencies || exit /b 1
haxelib git hxvlc https://github.com/IceTheAxe/hxvlc --skip-dependencies --always || exit /b 1
haxelib git lime https://github.com/TieGao/lime --always || exit /b 1
haxelib git openfl https://github.com/TieGao/openfl --skip-dependencies --always || exit /b 1
haxelib git moonchart https://github.com/MaybeMaru/moonchart --skip-dependencies || exit /b 1
haxelib install format --skip-dependencies || exit /b 1
haxelib install hxp --skip-dependencies || exit /b 1
haxelib git hxcpp https://github.com/TieGao/hxcpp.git || exit /b 1
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 0188d47c982913eb10fad7bd75f062ddfc680f4b --always || exit /b 1
haxelib git linc_luajit https://github.com/TieGao/linc_luajit_largs 82388eb8d9eb084d91da6ff63de44426c4df0a6e --always || exit /b 1
haxelib git luahscript https://github.com/VapireMox/luahscript 122acb150ba5a55d02b138c2530fa5619fb06c3a --always || exit /b 1
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90 --always || exit /b 1
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666 --always || exit /b 1
haxelib set hxcpp git || exit /b 1
echo Finished!
pause
