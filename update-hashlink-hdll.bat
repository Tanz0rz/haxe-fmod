REM @echo off

REM :: This script should be run whenever there are changes to the C++ haxe-fmod library
REM :: It regenerates the faxe.hdll file which is needed when a game is compiled into HashLink

REM IF NOT EXIST "update-hashlink-hdll.bat" (
REM   echo This script can only be run from inside the same directory
REM   pause
REM   exit -1
REM ) 

REM echo.
REM cd faxe
REM echo Building faxe dll
REM :: -DHASHLINK needs to point to the local 1.10 HashLink installation
REM haxelib run hxcpp Build.xml -DHASHLINK=C:\HaxeToolkit\HashLink
REM echo.

REM cd ..
REM echo removing old dll
REM del "ndll\Windows\faxe.hdll"
REM del "ndll\Windows\faxe.dll.hash"
REM echo.

REM echo moving dll and hash file into hashlink directory
REM move "faxe\faxe.dll" "ndll\Windows\faxe.hdll"
REM move "faxe\faxe.dll.hash" "ndll\Windows\"
REM echo.

REM :: Uncomment this for the "press any key" prompt after the script is finished
REM :: pause
