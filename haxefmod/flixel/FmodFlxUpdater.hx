package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;

/**
    Call init() once at startup (FmodFlxSetup.init() does this for you)

    It registers a global FlxG plugin that calls FmodManager.Update()
    every frame across all states
**/
class FmodFlxUpdater extends FlxBasic {
    public static function init() {
        // Membership check instead of a static guard, so a destroyed and
        // recreated FlxGame (fresh plugin list) gets the updater back
        if (FlxG.plugins.get(FmodFlxUpdater) != null) return;
        FlxG.plugins.add(new FmodFlxUpdater());
    }

    override public function update(elapsed:Float):Void {
        FmodManager.Update();
    }
}
