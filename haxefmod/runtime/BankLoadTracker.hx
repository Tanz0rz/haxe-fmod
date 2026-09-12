package haxefmod.runtime;

import haxefmod.studio.Types;

/**
    Engine-free half of a bank loader component. Loads a set of banks and
    reports once when they are all ready, or once when any of them fails.

    File names resolve against the configured bank folder (see
    FmodSettings.bankFolder). Pass plain names like "Vehicles.bank".
    Loading is refcounted through FmodRuntime.banks. dispose() releases
    this loader's references. The banks unload once nobody else holds
    them. Engine adapters call update() every frame.
*/
class BankLoadTracker {
    /** True once every requested bank has finished loading. */
    public var loaded(default, null):Bool = false;

    var disposed:Bool = false;
    // The file names as given. They resolve against the bank folder once
    // FMOD is ready, since init sets the folder.
    var files:Array<String>;
    var paths:Array<String> = [];
    var onLoaded:Void->Void;
    var onError:Void->Void;
    var errored:Bool = false;
    var async:Bool;
    var started:Bool = false;
    // dispose() unloads only the paths whose load this loader registered.
    // A rejected load therefore never steals a reference some other
    // holder registered for the same path later.
    var owned:Array<String> = [];

    /**
        Loading starts once FMOD is ready, on the first update after that.
        @param bankFiles Bank file names, resolved through FmodRuntime.bankPath.
        @param onLoaded Called exactly once, when all banks are loaded.
        @param onError Called exactly once, when any bank settles in an
        error state (a missing file or a failed fetch on HTML5). It also
        runs once when FMOD refused to initialize. Without it, a failed
        load is only visible through loadingState polling.
        @param async Loads in the background (default). Pass false to load
        synchronously on native targets.
    */
    public function new(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool = true) {
        this.onLoaded = onLoaded;
        this.onError = onError;
        this.async = async;
        files = bankFiles;
    }

    // Loads start on the first serviced frame after FMOD is ready. A
    // loader constructed before (or during) initialization waits instead
    // of failing outright.
    function startLoads():Void {
        started = true;
        paths = [for (file in files) FmodRuntime.bankPath(file)];
        for (path in paths) {
            var bank = async ? FmodRuntime.banks.loadAsync(path) : FmodRuntime.banks.load(path);
            if (!bank.isNull()) owned.push(path);
        }
    }

    /** Starts the loads once FMOD is ready, then polls until the banks settle. */
    public function update():Void {
        // A disposed loader has an empty path list. That reads as "all
        // banks loaded" and fires onLoaded after the banks were released.
        if (loaded || disposed || errored) return;
        if (!started) {
            if (!FmodRuntime.isInitialized()) {
                // A refused system never comes up, so the banks never
                // settle. The loader reports that once, like a failed load.
                if (FmodRuntime.initSettled() && FmodRuntime.initFailed()) {
                    errored = true;
                    if (onError != null) onError();
                }
                return;
            }
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

    /** Releases this loader's bank references (refcounted unload). */
    public function dispose():Void {
        disposed = true;
        for (path in owned) {
            FmodRuntime.banks.unload(path);
        }
        owned = [];
        paths = [];
    }
}
