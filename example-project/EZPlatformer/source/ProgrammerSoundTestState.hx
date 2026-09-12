package;

import flixel.FlxState;
import fmodtest.ProgrammerSoundScenario;

/**
 * Runs the shared programmer sound scenario (PS_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=ps-test (native) or ?test=ps-test (HTML5).
 */
class ProgrammerSoundTestState extends FlxState {
    var scenario = new ProgrammerSoundScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
