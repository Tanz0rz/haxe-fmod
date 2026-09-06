package haxefmod.core;

/**
 * Mode flags for Channel.setMode and Sound.setMode. Values match
 * FMOD_MODE in the FMOD headers and combine with bitwise or. The names
 * are the header's without its FMOD_ prefix, with MODE_ in front of the
 * ones that would start with a digit.
 *
 * The rolloff flags pick how 3D sounds attenuate with distance.
 * MODE_3D_INVERSEROLLOFF is FMOD's default natural falloff,
 * MODE_3D_LINEARROLLOFF reaches silence exactly at the max distance,
 * and MODE_3D_LINEARSQUAREROLLOFF fades faster near the end of the range.
 */
class ChannelMode {
    public static inline var DEFAULT:Int = 0x00000000;
    public static inline var LOOP_OFF:Int = 0x00000001;
    public static inline var LOOP_NORMAL:Int = 0x00000002;
    public static inline var LOOP_BIDI:Int = 0x00000004;
    public static inline var MODE_2D:Int = 0x00000008;
    public static inline var MODE_3D:Int = 0x00000010;
    public static inline var CREATESTREAM:Int = 0x00000080;
    public static inline var CREATESAMPLE:Int = 0x00000100;
    public static inline var CREATECOMPRESSEDSAMPLE:Int = 0x00000200;
    public static inline var OPENUSER:Int = 0x00000400;
    public static inline var OPENMEMORY:Int = 0x00000800;
    public static inline var OPENMEMORY_POINT:Int = 0x10000000;
    public static inline var OPENRAW:Int = 0x00001000;
    public static inline var OPENONLY:Int = 0x00002000;
    public static inline var ACCURATETIME:Int = 0x00004000;
    public static inline var MPEGSEARCH:Int = 0x00008000;
    public static inline var NONBLOCKING:Int = 0x00010000;
    public static inline var UNIQUE:Int = 0x00020000;
    public static inline var MODE_3D_HEADRELATIVE:Int = 0x00040000;
    public static inline var MODE_3D_WORLDRELATIVE:Int = 0x00080000;
    public static inline var MODE_3D_INVERSEROLLOFF:Int = 0x00100000;
    public static inline var MODE_3D_LINEARROLLOFF:Int = 0x00200000;
    public static inline var MODE_3D_LINEARSQUAREROLLOFF:Int = 0x00400000;
    public static inline var MODE_3D_INVERSETAPEREDROLLOFF:Int = 0x00800000;
    public static inline var MODE_3D_CUSTOMROLLOFF:Int = 0x04000000;
    public static inline var MODE_3D_IGNOREGEOMETRY:Int = 0x40000000;
    public static inline var IGNORETAGS:Int = 0x02000000;
    public static inline var LOWMEM:Int = 0x08000000;
    public static inline var VIRTUAL_PLAYFROMSTART:Int = 0x80000000;

    /** The names haxefmod 2.0.0 gave the 3D flags, the same bits. */
    public static inline var HEAD_RELATIVE_3D:Int = MODE_3D_HEADRELATIVE;
    public static inline var WORLD_RELATIVE_3D:Int = MODE_3D_WORLDRELATIVE;
    public static inline var INVERSE_ROLLOFF_3D:Int = MODE_3D_INVERSEROLLOFF;
    public static inline var LINEAR_ROLLOFF_3D:Int = MODE_3D_LINEARROLLOFF;
    public static inline var LINEAR_SQUARE_ROLLOFF_3D:Int = MODE_3D_LINEARSQUAREROLLOFF;
    public static inline var INVERSE_TAPERED_ROLLOFF_3D:Int = MODE_3D_INVERSETAPEREDROLLOFF;
}
