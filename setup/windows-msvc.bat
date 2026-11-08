@echo off
color 0a
cd ..
@echo on
echo Installing Microsoft Visual Studio Community (Dependency)
curl -L -# -O https://aka.ms/vs/17/release/vs_Community.exe
vs_Community.exe --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.Tools.ARM64 --add Microsoft.VisualStudio.Component.Windows10SDK.19041 -p
del vs_Community.exe
echo Finished.
pause
