package;

/**
 * A minimal 4-channel ProTracker module for the api-probe: one silent
 * sample, one empty pattern, played once. The tracker checks need a real
 * module on disk and no test asset ships one, so the probe writes this.
 *
 * Layout (2110 bytes): 20-byte title, 31 sample headers of 30 bytes
 * (22-byte name, length in words, finetune, volume, repeat start, repeat
 * length, all big-endian words), song length, restart byte, 128 pattern
 * positions, the "M.K." tag, one 1024-byte pattern (64 rows x 4 channels
 * x 4 bytes), then the sample data (one word of silence).
 */
class TrackerFixture {
    public static inline var TITLE:String = "haxefmod probe";
    public static inline var SAMPLE_NAME:String = "silence";
    public static inline var CHANNELS:Int = 4;

    static inline var HEADER:Int = 20 + 31 * 30 + 1 + 1 + 128 + 4;
    static inline var PATTERN:Int = 1024;
    static inline var SAMPLE_BYTES:Int = 2;

    /** The module as bytes. */
    public static function bytes():haxe.io.Bytes {
        var data = haxe.io.Bytes.alloc(HEADER + PATTERN + SAMPLE_BYTES);
        data.fill(0, data.length, 0);
        data.blit(0, haxe.io.Bytes.ofString(TITLE), 0, TITLE.length);
        // Sample 1: name, length 1 word, finetune 0, volume 64, no repeat
        var sample = 20;
        data.blit(sample, haxe.io.Bytes.ofString(SAMPLE_NAME), 0, SAMPLE_NAME.length);
        data.set(sample + 22, 0);
        data.set(sample + 23, 1);
        data.set(sample + 24, 0);
        data.set(sample + 25, 64);
        data.set(sample + 26, 0);
        data.set(sample + 27, 0);
        data.set(sample + 28, 0);
        data.set(sample + 29, 1);
        var order = 20 + 31 * 30;
        data.set(order, 1);
        data.set(order + 1, 127);
        var tag = order + 2 + 128;
        data.blit(tag, haxe.io.Bytes.ofString("M.K."), 0, 4);
        return data;
    }

    #if sys
    /** Writes the module to a temp file and returns its path. */
    public static function write():String {
        var dir = Sys.getEnv("TMPDIR");
        if (dir == null || dir == "") dir = Sys.getEnv("TEMP");
        if (dir == null || dir == "") dir = Sys.systemName() == "Windows" ? "." : "/tmp";
        var path = haxe.io.Path.join([dir, "haxefmod-probe-" + Std.int(Date.now().getTime() % 1000000) + ".mod"]);
        sys.io.File.saveBytes(path, bytes());
        return path;
    }
    #end
}
