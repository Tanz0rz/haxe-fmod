package;

import flixel.FlxState;
import fmodtest.BankLifecycleScenario;

/**
 * Runs the shared bank lifecycle scenario (BANK_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=bank-test (native) or ?test=bank-test (HTML5).
 */
class BankLifecycleTestState extends FlxState {
    var scenario = new BankLifecycleScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
