package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.Channel;
import haxefmod.core.ChannelEvent;
import haxefmod.core.ChannelGroup;
import haxefmod.core.ChannelMode;
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;
import haxefmod.core.Geometry;
import haxefmod.core.PcmStream;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types.FmodVector;

/**
 * Probe for the ChannelGroup half of the ChannelControl surface: the
 * group readers Channel already had (occlusion, delay, lowpass gain,
 * isPlaying), group callbacks, the stopChannels default of setDelay,
 * the mix matrix hop on channels, groups, and connections, the
 * connection addGroup hands back, and the connection-narrowed
 * disconnectFrom. The occlusion callback needs FMOD to update a few
 * times, so that part waits in tick().
 */
class ProbeChannelControl {
    static var _started:Bool = false;
    static var _waiting:Bool = false;
    static var _frames:Int = 0;
    static var _baseline:Int = 0;
    static var _events:Array<ChannelEvent> = [];
    static var _groupEvents:Array<ChannelEvent> = [];
    static var _geometry:Geometry = Geometry.NULL;
    static var _group:ChannelGroup = ChannelGroup.NULL;
    static var _stream:PcmStream = PcmStream.NULL;
    static var _channel:Channel = Channel.NULL;

    public static function run(state:ApiProbeScenario):Void {
        var master = ChannelGroup.master();
        var baseline = StudioSystem.liveHandleCount();

        // A nested group returns its connection. A group has one parent,
        // so the clock propagation flag gets its own pair.
        var parent = ChannelGroup.create("probe-cc-parent");
        var child = ChannelGroup.create("probe-cc-child");
        var conn = parent.addGroupConnection(child);
        @:privateAccess state.check("cg_add_group_connection", !conn.isNull() && parent.getGroupCount() == 1
            && (child.getParentGroup() : Int) == (parent : Int),
            'handle=${(conn : Int)} lastResult=${StudioSystem.lastResult().toString()} groups=${parent.getGroupCount()}');
        var other = ChannelGroup.create("probe-cc-other");
        var noClock:FmodResult = parent.addGroup(other, false);
        @:privateAccess state.check("cg_add_group_no_propagate", noClock.isOk() && parent.getGroupCount() == 2,
            'result=${noClock.toString()} groups=${parent.getGroupCount()}');
        var stale:ChannelGroup = cast 0x7fff0001;
        @:privateAccess state.check("cg_add_group_stale", parent.addGroup(stale) == FmodResult.FMOD_ERR_INVALID_HANDLE
            && stale.addGroupConnection(child).isNull(), 'lastResult=${StudioSystem.lastResult().toString()}');

        // isPlaying follows the channels routed into the group
        @:privateAccess state.check("cg_is_playing_empty", !parent.isPlaying() && StudioSystem.lastResult().isOk(),
            'lastResult=${StudioSystem.lastResult().toString()}');
        var stream = PcmStream.create(48000, 2);
        var channel = stream.play(false);
        channel.setChannelGroup(child);
        @:privateAccess state.check("cg_is_playing_nested", parent.isPlaying() && child.isPlaying(),
            'parent=${parent.isPlaying()} child=${child.isPlaying()}');
        @:privateAccess state.check("cg_is_playing_stale", !stale.isPlaying()
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // Lowpass gain and occlusion read back with OK. FMOD 2.03.12 leaves
        // a group's values at zero on every target, so the checks accept
        // any level inside the range and log what came back.
        var lowpass:FmodResult = child.setLowPassGain(0.5);
        var gain = child.getLowPassGain();
        @:privateAccess state.check("cg_get_low_pass_gain", lowpass.isOk() && StudioSystem.lastResult().isOk()
            && gain >= 0 && gain <= 1, 'result=${lowpass.toString()} gain=$gain');
        var occlusionSet:FmodResult = child.set3DOcclusion(0.4, 0.2);
        var occlusion = child.get3DOcclusion();
        @:privateAccess state.check("cg_get_3d_occlusion", occlusionSet.isOk() && occlusion != null
            && occlusion.direct >= 0 && occlusion.direct <= 1 && occlusion.reverb >= 0 && occlusion.reverb <= 1,
            occlusion == null ? 'result=${StudioSystem.lastResult().toString()}'
                : 'direct=${occlusion.direct} reverb=${occlusion.reverb}');
        @:privateAccess state.check("cg_get_3d_occlusion_stale", stale.get3DOcclusion() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        child.setLowPassGain(1.0);
        child.set3DOcclusion(0, 0);
        @:privateAccess state.check("cg_get_low_pass_gain_stale", stale.getLowPassGain() == 0.0
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");

        // setDelay stops the channels at the end clock unless told otherwise
        var clocks = child.getDspClock();
        var base = clocks == null ? 0.0 : clocks.parent;
        var delaySet:FmodResult = child.setDelay(0, base + 96000);
        var delay = child.getDelay();
        @:privateAccess state.check("cg_get_delay_default_stops", delaySet.isOk() && delay != null && delay.stopChannels
            && Math.abs(delay.endClock - (base + 96000)) < 1,
            delay == null ? 'result=${StudioSystem.lastResult().toString()}' : 'end=${delay.endClock} stop=${delay.stopChannels}');
        child.setDelay(0, base + 96000, false);
        delay = child.getDelay();
        @:privateAccess state.check("cg_get_delay_pause_only", delay != null && !delay.stopChannels,
            delay == null ? 'result=${StudioSystem.lastResult().toString()}' : 'stop=${delay.stopChannels}');
        child.setDelay(0, 0);
        @:privateAccess state.check("cg_get_delay_stale", stale.getDelay() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE, "");
        var chanClocks = channel.getDspClock();
        var chanBase = chanClocks == null ? 0.0 : chanClocks.parent;
        channel.setDelay(0, chanBase + 96000);
        var chanDelay = channel.getDelay();
        @:privateAccess state.check("chan_set_delay_default_stops", chanDelay != null && chanDelay.stopChannels,
            chanDelay == null ? 'result=${StudioSystem.lastResult().toString()}' : 'stop=${chanDelay.stopChannels}');
        channel.setDelay(0, 0);

        // The mix matrix hop lays rows out wider than the input count
        var wide:Array<Float> = [1, 0, 0, 0, 0, 1, 0, 0];
        var hopSet:FmodResult = channel.setMixMatrix(wide, 2, 2, 4);
        @:privateAccess state.check("chan_set_mix_matrix_hop", hopSet.isOk(), 'result=${hopSet.toString()}');
        @:privateAccess state.check("chan_set_mix_matrix_hop_too_narrow",
            channel.setMixMatrix(wide, 2, 2, 1) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        @:privateAccess state.check("chan_set_mix_matrix_hop_too_wide",
            channel.setMixMatrix(wide, 2, 2, 33) == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        var groupHop:FmodResult = child.setMixMatrix(wide, 2, 2, 4);
        @:privateAccess state.check("cg_set_mix_matrix_hop", groupHop.isOk(), 'result=${groupHop.toString()}');
        #if js
        @:privateAccess state.check("chan_get_mix_matrix_hop_unsupported", channel.getMixMatrix(0, 0, 4) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED,
            'lastResult=${StudioSystem.lastResult().toString()}');
        #else
        var hopped = channel.getMixMatrix(0, 0, 4);
        @:privateAccess state.check("chan_get_mix_matrix_hop", hopped != null && hopped.matrix.length == 8
            && Math.abs(hopped.matrix[0] - 1) < 0.001 && Math.abs(hopped.matrix[5] - 1) < 0.001
            && hopped.outChannels == 2 && hopped.inChannels == 2,
            hopped == null ? 'result=${StudioSystem.lastResult().toString()}'
                : 'length=${hopped.matrix.length} out=${hopped.outChannels} in=${hopped.inChannels}');
        var packed = channel.getMixMatrix();
        @:privateAccess state.check("chan_get_mix_matrix_packed", packed != null && packed.matrix.length == 4
            && Math.abs(packed.matrix[0] - 1) < 0.001 && Math.abs(packed.matrix[3] - 1) < 0.001,
            packed == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${packed.matrix.length}');
        var region = channel.getMixMatrix(1, 1);
        @:privateAccess state.check("chan_get_mix_matrix_region", region != null && region.matrix.length == 1
            && Math.abs(region.matrix[0] - 1) < 0.001 && region.outChannels == 2,
            region == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${region.matrix.length}');
        @:privateAccess state.check("chan_get_mix_matrix_hop_too_wide", channel.getMixMatrix(0, 0, 33) == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM, "");
        var groupHopped = child.getMixMatrix(0, 0, 4);
        @:privateAccess state.check("cg_get_mix_matrix_hop", groupHopped != null && groupHopped.matrix.length == 8
            && Math.abs(groupHopped.matrix[5] - 1) < 0.001,
            groupHopped == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${groupHopped.matrix.length}');
        #end
        channel.setMixMatrix([1, 0, 0, 1], 2, 2);
        child.setMixMatrix([1, 0, 0, 1], 2, 2);

        // A connection reads its matrix back without being told the shape
        var osc = Dsp.create(DspType.OSCILLATOR);
        var fft = Dsp.create(DspType.FFT);
        var link = fft.addInput(osc);
        var linkSet:FmodResult = link.setMixMatrix([0.5, 0, 0, 0.5], 2, 2);
        #if js
        @:privateAccess state.check("conn_get_mix_matrix_unsupported", linkSet.isOk() && link.getMixMatrix() == null
            && StudioSystem.lastResult() == FmodResult.FMOD_ERR_UNSUPPORTED,
            'lastResult=${StudioSystem.lastResult().toString()}');
        #else
        var linkMatrix = link.getMixMatrix();
        @:privateAccess state.check("conn_get_mix_matrix_no_dims", linkSet.isOk() && linkMatrix != null
            && linkMatrix.matrix.length == 4 && Math.abs(linkMatrix.matrix[0] - 0.5) < 0.001
            && linkMatrix.outChannels == 2 && linkMatrix.inChannels == 2,
            linkMatrix == null ? 'result=${StudioSystem.lastResult().toString()}'
                : 'length=${linkMatrix.matrix.length} out=${linkMatrix.outChannels} in=${linkMatrix.inChannels}');
        var linkHop:FmodResult = link.setMixMatrix([0.5, 0, 0, 0, 0, 0.5, 0, 0], 2, 2, 4);
        var linkHopped = link.getMixMatrix(0, 0, 4);
        @:privateAccess state.check("conn_mix_matrix_hop", linkHop.isOk() && linkHopped != null && linkHopped.matrix.length == 8
            && Math.abs(linkHopped.matrix[5] - 0.5) < 0.001,
            linkHopped == null ? 'result=${StudioSystem.lastResult().toString()}' : 'length=${linkHopped.matrix.length}');
        #end

        // disconnectFrom narrowed to one connection, then the stale handle
        var narrow:FmodResult = fft.disconnectFrom(osc, link);
        @:privateAccess state.check("dsp_disconnect_from_connection", narrow.isOk() && fft.getInputCount() == 0,
            'result=${narrow.toString()} inputs=${fft.getInputCount()}');
        var again = fft.addInput(osc);
        @:privateAccess state.check("dsp_disconnect_from_stale_connection",
            fft.disconnectFrom(osc, link) == FmodResult.FMOD_ERR_INVALID_HANDLE && fft.getInputCount() == 1,
            'inputs=${fft.getInputCount()} again=${(again : Int)} old=${(link : Int)}');
        @:privateAccess state.check("dsp_disconnect_from_any", fft.disconnectFrom(osc).isOk() && fft.getInputCount() == 0,
            'inputs=${fft.getInputCount()}');
        osc.release();
        fft.release();

        // Group callbacks register and clear like channel callbacks
        var groupEvents = 0;
        child.setCallback(function(_) groupEvents++);
        child.clearCallback();
        child.setCallback(function(_) groupEvents++);
        @:privateAccess state.check("cg_set_callback", StudioSystem.lastResult().isOk(), 'lastResult=${StudioSystem.lastResult().toString()}');

        channel.stop();
        stream.release();
        var released:FmodResult = child.release();
        @:privateAccess state.check("cg_release_with_callback", released.isOk(), 'result=${released.toString()}');
        other.release();
        parent.release();
        @:privateAccess state.check("cg_get_delay_master", master.getDelay() != null, 'lastResult=${StudioSystem.lastResult().toString()}');
        @:privateAccess state.check("no_handle_leaks_channelcontrol", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

    }

    /**
     * A quad between the listener and a 3D group with a playing channel.
     * FMOD computes occlusion from System::update, and both callbacks
     * should see an Occlusion event within a few frames.
     */
    static function startOcclusionWait(state:ApiProbeScenario):Void {
        _baseline = StudioSystem.liveHandleCount();
        _events = [];
        _groupEvents = [];
        _frames = 0;
        StudioSystem.setListenerPosition2D(0, -5, 0);
        _geometry = Geometry.create(4, 16);
        var quad:Array<FmodVector> = [{x: 0, y: -10, z: -10}, {x: 0, y: 10, z: -10}, {x: 0, y: 10, z: 10}, {x: 0, y: -10, z: 10}];
        _geometry.addPolygon(1.0, 0.5, true, quad);
        _group = ChannelGroup.create("probe-cc-occlusion");
        _group.setMode(ChannelMode.MODE_3D);
        _group.set3DAttributes(5, 0, 0);
        _group.setCallback(function(e) _groupEvents.push(e));
        _stream = PcmStream.create3d(48000, 1);
        _channel = _stream.play(false);
        _channel.setChannelGroup(_group);
        _channel.set3DAttributes(5, 0, 0);
        _channel.setCallback(function(e) _events.push(e));
        @:privateAccess state.check("occlusion_wait_setup", !_geometry.isNull() && !_channel.isNull(),
            'geometry=${(_geometry : Int)} channel=${(_channel : Int)}');
        _waiting = true;
    }

    /**
     * Called from the state's update once the channel event probe is
     * done, so the two waits never hold handles across each other's leak
     * checks. Starts the occlusion wait on the first call and finishes it
     * once the events land or the timeout passes. Geometry is native only.
     */
    public static function tick(state:ApiProbeScenario):Void {
        #if js
        return;
        #end
        if (!_started) {
            _started = true;
            startOcclusionWait(state);
            return;
        }
        if (!_waiting) return;
        _frames++;
        var sawChannel = false;
        var sawGroup = false;
        // the first occlusion event can carry zero before the geometry
        // settles, so wait for one with a real value
        for (e in _events) switch (e) {
            case Occlusion(d, _) if (d > 0): sawChannel = true;
            default:
        }
        for (e in _groupEvents) if (e.match(Occlusion(_, _))) sawGroup = true;
        if ((sawChannel && sawGroup) || _frames > 300) {
            _waiting = false;
            finishOcclusionWait(state, sawChannel, sawGroup);
        }
    }

    static function finishOcclusionWait(state:ApiProbeScenario, sawChannel:Bool, sawGroup:Bool):Void {
        var direct = -1.0;
        for (e in _events) switch (e) {
            case Occlusion(d, _): direct = d;
            default:
        }
        @:privateAccess state.check("chan_occlusion_event_delivered", sawChannel && direct > 0,
            'events=${_events.length} frames=$_frames direct=$direct');
        @:privateAccess state.check("cg_occlusion_event_delivered", sawGroup,
            'events=${_groupEvents.length} frames=$_frames');
        _channel.stop();
        _stream.release();
        _group.release();
        _geometry.release();
        StudioSystem.setListenerPosition2D(0, 0, 0);
        // Occlusion callbacks arrive from the mixer thread with a handle
        // each, and one can still land after the stop. Drain a few times
        // with the mixer given a moment in between, then count, before the
        // scenario moves on and holds handles of its own. Fewer than the
        // baseline only means an earlier probe's events drained late.
        for (i in 0...5) {
            StudioSystem.flushCommands();
            haxefmod.studio.CallbackDispatcher.update();
            Sys.sleep(0.01);
        }
        @:privateAccess state.check("no_handle_leaks_occlusion_callback", StudioSystem.liveHandleCount() <= _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');
    }
}
