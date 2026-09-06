package haxefmod.flixel;

import flixel.FlxBasic;
import haxefmod.runtime.BankLoadTracker;

/**
    Loads a set of banks and reports when they are all ready.

    File names are resolved against the configured bank folder (see
    FmodSettings.bankFolder), so pass plain names like "Vehicles.bank".
    Loading is refcounted through FmodRuntime.banks: destroy() releases
    this loader's references, and the banks unload once nobody else holds
    them. Add the loader to the state so its update() can poll:

        add(new FmodFlxBankLoader(["Vehicles.bank"], () -> spawnCars()));
**/
class FmodFlxBankLoader extends FlxBasic {
    /** True once every requested bank has finished loading. **/
    public var loaded(get, never):Bool;

    var tracker:BankLoadTracker;

    /**
        Starts loading immediately.
        @param bankFiles bank file names (resolved via FmodRuntime.bankPath)
        @param onLoaded called exactly once, when all banks are loaded
        @param onError called exactly once, when any bank settles in an
        error state (a missing file or a failed fetch on html5). Without
        it a failed load is only visible through loadingState polling.
        @param async load in the background (default). Pass false to load
        synchronously on native targets
    **/
    public function new(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool = true) {
        super();
        tracker = new BankLoadTracker(bankFiles, onLoaded, onError, async);
    }

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
