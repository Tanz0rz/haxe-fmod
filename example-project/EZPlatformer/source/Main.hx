package;

import flixel.FlxGame;
import flixel.FlxState;
import openfl.display.Sprite;

class Main extends Sprite {
    public function new() {
        super();
        // TestPreloader has FMOD and the default banks ready before the
        // first state, so it starts the game directly
        addChild(new FlxGame(320, 240, firstState(), 60, 60, true));
        #if audio_test
        // Flixel pauses the game when the window loses focus. A test
        // state counts frames, so a focus change would stall it.
        flixel.FlxG.autoPause = false;
        #end
    }

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
