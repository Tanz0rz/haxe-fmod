package;

import kha.graphics2.Graphics;
import fmodtest.ApiProbeScenario;
import fmodtest.BankLifecycleScenario;
import fmodtest.CallbackScenario;
import fmodtest.ProgrammerSoundScenario;
import fmodtest.StressScenario;
import fmodtest.SynthScenario;
import fmodtest.TestScenario;
import fmodtest.VolumeScenario;

/**
 * Hosts one shared test scenario (the same classes the flixel and Heaps
 * examples run) on top of Kha. Selected by name, see TestConfig.
 */
class TestScene implements GameScene {
    var scenario:TestScenario;
    var host:KhaTestHost;

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

    public function create():Void {
        host = new KhaTestHost();
        scenario.create(host);
    }

    public function update(dt:Float):Void {
        scenario.update(dt);
    }

    public function render(g2:Graphics):Void {
        host.render(g2);
    }

    public function dispose():Void {}
}
