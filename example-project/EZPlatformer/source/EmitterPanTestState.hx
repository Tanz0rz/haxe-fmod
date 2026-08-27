package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.flixel.FmodFlxEmitter;
import haxefmod.flixel.FmodFlxListener;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test state for the flixel attachment components. Logs one "PAN_TEST:"
 * line per check. CI gates on "PAN_TEST: COMPLETE" with no "pass=false".
 *
 * Validates the attachment machinery end to end (FmodFlxEmitter follows a
 * sprite's midpoint, detach/release on destroy, FmodFlxListener driving
 * the listener position) and real spatialization: the 3D Spatial event
 * from the Extras bank, metered on its channel group, must favor the left
 * channel while the emitter sits left of the listener and flip when it
 * moves right.
 *
 * Select via HAXEFMOD_TEST_STATE=pan-test (native) or ?test=pan-test (HTML5).
 */
class EmitterPanTestState extends FlxState {
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('PAN_TEST: $name pass=$pass $detail');
    }

    static inline function approx(a:Float, b:Float):Bool {
        return Math.abs(a - b) < 0.01;
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();

        var label = new FlxText(0, 0, FlxG.width, "PAN_TEST running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("PAN_TEST: Starting");

        // Warm the event description cache (the lookup allocates one
        // persistent deduped handle), then capture the leak baseline: the
        // emitter's instance is the only allocation after this point and
        // destroy() must release it.
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var baseline = StudioSystem.liveHandleCount();

        // Emitter attached to a sprite: play + attach in one call
        var sprite = new FlxSprite(100, 50);
        sprite.width = 16;
        sprite.height = 16;
        var emitter = FmodFlxEmitter.play(FmodEvents.MusicMainLevel, sprite);
        add(emitter);

        check("emitter_instance_created", !emitter.instance.isNull(), "");
        var state = emitter.instance.getPlaybackState();
        check("emitter_instance_playing",
            state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING,
            'state=$state');

        // Move the sprite. FmodManager.Update drives the attach loop
        sprite.x = 300;
        sprite.y = 220;
        sprite.velocity.x = 40;
        sprite.velocity.y = -20;
        FmodManager.Update();

        var attributes = emitter.instance.get3DAttributes();
        check("emitter_attributes_readable", attributes != null, "");
        if (attributes != null) {
            var midX = sprite.x + sprite.width / 2;
            var midY = sprite.y + sprite.height / 2;
            check("emitter_position_follows_midpoint",
                approx(attributes.position.x, midX) && approx(attributes.position.y, midY),
                'position=(${attributes.position.x}, ${attributes.position.y}) expected=($midX, $midY)');
            check("emitter_velocity_follows_target",
                approx(attributes.velocity.x, 40) && approx(attributes.velocity.y, -20),
                'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');
        }

        check("attached_count_one", FmodRuntime.attachedCount() == 1,
            'count=${FmodRuntime.attachedCount()}');

        // Destroying the emitter detaches and releases the instance
        var handle:EventInstance = emitter.instance;
        emitter.destroy();
        check("attached_count_zero_after_destroy", FmodRuntime.attachedCount() == 0,
            'count=${FmodRuntime.attachedCount()}');
        check("instance_invalid_after_destroy", !handle.isValid(), "");

        // Listener follows the sprite's midpoint
        var listener = new FmodFlxListener(sprite);
        _targetListener = listener;
        add(listener);
        listener.update(0); // create() runs before the state update loop
        FmodManager.Update();

        var listenerAttributes = StudioSystem.getListenerAttributes(0);
        check("listener_attributes_readable", listenerAttributes != null, "");
        if (listenerAttributes != null) {
            var midX = sprite.x + sprite.width / 2;
            var midY = sprite.y + sprite.height / 2;
            check("listener_position_follows_midpoint",
                approx(listenerAttributes.position.x, midX) && approx(listenerAttributes.position.y, midY),
                'position=(${listenerAttributes.position.x}, ${listenerAttributes.position.y}) expected=($midX, $midY)');
        }

        check("no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

        // The remaining flixel components, none reached by other states
        var loaderFired = false;
        var loader = new haxefmod.flixel.FmodFlxBankLoader([], () -> loaderFired = true);
        add(loader);
        loader.update(0);
        check("bank_loader_empty_fires", loaderFired, "");
        loader.update(0);
        loader.destroy();

        var triggerBaseline = StudioSystem.liveHandleCount();
        var zone = flixel.math.FlxRect.get(0, 0, 200, 200);
        var trigger = new haxefmod.flixel.FmodFlxParameterTrigger(sprite, zone, "Nope", 1, 0);
        add(trigger);
        // Outside the zone (the sprite sits at 300, 220): the outside value
        // applies once through the global-parameter path
        trigger.update(0);
        check("parameter_trigger_applied", !StudioSystem.lastResult().isOk(),
            'result=${StudioSystem.lastResult().toString()}');
        trigger.destroy();
        zone.put();
        check("parameter_trigger_no_leak", StudioSystem.liveHandleCount() == triggerBaseline,
            'baseline=$triggerBaseline now=${StudioSystem.liveHandleCount()}');

        // Distance culling continues asynchronously from update(): fades,
        // restarts, and one-shot playout all take real frames
        _label = label;
        _listenerSprite = sprite;
        startCullPhases();
    }

    var _label:FlxText;
    var _listenerSprite:FlxSprite;
    var _cullSprite:FlxSprite;
    var _cullEmitter:FmodFlxEmitter;
    var _targetListener:FmodFlxListener;
    var _phase:String = "";
    var _phaseFrames:Int = 0;
    var _utilBaseline:Int = 0;

    /** Final pass/fail counts survive the state switch the transition test performs. */
    public static var finalPassCount:Int = 0;
    public static var finalFailCount:Int = 0;

    static inline var FAR:Float = 100000;
    static inline var PHASE_TIMEOUT:Int = 600;

    /**
     * Runs the culling flow against a looping event with an explicit cull
     * distance (the example bank has no authored 3D distances): cull when
     * far, restart when near, restart when culling is disabled mid-cull,
     * and leave one-shots alone entirely.
     */
    var _cullBaseline:Int = 0;

    function startCullPhases():Void {
        // Warm the description lookups so their persistent dedup handles
        // sit inside the baseline
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        StudioSystem.getEvent(FmodEvents.SFXJump);
        _cullBaseline = StudioSystem.liveHandleCount();
        _cullSprite = new FlxSprite(FAR, 0);
        _cullSprite.width = 16;
        _cullSprite.height = 16;
        _cullEmitter = FmodFlxEmitter.play(FmodEvents.MusicMainLevel, _cullSprite);
        add(_cullEmitter);
        _cullEmitter.stopEventsOutsideMaxDistance = true;
        _cullEmitter.cullMaxDistance = 500;
        _cullEmitter.cullCheckInterval = 1;
        enterPhase("loop_culls_when_far");
    }

    function enterPhase(phase:String):Void {
        _phase = phase;
        _phaseFrames = 0;
    }

    function cullState():FmodPlaybackState {
        return _cullEmitter.instance.getPlaybackState();
    }

    function stepCullPhases():Void {
        _phaseFrames++;
        var timedOut = _phaseFrames > PHASE_TIMEOUT;
        switch (_phase) {
            case "loop_culls_when_far":
                if (cullState() == FmodPlaybackState.STOPPED || timedOut) {
                    check("cull_loop_stopped_when_far", !timedOut, 'frames=$_phaseFrames');
                    // Bring the emitter in range: the emitter restarts it
                    _cullSprite.x = _listenerSprite.x;
                    _cullSprite.y = _listenerSprite.y;
                    enterPhase("loop_restarts_when_near");
                }
            case "loop_restarts_when_near":
                var state = cullState();
                var playing = state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING;
                if (playing || timedOut) {
                    check("cull_loop_restarted_when_near", !timedOut, 'frames=$_phaseFrames');
                    _cullSprite.x = FAR;
                    enterPhase("loop_culls_again");
                }
            case "loop_culls_again":
                if (cullState() == FmodPlaybackState.STOPPED || timedOut) {
                    check("cull_loop_stopped_again", !timedOut, 'frames=$_phaseFrames');
                    // Disabling culling while culled must restart the event
                    // instead of leaving it stopped forever
                    _cullEmitter.stopEventsOutsideMaxDistance = false;
                    enterPhase("loop_restarts_when_disabled");
                }
            case "loop_restarts_when_disabled":
                var state = cullState();
                var playing = state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING;
                if (playing || timedOut) {
                    check("cull_disable_restarts", !timedOut, 'frames=$_phaseFrames');
                    _cullEmitter.destroy();
                    // One-shot far outside the cull distance: it must play
                    // to its natural end, never cull-stopped
                    _cullSprite.x = FAR;
                    _cullEmitter = FmodFlxEmitter.play(FmodEvents.SFXJump, _cullSprite);
                    add(_cullEmitter);
                    _cullEmitter.stopEventsOutsideMaxDistance = true;
                    _cullEmitter.cullMaxDistance = 500;
                    _cullEmitter.cullCheckInterval = 1;
                    enterPhase("oneshot_plays_out");
                }
            case "oneshot_plays_out":
                if (cullState() == FmodPlaybackState.STOPPED || timedOut) {
                    check("cull_oneshot_played_out", !timedOut, 'frames=$_phaseFrames');
                    // Re-entering range must not replay a finished one-shot
                    _cullSprite.x = _listenerSprite.x;
                    _cullSprite.y = _listenerSprite.y;
                    enterPhase("oneshot_not_replayed");
                }
            case "oneshot_not_replayed":
                if (_phaseFrames > 30) {
                    check("cull_oneshot_not_replayed",
                        cullState() == FmodPlaybackState.STOPPED, 'state=${cullState()}');
                    _cullEmitter.destroy();
                    enterPhase("");
                    finishCullPhases();
                }
        }
    }

    function finishCullPhases():Void {
        // Both cull emitters are destroyed: the DESTROYED drain reclaims
        // their instance slots over the following frames, so flush first
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_handle_leaks_cull", StudioSystem.liveHandleCount() == _cullBaseline,
            'baseline=$_cullBaseline now=${StudioSystem.liveHandleCount()}');

        // Utilities wrapper: attach-and-forget playback through the facade.
        // The next phase waits for playout so the auto-release branch runs
        // under the leak gate instead of outliving the state.
        _utilBaseline = FmodRuntime.attachedCount();
        haxefmod.flixel.FmodFlxUtilities.PlaySoundOneShotAttached(FmodEvents.SFXJump, _listenerSprite);
        check("utilities_oneshot_attached", FmodRuntime.attachedCount() == _utilBaseline + 1,
            'count=${FmodRuntime.attachedCount()}');
        enterPhase("util_oneshot_playout");
    }

    function stepHardeningPhases():Void {
        _phaseFrames++;
        var timedOut = _phaseFrames > PHASE_TIMEOUT;
        switch (_phase) {
            case "util_oneshot_playout":
                if (FmodRuntime.attachedCount() == _utilBaseline || timedOut) {
                    check("attached_oneshot_auto_released", !timedOut, 'frames=$_phaseFrames');
                    // The auto-release freed the instance: after the drain
                    // the handle table is back to the cull baseline
                    StudioSystem.flushCommands();
                    FmodManager.Update();
                    check("no_handle_leaks_attached_oneshot",
                        StudioSystem.liveHandleCount() == _cullBaseline,
                        'baseline=$_cullBaseline now=${StudioSystem.liveHandleCount()}');
                    // Authored-distance path: with no explicit cullMaxDistance
                    // the emitter asks the event, and a 2D event reports max
                    // distance 0 - culling must stay a no-op
                    _cullSprite.x = FAR;
                    _cullEmitter = FmodFlxEmitter.play(FmodEvents.MusicMainLevel, _cullSprite);
                    add(_cullEmitter);
                    _cullEmitter.stopEventsOutsideMaxDistance = true;
                    _cullEmitter.cullCheckInterval = 1;
                    enterPhase("authored_cull_noop");
                }
            case "authored_cull_noop":
                if (_phaseFrames > 40) {
                    var state = cullState();
                    check("cull_authored_2d_event_never_culls",
                        state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING,
                        'state=$state');
                    _cullEmitter.destroy();
                    // Reclaim the destroyed emitter's slots before the
                    // spatial baseline snapshot
                    StudioSystem.flushCommands();
                    FmodManager.Update();
                    _spatialBaseline = StudioSystem.liveHandleCount();
                    _extrasPath = FmodRuntime.bankPath("Extras.bank");
                    FmodRuntime.banks.load(_extrasPath);
                    enterPhase("spatial_load");
                }
            case "spatial_load":
                if (FmodRuntime.banks.isLoaded(_extrasPath) || timedOut) {
                    check("spatial_extras_loaded", !timedOut, 'frames=$_phaseFrames');
                    startSpatialEmitter();
                    enterPhase("spatial_meter_left");
                }
            case "spatial_meter_left":
                trackSpatialPeaks();
                if (_phaseFrames > 90) {
                    check("spatial_left_audible", _peakL > 0.01, 'left=$_peakL right=$_peakR');
                    check("spatial_pans_left", _peakL > _peakR * 1.3, 'left=$_peakL right=$_peakR');
                    _spatialSprite.x = 310;
                    _peakL = 0;
                    _peakR = 0;
                    enterPhase("spatial_meter_right");
                }
            case "spatial_meter_right":
                // Let the pan ramp settle before tracking fresh maxima
                if (_phaseFrames > 30) trackSpatialPeaks();
                if (_phaseFrames > 150) {
                    check("spatial_pans_right", _peakR > _peakL * 1.3, 'left=$_peakL right=$_peakR');
                    finishSpatial();
                }
            case "transition_switches":
                if (_phaseFrames == 2) {
                    finalPassCount = _passCount;
                    finalFailCount = _failCount;
                    haxefmod.flixel.FmodFlxUtilities.TransitionToStateAndStopMusic(
                        () -> new PanTestDoneState());
                } else if (timedOut) {
                    // The switch never happened: fail loudly from this state
                    check("transition_switched_state", false, 'frames=$_phaseFrames');
                    log('PAN_TEST: COMPLETE passed=$_passCount failed=${_failCount}');
                    _done = true;
                }
        }
    }

    var _extrasPath:String;
    var _spatialBaseline:Int = 0;
    var _spatialSprite:FlxSprite;
    var _spatialEmitter:FmodFlxEmitter;
    var _spatialGroup:ChannelGroup = ChannelGroup.NULL;
    var _spatialMeter:Dsp = Dsp.NULL;
    var _peakL:Float = 0;
    var _peakR:Float = 0;

    /**
     * Plays the looping 3D Spatial event 10 units left of the listener
     * (which follows the listener sprite's midpoint at 308, 228) and
     * meters the instance's channel group. The metering DSP sits at the
     * head of the group's chain, after the spatializer, so its input peaks
     * are the panned stereo image.
     */
    function startSpatialEmitter():Void {
        _spatialSprite = new FlxSprite(290, 220);
        _spatialSprite.width = 16;
        _spatialSprite.height = 16;
        _spatialEmitter = FmodFlxEmitter.play(FmodEvents.SFXSpatial, _spatialSprite);
        add(_spatialEmitter);
        check("spatial_emitter_created", !_spatialEmitter.instance.isNull(), "");
        FmodManager.Update();
        StudioSystem.flushCommands();
        _spatialGroup = _spatialEmitter.instance.getChannelGroup();
        check("spatial_channel_group", !_spatialGroup.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        _spatialMeter = Dsp.create(DspType.FFT);
        if (!_spatialGroup.isNull()) {
            _spatialGroup.addDsp(0, _spatialMeter);
            // getMetering reads the output meter, so output metering must
            // be on (the FFT passes audio through unchanged)
            _spatialMeter.setMeteringEnabled(true, true);
        }
        _peakL = 0;
        _peakR = 0;
    }

    function trackSpatialPeaks():Void {
        var metering = _spatialMeter.getMetering();
        if (metering == null || metering.peak.length < 2) return;
        if (metering.peak[0] > _peakL) _peakL = metering.peak[0];
        if (metering.peak[1] > _peakR) _peakR = metering.peak[1];
    }

    function finishSpatial():Void {
        _spatialGroup.removeDsp(_spatialMeter);
        _spatialMeter.release();
        _spatialEmitter.destroy();
        // The release-all sweep reclaims the dead group's slot on html5,
        // and the drain does it on native
        StudioSystem.getEvent(FmodEvents.SFXSpatial).releaseAllInstances();
        StudioSystem.flushCommands();
        FmodManager.Update();
        FmodRuntime.banks.unload(_extrasPath);
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_spatial_leaks", StudioSystem.liveHandleCount() == _spatialBaseline,
            'baseline=$_spatialBaseline now=${StudioSystem.liveHandleCount()}');

        runCameraListenerChecks();
        runParameterTriggerChecks();
        // The transition test ends the state: a playing song plus
        // TransitionToStateAndStopMusic must fade out and switch
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);
        enterPhase("transition_switches");
    }

    /**
     * Camera-follow mode is the listener's default and its math-heaviest
     * path: velocity derived from the camera center's per-frame movement,
     * with jumps beyond teleportDistance treated as cuts. Driven manually
     * with a fixed elapsed so the derived velocity is deterministic.
     */
    function runCameraListenerChecks():Void {
        remove(_targetListener);
        _targetListener.destroy();

        var camera = FlxG.camera;
        var savedX = camera.scroll.x;
        var savedY = camera.scroll.y;
        var cameraListener = new FmodFlxListener();
        cameraListener.update(0.5); // seeds tracking, pushes zero velocity
        camera.scroll.x = savedX + 30;
        cameraListener.update(0.5);
        var attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_attributes_readable", attributes != null, "");
        if (attributes != null) {
            check("camera_listener_position_is_center",
                approx(attributes.position.x, camera.scroll.x + camera.width / 2)
                && approx(attributes.position.y, camera.scroll.y + camera.height / 2),
                'position=(${attributes.position.x}, ${attributes.position.y})');
            check("camera_listener_velocity_from_movement",
                approx(attributes.velocity.x, 60) && approx(attributes.velocity.y, 0),
                'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');
        }

        // A jump beyond teleportDistance is a cut: zero velocity
        cameraListener.teleportDistance = 100;
        camera.scroll.x += 5000;
        cameraListener.update(0.5);
        attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_teleport_zeroes_velocity",
            attributes != null && approx(attributes.velocity.x, 0) && approx(attributes.velocity.y, 0),
            attributes == null ? "unreadable" : 'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');

        // resetMotion: the next frame reads as a fresh seed, not movement
        camera.scroll.x = savedX;
        camera.scroll.y = savedY;
        cameraListener.resetMotion();
        cameraListener.update(0.5);
        attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_reset_motion_seeds",
            attributes != null && approx(attributes.velocity.x, 0),
            attributes == null ? "unreadable" : 'velocity=(${attributes.velocity.x})');
        cameraListener.destroy();
    }

    /**
     * A real zone crossing driving a real event parameter through the
     * trigger's instance variant, plus the contract that manual changes
     * between crossings are not fought over. The global path runs both
     * ways: the missing-name negative in create(), and a real crossing on
     * the authored Intensity parameter below.
     */
    function runParameterTriggerChecks():Void {
        var sprite = _listenerSprite; // sits at (300, 220)
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("trigger_event_has_parameters", desc.getParameterDescriptionCount() > 0,
            'count=${desc.getParameterDescriptionCount()}');
        if (desc.getParameterDescriptionCount() == 0) return;
        var param = desc.getParameterDescriptionByIndex(0);
        var inst = desc.createInstance();
        var mid = (param.minimum + param.maximum) / 2;
        var zone = flixel.math.FlxRect.get(250, 150, 200, 200);
        var trigger = new haxefmod.flixel.FmodFlxParameterTrigger(
            sprite, zone, param.name, param.maximum, param.minimum, inst);
        trigger.update(0);
        check("trigger_inside_value_applied",
            Math.abs(inst.getParameter(param.name) - param.maximum) < 0.001,
            'value=${inst.getParameter(param.name)}');
        // Manual changes between crossings survive
        inst.setParameter(param.name, mid);
        trigger.update(0);
        check("trigger_no_crossing_keeps_manual_value",
            Math.abs(inst.getParameter(param.name) - mid) < 0.001,
            'value=${inst.getParameter(param.name)}');
        // Crossing out applies the outside value
        sprite.x = 1000;
        trigger.update(0);
        check("trigger_outside_value_applied",
            Math.abs(inst.getParameter(param.name) - param.minimum) < 0.001,
            'value=${inst.getParameter(param.name)}');
        sprite.x = 300;
        trigger.destroy();
        zone.put();
        inst.release();

        // Global path with the authored Intensity parameter: a crossing
        // applies the inside value through StudioSystem
        var intensityBefore = StudioSystem.getParameter("Intensity");
        var globalZone = flixel.math.FlxRect.get(250, 150, 200, 200);
        var globalTrigger = new haxefmod.flixel.FmodFlxParameterTrigger(
            sprite, globalZone, "Intensity", 1, 0);
        globalTrigger.update(0); // the sprite sits at (300, 220), inside
        check("trigger_global_inside_applied",
            Math.abs(StudioSystem.getParameter("Intensity") - 1) < 0.001,
            'value=${StudioSystem.getParameter("Intensity")}');
        globalTrigger.destroy();
        globalZone.put();
        StudioSystem.setParameter("Intensity", intensityBefore, true);
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (_phase != "") {
            if (_phase == "util_oneshot_playout" || _phase == "authored_cull_noop"
                || _phase == "transition_switches" || _phase == "spatial_load"
                || _phase == "spatial_meter_left" || _phase == "spatial_meter_right") {
                stepHardeningPhases();
            } else {
                stepCullPhases();
            }
        }
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}

/**
 * Terminal state for the transition test: arriving here IS the check.
 * Prints the suite's COMPLETE line so CI's log gate sees the full result.
 */
class PanTestDoneState extends FlxState {
    var _framesWaited:Int = 0;

    override public function create():Void {
        super.create();
        var passed = EmitterPanTestState.finalPassCount + 1;
        var failed = EmitterPanTestState.finalFailCount;
        log2('PAN_TEST: transition_switched_state pass=true ');
        log2('PAN_TEST: COMPLETE passed=$passed failed=$failed');
        var label = new FlxText(0, 0, FlxG.width, 'PAN_TEST complete: $passed passed, $failed failed');
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);
    }

    static inline function log2(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(EmitterPanTestState.finalFailCount > 0 ? 1 : 0);
            #end
        }
    }
}
