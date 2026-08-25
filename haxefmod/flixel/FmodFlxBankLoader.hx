package haxefmod.flixel;

import flixel.FlxBasic;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.Types;

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
    public var loaded(default, null):Bool = false;

    var destroyed:Bool = false;

    var paths:Array<String>;
    var onLoaded:Void->Void;
    var onError:Void->Void;
    var errored:Bool = false;

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
        this.onLoaded = onLoaded;
        this.onError = onError;
        paths = [for (file in bankFiles) FmodRuntime.bankPath(file)];
        for (path in paths) {
            if (async) {
                FmodRuntime.banks.loadAsync(path);
            } else {
                FmodRuntime.banks.load(path);
            }
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        // A destroyed loader has an empty path list, which would read as
        // "all banks loaded" and fire onLoaded after the banks were released
        if (loaded || destroyed || errored) return;
        for (path in paths) {
            var state = FmodRuntime.banks.loadingState(path);
            // ERROR: an async load settled in failure. UNLOADED: the load
            // this constructor issued was rejected outright and never
            // registered. Both are load failures.
            if (state == ERROR || state == UNLOADED) {
                errored = true;
                if (onError != null) onError();
                return;
            }
        }
        for (path in paths) {
            if (!FmodRuntime.banks.isLoaded(path)) return;
        }
        loaded = true;
        if (onLoaded != null) onLoaded();
    }

    /** Releases this loader's bank references (refcounted unload). **/
    override public function destroy():Void {
        destroyed = true;
        for (path in paths) {
            FmodRuntime.banks.unload(path);
        }
        paths = [];
        super.destroy();
    }
}
