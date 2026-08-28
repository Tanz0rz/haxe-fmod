# studio-api-system

## FMOD_STUDIO_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioAdvancedSettings
Set through the FmodSettings fields of the same names at init, read back with StudioSystem.getStudioAdvancedSettings.

## FMOD_STUDIO_BANK_INFO
verdict: library user file callbacks are not exposed, StudioSystem.loadBankFile and loadBankMemory load banks

## FMOD_STUDIO_BUFFER_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodBufferInfo

## FMOD_STUDIO_BUFFER_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodBufferUsage

## FMOD_STUDIO_COMMANDCAPTURE_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandCaptureFlags
StudioSystem.startCommandCapture(path) always captures with NORMAL.

## FMOD_STUDIO_COMMANDREPLAY_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandReplayFlags
StudioSystem.loadCommandReplay(path) always loads with NORMAL.

## FMOD_STUDIO_CPU_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCpuUsage
The Studio update time is merged with the core FMOD_CPU_USAGE breakdown into one structure.

## FMOD_STUDIO_INITFLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioInitFlags
The library composes the flags from FmodSettings at init, live update is the liveUpdate field.

## FMOD_STUDIO_LOAD_BANK_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodLoadBankFlags

## FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT
verdict: review note only, decide bound or a category
No Haxe equivalent. StudioSystem.loadBankMemory copies the bytes into memory FMOD owns, so alignment is handled for you.

## FMOD_STUDIO_LOAD_MEMORY_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodLoadMemoryMode
StudioSystem.loadBankMemory always uses MEMORY, since the binding cannot pin a Haxe buffer for the bank's lifetime.

## FMOD_STUDIO_LOAD_MEMORY_MODE#2
verdict: review note only, decide bound or a category
StudioSystem.loadBankMemory copies the bytes, which matches the memory mode of this example. The point mode is not exposed.

## FMOD_STUDIO_SOUND_INFO
verdict: library the native side of programmer sounds, StudioSystem.getSoundInfo returns the name and subsound index

## FMOD_STUDIO_SYSTEM_CALLBACK
verdict: bound
StudioSystem.setSystemCallback takes one handler and delivers the events from FmodManager.Update() on the game thread: device list changed, device lost, bank unload with the bank's path, live update connected and disconnected, and pre and post update.
```haxe
StudioSystem.setSystemCallback(event -> switch (event) {
    case BankUnload(path): trace('unloaded $path');
    case LiveUpdateConnected: trace("live update connected");
    default:
});
```

## FMOD_STUDIO_SYSTEM_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodStudioSystemCallbackType
The mask bits are also the STUDIO_* Int constants on SystemCallbacks. StudioSystem.setSystemCallback delivers every one of them as SystemEvent.
