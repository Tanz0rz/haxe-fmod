package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;

/**
 * A handle to a connection between two DSPs in the mixing graph.
 *
 * Obtain from Dsp.addInput or Dsp.getInputConnection. The mix level scales
 * the signal flowing through this specific connection, which is how send
 * and sidechain style routings balance their inputs.
 *
 * Any graph change (a disconnect or a DSP release) invalidates every
 * connection handle, matching FMOD's own rule that graph changes
 * invalidate connections. Re-query through Dsp.getInputConnection after
 * changing the graph.
 */
abstract DspConnection(Int) from Int to Int {
    public static inline var NULL:DspConnection = cast 0;

    /** Standard connection types (FMOD_DSPCONNECTION_TYPE values). */
    public static inline var TYPE_STANDARD:Int = 0;
    public static inline var TYPE_SIDECHAIN:Int = 1;
    public static inline var TYPE_SEND:Int = 2;
    public static inline var TYPE_SEND_SIDECHAIN:Int = 3;

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Signal scale through this connection (linear, 0.0 = silent, 1.0 = full). */
    public inline function getMix():Float {
        return NativeStudio.dspconn_get_mix(this);
    }

    public inline function setMix(mix:Float):FmodResult {
        return NativeStudio.dspconn_set_mix(this, mix);
    }

    /** One of the TYPE_* values. */
    public inline function getType():Int {
        return NativeStudio.dspconn_get_type(this);
    }
}
