package haxefmod.studio.native;

#if cpp
/**
 * C++ (hxcpp) backend for the FMOD Studio bindings.
 * Converts const char* returns to Haxe String at the boundary; raw functions
 * live in linc_faxe.cpp.
 *
 * Note: build wiring (linc buildXml) currently comes from CppBackend, which
 * is always compiled via FmodManager. When the legacy backends are deleted,
 * the CppBackend_Linc build metas move to this class.
 */
class NativeStudioCpp {
    // System
    public static inline function sys_last_result():Int return Raw.sys_last_result();
    public static inline function sys_get_bus(path:String):Int return Raw.sys_get_bus(path);

    // Bus
    public static inline function bus_is_valid(handle:Int):Bool return Raw.bus_is_valid(handle);
    public static inline function bus_get_id(handle:Int):String return Raw.bus_get_id(handle).toString();
    public static inline function bus_get_path(handle:Int):String return Raw.bus_get_path(handle).toString();
    public static inline function bus_get_volume(handle:Int):Float return Raw.bus_get_volume(handle);
    public static inline function bus_get_final_volume(handle:Int):Float return Raw.bus_get_final_volume(handle);
    public static inline function bus_set_volume(handle:Int, volume:Float):Int return Raw.bus_set_volume(handle, volume);
    public static inline function bus_get_paused(handle:Int):Bool return Raw.bus_get_paused(handle);
    public static inline function bus_set_paused(handle:Int, paused:Bool):Int return Raw.bus_set_paused(handle, paused);
    public static inline function bus_get_mute(handle:Int):Bool return Raw.bus_get_mute(handle);
    public static inline function bus_set_mute(handle:Int, mute:Bool):Int return Raw.bus_set_mute(handle, mute);
    public static inline function bus_stop_all_events(handle:Int, stopMode:Int):Int return Raw.bus_stop_all_events(handle, stopMode);

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive (microseconds) */
    public static inline function bus_get_cpu_usage(handle:Int):Int return Raw.bus_get_cpu_usage(handle, Scratch.intBuf());

    /** Fills Scratch int buffer: [0]=exclusive, [1]=inclusive, [2]=sampledata (bytes) */
    public static inline function bus_get_memory_usage(handle:Int):Int return Raw.bus_get_memory_usage(handle, Scratch.intBuf());

    // Debug
    public static inline function debug_live_handle_count():Int return Raw.debug_live_handle_count();
}

@:keep
@:include("linc_faxe.h")
private extern class Raw {
    @:native("linc::faxe::fmod_sys_last_result")
    static function sys_last_result():Int;

    @:native("linc::faxe::fmod_sys_get_bus")
    static function sys_get_bus(path:String):Int;

    @:native("linc::faxe::fmod_bus_is_valid")
    static function bus_is_valid(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_get_id")
    static function bus_get_id(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bus_get_path")
    static function bus_get_path(handle:Int):cpp.ConstCharStar;

    @:native("linc::faxe::fmod_bus_get_volume")
    static function bus_get_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_bus_get_final_volume")
    static function bus_get_final_volume(handle:Int):Float;

    @:native("linc::faxe::fmod_bus_set_volume")
    static function bus_set_volume(handle:Int, volume:Float):Int;

    @:native("linc::faxe::fmod_bus_get_paused")
    static function bus_get_paused(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_set_paused")
    static function bus_set_paused(handle:Int, paused:Bool):Int;

    @:native("linc::faxe::fmod_bus_get_mute")
    static function bus_get_mute(handle:Int):Bool;

    @:native("linc::faxe::fmod_bus_set_mute")
    static function bus_set_mute(handle:Int, mute:Bool):Int;

    @:native("linc::faxe::fmod_bus_stop_all_events")
    static function bus_stop_all_events(handle:Int, stopMode:Int):Int;

    @:native("linc::faxe::fmod_bus_get_cpu_usage")
    static function bus_get_cpu_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_bus_get_memory_usage")
    static function bus_get_memory_usage(handle:Int, out:Array<Int>):Int;

    @:native("linc::faxe::fmod_debug_live_handle_count")
    static function debug_live_handle_count():Int;
}
#end
