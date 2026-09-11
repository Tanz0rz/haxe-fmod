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
    // One closure for the whole session. Flixel defers a removal that
    // runs inside the postUpdate dispatch to the end of it, and an add
    // of the same listener in between finds it still present and keeps
    // it, so the deferred removal would drop the hook. The hook is
    // therefore never removed from inside its own dispatch: the wanted
    // flag turns it off, and the next frame removes it.
    static var handler:Void->Void = () -> tick();
    static var wanted:Bool = false;
    static var inHandler:Bool = false;

    static function tick():Void {
        if (!wanted) {
            // Turned off from inside the dispatch. The removal is safe now,
            // since no add can come between it and the end of the frame.
            FlxG.signals.postUpdate.remove(handler);
            return;
        }
        inHandler = true;
        FmodManager.Update();
        inHandler = false;
    }

    /** Hooks the update once. Safe to call again, and from inside a callback. **/
    public static function init():Void {
        wanted = true;
        // add() keeps a single hook: a listener already registered is
        // returned as is
        FlxG.signals.postUpdate.add(handler);
    }

    /** True while the per-frame hook is installed. **/
    public static function isInstalled():Bool {
        return wanted && FlxG.signals.postUpdate.has(handler);
    }

    /** Removes the hook. FmodManager.Update() then runs only when the game calls it. **/
    public static function removeHook():Void {
        wanted = false;
        // From inside the dispatch the listener stays until its next
        // frame, where it removes itself. An init before then keeps it.
        if (!inHandler) FlxG.signals.postUpdate.remove(handler);
    }
}
