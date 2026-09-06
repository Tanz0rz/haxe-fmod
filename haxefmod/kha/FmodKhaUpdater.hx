package haxefmod.kha;

import haxefmod.FmodManager;
import kha.Scheduler;

/**
    Per-frame driver for FMOD in a Kha game. Call init() once at startup
    (FmodKhaSetup.init() does this for you).

    The updater is a Scheduler frame task. Every haxefmod.kha component
    registers here and is ticked before FmodManager.Update() runs, so the
    positions it samples reach FMOD in the same frame.
**/
class FmodKhaUpdater {
    /** How many times the frame task was actually installed (1 after init). **/
    public static var installCount(default, null):Int = 0;

    static var tickers:Array<IKhaTicker> = [];
    static var lastStamp:Float = -1;

    public static function init():Void {
        if (installCount > 0) return;
        installCount++;
        // Priority 0 runs after the game's own frame tasks at higher
        // priorities, so positions set this frame are what FMOD sees
        Scheduler.addFrameTask(frame, 0);
    }

    /** Registers a component to be ticked every frame, installing the frame task if needed. **/
    public static function add(ticker:IKhaTicker):Void {
        init();
        if (tickers.indexOf(ticker) == -1) tickers.push(ticker);
    }

    public static function remove(ticker:IKhaTicker):Void {
        tickers.remove(ticker);
    }

    /** How many components are registered. **/
    public static function count():Int {
        return tickers.length;
    }

    static function frame():Void {
        var now = Scheduler.realTime();
        var dt = lastStamp < 0 ? 0.0 : now - lastStamp;
        lastStamp = now;
        // Copy first: a ticker may remove itself (a loader that just fired)
        for (ticker in tickers.copy()) {
            ticker.tick(dt);
        }
        FmodManager.Update();
    }
}

/** A component the updater ticks once per frame with the elapsed seconds. **/
interface IKhaTicker {
    function tick(dt:Float):Void;
}
