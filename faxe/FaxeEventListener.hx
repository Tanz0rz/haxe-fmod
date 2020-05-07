package faxe;

enum FaxeEvent {
    MUSIC_STOPPED;
}

interface FaxeEventListener {
    public function ReceiveEvent(faxeEvent:FaxeEvent):Void;
}

class FaxeCallback {
    public static inline var CREATED:UInt = 1;
    public static inline var DESTROYED:UInt = 2;
    public static inline var STARTING:UInt = 4;
    public static inline var STARTED:UInt = 8;
    public static inline var RESTARTED:UInt = 16;
    public static inline var STOPPED:UInt = 32;
    public static inline var START_FAILED:UInt = 64;
    public static inline var CREATE_PROGRAMMER_SOUND:UInt = 128;
    public static inline var DESTROY_PROGRAMMER_SOUND:UInt = 256;
    public static inline var PLUGIN_CREATED:UInt = 512;
    public static inline var PLUGIN_DESTROYED:UInt = 1024;
    public static inline var TIMELINE_MARKER:UInt = 2048;
    public static inline var TIMELINE_BEAT:UInt = 4096;
    public static inline var SOUND_PLAYED:UInt = 8192;
    public static inline var SOUND_STOPPED:UInt = 16384;
    public static inline var REAL_TO_VIRTUAL:UInt = 32768;
    public static inline var VIRTUAL_TO_REAL:UInt = 65536;
}
