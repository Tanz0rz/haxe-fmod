package fmodtest;

import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;
import haxefmod.studio.native.NativeStudio;

/**
 * CI test scenario for payload-carrying callbacks.
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
 * Nested flow: plays the Nested event, whose event instrument references
 * the music event, and gates on NestedTimelineBeat payloads arriving from
 * the referenced timeline.
 *
 * CI gates on "CB_TEST: Stopped" and "CB_TEST: COMPLETE" with no
 * "pass=false".
 *
 * Select via HAXEFMOD_TEST_STATE=cb-test (native) or ?test=cb-test (HTML5).
 */
class CallbackScenario implements TestScenario {
    var host:TestHost;

    public function new() {}

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
    var _beatSeen:Bool = false;
    var _beatTimeSigOk:Bool = false;
    var _markerSeen:Bool = false;
    var _markerPosition:Int = -1;
    var _failCount:Int = 0;
    var _passCount:Int = 0;

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

    public function create(host:TestHost):Void {
        this.host = host;

        FmodManager.EnableDebugMessages();
        FmodManager.PlaySong(FmodEvents.MusicMainLevel);

        host.setStatus("CB_TEST running");

        log("CB_TEST: Starting");

        FmodManager.OnSongEvent(data -> {
            _eventCount++;
            switch (data) {
                case TimelineMarker(marker):
                    log('CB_TEST: TimelineMarker name=${marker.name} position=${marker.position}');
                    if (marker.name == "ProbeMarker") {
                        _markerSeen = true;
                        _markerPosition = marker.position;
                    }
                case TimelineBeat(beat):
                    log('CB_TEST: TimelineBeat bar=${beat.bar} beat=${beat.beat} position=${beat.position} tempo=${beat.tempo} timeSig=${beat.timeSignatureUpper}/${beat.timeSignatureLower}');
                    _beatSeen = true;
                    if (beat.timeSignatureUpper > 0 && beat.timeSignatureLower > 0) _beatTimeSigOk = true;
                case NestedTimelineBeat(nested):
                    var beat = nested.properties;
                    log('CB_TEST: NestedTimelineBeat bar=${beat.bar} beat=${beat.beat} position=${beat.position} tempo=${beat.tempo} timeSig=${beat.timeSignatureUpper}/${beat.timeSignatureLower} eventId=${nested.eventId}');
                case Stopped:
                    log("CB_TEST: Stopped");
                    _stoppedReceived = true;
                case unhandled:
                    log('CB_TEST: $unhandled');
            }
        });
    }

    public function update(elapsed:Float):Void {

        switch (_phase) {
            case 0: updateSongFlow();
            case 4: updateNestedWait();
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
            // The song has a tempo track, so beats must arrive and every
            // beat must carry the authored time signature
            check("beat_time_signature", _beatSeen && _beatTimeSigOk,
                'seen=$_beatSeen sigOk=$_beatTimeSigOk');
            // The song passes its ProbeMarker before the 3-second stop
            check("marker_delivered", _markerSeen && _markerPosition > 0,
                'seen=$_markerSeen position=$_markerPosition');
            log('CB_TEST: Song flow done events=$_eventCount');
            startNestedPhase();
        }
    }

    var _nestedInstance:EventInstance = EventInstance.NULL;
    var _nestedBeats:Int = 0;
    var _nestedTempoOk:Bool = false;
    var _nestedEventId:String = "";
    var _nestedParentId:String = "";
    var _nestedFrames:Int = 0;
    var _nestedBaseline:Int = 0;

