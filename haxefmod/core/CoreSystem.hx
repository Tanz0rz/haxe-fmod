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

    /**
     * Global 3D scale factors: doppler strength, world units per meter,
     * and how aggressively sounds attenuate with distance.
     */
    public static inline function set3DSettings(dopplerScale:Float, distanceFactor:Float, rolloffScale:Float):FmodResult {
        return NativeStudio.sys_set_3d_settings(dopplerScale, distanceFactor, rolloffScale);
    }

    public static function get3DSettings():Null<{dopplerScale:Float, distanceFactor:Float, rolloffScale:Float}> {
        var result:FmodResult = NativeStudio.sys_get_3d_settings();
        if (!result.isOk()) return null;
        return {dopplerScale: Scratch.readF(0), distanceFactor: Scratch.readF(1), rolloffScale: Scratch.readF(2)};
    }

    public static inline function getDriverCount():Int {
        return NativeStudio.sys_get_num_drivers();
    }

    public static inline function getDriverName(index:Int):String {
        return NativeStudio.sys_get_driver_name(index);
    }

    /** Switches the output device (see getDriverCount/getDriverName). */
    public static inline function setDriver(index:Int):FmodResult {
        return NativeStudio.sys_set_driver(index);
    }

    public static inline function getDriver():Int {
        return NativeStudio.sys_get_driver();
    }
}
