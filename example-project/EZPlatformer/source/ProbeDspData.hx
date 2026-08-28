package;

import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.core.DspParameters;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * The api-probe section for DSP data parameters and unit info: getInfo,
 * both sides of the meter, the per channel FFT spectrum, the raw and
 * typed data parameter readbacks, the packed 3D attribute setters, and
 * the full parameter descriptor. An oscillator through the master group
 * gives the analyzers a signal, and the section waits on the mixer
 * thread for the meters to fill.
 */
class ProbeDspData {
    static function origin():Fmod3DAttributes {
        return {position: {x: 0, y: 0, z: 0}, velocity: {x: 0, y: 0, z: 0}, forward: {x: 0, y: 0, z: 1}, up: {x: 0, y: 1, z: 0}};
    }

    static function at(x:Float, y:Float, z:Float):Fmod3DAttributes {
        return {position: {x: x, y: y, z: z}, velocity: {x: 0, y: 0, z: 0}, forward: {x: 0, y: 0, z: 1}, up: {x: 0, y: 1, z: 0}};
    }

    /** Ticks the system until the condition holds or the tries run out. */
    static function waitFor(ready:Void->Bool, tries:Int = 100):Bool {
        var i = 0;
        while (i < tries) {
            if (ready()) return true;
            haxefmod.studio.native.NativeStudio.sys_update();
            #if sys
            Sys.sleep(0.02);
            #end
            i++;
        }
        return ready();
    }

    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();
        var master = ChannelGroup.master();

