# core-api-common

## FMOD_3D_ATTRIBUTES
verdict: bound
Type: haxefmod.studio.Types.Fmod3DAttributes

## FMOD_CHANNELMASK
verdict: bound
Type: haxefmod.studio.Types.FmodChannelMask
Taken by Dsp.setChannelFormat and Dsp.getOutputChannelFormat. Per-speaker routing goes through Channel.setMixMatrix or ChannelGroup.setMixMatrix.

## FMOD_CHANNELORDER
verdict: bound
Type: haxefmod.studio.Types.FmodChannelOrder
Sound.create and Sound.fromPcm use DEFAULT, no call takes a channel order.

## FMOD_CPU_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCpuUsage
FMOD_CPU_USAGE and the studio update field are merged into one record, returned by StudioSystem.getCpuUsage.

## FMOD_DEBUG_CALLBACK
verdict: review note only, decide bound or a category
Debug callbacks are not exposed, since they run on FMOD threads. FMOD's log goes to the platform's standard output at the level set by FmodSettings.logLevel.

## FMOD_DEBUG_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodDebugFlags
The library composes these from FmodSettings.logLevel (0 none, 1 error, 2 warning, 3 log), and FmodManager.EnableDebugMessages logs everything.

## FMOD_DEBUG_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodDebugMode
The library keeps TTY, and the level comes from FmodSettings.logLevel.

## FMOD_GUID
verdict: library GUIDs are strings in the text form FMOD Studio shows, taken by StudioSystem.getEventByID and returned by EventDescription.getID

## FMOD_MAX_CHANNEL_WIDTH
verdict: review note only, decide bound or a category
No Haxe equivalent. FMOD validates mix matrices passed to setMixMatrix, and an oversized one comes back as FMOD_ERR_INVALID_PARAM.

## FMOD_MAX_LISTENERS
verdict: review note only, decide bound or a category
No Haxe equivalent. StudioSystem.setNumListeners passes the count through to FMOD, which rejects anything above eight.

## FMOD_MAX_SYSTEMS
verdict: review note only, decide bound or a category
No Haxe equivalent. haxefmod creates exactly one FMOD system per process, so the limit never applies.

## FMOD_MEMORY_ALLOC_CALLBACK
verdict: bound
Custom allocators are not exposed. FMOD uses its own allocator, and StudioSystem.getMemoryStats reports what it has allocated.
```haxe
var stats = StudioSystem.getMemoryStats();
if (stats != null) {
    trace('current ${stats.current} bytes, peak ${stats.maximum} bytes');
}
```

## FMOD_MEMORY_FREE_CALLBACK
verdict: review note only, decide bound or a category
Custom allocators are not exposed. FMOD uses its own allocator.

## FMOD_MEMORY_REALLOC_CALLBACK
verdict: review note only, decide bound or a category
Custom allocators are not exposed. FMOD uses its own allocator.

## FMOD_MEMORY_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodMemoryType
The flags belong to the allocator hooks, which are not exposed. Totals come from StudioSystem.getMemoryStats and StudioSystem.getMemoryUsage.

## FMOD_MODE
verdict: bound
Type: haxefmod.core.ChannelMode
The flags are Int constants on ChannelMode, combined with | and passed to Sound.setMode or Channel.setMode.

## FMOD_RESULT
verdict: bound
Type: haxefmod.studio.FmodResult

## FMOD_SPEAKER
verdict: bound
Type: haxefmod.studio.Types.FmodSpeaker
Taken by CoreSystem.setSpeakerPosition and getSpeakerPosition. The same values are the row and column indices of a mix matrix in Channel.setMixMatrix and ChannelGroup.setMixMatrix.

## FMOD_SPEAKERMODE
verdict: bound
Type: haxefmod.studio.Types.FmodSpeakerMode
Requested through FmodSettings.speakerMode and read from CoreSystem.getSoftwareFormat.

## FMOD_SYNCPOINT
verdict: bound
Type: haxefmod.core.ChannelEvent
Sync points are addressed by index on the Sound, and crossings arrive as ChannelEvent.SyncPoint through Channel.setCallback.

## FMOD_THREAD_AFFINITY
verdict: review note only, decide bound or a category
No Haxe equivalent. FMOD chooses its thread placement on every target, and there is no thread to place on HTML5.

## FMOD_THREAD_PRIORITY
verdict: bound
Type: haxefmod.studio.Types.FmodThreadPriority
FMOD uses these default priorities on every target, no call changes them.

## FMOD_THREAD_STACK_SIZE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadStackSize
FMOD uses these default stack sizes on every target, no call changes them.

## FMOD_THREAD_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadType
Thread settings are not exposed, so no call takes a thread type.

## FMOD_TIMEUNIT
verdict: bound
Type: haxefmod.studio.Types.FmodTimeUnit
No call takes a time unit. Positions and lengths are always milliseconds in Channel.getPosition, Channel.setPosition, Sound.getLength, and Sound.addSyncPoint.

## FMOD_VECTOR
verdict: bound
Type: haxefmod.studio.Types.FmodVector

## FMOD_VERSION
verdict: review note only, decide bound or a category
No Haxe equivalent. haxefmod links one FMOD version per release, and StudioSystem.getVersion reports it as a string.
