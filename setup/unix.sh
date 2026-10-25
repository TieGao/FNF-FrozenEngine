#!/bin/sh
# SETUP FOR MAC AND LINUX SYSTEMS!!!
# REMINDER THAT YOU NEED HAXE INSTALLED PRIOR TO USING THIS
# https://haxe.org/download
cd ..
# CI 里 workflow 已把 haxelib 钉到项目内 .haxelib/（HAXELIB_REPO 注入），这里别再 setup 到
# ~/haxelib 把配置覆盖掉，否则依赖落到家目录、缓存里的 .haxelib/ 是空的。
# 本地开发不设该变量，行为完全不变。
if [ -z "$HAXELIB_REPO" ]; then
  echo Makking the main haxelib and setuping folder in same time..
  mkdir ~/haxelib && haxelib setup ~/haxelib
fi
echo Installing dependencies...
echo This might take a few moments depending on your internet speed.
haxelib install flixel 6.2.0 --skip-dependencies
haxelib install flixel-addons 4.0.1 --skip-dependencies
haxelib install flixel-tools 1.5.1 --skip-dependencies
haxelib install hscript-iris 1.1.3 --skip-dependencies
haxelib install tjson 1.4.0 --skip-dependencies
haxelib install hxdiscord_rpc 1.2.4 --skip-dependencies
haxelib git hxvlc https://github.com/IceTheAxe/hxvlc --skip-dependencies --always
haxelib install moonchart --skip-dependencies
haxelib git lime https://github.com/TieGao/lime --always
haxelib git openfl https://github.com/TieGao/openfl --skip-dependencies --always
haxelib install format --skip-dependencies --always
haxelib install hxp --skip-dependencies --always
haxelib git hxcpp https://github.com/TieGao/hxcpp.git  
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 0188d47c982913eb10fad7bd75f062ddfc680f4b --always
haxelib git linc_luajit https://github.com/TieGao/linc_luajit_largs 8e8340e67fe08560f3205110cc95d3279ecb3973 --always
haxelib git luahscript https://github.com/VapireMox/luahscript 122acb150ba5a55d02b138c2530fa5619fb06c3a --always
haxelib git funkin.vis https://github.com/FunkinCrew/funkVis 22b1ce089dd924f15cdc4632397ef3504d464e90 --always
haxelib git grig.audio https://gitlab.com/haxe-grig/grig.audio.git cbf91e2180fd2e374924fe74844086aab7891666 --always
haxelib set hxcpp git
echo Finished!
