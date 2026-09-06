package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;

/**
 * Probe for walking a channel group's DSP chain. Adds a unit to the master
 * group, counts it, reads it back by index and by the named positions,
 * compares handles, removes it again and checks nothing leaked.
 */
class ProbeGroupDsp {
    public static function run(state:ApiProbeScenario):Void {
        var baseline = StudioSystem.liveHandleCount();
        var master = ChannelGroup.master();

        var before = master.getDspCount();
        @:privateAccess state.check("cg_dsp_count_has_fader", before >= 1, 'count=$before');
        var fader = master.getDsp(ChannelGroup.DSP_FADER);
        @:privateAccess state.check("cg_dsp_fader_lookup", !fader.isNull(), 'handle=${(fader : Int)}');
        var tail = master.getDsp(ChannelGroup.DSP_TAIL);
        @:privateAccess state.check("cg_dsp_tail_is_fader", !tail.isNull() && (tail : Int) == (fader : Int),
            'tail=${(tail : Int)} fader=${(fader : Int)}');
        var afterLookup = StudioSystem.liveHandleCount();

        var lowpass = Dsp.create(DspType.LOWPASS);
        var add:FmodResult = master.addDsp(ChannelGroup.DSP_HEAD, lowpass);
        @:privateAccess state.check("cg_dsp_add_head", add.isOk(), 'result=${add.toString()}');
        var after = master.getDspCount();
        @:privateAccess state.check("cg_dsp_count_grew", after == before + 1, 'before=$before after=$after');
        var head = master.getDsp(0);
        @:privateAccess state.check("cg_dsp_get_index_returns_same_handle", (head : Int) == (lowpass : Int),
            'head=${(head : Int)} lowpass=${(lowpass : Int)}');
        var byHead = master.getDsp(ChannelGroup.DSP_HEAD);
        @:privateAccess state.check("cg_dsp_get_head_position", (byHead : Int) == (lowpass : Int),
            'head=${(byHead : Int)} lowpass=${(lowpass : Int)}');
        var stillTail = master.getDsp(ChannelGroup.DSP_TAIL);
        @:privateAccess state.check("cg_dsp_tail_unchanged", (stillTail : Int) == (fader : Int),
            'tail=${(stillTail : Int)} fader=${(fader : Int)}');
        var outOfRange = master.getDsp(after + 5);
        @:privateAccess state.check("cg_dsp_out_of_range_null", outOfRange.isNull()
            && !StudioSystem.lastResult().isOk(),
            'handle=${(outOfRange : Int)} result=${StudioSystem.lastResult().toString()}');

        var remove:FmodResult = master.removeDsp(lowpass);
        @:privateAccess state.check("cg_dsp_remove", remove.isOk(), 'result=${remove.toString()}');
        @:privateAccess state.check("cg_dsp_count_restored", master.getDspCount() == before,
            'count=${master.getDspCount()} before=$before');
        lowpass.release();

        var stale:ChannelGroup = cast 0x7fff0001;
        @:privateAccess state.check("cg_dsp_stale_handle", stale.getDspCount() == 0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'result=${StudioSystem.lastResult().toString()}');

        @:privateAccess state.check("no_handle_leaks_group_dsp", StudioSystem.liveHandleCount() == afterLookup
            && afterLookup <= baseline + 1,
            'baseline=$baseline afterLookup=$afterLookup now=${StudioSystem.liveHandleCount()}');
    }
}
