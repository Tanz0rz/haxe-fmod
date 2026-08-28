package;

import haxefmod.core.Dsp;
import haxefmod.core.DspParameters;
import haxefmod.core.DspType;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;

/**
 * Probe for the DSP parameter index enums. Creates a LOWPASS and a
 * CHANNELMIX unit, sets parameters through the enums, reads them back, and
 * asks getParameterInfo which parameter each index really is (FMOD names
 * every CHANNELMIX gain "Channel Gain" and every mapping "Channel
 * Mapping", so the name proves the group, the count proves the index
 * range). Native only, getParameterInfo is HTML5 gated.
 */
class ProbeDspParameters {
    public static function run(state:ApiProbeState):Void {
        var baseline = StudioSystem.liveHandleCount();

        var lowpass = Dsp.create(DspType.LOWPASS);
        @:privateAccess state.check("dsp_params_lowpass_created", !lowpass.isNull(), 'handle=${(lowpass : Int)}');
        var set:FmodResult = lowpass.setParameter(DspLowpass.CUTOFF, 800);
        @:privateAccess state.check("dsp_params_lowpass_set_cutoff", set.isOk(), 'result=${set.toString()}');
        var cutoff = lowpass.getParameter(DspLowpass.CUTOFF);
        @:privateAccess state.check("dsp_params_lowpass_get_cutoff", Math.abs(cutoff - 800) < 0.5, 'cutoff=$cutoff');
        var cutoffInfo = lowpass.getParameterInfo(DspLowpass.CUTOFF);
        @:privateAccess state.check("dsp_params_lowpass_cutoff_name", cutoffInfo != null && cutoffInfo.name == "Cutoff freq",
            'name=${cutoffInfo == null ? "null" : cutoffInfo.name}');
        var resonanceInfo = lowpass.getParameterInfo(DspLowpass.RESONANCE);
        @:privateAccess state.check("dsp_params_lowpass_resonance_name", resonanceInfo != null && resonanceInfo.name == "Resonance",
            'name=${resonanceInfo == null ? "null" : resonanceInfo.name}');
        @:privateAccess state.check("dsp_params_lowpass_count", lowpass.getParameterCount() == 2, 'count=${lowpass.getParameterCount()}');
        lowpass.release();

        var mix = Dsp.create(DspType.CHANNELMIX);
        @:privateAccess state.check("dsp_params_channelmix_created", !mix.isNull(), 'handle=${(mix : Int)}');
        set = mix.setParameterInt(DspChannelMix.OUTPUTGROUPING, 2);
        @:privateAccess state.check("dsp_params_channelmix_set_grouping", set.isOk(), 'result=${set.toString()}');
        var grouping = mix.getParameterInt(DspChannelMix.OUTPUTGROUPING);
        @:privateAccess state.check("dsp_params_channelmix_get_grouping", grouping == 2, 'grouping=$grouping');
        set = mix.setParameter(DspChannelMix.GAIN_CH0, -6);
        @:privateAccess state.check("dsp_params_channelmix_set_gain", set.isOk(), 'result=${set.toString()}');
        var gain = mix.getParameter(DspChannelMix.GAIN_CH0);
        @:privateAccess state.check("dsp_params_channelmix_get_gain", Math.abs(gain + 6) < 0.01, 'gain=$gain');
        var groupingInfo = mix.getParameterInfo(DspChannelMix.OUTPUTGROUPING);
        @:privateAccess state.check("dsp_params_channelmix_grouping_name", groupingInfo != null && groupingInfo.name == "Output Format",
            'name=${groupingInfo == null ? "null" : groupingInfo.name}');
        var gainInfo = mix.getParameterInfo(DspChannelMix.GAIN_CH0);
        @:privateAccess state.check("dsp_params_channelmix_gain_ch0_name", gainInfo != null && gainInfo.name == "Channel Gain",
            'name=${gainInfo == null ? "null" : gainInfo.name}');
        var lastInfo = mix.getParameterInfo(DspChannelMix.OUTPUT_CH31);
        @:privateAccess state.check("dsp_params_channelmix_output_ch31_name", lastInfo != null && lastInfo.name == "Channel Mapping",
            'name=${lastInfo == null ? "null" : lastInfo.name}');
        @:privateAccess state.check("dsp_params_channelmix_count", mix.getParameterCount() == 65, 'count=${mix.getParameterCount()}');
        mix.release();

        @:privateAccess state.check("no_handle_leaks_dsp_parameters", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');
    }
}
