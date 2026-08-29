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
 * typed data parameter readbacks, the packed 3D attribute setters, the
 * full parameter descriptor, and the typed sidechain, finite length,
 * attenuation range, dynamic response, and loudness weighting structs. An oscillator through the master group
 * gives the analyzers a signal, and the section waits on the mixer
 * thread for the meters to fill. Native targets wait inside run. On
 * html5 the mixer runs on the audio thread and only advances between
 * frames, so run starts the signal and the state's update loop calls
 * tick until the meter reads, then the checks finish from there. The
 * parameter descriptor, the loudness readbacks, and the loudness
 * weighting readback are unsupported on html5 and assert that.
 */
class ProbeDspData {
    static var _waiting:Bool = false;
    static var _frames:Int = 0;
    static var _baseline:Int = 0;
    static var _master:ChannelGroup = ChannelGroup.NULL;
    static var _fft:Dsp = cast 0;
    static var _osc:Dsp = cast 0;
    static var _loud:Dsp = cast 0;
    static var _channel:haxefmod.core.Channel = cast 0;

    /** True while the html5 run is waiting on the mixer for the meters. */
    public static function pending():Bool {
        return _waiting;
    }

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
        _baseline = StudioSystem.liveHandleCount();
        _master = ChannelGroup.master();

        // --- getInfo ---
        _fft = Dsp.create(DspType.FFT);
        var fft = _fft;
        var fftInfo = fft.getInfo();
        @:privateAccess state.check("dsp_get_info", fftInfo != null && fftInfo.name == fft.getName() && fftInfo.name != ""
            && fftInfo.version > 0,
            fftInfo == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'name=${fftInfo.name} version=${fftInfo.version} channels=${fftInfo.channels} config=${fftInfo.configWidth}x${fftInfo.configHeight}');
        var stale:Dsp = cast 0;
        @:privateAccess state.check("dsp_get_info_null_handle", stale.getInfo() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, 'result=${StudioSystem.lastResult().toString()}');

