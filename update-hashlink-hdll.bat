@echo off

:: This script should be run whenever there are changes to the C++ haxe-fmod library
:: It regenerates the faxe.hdll file which is needed when a game is compiled into HashLink

IF NOT EXIST "update-hashlink-hdll.bat" (
  echo This script can only be run from inside the same directory
  pause
  exit -1
) 

echo.
cd faxe
echo Building faxe dll
:: -DHASHLINK needs to point to the local 1.10 HashLink installation
haxelib run hxcpp Build.xml -DHASHLINK=C:\HaxeToolkit\HashLink
echo.

cd ..
echo removing old dll
del "ndll\Windows\faxe.hdll"
del "ndll\Windows\faxe.dll.hash"
echo.

echo moving dll and hash file into hashlink directory
move "faxe\faxe.dll" "ndll\Windows\faxe.hdll"
move "faxe\faxe.dll.hash" "ndll\Windows\"
echo.

:: Uncomment this for the "press any key" prompt after the script is finished
:: pause
