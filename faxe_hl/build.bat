@echo off
IF NOT DEFINED __ARCH__ (
    @call vcsetup x86
)
@cl.exe /Fo"obj/" faxe_hl.cpp -I./ -I../lib/Windows/api/core/inc -I../lib/Windows/api/studio/inc -I%HASHLINK%/include ..\lib\Windows\api\core\lib\%__ARCH__%\fmod_vc.lib ..\lib\Windows\api\studio\lib\%__ARCH__%\fmodstudio_vc.lib libhl.lib /link /DLL /out:faxe.hdll
@copy faxe.hdll ..\faxe.hdll