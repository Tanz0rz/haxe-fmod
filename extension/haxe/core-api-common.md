# core-api-common

## FMOD_3D_ATTRIBUTES
verdict: bound
Type: haxefmod.studio.Types.Fmod3DAttributes

## FMOD_CHANNELMASK
verdict: bound
Type: haxefmod.studio.Types.FmodChannelMask

## FMOD_CHANNELORDER
verdict: bound
Type: haxefmod.studio.Types.FmodChannelOrder

## FMOD_CPU_USAGE
verdict: bound
Type: haxefmod.studio.Types.FmodSystemCpuUsage

## FMOD_DEBUG_CALLBACK
verdict: cannot FMOD calls it on whichever of its threads logs, no Haxe target can run code there. The log goes to the platform's standard output at the level set by FmodSettings.logLevel, or to the file named by FmodSettings.logFile on native targets.

## FMOD_DEBUG_FLAGS
verdict: bound
Type: haxefmod.studio.Types.FmodDebugFlags

## FMOD_DEBUG_MODE
verdict: bound
Type: haxefmod.studio.Types.FmodDebugMode

## FMOD_GUID
verdict: bound
Type: haxefmod.studio.Types.FmodGuid

## FMOD_MAX_CHANNEL_WIDTH
verdict: bound
Type: haxefmod.studio.Types.FmodLimits

## FMOD_MAX_LISTENERS
verdict: bound
Type: haxefmod.studio.Types.FmodLimits

## FMOD_MAX_SYSTEMS
verdict: bound
Type: haxefmod.studio.Types.FmodLimits

## FMOD_MEMORY_ALLOC_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

## FMOD_MEMORY_FREE_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

## FMOD_MEMORY_REALLOC_CALLBACK
verdict: cannot FMOD calls its allocator on every one of its threads, no Haxe target can run code there. FMOD keeps its default allocator, and StudioSystem.getMemoryStats reports what it has allocated.

## FMOD_MEMORY_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodMemoryType

## FMOD_MODE
verdict: bound
Type: haxefmod.core.ChannelMode

## FMOD_RESULT
verdict: bound
Type: haxefmod.studio.FmodResult

## FMOD_SPEAKER
verdict: bound
Type: haxefmod.studio.Types.FmodSpeaker

## FMOD_SPEAKERMODE
verdict: bound
Type: haxefmod.studio.Types.FmodSpeakerMode

## FMOD_SYNCPOINT
verdict: bound
Type: haxefmod.core.Sound.FmodSyncPoint

## FMOD_THREAD_AFFINITY
verdict: bound
Type: haxefmod.studio.Types.FmodThreadAffinity

## FMOD_THREAD_PRIORITY
verdict: bound
Type: haxefmod.studio.Types.FmodThreadPriority

## FMOD_THREAD_STACK_SIZE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadStackSize

## FMOD_THREAD_TYPE
verdict: bound
Type: haxefmod.studio.Types.FmodThreadType

## FMOD_TIMEUNIT
verdict: bound
Type: haxefmod.studio.Types.FmodTimeUnit

## FMOD_VECTOR
verdict: bound
Type: haxefmod.studio.Types.FmodVector

## FMOD_VERSION
verdict: bound
Type: haxefmod.studio.Types.FmodVersion

