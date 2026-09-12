package;

import flixel.FlxGame;
import flixel.FlxState;
import openfl.display.Sprite;

class Main extends Sprite {
    public function new() {
        super();
        #if (audio_test && sys)
        mirrorTraceToFile();
        #end
        // TestPreloader has FMOD and the default banks ready before the
        // first state, so it starts the game directly
        addChild(new FlxGame(320, 240, firstState(), 60, 60, true));
        #if audio_test
        // Flixel pauses the game when the window loses focus. A test
        // state counts frames, so a focus change would stall it.
        flixel.FlxG.autoPause = false;
        #end
    }

    #if (audio_test && sys)
    /**
     * CI on Windows builds GUI executables whose stdout goes nowhere, so
     * every trace also lands in the file HAXEFMOD_LOG_FILE names.
     */
    static function mirrorTraceToFile():Void {
        var path = Sys.getEnv("HAXEFMOD_LOG_FILE");
        if (path == null || path == "") return;
        var original = haxe.Log.trace;
        haxe.Log.trace = function(v:Dynamic, ?pos:haxe.PosInfos) {
            original(v, pos);
            try {
                var out = sys.io.File.append(path, false);
                out.writeString(haxe.Log.formatOutput(v, pos) + "\n");
                out.close();
            } catch (e:Dynamic) {}
        };
    }
    #end

    static function firstState():Class<FlxState> {
        #if audio_test
        // A test build with no state requested is the plain game, so CI
        // builds one variant for every leg
        return switch (TestConfig.requestedState()) {
            case null: PlayState;
            case "api-probe": ApiProbeState;
            case "cb-test": BeatTestState;
            case "ps-test": ProgrammerSoundTestState;
            case "bank-test": BankLifecycleTestState;
            case "pan-test": EmitterPanTestState;
            case "stress-test": StressTestState;
            case "synth-test": SynthTestState;
            default: VolumeTestState;
        }
        #else
        return PlayState;
        #end
    }
}
