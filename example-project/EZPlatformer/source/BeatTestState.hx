package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * CI test state for payload-carrying callbacks.
 *
 * Song flow: plays the song, registers a typed OnSongEvent handler, logs
 * every callback with its payload as a "CB_TEST:" line, then soft-stops the
 * song and waits for the Stopped event to prove the queue delivers end to
 * end.
 *
 * Overflow flow: floods the native callback ring (256 entries) by starting
 * many instances with full callback masks while update is deliberately
 * withheld, verifies the overflow flag trips, then proves delivery recovers
 * after a drain and that no instance handles leaked.
 *
 * CI gates on "CB_TEST: Stopped" and "CB_TEST: COMPLETE" with no
 * "pass=false". Beat and marker lines are informational (they only fire if
 * the FMOD project has tempo markers on the event timeline).
 *
 * Select via HAXEFMOD_TEST_STATE=cb-test (native) or ?test=cb-test (HTML5).
 */
class BeatTestState extends FlxState {
    // Each started instance pushes at least Starting/Started/SoundPlayed
    // into the queue, so 100 instances push well past the 256-entry ring
    // while updates are withheld. Keep this flood comfortably above
    // FAXE_CBQ_CAPACITY (native/shared/faxe_cbqueue.h) or the overflow
    // phase stops exercising the recovery path
    static inline var OVERFLOW_INSTANCES:Int = 100;
    // ~5 seconds at 60fps for the overflow flag to trip
    static inline var OVERFLOW_WAIT_FRAMES:Int = 300;
    // ~10 seconds at 60fps for the recovery Stopped to arrive
    static inline var RECOVERY_WAIT_FRAMES:Int = 600;

    // 0 = song flow, 1 = overflow wait, 2 = recovery wait, 3 = done
    var _phase:Int = 0;
    var _stopRequested:Bool = false;
    var _stoppedReceived:Bool = false;
    var _eventCount:Int = 0;
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _status:FlxText;

    var _baseline:Int = 0;
    var _overflowInstances:Array<EventInstance> = [];
    var _overflowSeen:Bool = false;
    var _overflowFrames:Int = 0;
    var _recoveryStopped:Bool = false;
    var _recoveryFrames:Int = 0;
    var _framesSinceDone:Int = 0;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('CB_TEST: $name pass=$pass $detail');
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        _status = new FlxText(0, 0, FlxG.width, "CB_TEST running");
        _status.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        _status.y = (FlxG.height / 2) - (_status.height / 2);
        add(_status);

        log("CB_TEST: Starting");

        FmodManager.OnSongEvent(data -> {
            _eventCount++;
            switch (data) {
                case TimelineMarker(name, positionMs):
                    log('CB_TEST: TimelineMarker name=$name position=$positionMs');
                case TimelineBeat(bar, beat, positionMs, tempo):
                    log('CB_TEST: TimelineBeat bar=$bar beat=$beat position=$positionMs tempo=$tempo');
                case NestedTimelineBeat(bar, beat, positionMs, tempo):
                    log('CB_TEST: NestedTimelineBeat bar=$bar beat=$beat position=$positionMs tempo=$tempo');
                case Stopped:
                    log("CB_TEST: Stopped");
                    _stoppedReceived = true;
                case other:
                    log('CB_TEST: $other');
            }
        });
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        switch (_phase) {
            case 0: updateSongFlow();
            case 1: updateOverflowWait();
            case 2: updateRecoveryWait();
            default: updateDone();
        }
    }

    function updateSongFlow():Void {
        // Drain the callback queue - typed callbacks are only delivered
        // from FmodManager.Update(), the same way games consume them
        FmodManager.Update();

        // Let the song play for 3 seconds of audio time, then soft-stop it
        if (!_stopRequested && FmodManager.GetSongTimelinePosition() >= 3000) {
            _stopRequested = true;
            log("CB_TEST: Requesting soft stop");
            FmodManager.StopSong();
        }

        if (_stoppedReceived) {
            log('CB_TEST: Song flow done events=$_eventCount');
            startOverflowPhase();
        }
    }

    function startOverflowPhase():Void {
        // The song instance stays alive in the FmodManager slot and its
        // description handle is deduplicated, so this baseline only moves
        // if the overflow phase leaks instance handles
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        _baseline = StudioSystem.liveHandleCount();

        log('CB_TEST: Overflow phase starting instances=$OVERFLOW_INSTANCES');
        _status.text = "CB_TEST overflow phase";
        for (i in 0...OVERFLOW_INSTANCES) {
            var instance = desc.createInstance();
            var isRecoveryProbe = i == 0;
            instance.setCallback(data -> {
                switch (data) {
                    case Stopped:
                        if (isRecoveryProbe) _recoveryStopped = true;
                    default:
                }
            }, EventCallbackType.PLAYBACK_ALL);
            instance.start();
            _overflowInstances.push(instance);
        }
        _phase = 1;
    }

    function updateOverflowWait():Void {
        // Deliberately NOT calling FmodManager.Update() here: the queue must
        // fill up while nothing drains it. cb_take_overflow consumes the
        // flag (Update would eat it), so latch it before any drain runs.
        _overflowFrames++;
        if (NativeStudio.cb_take_overflow()) _overflowSeen = true;
        if (!_overflowSeen && _overflowFrames <= OVERFLOW_WAIT_FRAMES) return;

        check("queue_overflowed", _overflowSeen, 'frames=$_overflowFrames');

        // Recovery: drain the backlog, then prove delivery still works by
        // soft-stopping one instance and waiting for its Stopped event
        FmodManager.Update();
        log("CB_TEST: Requesting recovery stop");
        _overflowInstances[0].stop(ALLOWFADEOUT);
        _phase = 2;
    }

    function updateRecoveryWait():Void {
        FmodManager.Update();
        _recoveryFrames++;
        if (!_recoveryStopped && _recoveryFrames <= RECOVERY_WAIT_FRAMES) return;

        check("delivery_recovers", _recoveryStopped, 'frames=$_recoveryFrames');

        for (instance in _overflowInstances) {
            instance.stop(IMMEDIATE);
            instance.release();
        }
        _overflowInstances = [];
        check("no_handle_leaks", StudioSystem.liveHandleCount() == _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');

        log('CB_TEST: COMPLETE events=$_eventCount passed=$_passCount failed=$_failCount');
        _status.text = 'CB_TEST complete: $_eventCount events, $_failCount failed';
        _phase = 3;
    }

    function updateDone():Void {
        // Keep draining so released instances finish destroying cleanly
        FmodManager.Update();
        // Give the renderer a few frames, then exit
        _framesSinceDone++;
        if (_framesSinceDone > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
