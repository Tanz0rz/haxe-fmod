package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.Types.FmodVector;
import haxefmod.studio.UserData;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD channel group - a mixing bus for raw channels.
 *
 * master() is the final mix everything passes through. Custom groups from
 * create() can hold any set of channels (see Channel.setChannelGroup) for
 * shared volume, pitch, and effects. Studio buses also expose their group
 * through Bus.getChannelGroup for attaching effects to Studio-mixed audio.
 *
 * Handles are plain ints under the hood. A stale or invalid handle makes
 * every call a safe no-op.
 */
abstract ChannelGroup(Int) from Int to Int {
    public static inline var NULL:ChannelGroup = cast 0;

    /** DSP chain positions for addDsp. */
    public static inline var DSP_HEAD:Int = -1;
    public static inline var DSP_FADER:Int = -2;
    public static inline var DSP_TAIL:Int = -3;

    /** The master group (the final mix). One shared handle per session. */
    public static inline function master():ChannelGroup {
        return NativeStudio.cg_get_master();
    }

    /** Creates a custom group. Returns ChannelGroup.NULL on failure. */
    public static inline function create(name:String):ChannelGroup {
        return NativeStudio.cg_create(name);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    public inline function getVolume():Float {
        return NativeStudio.cg_get_volume(this);
    }

    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.cg_set_volume(this, volume);
    }

    public inline function getPitch():Float {
        return NativeStudio.cg_get_pitch(this);
    }

    public inline function setPitch(pitch:Float):FmodResult {
        return NativeStudio.cg_set_pitch(this, pitch);
    }

    public inline function getMute():Bool {
        return NativeStudio.cg_get_mute(this);
    }

    public inline function setMute(mute:Bool):FmodResult {
        return NativeStudio.cg_set_mute(this, mute);
    }

    public inline function getPaused():Bool {
        return NativeStudio.cg_get_paused(this);
    }

    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.cg_set_paused(this, paused);
    }

    /** Inserts an effect at index (0 = head of the chain, or a DSP_* position). */
    public inline function addDsp(index:Int, dsp:Dsp):FmodResult {
        return NativeStudio.cg_add_dsp(this, index, dsp);
    }

    public inline function removeDsp(dsp:Dsp):FmodResult {
        return NativeStudio.cg_remove_dsp(this, dsp);
    }

    /** Stops every channel in the group. */
    public inline function stop():FmodResult {
        return NativeStudio.cg_stop(this);
    }

    /** Routes a child group's output through this one (group hierarchies). */
    public inline function addGroup(child:ChannelGroup):FmodResult {
        return NativeStudio.cg_add_group(this, child);
    }

    public inline function getGroupCount():Int {
        return NativeStudio.cg_get_num_groups(this);
    }

    /** A nested child group by index (a known group returns its existing handle). */
    public inline function getGroup(index:Int):ChannelGroup {
        return NativeStudio.cg_get_group(this, index);
    }

    public inline function getParentGroup():ChannelGroup {
        return NativeStudio.cg_get_parent_group(this);
    }

    /**
     * The group's mixer clock in output samples, or null on failure.
     * `clock` is this group's own time, `parent` the enclosing group's,
     * which is the timeline setDelay and fade points schedule against.
     */
    public function getDspClock():Null<{clock:Float, parent:Float}> {
        var result:FmodResult = NativeStudio.cg_get_dsp_clock(this);
        if (!result.isOk()) return null;
        return {clock: Scratch.readF(0), parent: Scratch.readF(1)};
    }

    /** Sample-accurate start/stop window on the parent clock (0 = no bound). */
    public inline function setDelay(startClock:Float, endClock:Float, stopChannels:Bool = false):FmodResult {
        return NativeStudio.cg_set_delay(this, startClock, endClock, stopChannels);
    }

    /** Schedules a volume point at a parent-clock time. FMOD ramps between points. */
    public inline function addFadePoint(clock:Float, volume:Float):FmodResult {
        return NativeStudio.cg_add_fade_point(this, clock, volume);
    }

    /** A click-free ramp from the current volume to `volume`, ending at `clock`. */
    public inline function setFadePointRamp(clock:Float, volume:Float):FmodResult {
        return NativeStudio.cg_set_fade_point_ramp(this, clock, volume);
    }

    public inline function removeFadePoints(startClock:Float, endClock:Float):FmodResult {
        return NativeStudio.cg_remove_fade_points(this, startClock, endClock);
    }

    /** Constant-power stereo pan over the whole group. */
    public inline function setPan(pan:Float):FmodResult {
        return NativeStudio.cg_set_pan(this, pan);
    }

    /**
     * A built-in lowpass on the group (1.0 = open, 0.0 = closed). The
     * matching getter is channel-only (its group binding misreads on
     * HTML5, see the platform notes).
     */
    public inline function setLowPassGain(gain:Float):FmodResult {
        return NativeStudio.cg_set_low_pass_gain(this, gain);
    }

    /** Combines ChannelMode flags (looping, 2D/3D, rolloff shape). */
    public inline function setMode(mode:Int):FmodResult {
        return NativeStudio.cg_set_mode(this, mode);
    }

    public inline function getMode():Int {
        return NativeStudio.cg_get_mode(this);
    }

    /** Positions the whole group in 3D space (needs a 3D mode set). */
    public inline function set3DAttributes(posX:Float, posY:Float, posZ:Float,
            velX:Float = 0, velY:Float = 0, velZ:Float = 0):FmodResult {
        return NativeStudio.cg_set_3d_attributes(this, posX, posY, posZ, velX, velY, velZ);
    }

    public function get3DAttributes():Null<{posX:Float, posY:Float, posZ:Float, velX:Float, velY:Float, velZ:Float}> {
        var result:FmodResult = NativeStudio.cg_get_3d_attributes(this);
        if (!result.isOk()) return null;
        return {posX: Scratch.readF(0), posY: Scratch.readF(1), posZ: Scratch.readF(2),
            velX: Scratch.readF(3), velY: Scratch.readF(4), velZ: Scratch.readF(5)};
    }

    public inline function set3DMinMaxDistance(minDistance:Float, maxDistance:Float):FmodResult {
        return NativeStudio.cg_set_3d_min_max(this, minDistance, maxDistance);
    }

    public function get3DMinMaxDistance():Null<{minDistance:Float, maxDistance:Float}> {
        var result:FmodResult = NativeStudio.cg_get_3d_min_max(this);
        if (!result.isOk()) return null;
        return {minDistance: Scratch.readF(0), maxDistance: Scratch.readF(1)};
    }

    /**
     * Muffles the group as if behind an obstacle. The matching getter is
     * channel-only (its group binding misreads on HTML5).
     */
    public inline function set3DOcclusion(direct:Float, reverb:Float):FmodResult {
        return NativeStudio.cg_set_3d_occlusion(this, direct, reverb);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Replaces the distance rolloff curve with the given points. Each
     * point's x is the distance and y the volume (0 to 1), sorted by
     * distance. An empty array restores the mode-driven rolloff
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). The
     * binding keeps its own copy of the points for the group's
     * lifetime.
     */
    public macro function set3DCustomRolloff(self:haxe.macro.Expr, points:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("ChannelGroup.set3DCustomRolloff", "the web boundary rejects custom rolloff points");
    }
    #else
    /**
     * Replaces the distance rolloff curve with the given points. Each
     * point's x is the distance and y the volume (0 to 1), sorted by
     * distance. An empty array restores the mode-driven rolloff
     * (unsupported in HTML5, returns FMOD_ERR_UNSUPPORTED). The
     * binding keeps its own copy of the points for the group's
     * lifetime.
     */
    public function set3DCustomRolloff(points:Array<FmodVector>):FmodResult {
        var packed = Scratch.packVectors(points);
        return NativeStudio.cg_set_3d_custom_rolloff(this, packed, packed == null ? 0 : points.length);
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The custom rolloff points (unsupported in HTML5, always empty
     * there), empty when none are set or on failure (see
     * StudioSystem.lastResult). Capped at Scratch.VECTOR_CAPACITY points.
     */
    public macro function get3DCustomRolloff(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("ChannelGroup.get3DCustomRolloff", "custom rolloff points cannot be set in the web build, so there is nothing to read");
    }
    #else
    /**
     * The custom rolloff points (unsupported in HTML5, always empty
     * there), empty when none are set or on failure (see
     * StudioSystem.lastResult). Capped at Scratch.VECTOR_CAPACITY points.
     */
    public function get3DCustomRolloff():Array<FmodVector> {
        var count = NativeStudio.cg_get_3d_custom_rolloff(this);
        if (count <= 0) return [];
        return Scratch.readVectors(count);
    }
    #end

    /**
     * Overrides the distance lowpass on this group's 3D channels. With
     * custom on, customLevel (0 to 1) replaces the distance-derived
     * attenuation and centerFreq sets the filter's center in Hz. The
     * distanceFilter setting must be on at init for any of this to take
     * effect.
     */
    public inline function set3DDistanceFilter(custom:Bool, customLevel:Float, centerFreq:Float):FmodResult {
        return NativeStudio.cg_set_3d_distance_filter(this, custom, customLevel, centerFreq);
    }

    public function get3DDistanceFilter():Null<{custom:Bool, customLevel:Float, centerFreq:Float}> {
        var result:FmodResult = NativeStudio.cg_get_3d_distance_filter(this);
        if (!result.isOk()) return null;
        return {custom: Scratch.readF(0) != 0, customLevel: Scratch.readF(1), centerFreq: Scratch.readF(2)};
    }

    public inline function set3DLevel(level:Float):FmodResult {
        return NativeStudio.cg_set_3d_level(this, level);
    }

    public inline function get3DLevel():Float {
        return NativeStudio.cg_get_3d_level(this);
    }

    public inline function set3DSpread(angle:Float):FmodResult {
        return NativeStudio.cg_set_3d_spread(this, angle);
    }

    public inline function get3DSpread():Float {
        return NativeStudio.cg_get_3d_spread(this);
    }

    public inline function set3DDopplerLevel(level:Float):FmodResult {
        return NativeStudio.cg_set_3d_doppler_level(this, level);
    }

    public inline function get3DDopplerLevel():Float {
        return NativeStudio.cg_get_3d_doppler_level(this);
    }

    public inline function set3DConeSettings(insideAngle:Float, outsideAngle:Float, outsideVolume:Float):FmodResult {
        return NativeStudio.cg_set_3d_cone_settings(this, insideAngle, outsideAngle, outsideVolume);
    }

    public function get3DConeSettings():Null<{insideAngle:Float, outsideAngle:Float, outsideVolume:Float}> {
        var result:FmodResult = NativeStudio.cg_get_3d_cone_settings(this);
        if (!result.isOk()) return null;
        return {insideAngle: Scratch.readF(0), outsideAngle: Scratch.readF(1), outsideVolume: Scratch.readF(2)};
    }

    public inline function set3DConeOrientation(x:Float, y:Float, z:Float):FmodResult {
        return NativeStudio.cg_set_3d_cone_orientation(this, x, y, z);
    }

    public function get3DConeOrientation():Null<{x:Float, y:Float, z:Float}> {
        var result:FmodResult = NativeStudio.cg_get_3d_cone_orientation(this);
        if (!result.isOk()) return null;
        return {x: Scratch.readF(0), y: Scratch.readF(1), z: Scratch.readF(2)};
    }

    /** How much this group feeds a reverb instance (0.0 = none, 1.0 = full). */
    public inline function setReverbWet(instance:Int, wet:Float):FmodResult {
        return NativeStudio.cg_set_reverb_wet(this, instance, wet);
    }

    public inline function getReverbWet(instance:Int):Float {
        return NativeStudio.cg_get_reverb_wet(this, instance);
    }

    /** Routes inputs to speakers with explicit gains (row-major, up to 32x32). */
    public function setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int):FmodResult {
        var total = outChannels * inChannels;
        if (total < 0 || total > matrix.length || total > Scratch.CAPACITY) {
            return haxefmod.studio.FmodResult.FMOD_ERR_INVALID_PARAM;
        }
        for (i in 0...total) Scratch.writeF(i, matrix[i]);
        return NativeStudio.cg_set_mix_matrix(this, outChannels, inChannels);
    }

    /** Short volume ramping on changes (on by default, prevents clicks). */
    public inline function setVolumeRamp(ramp:Bool):FmodResult {
        return NativeStudio.cg_set_volume_ramp(this, ramp);
    }

    public inline function getVolumeRamp():Bool {
        return NativeStudio.cg_get_volume_ramp(this);
    }

    /** The final audible volume after parent groups and 3D scaling. */
    public inline function getAudibility():Float {
        return NativeStudio.cg_get_audibility(this);
    }

    /** Moves an attached effect to another chain position (0 = head). */
    public inline function setDspIndex(dsp:Dsp, index:Int):haxefmod.studio.FmodResult {
        return NativeStudio.cg_set_dsp_index(this, dsp, index);
    }

    /** The chain position of an attached effect, -1 when it is not attached or on failure. */
    public inline function getDspIndex(dsp:Dsp):Int {
        return NativeStudio.cg_get_dsp_index(this, dsp);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The scheduled fade points as parent-clock and volume pairs
     * (unsupported in HTML5, null there). Null on failure, at most
     * Scratch.CAPACITY / 2 points.
     */
    public macro function getFadePoints(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("ChannelGroup.getFadePoints", "FMOD's web glue never returns the fade point arrays");
    }
    #else
    /**
     * The scheduled fade points as parent-clock and volume pairs
     * (unsupported in HTML5, null there). Null on failure, at most
     * Scratch.CAPACITY / 2 points.
     */
    public function getFadePoints():Null<Array<{clock:Float, volume:Float}>> {
        var count = NativeStudio.cg_get_fade_points(this);
        var result:haxefmod.studio.FmodResult = haxefmod.studio.StudioSystem.lastResult();
        if (!result.isOk()) return null;
        return [for (i in 0...count) {clock: Scratch.readF(i * 2), volume: Scratch.readF(i * 2 + 1)}];
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads back the mix matrix region of outChannels rows by inChannels
     * gains, row-major (unsupported in HTML5, null there). The returned
     * outChannels and inChannels are the counts FMOD reports for the
     * group. Null on failure or for sizes outside 1..32.
     */
    public macro function getMixMatrix(self:haxe.macro.Expr, outChannels:haxe.macro.Expr, inChannels:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("ChannelGroup.getMixMatrix", "FMOD's web glue binds the matrix as a single float");
    }
    #else
    /**
     * Reads back the mix matrix region of outChannels rows by inChannels
     * gains, row-major (unsupported in HTML5, null there). The returned
     * outChannels and inChannels are the counts FMOD reports for the
     * group. Null on failure or for sizes outside 1..32.
     */
    public function getMixMatrix(outChannels:Int, inChannels:Int):Null<{matrix:Array<Float>, outChannels:Int, inChannels:Int}> {
        var total = NativeStudio.cg_get_mix_matrix(this, outChannels, inChannels);
        if (total <= 0) return null;
        return {matrix: [for (i in 0...total) Scratch.readF(i)], outChannels: Scratch.readI(0), inChannels: Scratch.readI(1)};
    }
    #end

    public inline function getName():String {
        return NativeStudio.cg_get_name(this);
    }

    public inline function getChannelCount():Int {
        return NativeStudio.cg_get_num_channels(this);
    }

    /** A channel routed into this group by index (known channels dedup). */
    public inline function getChannel(index:Int):Channel {
        return NativeStudio.cg_get_channel(this, index);
    }

    /**
     * Frees a group made with create() and invalidates this handle. Do not
     * release the master group or a Studio bus's group.
     */
    public inline function release():FmodResult {
        UserData.clear(UserDataKind.ChannelGroup, this);
        return NativeStudio.cg_release(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.ChannelGroup, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.ChannelGroup, this);
    }
}
