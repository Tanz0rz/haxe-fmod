package haxefmod.kha;

import haxefmod.FmodManager;
import kha.Scheduler;

/**
    Per-frame driver for FMOD in a Kha game. Call init() once at startup
    (FmodKhaSetup.init() does this for you).

    The updater is a Scheduler frame task at priority 100. Kha runs frame
    tasks in ascending priority order, so it runs after the game's own
    tasks at lower numbers. Every haxefmod.kha component registers here.
    The task calls update(), which ticks each component and then runs
    FmodManager.Update(). The positions the game set this frame reach
    FMOD in the same frame.

    A game that runs FMOD from its own task calls removeHook() once and
    then calls update() from that task. The task stays out after that.
    A component created later registers without installing it.
    init(), FmodKhaSetup.init(), and FmodKhaSetup.preload() install it
    again.
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
    // Set by removeHook() and cleared by init(). While set, add() leaves
    // the task out.
    static var hookRemoved:Bool = false;

    /** Installs the frame task once and undoes an earlier removeHook(). Later calls do nothing. **/
    public static function init():Void {
        hookRemoved = false;
        if (taskId >= 0) return;
        installCount++;
        taskId = Scheduler.addFrameTask(frame, PRIORITY);
    }

    /** True while the frame task is installed. **/
    public static function isInstalled():Bool {
        return taskId >= 0;
    }

    /**
        Removes the frame task. The game then calls update() once per
        frame. Components created afterwards leave the task out. init()
        installs it again.
    **/
    public static function removeHook():Void {
        hookRemoved = true;
        if (taskId < 0) return;
        Scheduler.removeFrameTask(taskId);
        taskId = -1;
        lastStamp = -1;
    }

    /** Registers a component to be ticked every frame. Installs the frame task unless removeHook() took it out. **/
    public static function add(ticker:IKhaTicker):Void {
        if (!hookRemoved) init();
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

    /**
        Ticks every registered component with the seconds since the last
        update, then runs FmodManager.Update(). The frame task calls it.
        After removeHook() the game calls it from its own task instead.
    **/
    public static function update():Void {
        // A frame task installed later in this frame finds the frame done
        lastFrameTime = Scheduler.time();
        var now = Scheduler.realTime();
        var dt = lastStamp < 0 ? 0.0 : now - lastStamp;
        lastStamp = now;
        // Copy first: a ticker can remove itself (a loader that just fired).
        for (ticker in tickers.copy()) {
            ticker.tick(dt);
        }
        FmodManager.Update();
    }

    static function frame():Void {
        var frameTime = Scheduler.time();
        if (frameTime == lastFrameTime) return;
        lastFrameTime = frameTime;
        update();
    }
}

/** A component the updater ticks once per frame with the elapsed seconds. **/
@:dox(hide)
interface IKhaTicker {
    function tick(dt:Float):Void;
}
