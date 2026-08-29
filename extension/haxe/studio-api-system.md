# studio-api-system

## FMOD_STUDIO_ADVANCEDSETTINGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioAdvancedSettings

## FMOD_STUDIO_BANK_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodStudioBankInfo

## FMOD_STUDIO_BUFFER_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodBufferInfo

## FMOD_STUDIO_BUFFER_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodBufferUsage

## FMOD_STUDIO_COMMANDCAPTURE_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandCaptureFlags

## FMOD_STUDIO_COMMANDREPLAY_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodCommandReplayFlags

## FMOD_STUDIO_CPU_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCpuUsage

## FMOD_STUDIO_INITFLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodStudioInitFlags

## FMOD_STUDIO_LOAD_BANK_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodLoadBankFlags

## FMOD_STUDIO_LOAD_MEMORY_ALIGNMENT
verdict: bound
Type: haxefmod.studio.Types.FmodLimits

## FMOD_STUDIO_LOAD_MEMORY_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodLoadMemoryMode

## FMOD_STUDIO_LOAD_MEMORY_MODE#2
verdict: bound
Type: haxefmod.studio.Types.FmodLoadMemoryMode
StudioSystem.loadBankMemory always loads with MEMORY. A Haxe buffer cannot be pinned for the bank's lifetime, so MEMORY_POINT is never used.

## FMOD_STUDIO_SOUND_INFO
verdict: bound
Type: haxefmod.studio.Types.FmodSoundInfo

## FMOD_STUDIO_SYSTEM_CALLBACK
verdict: bound
Type: haxefmod.studio.SystemCallbacks.SystemCallback
The handler is a SystemCallback, a SystemEvent->Void function shared with the core system callback. FmodManager.Update() delivers the events on the game thread, so there is no system, commanddata, or userdata argument and nothing to return.
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

