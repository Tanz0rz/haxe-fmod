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
:: -DHASHLINK needs to point to a local 1.10 HashLink installation
haxelib run hxcpp Build.xml -DHASHLINK=C:\HaxeToolkit\HashLink
echo.

:: Uncomment this for the "press any key" prompt after the script is finished
:: pause
