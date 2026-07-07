package haxefmod.studio.native;

#if hl
/**
 * HashLink backend for the FMOD Studio bindings.
 * Converts String to hl.Bytes at the boundary; raw prims live in hlaxe_fmod.c.
 */
class NativeStudioHl {
    static inline function toBytes(text:String):hl.Bytes {
        return @:privateAccess text.toUtf8();
    }

    static inline function fromBytes(bytes:hl.Bytes):String {
        return bytes == null ? "" : @:privateAccess String.fromUTF8(bytes);
    }

    // System
    public static inline function sys_last_result():Int return Raw.sys_last_result();
    public static inline function sys_get_bus(path:String):Int return Raw.sys_get_bus(toBytes(path));

    // Bus
    public static inline function bus_is_valid(handle:Int):Bool return Raw.bus_is_valid(handle);
    public static inline function bus_get_id(handle:Int):String return fromBytes(Raw.bus_get_id(handle));
    public static inline function bus_get_path(handle:Int):String return fromBytes(Raw.bus_get_path(handle));
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

@:hlNative("hlaxe_fmod")
private extern class Raw {
    static function sys_last_result():Int;
    static function sys_get_bus(path:hl.Bytes):Int;
    static function bus_is_valid(handle:Int):Bool;
    static function bus_get_id(handle:Int):hl.Bytes;
    static function bus_get_path(handle:Int):hl.Bytes;
    static function bus_get_volume(handle:Int):Float;
    static function bus_get_final_volume(handle:Int):Float;
    static function bus_set_volume(handle:Int, volume:Float):Int;
    static function bus_get_paused(handle:Int):Bool;
    static function bus_set_paused(handle:Int, paused:Bool):Int;
    static function bus_get_mute(handle:Int):Bool;
    static function bus_set_mute(handle:Int, mute:Bool):Int;
    static function bus_stop_all_events(handle:Int, stopMode:Int):Int;
    static function bus_get_cpu_usage(handle:Int, out:hl.Bytes):Int;
    static function bus_get_memory_usage(handle:Int, out:hl.Bytes):Int;
    static function debug_live_handle_count():Int;
}
#end
