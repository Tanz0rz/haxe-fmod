# studio-api-system

## FMOD_STUDIO_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioAdvancedSettings
Set through the FmodSettings fields of the same names before init, encryptionKey included. StudioSystem.getStudioAdvancedSettings reads the five sizes back, native only (unsupported in HTML5). The key is never read back.

## FMOD_STUDIO_BANK_INFO
verdict: library the file callbacks it carries would run on FMOD's loading threads, StudioSystem.loadBankFile and loadBankMemory are the bank loading paths

## FMOD_STUDIO_BUFFER_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodBufferInfo

## FMOD_STUDIO_BUFFER_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodBufferUsage

## FMOD_STUDIO_COMMANDCAPTURE_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandCaptureFlags
The flags argument of StudioSystem.startCommandCapture(path, flags), NORMAL when left out.

## FMOD_STUDIO_COMMANDREPLAY_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandReplayFlags
The flags argument of StudioSystem.loadCommandReplay(path, flags), NORMAL when left out.

## FMOD_STUDIO_CPU_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCpuUsage
StudioSystem.getCpuUsage returns one structure for both systems. The Studio update time is studioUpdate, and update is the core update time from FMOD_CPU_USAGE.

## FMOD_STUDIO_INITFLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioInitFlags
The library passes LIVEUPDATE when FmodSettings.liveUpdate is true and MEMORY_TRACKING when FmodSettings.memoryTracking is true, NORMAL otherwise. The other flags are never set.

## FMOD_STUDIO_LOAD_BANK_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodLoadBankFlags
The flags argument of StudioSystem.loadBankFile and loadBankMemory, NORMAL when left out.

## FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT
verdict: bound
Type: haxefmod.studio.Types.FmodLimits
FmodLimits.STUDIO_LOAD_MEMORY_ALIGNMENT. StudioSystem.loadBankMemory copies the bytes into memory FMOD allocates, so game code never aligns a bank buffer.

## FMOD_STUDIO_LOAD_MEMORY_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodLoadMemoryMode
StudioSystem.loadBankMemory always loads with MEMORY. A Haxe buffer cannot be pinned for the bank's lifetime, so MEMORY_POINT is never used.

## FMOD_STUDIO_LOAD_MEMORY_MODE#2
verdict: bound
Type: haxefmod.studio.Types.FmodLoadMemoryMode
StudioSystem.loadBankMemory always loads with MEMORY. A Haxe buffer cannot be pinned for the bank's lifetime, so MEMORY_POINT is never used.

## FMOD_STUDIO_SOUND_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodSoundInfo
Returned by StudioSystem.getSoundInfo(key). The exinfo fields FMOD fills are flattened into length, fileOffset, initialSubsound, and numSubsounds. The programmer sound callbacks resolve the key natively, EventInstance.assignProgrammerSound(key) picks the sound.

## FMOD_STUDIO_SYSTEM_CALLBACK
verdict: bound
Shape: usage
The handler is a SystemEvent->Void function. FmodManager.Update() delivers the events on the game thread, so there is no system, commanddata, or userdata argument and nothing to return.
```haxe
import haxefmod.studio.SystemCallbacks;

StudioSystem.setSystemCallback(event -> switch (event) {
    case PreUpdate: trace("before update");
    case PostUpdate: trace("after update");
    case BankUnload(path): trace('unloaded $path');
    case LiveUpdateConnected: trace("live update connected");
    case LiveUpdateDisconnected: trace("live update disconnected");
    default:
}, null, SystemCallbacks.STUDIO_PREUPDATE | SystemCallbacks.STUDIO_POSTUPDATE | SystemCallbacks.DEFAULT_STUDIO_MASK);
```

## FMOD_STUDIO_SYSTEM_CALLBACK_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodStudioSystemCallbackType
The same bits are the STUDIO_* Int constants on SystemCallbacks, which is what the studioMask argument of StudioSystem.setSystemCallback takes. PREUPDATE and POSTUPDATE are off by default.
