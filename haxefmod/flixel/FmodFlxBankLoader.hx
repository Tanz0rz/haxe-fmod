package haxefmod.flixel;

import flixel.FlxBasic;
import haxefmod.runtime.BankLoadTracker;

/**
    Loads a set of banks and reports when they are all ready.

    File names resolve against the configured bank folder (see
    FmodSettings.bankFolder). Pass plain names like "Vehicles.bank".
    Loading is refcounted through FmodRuntime.banks. destroy() releases
    this loader's references. The banks unload once nobody else holds
    them. Add the loader to the state so its update() can poll:

        add(new FmodFlxBankLoader(["Vehicles.bank"], () -> spawnCars()));
**/
class FmodFlxBankLoader extends FlxBasic {
    /** True once every requested bank has finished loading. **/
    public var loaded(get, never):Bool;

    var tracker:BankLoadTracker;

    /**
        Loading starts once FMOD is ready, on the first update after that.
        @param bankFiles Bank file names, resolved through FmodRuntime.bankPath.
        @param onLoaded Called exactly once, when all banks are loaded.
        @param onError Called exactly once, when any bank settles in an
        error state (a missing file or a failed fetch on HTML5). Without
        it, a failed load is only visible through loadingState polling.
        @param async Loads in the background (default). Pass false to load
        synchronously on native targets.
    **/
    public function new(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool = true) {
        super();
        tracker = new BankLoadTracker(bankFiles, onLoaded, onError, async);
        FmodFlxUpdater.init();
    }

    /** Polls the loading state and fires the callbacks once the banks settle. **/
    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        tracker.update();
    }

    /** Releases this loader's bank references (refcounted unload). **/
    override public function destroy():Void {
        tracker.dispose();
        super.destroy();
    }

    function get_loaded():Bool return tracker.loaded;
}
