package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.core.ChannelGroup;
import haxefmod.core.Dsp;
import haxefmod.core.SoundGroup;
import haxefmod.core.DspType;
import haxefmod.core.PcmStream;
import haxefmod.core.Reverb;
import haxefmod.core.Reverb3D;
import haxefmod.core.Sound;
import haxefmod.studio.Callbacks;
import haxefmod.studio.EventInstance;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * Long-running CI stress state for the handle table and the callback
 * dispatcher. Logs one "STRESS_TEST:" line per check. CI gates on
 * "STRESS_TEST: COMPLETE" with no "pass=false".
 *
 * Wide phase: 80 simultaneous instances prove the handle table grows past
 * its initial 64 slots and that releasing them all returns the live count
 * to baseline.
 *
 * Churn phase: for the configured duration, every frame creates, starts,
 * immediately stops, and releases a small batch of instances - registering
 * a callback on one instance per batch to churn the dispatcher map under
 * sustained mutation - plus rotating lifecycle churn: PcmStream cycles
 * (with a DSP attached and detached mid-cycle), then DSP graph and reverb
 * zone cycles, then sound group, nested group, and channel callback
 * cycles, so every slot type recycles under the same pressure. The
 * families rotate across frames. Reverb zones churn the realistic way
 * (a persistent zone with property and active churn, no lifecycle
 * cycling) because zone create/release concurrent with stream
 * lifecycles crashes inside FMOD
 * itself (pure C repro in tests/native/fmod_churn_crash_repro.c). Every
 * heartbeat asserts the live handle count stays flat.
 *
 * Duration comes from the STRESS_SECONDS env var (default 60 seconds;
 * HTML5 always uses the default). Select via
 * HAXEFMOD_TEST_STATE=stress-test (native) or ?test=stress-test (HTML5).
 */
