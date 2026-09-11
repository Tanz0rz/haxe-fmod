package haxefmod.heaps;

import haxefmod.FmodManager;

/**
    Per-frame driver for FMOD in a Heaps game. Call init() once at startup
    (FmodHeapsSetup.init() does this for you).

    Heaps has no component list to hook. On HashLink the updater is a
    repeating event on the main thread's event loop. hxd.System pumps
    that loop once per frame, before hxd.App.update. haxe.MainLoop is
    never ticked there on Haxe 4.2 and later. In the browser the updater
    is a requestAnimationFrame loop. Every haxefmod.heaps component
    registers here. The updater ticks each component before
    FmodManager.Update() runs. The positions it samples are the ones the
    last update set, so they reach FMOD at the start of the next frame.
    A game that needs them in the same frame calls FmodManager.Update()
    at the end of its own update and leaves this updater out with
    removeHook().
**/
class FmodHeapsUpdater {
    /** How many times the frame hook was actually installed (1 after init). **/
    @:dox(hide)
    public static var installCount(default, null):Int = 0;

    static var tickers:Array<IHeapsTicker> = [];
    static var lastStamp:Float = -1;
    static var installed:Bool = false;
    #if js
    static var frameRequest:Int = 0;
    #elseif (target.threaded && haxe_ver >= 4.2)
    static var eventHandler:sys.thread.EventLoop.EventHandler = null;
    #else
    static var mainLoopEvent:haxe.MainLoop.MainEvent = null;
    #end

    /** Installs the frame hook once. Later calls do nothing. **/
    public static function init():Void {
        if (installed) return;
        installed = true;
        installCount++;
        #if js
        frameRequest = js.Browser.window.requestAnimationFrame(browserFrame);
        #elseif (target.threaded && haxe_ver >= 4.2)
        // Interval 0 runs the event exactly once per progress() call.
        eventHandler = sys.thread.Thread.current().events.repeat(frame, 0);
        #else
        mainLoopEvent = haxe.MainLoop.add(frame);
        #end
    }

    /** True while the frame hook is installed. **/
    public static function isInstalled():Bool {
        return installed;
    }

    /** Removes the frame hook. FmodManager.Update() then runs only when the game calls it. **/
    public static function removeHook():Void {
        if (!installed) return;
        installed = false;
        lastStamp = -1;
        #if js
        js.Browser.window.cancelAnimationFrame(frameRequest);
        #elseif (target.threaded && haxe_ver >= 4.2)
        sys.thread.Thread.current().events.cancel(eventHandler);
        eventHandler = null;
        #else
        mainLoopEvent.stop();
        mainLoopEvent = null;
        #end
    }

    #if js
    static function browserFrame(_:Float):Void {
        frame();
        // A removeHook from inside frame() cancels a request that is
        // already being serviced, so the loop ends here instead
        if (!installed) return;
        frameRequest = js.Browser.window.requestAnimationFrame(browserFrame);
    }
    #end

    /** Registers a component to be ticked every frame, installing the frame hook if needed. **/
    public static function add(ticker:IHeapsTicker):Void {
        init();
        if (tickers.indexOf(ticker) == -1) tickers.push(ticker);
    }

    /** Unregisters a component. The updater stops ticking it. **/
    public static function remove(ticker:IHeapsTicker):Void {
        tickers.remove(ticker);
    }

    /** How many components are registered. **/
    @:dox(hide)
    public static function count():Int {
        return tickers.length;
    }

    static function frame():Void {
        var now = haxe.Timer.stamp();
        var dt = lastStamp < 0 ? 0.0 : now - lastStamp;
        lastStamp = now;
        // Copy first: a ticker can remove itself (a loader that just fired).
        for (ticker in tickers.copy()) {
            ticker.tick(dt);
        }
        FmodManager.Update();
    }
}

/** A component the updater ticks once per frame with the elapsed seconds. **/
@:dox(hide)
interface IHeapsTicker {
    function tick(dt:Float):Void;
}
