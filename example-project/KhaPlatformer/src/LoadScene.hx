package;

import kha.graphics2.Graphics;

/**
 * Waits for FMOD to finish initializing (the browser does it
 * asynchronously), then starts the game or the selected test scenario.
 */
class LoadScene implements GameScene {
    public function new() {}

    public function create():Void {}

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

    public function render(g2:Graphics):Void {
        // A loading bar stands in for text: Kha ships no default font
        g2.color = 0xffffffff;
        g2.fillRect(120, 118, 80, 4);
    }

    public function dispose():Void {}
}
