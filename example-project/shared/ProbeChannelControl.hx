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
 * Probe for the ChannelGroup half of the ChannelControl surface. It
 * covers the group readers Channel already had: occlusion, delay,
 * lowpass gain, and isPlaying. It also covers group callbacks, the
 * stopChannels default of setDelay, and the mix matrix hop on channels,
 * groups, and connections. The last two are the connection addGroup
 * hands back and the connection-narrowed disconnectFrom. The occlusion
 * callback needs FMOD to update a few times, so that part waits in
 * tick().
 */
class ProbeChannelControl {
    static var _started:Bool = false;
    static var _waiting:Bool = false;
    static var _waitStamp:Float = 0;
    static var _finished:Bool = false;

    /** True until the occlusion wait and its leak count have run (never on js). */
    public static function pending():Bool {
        #if js
        return false;
        #else
        return !_finished;
        #end
    }
    static var _frames:Int = 0;
    static var _baseline:Int = 0;
    static var _events:Array<ChannelEvent> = [];
    static var _groupEvents:Array<ChannelEvent> = [];
    static var _geometry:Geometry = Geometry.NULL;
    static var _group:ChannelGroup = ChannelGroup.NULL;
    static var _stream:PcmStream = PcmStream.NULL;
    static var _channel:Channel = Channel.NULL;

    /** True when the connection handle still works and runs at mix. */
    static function connLive(c:DspConnection, mix:Float):Bool {
        var m = c.getMix();
        return Math.abs(m - mix) < 0.001 && StudioSystem.lastResult().isOk();
    }

    /** True when the connection handle fails its check. */
    static function connDead(c:DspConnection):Bool {
        var m = c.getMix();
        return m == 0 && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE;
    }

    /** How many of a DSP's input connections run at mix. */
    static function countInputsAtMix(dsp:Dsp, mix:Float):Int {
        var count = 0;
        for (i in 0...dsp.getInputCount()) {
            if (Math.abs(dsp.getInputConnection(i).getMix() - mix) < 0.001) count++;
        }
        return count;
    }

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
        // A group added below itself makes FMOD recurse without end. The
        // binding refuses the group itself, its parent, and the master.
        var selfAdd:FmodResult = child.addGroup(child);
        var parentAdd:FmodResult = child.addGroup(parent);
        var masterAdd:FmodResult = child.addGroup(master);
        var masterConn = parent.addGroupConnection(master);
        @:privateAccess state.check("cg_add_group_ancestor_refused", selfAdd == FmodResult.FMOD_ERR_INVALID_PARAM
            && parentAdd == FmodResult.FMOD_ERR_INVALID_PARAM && masterAdd == FmodResult.FMOD_ERR_INVALID_PARAM
            && masterConn.isNull() && StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_PARAM
            && parent.getGroupCount() == 2 && (child.getParentGroup() : Int) == (parent : Int),
            'self=${selfAdd.toString()} parent=${parentAdd.toString()} master=${masterAdd.toString()}'
            + ' groups=${parent.getGroupCount()}');
        // A move down a branch and back up to the grandparent stays open
        var down:FmodResult = child.addGroup(other);
        var downParent:Int = other.getParentGroup();
        var up:FmodResult = parent.addGroup(other);
        @:privateAccess state.check("cg_add_group_reparent", down.isOk() && downParent == (child : Int) && up.isOk()
            && (other.getParentGroup() : Int) == (parent : Int) && parent.getGroupCount() == 2,
            'down=${down.toString()} up=${up.toString()} groups=${parent.getGroupCount()}');

