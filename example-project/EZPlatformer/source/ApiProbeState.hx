package;

import flixel.FlxState;
import fmodtest.ApiProbeScenario;

/**
 * Runs the shared API probe (API_PROBE log lines).
 * Select via HAXEFMOD_TEST_STATE=api-probe (native) or ?test=api-probe (HTML5).
 */
class ApiProbeState extends FlxState {
    var scenario = new ApiProbeScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
