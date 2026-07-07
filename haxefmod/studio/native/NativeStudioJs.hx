package haxefmod.studio.native;

#if js
/**
 * JavaScript (Emscripten) backend for the FMOD Studio bindings.
 * Raw functions live in jaxe.js (shipped as a lime dependency script).
 */
class NativeStudioJs {
    // System
    public static inline function sys_last_result():Int return Raw.fmod_sys_last_result();
    public static inline function sys_get_bus(path:String):Int return Raw.fmod_sys_get_bus(path);

    // Bus
    public static inline function bus_is_valid(handle:Int):Bool return Raw.fmod_bus_is_valid(handle);
    public static inline function bus_get_id(handle:Int):String return Raw.fmod_bus_get_id(handle);
    public static inline function bus_get_path(handle:Int):String return Raw.fmod_bus_get_path(handle);
    public static inline function bus_get_volume(handle:Int):Float return Raw.fmod_bus_get_volume(handle);
    public static inline function bus_get_final_volume(handle:Int):Float return Raw.fmod_bus_get_final_volume(handle);
    public static inline function bus_set_volume(handle:Int, volume:Float):Int return Raw.fmod_bus_set_volume(handle, volume);
    public static inline function bus_get_paused(handle:Int):Bool return Raw.fmod_bus_get_paused(handle);
    public static inline function bus_set_paused(handle:Int, paused:Bool):Int return Raw.fmod_bus_set_paused(handle, paused);
    public static inline function bus_get_mute(handle:Int):Bool return Raw.fmod_bus_get_mute(handle);
    public static inline function bus_set_mute(handle:Int, mute:Bool):Int return Raw.fmod_bus_set_mute(handle, mute);
    public static inline function bus_stop_all_events(handle:Int, stopMode:Int):Int return Raw.fmod_bus_stop_all_events(handle, stopMode);

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive (microseconds) */
    public static inline function bus_get_cpu_usage(handle:Int):Int return Raw.fmod_bus_get_cpu_usage(handle, Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function bus_get_memory_usage(handle:Int):Int return Raw.fmod_bus_get_memory_usage(handle, Scratch.intBuf());

    // Debug
    public static inline function debug_live_handle_count():Int return Raw.fmod_debug_live_handle_count();
}

@:native("jaxe")
private extern class Raw {
    static function fmod_sys_last_result():Int;
    static function fmod_sys_get_bus(path:String):Int;
    static function fmod_bus_is_valid(handle:Int):Bool;
    static function fmod_bus_get_id(handle:Int):String;
    static function fmod_bus_get_path(handle:Int):String;
    static function fmod_bus_get_volume(handle:Int):Float;
    static function fmod_bus_get_final_volume(handle:Int):Float;
    static function fmod_bus_set_volume(handle:Int, volume:Float):Int;
    static function fmod_bus_get_paused(handle:Int):Bool;
    static function fmod_bus_set_paused(handle:Int, paused:Bool):Int;
    static function fmod_bus_get_mute(handle:Int):Bool;
    static function fmod_bus_set_mute(handle:Int, mute:Bool):Int;
    static function fmod_bus_stop_all_events(handle:Int, stopMode:Int):Int;
    static function fmod_bus_get_cpu_usage(handle:Int, out:Array<Int>):Int;
    static function fmod_bus_get_memory_usage(handle:Int, out:Array<Int>):Int;
    static function fmod_debug_live_handle_count():Int;
}
#end