        // A walk returns the live handle of a connection the game made. A
        // connection the game did not make gets a short-lived handle, and
        // a stop ends it.
        var walked = parent.getDsp(-1).getOutputConnection(0);
        var walkedLive = !walked.isNull() && walked.getMix() > 0;
        var reached = child.getDsp(-1).getOutputConnection(0);
        parent.stop();
        var walkedMix = walked.getMix();
        var walkedResult = StudioSystem.lastResult();
        var connMix = conn.getMix();
        @:privateAccess state.check("dsp_walk_connection_short_lived", walkedLive && walkedMix == 0
            && walkedResult == FmodResult.FMOD_ERR_INVALID_HANDLE && (reached : Int) == (conn : Int)
            && connMix > 0 && StudioSystem.lastResult().isOk(),
            'live=$walkedLive walked=${walkedResult.toString()} reached=${(reached : Int)} conn=${(conn : Int)}'
            + ' connMix=$connMix');
        // A move destroys the connection to the old parent, and its handle
        // fails the check. Every other handle keeps working. A refused move
        // keeps the connection, and so does a move into the parent the
        // child already has.
        var moved = child.addGroupConnection(other);
        var movedLive = !moved.isNull() && moved.getMix() > 0;
        var refusedMove:FmodResult = other.addGroup(parent);
        var keptMix = moved.getMix();
        var sameParent = child.addGroupConnection(other);
        var sameResult = StudioSystem.lastResult();
        var sameMix = moved.getMix();
        @:privateAccess state.check("cg_add_group_same_parent_keeps_connection", sameParent.isNull() && sameResult.isOk()
            && sameMix > 0 && StudioSystem.lastResult().isOk(),
            'same=${(sameParent : Int)} result=${sameResult.toString()} mix=$sameMix');
        var moveBack:FmodResult = parent.addGroup(other);
        var movedMix = moved.getMix();
        var movedResult = StudioSystem.lastResult();
        var unrelatedMix = conn.getMix();
        @:privateAccess state.check("cg_add_group_move_ends_connection", movedLive
            && refusedMove == FmodResult.FMOD_ERR_INVALID_PARAM && keptMix > 0 && moveBack.isOk() && movedMix == 0
            && movedResult == FmodResult.FMOD_ERR_INVALID_HANDLE && unrelatedMix > 0 && StudioSystem.lastResult().isOk()
            && (other.getParentGroup() : Int) == (parent : Int),
            'live=$movedLive refused=${refusedMove.toString()} kept=$keptMix back=${moveBack.toString()} mix=$movedMix'
            + ' unrelated=$unrelatedMix');

        // isPlaying follows the channels routed into the group
        @:privateAccess state.check("cg_is_playing_empty", !parent.isPlaying() && StudioSystem.lastResult().isOk(),
            'lastResult=${StudioSystem.lastResult().toString()}');
        var stream = PcmStream.create(48000, 2);
        var channel = stream.play(false);
        // A channel move destroys the connection to the old group, and its
        // handle fails the check. Every other handle keeps working. A
        // refused move keeps the connection, and so does a move into the
        // group the channel is in.
        var sendOsc = Dsp.create(DspType.OSCILLATOR);
        var sendFft = Dsp.create(DspType.FFT);
        var send = sendFft.addInput(sendOsc);
        var sendLive = !send.isNull() && send.getMix() > 0;
        var toMaster = channel.getDsp(Channel.DSP_HEAD).getOutputConnection(0);
        var toMasterLive = !toMaster.isNull() && toMaster.getMix() > 0;
        var refusedRoute:FmodResult = channel.setChannelGroup(stale);
        var keptMix = toMaster.getMix();
        var sameRoute:FmodResult = channel.setChannelGroup(master);
        var sameMix = toMaster.getMix();
        @:privateAccess state.check("chan_set_channel_group_same_group_keeps_connection", toMasterLive
            && refusedRoute == FmodResult.FMOD_ERR_INVALID_HANDLE && keptMix > 0 && sameRoute.isOk() && sameMix > 0
            && StudioSystem.lastResult().isOk(),
            'live=$toMasterLive refused=${refusedRoute.toString()} kept=$keptMix same=${sameRoute.toString()} mix=$sameMix');
        var route:FmodResult = channel.setChannelGroup(child);
        var movedMix = toMaster.getMix();
        var movedResult = StudioSystem.lastResult();
        var sendMix = send.getMix();
        @:privateAccess state.check("chan_set_channel_group_ends_connection", sendLive && route.isOk() && movedMix == 0
            && movedResult == FmodResult.FMOD_ERR_INVALID_HANDLE && sendMix > 0 && StudioSystem.lastResult().isOk(),
            'route=${route.toString()} moved=${movedResult.toString()} send=$sendMix');
        sendFft.release();
        sendOsc.release();
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

