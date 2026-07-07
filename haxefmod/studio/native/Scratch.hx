package haxefmod.studio.native;

/**
 * Reusable scratch buffers for struct out-params crossing the FFI boundary.
 *
 * The NativeStudio wrappers pass these buffers to native functions; callers
 * read results back via readI immediately after the call. Only ever touched
 * from the Haxe thread, so a single static buffer per type is safe.
 */
class Scratch {
    #if hl
    static var ints:hl.Bytes = null;

    public static function intBuf():hl.Bytes {
        if (ints == null) ints = new hl.Bytes(64);
        return ints;
    }

    public static inline function readI(index:Int):Int {
        return ints.getI32(index * 4);
    }
    #else
    static var ints:Array<Int> = [0, 0, 0, 0, 0, 0, 0, 0];

    public static inline function intBuf():Array<Int> {
        return ints;
    }

    public static inline function readI(index:Int):Int {
        return ints[index];
    }
    #end
}
