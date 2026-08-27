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
        this.async = async;
        paths = [for (file in bankFiles) FmodRuntime.bankPath(file)];
    }

    var async:Bool;
    var started:Bool = false;
    // Only paths whose load this loader actually registered are unloaded
    // by destroy(), so a rejected load can never steal a reference some
    // other holder registered for the same path later
    var owned:Array<String> = [];

    // Loads start on the first serviced frame after FMOD is ready, so a
    // loader constructed before (or during) initialization waits instead
    // of failing outright
    function startLoads():Void {
        started = true;
        for (path in paths) {
            var bank = async ? FmodRuntime.banks.loadAsync(path) : FmodRuntime.banks.load(path);
            if (!bank.isNull()) owned.push(path);
        }
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        // A destroyed loader has an empty path list, which would read as
        // "all banks loaded" and fire onLoaded after the banks were released
        if (loaded || destroyed || errored) return;
        if (!started) {
            if (!FmodRuntime.isInitialized()) return;
            startLoads();
        }
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
        for (path in owned) {
            FmodRuntime.banks.unload(path);
        }
        owned = [];
        paths = [];
        super.destroy();
    }
}
