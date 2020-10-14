package;

import flixel.FlxGame;
import openfl.display.Sprite;
import other.Version;

class Main extends Sprite {
    public function new() {
        super();
        trace(Version.getGitCommitHash());
        addChild(new FlxGame(320, 240, LoadFmodState));
    }
}
