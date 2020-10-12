@echo off
@pushd %~dp0
@haxelib run hxcpp Build.xml -DHXCPP_M32 %*
@copy faxe.hdll ..\ndll\Windows\faxe.hdll
@popd