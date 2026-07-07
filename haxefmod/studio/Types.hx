package haxefmod.studio;

/**
 * Shared types for the FMOD Studio bindings.
 * Values are pinned to FMOD 2.03.12 headers.
 */

/** FMOD_STUDIO_STOP_MODE */
enum abstract FmodStopMode(Int) from Int to Int {
    var ALLOWFADEOUT = 0;
    var IMMEDIATE = 1;
}

/** CPU usage in microseconds (FMOD_Studio_Bus_GetCPUUsage) */
typedef FmodCpuUsage = {
    var exclusive:Int;
    var inclusive:Int;
}

/** Memory usage in bytes (FMOD_STUDIO_MEMORY_USAGE) */
typedef FmodMemoryUsage = {
    var exclusive:Int;
    var inclusive:Int;
    var sampledata:Int;
}
