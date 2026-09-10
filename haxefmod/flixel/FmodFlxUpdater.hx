package haxefmod.flixel;

import flixel.FlxBasic;
import flixel.FlxG;

/**
    Per-frame driver for FMOD in a HaxeFlixel game. Call init() once at
    startup (FmodFlxSetup.init() does this for you).

    init() registers a global FlxG plugin that calls FmodManager.Update()
    every frame across all states.
**/
class FmodFlxUpdater extends FlxBasic {
    /** Registers the plugin once. Safe to call again after a recreated FlxGame. **/
    public static function init() {
        // Membership check instead of a static guard, so a destroyed and
        // recreated FlxGame (fresh plugin list) gets the updater back
        if (FlxG.plugins.get(FmodFlxUpdater) != null) return;
        FlxG.plugins.add(new FmodFlxUpdater());
    }

    /** Calls FmodManager.Update() once per frame. **/
    override public function update(elapsed:Float):Void {
        FmodManager.Update();
    }
}
