package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
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
 * The example bank has no 3D events, so audible stereo panning cannot be
 * validated yet. This state validates the attachment machinery end to end
 * instead: FmodFlxEmitter follows a sprite's midpoint (2D events accept 3D
 * attributes, they just do not pan), detach/release on destroy, and
 * FmodFlxListener driving the listener position.
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
    var _phase:String = "";
    var _phaseFrames:Int = 0;

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

        // Utilities wrapper: attach-and-forget playback through the facade
        // (after the leak gate, since the one-shot outlives this state)
        var utilBaseline = FmodRuntime.attachedCount();
        haxefmod.flixel.FmodFlxUtilities.PlaySoundOneShotAttached(FmodEvents.SFXJump, _listenerSprite);
        check("utilities_oneshot_attached", FmodRuntime.attachedCount() == utilBaseline + 1,
            'count=${FmodRuntime.attachedCount()}');

        log('PAN_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        _label.text = 'PAN_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (_phase != "") stepCullPhases();
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