        // disconnectFrom narrowed to one connection, then the stale handle.
        // A connection the disconnect leaves keeps its handle.
        var bystanderIn = Dsp.create(DspType.OSCILLATOR);
        var bystanderOut = Dsp.create(DspType.MIXER);
        var bystander = bystanderOut.addInput(bystanderIn);
        bystander.setMix(0.4);
        var narrow:FmodResult = fft.disconnectFrom(osc, link);
        @:privateAccess state.check("dsp_disconnect_from_connection", narrow.isOk() && fft.getInputCount() == 0
            && connDead(link) && connLive(bystander, 0.4),
            'result=${narrow.toString()} inputs=${fft.getInputCount()}');
        // A connection FMOD makes at the address of one it destroyed gets a
        // new handle. The old handle is never checked before the new
        // connections come, and no new one comes back with it.
        var oldLink = fft.addInput(osc);
        fft.disconnectFrom(osc);
        StudioSystem.flushCommands();
        var reusedAs = 0;
        var churn:Array<Dsp> = [];
        for (i in 0...1500) {
            var x = Dsp.create(DspType.OSCILLATOR);
            var y = Dsp.create(DspType.MIXER);
            var c = y.addInput(x);
            if ((c : Int) == (oldLink : Int)) reusedAs = c;
            churn.push(x);
            churn.push(y);
            if (reusedAs != 0) break;
            if (i % 64 == 63) StudioSystem.flushCommands();
        }
        for (d in churn) d.release();
        var again = fft.addInput(osc);
        @:privateAccess state.check("dsp_add_input_new_handle_at_reused_address", !oldLink.isNull() && reusedAs == 0
            && (again : Int) != (oldLink : Int) && connDead(oldLink) && connLive(again, 1.0),
            'old=${(oldLink : Int)} reused=$reusedAs again=${(again : Int)}');
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

        // A head with a second connection to the old parent's tail. The move
        // destroys the parent connection, and the game's send keeps routing
        // at its mix with its handle.
        var dupParent = ChannelGroup.create("probe-cc-dup-parent");
        var dupChild = ChannelGroup.create("probe-cc-dup-child");
        var dupTail = dupParent.getDsp(ChannelGroup.DSP_TAIL);
        var dupSend = dupTail.addInput(dupChild.getDsp(ChannelGroup.DSP_HEAD), DspConnection.TYPE_SEND);
        dupSend.setMix(0.25);
        var dupConn = dupParent.addGroupConnection(dupChild);
        var dupLive = !dupSend.isNull() && !dupConn.isNull() && dupConn.getMix() > 0 && countInputsAtMix(dupTail, 0.25) == 1;
        var dupMove:FmodResult = other.addGroup(dupChild);
        var dupMix = dupConn.getMix();
        var dupResult = StudioSystem.lastResult();
        var dupSends = countInputsAtMix(dupTail, 0.25);
        @:privateAccess state.check("cg_add_group_second_tail_connection", dupLive && dupMove.isOk() && dupMix == 0
            && dupResult == FmodResult.FMOD_ERR_INVALID_HANDLE && dupSends == 1 && connLive(dupSend, 0.25),
            'live=$dupLive move=${dupMove.toString()} result=${dupResult.toString()} sends=$dupSends');
        // The same holds for a channel. The game sends to a group's tail
        // first, then moves the channel into the group and out again.
        var otherTail = other.getDsp(ChannelGroup.DSP_TAIL);
        var chanSend = otherTail.addInput(channel.getDsp(Channel.DSP_HEAD), DspConnection.TYPE_SEND);
        chanSend.setMix(0.25);
        var tailInputs = [for (i in 0...otherTail.getInputCount()) (otherTail.getInputConnection(i) : Int)];
        var chanJoin:FmodResult = channel.setChannelGroup(other);
        var chanParent = DspConnection.NULL;
        for (i in 0...otherTail.getInputCount()) {
            var c = otherTail.getInputConnection(i);
            if (tailInputs.indexOf((c : Int)) < 0) chanParent = c;
        }
        var chanLive = !chanSend.isNull() && chanJoin.isOk() && !chanParent.isNull() && chanParent.getMix() > 0;
        var chanLeave:FmodResult = channel.setChannelGroup(child);
        var chanMix = chanParent.getMix();
        var chanResult = StudioSystem.lastResult();
        var chanSends = countInputsAtMix(otherTail, 0.25);
        @:privateAccess state.check("chan_set_channel_group_second_tail_connection", chanLive && chanLeave.isOk() && chanMix == 0
            && chanResult == FmodResult.FMOD_ERR_INVALID_HANDLE && chanSends == 1 && connLive(chanSend, 0.25),
            'live=$chanLive leave=${chanLeave.toString()} result=${chanResult.toString()} sends=$chanSends');
        dupChild.release();
        dupParent.release();

