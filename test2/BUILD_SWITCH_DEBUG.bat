@echo off
echo "adding switch vars"
SET HAXEPATH=C:\HaxeToolkit_347\haxe\
SET NEKO_INSTPATH=C:\HaxeToolkit_347\neko\
SET PATH=C:\HaxeToolkit_347\haxe;%PATH%
SET HAXELIB_PATH=C:\HaxeToolkit_347\haxelibs
@echo on
haxe build_nx.hxml 
