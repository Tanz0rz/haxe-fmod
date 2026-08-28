# studio-api-system

## 0
<!-- FMOD_STUDIO_ADVANCEDSETTINGS -->
Set through the FmodSettings fields of the same names at init, read back with StudioSystem.getStudioAdvancedSettings.
Type: haxefmod.studio.Types.FmodStudioAdvancedSettings

## 1
<!-- FMOD_STUDIO_BANK_INFO -->
No Haxe equivalent. User file callbacks would run on FMOD's threads, so loadBankCustom is not exposed. Load banks with StudioSystem.loadBankFile(path) or StudioSystem.loadBankMemory(bytes).

## 2
<!-- FMOD_STUDIO_BUFFER_INFO -->
Type: haxefmod.studio.Types.FmodBufferInfo

## 3
<!-- FMOD_STUDIO_BUFFER_USAGE -->
Type: haxefmod.studio.Types.FmodBufferUsage

## 4
<!-- FMOD_STUDIO_COMMANDCAPTURE_FLAGS -->
No Haxe equivalent. StudioSystem.startCommandCapture(path) always captures with the normal flags.

## 5
<!-- FMOD_STUDIO_COMMANDREPLAY_FLAGS -->
No Haxe equivalent. StudioSystem.loadCommandReplay(path) always loads with the normal flags.

## 6
<!-- FMOD_STUDIO_CPU_USAGE -->
The Studio update time is merged with the core FMOD_CPU_USAGE breakdown into one structure.
Type: haxefmod.studio.Types.FmodSystemCpuUsage

## 7
<!-- FMOD_STUDIO_INITFLAGS -->
No Haxe equivalent. The library chooses the init flags, live update is the liveUpdate field of FmodSettings.

## 8
<!-- FMOD_STUDIO_LOAD_BANK_FLAGS -->
Type: haxefmod.studio.Types.FmodLoadBankFlags

## 9
<!-- FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT -->
No Haxe equivalent. StudioSystem.loadBankMemory copies the bytes into memory FMOD owns, so alignment is handled for you.

## 10
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
No Haxe equivalent. StudioSystem.loadBankMemory always uses the copying mode, since the binding cannot pin a Haxe buffer for the bank's lifetime.

## 11
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
StudioSystem.loadBankMemory copies the bytes, which matches the memory mode of this example. The point mode is not exposed.

## 12
<!-- FMOD_STUDIO_SOUND_INFO -->
No Haxe equivalent. Audio table lookups happen natively when EventInstance.assignProgrammerSound(key) is called before start(), native only (unsupported in HTML5).

## 13
<!-- FMOD_STUDIO_SYSTEM_CALLBACK -->
StudioSystem.setSystemCallback takes one handler and delivers the events from FmodManager.Update() on the game thread: device list changed, device lost, bank unload with the bank's path, live update connected and disconnected, and pre and post update.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case BankUnload(path): trace('unloaded $path');
    case LiveUpdateConnected: trace("live update connected");
    default:
});
```

## 14
<!-- FMOD_STUDIO_SYSTEM_CALLBACK_TYPE -->
The mask bits are the STUDIO_* Int constants on SystemCallbacks, the events arrive as this enum through StudioSystem.setSystemCallback.
Type: haxefmod.studio.SystemCallbacks.SystemEvent
