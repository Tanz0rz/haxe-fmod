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
    // A fresh closure per install. Flixel defers a removal that runs
    // inside the postUpdate dispatch to the end of that dispatch. add()
    // would then find the old closure still present and keep it. An
    // init after a removeHook in the same dispatch therefore registers
    // a distinct closure, which survives the deferred removal.
    static var handler:Void->Void = null;

    /** Hooks the update once. Safe to call again, and from inside a callback. **/
    public static function init():Void {
        if (handler == null) handler = () -> FmodManager.Update();
        // add() keeps a single hook: a listener already registered is
        // returned as is
        FlxG.signals.postUpdate.add(handler);
    }

    /** True while the per-frame hook is installed. **/
    public static function isInstalled():Bool {
        return handler != null && FlxG.signals.postUpdate.has(handler);
    }

    /** Removes the hook. FmodManager.Update() then runs only when the game calls it. **/
    public static function removeHook():Void {
        if (handler == null) return;
        FlxG.signals.postUpdate.remove(handler);
        handler = null;
    }
}