        // --- getInfo ---
        var fft = Dsp.create(DspType.FFT);
        var fftInfo = fft.getInfo();
        @:privateAccess state.check("dsp_get_info", fftInfo != null && fftInfo.name == fft.getName() && fftInfo.name != ""
            && fftInfo.version > 0,
            fftInfo == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${fftInfo.name} version=${fftInfo.version} channels=${fftInfo.channels} config=${fftInfo.configWidth}x${fftInfo.configHeight}');
        var stale:Dsp = cast 0;
        @:privateAccess state.check("dsp_get_info_null_handle", stale.getInfo() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, 'result=${StudioSystem.lastResult().toString()}');

        // --- analyzers on a live signal ---
        var osc = Dsp.create(DspType.OSCILLATOR);
        osc.setParameterInt(DspOscillator.TYPE, 0);
        osc.setParameter(DspOscillator.RATE, 1000);
        var channel = osc.play(false);
        channel.setVolume(0.5);
        @:privateAccess state.check("dspdata_play_osc", !channel.isNull(), 'handle=${(channel : Int)}');
        @:privateAccess state.check("dspdata_add_fft", master.addDsp(ChannelGroup.DSP_TAIL, fft).isOk(), "");
        fft.setMeteringEnabled(true, true);
        var metered = waitFor(function() {
            var m = fft.getMetering();
            return m != null && m.peak[0] > 0.01;
        });
        var output = fft.getMetering();
        @:privateAccess state.check("dsp_get_metering_output", metered && output != null && output.numChannels == output.peak.length
            && output.numSamples > 0 && output.rms.length == output.numChannels,
            output == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'channels=${output.numChannels} samples=${output.numSamples} peak=${output.peak[0]} rms=${output.rms[0]}');
        var input = fft.getInputMetering();
        @:privateAccess state.check("dsp_get_metering_input", input != null && input.numChannels > 0 && input.peak[0] > 0.01
            && input.numSamples > 0,
            input == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'channels=${input.numChannels} samples=${input.numSamples} peak=${input.peak[0]}');
        var inputAgain = fft.getMetering(true);
        @:privateAccess state.check("dsp_get_metering_input_flag", inputAgain != null && inputAgain.numChannels == input.numChannels, "");

        var spectrum = fft.getFftSpectrumInfo(64);
        var energy = 0.0;
        if (spectrum != null) for (v in spectrum.spectrum[0]) energy += v;
        @:privateAccess state.check("dsp_get_fft_spectrum_info", spectrum != null && spectrum.numChannels >= 1
            && spectrum.spectrum.length == spectrum.numChannels && spectrum.spectrum[0].length == 64 && spectrum.length >= 64
            && energy > 0,
            spectrum == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'channels=${spectrum.numChannels} length=${spectrum.length} bins=${spectrum.spectrum[0].length} sum=$energy');
        var legacy = fft.getFftSpectrum(64);
        @:privateAccess state.check("dsp_get_fft_spectrum_agrees", legacy != null && spectrum != null && legacy.length == 64
            && spectrum.spectrum.length > 0, legacy == null ? "null" : 'bins=${legacy.length}');

        // --- raw data readback: the FFT block carries its header ---
        var fftBlock = fft.getParameterData(DspFft.SPECTRUMDATA);
        @:privateAccess state.check("dsp_get_parameter_data_fft", fftBlock != null && fftBlock.length >= 8 && spectrum != null
            && fftBlock.getInt32(0) == spectrum.length && fftBlock.getInt32(4) == spectrum.numChannels,
            fftBlock == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'bytes=${fftBlock.length} length=${fftBlock.getInt32(0)} channels=${fftBlock.getInt32(4)}');
        @:privateAccess state.check("dsp_get_parameter_data_float_param", fft.getParameterData(DspFft.WINDOWSIZE) == null
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_get_parameter_data_null_handle", stale.getParameterData(0) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // --- overall gain on a fader ---
        var fader = Dsp.create(DspType.FADER);
        var gainIndex = fader.getDataParameterIndex(FmodDspParameterDataType.OVERALLGAIN);
        var gain = fader.getOverallGain();
        @:privateAccess state.check("dsp_get_overall_gain", gainIndex >= 0 && gain != null && Math.abs(gain.linearGain - 1) < 0.001
            && gain.linearGainAdditive == 0,
            gain == null ? 'null index=$gainIndex result=${StudioSystem.lastResult().toString()}'
            : 'index=$gainIndex gain=${gain.linearGain} additive=${gain.linearGainAdditive}');
        var gainByIndex = fader.getOverallGain(gainIndex);
        @:privateAccess state.check("dsp_get_overall_gain_by_index", gainByIndex != null && gainByIndex.linearGain == gain.linearGain, "");
        var gainBlock = fader.getParameterData(gainIndex);
        @:privateAccess state.check("dsp_get_parameter_data_overall_gain", gainBlock != null && gainBlock.length == 8
            && Math.abs(gainBlock.getFloat(0) - 1) < 0.001, gainBlock == null ? "null" : 'bytes=${gainBlock.length}');
        @:privateAccess state.check("dsp_get_overall_gain_none", fft.getOverallGain() == null, "");

        // --- loudness meter readback ---
        var loud = Dsp.create(DspType.LOUDNESS_METER);
        @:privateAccess state.check("dspdata_add_loudness", master.addDsp(ChannelGroup.DSP_TAIL, loud).isOk(), "");
        var loudness = null;
        waitFor(function() {
            loudness = loud.getLoudnessMeterInfo();
            return loudness != null && loudness.momentaryLoudness > -100;
        });
        @:privateAccess state.check("dsp_get_loudness_meter_info", loudness != null && loudness.loudnessHistogram.length == Dsp.LOUDNESS_HISTOGRAM_BINS
            && loudness.momentaryLoudness > -100 && loudness.momentaryLoudness < 10 && loudness.maxTruePeak > -100,
            loudness == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'momentary=${loudness.momentaryLoudness} short=${loudness.shortTermLoudness} integrated=${loudness.integratedLoudness} peak=${loudness.maxTruePeak}');
        var loudBlock = loud.getParameterData(DspLoudnessMeter.INFO);
        @:privateAccess state.check("dsp_get_parameter_data_loudness", loudBlock != null && loudBlock.length == Dsp.LOUDNESS_INFO_BYTES,
            loudBlock == null ? "null" : 'bytes=${loudBlock.length}');

        // --- 3D attributes on a pan unit ---
        var pan = Dsp.create(DspType.PAN);
        var multiIndex = pan.getDataParameterIndex(FmodDspParameterDataType._3DATTRIBUTES_MULTI);
        @:privateAccess state.check("dsp_3d_multi_index", multiIndex >= 0, 'index=$multiIndex');
        var listener = at(1, 2, 3);
        var setMulti = pan.setParameter3DAttributesMulti(multiIndex, at(7, 8, 9), [listener]);
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_multi", setMulti.isOk(), 'result=${setMulti.toString()}');
        var setMultiWeights = pan.setParameter3DAttributesMulti(multiIndex, at(7, 8, 9), [listener, at(-1, 0, 0)], [0.75, 0.25]);
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_multi_two_listeners", setMultiWeights.isOk(), 'result=${setMultiWeights.toString()}');
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_multi_empty",
            pan.setParameter3DAttributesMulti(multiIndex, at(7, 8, 9), []) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_multi_oversized",
            pan.setParameter3DAttributesMulti(multiIndex, origin(), [for (_ in 0...Dsp.MAX_LISTENERS + 1) origin()]) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        // the single struct on the multi parameter is a size mismatch FMOD rejects
        var wrongSize = pan.setParameter3DAttributes(multiIndex, at(7, 8, 9));
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_size_checked", !wrongSize.isOk(), 'result=${wrongSize.toString()}');
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_null_handle",
            stale.setParameter3DAttributes(0, origin()) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("dsp_set_parameter_3d_attributes_multi_null_handle",
            stale.setParameter3DAttributesMulti(0, origin(), [origin()]) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // --- the full parameter descriptor ---
        var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
        var cutoff = lowpass.getParameterInfo(DspLowpassSimple.CUTOFF);
        @:privateAccess state.check("dsp_get_parameter_info_float", cutoff != null && cutoff.type == FmodDspParameterType.FLOAT
            && cutoff.max > cutoff.min && cutoff.description != "" && cutoff.label != ""
            && !cutoff.goesToInfinity && cutoff.valueNames == null,
            cutoff == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${cutoff.name} label=${cutoff.label} desc=${cutoff.description} mapping=${(cutoff.mappingType : Int)} points=${cutoff.mappingPoints == null ? 0 : cutoff.mappingPoints.values.length} range=${cutoff.min}..${cutoff.max}');
        var oscType = osc.getParameterInfo(DspOscillator.TYPE);
        @:privateAccess state.check("dsp_get_parameter_info_int", oscType != null && oscType.type == FmodDspParameterType.INT
            && oscType.min == 0 && oscType.max >= 5 && oscType.valueNames != null
            && oscType.valueNames.length == Std.int(oscType.max - oscType.min) + 1 && oscType.valueNames[0] != "",
            oscType == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${oscType.name} range=${oscType.min}..${oscType.max} names=${oscType.valueNames} inf=${oscType.goesToInfinity}');
        var compressor = Dsp.create(DspType.COMPRESSOR);
        var linked = compressor.getParameterInfo(DspCompressor.LINKED);
        @:privateAccess state.check("dsp_get_parameter_info_bool", linked != null && linked.type == FmodDspParameterType.BOOL
            && (linked.defaultValue == 0 || linked.defaultValue == 1)
            && (linked.valueNames == null || linked.valueNames.length == 2),
            linked == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${linked.name} default=${linked.defaultValue} names=${linked.valueNames}');
        var spectrumDesc = fft.getParameterInfo(DspFft.SPECTRUMDATA);
        @:privateAccess state.check("dsp_get_parameter_info_data", spectrumDesc != null && spectrumDesc.type == FmodDspParameterType.DATA
            && spectrumDesc.dataType == FmodDspParameterDataType.FFT,
            spectrumDesc == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${spectrumDesc.name} dataType=${(spectrumDesc.dataType : Int)}');
        var gainDesc = fader.getParameterInfo(gainIndex);
        @:privateAccess state.check("dsp_get_parameter_info_data_overall_gain", gainDesc != null
            && gainDesc.dataType == FmodDspParameterDataType.OVERALLGAIN, gainDesc == null ? "null" : 'dataType=${(gainDesc.dataType : Int)}');
        @:privateAccess state.check("dsp_get_parameter_info_out_of_range", lowpass.getParameterInfo(99) == null
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');

        // --- teardown ---
        channel.stop();
        @:privateAccess state.check("dspdata_remove_fft", master.removeDsp(fft).isOk(), "");
        @:privateAccess state.check("dspdata_remove_loudness", master.removeDsp(loud).isOk(), "");
        fft.release();
        loud.release();
        fader.release();
        pan.release();
        osc.release();
        lowpass.release();
        compressor.release();
        var now = StudioSystem.liveHandleCount();
        @:privateAccess state.check("no_handle_leaks_dspdata", now == baseline, 'baseline=$baseline now=$now');
    }
}
