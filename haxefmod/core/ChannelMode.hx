package haxefmod.core;

/**
 * Mode flags for Channel.setMode and Sound.setMode. Values match
 * FMOD_MODE in the FMOD headers and combine with bitwise or.
 *
 * The rolloff flags pick how 3D sounds attenuate with distance:
 * INVERSE_ROLLOFF is FMOD's default natural falloff, LINEAR reaches
 * silence exactly at the max distance, LINEAR_SQUARE fades faster near
 * the end of the range.
 */
class ChannelMode {
    public static inline var LOOP_OFF:Int = 0x00000001;
    public static inline var LOOP_NORMAL:Int = 0x00000002;
    public static inline var LOOP_BIDI:Int = 0x00000004;
    public static inline var MODE_2D:Int = 0x00000008;
    public static inline var MODE_3D:Int = 0x00000010;
    public static inline var HEAD_RELATIVE_3D:Int = 0x00040000;
    public static inline var WORLD_RELATIVE_3D:Int = 0x00080000;
    public static inline var INVERSE_ROLLOFF_3D:Int = 0x00100000;
    public static inline var LINEAR_ROLLOFF_3D:Int = 0x00200000;
    public static inline var LINEAR_SQUARE_ROLLOFF_3D:Int = 0x00400000;
    public static inline var INVERSE_TAPERED_ROLLOFF_3D:Int = 0x00800000;
}
