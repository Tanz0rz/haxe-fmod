package haxefmod.core;

import haxefmod.studio.FmodResult;
import haxefmod.studio.native.NativeStudio;
import haxefmod.studio.native.Scratch;

/**
 * A handle to an FMOD DSP effect unit.
 *
 * Create with a DspType, set its parameters by index (parameter indices for
 * each effect are in the FMOD DSP effect reference), then attach it to a
 * Channel or ChannelGroup. Handles are plain ints under the hood. A stale
 * or invalid handle makes every call a safe no-op (getters return defaults,
 * setters return FMOD_ERR_INVALID_HANDLE).
 */
abstract Dsp(Int) from Int to Int {
    public static inline var NULL:Dsp = cast 0;

    /** Creates an effect unit. Returns Dsp.NULL on failure. */
    public static inline function create(type:DspType):Dsp {
        return NativeStudio.dsp_create_by_type(type);
    }

    public inline function isNull():Bool {
        return this == 0;
    }

    /** Plays this DSP as a sound source (e.g. an OSCILLATOR). Returns Channel.NULL on failure. */
    public inline function play(startPaused:Bool = false):Channel {
        return NativeStudio.sys_play_dsp(this, startPaused);
    }

    public inline function setParameter(index:Int, value:Float):FmodResult {
        return NativeStudio.dsp_set_param_float(this, index, value);
    }

    public inline function getParameter(index:Int):Float {
        return NativeStudio.dsp_get_param_float(this, index);
    }

    public inline function setParameterInt(index:Int, value:Int):FmodResult {
        return NativeStudio.dsp_set_param_int(this, index, value);
    }

    public inline function getParameterInt(index:Int):Int {
        return NativeStudio.dsp_get_param_int(this, index);
    }

    public inline function setParameterBool(index:Int, value:Bool):FmodResult {
        return NativeStudio.dsp_set_param_bool(this, index, value);
    }

    public inline function getParameterBool(index:Int):Bool {
        return NativeStudio.dsp_get_param_bool(this, index);
    }

    public inline function getParameterCount():Int {
        return NativeStudio.dsp_get_num_params(this);
    }

    public inline function getType():DspType {
        return NativeStudio.dsp_get_type(this);
    }

    /** A bypassed effect passes audio through unprocessed. */
    public inline function setBypass(bypass:Bool):FmodResult {
        return NativeStudio.dsp_set_bypass(this, bypass);
    }

    public inline function getBypass():Bool {
        return NativeStudio.dsp_get_bypass(this);
    }

    /** Scales the pre-effect signal, the processed signal, and the dry signal (each 0..1). */
    public inline function setWetDryMix(prewet:Float, postwet:Float, dry:Float):FmodResult {
        return NativeStudio.dsp_set_wet_dry_mix(this, prewet, postwet, dry);
    }

    public inline function setActive(active:Bool):FmodResult {
        return NativeStudio.dsp_set_active(this, active);
    }

    /** Clears the effect's internal state (delay lines, envelopes). */
    public inline function reset():FmodResult {
        return NativeStudio.dsp_reset(this);
    }

    /** Metering must be enabled before getMetering returns data. */
    public inline function setMeteringEnabled(input:Bool, output:Bool):FmodResult {
        return NativeStudio.dsp_set_metering_enabled(this, input, output);
    }

    /**
     * Peak and RMS levels per output channel (linear 0..1), or null when
     * unavailable (metering disabled, no signal yet, or a stale handle).
     */
    public function getMetering():Null<{peak:Array<Float>, rms:Array<Float>}> {
        var channels = NativeStudio.dsp_get_metering(this);
        if (channels <= 0) return null;
        var peak = [for (i in 0...channels) Scratch.readF(i)];
        var rms = [for (i in 0...channels) Scratch.readF(channels + i)];
        return {peak: peak, rms: rms};
    }

    /**
     * Spectrum magnitudes from an FFT effect (create with DspType.FFT and
     * attach where you want to analyze). Returns null when no data is
     * available yet. maxBins is capped at 512.
     */
    public function getFftSpectrum(maxBins:Int = 512):Null<Array<Float>> {
        if (maxBins > 512) maxBins = 512;
        var bins = NativeStudio.dsp_fft_get_spectrum(this, maxBins);
        if (bins <= 0) return null;
        return [for (i in 0...bins) Scratch.readF(i)];
    }

    /** Releases the effect and invalidates this handle. Detach it first. */
    public inline function release():FmodResult {
        return NativeStudio.dsp_release(this);
    }
}
