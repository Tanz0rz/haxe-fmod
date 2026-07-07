package haxefmod.studio;

import haxefmod.studio.native.NativeStudio;

/**
 * Entry point for the FMOD Studio bindings.
 *
 * There is exactly one FMOD Studio system per process (created by
 * FmodManager.Initialize), so this class is all statics. It is the escape
 * hatch for anything the high-level API does not cover:
 *
 *   import haxefmod.studio.StudioSystem;
 *   var music = StudioSystem.getBus("bus:/Music");
 *   music.setVolume(0.5);
 */
class StudioSystem {
    /** One handle per bus path - repeated lookups return the cached handle. */
    static var busCache:Map<String, Bus> = new Map();

    /**
     * Looks up a bus by path (e.g. "bus:/" for the master bus).
     * Returns Bus.NULL if the system is not initialized or the path is
     * unknown; check lastResult() for the reason.
     */
    public static function getBus(path:String):Bus {
        if (busCache.exists(path)) {
            return busCache.get(path);
        }
        var bus:Bus = NativeStudio.sys_get_bus(path);
        if (!bus.isNull()) {
            busCache.set(path, bus);
        }
        return bus;
    }

    /** Result of the most recent studio binding call. */
    public static function lastResult():FmodResult {
        return NativeStudio.sys_last_result();
    }

    /** Number of live native handles - useful for leak checks in tests. */
    public static function liveHandleCount():Int {
        return NativeStudio.debug_live_handle_count();
    }
}