class StressTestState extends FlxState {
    static inline var WIDE_INSTANCES:Int = 80;
    // 3 cycles per frame keeps per-frame work bounded (~180 cycles/second
    // at 60fps) so the frame loop never stalls behind FMOD's async teardown
    static inline var CHURN_BATCH:Int = 3;
    static inline var HEARTBEAT_SECONDS:Float = 5.0;
    static inline var DEFAULT_SECONDS:Int = 60;

    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    var _durationSeconds:Float = DEFAULT_SECONDS;
    var _baseline:Int = 0;
    var _widePhaseRun:Bool = false;
    var _churnElapsed:Float = 0;
    var _nextHeartbeat:Float = HEARTBEAT_SECONDS;
    var _heartbeats:Int = 0;
    var _iterations:Int = 0;
    var _churnFrame:Int = 0;
    var _persistentZone:Reverb3D = Reverb3D.NULL;
    var _pcmCycles:Int = 0;
    var _dspCycles:Int = 0;
    var _graphCycles:Int = 0;
    var _pcmChunk:haxe.io.Bytes;
    var _callbackEvents:Int = 0;
    var _status:FlxText;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('STRESS_TEST: $name pass=$pass $detail');
    }

    function info(name:String, detail:String):Void {
        log('STRESS_TEST: $name info=$detail');
    }

    override public function create():Void {
        super.create();

        _status = new FlxText(0, 0, FlxG.width, "STRESS_TEST running");
        _status.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        _status.y = (FlxG.height / 2) - (_status.height / 2);
        add(_status);

        log("STRESS_TEST: Starting");

        #if sys
        var configured = Sys.getEnv("STRESS_SECONDS");
        if (configured != null) {
            var parsed = Std.parseInt(configured);
            if (parsed != null && parsed > 0) _durationSeconds = parsed;
        }
        #end
        info("duration_seconds", Std.string(_durationSeconds));

        // Warm the event description cache (the lookup allocates one
        // persistent deduped handle) and create the persistent reverb zone
        // so the baseline only moves if a phase below leaks handles
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        _persistentZone = Reverb3D.create();
        _baseline = StudioSystem.liveHandleCount();
        info("baseline_handles", Std.string(_baseline));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);

        if (_done) {
            // Keep draining so released instances finish destroying
            FmodManager.Update();
            _framesWaited++;
            if (_framesWaited > 30) {
                #if sys
                Sys.exit(_failCount > 0 ? 1 : 0);
                #end
            }
            return;
        }

        if (!_widePhaseRun) {
            _widePhaseRun = true;
            runWidePhase();
            return;
        }

        runChurnFrame(elapsed);
    }

    /** Wide phase: many simultaneous instances, then a full release. */
    function runWidePhase():Void {
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);

        var instances:Array<EventInstance> = [];
        var validCount = 0;
        for (i in 0...WIDE_INSTANCES) {
            var instance = desc.createInstance();
            instance.start();
            if (instance.isValid()) validCount++;
            instances.push(instance);
        }
        check("wide_all_valid", validCount == WIDE_INSTANCES,
            'valid=$validCount of $WIDE_INSTANCES');
        // The baseline plus 80 live instances proves the table grew past
        // its initial 64 slots
        info("wide_live_handles", Std.string(StudioSystem.liveHandleCount()));
        check("wide_handle_count", StudioSystem.liveHandleCount() == _baseline + WIDE_INSTANCES,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');

        FmodManager.Update();
        for (instance in instances) {
            instance.stop(IMMEDIATE);
            instance.release();
        }
        check("wide_release_returns_to_baseline", StudioSystem.liveHandleCount() == _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');

        log("STRESS_TEST: Churn phase starting");
        _status.text = "STRESS_TEST churn phase";
    }

    /** Churn phase: full create/start/stop/release cycles every frame. */
    function runChurnFrame(elapsed:Float):Void {
        var desc = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        for (i in 0...CHURN_BATCH) {
            var instance = desc.createInstance();
            if (i == 0) {
                // Registration churn: setCallback installs a dispatcher map
                // entry every batch and release() removes it again
                instance.setCallback(function(data) {
                    _callbackEvents++;
                }, EventCallbackType.ALL);
            }
            instance.start();
            instance.stop(IMMEDIATE);
            instance.release();
            _iterations++;
        }

        // Core churn: one full PcmStream lifecycle per frame proves the PCM
        // and channel slots recycle cleanly under sustained mutation
        if (_pcmChunk == null) {
            _pcmChunk = haxe.io.Bytes.alloc(2400);
            for (i in 0...1200) {
                var v = Std.int(Math.sin(2 * Math.PI * 440 * i / 48000) * 0x3000);
                _pcmChunk.setUInt16(i * 2, v & 0xFFFF);
            }
        }
        // The lifecycle families rotate across frames: same-frame stream
        // and reverb zone churn trips a crash inside FMOD itself (pure C
        // repro in tests/native/fmod_churn_crash_repro.c)
        _churnFrame++;
        var family = _churnFrame % 3;

        if (family == 0) {
            var stream = PcmStream.create(48000, 1, 4800);
            if (!stream.isNull()) {
                stream.write(_pcmChunk);
                var channel = stream.play(true);
                var lowpass = Dsp.create(DspType.LOWPASS_SIMPLE);
                if (!lowpass.isNull()) {
                    channel.addDsp(0, lowpass);
                    channel.removeDsp(lowpass);
                    lowpass.release();
                    _dspCycles++;
                }
                channel.stop();
                stream.release();
                _pcmCycles++;
            }
        }

        if (family == 1) {
            // Graph churn plus realistic zone churn: a persistent zone
            // takes property and active updates every pass
            var osc = Dsp.create(DspType.OSCILLATOR);
            var target = Dsp.create(DspType.LOWPASS_SIMPLE);
            if (!osc.isNull() && !target.isNull()) {
                var conn = target.addInput(osc);
                if (!conn.isNull()) {
                    conn.setMix(0.5);
                    target.disconnectFrom(osc);
                }
                if (_persistentZone.isNull()) _persistentZone = Reverb3D.create();
                if (!_persistentZone.isNull()) {
                    _persistentZone.set3DAttributes(_churnFrame % 100, 0, 0, 5, 20);
                    _persistentZone.setProperties(Reverb.PRESET_CAVE);
                    _persistentZone.setActive(_churnFrame % 2 == 0);
                }
                _graphCycles++;
            }
            target.release();
            osc.release();
        }

        if (family == 2) {
            // Group and callback churn: sound group with assignment,
            // nested channel groups, and a channel callback registered
            // and cleared on a live stream channel
            var parent = ChannelGroup.create("churn-parent");
            var child = ChannelGroup.create("churn-child");
            if (!parent.isNull() && !child.isNull()) {
                parent.addGroup(child);
                child.release();
                parent.release();
            }
            var soundGroup = SoundGroup.create("churn-sg");
            var pcmSound = Sound.fromPcm(_pcmChunk, 48000, 1);
            if (!soundGroup.isNull() && !pcmSound.isNull()) {
                soundGroup.setMaxAudible(1);
                pcmSound.setSoundGroup(soundGroup);
                // Releasing the sound leaves the group, so no reassignment
                // to the master group (whose cached lookup handle would
                // move the flat-count baseline)
                pcmSound.release();
                soundGroup.release();
            }
            var cbStream = PcmStream.create(48000, 1, 4800);
            if (!cbStream.isNull()) {
                var cbChannel = cbStream.play(true);
                cbChannel.setCallback(function(e) _callbackEvents++);
                cbChannel.clearCallback();
                cbChannel.stop();
                cbStream.release();
            }
        }
        FmodManager.Update();

        _churnElapsed += elapsed;
        if (_churnElapsed >= _nextHeartbeat) {
            _nextHeartbeat += HEARTBEAT_SECONDS;
            _heartbeats++;
            var live = StudioSystem.liveHandleCount();
            check("handle_count_flat", live == _baseline,
                'heartbeat=$_heartbeats baseline=$_baseline now=$live iterations=$_iterations');
            log('STRESS_TEST: Heartbeat $_heartbeats elapsed=${Math.round(_churnElapsed)}s iterations=$_iterations callbacks=$_callbackEvents live=$live');
        }

        if (_churnElapsed >= _durationSeconds) finish();
    }

    function finish():Void {
        check("no_handle_leaks", StudioSystem.liveHandleCount() == _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');
        info("callback_events", Std.string(_callbackEvents));
        if (!_persistentZone.isNull()) {
            _persistentZone.release();
            _persistentZone = Reverb3D.NULL;
        }
        info("pcm_cycles", Std.string(_pcmCycles));
        info("dsp_cycles", Std.string(_dspCycles));
        info("graph_cycles", Std.string(_graphCycles));
        log('STRESS_TEST: COMPLETE passed=$_passCount failed=$_failCount iterations=$_iterations');
        _status.text = 'STRESS_TEST complete: $_passCount passed, $_failCount failed, $_iterations cycles';
        _done = true;
    }
}
