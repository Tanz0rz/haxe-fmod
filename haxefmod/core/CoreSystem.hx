package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * Core mixer queries and controls that belong to no single object.
 */
class CoreSystem {
    /**
     * Playing channel counts, or null on failure. `all` includes virtual
     * (inaudible) channels, `real` is what the mixer actually processes.
     */
    public static function getChannelsPlaying():Null<{all:Int, real:Int}> {
        var result:FmodResult = NativeStudio.sys_get_channels_playing();
        if (!result.isOk()) return null;
        return {all: Scratch.readI(0), real: Scratch.readI(1)};
    }

    /**
     * Stops the mixer entirely (for app backgrounding on platforms that
     * demand silence). Pair with mixerResume.
     */
    public static inline function mixerSuspend():FmodResult {
        return NativeStudio.sys_mixer_suspend();
    }

    public static inline function mixerResume():FmodResult {
        return NativeStudio.sys_mixer_resume();
    }

    /** The mixer's output format, or null on failure. */
    public static function getSoftwareFormat():Null<{sampleRate:Int, speakerMode:Int, rawSpeakers:Int}> {
        var result:FmodResult = NativeStudio.sys_get_software_format();
        if (!result.isOk()) return null;
        return {sampleRate: Scratch.readI(0), speakerMode: Scratch.readI(1), rawSpeakers: Scratch.readI(2)};
    }
}
