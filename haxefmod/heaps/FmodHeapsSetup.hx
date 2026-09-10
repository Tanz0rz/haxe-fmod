package haxefmod.heaps;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import hxd.Event;

/**
    One-call FMOD setup for Heaps games. Call init() once from your
    hxd.App's init(). init() does the following.

    It initializes FMOD. Settings pass through to FmodManager.Initialize.
    The first initialization wins. Settings are ignored if something
    already initialized FMOD.

    It installs FmodHeapsUpdater so FmodManager.Update() runs every frame.

    It mutes the FMOD master output while the window is unfocused, through
    the window's focus events.

    Heaps has no global volume control of its own, so the FMOD master bus
    is the volume. Use FmodManager.SetMasterVolume and SetMasterMute.

    Calling init() again is safe and keeps a single focus wiring.

    preload() does the same and also loads the default banks through
    Heaps' own binary loader, then calls back once FMOD is ready. The
    first scene can then play events at once, on HTML5 too.
**/
class FmodHeapsSetup {
    /**
        Initializes FMOD, loads the default banks through hxd.net.BinaryLoader
        from the bank folder, and calls onReady once everything is usable.
        On HTML5 the bank fetch and the FMOD module load run in parallel.
        On HashLink both are synchronous and onReady runs before this
        returns. onFailed runs instead when a bank cannot be loaded, and
        the console names it.
        @param settings The FmodSettings for Initialize. banksProvided is set here.
        @param onReady Called once FMOD and the default banks are usable.
        @param onFailed Called when a default bank fails to load.
    **/
    public static function preload(?settings:FmodSettings, onReady:Void->Void, ?onFailed:Void->Void):Void {
        if (settings == null) settings = {};
        settings.banksProvided = true;
        var resolved = haxefmod.runtime.FmodSettingsResolver.resolve(settings);
        var failed = false;
        var fail = function(fileName:String, reason:String) {
            if (failed) return;
            failed = true;
            trace('Error: FMOD - could not load the default bank $fileName: $reason');
            if (onFailed != null) onFailed();
        };
        #if js
        // The wasm module and the bank fetches run in parallel
        init(settings);
        #end
        for (fileName in resolved.autoLoadBanks) {
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            #if js
            var loader = new hxd.net.BinaryLoader(path);
            loader.onLoaded = function(bytes:haxe.io.Bytes) FmodRuntime.provideBank(fileName, bytes);
            loader.onError = function(message:String) fail(fileName, message);
            loader.load();
            #else
            try {
                FmodRuntime.provideBank(fileName, sys.io.File.getBytes(path));
            } catch (e:Dynamic) {
                fail(fileName, Std.string(e));
            }
            #end
        }
        if (failed) return;
        #if !js
        // Native init loads the default banks inside init, from the bytes
        // provided above
        init(settings);
        #end
        FmodRuntime.onceReady(onReady, function() {
            if (!failed) fail("a default bank", "the runtime reports the load failed");
        });
    }

    /** Initializes FMOD and wires the Heaps updater and focus hooks. **/
    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodHeapsUpdater.init();
        var window = hxd.Window.getInstance();
        // Remove-then-add keeps exactly one wiring across repeated init
        // calls.
        window.removeEventTarget(onWindowEvent);
        window.addEventTarget(onWindowEvent);
    }

    static function onWindowEvent(event:Event):Void {
        switch (event.kind) {
            case EFocus: FmodRuntime.setWindowFocused(true);
            case EFocusLost: FmodRuntime.setWindowFocused(false);
            default:
        }
    }
}
