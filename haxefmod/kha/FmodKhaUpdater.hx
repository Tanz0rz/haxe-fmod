package haxefmod.kha;

import haxefmod.FmodManager;
import kha.Scheduler;

/**
    Per-frame driver for FMOD in a Kha game. Call init() once at startup
    (FmodKhaSetup.init() does this for you).

    The updater is a Scheduler frame task at priority 100. Kha runs frame
    tasks in ascending priority order, so it runs after the game's own
    tasks at lower numbers. Every haxefmod.kha component registers here.
    The updater ticks each component before FmodManager.Update() runs, so
    the positions the game set this frame reach FMOD in the same frame.
**/
class FmodKhaUpdater {
    /** How many times the frame task was actually installed (1 after init). **/
    @:dox(hide)
    public static var installCount(default, null):Int = 0;

    /** The frame task priority. Lower numbers run first, so the game's tasks go below this. **/
    public static inline var PRIORITY:Int = 100;

    static var tickers:Array<IKhaTicker> = [];
    static var lastStamp:Float = -1;
    static var taskId:Int = -1;
    // Scheduler.time() holds one value for the whole frame. A task added
    // during the frame runs in that frame, so a reinstall from inside a
    // tick would tick everything twice without this latch.
    static var lastFrameTime:Float = -1;

    /** Installs the frame task once. Later calls do nothing. **/
    public static function init():Void {
        if (taskId >= 0) return;
        installCount++;
        taskId = Scheduler.addFrameTask(frame, PRIORITY);
    }

    /** True while the frame task is installed. **/
    public static function isInstalled():Bool {
        return taskId >= 0;
    }

    /** Removes the frame task. FmodManager.Update() then runs only when the game calls it. **/
    public static function removeHook():Void {
        if (taskId < 0) return;
        Scheduler.removeFrameTask(taskId);
        taskId = -1;
        lastStamp = -1;
    }

    /** Registers a component to be ticked every frame, installing the frame task if needed. **/
    public static function add(ticker:IKhaTicker):Void {
        init();
        if (tickers.indexOf(ticker) == -1) tickers.push(ticker);
    }

    /** Unregisters a component. The updater stops ticking it. **/
    public static function remove(ticker:IKhaTicker):Void {
        tickers.remove(ticker);
    }

    /** How many components are registered. **/
    @:dox(hide)
    public static function count():Int {
        return tickers.length;
    }

    static function frame():Void {
        var frameTime = Scheduler.time();
        if (frameTime == lastFrameTime) return;
        lastFrameTime = frameTime;
        var now = Scheduler.realTime();
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
interface IKhaTicker {
    function tick(dt:Float):Void;
}
