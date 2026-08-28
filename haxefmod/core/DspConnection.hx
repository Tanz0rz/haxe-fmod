package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.Types.DspConnectionType;
import haxefmod.studio.UserData;
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

    /** The connection types Dsp.addInput takes, the same values as DspConnectionType. */
    public static inline var TYPE_STANDARD:DspConnectionType = DspConnectionType.STANDARD;
    public static inline var TYPE_SIDECHAIN:DspConnectionType = DspConnectionType.SIDECHAIN;
    public static inline var TYPE_SEND:DspConnectionType = DspConnectionType.SEND;
    public static inline var TYPE_SEND_SIDECHAIN:DspConnectionType = DspConnectionType.SEND_SIDECHAIN;

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

    /** The connection's type, STANDARD on failure. */
    public inline function getType():DspConnectionType {
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
     * Routes the input's channels to the output's with explicit gains.
     * The matrix is one flat row-major array, one row per output channel,
     * with inChannelHop floats per row (0 = packed to inChannels). FMOD
     * mixes at most 32 channels, so larger shapes are refused with
     * FMOD_ERR_INVALID_PARAM.
     */
    public function setMixMatrix(matrix:Array<Float>, outChannels:Int, inChannels:Int, inChannelHop:Int = 0):FmodResult {
        if (!MixMatrix.pack(matrix, outChannels, inChannels, inChannelHop)) return FmodResult.FMOD_ERR_INVALID_PARAM;
        return NativeStudio.conn_set_mix_matrix(this, outChannels, inChannels, inChannelHop);
    }

    #if (macro || (js && !haxefmod_html5_allow_unsupported))
    /**
     * Reads the mix matrix back as one flat row-major array with
     * inChannelHop floats per row (0 = packed to the input count), and
     * the output and input channel counts FMOD reports (unsupported in
     * HTML5, null there). outChannels and inChannels above 0 keep only
     * that many rows and columns. Null on failure, at most 32 by 32.
     */
    public macro function getMixMatrix(self:haxe.macro.Expr, ?outChannels:haxe.macro.Expr, ?inChannels:haxe.macro.Expr, ?inChannelHop:haxe.macro.Expr):haxe.macro.Expr {
        return haxefmod.studio.native.Html5Gate.block("DspConnection.getMixMatrix", "FMOD's web glue binds the matrix as a single float");
    }
    #else
    /**
     * Reads the mix matrix back as one flat row-major array with
     * inChannelHop floats per row (0 = packed to the input count), and
     * the output and input channel counts FMOD reports (unsupported in
     * HTML5, null there). outChannels and inChannels above 0 keep only
     * that many rows and columns. Null on failure, at most 32 by 32.
     */
    public function getMixMatrix(outChannels:Int = 0, inChannels:Int = 0, inChannelHop:Int = 0):Null<{matrix:Array<Float>, outChannels:Int, inChannels:Int}> {
        var total = NativeStudio.conn_get_mix_matrix(this, inChannelHop);
        if (total <= 0) return null;
        return MixMatrix.read(total, outChannels, inChannels, inChannelHop);
    }
    #end
    /**
     * Attaches a Haxe value to this handle. The value lives on the Haxe
     * side keyed by the handle and is dropped when the handle is released.
     * A recycled native slot gets a new generation and therefore a new
     * handle int, so a stale entry never shows up on a later handle.
     */
    public inline function setUserData(value:Dynamic):Void {
        UserData.set(UserDataKind.DspConnection, this, value);
    }

    /** The value attached with setUserData, or null. */
    public inline function getUserData():Dynamic {
        return UserData.get(UserDataKind.DspConnection, this);
    }
}
