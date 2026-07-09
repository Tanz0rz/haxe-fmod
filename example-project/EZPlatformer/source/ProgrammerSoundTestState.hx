package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.studio.CoreSound;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;

/**
 * CI test state for the programmer-sound plumbing and the Core API micro
 * subset. Logs one "PS_TEST:" line per check; CI gates on "PS_TEST: COMPLETE"
 * with no "pass=false".
 *
 * The core subset is validated end to end against a real audio file (the CI
 * step copies fmod/Assets/Jump.wav into the game's assets before running).
 * The programmer-sound CREATE/DESTROY resolution can only fire once the FMOD
 * project contains a programmer instrument, so this state validates the
 * assignment plumbing (mask install, start/stop with the callback armed,
 * clear) and that nothing crashes with the machinery in place.
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
        // example bank has no programmer instrument, so the callback never
        // triggers; this proves assignment, playback with the callback
        // armed, and cleanup are all safe.
        var desc = StudioSystem.getEvent(FmodSongs.MainLevel);
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

        log('PS_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'PS_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
