package haxefmod.kha;

import haxefmod.kha.FmodKhaUpdater.IKhaTicker;
import haxefmod.runtime.BankLoadTracker;

/**
    Loads a set of banks and reports when they are all ready.

    File names are resolved against the configured bank folder (see
    FmodSettings.bankFolder), so pass plain names like "Vehicles.bank".
    Loading is refcounted through FmodRuntime.banks: dispose() releases
    this loader's references, and the banks unload once nobody else holds
    them. The loader registers with FmodKhaUpdater and polls on its own.

        new FmodKhaBankLoader(["Vehicles.bank"], () -> spawnCars());
**/
class FmodKhaBankLoader implements IKhaTicker {
    /** True once every requested bank has finished loading. **/
    public var loaded(get, never):Bool;

    var tracker:BankLoadTracker;

    /**
        Starts loading on the next frame FMOD is ready.
        @param bankFiles bank file names (resolved via FmodRuntime.bankPath)
        @param onLoaded called exactly once, when all banks are loaded
        @param onError called exactly once, when any bank settles in an
        error state (a missing file or a failed fetch on html5)
        @param async load in the background (default). Pass false to load
        synchronously on native targets
    **/
    public function new(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool = true) {
        tracker = new BankLoadTracker(bankFiles, onLoaded, onError, async);
        FmodKhaUpdater.add(this);
    }

    public function tick(dt:Float):Void {
        tracker.update();
    }

    /** Releases this loader's bank references (refcounted unload). **/
    public function dispose():Void {
        FmodKhaUpdater.remove(this);
        tracker.dispose();
    }

    function get_loaded():Bool return tracker.loaded;
}
