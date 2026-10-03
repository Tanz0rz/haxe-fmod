package;

import h2d.Object;
import h2d.Scene;
import fmodtest.ApiProbeScenario;
import fmodtest.BankLifecycleScenario;
import fmodtest.CallbackScenario;
import fmodtest.ProgrammerSoundScenario;
import fmodtest.StressScenario;
import fmodtest.SynthScenario;
import fmodtest.TestScenario;
import fmodtest.VolumeScenario;

/**
 * Hosts one shared test scenario (the same classes the flixel example
 * runs) on top of the Heaps engine. Selected by name, see TestConfig.
 */
class TestScene implements GameScene {
    var root:Object;
    var scenario:TestScenario;
    var host:HeapsTestHost;

    public function new(name:String) {
        scenario = switch (name) {
            case "api-probe": new ApiProbeScenario();
            case "cb-test": new CallbackScenario();
            case "ps-test": new ProgrammerSoundScenario();
            case "bank-test": new BankLifecycleScenario();
            case "stress-test": new StressScenario();
            case "synth-test": new SynthScenario();
            case "pan-test": new PanTestScenario();
            default: new VolumeScenario();
        };
    }

    public function create(s2d:Scene):Void {
        root = new Object(s2d);
        host = new HeapsTestHost(root);
        scenario.create(host);
    }

    public function update(dt:Float):Void {
        scenario.update(dt);
    }

    public function dispose():Void {
        root.remove();
    }
}
