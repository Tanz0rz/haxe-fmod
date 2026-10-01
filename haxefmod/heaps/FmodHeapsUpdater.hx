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
    registers here. Each frame the hook calls update(), which ticks each
    component and then runs FmodManager.Update(). The positions it
    samples are the ones the last update set, so they reach FMOD at the
    start of the next frame.

    A game that needs them in the same frame calls removeHook() once and
    then calls update() at the end of its own update. The hook stays out
    after that. A component created later registers without installing
    it. init(), FmodHeapsSetup.init(), and FmodHeapsSetup.preload()
    install it again.
**/
class FmodHeapsUpdater {
    /** How many times the frame hook was actually installed (1 after init). **/
    @:dox(hide)
    public static var installCount(default, null):Int = 0;

    static var tickers:Array<IHeapsTicker> = [];
    static var lastStamp:Float = -1;
    static var installed:Bool = false;
    // Set by removeHook() and cleared by init(). While set, add() leaves
    // the hook out.
    static var hookRemoved:Bool = false;
    #if js
    static var frameRequest:Int = 0;
    // True while browserFrame runs its tickers. An init from inside
    // leaves the re-arm to the running frame.
    static var inFrame:Bool = false;
    #elseif (target.threaded && haxe_ver >= 4.2)
    static var eventHandler:sys.thread.EventLoop.EventHandler = null;
    #else
    static var mainLoopEvent:haxe.MainLoop.MainEvent = null;
    #end

    /** Installs the frame hook once and undoes an earlier removeHook(). Later calls do nothing. **/
    public static function init():Void {
        hookRemoved = false;
        if (installed) return;
        installed = true;
        installCount++;
        #if js
        if (!inFrame) frameRequest = js.Browser.window.requestAnimationFrame(browserFrame);
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

    /**
        Removes the frame hook. The game then calls update() once per
        frame. Components created afterwards leave the hook out. init()
        installs it again.
    **/
    public static function removeHook():Void {
        hookRemoved = true;
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
        inFrame = true;
        try {
            frame();
        } catch (e:Dynamic) {
            // A throwing ticker must not end the loop: the next frame is
            // armed before the error goes on to the browser console
            inFrame = false;
            if (installed) frameRequest = js.Browser.window.requestAnimationFrame(browserFrame);
            throw e;
        }
        inFrame = false;
        // A removeHook from inside frame() cancels a request that is
        // already being serviced, so the loop ends here instead. An init
        // from inside left the re-arm to this line, so one loop runs.
        if (!installed) return;
        frameRequest = js.Browser.window.requestAnimationFrame(browserFrame);
    }
    #end

    /** Registers a component to be ticked every frame. Installs the frame hook unless removeHook() took it out. **/
    public static function add(ticker:IHeapsTicker):Void {
        if (!hookRemoved) init();
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

    /**
        Ticks every registered component with the seconds since the last
        update, then runs FmodManager.Update(). The installed hook calls
        it every frame. After removeHook() the game calls it at the end of
        its own update instead.
    **/
    public static function update():Void {
        var now = haxe.Timer.stamp();
        var dt = lastStamp < 0 ? 0.0 : now - lastStamp;
        lastStamp = now;
        // Copy first: a ticker can remove itself (a loader that just fired).
        for (ticker in tickers.copy()) {
            ticker.tick(dt);
        }
        FmodManager.Update();
    }

    static function frame():Void {
        update();
    }
}

/** A component the updater ticks once per frame with the elapsed seconds. **/
@:dox(hide)
interface IHeapsTicker {
    function tick(dt:Float):Void;
}
