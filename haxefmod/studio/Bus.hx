package haxefmod.studio;

import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD Studio bus.
 *
 * Obtain via StudioSystem.getBus("bus:/..."). Handles are plain ints under
 * the hood. A stale or invalid handle makes every call a safe no-op (getters
 * return defaults, setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Bus(Int) from Int to Int {
    public static inline var NULL:Bus = cast 0;

    /** True if this is the invalid handle (lookup failed). */
    public inline function isNull():Bool {
        return this == 0;
    }

    /** True if the handle resolves to a live FMOD bus. */
    public inline function isValid():Bool {
        return this != 0 && NativeStudio.bus_is_valid(this);
    }

    /** The bus GUID as a string, e.g. "{1f687138-e06c-40f5-9bac-57f84bbcedd3}". */
    public inline function getID():String {
        return NativeStudio.bus_get_id(this);
    }

    /** The full bus path, e.g. "bus:/Music". */
    public inline function getPath():String {
        return NativeStudio.bus_get_path(this);
    }

    /** The volume as set by the API (linear: 0.0 = silent, 1.0 = full). */
    public inline function getVolume():Float {
        return NativeStudio.bus_get_volume(this);
    }

    /** The final combined volume (set volume x snapshots/automation). */
    public inline function getFinalVolume():Float {
        return NativeStudio.bus_get_final_volume(this);
    }

    public inline function setVolume(volume:Float):FmodResult {
        return NativeStudio.bus_set_volume(this, volume);
    }

    public inline function getPaused():Bool {
        return NativeStudio.bus_get_paused(this);
    }

    public inline function setPaused(paused:Bool):FmodResult {
        return NativeStudio.bus_set_paused(this, paused);
    }

    public inline function getMute():Bool {
        return NativeStudio.bus_get_mute(this);
    }

    public inline function setMute(mute:Bool):FmodResult {
        return NativeStudio.bus_set_mute(this, mute);
    }

    /** Stops all events routed through this bus. */
    public inline function stopAllEvents(stopMode:FmodStopMode = ALLOWFADEOUT):FmodResult {
        return NativeStudio.bus_stop_all_events(this, stopMode);
    }

    /** CPU usage of this bus, or null on failure. Requires profiling enabled. */
    public function getCpuUsage():Null<FmodCpuUsage> {
        var result:FmodResult = NativeStudio.bus_get_cpu_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1)};
    }

    /** Memory usage of this bus, or null on failure. */
    public function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.bus_get_memory_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }

    /**
     * Forces the bus's core channel group to exist so effects can attach
     * to it (see getChannelGroup). Call unlockChannelGroup when done.
     */
    public inline function lockChannelGroup():FmodResult {
        return NativeStudio.bus_lock_channel_group(this);
    }

    public inline function unlockChannelGroup():FmodResult {
        return NativeStudio.bus_unlock_channel_group(this);
    }

    /**
     * The core channel group carrying this bus's audio, for attaching DSP
     * effects to Studio-mixed sound. Lock it first, and never release it
     * (the bus owns it). Returns ChannelGroup.NULL on failure.
     */
    public inline function getChannelGroup():haxefmod.core.ChannelGroup {
        return NativeStudio.bus_get_channel_group(this);
    }
}
