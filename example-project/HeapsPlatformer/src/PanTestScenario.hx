package;

import h2d.Bitmap;
import h2d.Object;
import h2d.Tile;
import h2d.col.Bounds;
import fmodtest.TestHost;
import fmodtest.TestScenario;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.heaps.FmodHeapsBankLoader;
import haxefmod.heaps.FmodHeapsEmitter;
import haxefmod.heaps.FmodHeapsListener;
import haxefmod.heaps.FmodHeapsParameterTrigger;
import haxefmod.heaps.FmodHeapsUtilities;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test scenario for the Heaps attachment components. Logs one
 * "PAN_TEST:" line per check. CI gates on "PAN_TEST: COMPLETE" with no
 * "pass=false".
 *
 * Same flow as the flixel EmitterPanTestState: emitter follows an
 * object, detach and release on dispose, listener driving the listener
 * position, distance culling, the attached one-shot helper, and real
 * spatialization metered on the Spatial event's channel group. Heaps
 * objects carry no velocity, so the checks that need a known velocity
 * tick the component with a fixed elapsed time and move the object by a
 * known distance.
 *
 * Select via HAXEFMOD_TEST_STATE=pan-test (HashLink) or ?test=pan-test (browser).
 */
class PanTestScenario implements TestScenario {
    var host:HeapsTestHost;
    var root:Object;
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    public function new() {}

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

    function sprite(x:Float, y:Float):Bitmap {
        var bitmap = new Bitmap(Tile.fromColor(0xff00ff, 16, 16), root);
        bitmap.x = x;
        bitmap.y = y;
        return bitmap;
    }

