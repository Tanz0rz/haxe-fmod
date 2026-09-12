package haxefmod.studio;

import haxefmod.core.Sound;
/**
 * The handle families that can carry user data. Each family has its own
 * map because handle ints from different native types can collide. Plain
 * ints rather than an enum so the names do not shadow the abstracts in
 * files that import this module.
 */
@:dox(hide)
class UserDataKind {
    public static inline var EventDescription:Int = 0;
    public static inline var EventInstance:Int = 1;
    public static inline var Bank:Int = 2;
    public static inline var Bus:Int = 3;
    public static inline var Vca:Int = 4;
    public static inline var CommandReplay:Int = 5;
    public static inline var Sound:Int = 6;
    public static inline var Channel:Int = 7;
    public static inline var ChannelGroup:Int = 8;
    public static inline var Dsp:Int = 9;
    public static inline var DspConnection:Int = 10;
    public static inline var SoundGroup:Int = 11;
    public static inline var Reverb3D:Int = 12;
    public static inline var Geometry:Int = 13;
    public static inline var PcmStream:Int = 14;

    public static inline var COUNT:Int = 15;
}

/**
 * Haxe-side storage behind the setUserData / getUserData pair on every
 * handle abstract. FMOD's own userdata slot holds a raw pointer, which
 * cannot carry a Haxe value across the binding. The value therefore lives
 * here keyed by the handle int instead.
 *
 * The store drops an entry when the handle is released through the
 * abstract (release, stop, unload). FMOD has to accept the release or
 * report the handle dead already. A refused release keeps the object,
 * so the entry stays with it. An event instance or a channel drops its
 * entry before the call, since those calls fail on a dead handle only.
 * It also drops the entry when the dispatcher delivers Destroyed for an
 * event instance FMOD tore down on its own. End does the same for a
 * channel with a handler. On HTML5 Destroyed never arrives, so the dispatcher drops the
 * entries of dead instance handles each update instead. The native handle
 * table recycles a slot with a new generation. A reused slot produces a
 * different handle int, so a stale entry does not show up on the next
 * handle in that slot. Entries for handles that die without passing through one
 * of those paths (a channel with no handler that ends by itself) linger until
 * clearAll.
 */
@:dox(hide)
class UserData {
    static var maps:Array<Map<Int, Dynamic>> = [for (i in 0...UserDataKind.COUNT) new Map()];

    /** The value attached to the studio system itself. */
    public static var systemValue:Dynamic = null;

    public static function set(kind:Int, handle:Int, value:Dynamic):Void {
        if (handle == 0) return;
        if (value == null) {
            maps[kind].remove(handle);
        } else {
            maps[kind].set(handle, value);
        }
    }

    public static function get(kind:Int, handle:Int):Dynamic {
        if (handle == 0) return null;
        return maps[kind].get(handle);
    }

    public static function has(kind:Int, handle:Int):Bool {
        return handle != 0 && maps[kind].exists(handle);
    }

    public static function clear(kind:Int, handle:Int):Void {
        maps[kind].remove(handle);
    }

    /**
     * True when a release result means the object is gone: FMOD accepted
     * it, or the handle was dead already. A refused release, for example
     * on a sound the library owns, keeps the object and its entry.
     */
    public static inline function releaseTookEffect(result:FmodResult):Bool {
        return result.isOk() || result == FmodResult.FMOD_ERR_INVALID_HANDLE;
    }

    /** Drops every entry of one family. */
    public static function clearKind(kind:Int):Void {
        maps[kind] = new Map();
    }

    /** Drops every entry of every family and the system value. */
    public static function clearAll():Void {
        maps = [for (i in 0...UserDataKind.COUNT) new Map()];
        systemValue = null;
    }

    #if js
    /**
     * Drops the event instance entries whose handle does not resolve.
     * FMOD's web glue never delivers Destroyed (the js backend uninstalls
     * callbacks before every destruction path). The backend's handle sweep
     * instead reclaims an instance FMOD tore down on its own, and the
     * dispatcher calls this each update to drop its entry.
     */
    @:allow(haxefmod.studio.CallbackDispatcher)
    static function dropDeadInstances():Void {
        var map = maps[UserDataKind.EventInstance];
        var dead:Array<Int> = [];
        for (handle in map.keys()) {
            if (!haxefmod.studio.native.NativeStudio.evi_is_valid(handle)) dead.push(handle);
        }
        for (handle in dead) map.remove(handle);
    }
    #end

    /** Number of stored entries across all families. Used by tests. */
    public static function count():Int {
        var n = 0;
        for (m in maps) for (_ in m) n++;
        return n;
    }
}
