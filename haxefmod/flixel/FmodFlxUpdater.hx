package haxefmod.flixel;

import flixel.FlxG;

/**
    Per-frame driver for FMOD in a HaxeFlixel game. Call init() once at
    startup. FmodFlxSetup.init() and every haxefmod.flixel component do
    this for you.

    init() hooks FlxG.signals.postUpdate, which fires after the state and
    its members have updated. The emitter and listener positions of this
    frame reach FMOD in the same frame. A plugin runs before the state,
    so it pushes the positions of the frame before.
**/
class FmodFlxUpdater {
    static var handler:Void->Void = () -> FmodManager.Update();

    /** Hooks the update once. Safe to call again, and after a recreated FlxGame. **/
    public static function init():Void {
        // Remove-then-add keeps a single hook across repeated init calls.
        FlxG.signals.postUpdate.remove(handler);
        FlxG.signals.postUpdate.add(handler);
    }

    /** True while the per-frame hook is installed. **/
    public static function isInstalled():Bool {
        return FlxG.signals.postUpdate.has(handler);
    }

    /** Removes the hook. FmodManager.Update() then runs only when the game calls it. **/
    public static function remove():Void {
        FlxG.signals.postUpdate.remove(handler);
    }
}
