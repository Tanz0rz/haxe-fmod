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
        Main.instance.switchScene(new TestScene(TestConfig.testState()));
        #else
        Main.instance.switchScene(new PlayScene());
        #end
    }

    public function render(g2:Graphics):Void {
        // A loading bar stands in for text: Kha ships no default font
        g2.color = 0xffffffff;
        g2.fillRect(120, 118, 80, 4);
    }

    public function dispose():Void {}
}
