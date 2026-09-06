package;

import h2d.Object;
import h2d.Scene;
import h2d.Text;

/**
 * Waits for FMOD to finish initializing (the browser does it
 * asynchronously), then starts the game or the selected test scenario.
 */
class LoadScene implements GameScene {
    var root:Object;

    public function new() {}

    public function create(s2d:Scene):Void {
        root = new Object(s2d);
        var text = new Text(hxd.res.DefaultFont.get(), root);
        text.text = "Loading...";
        text.textAlign = Center;
        text.maxWidth = 320;
        text.x = 160;
        text.y = 120 - 6;
    }

    public function update(dt:Float):Void {
        if (!FmodManager.IsInitialized()) return;
        #if audio_test
        // A test build with no state requested is the plain game, so CI
        // builds one variant for every leg
        var state = TestConfig.requestedState();
        if (state != null) {
            Main.instance.switchScene(new TestScene(state));
            return;
        }
        #end
        Main.instance.switchScene(new PlayScene());
    }

    public function dispose():Void {
        root.remove();
    }
}