        // A DSP at a group's tail carries the connections of the group's
        // children. FMOD destroys the connection of a lone child when that
        // DSP moves, and its handle fails the check. A fresh DSP at the
        // tail takes the connection over, and the handle follows the tail.
        // The bystander keeps working throughout.
        var tailParent = ChannelGroup.create("probe-cc-tail-parent");
        var tailChild = ChannelGroup.create("probe-cc-tail-child");
        var tailConn = tailParent.addGroupConnection(tailChild);
        tailConn.setMix(0.6);
        var tailDsp = Dsp.create(DspType.LOWPASS);
        var tailAdd:FmodResult = tailParent.addDsp(tailParent.getNumDSPs(), tailDsp);
        var tailKept = tailConn.getMix();
        var tailKeptResult = StudioSystem.lastResult();
        @:privateAccess state.check("cg_add_dsp_fresh_keeps_connection", tailAdd.isOk() && tailKeptResult.isOk()
            && Math.abs(tailKept - 0.6) < 0.001, 'add=${tailAdd.toString()} result=${tailKeptResult.toString()} mix=$tailKept');
        var tailMove:FmodResult = tailParent.setDspIndex(tailDsp, 0);
        tailConn.getMix();
        var tailMoveResult = StudioSystem.lastResult();
        @:privateAccess state.check("cg_set_dsp_index_tail_ends_connection", tailMove.isOk()
            && tailMoveResult == FmodResult.FMOD_ERR_INVALID_HANDLE && connLive(bystander, 0.4),
            'move=${tailMove.toString()} result=${tailMoveResult.toString()}');
        var readdParent = ChannelGroup.create("probe-cc-readd-parent");
        var readdChild = ChannelGroup.create("probe-cc-readd-child");
        var readdConn = readdParent.addGroupConnection(readdChild);
        var readdDsp = Dsp.create(DspType.HIGHPASS);
        var readdFirst:FmodResult = readdParent.addDsp(readdParent.getNumDSPs(), readdDsp);
        readdConn.getMix();
        var readdLive = readdFirst.isOk() && StudioSystem.lastResult().isOk();
        var readdAgain:FmodResult = readdParent.addDsp(0, readdDsp);
        readdConn.getMix();
        var readdResult = StudioSystem.lastResult();
        @:privateAccess state.check("cg_add_dsp_tail_again_ends_connection", readdLive && readdAgain.isOk()
            && readdResult == FmodResult.FMOD_ERR_INVALID_HANDLE && connLive(bystander, 0.4),
            'live=$readdLive again=${readdAgain.toString()} result=${readdResult.toString()}');
        readdParent.removeDsp(readdDsp);
        readdDsp.release();
        readdChild.release();
        readdParent.release();
        tailParent.removeDsp(tailDsp);
        tailDsp.release();
        tailChild.release();
        tailParent.release();

        // Each graph call ends only the handles of the connections it
        // destroys or moves. The bystander joins two DSPs none of these
        // calls touches.
        var fxStream = PcmStream.create(48000, 2);
        var fxChannel = fxStream.play(false);
        var fx = Dsp.create(DspType.LOWPASS);
        var fxIn = Dsp.create(DspType.MIXER);
        var fxOut = Dsp.create(DspType.MIXER);
        fxChannel.addDsp(0, fx);
        var fxFeed = fx.addInput(fxIn);
        fxFeed.setMix(0.3);
        var fxSend = fxOut.addInput(fx, DspConnection.TYPE_SEND);
        fxSend.setMix(0.5);
        var fxLive = connLive(fxFeed, 0.3) && connLive(fxSend, 0.5);
        var fxStop:FmodResult = fxChannel.stop();
        // The stop takes the DSP out of the channel's chain and moves its
        // input onto the chain. The send out of it stays.
        @:privateAccess state.check("chan_stop_ends_feed_keeps_send", fxLive && fxStop.isOk() && connDead(fxFeed)
            && connLive(fxSend, 0.5) && connLive(bystander, 0.4), 'live=$fxLive stop=${fxStop.toString()}');
        var fxFeed2 = fx.addInput(fxIn);
        var fxFed = connLive(fxFeed2, 1.0);
        var fxRelease:FmodResult = fx.release();
        @:privateAccess state.check("dsp_release_ends_its_connections", fxFed && fxRelease.isOk() && connDead(fxFeed2)
            && connDead(fxSend) && connLive(bystander, 0.4), 'fed=$fxFed release=${fxRelease.toString()}');
        fxIn.release();
        fxOut.release();
        fxStream.release();

        var relParent = ChannelGroup.create("probe-cc-rel-parent");
        var relChild = ChannelGroup.create("probe-cc-rel-child");
        var relConn = relParent.addGroupConnection(relChild);
        relConn.setMix(0.7);
        var relLive = connLive(relConn, 0.7);
        var relRelease:FmodResult = relChild.release();
        @:privateAccess state.check("cg_release_ends_child_connection", relLive && relRelease.isOk() && connDead(relConn)
            && connLive(bystander, 0.4), 'live=$relLive release=${relRelease.toString()}');
        relParent.release();

