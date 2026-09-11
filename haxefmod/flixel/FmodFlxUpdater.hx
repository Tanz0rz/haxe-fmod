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
    // One closure per install, each with its own generation captured.
    // Flixel defers a removal made inside the postUpdate dispatch to the
    // end of it. An add of the same listener in between finds it still
    // present and keeps the doomed entry, so the hook would be lost. A
    // distinct closure is pushed as a new entry and survives. The
    // capture matters: HashLink treats capture-free closures of one
    // function as equal, and flixel would dedupe them.
    static var handler:Void->Void = null;
    static var generation:Int = 0;
    // A closure pushed during the dispatch runs in that same dispatch.
    // This flag keeps FmodManager.Update at one run per frame, and the
    // preUpdate hook clears it.
    static var updated:Bool = false;
    static var frameStart:Void->Void = null;

    static function tick(id:Int):Void {
        // A closure flixel has yet to remove can run once more in the
        // frame it was removed in
        if (id != generation || updated) return;
        updated = true;
        FmodManager.Update();
    }

    static function clearUpdated():Void {
        updated = false;
    }

    /** Hooks the update once. Safe to call again, and from inside a callback. **/
    public static function init():Void {
        if (frameStart == null) {
            frameStart = clearUpdated;
            FlxG.signals.preUpdate.add(frameStart);
        }
        if (handler == null) {
            var id = ++generation;
            handler = () -> tick(id);
        }
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
        // The removed closure stops ticking at once, even where flixel
        // defers the removal to the end of the dispatch
        generation++;
    }
}
