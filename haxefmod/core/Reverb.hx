package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * Reverb environment properties: the twelve fields of
 * FMOD_REVERB_PROPERTIES in header order.
 */
typedef ReverbProperties = {
    /** Reverberation decay time (ms). */
    var decayTime:Float;
    /** Initial reflection delay (ms). */
    var earlyDelay:Float;
    /** Late reverberation delay relative to the initial reflection (ms). */
    var lateDelay:Float;
    /** Reference high frequency (Hz). */
    var hfReference:Float;
    /** High-frequency to mid-frequency decay time ratio (%). */
    var hfDecayRatio:Float;
    /** Echo density in the late reverberation decay (%). */
    var diffusion:Float;
    /** Modal density in the late reverberation decay (%). */
    var density:Float;
    /** Transition frequency of the low-shelf filter (Hz). */
    var lowShelfFrequency:Float;
    /** Gain of the low-shelf filter (dB). */
    var lowShelfGain:Float;
    /** Cutoff frequency of the low-pass filter (Hz). */
    var highCut:Float;
    /** Blend of late reverberation into early reflections (%). */
    var earlyLateMix:Float;
    /** Reverb signal level (dB). */
    var wetLevel:Float;
}

/**
 * The built-in system reverb. Set an environment (use a preset or your own
 * properties) and channels contribute to it through their reverb wet level
 * (Channel.setReverbWet, on by default at 1.0).
 *
 * FMOD supports four reverb instances (0..3); games normally use 0.
 */
class Reverb {
    public static function set(instance:Int, properties:ReverbProperties):FmodResult {
        Scratch.writeF(0, properties.decayTime);
        Scratch.writeF(1, properties.earlyDelay);
        Scratch.writeF(2, properties.lateDelay);
        Scratch.writeF(3, properties.hfReference);
        Scratch.writeF(4, properties.hfDecayRatio);
        Scratch.writeF(5, properties.diffusion);
        Scratch.writeF(6, properties.density);
        Scratch.writeF(7, properties.lowShelfFrequency);
        Scratch.writeF(8, properties.lowShelfGain);
        Scratch.writeF(9, properties.highCut);
        Scratch.writeF(10, properties.earlyLateMix);
        Scratch.writeF(11, properties.wetLevel);
        return NativeStudio.sys_set_reverb_properties(instance);
    }

    public static function get(instance:Int):Null<ReverbProperties> {
        var result:FmodResult = NativeStudio.sys_get_reverb_properties(instance);
        if (!result.isOk()) return null;
        return {
            decayTime: Scratch.readF(0),
            earlyDelay: Scratch.readF(1),
            lateDelay: Scratch.readF(2),
            hfReference: Scratch.readF(3),
            hfDecayRatio: Scratch.readF(4),
            diffusion: Scratch.readF(5),
            density: Scratch.readF(6),
            lowShelfFrequency: Scratch.readF(7),
            lowShelfGain: Scratch.readF(8),
            highCut: Scratch.readF(9),
            earlyLateMix: Scratch.readF(10),
            wetLevel: Scratch.readF(11),
        };
    }

    /** Turns the reverb instance off. */
    public static inline function off(instance:Int = 0):FmodResult {
        return set(instance, PRESET_OFF);
    }

    // The FMOD_PRESET_* environments from the FMOD headers
    static function preset(values:Array<Float>):ReverbProperties {
        return {
            decayTime: values[0], earlyDelay: values[1], lateDelay: values[2],
            hfReference: values[3], hfDecayRatio: values[4], diffusion: values[5],
            density: values[6], lowShelfFrequency: values[7], lowShelfGain: values[8],
            highCut: values[9], earlyLateMix: values[10], wetLevel: values[11],
        };
    }

