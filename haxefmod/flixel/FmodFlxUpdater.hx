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

    /** Hooks the update once. Safe to call again, and from inside a callback. **/
    public static function init():Void {
        // add() keeps a single hook: a listener already registered is
        // returned as is. A remove first would drop the hook when init
        // runs inside the postUpdate dispatch. Flixel defers that removal
        // to the end of the dispatch, and add() sees the listener still
        // present until then.
        FlxG.signals.postUpdate.add(handler);
    }

    /** True while the per-frame hook is installed. **/
    public static function isInstalled():Bool {
        return FlxG.signals.postUpdate.has(handler);
    }

    /** Removes the hook. FmodManager.Update() then runs only when the game calls it. **/
    public static function removeHook():Void {
        FlxG.signals.postUpdate.remove(handler);
    }
}
