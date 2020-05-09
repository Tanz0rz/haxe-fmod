package faxe;

import flixel.FlxBasic;
import flixel.FlxG;

/**
    Add this to every state's create() method using init()

    It will automatically call FaxeSoundHelper.Update() in the background
**/
class FaxeFlxUpdater extends FlxBasic {
    public static function init() {
        FlxG.plugins.add(new FaxeFlxUpdater());
    }

    override public function update(elapsed:Float):Void {
        FaxeSoundHelper.Update();
    }
}
