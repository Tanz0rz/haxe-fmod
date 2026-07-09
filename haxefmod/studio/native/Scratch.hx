package haxefmod.studio.native;

/**
 * Reusable scratch buffers for struct out-params crossing the FFI boundary.
 *
 * The NativeStudio wrappers pass these buffers to native functions; callers
 * read results back via readI/readF immediately after the call. Only ever
 * touched from the Haxe thread, so a single static buffer per type is safe.
 *
 * Capacity is 64 slots each - list-returning bindings (bank_get_event_list
 * and friends) cap their output at this size.
 */
class Scratch {
    public static inline var CAPACITY:Int = 64;

    #if hl
    static var ints:hl.Bytes = null;
    static var floats:hl.Bytes = null;

    public static function intBuf():hl.Bytes {
        if (ints == null) ints = new hl.Bytes(CAPACITY * 4);
        return ints;
    }

    public static inline function readI(index:Int):Int {
        return ints.getI32(index * 4);
    }

    public static function floatBuf():hl.Bytes {
        if (floats == null) floats = new hl.Bytes(CAPACITY * 8);
        return floats;
    }

    public static inline function readF(index:Int):Float {
        return floats.getF64(index * 8);
    }
    #else
    static var ints:Array<Int> = [for (_ in 0...CAPACITY) 0];
    static var floats:Array<Float> = [for (_ in 0...CAPACITY) 0.0];

    public static inline function intBuf():Array<Int> {
        return ints;
    }

    public static inline function readI(index:Int):Int {
        return ints[index];
    }

    public static inline function floatBuf():Array<Float> {
        return floats;
    }

    public static inline function readF(index:Int):Float {
        return floats[index];
    }
    #end
}