    // The Nested event's instrument references the music event, so its
    // tempo arrives through the nested beat payload on the parent instance
    function startNestedPhase():Void {
        host.setStatus("CB_TEST nested phase");
        var desc = StudioSystem.getEvent(FmodEvents.MusicNested);
        _nestedBaseline = StudioSystem.liveHandleCount();
        check("nested_event_lookup", !desc.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        _nestedParentId = desc.getID();
        _nestedInstance = desc.createInstance();
        // The full mask, with every delivery logged: which type the
        // parent's referenced-event beats arrive under is itself under
        // test (a browser glue can misroute them)
        _nestedInstance.setCallback(data -> {
            switch (data) {
                case NestedTimelineBeat(nested):
                    var beat = nested.properties;
                    log('CB_TEST: nested-phase NestedTimelineBeat bar=${beat.bar} beat=${beat.beat} position=${beat.position} tempo=${beat.tempo} timeSig=${beat.timeSignatureUpper}/${beat.timeSignatureLower} eventId=${nested.eventId}');
                    _nestedBeats++;
                    if (beat.tempo > 0 && beat.timeSignatureUpper > 0 && beat.timeSignatureLower > 0) _nestedTempoOk = true;
                    _nestedEventId = nested.eventId;
                case other:
                    log('CB_TEST: nested-phase $other');
            }
        }, EventCallbackType.ALL);
        _nestedInstance.start();
        _phase = 4;
    }

    function updateNestedWait():Void {
        FmodManager.Update();
        _nestedFrames++;
        if (_nestedBeats < 2 && _nestedFrames <= RECOVERY_WAIT_FRAMES) return;

        var firefoxGlue = false;
        #if js
        firefoxGlue = js.Browser.navigator.userAgent.indexOf("Firefox") >= 0;
        #end
        if (firefoxGlue) {
            // FMOD's JS runtime never invokes the nested-beat callback on
            // Firefox. The parent still receives the referenced timeline's
            // markers, and chromium delivers the beats, so the gating
            // check lives on the other targets.
            log('CB_TEST: nested_beats_delivered info=not delivered by the firefox glue'
                + ' beats=$_nestedBeats frames=$_nestedFrames');
        } else {
            check("nested_beats_delivered", _nestedBeats >= 2 && _nestedTempoOk,
                'beats=$_nestedBeats tempoOk=$_nestedTempoOk frames=$_nestedFrames');
        }
        _nestedInstance.stop(IMMEDIATE);
        _nestedInstance.release();
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_nested_leaks", StudioSystem.liveHandleCount() == _nestedBaseline,
            'baseline=$_nestedBaseline now=${StudioSystem.liveHandleCount()}');
        // The payload carries the GUID FMOD reports for the referenced
        // timeline. FMOD 2.03.12 hands over the timeline object's own id,
        // which no lookup resolves, so a well-formed non-zero GUID that is
        // not the parent's is the proof it arrived intact
        var zeroGuid = "{00000000-0000-0000-0000-000000000000}";
        #if js
        // The web glue hands the beat fields over flat and drops the GUID
        log('CB_TEST: nested_beat_event_id info=eventId=$_nestedEventId');
        #else
        check("nested_beat_event_id", _nestedEventId.length == 38 && _nestedEventId != zeroGuid
            && _nestedEventId != _nestedParentId,
            'eventId=$_nestedEventId');
        #end
        startOverflowPhase();
    }

    function startOverflowPhase():Void {
        // The song instance stays alive in the FmodManager slot and its
        // description handle is deduplicated, so this baseline only moves
        // if the overflow phase leaks instance handles
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        _baseline = StudioSystem.liveHandleCount();

        log('CB_TEST: Overflow phase starting instances=$OVERFLOW_INSTANCES');
        host.setStatus("CB_TEST overflow phase");
        for (i in 0...OVERFLOW_INSTANCES) {
            var instance = desc.createInstance();
            var isRecoveryProbe = i == 0;
            instance.setCallback(data -> {
                switch (data) {
                    case Stopped:
                        if (isRecoveryProbe) _recoveryStopped = true;
                    default:
                }
            }, EventCallbackType.ALL);
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
        host.setStatus('CB_TEST complete: $_eventCount events, $_failCount failed');
        _phase = 3;
    }

    function updateDone():Void {
        // Keep draining so released instances finish destroying
        FmodManager.Update();
        // Give the renderer a few frames, then exit
        _framesSinceDone++;
        if (_framesSinceDone > 30) {
            host.exit(_failCount > 0 ? 1 : 0);
        }
    }
}
