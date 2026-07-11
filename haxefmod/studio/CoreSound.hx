package haxefmod.studio;

import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD Core sound - the micro subset of the Core API shipped
 * for programmer sounds. Create from an audio file (native: a path on disk;
 * html5: a file preloaded into the virtual filesystem).
 *
 * The full Core API is not bound. This exists so games can
 * inspect and manage the loose audio files they feed to programmer sounds.
 */
abstract CoreSound(Int) from Int to Int {
    public static inline var NULL:CoreSound = cast 0;

    /** Loads a sound file. Returns CoreSound.NULL on failure (see StudioSystem.lastResult). */
    public static inline function create(path:String, loop:Bool = false):CoreSound {
        return NativeStudio.core_create_sound(path, loop ? 1 : 0);
    }

    /**
     * A sound from raw 16-bit PCM in memory (interleaved when stereo).
     * The bytes are copied, so the buffer is free after this returns.
     * Works on every supported platform.
     */
    public static inline function fromPcm(data:haxe.io.Bytes, sampleRate:Int, channels:Int, length:Int = -1):CoreSound {
        return NativeStudio.core_create_sound_pcm(data, length < 0 ? data.length : length, sampleRate, channels);
    }

    /** Starts playback. Returns Channel.NULL on failure. */
    public inline function play(startPaused:Bool = false):haxefmod.core.Channel {
        return NativeStudio.core_play_sound(this, startPaused);
    }

    /** Default playback rate (samples per second) and priority (0 = highest, 256 = lowest). */
    public inline function setDefaults(frequency:Float, priority:Int):FmodResult {
        return NativeStudio.sound_set_defaults(this, frequency, priority);
    }

    public function getDefaults():Null<{frequency:Float, priority:Int}> {
        var result:FmodResult = NativeStudio.sound_get_defaults(this);
        if (!result.isOk()) return null;
        return {frequency: haxefmod.studio.native.Scratch.readF(0),
            priority: Std.int(haxefmod.studio.native.Scratch.readF(1))};
    }

    /** Loop region in milliseconds (needs a looping mode set). */
    public inline function setLoopPoints(startMs:Int, endMs:Int):FmodResult {
        return NativeStudio.sound_set_loop_points(this, startMs, endMs);
    }

    public function getLoopPoints():Null<{startMs:Int, endMs:Int}> {
        var result:FmodResult = NativeStudio.sound_get_loop_points(this);
        if (!result.isOk()) return null;
        return {startMs: haxefmod.studio.native.Scratch.readI(0),
            endMs: haxefmod.studio.native.Scratch.readI(1)};
    }

    /** Combines ChannelMode flags. New channels start with the sound's mode. */
    public inline function setMode(mode:Int):FmodResult {
        return NativeStudio.sound_set_mode(this, mode);
    }

    public inline function getMode():Int {
        return NativeStudio.sound_get_mode(this);
    }

    public function getFormat():Null<{channels:Int, bits:Int}> {
        var result:FmodResult = NativeStudio.sound_get_format(this);
        if (!result.isOk()) return null;
        return {channels: haxefmod.studio.native.Scratch.readI(0),
            bits: haxefmod.studio.native.Scratch.readI(1)};
    }

    /** FMOD_OPENSTATE value (0 = ready), or -1 on failure. Async loads report progress here. */
    public inline function getOpenState():Int {
        return NativeStudio.sound_get_open_state(this);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Length in milliseconds, or -1 on failure. */
    public inline function getLength():Int {
        return NativeStudio.core_get_sound_length(this);
    }

    /** Releases the sound and invalidates this handle. */
    public inline function release():FmodResult {
        return NativeStudio.core_release_sound(this);
    }
}