    public function create(testHost:TestHost):Void {
        host = cast testHost;
        root = host.root;

        FmodManager.EnableDebugMessages();
        host.setStatus("PAN_TEST running");
        log("PAN_TEST: Starting");

        // Warm the event description cache (the lookup allocates one
        // persistent deduped handle), then capture the leak baseline: the
        // emitter's instance is the only allocation after this point and
        // dispose() must release it.
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var baseline = StudioSystem.liveHandleCount();

        // Emitter attached to an object: play + attach in one call
        var target = sprite(100, 50);
        var emitter = FmodHeapsEmitter.play(FmodEvents.MusicMainLevel, target);

        check("emitter_instance_created", !emitter.instance.isNull(), "");
        var state = emitter.instance.getPlaybackState();
        check("emitter_instance_playing",
            state == FmodPlaybackState.PLAYING || state == FmodPlaybackState.STARTING,
            'state=$state');

        // Seed the derived velocity at the start position, then move the
        // object 20 right and 10 up over half a second: velocity (40, -20)
        emitter.tick(0);
        target.x = 120;
        target.y = 40;
        emitter.tick(0.5);
        FmodManager.Update();

        var attributes = emitter.instance.get3DAttributes();
        check("emitter_attributes_readable", attributes != null, "");
        if (attributes != null) {
            var midX = target.x + 8;
            var midY = target.y + 8;
            check("emitter_position_follows_midpoint",
                approx(attributes.position.x, midX) && approx(attributes.position.y, midY),
                'position=(${attributes.position.x}, ${attributes.position.y}) expected=($midX, $midY)');
            check("emitter_velocity_follows_target",
                approx(attributes.velocity.x, 40) && approx(attributes.velocity.y, -20),
                'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');
        }

        check("attached_count_one", FmodRuntime.attachedCount() == 1,
            'count=${FmodRuntime.attachedCount()}');

        // Disposing the emitter detaches and releases the instance
        var handle:EventInstance = emitter.instance;
        emitter.dispose();
        check("attached_count_zero_after_destroy", FmodRuntime.attachedCount() == 0,
            'count=${FmodRuntime.attachedCount()}');
        check("instance_invalid_after_destroy", !handle.isValid(), "");

        // Listener follows the object's center
        target.x = 300;
        target.y = 220;
        var listener = new FmodHeapsListener(target);
        _targetListener = listener;
        listener.tick(0);
        FmodManager.Update();

        var listenerAttributes = StudioSystem.getListenerAttributes(0);
        check("listener_attributes_readable", listenerAttributes != null, "");
        if (listenerAttributes != null) {
            var midX = target.x + 8;
            var midY = target.y + 8;
            check("listener_position_follows_midpoint",
                approx(listenerAttributes.position.x, midX) && approx(listenerAttributes.position.y, midY),
                'position=(${listenerAttributes.position.x}, ${listenerAttributes.position.y}) expected=($midX, $midY)');
        }

        check("no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

        // The remaining components, none reached by other scenarios
        var loaderFired = false;
        var loader = new FmodHeapsBankLoader([], () -> loaderFired = true);
        loader.tick(0);
        check("bank_loader_empty_fires", loaderFired, "");
        loader.tick(0);
        loader.dispose();

        var triggerBaseline = StudioSystem.liveHandleCount();
        var trigger = new FmodHeapsParameterTrigger(target, Bounds.fromValues(0, 0, 200, 200), "Nope", 1, 0);
        // Outside the zone (the object sits at 300, 220): the outside value
        // applies once through the global-parameter path
        trigger.tick(0);
        check("parameter_trigger_applied", !StudioSystem.lastResult().isOk(),
            'result=${StudioSystem.lastResult().toString()}');
        trigger.dispose();
        check("parameter_trigger_no_leak", StudioSystem.liveHandleCount() == triggerBaseline,
            'baseline=$triggerBaseline now=${StudioSystem.liveHandleCount()}');

        // Distance culling continues asynchronously from update(): fades,
        // restarts, and one-shot playout all take real frames
        _listenerSprite = target;
        startCullPhases();
    }

    var _listenerSprite:Bitmap;
    var _cullSprite:Bitmap;
    var _cullEmitter:FmodHeapsEmitter;
    var _targetListener:FmodHeapsListener;
    var _phase:String = "";
    var _phaseFrames:Int = 0;
    var _utilBaseline:Int = 0;
    var _cullBaseline:Int = 0;

    static inline var FAR:Float = 100000;
    static inline var PHASE_TIMEOUT:Int = 600;

    /**
     * Runs the culling flow against a looping event with an explicit cull
     * distance (the example bank has no authored 3D distances): cull when
     * far, restart when near, restart when culling is disabled mid-cull,
     * and leave one-shots alone entirely.
     */
    function startCullPhases():Void {
        // Warm the description lookups so their persistent dedup handles
        // sit inside the baseline
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        StudioSystem.getEvent(FmodEvents.SFXJump);
        _cullBaseline = StudioSystem.liveHandleCount();
        _cullSprite = sprite(FAR, 0);
        _cullEmitter = FmodHeapsEmitter.play(FmodEvents.MusicMainLevel, _cullSprite);
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
                    _cullEmitter.dispose();
                    // One-shot far outside the cull distance: it must play
                    // to its natural end, never cull-stopped
                    _cullSprite.x = FAR;
                    _cullEmitter = FmodHeapsEmitter.play(FmodEvents.SFXJump, _cullSprite);
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
                    _cullEmitter.dispose();
                    enterPhase("");
                    finishCullPhases();
                }
        }
    }

    function finishCullPhases():Void {
        // Both cull emitters are disposed: the DESTROYED drain reclaims
        // their instance slots over the following frames, so flush first
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_handle_leaks_cull", StudioSystem.liveHandleCount() == _cullBaseline,
            'baseline=$_cullBaseline now=${StudioSystem.liveHandleCount()}');

        // Utilities wrapper: attach-and-forget playback through the facade.
        // The next phase waits for playout so the auto-release branch runs
        // under the leak gate instead of outliving the scenario.
        _utilBaseline = FmodRuntime.attachedCount();
        FmodHeapsUtilities.PlaySoundOneShotAttached(FmodEvents.SFXJump, _listenerSprite);
        check("utilities_oneshot_attached", FmodRuntime.attachedCount() == _utilBaseline + 1,
            'count=${FmodRuntime.attachedCount()}');
        enterPhase("util_oneshot_playout");
    }

    function stepHardeningPhases(dt:Float):Void {
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
                    _cullEmitter = FmodHeapsEmitter.play(FmodEvents.MusicMainLevel, _cullSprite);
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
                    _cullEmitter.dispose();
                    // Reclaim the disposed emitter's slots before the
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
                    // Doppler is enabled on the event: move the emitter and
                    // prove playback survives a real velocity
                    _spatialMoving = true;
                    _peakL = 0;
                    _peakR = 0;
                    enterPhase("spatial_doppler_motion");
                }
            case "spatial_doppler_motion":
                // 200 units per second, the derived velocity picks it up
                if (_spatialMoving) _spatialSprite.x += 200 * dt;
                trackSpatialPeaks();
                if (_phaseFrames > 60) {
                    _spatialMoving = false;
                    var moving = _spatialEmitter.instance.getPlaybackState();
                    check("spatial_doppler_motion_plays",
                        moving == FmodPlaybackState.PLAYING || moving == FmodPlaybackState.STARTING,
                        'state=$moving');
                    check("spatial_doppler_motion_audible", _peakL > 0.005 || _peakR > 0.005,
                        'left=$_peakL right=$_peakR');
                    finishSpatial();
                }
        }
    }

    var _extrasPath:String;
    var _spatialBaseline:Int = 0;
    var _spatialSprite:Bitmap;
    var _spatialMoving:Bool = false;
    var _spatialEmitter:FmodHeapsEmitter;
    var _spatialGroup:ChannelGroup = ChannelGroup.NULL;
    var _spatialMeter:Dsp = Dsp.NULL;
    var _peakL:Float = 0;
    var _peakR:Float = 0;

    /**
     * Plays the looping 3D Spatial event 10 units left of the listener
     * (which follows the listener object's center at 308, 228) and
     * meters the instance's channel group. The metering DSP sits at the
     * head of the group's chain, after the spatializer, so its input peaks
     * are the panned stereo image.
     */
    function startSpatialEmitter():Void {
        _spatialSprite = sprite(290, 220);
        _spatialEmitter = FmodHeapsEmitter.play(FmodEvents.SFXSpatial, _spatialSprite);
        _spatialEmitter.tick(0);
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
        if (metering == null || metering.peakLevel.length < 2) return;
        if (metering.peakLevel[0] > _peakL) _peakL = metering.peakLevel[0];
        if (metering.peakLevel[1] > _peakR) _peakR = metering.peakLevel[1];
    }

    function finishSpatial():Void {
        _spatialGroup.removeDsp(_spatialMeter);
        _spatialMeter.release();
        _spatialEmitter.dispose();
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
        log('PAN_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        host.setStatus('PAN_TEST complete: $_passCount passed, $_failCount failed');
        enterPhase("");
        _done = true;
    }

    /**
     * Scene-follow mode: velocity derived from the camera view center's
     * per-frame movement, with jumps beyond teleportDistance treated as
     * cuts. Driven manually with a fixed elapsed so the derived velocity
     * is deterministic.
     */
    function runCameraListenerChecks():Void {
        _targetListener.dispose();

        var scene = Main.instance.s2d;
        var camera = scene.camera;
        var savedX = camera.x;
        var savedY = camera.y;
        var cameraListener = new FmodHeapsListener();
        cameraListener.setScene(scene);
        cameraListener.tick(0.5); // seeds tracking, pushes zero velocity
        camera.x = savedX + 30;
        cameraListener.tick(0.5);
        var attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_attributes_readable", attributes != null, "");
        if (attributes != null) {
            var centerX = camera.x + (0.5 - camera.anchorX) * scene.width / camera.scaleX;
            var centerY = camera.y + (0.5 - camera.anchorY) * scene.height / camera.scaleY;
            check("camera_listener_position_is_center",
                approx(attributes.position.x, centerX) && approx(attributes.position.y, centerY),
                'position=(${attributes.position.x}, ${attributes.position.y}) expected=($centerX, $centerY)');
            check("camera_listener_velocity_from_movement",
                approx(attributes.velocity.x, 60) && approx(attributes.velocity.y, 0),
                'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');
        }

        // A jump beyond teleportDistance is a cut: zero velocity
        cameraListener.teleportDistance = 100;
        camera.x += 5000;
        cameraListener.tick(0.5);
        attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_teleport_zeroes_velocity",
            attributes != null && approx(attributes.velocity.x, 0) && approx(attributes.velocity.y, 0),
            attributes == null ? "unreadable" : 'velocity=(${attributes.velocity.x}, ${attributes.velocity.y})');

        // resetMotion: the next frame reads as a fresh seed, not movement
        camera.x = savedX;
        camera.y = savedY;
        cameraListener.resetMotion();
        cameraListener.tick(0.5);
        attributes = StudioSystem.getListenerAttributes(0);
        check("camera_listener_reset_motion_seeds",
            attributes != null && approx(attributes.velocity.x, 0),
            attributes == null ? "unreadable" : 'velocity=(${attributes.velocity.x})');
        cameraListener.dispose();
    }

    /**
     * A real zone crossing driving a real event parameter through the
     * trigger's instance variant, plus the contract that manual changes
     * between crossings are not fought over. The global path runs both
     * ways: the missing-name negative in create(), and a real crossing on
     * the authored Intensity parameter below.
     */
    function runParameterTriggerChecks():Void {
        var target = _listenerSprite; // sits at (300, 220)
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("trigger_event_has_parameters", desc.getParameterDescriptionCount() > 0,
            'count=${desc.getParameterDescriptionCount()}');
        if (desc.getParameterDescriptionCount() == 0) return;
        var param = desc.getParameterDescriptionByIndex(0);
        var inst = desc.createInstance();
        var mid = (param.minimum + param.maximum) / 2;
        var trigger = new FmodHeapsParameterTrigger(
            target, Bounds.fromValues(250, 150, 200, 200), param.name, param.maximum, param.minimum, inst);
        trigger.tick(0);
        check("trigger_inside_value_applied",
            Math.abs(inst.getParameter(param.name) - param.maximum) < 0.001,
            'value=${inst.getParameter(param.name)}');
        // Manual changes between crossings survive
        inst.setParameter(param.name, mid);
        trigger.tick(0);
        check("trigger_no_crossing_keeps_manual_value",
            Math.abs(inst.getParameter(param.name) - mid) < 0.001,
            'value=${inst.getParameter(param.name)}');
        // Crossing out applies the outside value
        target.x = 1000;
        trigger.tick(0);
        check("trigger_outside_value_applied",
            Math.abs(inst.getParameter(param.name) - param.minimum) < 0.001,
            'value=${inst.getParameter(param.name)}');
        target.x = 300;
        trigger.dispose();
        inst.release();

        // Global path with the authored Intensity parameter: a crossing
        // applies the inside value through StudioSystem
        var intensityBefore = StudioSystem.getParameter("Intensity");
        var globalTrigger = new FmodHeapsParameterTrigger(
            target, Bounds.fromValues(250, 150, 200, 200), "Intensity", 1, 0);
        globalTrigger.tick(0); // the object sits at (300, 220), inside
        check("trigger_global_inside_applied",
            Math.abs(StudioSystem.getParameter("Intensity") - 1) < 0.001,
            'value=${StudioSystem.getParameter("Intensity")}');
        globalTrigger.dispose();
        StudioSystem.setParameter("Intensity", intensityBefore, true);
    }

    public function update(elapsed:Float):Void {
        FmodManager.Update();
        if (_phase != "") {
            if (_phase == "util_oneshot_playout" || _phase == "authored_cull_noop"
                || _phase == "spatial_load" || _phase == "spatial_meter_left"
                || _phase == "spatial_meter_right" || _phase == "spatial_doppler_motion") {
                stepHardeningPhases(elapsed);
            } else {
                stepCullPhases();
            }
        }
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            host.exit(_failCount > 0 ? 1 : 0);
        }
    }
}
