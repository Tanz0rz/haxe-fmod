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

    /** Constant-power stereo pan (-1.0 = full left, 0 = center, 1.0 = full right). */
    public inline function setPan(pan:Float):FmodResult {
        return NativeStudio.chan_set_pan(this, pan);
    }

    /** Playback rate in samples per second (resampling: also shifts pitch). */
    public inline function getFrequency():Float {
        return NativeStudio.chan_get_frequency(this);
    }

    public inline function setFrequency(frequency:Float):FmodResult {
        return NativeStudio.chan_set_frequency(this, frequency);
    }

    /** Times to loop before stopping (-1 = forever, 0 = play once). */
    public inline function setLoopCount(loopCount:Int):FmodResult {
        return NativeStudio.chan_set_loop_count(this, loopCount);
    }

    /** Playback position in milliseconds, or -1 on failure. */
    public inline function getPosition():Int {
        return NativeStudio.chan_get_position(this);
    }

    public inline function setPosition(positionMs:Int):FmodResult {
        return NativeStudio.chan_set_position(this, positionMs);
    }

    /** Reroutes this channel into a group. */
    public inline function setChannelGroup(group:ChannelGroup):FmodResult {
        return NativeStudio.chan_set_channel_group(this, group);
    }

    /** Inserts an effect on this channel (0 = head of the chain). */
    public inline function addDsp(index:Int, dsp:Dsp):FmodResult {
        return NativeStudio.chan_add_dsp(this, index, dsp);
    }

    public inline function removeDsp(dsp:Dsp):FmodResult {
        return NativeStudio.chan_remove_dsp(this, dsp);
    }

    /**
     * Positions the channel in 3D space. Only works on 3D sounds
     * (PcmStream.create3d). Uses the Studio listener for distance and pan.
     */
    public inline function set3DAttributes(posX:Float, posY:Float, posZ:Float,
            velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult {
        return NativeStudio.chan_set_3d_attributes(this, posX, posY, posZ, velX, velY, velZ);
    }

    /** Distances where attenuation starts and stops (3D sounds). */
    public inline function set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult {
        return NativeStudio.chan_set_3d_min_max(this, minDistance, maxDistance);
    }

    /** How much this channel feeds a reverb instance (0.0 = none, 1.0 = full). */
    public inline function setReverbWet(instance:Int, wet:Float):FmodResult {
        return NativeStudio.chan_set_reverb_wet(this, instance, wet);
    }

    /** Stops playback and invalidates this handle. */
    public inline function stop():FmodResult {
        return NativeStudio.chan_stop(this);
    }
}
