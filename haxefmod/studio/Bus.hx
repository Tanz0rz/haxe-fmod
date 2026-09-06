package haxefmod.studio;

import haxefmod.studio.Types;
import haxefmod.studio.UserData;
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

    /** The bus GUID. */
    public inline function getID():FmodGuid {
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

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** CPU usage of this bus, or null on failure. Needs the profiling setting on at init (unsupported in HTML5, null there). */
    public macro function getCpuUsage(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Bus.getCpuUsage", "FMOD's JavaScript API does not expose per-object CPU usage");
    }
    #else
    /** CPU usage of this bus, or null on failure. Needs the profiling setting on at init (unsupported in HTML5, null there). */
    public function getCpuUsage():Null<FmodCpuUsage> {
        var result:FmodResult = NativeStudio.bus_get_cpu_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1)};
    }
    #end

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /** Memory usage of this bus, or null on failure (unsupported in HTML5, null there). */
    public macro function getMemoryUsage(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Bus.getMemoryUsage", "FMOD's JavaScript API does not expose memory usage");
    }
    #else
    /** Memory usage of this bus, or null on failure (unsupported in HTML5, null there). */
    public function getMemoryUsage():Null<FmodMemoryUsage> {
        var result:FmodResult = NativeStudio.bus_get_memory_usage(this);
        if (!result.isOk()) return null;
        return {exclusive: Scratch.readI(0), inclusive: Scratch.readI(1), sampledata: Scratch.readI(2)};
    }
    #end

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

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * The output port this bus is assigned to, FmodPortIndex.NONE when it
     * plays through the main mix (unsupported in HTML5, NONE there). FMOD
     * routes buses to ports on consoles only, desktop reports NONE.
     */
    public macro function getPortIndex(self:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Bus.getPortIndex", "the web build has no bus port index");
    }
    #else
    /**
     * The output port this bus is assigned to, FmodPortIndex.NONE when it
     * plays through the main mix (unsupported in HTML5, NONE there). FMOD
     * routes buses to ports on consoles only, desktop reports NONE.
     */
    public inline function getPortIndex():FmodPortIndex {
        return NativeStudio.bus_get_port_index(this);
    }
    #end

#if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Assigns this bus to an output port, FmodPortIndex.NONE for the main
     * mix (unsupported in HTML5). FMOD routes buses to ports on consoles
     * only, desktop returns FMOD_ERR_UNSUPPORTED. The bus's channel group
     * is recreated on the port, so effects attached to it are dropped.
     */
    public macro function setPortIndex(self:haxe.macro.Expr, index:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("Bus.setPortIndex", "the web build has no bus port index");
    }
    #else
    /**
     * Assigns this bus to an output port, FmodPortIndex.NONE for the main
     * mix (unsupported in HTML5). FMOD routes buses to ports on consoles
     * only, desktop returns FMOD_ERR_UNSUPPORTED. The bus's channel group
     * is recreated on the port, so effects attached to it are dropped.
     */
    public inline function setPortIndex(index:FmodPortIndex):FmodResult {
        return NativeStudio.bus_set_port_index(this, index);
    }
    #end

    /**
     * The core channel group carrying this bus's audio, for attaching DSP
     * effects to Studio-mixed sound. Lock it first, and never release it
     * (the bus owns it). Returns ChannelGroup.NULL on failure.
     */
    public inline function getChannelGroup():haxefmod.core.ChannelGroup {
        return NativeStudio.bus_get_channel_group(this);
    }

    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.Bus, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.Bus, this);
    }
}
