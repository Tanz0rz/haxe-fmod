package;

import flixel.FlxState;
import fmodtest.CallbackScenario;

/**
 * Runs the shared payload callback scenario (CB_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=cb-test (native) or ?test=cb-test (HTML5).
 */
class BeatTestState extends FlxState {
    var scenario = new CallbackScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