        var rmGroup = ChannelGroup.create("probe-cc-rm");
        var rmDsp = Dsp.create(DspType.LOWPASS);
        var rmIn = Dsp.create(DspType.MIXER);
        var rmOut = Dsp.create(DspType.MIXER);
        rmGroup.addDsp(0, rmDsp);
        var rmFeed = rmDsp.addInput(rmIn);
        rmFeed.setMix(0.3);
        var rmSend = rmOut.addInput(rmDsp, DspConnection.TYPE_SEND);
        rmSend.setMix(0.5);
        var rmLive = connLive(rmFeed, 0.3) && connLive(rmSend, 0.5);
        var rmResult:FmodResult = rmGroup.removeDsp(rmDsp);
        @:privateAccess state.check("cg_remove_dsp_ends_feed_keeps_send", rmLive && rmResult.isOk() && connDead(rmFeed)
            && connLive(rmSend, 0.5) && connLive(bystander, 0.4), 'live=$rmLive remove=${rmResult.toString()}');
        var daFeed = rmDsp.addInput(rmIn);
        var daLive = connLive(daFeed, 1.0);
        var daResult:FmodResult = rmDsp.disconnectAll(true, false);
        @:privateAccess state.check("dsp_disconnect_all_ends_inputs_keeps_send", daLive && daResult.isOk() && connDead(daFeed)
            && connLive(rmSend, 0.5) && connLive(bystander, 0.4), 'live=$daLive result=${daResult.toString()}');
        rmOut.release();
        rmIn.release();
        rmDsp.release();
        rmGroup.release();

        // A reorder in a chain leaves the child's connection and a send out
        // of the chain alone
        var roParent = ChannelGroup.create("probe-cc-ro-parent");
        var roChild = ChannelGroup.create("probe-cc-ro-child");
        var roConn = roParent.addGroupConnection(roChild);
        roConn.setMix(0.6);
        var roX = Dsp.create(DspType.LOWPASS);
        var roY = Dsp.create(DspType.HIGHPASS);
        var roOut = Dsp.create(DspType.MIXER);
        roParent.addDsp(0, roX);
        roParent.addDsp(0, roY);
        var roSend = roOut.addInput(roX, DspConnection.TYPE_SEND);
        roSend.setMix(0.5);
        var roIn = Dsp.create(DspType.MIXER);
        var roFeed = roX.addInput(roIn);
        roFeed.setMix(0.3);
        var roLive = connLive(roConn, 0.6) && connLive(roSend, 0.5) && connLive(roFeed, 0.3);
        var roMove:FmodResult = roParent.setDspIndex(roY, 1);
        @:privateAccess state.check("cg_set_dsp_index_keeps_unrelated_connections", roLive && roMove.isOk()
            && connLive(roConn, 0.6) && connLive(roSend, 0.5) && connLive(bystander, 0.4),
            'live=$roLive move=${roMove.toString()}');
        // FMOD moved the feed onto the DSP above roX. Its
        // handle fails, and a walk to the moved connection mints a new one.
        var roWalked = DspConnection.NULL;
        for (i in 0...roY.getInputCount()) {
            var c = roY.getInputConnection(i);
            if (Math.abs(c.getMix() - 0.3) < 0.001) roWalked = c;
        }
        @:privateAccess state.check("cg_set_dsp_index_moved_feed_rewalks", connDead(roFeed) && !roWalked.isNull()
            && (roWalked : Int) != (roFeed : Int) && connLive(roWalked, 0.3),
            'walked=${(roWalked : Int)} feed=${(roFeed : Int)}');
        roIn.release();
        roParent.removeDsp(roX);
        roParent.removeDsp(roY);
        roOut.release();
        roX.release();
        roY.release();
        roChild.release();
        roParent.release();

        // FMOD destroys a standard input of a DSP that a chain takes
        var fedParent = ChannelGroup.create("probe-cc-fed-parent");
        var fedSource = Dsp.create(DspType.MIXER);
        var fedDsp = Dsp.create(DspType.LOWPASS);
        var fedConn = fedDsp.addInput(fedSource);
        var fedLive = connLive(fedConn, 1.0);
        var fedAdd:FmodResult = fedParent.addDsp(0, fedDsp);
        @:privateAccess state.check("cg_add_dsp_fed_ends_connection", fedLive && fedAdd.isOk() && connDead(fedConn)
            && connLive(bystander, 0.4), 'live=$fedLive add=${fedAdd.toString()}');
        fedParent.removeDsp(fedDsp);
        fedDsp.release();
        fedSource.release();
        fedParent.release();

