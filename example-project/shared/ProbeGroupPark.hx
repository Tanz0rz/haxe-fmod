package;

import fmodtest.ApiProbeScenario;
import haxefmod.core.Channel;
import haxefmod.core.ChannelGroup;
import haxefmod.core.ChannelMode;
import haxefmod.core.Dsp;
import haxefmod.core.Geometry;
import haxefmod.core.PcmStream;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types.FmodVector;

/**
 * Probe for a channel group released while a Geometry exists. FMOD frees
 * a group with its occlusion request still queued for the geometry
 * thread. So the native shims park such a group and run the FMOD release
 * once 60 ms have passed. The game's handle dies at once. The group
 * walks skip the parked group. Its channels and child groups move to the
 * master at once. The parked group's DSPs stay in the graph until the
 * FMOD release, which is how this probe sees that release happen. A
 * parent group of the probe's own holds the parked group, so nothing
 * else in the mix changes the input count it reads. Geometry is native
 * only, so the probe skips the web build.
 */
class ProbeGroupPark {
    static var _started:Bool = false;
    static var _finished:Bool = false;
    static var _moving:Bool = false;
    static var _waiting:Bool = false;
    static var _frames:Int = 0;
    static var _stamp:Float = 0;
    static var _releasedAt:Float = 0;
    static var _baseline:Int = 0;
    static var _listener:FmodVector = {x: 0, y: 0, z: 0};
    static var _geometry:Geometry = Geometry.NULL;
    static var _parent:ChannelGroup = ChannelGroup.NULL;
    static var _group:ChannelGroup = ChannelGroup.NULL;
    static var _child:ChannelGroup = ChannelGroup.NULL;
    static var _stream:PcmStream = PcmStream.NULL;
    static var _channel:Channel = Channel.NULL;
    static var _parentHead:Dsp = Dsp.NULL;

    /** True until the parked release and its leak count have run (never on js). */
    public static function pending():Bool {
        #if js
        return false;
        #else
        return !_finished;
        #end
    }

    /**
     * Called from the state's update once the occlusion probe is done.
     * Sets the group up on the first call, moves it for a few frames,
     * releases it, and then waits for the FMOD release.
     */
    public static function tick(state:ApiProbeScenario):Void {
        #if js
        return;
        #end
        if (!_started) {
            _started = true;
            start(state);
            return;
        }
        if (_moving) {
            _frames++;
            // A moving 3D group asks for occlusion on every update
            _group.set3DAttributes(5 + (_frames % 2 == 0 ? 0.01 : -0.01), 0, 0);
            if (_frames >= 6 && haxe.Timer.stamp() - _stamp > 0.1) {
                _moving = false;
                releaseMoving(state);
            }
            return;
        }
        if (_waiting) {
            // The drain is a drop point, where a parked group whose wait
            // is over gets its FMOD release
            haxefmod.studio.CallbackDispatcher.update();
            var elapsed = haxe.Timer.stamp() - _releasedAt;
            if (_parentHead.getNumInputs() == 0 || elapsed > 3) {
                _waiting = false;
                finish(state, elapsed);
            }
        }
    }

    static function start(state:ApiProbeScenario):Void {
        // The master's fixed handle exists before the baseline
        ChannelGroup.master();
        _baseline = StudioSystem.liveHandleCount();
        var attributes = StudioSystem.getListenerAttributes(0);
        if (attributes != null) _listener = {x: attributes.position.x, y: attributes.position.y, z: 0};
        StudioSystem.setListenerPosition2D(0, -5, 0);
        _geometry = Geometry.create(4, 16);
        var quad:Array<FmodVector> = [{x: 0, y: -10, z: -10}, {x: 0, y: 10, z: -10}, {x: 0, y: 10, z: 10}, {x: 0, y: -10, z: 10}];
        _geometry.addPolygon(1.0, 0.5, true, quad);
        _parent = ChannelGroup.create("probe-park-parent");
        _group = ChannelGroup.create("probe-park-group");
        _child = ChannelGroup.create("probe-park-child");
        _parent.addGroup(_group);
        _group.addGroup(_child);
        _group.setMode(ChannelMode.MODE_3D);
        _group.set3DAttributes(5, 0, 0);
        _group.setCallback(function(_) {});
        _stream = PcmStream.create3d(48000, 1);
        _channel = _stream.play(false);
        _channel.setChannelGroup(_group);
        _channel.set3DAttributes(5, 0, 0);
        _parentHead = _parent.getDsp(ChannelGroup.DSP_HEAD);
        @:privateAccess state.check("cg_park_setup", !_geometry.isNull() && !_group.isNull() && !_child.isNull()
            && !_channel.isNull() && _parentHead.getNumInputs() == 1 && _parent.getNumGroups() == 1,
            'geometry=${(_geometry : Int)} group=${(_group : Int)} channel=${(_channel : Int)} inputs=${_parentHead.getNumInputs()}');
        _frames = 0;
        _stamp = haxe.Timer.stamp();
        _moving = true;
    }

    static function releaseMoving(state:ApiProbeScenario):Void {
        var master = ChannelGroup.master();
        // One more move and a flush leave the group's request queued for
        // the geometry thread when the release comes
        _group.set3DAttributes(5.02, 0, 0);
        StudioSystem.flushCommands();
        _releasedAt = haxe.Timer.stamp();
        var released:FmodResult = _group.release();
        var inputs = _parentHead.getNumInputs();
        @:privateAccess state.check("cg_park_release_ok", released == FmodResult.FMOD_OK, 'result=${released.toString()}');
        _group.getVolume();
        @:privateAccess state.check("cg_park_handle_dead", StudioSystem.lastResult() == FmodResult.FMOD_ERR_INVALID_HANDLE,
            'lastResult=${StudioSystem.lastResult().toString()}');
        // The walks skip the parked group
        var shown = _parent.getNumGroups();
        var first = _parent.getGroup(0);
        @:privateAccess state.check("cg_park_hidden_from_walks", shown == 0 && first.isNull(),
            'shown=$shown first=${(first : Int)} lastResult=${StudioSystem.lastResult().toString()}');
        // The FMOD release would move them there, so the move comes at once
        var childParent = _child.getParentGroup();
        var channelGroup = _channel.getChannelGroup();
        @:privateAccess state.check("cg_park_children_moved", (childParent : Int) == (master : Int)
            && (channelGroup : Int) == (master : Int),
            'childParent=${(childParent : Int)} channelGroup=${(channelGroup : Int)} master=${(master : Int)}');
        // The FMOD object waits on the parked list, so its DSPs still feed
        // the parent
        @:privateAccess state.check("cg_park_fmod_release_waits", inputs == 1, 'inputs=$inputs');
        _waiting = true;
    }

    static function finish(state:ApiProbeScenario, elapsed:Float):Void {
        var inputs = _parentHead.getNumInputs();
        // The FMOD release runs at the first drop point after the wait
        @:privateAccess state.check("cg_park_fmod_release_runs", inputs == 0 && elapsed >= 0.05,
            'inputs=$inputs elapsed_ms=${Math.round(elapsed * 1000)}');
        _channel.stop();
        var rStream = _stream.release();
        var rChild = _child.release();
        var rParent = _parent.release();
        var rGeometry = _geometry.release();
        StudioSystem.setListenerPosition2D(0, _listener.x, _listener.y);
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
        @:privateAccess state.check("no_handle_leaks_group_park", StudioSystem.liveHandleCount() <= _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()} settle_wait=$settled stream=${rStream.toString()}'
            + ' child=${rChild.toString()} parent=${rParent.toString()} geometry=${rGeometry.toString()}');
        _finished = true;
    }
}
