package haxefmod.flixel;

import flixel.FlxBasic;
import haxefmod.runtime.FmodRuntime;

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

    var paths:Array<String>;
    var onLoaded:Void->Void;

    /**
        Starts loading immediately.
        @param bankFiles bank file names (resolved via FmodRuntime.bankPath)
        @param onLoaded called exactly once, when all banks are loaded
        @param async load in the background (default). Pass false to load
        synchronously on native targets
    **/
    public function new(bankFiles:Array<String>, ?onLoaded:Void->Void, async:Bool = true) {
        super();
        this.onLoaded = onLoaded;
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
        if (loaded) return;
        for (path in paths) {
            if (!FmodRuntime.banks.isLoaded(path)) return;
        }
        loaded = true;
        if (onLoaded != null) onLoaded();
    }

    /** Releases this loader's bank references (refcounted unload). **/
    override public function destroy():Void {
        for (path in paths) {
            FmodRuntime.banks.unload(path);
        }
        paths = [];
        super.destroy();
    }
}
