package haxefmod.core;

import haxefmod.studio.FmodResult;
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

    /**
     * Frees a group made with create() and invalidates this handle. Do not
     * release the master group or a Studio bus's group.
     */
    public inline function release():FmodResult {
        return NativeStudio.cg_release(this);
    }
}
