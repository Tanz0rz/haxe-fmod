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

    /**
     * The pool channel at index (see Channel.getIndex). FMOD hands back a
     * reference to the pool slot rather than to the sound playing in it,
     * so this is a separate handle from the one play returned, shared by
     * every call for the same index. The channel may be idle, and every
     * call on an idle channel reports FMOD_ERR_INVALID_HANDLE until FMOD
     * reuses the slot. Stop the handle when done with it to release it.
     * Channel.NULL on failure.
     */
    public static inline function getChannel(index:Int):Channel {
        return NativeStudio.sys_get_channel(index);
    }

    /** The active output type as an FMOD_OUTPUTTYPE value, -1 on failure. */
    public static inline function getOutput():Int {
        return NativeStudio.sys_get_output();
    }

    /** Speaker count of an FMOD_SPEAKERMODE value, 0 on failure. */
    public static inline function getSpeakerModeChannels(speakerMode:Int):Int {
        return NativeStudio.sys_get_speaker_mode_channels(speakerMode);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * FMOD's default upmix or downmix matrix between two FMOD_SPEAKERMODE
     * values, row-major with one row per target channel (unsupported in
     * HTML5, null there). matrixHop widens each row past the source
     * channel count, 0 keeps rows at that count. Null on failure.
     */
    public static macro function getDefaultMixMatrix(sourceSpeakerMode:haxe.macro.Expr, targetSpeakerMode:haxe.macro.Expr, ?matrixHop:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("CoreSystem.getDefaultMixMatrix", "FMOD's web glue binds the matrix as a single float");
    }
    #else
    /**
     * FMOD's default upmix or downmix matrix between two FMOD_SPEAKERMODE
     * values, row-major with one row per target channel (unsupported in
     * HTML5, null there). matrixHop widens each row past the source
     * channel count, 0 keeps rows at that count. Null on failure.
     */
    public static function getDefaultMixMatrix(sourceSpeakerMode:Int, targetSpeakerMode:Int, matrixHop:Int = 0):Null<Array<Float>> {
        var total = NativeStudio.sys_get_default_mix_matrix(sourceSpeakerMode, targetSpeakerMode, matrixHop);
        if (total <= 0) return null;
        return [for (i in 0...total) Scratch.readF(i)];
    }
    #end
}
