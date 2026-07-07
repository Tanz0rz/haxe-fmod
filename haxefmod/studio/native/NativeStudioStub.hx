package haxefmod.studio.native;

/**
 * Stub backend for targets without a native FMOD shim (eval/interp, used by
 * unit tests). Every call is a safe no-op: results report
 * FMOD_ERR_UNSUPPORTED, lookups return the invalid handle 0.
 */
class NativeStudioStub {
    static inline var ERR_UNSUPPORTED = 68;

    // System
    public static function sys_last_result():Int return ERR_UNSUPPORTED;
    public static function sys_get_bus(path:String):Int return 0;

    // Bus
    public static function bus_is_valid(handle:Int):Bool return false;
    public static function bus_get_id(handle:Int):String return "";
    public static function bus_get_path(handle:Int):String return "";
    public static function bus_get_volume(handle:Int):Float return 0.0;
    public static function bus_get_final_volume(handle:Int):Float return 0.0;
    public static function bus_set_volume(handle:Int, volume:Float):Int return ERR_UNSUPPORTED;
    public static function bus_get_paused(handle:Int):Bool return false;
    public static function bus_set_paused(handle:Int, paused:Bool):Int return ERR_UNSUPPORTED;
    public static function bus_get_mute(handle:Int):Bool return false;
    public static function bus_set_mute(handle:Int, mute:Bool):Int return ERR_UNSUPPORTED;
    public static function bus_stop_all_events(handle:Int, stopMode:Int):Int return ERR_UNSUPPORTED;
    public static function bus_get_cpu_usage(handle:Int):Int return ERR_UNSUPPORTED;
    public static function bus_get_memory_usage(handle:Int):Int return ERR_UNSUPPORTED;

    // Debug
    public static function debug_live_handle_count():Int return 0;
}
