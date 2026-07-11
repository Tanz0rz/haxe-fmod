package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to an FMOD Core channel - a playing instance of a sound.
 *
 * Obtain via PcmStream.play(). Handles are plain ints under the hood. A
 * stale or invalid handle makes every call a safe no-op (getters return
 * defaults, setters return FMOD_ERR_INVALID_HANDLE). Channels end on their
 * own when playback stops, so FMOD-side errors can appear before stop() is
 * called. Call stop() when done with the channel either way: it always
 * frees the handle.
 */
abstract Channel(Int) from Int to Int {
    public static inline var NULL:Channel = cast 0;

    /** True if this is the invalid handle (play failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** The volume as set by the API (linear: 0.0 = silent, 1.0 = full). */
    public inline function getVolume():Float {
        return NativeStudio.chan_get_volume(this);
    }

    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.chan_set_volume(this, volume);
    }

    /** The pitch multiplier (1.0 = as recorded, 2.0 = one octave up). */
    public inline function getPitch():Float {
        return NativeStudio.chan_get_pitch(this);
    }

    public inline function setPitch(pitch:Float):FmodResult {
        return NativeStudio.chan_set_pitch(this, pitch);
    }

    public inline function getPaused():Bool {
        return NativeStudio.chan_get_paused(this);
    }

    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.chan_set_paused(this, paused);
    }

    public inline function isPlaying():Bool {
        return NativeStudio.chan_is_playing(this);
    }

    /** Stops playback and invalidates this handle. */
    public inline function stop():FmodResult {
        return NativeStudio.chan_stop(this);
    }
}