    public static var PRESET_OFF(get, never):ReverbProperties;
    static function get_PRESET_OFF() return preset([1000, 7, 11, 5000, 100, 100, 100, 250, 0, 20, 96, -80.0]);
    public static var PRESET_GENERIC(get, never):ReverbProperties;
    static function get_PRESET_GENERIC() return preset([1500, 7, 11, 5000, 83, 100, 100, 250, 0, 14500, 96, -8.0]);
    public static var PRESET_PADDEDCELL(get, never):ReverbProperties;
    static function get_PRESET_PADDEDCELL() return preset([170, 1, 2, 5000, 10, 100, 100, 250, 0, 160, 84, -7.8]);
    public static var PRESET_ROOM(get, never):ReverbProperties;
    static function get_PRESET_ROOM() return preset([400, 2, 3, 5000, 83, 100, 100, 250, 0, 6050, 88, -9.4]);
    public static var PRESET_BATHROOM(get, never):ReverbProperties;
    static function get_PRESET_BATHROOM() return preset([1500, 7, 11, 5000, 54, 100, 60, 250, 0, 2900, 83, 0.5]);
    public static var PRESET_LIVINGROOM(get, never):ReverbProperties;
    static function get_PRESET_LIVINGROOM() return preset([500, 3, 4, 5000, 10, 100, 100, 250, 0, 160, 58, -19.0]);
    public static var PRESET_STONEROOM(get, never):ReverbProperties;
    static function get_PRESET_STONEROOM() return preset([2300, 12, 17, 5000, 64, 100, 100, 250, 0, 7800, 71, -8.5]);
    public static var PRESET_AUDITORIUM(get, never):ReverbProperties;
    static function get_PRESET_AUDITORIUM() return preset([4300, 20, 30, 5000, 59, 100, 100, 250, 0, 5850, 64, -11.7]);
    public static var PRESET_CONCERTHALL(get, never):ReverbProperties;
    static function get_PRESET_CONCERTHALL() return preset([3900, 20, 29, 5000, 70, 100, 100, 250, 0, 5650, 80, -9.8]);
    public static var PRESET_CAVE(get, never):ReverbProperties;
    static function get_PRESET_CAVE() return preset([2900, 15, 22, 5000, 100, 100, 100, 250, 0, 20000, 59, -11.3]);
    public static var PRESET_ARENA(get, never):ReverbProperties;
    static function get_PRESET_ARENA() return preset([7200, 20, 30, 5000, 33, 100, 100, 250, 0, 4500, 80, -9.6]);
    public static var PRESET_HANGAR(get, never):ReverbProperties;
    static function get_PRESET_HANGAR() return preset([10000, 20, 30, 5000, 23, 100, 100, 250, 0, 3400, 72, -7.4]);
    public static var PRESET_CARPETTEDHALLWAY(get, never):ReverbProperties;
    static function get_PRESET_CARPETTEDHALLWAY() return preset([300, 2, 30, 5000, 10, 100, 100, 250, 0, 500, 56, -24.0]);
    public static var PRESET_HALLWAY(get, never):ReverbProperties;
    static function get_PRESET_HALLWAY() return preset([1500, 7, 11, 5000, 59, 100, 100, 250, 0, 7800, 87, -5.5]);
    public static var PRESET_STONECORRIDOR(get, never):ReverbProperties;
    static function get_PRESET_STONECORRIDOR() return preset([270, 13, 20, 5000, 79, 100, 100, 250, 0, 9000, 86, -6.0]);
    public static var PRESET_ALLEY(get, never):ReverbProperties;
    static function get_PRESET_ALLEY() return preset([1500, 7, 11, 5000, 86, 100, 100, 250, 0, 8300, 80, -9.8]);
    public static var PRESET_FOREST(get, never):ReverbProperties;
    static function get_PRESET_FOREST() return preset([1500, 162, 88, 5000, 54, 79, 100, 250, 0, 760, 94, -12.3]);
    public static var PRESET_CITY(get, never):ReverbProperties;
    static function get_PRESET_CITY() return preset([1500, 7, 11, 5000, 67, 50, 100, 250, 0, 4050, 66, -26.0]);
    public static var PRESET_MOUNTAINS(get, never):ReverbProperties;
    static function get_PRESET_MOUNTAINS() return preset([1500, 300, 100, 5000, 21, 27, 100, 250, 0, 1220, 82, -24.0]);
    public static var PRESET_QUARRY(get, never):ReverbProperties;
    static function get_PRESET_QUARRY() return preset([1500, 61, 25, 5000, 83, 100, 100, 250, 0, 3400, 100, -5.0]);
    public static var PRESET_PLAIN(get, never):ReverbProperties;
    static function get_PRESET_PLAIN() return preset([1500, 179, 100, 5000, 50, 21, 100, 250, 0, 1670, 65, -28.0]);
    public static var PRESET_PARKINGLOT(get, never):ReverbProperties;
    static function get_PRESET_PARKINGLOT() return preset([1700, 8, 12, 5000, 100, 100, 100, 250, 0, 20000, 56, -19.5]);
    public static var PRESET_SEWERPIPE(get, never):ReverbProperties;
    static function get_PRESET_SEWERPIPE() return preset([2800, 14, 21, 5000, 14, 80, 60, 250, 0, 3400, 66, 1.2]);
    public static var PRESET_UNDERWATER(get, never):ReverbProperties;
    static function get_PRESET_UNDERWATER() return preset([1500, 7, 11, 5000, 10, 100, 100, 250, 0, 500, 92, 7.0]);
}
