package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

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

    public inline function getMute():Bool {
        return NativeStudio.chan_get_mute(this);
    }

    public inline function setMute(mute:Bool):FmodResult {
        return NativeStudio.chan_set_mute(this, mute);
    }

    /** A built-in lowpass on the channel (1.0 = open, 0.0 = fully closed). */
    public inline function setLowPassGain(gain:Float):FmodResult {
        return NativeStudio.chan_set_low_pass_gain(this, gain);
    }

    /** Combines ChannelMode flags (looping, 2D/3D, rolloff shape). */
    public inline function setMode(mode:Int):FmodResult {
        return NativeStudio.chan_set_mode(this, mode);
    }

    /** Directional sound: full volume inside the cone, outsideVolume behind it. */
    public inline function set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult {
        return NativeStudio.chan_set_3d_cone_settings(this, insideAngle, outsideAngle, outsideVolume);
    }

    public inline function set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult {
        return NativeStudio.chan_set_3d_cone_orientation(this, x, y, z);
    }

    /** Muffles the channel as if behind an obstacle (0.0 = clear, 1.0 = fully blocked). */
    public inline function set3DOcclusion(direct:Float, reverb:Float):FmodResult {
        return NativeStudio.chan_set_3d_occlusion(this, direct, reverb);
    }

    public function get3DOcclusion():Null<{direct:Float, reverb:Float}> {
        var result:FmodResult = NativeStudio.chan_get_3d_occlusion(this);
        if (!result.isOk()) return null;
        return {direct: Scratch.readF(0), reverb: Scratch.readF(1)};
    }

    /** Speaker spread of a 3D sound in degrees (0 = point source). */
    public inline function set3DSpread(angle:Float):FmodResult {
        return NativeStudio.chan_set_3d_spread(this, angle);
    }

    /** Blend between 2D and full 3D positioning (0.0 = 2D, 1.0 = 3D). */
    public inline function set3DLevel(level:Float):FmodResult {
        return NativeStudio.chan_set_3d_level(this, level);
    }

    public inline function set3DDopplerLevel(level:Float):FmodResult {
        return NativeStudio.chan_set_3d_doppler_level(this, level);
    }

    /**
     * Routes input channels to output speakers with explicit gains
     * (row-major, outChannels rows of inChannels gains, up to 32x32).
     */
    public function setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int):FmodResult {
        var total = outChannels * inChannels;
        if (total < 0 || total > matrix.length || total > Scratch.CAPACITY) {
            return FmodResult.FMOD_ERR_INVALID_PARAM;
        }
        for (i in 0...total) Scratch.writeF(i, matrix[i]);
        return NativeStudio.chan_set_mix_matrix(this, outChannels, inChannels);
    }

    /**
     * The channel's mixer clock in output samples, or null on failure.
     * `parent` is the group clock that setDelay and fade points schedule
     * against. Clocks are exact to 2^53 samples.
     */
    public function getDspClock():Null<{clock:Float, parent:Float}> {
        var result:FmodResult = NativeStudio.chan_get_dsp_clock(this);
        if (!result.isOk()) return null;
        return {clock: Scratch.readF(0), parent: Scratch.readF(1)};
    }

    /** Sample-accurate start/stop window on the parent clock (0 = no bound). */
    public inline function setDelay(startClock:Float, endClock:Float, stopChannels:Bool = false):FmodResult {
        return NativeStudio.chan_set_delay(this, startClock, endClock, stopChannels);
    }

    /** Schedules a volume point at a parent-clock time. FMOD ramps between points. */
    public inline function addFadePoint(clock:Float, volume:Float):FmodResult {
        return NativeStudio.chan_add_fade_point(this, clock, volume);
    }

    /** A click-free ramp from the current volume to `volume`, ending at `clock`. */
    public inline function setFadePointRamp(clock:Float, volume:Float):FmodResult {
        return NativeStudio.chan_set_fade_point_ramp(this, clock, volume);
    }

    public inline function removeFadePoints(startClock:Float, endClock:Float):FmodResult {
        return NativeStudio.chan_remove_fade_points(this, startClock, endClock);
    }

    /**
     * Delivers End and SyncPoint events for this channel (drained once per
     * frame with the other callbacks). End also removes the handler.
     */
    public inline function setCallback(handler:haxefmod.core.ChannelEvent->Void):Void {
        haxefmod.core.ChannelCallbacks.set(this, handler);
    }

    public inline function clearCallback():Void {
        haxefmod.core.ChannelCallbacks.remove(this);
    }

    public inline function getLoopCount():Int {
        return NativeStudio.chan_get_loop_count(this);
    }

    public inline function getLowPassGain():Float {
        return NativeStudio.chan_get_low_pass_gain(this);
    }

    public inline function getMode():Int {
        return NativeStudio.chan_get_mode(this);
    }

    public function get3DConeSettings():Null<{insideAngle:Float, outsideAngle:Float, outsideVolume:Float}> {
        var result:FmodResult = NativeStudio.chan_get_3d_cone_settings(this);
        if (!result.isOk()) return null;
        return {insideAngle: Scratch.readF(0), outsideAngle: Scratch.readF(1), outsideVolume: Scratch.readF(2)};
    }

    public inline function get3DSpread():Float {
        return NativeStudio.chan_get_3d_spread(this);
    }

    public inline function get3DLevel():Float {
        return NativeStudio.chan_get_3d_level(this);
    }

    public inline function get3DDopplerLevel():Float {
        return NativeStudio.chan_get_3d_doppler_level(this);
    }

    public function get3DMinMaxDistance():Null<{minDistance:Float, maxDistance:Float}> {
        var result:FmodResult = NativeStudio.chan_get_3d_min_max(this);
        if (!result.isOk()) return null;
        return {minDistance: Scratch.readF(0), maxDistance: Scratch.readF(1)};
    }

    public function get3DAttributes():Null<{posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float}> {
        var result:FmodResult = NativeStudio.chan_get_3d_attributes(this);
        if (!result.isOk()) return null;
        return {posX: Scratch.readF(0), posY: Scratch.readF(1), posZ: Scratch.readF(2),
            velX: Scratch.readF(3), velY: Scratch.readF(4), velZ: Scratch.readF(5)};
    }

    public function getDelay():Null<{startClock:Float, endClock:Float, stopChannels:Bool}> {
        var result:FmodResult = NativeStudio.chan_get_delay(this);
        if (!result.isOk()) return null;
        return {startClock: Scratch.readF(0), endClock: Scratch.readF(1), stopChannels: Scratch.readF(2) > 0.5};
    }

    /** Stops playback, removes any callback handler, and invalidates this handle. */
    public function stop():FmodResult {
        haxefmod.core.ChannelCallbacks.remove(this);
        return NativeStudio.chan_stop(this);
    }
}