        // An addDsp past the end of the DSP's own chain takes the DSP out of
        // the chain before FMOD refuses the index
        var refParent = ChannelGroup.create("probe-cc-refused-parent");
        var refChild = ChannelGroup.create("probe-cc-refused-child");
        var refConn = refParent.addGroupConnection(refChild);
        var refDsp = Dsp.create(DspType.LOWPASS);
        var refFirst:FmodResult = refParent.addDsp(refParent.getNumDSPs(), refDsp);
        var refLive = refFirst.isOk() && connLive(refConn, 1.0);
        var refAgain:FmodResult = refParent.addDsp(refParent.getNumDSPs(), refDsp);
        @:privateAccess state.check("cg_add_dsp_refused_ends_connection", refLive
            && refAgain == FmodResult.FMOD_ERR_INVALID_PARAM && connDead(refConn) && connLive(bystander, 0.4),
            'live=$refLive again=${refAgain.toString()}');
        refParent.removeDsp(refDsp);
        refDsp.release();
        refChild.release();
        refParent.release();

        // FMOD lists a DSP that another chain holds in both chains, and a
        // later release frees it while one chain still uses it. So a second
        // chain refuses the DSP until the first one removes it. A channel's
        // own DSP counts as held by that channel. An add after the removal,
        // a re-add in the same chain, and a reuse after the holding channel
        // stops or ends all work.
        var inuseGroup = ChannelGroup.create("probe-cc-inuse-group");
        var inuseOther = ChannelGroup.create("probe-cc-inuse-other");
        var inuseStream = PcmStream.create(48000, 1);
        var inuseChannel = inuseStream.play(false, inuseGroup);
        var inuseDsp = Dsp.create(DspType.LOWPASS);
        var inFirst:FmodResult = inuseChannel.addDsp(0, inuseDsp);
        var inGroup:FmodResult = inuseGroup.addDsp(0, inuseDsp);
        var inOther:FmodResult = inuseOther.addDsp(0, inuseDsp);
        var inFader:FmodResult = inuseOther.addDsp(0, inuseChannel.getDsp(Channel.DSP_FADER));
        var inRemove:FmodResult = inuseChannel.removeDsp(inuseDsp);
        var inAfterRemove:FmodResult = inuseGroup.addDsp(0, inuseDsp);
        var inSame:FmodResult = inuseGroup.addDsp(1, inuseDsp);
        var inSameIndex = inuseGroup.getDspIndex(inuseDsp);
        var inBack:FmodResult = inuseChannel.addDsp(0, inuseDsp);
        inuseGroup.removeDsp(inuseDsp);
        var stopStream = PcmStream.create(48000, 1);
        var stopChannel = stopStream.play(false, inuseOther);
        var inStopFirst:FmodResult = stopChannel.addDsp(0, inuseDsp);
        stopChannel.stop();
        var inAfterStop:FmodResult = inuseChannel.addDsp(0, inuseDsp);
        // The group stop ends the channel with no call on its handle
        inuseGroup.stop();
        var inAfterEnd:FmodResult = inuseOther.addDsp(0, inuseDsp);
        var inCleanup:FmodResult = inuseOther.removeDsp(inuseDsp);
        var inRelease:FmodResult = inuseDsp.release();
        @:privateAccess state.check("chan_add_dsp_held_elsewhere_inuse", inFirst.isOk()
            && inGroup == FmodResult.FMOD_ERR_DSP_INUSE && inOther == FmodResult.FMOD_ERR_DSP_INUSE
            && inFader == FmodResult.FMOD_ERR_DSP_INUSE && inRemove.isOk() && inAfterRemove.isOk()
            && inSame.isOk() && inSameIndex == 1 && inBack == FmodResult.FMOD_ERR_DSP_INUSE
            && inStopFirst.isOk() && inAfterStop.isOk() && inAfterEnd.isOk() && inCleanup.isOk() && inRelease.isOk(),
            'first=${inFirst.toString()} group=${inGroup.toString()} other=${inOther.toString()} fader=${inFader.toString()}'
            + ' remove=${inRemove.toString()} afterRemove=${inAfterRemove.toString()} same=${inSame.toString()}/$inSameIndex'
            + ' back=${inBack.toString()} stopFirst=${inStopFirst.toString()} afterStop=${inAfterStop.toString()}'
            + ' afterEnd=${inAfterEnd.toString()} cleanup=${inCleanup.toString()} release=${inRelease.toString()}');
        // The stop of an ended channel frees its handle
        inuseChannel.stop();
        stopStream.release();
        inuseStream.release();
        inuseOther.release();
        inuseGroup.release();

