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
verdict: cannot FMOD calls it on whichever of its threads logs, no Haxe target can run code there. The log goes to the platform's standard output at the level set by FmodSettings.logLevel, or to the file named by FmodSettings.logFile on native targets.

## FMOD_DEBUG_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodDebugFlags
The LEVEL_ bits come from FmodSettings.logLevel (0 none, 1 error, 2 warning, 3 log) and FmodManager.EnableDebugMessages logs everything. FmodSettings.logFlags adds the TYPE_ and DISPLAY_ bits, native only.

## FMOD_DEBUG_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodDebugMode
TTY unless FmodSettings.logFile names a file, which picks FILE on native targets. CALLBACK is not exposed, FMOD would call it from whichever thread logs.

## FMOD_GUID
verdict: library GUIDs are strings in the text form FMOD Studio shows, taken by StudioSystem.getEventByID and returned by getID on EventDescription, Bank, Bus, and Vca, by FmodParameterDescription.guid, and by the guid field of CoreSystem.getDriverInfo

## FMOD_MAX_CHANNEL_WIDTH
verdict: bound
Type: haxefmod.studio.Types.FmodLimits
FmodLimits.MAX_CHANNEL_WIDTH. A wider mix matrix passed to Channel.setMixMatrix or ChannelGroup.setMixMatrix comes back as FmodResult.FMOD_ERR_INVALID_PARAM.

## FMOD_MAX_LISTENERS
verdict: bound
Type: haxefmod.studio.Types.FmodLimits
FmodLimits.MAX_LISTENERS, the cap StudioSystem.setNumListeners runs into.

## FMOD_MAX_SYSTEMS
verdict: bound
Type: haxefmod.studio.Types.FmodLimits
FmodLimits.MAX_SYSTEMS. haxefmod creates exactly one FMOD system per process inside FmodManager.Initialize, so the limit never applies.

## FMOD_MEMORY_ALLOC_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

## FMOD_MEMORY_FREE_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

## FMOD_MEMORY_REALLOC_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

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
Requested through FmodSettings.speakerMode and read from CoreSystem.getSoftwareFormat, CoreSystem.getDriverInfo, and StudioSystem.getRecordDriverInfo. Dsp.setChannelFormat takes one with the channel mask.

## FMOD_SYNCPOINT
verdict: covered sync points are addressed by index on the Sound (Sound.addSyncPoint, Sound.getSyncPointName, Sound.getSyncPointOffset, Sound.deleteSyncPoint), and a crossing arrives as ChannelEvent.SyncPoint(index) through Channel.setCallback

## FMOD_THREAD_AFFINITY
verdict: bound
Type: haxefmod.studio.Types.FmodThreadAffinity
The affinity field of a FmodSettings.threadAttributes entry, a 32-bit core mask. The 64-bit group values do not fit a Haxe Int, so an unset affinity keeps FMOD's default group. Native only, the web build has no threads to place.

## FMOD_THREAD_PRIORITY
verdict: bound
Type: haxefmod.studio.Types.FmodThreadPriority
The priority field of a FmodSettings.threadAttributes entry. DEFAULT keeps FMOD's own value for that thread.

## FMOD_THREAD_STACK_SIZE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadStackSize
The stackSize field of a FmodSettings.threadAttributes entry. DEFAULT keeps FMOD's own value for that thread.

## FMOD_THREAD_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadType
The type field of a FmodSettings.threadAttributes entry, applied with Thread_SetAttributes before the system is created.

## FMOD_TIMEUNIT
verdict: bound
Type: haxefmod.studio.Types.FmodTimeUnit
An optional trailing parameter on Sound.getLength, Sound.getLoopPoints, Sound.setLoopPoints, Sound.addSyncPoint, Sound.getSyncPointOffset, Channel.getPosition, Channel.setPosition, Channel.getLoopPoints, and Channel.setLoopPoints. It defaults to MS. Loop points share one unit for the start and the end.

## FMOD_VECTOR
verdict: bound
Type: haxefmod.studio.Types.FmodVector

## FMOD_VERSION
verdict: covered haxefmod links one FMOD version per release, and StudioSystem.getVersion returns the version the running build loaded as a string formatted like "2.03.12"
