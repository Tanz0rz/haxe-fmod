# core-api-common

## 0
<!-- FMOD_3D_ATTRIBUTES -->
Type: haxefmod.studio.Types.Fmod3DAttributes

## 1
<!-- FMOD_CHANNELMASK -->
No Haxe equivalent. Speaker layouts come from CoreSystem.getSoftwareFormat, and per-speaker routing goes through Channel.setMixMatrix or ChannelGroup.setMixMatrix.

## 2
<!-- FMOD_CHANNELORDER -->
No Haxe equivalent. Sound.create and Sound.fromPcm use FMOD's default interleaved order.

## 3
<!-- FMOD_CPU_USAGE -->
FMOD_CPU_USAGE and the studio update field are merged into one record, returned by StudioSystem.getCpuUsage.
Type: haxefmod.studio.Types.FmodSystemCpuUsage

## 4
<!-- FMOD_DEBUG_CALLBACK -->
Debug callbacks are not exposed, since they run on FMOD threads. FMOD's log goes to the platform's standard output at the level set by FmodSettings.logLevel.

## 5
<!-- FMOD_DEBUG_FLAGS -->
No Haxe equivalent. The level is chosen by FmodSettings.logLevel (0 none, 1 error, 2 warning, 3 log), and FmodManager.EnableDebugMessages logs everything.

## 7
<!-- FMOD_DEBUG_MODE -->
No Haxe equivalent. The output mode is FMOD's default, and the level comes from FmodSettings.logLevel.

## 10
<!-- FMOD_GUID -->
No Haxe equivalent. GUIDs are strings in the text form FMOD Studio shows, used by StudioSystem.getEventByID, EventDescription.getID, and the generated FmodEventsGuids class.

## 11
<!-- FMOD_MAX_CHANNEL_WIDTH -->
No Haxe equivalent. FMOD validates mix matrices passed to setMixMatrix, and an oversized one comes back as FMOD_ERR_INVALID_PARAM.

## 12
<!-- FMOD_MAX_LISTENERS -->
No Haxe equivalent. StudioSystem.setNumListeners passes the count through to FMOD, which rejects anything above eight.

## 13
<!-- FMOD_MAX_SYSTEMS -->
No Haxe equivalent. haxefmod creates exactly one FMOD system per process, so the limit never applies.

## 14
<!-- FMOD_MEMORY_ALLOC_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator, and StudioSystem.getMemoryStats reports what it has allocated.
```haxe
var stats = StudioSystem.getMemoryStats();
if (stats != null) {
    trace('current ${stats.current} bytes, peak ${stats.maximum} bytes');
}
```

## 15
<!-- FMOD_MEMORY_FREE_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator.

## 18
<!-- FMOD_MEMORY_REALLOC_CALLBACK -->
Custom allocators are not exposed. FMOD uses its own allocator.

## 19
<!-- FMOD_MEMORY_TYPE -->
No Haxe equivalent. The flags belong to the allocator hooks, which are not exposed, and totals come from StudioSystem.getMemoryStats and StudioSystem.getMemoryUsage.

## 20
<!-- FMOD_MODE -->
The flags are Int constants on ChannelMode, combined with | and passed to Sound.setMode or Channel.setMode.
Type: haxefmod.core.ChannelMode

## 21
<!-- FMOD_RESULT -->
Type: haxefmod.studio.FmodResult

## 22
<!-- FMOD_SPEAKER -->
No Haxe equivalent. Speakers are the row and column indices of a mix matrix in FMOD's speaker order, taken directly by Channel.setMixMatrix and ChannelGroup.setMixMatrix.

## 23
<!-- FMOD_SPEAKERMODE -->
No Haxe equivalent. The mode is a plain Int with FMOD's values, requested through FmodSettings.speakerMode and read from CoreSystem.getSoftwareFormat.

## 24
<!-- FMOD_SYNCPOINT -->
Sync points are addressed by index on the Sound, and crossings arrive as ChannelEvent.SyncPoint through Channel.setCallback.
Type: haxefmod.core.ChannelEvent

## 25
<!-- FMOD_THREAD_AFFINITY -->
No Haxe equivalent. FMOD chooses its thread placement on every target, and there is no thread to place on HTML5.

## 26
<!-- FMOD_THREAD_PRIORITY -->
No Haxe equivalent. FMOD uses its default priorities on every target.

## 28
<!-- FMOD_THREAD_STACK_SIZE -->
No Haxe equivalent. FMOD uses its default stack sizes on every target.

## 29
<!-- FMOD_THREAD_TYPE -->
No Haxe equivalent. Thread settings are not exposed, so the type has no use from Haxe.

## 30
<!-- FMOD_TIMEUNIT -->
No Haxe equivalent. Positions and lengths are always milliseconds in Channel.getPosition, Channel.setPosition, Sound.getLength, and Sound.addSyncPoint.

## 31
<!-- FMOD_VECTOR -->
Type: haxefmod.studio.Types.FmodVector

## 32
<!-- FMOD_VERSION -->
No Haxe equivalent. haxefmod links one FMOD version per release, and StudioSystem.getVersion reports it as a string.
