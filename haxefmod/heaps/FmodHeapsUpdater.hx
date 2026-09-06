package haxefmod.heaps;

import haxefmod.FmodManager;

/**
    Per-frame driver for FMOD in a Heaps game. Call init() once at startup
    (FmodHeapsSetup.init() does this for you).

    Heaps has no component list to hook. On HashLink the updater is a
    repeating event on the main thread's event loop, which hxd.System
    pumps once per frame (haxe.MainLoop is never ticked there on Haxe
    4.2+). In the browser it is a requestAnimationFrame loop. Every
    haxefmod.heaps component registers here and is ticked before
    FmodManager.Update() runs, so the positions it samples reach FMOD in
    the same frame.
**/
class FmodHeapsUpdater {
    /** How many times the frame hook was actually installed (1 after init). **/
    public static var installCount(default, null):Int = 0;

    static var tickers:Array<IHeapsTicker> = [];
    static var lastStamp:Float = -1;

    public static function init():Void {
        if (installCount > 0) return;
        installCount++;
        #if js
        js.Browser.window.requestAnimationFrame(browserFrame);
        #elseif (target.threaded && haxe_ver >= 4.2)
        // Interval 0 runs the event exactly once per progress() call
        sys.thread.Thread.current().events.repeat(frame, 0);
        #else
        haxe.MainLoop.add(frame);
        #end
    }

    #if js
    static function browserFrame(_:Float):Void {
        frame();
        js.Browser.window.requestAnimationFrame(browserFrame);
    }
    #end

    /** Registers a component to be ticked every frame, installing the frame hook if needed. **/
    public static function add(ticker:IHeapsTicker):Void {
        init();
        if (tickers.indexOf(ticker) == -1) tickers.push(ticker);
    }

    public static function remove(ticker:IHeapsTicker):Void {
        tickers.remove(ticker);
    }

    /** How many components are registered. **/
    public static function count():Int {
        return tickers.length;
    }

    static function frame():Void {
        var now = haxe.Timer.stamp();
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
interface IHeapsTicker {
    function tick(dt:Float):Void;
}
