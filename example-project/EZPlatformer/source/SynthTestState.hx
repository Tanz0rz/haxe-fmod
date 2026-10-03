package;

import flixel.FlxState;
import fmodtest.SynthScenario;

/**
 * Runs the shared generated PCM scenario (SYNTH_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=synth-test (native) or ?test=synth-test (HTML5).
 */
class SynthTestState extends FlxState {
    var scenario = new SynthScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
