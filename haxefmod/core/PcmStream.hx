package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;

/**
 * A stream for playing audio generated at runtime.
 *
 * create() makes an FMOD user sound backed by a ring buffer. The game
 * writes PCM bytes with write() and FMOD's mixer drains them as the sound
 * plays. Keep the ring topped up: when it runs dry the mixer plays silence
 * and counts an underrun (see takeUnderruns()).
 *
 * Samples are 16-bit signed integers in system byte order, interleaved
 * when stereo.
 */
abstract PcmStream(Int) from Int to Int {
    public static inline var NULL:PcmStream = cast 0;

    /**
     * Creates a stream. channels is 1 (mono) or 2 (stereo). ringBytes sets
     * how much audio can be buffered between the game and the mixer. The
     * default holds half a second: bigger rides out frame spikes without
     * underruns, smaller lets generated audio react faster.
     * Returns PcmStream.NULL on failure (see StudioSystem.lastResult).
     */
    public static inline function create(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream {
        // The default ring holds 0.5s of 16-bit PCM (2 bytes per sample)
        return NativeStudio.core_pcm_create(sampleRate, channels,
            ringBytes > 0 ? ringBytes : sampleRate * channels);
    }

    /**
     * Like create() but positional: the channel from play() accepts
     * set3DAttributes and attenuates with distance from the listener.
     */
    public static inline function create3d(sampleRate:Int, channels:Int, ringBytes:Int = 0):PcmStream {
        return NativeStudio.core_pcm_create_3d(sampleRate, channels,
            ringBytes > 0 ? ringBytes : sampleRate * channels);
    }

    /** True if this is the invalid handle (create failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /**
     * Queues PCM bytes for the mixer. Returns how many were accepted.
     * When the ring is full the rest are dropped, so hold on to anything
     * unaccepted and resend it once space() opens up.
     */
    public inline function write(data:haxe.io.Bytes, length:Int = -1):Int {
        if (data == null) return 0;
        // Exactly -1 means the whole buffer. Any other non-positive count
        // reaches the native layer and reports FMOD_ERR_INVALID_PARAM, so
        // a miscomputed count surfaces instead of writing everything.
        var len = length == -1 ? data.length : length;
        // Clamp to the real buffer size. The HashLink shim receives a bare
        // byte pointer with no length of its own, so an oversized count
        // would read past the buffer without this guard.
        if (len > data.length) len = data.length;
        return NativeStudio.core_pcm_write(this, data, len);
    }

    /** Bytes that can be written right now. */
    public inline function space():Int {
        return NativeStudio.core_pcm_space(this);
    }

    /**
     * Underruns since the last call, clearing the count. An underrun means
     * the mixer needed audio while the ring was empty and played silence.
     */
    public inline function takeUnderruns():Int {
        return NativeStudio.core_pcm_underruns(this);
    }

    /** Starts playback. Returns Channel.NULL on failure. */
    public inline function play(startPaused:Bool = false):Channel {
        return NativeStudio.core_pcm_play(this, startPaused);
    }

    /** Stops playback, frees the stream, and invalidates this handle. */
    public inline function release():FmodResult {
        UserData.clear(UserDataKind.PcmStream, this);
        return NativeStudio.core_pcm_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.PcmStream, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.PcmStream, this);
    }
}
