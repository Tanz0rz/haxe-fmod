package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

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

    /** The DSP feeding this connection (a known DSP returns its existing handle). */
    public inline function getInputDsp():Dsp {
        return NativeStudio.dspconn_get_input_dsp(this);
    }

    public inline function getOutputDsp():Dsp {
        return NativeStudio.dspconn_get_output_dsp(this);
    }

    /**
     * Routes the input's channels to the output's with explicit gains
     * (row-major, outChannels rows of inChannels gains, up to 32x32).
     */
    public function setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int):FmodResult {
        var total = outChannels * inChannels;
        if (total < 0 || total > matrix.length || total > Scratch.CAPACITY) {
            return FmodResult.FMOD_ERR_INVALID_PARAM;
        }
        for (i in 0...total) Scratch.writeF(i, matrix[i]);
        return NativeStudio.conn_set_mix_matrix(this, outChannels, inChannels);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads back the mix matrix region of outChannels rows by inChannels
     * gains, row-major (unsupported in HTML5, null there). The returned
     * outChannels and inChannels are the counts FMOD reports for the
     * connection. Null on failure or for sizes outside 1..32.
     */
    public macro function getMixMatrix(self:haxe.macro.Expr, outChannels:haxe.macro.Expr, inChannels:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("DspConnection.getMixMatrix", "FMOD's web glue binds the matrix as a single float");
    }
    #else
    /**
     * Reads back the mix matrix region of outChannels rows by inChannels
     * gains, row-major (unsupported in HTML5, null there). The returned
     * outChannels and inChannels are the counts FMOD reports for the
     * connection. Null on failure or for sizes outside 1..32.
     */
    public function getMixMatrix(outChannels:Int, inChannels:Int):Null<{matrix:Array<Float>, outChannels:Int, inChannels:Int}> {
        var total = NativeStudio.conn_get_mix_matrix(this, outChannels, inChannels);
        if (total <= 0) return null;
        return {matrix: [for (i in 0...total) Scratch.readF(i)], outChannels: Scratch.readI(0), inChannels: Scratch.readI(1)};
    }
    #end
}
