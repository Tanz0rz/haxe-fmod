package;

import flixel.FlxState;
import fmodtest.StressScenario;

/**
 * Runs the shared handle churn scenario (STRESS_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=stress-test (native) or ?test=stress-test (HTML5).
 */
class StressTestState extends FlxState {
    var scenario = new StressScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