        // A group's own fader reached through a DSP walk has no recorded
        // chain. FMOD accepts it in a second chain and reads freed memory
        // after the group's release. So another group refuses it. A
        // channel refuses it too.
        var walkGroup = ChannelGroup.create("probe-cc-walk-group");
        var walkOther = ChannelGroup.create("probe-cc-walk-other");
        var walkDsp = Dsp.create(DspType.LOWPASS);
        var walkStream = PcmStream.create(48000, 1);
        var walkChannel = walkStream.play(false, walkOther);
        var walkFirst:FmodResult = walkGroup.addDsp(0, walkDsp);
        var walkFader = walkDsp.getInput(0);
        var walkFaderIndex = walkGroup.getDspIndex(walkFader);
        var walkAdd:FmodResult = walkOther.addDsp(0, walkFader);
        var walkListed = walkOther.getDspIndex(walkFader);
        if (walkAdd.isOk()) walkOther.removeDsp(walkFader);
        var walkChannelAdd:FmodResult = walkChannel.addDsp(0, walkFader);
        if (walkChannelAdd.isOk()) walkChannel.removeDsp(walkFader);
        var walkRemove:FmodResult = walkGroup.removeDsp(walkDsp);
        var walkRelease:FmodResult = walkDsp.release();
        @:privateAccess state.check("cg_add_dsp_walked_fader_inuse", walkFirst.isOk() && !walkFader.isNull()
            && walkFaderIndex == 1 && walkAdd == FmodResult.FMOD_ERR_DSP_INUSE && walkListed == -1
            && walkChannelAdd == FmodResult.FMOD_ERR_DSP_INUSE && walkRemove.isOk() && walkRelease.isOk(),
            'first=${walkFirst.toString()} fader=${(walkFader : Int)}/$walkFaderIndex add=${walkAdd.toString()}'
            + ' listed=$walkListed channel=${walkChannelAdd.toString()} remove=${walkRemove.toString()}'
            + ' release=${walkRelease.toString()}');
        walkChannel.stop();
        walkStream.release();
        walkOther.release();
        walkGroup.release();