        // --- analyzers on a live signal ---
        _osc = Dsp.create(DspType.OSCILLATOR);
        _osc.setParameterInt(DspOscillator.TYPE, 0);
        _osc.setParameter(DspOscillator.RATE, 1000);
        _channel = _osc.play(false);
        _channel.setVolume(0.5);
        @:privateAccess state.check("dspdata_play_osc", !_channel.isNull(), 'handle=${(_channel : Int)}');
        @:privateAccess state.check("dspdata_add_fft", _master.addDsp(ChannelGroup.DSP_TAIL, fft).isOk(), "");
        fft.setMeteringEnabled(true, true);
        _loud = Dsp.create(DspType.LOUDNESS_METER);
        @:privateAccess state.check("dspdata_add_loudness", _master.addDsp(ChannelGroup.DSP_TAIL, _loud).isOk(), "");
        #if js
        _waiting = true;
        _frames = 0;
        #else
        finish(state);
        #end
    }

    /** Called from the state's update loop, finishes the html5 run once the meter reads or the wait times out. */
    public static function tick(state:ApiProbeState):Void {
        if (!_waiting) return;
        _frames++;
        var m = _fft.getMetering();
        if ((m != null && m.peakLevel[0] > 0.01) || _frames > 300) {
            _waiting = false;
            finish(state);
        }
    }

    static function metered():Bool {
        var m = _fft.getMetering();
        return m != null && m.peakLevel[0] > 0.01;
    }

    static function finish(state:ApiProbeState):Void {
        var master = _master;
        var fft = _fft;
        var osc = _osc;
        var channel = _channel;
        var loud = _loud;
        var stale:Dsp = cast 0;
        var metered = waitFor(metered);
        var output = fft.getMetering();
        @:privateAccess state.check("dsp_get_metering_output", metered && output != null && output.numChannels == output.peakLevel.length
            && output.numSamples > 0 && output.rmsLevel.length == output.numChannels,
            output == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'channels=${output.numChannels} samples=${output.numSamples} peak=${output.peakLevel[0]} rms=${output.rmsLevel[0]}');
        var input = fft.getInputMetering();
        @:privateAccess state.check("dsp_get_metering_input", input != null && input.numChannels > 0 && input.peakLevel[0] > 0.01
            && input.numSamples > 0,
            input == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : 'channels=${input.numChannels} samples=${input.numSamples} peak=${input.peakLevel[0]}');
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
        #if js
        // FMOD's web glue rejects the loudness info block (INVALID_PARAM
        // from getParameterData), so neither readback exists on html5
        @:privateAccess state.check("dsp_get_loudness_meter_info_unsupported", loud.getLoudnessMeterInfo() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_get_parameter_data_loudness_unsupported", loud.getParameterData(DspLoudnessMeter.INFO) == null
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');
        #else
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
        #end

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
        var compressor = Dsp.create(DspType.COMPRESSOR);
        #if js
        // FMOD's web glue cannot marshal FMOD_DSP_PARAMETER_DESC (the call
        // throws inside embind), so no descriptor comes back on html5
        function unsupportedInfo(name:String, dsp:Dsp, index:Int):Void {
            @:privateAccess state.check(name, dsp.getParameterInfo(index) == null
                && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        }
        unsupportedInfo("dsp_get_parameter_info_float_unsupported", lowpass, DspLowpassSimple.CUTOFF);
        unsupportedInfo("dsp_get_parameter_info_int_unsupported", osc, DspOscillator.TYPE);
        unsupportedInfo("dsp_get_parameter_info_bool_unsupported", compressor, DspCompressor.LINKED);
        unsupportedInfo("dsp_get_parameter_info_data_unsupported", fft, DspFft.SPECTRUMDATA);
        unsupportedInfo("dsp_get_parameter_info_data_overall_gain_unsupported", fader, gainIndex);
        #else
        var cutoff = lowpass.getParameterInfo(DspLowpassSimple.CUTOFF);
        @:privateAccess state.check("dsp_get_parameter_info_float", cutoff != null && cutoff.type == FmodDspParameterType.FLOAT
            && cutoff.floatDesc != null && cutoff.intDesc == null && cutoff.boolDesc == null && cutoff.dataDesc == null
            && cutoff.floatDesc.max > cutoff.floatDesc.min && cutoff.description != "" && cutoff.label != ""
            && cutoff.floatDesc.mapping.piecewiseLinearMapping.numPoints == cutoff.floatDesc.mapping.piecewiseLinearMapping.pointParamValues.length,
            cutoff == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : cutoff.floatDesc == null ? 'type=${(cutoff.type : Int)} floatDesc=null'
            : 'name=${cutoff.name} label=${cutoff.label} desc=${cutoff.description} mapping=${(cutoff.floatDesc.mapping.type : Int)} points=${cutoff.floatDesc.mapping.piecewiseLinearMapping.numPoints} range=${cutoff.floatDesc.min}..${cutoff.floatDesc.max}');
        var oscType = osc.getParameterInfo(DspOscillator.TYPE);
        @:privateAccess state.check("dsp_get_parameter_info_int", oscType != null && oscType.type == FmodDspParameterType.INT
            && oscType.intDesc != null && oscType.floatDesc == null
            && oscType.intDesc.min == 0 && oscType.intDesc.max >= 5 && oscType.intDesc.valueNames != null
            && oscType.intDesc.valueNames.length == oscType.intDesc.max - oscType.intDesc.min + 1 && oscType.intDesc.valueNames[0] != "",
            oscType == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : oscType.intDesc == null ? 'type=${(oscType.type : Int)} intDesc=null'
            : 'name=${oscType.name} range=${oscType.intDesc.min}..${oscType.intDesc.max} names=${oscType.intDesc.valueNames} inf=${oscType.intDesc.goesToInf}');
        var linked = compressor.getParameterInfo(DspCompressor.LINKED);
        @:privateAccess state.check("dsp_get_parameter_info_bool", linked != null && linked.type == FmodDspParameterType.BOOL
            && linked.boolDesc != null && linked.intDesc == null
            && (linked.boolDesc.valueNames == null || linked.boolDesc.valueNames.length == 2),
            linked == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : linked.boolDesc == null ? 'type=${(linked.type : Int)} boolDesc=null'
            : 'name=${linked.name} default=${linked.boolDesc.defaultVal} names=${linked.boolDesc.valueNames}');
        var spectrumDesc = fft.getParameterInfo(DspFft.SPECTRUMDATA);
        @:privateAccess state.check("dsp_get_parameter_info_data", spectrumDesc != null && spectrumDesc.type == FmodDspParameterType.DATA
            && spectrumDesc.dataDesc != null && spectrumDesc.floatDesc == null
            && spectrumDesc.dataDesc.dataType == FmodDspParameterDataType.FFT,
            spectrumDesc == null ? 'null result=${StudioSystem.lastResult().toString()}'
            : spectrumDesc.dataDesc == null ? 'type=${(spectrumDesc.type : Int)} dataDesc=null'
            : 'name=${spectrumDesc.name} dataType=${(spectrumDesc.dataDesc.dataType : Int)}');
        var gainDesc = fader.getParameterInfo(gainIndex);
        @:privateAccess state.check("dsp_get_parameter_info_data_overall_gain", gainDesc != null && gainDesc.dataDesc != null
            && gainDesc.dataDesc.dataType == FmodDspParameterDataType.OVERALLGAIN,
            gainDesc == null || gainDesc.dataDesc == null ? "null" : 'dataType=${(gainDesc.dataDesc.dataType : Int)}');
        #end
        @:privateAccess state.check("dsp_get_parameter_info_out_of_range", lowpass.getParameterInfo(99) == null
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');

        // --- typed data parameters ---
        var sidechainIndex = compressor.getDataParameterIndex(FmodDspParameterDataType.SIDECHAIN);
        @:privateAccess state.check("dsp_sidechain_index", sidechainIndex == DspCompressor.USESIDECHAIN, 'index=$sidechainIndex');
        var setSidechain = compressor.setParameterSidechain(DspCompressor.USESIDECHAIN, {sidechainEnable: true});
        var sidechain = compressor.getParameterSidechain(DspCompressor.USESIDECHAIN);
        @:privateAccess state.check("dsp_set_get_parameter_sidechain", setSidechain.isOk() && sidechain != null && sidechain.sidechainEnable,
            sidechain == null ? 'set=${setSidechain.toString()} get=null result=${StudioSystem.lastResult().toString()}'
            : 'set=${setSidechain.toString()} enable=${sidechain.sidechainEnable}');
        compressor.setParameterSidechain(DspCompressor.USESIDECHAIN, {sidechainEnable: false});
        sidechain = compressor.getParameterSidechain(DspCompressor.USESIDECHAIN);
        @:privateAccess state.check("dsp_get_parameter_sidechain_off", sidechain != null && !sidechain.sidechainEnable, "");
        @:privateAccess state.check("dsp_set_parameter_sidechain_null_props",
            compressor.setParameterSidechain(DspCompressor.USESIDECHAIN, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        @:privateAccess state.check("dsp_set_parameter_sidechain_null_handle",
            stale.setParameterSidechain(0, {sidechainEnable: true}) == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        @:privateAccess state.check("dsp_get_parameter_sidechain_null_handle", stale.getParameterSidechain(0) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        // a finite length struct is the same four byte FMOD_BOOL block, it lands on the sidechain switch
        var setFinite = compressor.setParameterFiniteLength(DspCompressor.USESIDECHAIN, {finite: true});
        var finite = compressor.getParameterFiniteLength(DspCompressor.USESIDECHAIN);
        @:privateAccess state.check("dsp_set_get_parameter_finite_length", setFinite.isOk() && finite != null && finite.finite,
            finite == null ? 'set=${setFinite.toString()} null result=${StudioSystem.lastResult().toString()}' : 'finite=${finite.finite}');
        compressor.setParameterSidechain(DspCompressor.USESIDECHAIN, {sidechainEnable: false});
        @:privateAccess state.check("dsp_set_parameter_finite_length_null_props",
            compressor.setParameterFiniteLength(DspCompressor.USESIDECHAIN, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        // an eight byte overall gain block is too short for a dynamic response
        @:privateAccess state.check("dsp_get_parameter_dynamic_response_short_block", fader.getParameterDynamicResponse(gainIndex) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM, 'result=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("dsp_get_parameter_dynamic_response_float_param", fft.getParameterDynamicResponse(DspFft.WINDOWSIZE) == null
            && !StudioSystem.lastResult().isOk(), 'result=${StudioSystem.lastResult().toString()}');
        var rangeIndex = pan.getDataParameterIndex(FmodDspParameterDataType.ATTENUATION_RANGE);
        var setRange = pan.setParameterAttenuationRange(rangeIndex, {min: 1.5, max: 250});
        @:privateAccess state.check("dsp_set_parameter_attenuation_range", rangeIndex >= 0 && setRange.isOk(),
            'index=$rangeIndex result=${setRange.toString()}');
        var range = pan.getParameterAttenuationRange(rangeIndex);
        @:privateAccess state.check("dsp_get_parameter_attenuation_range", range == null
            ? !StudioSystem.lastResult().isOk() : (range.min == 1.5 && range.max == 250),
            range == null ? 'null result=${StudioSystem.lastResult().toString()}' : 'min=${range.min} max=${range.max}');
        @:privateAccess state.check("dsp_set_parameter_attenuation_range_null_props",
            pan.setParameterAttenuationRange(rangeIndex, null) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        var setWeighting = loud.setLoudnessMeterWeighting({channelWeight: [0.5, 0.25]});
        @:privateAccess state.check("dsp_set_loudness_meter_weighting", setWeighting.isOk(), 'result=${setWeighting.toString()}');
        #if js
        // The glue hands the weighting block back without its fields
        @:privateAccess state.check("dsp_get_loudness_meter_weighting_unsupported", loud.getLoudnessMeterWeighting() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED, 'result=${StudioSystem.lastResult().toString()}');
        #else
        var weighting = loud.getLoudnessMeterWeighting();
        @:privateAccess state.check("dsp_get_loudness_meter_weighting", weighting != null
            && weighting.channelWeight.length == Dsp.MAX_CHANNEL_SLOTS && weighting.channelWeight[0] == 0.5 && weighting.channelWeight[1] == 0.25 && weighting.channelWeight[2] == 0,
            weighting == null ? 'null result=${StudioSystem.lastResult().toString()}' : 'w0=${weighting.channelWeight[0]} w1=${weighting.channelWeight[1]} n=${weighting.channelWeight.length}');
        #end
        @:privateAccess state.check("dsp_set_loudness_meter_weighting_oversized",
            loud.setLoudnessMeterWeighting({channelWeight: [for (_ in 0...Dsp.MAX_CHANNEL_SLOTS + 1) 1.0]}) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        @:privateAccess state.check("dsp_set_loudness_meter_weighting_null",
            loud.setLoudnessMeterWeighting(null) == FmodResult.FMOD_ERR_INVALID_PARAM, "");

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
        @:privateAccess state.check("no_handle_leaks_dspdata", now == _baseline, 'baseline=$_baseline now=$now');
    }
}
