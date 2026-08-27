package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.DspType;
import haxefmod.studio.Callbacks;
import haxefmod.studio.CoreSound;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test state for the programmer-sound plumbing and the Core API micro
 * subset. Logs one "PS_TEST:" line per check. CI gates on "PS_TEST: COMPLETE"
 * with no "pass=false".
 *
 * The core subset is validated end to end against a real audio file (the CI
 * step copies fmod/Assets/Jump.wav into the game's assets before running).
 * The Dialogue/Speak event carries a real async programmer instrument, so
 * the audio-table phase proves the full CREATE/DESTROY resolution from the
 * "hello" key, with channel-group metering as the evidence the key resolved
 * to audio. The music-event block below keeps the armed-but-never-fired
 * plumbing covered too.
 *
 * Select via HAXEFMOD_TEST_STATE=ps-test (native) or ?test=ps-test (HTML5).
 */
class ProgrammerSoundTestState extends FlxState {
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
        log('PS_TEST: $name pass=$pass $detail');
    }

    function info(name:String, detail:String):Void {
        log('PS_TEST: $name info=$detail');
    }

    override public function create():Void {
        super.create();

        FmodManager.EnableDebugMessages();

        var label = new FlxText(0, 0, FlxG.width, "PS_TEST running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("PS_TEST: Starting");
        var handlesBefore = StudioSystem.liveHandleCount();

        // Core API micro subset against a real file. The html5 build ships
        // FSB-only codecs, so loose files legitimately fail there with
        // FMOD_ERR_FORMAT - informational on js, gating on native.
        var sound = CoreSound.create("assets/fmod/Jump.wav");
        #if js
        info("core_create_sound", sound.isNull()
            ? 'unavailable result=${StudioSystem.lastResult().toString()}'
            : "loaded (unexpected on html5)");
        #else
        check("core_create_sound", !sound.isNull(), 'result=${StudioSystem.lastResult().toString()}');
        if (!sound.isNull()) {
            var lengthMs = sound.getLength();
            // Jump.wav is roughly half a second of PCM
            check("core_get_sound_length", lengthMs > 100 && lengthMs < 2000, 'ms=$lengthMs');
            var releaseResult:FmodResult = sound.release();
            check("core_release_sound", releaseResult.isOk(), 'result=${releaseResult.toString()}');
            check("core_released_invalid", sound.getLength() == -1, "");
        }
        check("core_missing_file", CoreSound.create("assets/fmod/DoesNotExist.wav").isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');
        #end

        // Programmer-sound assignment plumbing on a real instance. The
        // music event has no programmer instrument, so the callback never
        // triggers here. This proves assignment, playback with the callback
        // armed, and cleanup are all safe.
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        // Leak baseline after the lookup (descriptions cache a persistent
        // deduped handle) and before the instance, which is released below
        var baseline = StudioSystem.liveHandleCount();
        var instance:EventInstance = desc.createInstance();
        check("create_instance", !instance.isNull(), "");
        var assignResult = instance.assignProgrammerSound("assets/fmod/Jump.wav");
        check("ps_assign", assignResult.isOk(), 'result=${assignResult.toString()}');
        check("evi_start_with_ps_armed", instance.start().isOk(), "");
        check("evi_stop_with_ps_armed", instance.stop(IMMEDIATE).isOk(), "");
        var clearResult = instance.clearProgrammerSound();
        check("ps_clear", clearResult.isOk(), 'result=${clearResult.toString()}');
        check("evi_release", instance.release().isOk(), "");

        info("live_handle_delta", Std.string(StudioSystem.liveHandleCount() - handlesBefore));
        check("no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

        _label = label;
        startAudioTable();
    }

    var _label:FlxText;
    var _phase:String = "";
    var _atInstance:EventInstance = EventInstance.NULL;
    var _atGroup:ChannelGroup = ChannelGroup.NULL;
    var _atMeter:Dsp = Dsp.NULL;
    var _atBaseline:Int = 0;
    var _atFrames:Int = 0;
    var _atCreates:Int = 0;
    var _atDestroys:Int = 0;
    var _atStopped:Bool = false;
    var _atMaxPeak:Float = 0;
    var _bogusInstance:EventInstance = EventInstance.NULL;

    /**
     * The audio-table key route: Speak's async programmer instrument
     * resolves the "hello" key through the Master bank's audio table. The
     * create callback fires whether or not the key resolves, so metering
     * on the instance's channel group is the proof it resolved to real
     * audio. Async: the event plays its region out (about six seconds).
     */
    function startAudioTable():Void {
        // The description lookup mints a persistent dedup handle: warm it
        // before the baseline
        var desc = StudioSystem.getEvent(FmodEvents.DialogueSpeak);
        _atBaseline = StudioSystem.liveHandleCount();
        check("at_event_lookup", !desc.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        if (desc.isNull()) {
            finishState();
            return;
        }
        _atInstance = desc.createInstance();
        check("at_create_instance", !_atInstance.isNull(), "");
        _atInstance.setCallback(data -> {
            switch (data) {
                case Stopped: _atStopped = true;
                case Other(t):
                    if (t == EventCallbackType.CREATE_PROGRAMMER_SOUND) _atCreates++;
                    if (t == EventCallbackType.DESTROY_PROGRAMMER_SOUND) _atDestroys++;
                default:
            }
        }, EventCallbackType.STOPPED | EventCallbackType.CREATE_PROGRAMMER_SOUND
            | EventCallbackType.DESTROY_PROGRAMMER_SOUND);
        check("at_assign_key", _atInstance.assignProgrammerSound("hello").isOk(), "");
        check("at_start", _atInstance.start().isOk(), "");
        StudioSystem.flushCommands();
        _atGroup = _atInstance.getChannelGroup();
        check("at_channel_group", !_atGroup.isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        _atMeter = Dsp.create(DspType.FFT);
        if (!_atGroup.isNull()) {
            _atGroup.addDsp(0, _atMeter);
            // getMetering reads the output meter, so output metering must
            // be on (the FFT passes audio through unchanged)
            _atMeter.setMeteringEnabled(true, true);
        }
        _atFrames = 0;
        _phase = "at-play";
    }

    function finishAudioTable():Void {
        check("at_stopped_naturally", _atStopped, 'frames=$_atFrames');
        check("at_create_callback_delivered", _atCreates > 0, 'count=$_atCreates');
        check("at_destroy_callback_delivered", _atDestroys > 0, 'count=$_atDestroys');
        check("at_key_resolved_audibly", _atMaxPeak > 0.01, 'peak=$_atMaxPeak');
        _atGroup.removeDsp(_atMeter);
        _atMeter.release();
        _atInstance.release();
        var desc = StudioSystem.getEvent(FmodEvents.DialogueSpeak);
        desc.releaseAllInstances();
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_at_leaks", StudioSystem.liveHandleCount() == _atBaseline,
            'baseline=$_atBaseline now=${StudioSystem.liveHandleCount()}');

        // A well-formed key that matches nothing: the instrument stays
        // silent and the event still plays its region out without wedging
        _bogusInstance = desc.createInstance();
        check("at_bogus_assign", _bogusInstance.assignProgrammerSound("no_such_key").isOk(), "");
        check("at_bogus_start", _bogusInstance.start().isOk(), "");
        _atFrames = 0;
        _phase = "at-bogus";
    }

    function finishBogus(stopped:Bool):Void {
        check("at_bogus_plays_out", stopped, 'frames=$_atFrames');
        _bogusInstance.release();
        var desc = StudioSystem.getEvent(FmodEvents.DialogueSpeak);
        desc.releaseAllInstances();
        StudioSystem.flushCommands();
        FmodManager.Update();
        check("no_bogus_leaks", StudioSystem.liveHandleCount() == _atBaseline,
            'baseline=$_atBaseline now=${StudioSystem.liveHandleCount()}');
        finishState();
    }

    function finishState():Void {
        log('PS_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        _label.text = 'PS_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
        _phase = "";
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (_phase == "at-play") {
            _atFrames++;
            var metering = _atMeter.getMetering();
            if (metering != null) {
                for (p in metering.peak) if (p > _atMaxPeak) _atMaxPeak = p;
            }
            // The destroy event can trail the stop by a drain or two, so
            // wait for both before finishing
            if ((_atStopped && _atDestroys > 0) || _atFrames > 600) {
                finishAudioTable();
            }
            return;
        }
        if (_phase == "at-bogus") {
            _atFrames++;
            var stopped = _bogusInstance.getPlaybackState() == FmodPlaybackState.STOPPED;
            if (stopped || _atFrames > 600) {
                finishBogus(stopped);
            }
            return;
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
