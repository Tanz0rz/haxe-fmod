# studio-api-system

## 0
<!-- FMOD_STUDIO_ADVANCEDSETTINGS -->
Set through the FmodSettings fields of the same names at init, read back with StudioSystem.getStudioAdvancedSettings.

## 4
<!-- FMOD_STUDIO_COMMANDCAPTURE_FLAGS -->
StudioSystem.startCommandCapture(path) always captures with NORMAL.

## 5
<!-- FMOD_STUDIO_COMMANDREPLAY_FLAGS -->
StudioSystem.loadCommandReplay(path) always loads with NORMAL.

## 6
<!-- FMOD_STUDIO_CPU_USAGE -->
The Studio update time is merged with the core FMOD_CPU_USAGE breakdown into one structure.

## 7
<!-- FMOD_STUDIO_INITFLAGS -->
The library composes the flags from FmodSettings at init, live update is the liveUpdate field.

## 9
<!-- FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT -->
No Haxe equivalent. StudioSystem.loadBankMemory copies the bytes into memory FMOD owns, so alignment is handled for you.

## 10
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
StudioSystem.loadBankMemory always uses MEMORY, since the binding cannot pin a Haxe buffer for the bank's lifetime.

## 11
<!-- FMOD_STUDIO_LOAD_MEMORY_MODE -->
StudioSystem.loadBankMemory copies the bytes, which matches the memory mode of this example. The point mode is not exposed.

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
The mask bits are also the STUDIO_* Int constants on SystemCallbacks. StudioSystem.setSystemCallback delivers every one of them as SystemEvent.