        // A Studio effect that the game removes from its bus group still
        // dies with that group. So another chain refuses it. Its own group
        // takes it back. Reached first by a DSP walk, it moves inside its
        // own chain.
        var fxBus = StudioSystem.getBus("bus:/Reverb");
        var fxLock:FmodResult = fxBus.lockChannelGroup();
        var fxGroup = fxBus.getChannelGroup();
        var fxOther = ChannelGroup.create("probe-cc-fx-other");
        var fxWalk = fxGroup.getDsp(ChannelGroup.DSP_HEAD).getInput(0);
        var fxWalkAt = fxGroup.getDspIndex(fxWalk);
        var fxWalkMove:FmodResult = fxGroup.addDsp(fxWalkAt, fxWalk);
        var fxWalkIndex = fxGroup.getDspIndex(fxWalk);
        var fx = Dsp.NULL;
        for (i in 0...fxGroup.getNumDSPs()) {
            var candidate = fxGroup.getDsp(i);
            if (candidate.getType() == DspType.SFXREVERB) fx = candidate;
        }
        var fxIndex = fxGroup.getDspIndex(fx);
        var fxRemove:FmodResult = fxGroup.removeDsp(fx);
        var fxAdd:FmodResult = fxOther.addDsp(0, fx);
        if (fxAdd.isOk()) fxOther.removeDsp(fx);
        var fxBack:FmodResult = fxGroup.addDsp(fxIndex, fx);
        var fxBackIndex = fxGroup.getDspIndex(fx);
        @:privateAccess state.check("cg_add_dsp_studio_effect_moved_inuse", fxLock.isOk() && !fx.isNull()
            && fxRemove.isOk() && fxAdd == FmodResult.FMOD_ERR_DSP_INUSE && fxBack.isOk() && fxBackIndex == fxIndex
            && fxWalkAt >= 0 && fxWalkMove.isOk() && fxWalkIndex == fxWalkAt,
            'lock=${fxLock.toString()} fx=${(fx : Int)}/$fxIndex remove=${fxRemove.toString()} add=${fxAdd.toString()}'
            + ' back=${fxBack.toString()}/$fxBackIndex walk=${(fxWalk : Int)}/$fxWalkAt/${fxWalkMove.toString()}/$fxWalkIndex');
        fxOther.release();
        fxBus.unlockChannelGroup();
        bystanderOut.release();
        bystanderIn.release();

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
     * get an Occlusion event within a few frames.
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
        _waitStamp = haxe.Timer.stamp();
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
        // FMOD recomputes geometry occlusion when the listener or the
        // source moves. Re-setting the same position does not count as a
        // move (seen on macOS, where the second event sometimes never
        // came). Wobble the listener by a hair every frame so the polygon
        // added after the channel started gets evaluated.
        StudioSystem.setListenerPosition2D(0, -5 + (_frames % 2 == 0 ? 0.01 : -0.01), 0);
        var sawChannel = false;
        var sawGroup = false;
        // the first occlusion event can carry zero before the geometry
        // settles, so wait for one with a real value
        for (e in _events) switch (e) {
            case Occlusion(d, _) if (d > 0): sawChannel = true;
            default:
        }
        for (e in _groupEvents) if (e.match(Occlusion(_, _))) sawGroup = true;
        // Bounded in frames and in seconds. A slow loop otherwise spends
        // most of the state's minute here when the recompute never comes.
        // Kha on the macOS runner draws about eleven frames a second.
        if ((sawChannel && sawGroup) || _frames > 300 || haxe.Timer.stamp() - _waitStamp > 5) {
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
        // What FMOD itself reports at this moment, for a timed-out wait
        var live = _channel.get3DOcclusion();
        var listener = StudioSystem.getListenerAttributes(0);
        var query = Geometry.getOcclusion({x: -5, y: 0, z: 0}, {x: 5, y: 0, z: 0});
        // A timed-out wait with an event delivered and FMOD's own query
        // reporting the occlusion proves the callback path and the
        // geometry. In that case FMOD's recompute never pushed the new
        // value. That is FMOD's cadence, and the info line below says it
        // happened.
        var recomputeMissed = !(sawChannel && direct > 0) && _events.length > 0 && query != null && query.direct > 0;
        if (recomputeMissed) @:privateAccess state.info("chan_occlusion_recompute", 'missed after $_frames frames');
        @:privateAccess state.check("chan_occlusion_event_delivered", (sawChannel && direct > 0) || recomputeMissed,
            'events=${_events.length} frames=$_frames direct=$direct'
            + ' live_direct=${live == null ? -1 : live.direct} playing=${_channel.isPlaying()}'
            + ' listener=${listener == null ? "null" : listener.position.x + "," + listener.position.y + "," + listener.position.z}'
            + ' query_direct=${query == null ? -1 : query.direct}');
        @:privateAccess state.check("cg_occlusion_event_delivered", sawGroup,
            'events=${_groupEvents.length} frames=$_frames');
        var rStop = _channel.stop();
        // Core commands cross to the mixer asynchronously. The stop is
        // applied at the start of a mix block, so wait until the group
        // reports nothing playing (bounded). The channel handle itself is
        // freed by the stop, so it reads as stopped at once and cannot be
        // the thing waited on. A lock and unlock pair then waits out the
        // block in flight. The stream and group are then safe from a
        // teardown under a live mix that reads them.
        var waited = 0;
        for (i in 0...100) {
            if (!_group.isPlaying()) break;
            waited++;
            #if sys
            Sys.sleep(0.01);
            #end
        }
        @:privateAccess state.check("occlusion_group_stopped", !_group.isPlaying(), 'waited=$waited');
        StudioSystem.lockDsp();
        StudioSystem.unlockDsp();
        var rStream = _stream.release();
        var rGroup = _group.release();
        // Occlusion is computed on FMOD's update thread, which the lock
        // pair does not hold. The listener goes home and the Studio queue
        // is flushed, so nothing is occluded when the polygon goes.
        StudioSystem.setListenerPosition2D(0, 0, 0);
        StudioSystem.flushCommands();
        var rGeometry = _geometry.release();
        // Occlusion callbacks arrive from the mixer thread, so let the
        // queue drain and the count settle (bounded) before comparing.
        // Fewer handles than the baseline only means an earlier probe's
        // events drained late. The release results are in the detail so a
        // handle that stays behind names its owner.
        var settled = 0;
        for (i in 0...100) {
            StudioSystem.flushCommands();
            haxefmod.studio.CallbackDispatcher.update();
            if (StudioSystem.liveHandleCount() <= _baseline) break;
            settled++;
            #if sys
            Sys.sleep(0.01);
            #end
        }
        @:privateAccess state.check("no_handle_leaks_occlusion_callback", StudioSystem.liveHandleCount() <= _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()} waited=$waited settle_wait=$settled stop=${rStop.toString()} stream=${rStream.toString()} group=${rGroup.toString()} geometry=${rGeometry.toString()}');
        _finished = true;
    }
}
