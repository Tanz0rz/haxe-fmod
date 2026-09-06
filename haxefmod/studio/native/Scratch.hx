package haxefmod.studio.native;

/**
 * Reusable scratch buffers for struct out-params crossing the FFI boundary.
 *
 * The NativeStudio wrappers pass these buffers to native functions. Callers
 * read results back via readI/readF immediately after the call. Only ever
 * touched from the Haxe thread, so a single static buffer per type is safe.
 *
 * Capacity is 1024 slots each, in lockstep with the native FAXE_LIST_MAX -
 * list-returning bindings cap their output at this size and the abstracts
 * warn when a larger list gets truncated.
 */
class Scratch {
    public static inline var CAPACITY:Int = 1024;

    /** Most xyz triples the float buffer holds, the cap on vector list getters. */
    public static inline var VECTOR_CAPACITY:Int = 341;

    /**
     * Packs vectors as float32 x,y,z triples for the bindings that take a
     * point array (custom rolloff, geometry polygons). Null for an empty
     * or missing list, which the shims read as "clear".
     */
    public static function packVectors(points:Array<haxefmod.studio.Types.FmodVector>):haxe.io.Bytes {
        if (points == null || points.length == 0) return null;
        var bytes = haxe.io.Bytes.alloc(points.length * 12);
        for (i in 0...points.length) {
            bytes.setFloat(i * 12, points[i].x);
            bytes.setFloat(i * 12 + 4, points[i].y);
            bytes.setFloat(i * 12 + 8, points[i].z);
        }
        return bytes;
    }

    /** Reads count xyz triples back out of the float buffer. */
    public static function readVectors(count:Int):Array<haxefmod.studio.Types.FmodVector> {
        var points = [];
        if (count > VECTOR_CAPACITY) count = VECTOR_CAPACITY;
        for (i in 0...count) {
            points.push({x: readF(i * 3), y: readF(i * 3 + 1), z: readF(i * 3 + 2)});
        }
        return points;
    }

    /** Shared warning for list getters that hit the scratch capacity. */
    public static function warnTruncated(what:String, returned:Int, total:Int):Void {
        if (total > returned) {
            trace('Warn: FMOD - $what list truncated ($returned of $total). Raise FAXE_LIST_MAX/Scratch.CAPACITY.');
        }
    }

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

    public static inline function writeF(index:Int, value:Float):Void {
        floatBuf().setF64(index * 8, value);
    }

    public static inline function writeI(index:Int, value:Int):Void {
        intBuf().setI32(index * 4, value);
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

    public static inline function writeF(index:Int, value:Float):Void {
        floats[index] = value;
    }

    public static inline function writeI(index:Int, value:Int):Void {
        ints[index] = value;
    }
    #end
}
