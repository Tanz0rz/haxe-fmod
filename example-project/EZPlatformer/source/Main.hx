package;

import flixel.FlxGame;
import openfl.display.Sprite;
import other.Version;

class Main extends Sprite {
    public function new() {
        super();
        addChild(new FlxGame(320, 240, LoadFmodState));
    }
}
