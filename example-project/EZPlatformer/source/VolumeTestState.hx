package;

import flixel.FlxState;
import fmodtest.VolumeScenario;

/**
 * Runs the shared bus volume and mute scenario (VOLUME_TEST log lines).
 * Select via HAXEFMOD_TEST_STATE=volume (native) or ?test=volume (HTML5).
 */
class VolumeTestState extends FlxState {
    var scenario = new VolumeScenario();

    override public function create():Void {
        super.create();
        scenario.create(new FlxTestHost(this));
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        scenario.update(elapsed);
    }
}
