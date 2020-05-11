package faxe.flixel;

import flixel.FlxBasic;
import flixel.FlxG;

/**
    Add this to every state's create() method using init()

    It will automatically call FmodManager.Update() in the background
**/
class FmodUpdater extends FlxBasic {
    public static function init() {
        FlxG.plugins.add(new FmodUpdater());
    }

    override public function update(elapsed:Float):Void {
        FmodManager.Update();
    }
}
