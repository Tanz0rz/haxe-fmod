package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;

/**
    Call init() once at startup (FmodFlxSetup.init() does this for you)

    It registers a global FlxG plugin that calls FmodManager.Update()
    every frame across all states
**/
class FmodFlxUpdater extends FlxBasic {
    static var added:Bool = false;

    public static function init() {
        if (added) return;
        added = true;
        FlxG.plugins.add(new FmodFlxUpdater());
    }

    override public function update(elapsed:Float):Void {
        FmodManager.Update();
    }
}
