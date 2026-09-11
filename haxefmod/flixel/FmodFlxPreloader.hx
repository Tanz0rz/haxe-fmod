package haxefmod.flixel;

import flixel.system.FlxPreloader;
import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.utils.Assets;

/**
    A lime preloader that has FMOD ready when the first state starts.

    Set it in Project.xml:

        <app preloader="haxefmod.flixel.FmodFlxPreloader" />

    The preloader initializes FMOD while lime loads the assets. The
    default banks come from the loaded assets, so the runtime fetches
    none of them. The preloader completes once initialization settled,
    and the first state plays events at once. Native targets initialize
    synchronously, so the preloader completes as soon as the assets do.
    It installs FmodFlxUpdater, so FmodManager.Update() runs every frame
    from the first state on.

    A subclass overrides settings() to pass FmodSettings. It runs once,
    and the preloader sets banksProvided on the object it returns. The
    first initialization wins, so settings passed to FmodFlxSetup.init
    later are ignored. Override create() and update() for custom visuals
    the way FlxPreloader allows.

    When a default bank is missing or fails to load, or FMOD refuses to
    initialize, the preloader shows the failure for failureDisplayTime
    seconds, then completes. The game then runs without that bank, and
    the console names it.
**/
class FmodFlxPreloader extends FlxPreloader {
    /** How long the failure message stays before the game starts anyway, in seconds. **/
    public var failureDisplayTime:Float = 4;

    var initialized:Bool = false;
    var assetsLoaded:Bool = false;
    var provided:Bool = false;
    var pendingLoads:Int = 0;
    var failedAt:Float = -1;
    var failureText:TextField;
    var fmodSettings:FmodSettings;
    var resolved:haxefmod.runtime.ResolvedFmodSettings;

    /** The settings FMOD initializes with. Override it in a subclass. Null means the defines and defaults. **/
    function settings():Null<FmodSettings> {
        return null;
    }

    override function create():Void {
        super.create();
        #if js
        // The wasm module loads while lime loads the assets. The banks
        // arrive once the assets are in, and the runtime waits for them.
        initialize();
        #end
    }

    function initialize():Void {
        if (initialized) return;
        initialized = true;
        resolvedSettings();
        FmodManager.Initialize(fmodSettings);
    }

    /**
        Lime reports the assets as loaded here on HTML5. On native targets
        this runs before the asset library is registered, so the banks are
        picked up from update() once the library exists.
    **/
    override public function onLoaded():Void {
        super.onLoaded();
        _loaded = false;
        assetsLoaded = true;
    }

    // The settings are read once. The resolved copy names the banks and
    // the folder before the runtime has them.
    function resolvedSettings():haxefmod.runtime.ResolvedFmodSettings {
        if (resolved == null) {
            fmodSettings = settings();
            if (fmodSettings == null) fmodSettings = {};
            fmodSettings.banksProvided = true;
            resolved = haxefmod.runtime.FmodSettingsResolver.resolve(fmodSettings);
        }
        return resolved;
    }

    /**
        Hands every bank in autoLoadBanks to the runtime. A bank lime
        preloaded is read at once. A bank the project marked as not
        preloaded is fetched here, and initialization waits for it. A
        bank the project assets lack is reported as failed.
    **/
    function provideBanks():Void {
        var resolved = resolvedSettings();
        for (fileName in resolved.autoLoadBanks) {
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            if (!Assets.exists(path)) {
                FmodRuntime.provideBankFailed(fileName, 'the project assets have no $path. Add the bank folder to the project assets');
                continue;
            }
            if (lime.utils.Assets.isLocal(path, BINARY)) {
                // The manifest lists the asset. On a native target the
                // file can still be absent from the bank folder.
                var bytes = Assets.getBytes(path);
                if (bytes == null) FmodRuntime.provideBankFailed(fileName, 'the assets list $path but there is no file behind it. Check the bank folder');
                else FmodRuntime.provideBank(fileName, bytes);
                continue;
            }
            pendingLoads++;
            lime.utils.Assets.loadBytes(path).onComplete(function(bytes) {
                FmodRuntime.provideBank(fileName, bytes);
                pendingLoads--;
            }).onError(function(error) {
                FmodRuntime.provideBankFailed(fileName, 'the preloader could not load $path ($error)');
                pendingLoads--;
            });
        }
    }

    override public function update(percent:Float):Void {
        super.update(percent);
        if (!provided) {
            // Lime hands out asset bytes after its own preload, and on
            // native targets it registers the library a frame or two after
            // the preloader started
            if (!assetsLoaded || lime.utils.Assets.getLibrary("default") == null) return;
            provided = true;
            provideBanks();
        }
        if (pendingLoads > 0) return;
        // Native init loads the default banks inside Initialize, so the
        // bytes go in first. HTML5 is initialized from create().
        initialize();
        FmodManager.Update();
        // Every default bank has loaded or failed, or FMOD refused
        if (!FmodManager.InitializeSettled()) return;
        if (!FmodManager.InitializeFailed()) {
            complete();
            return;
        }
        var now = haxe.Timer.stamp();
        if (failedAt < 0) {
            failedAt = now;
            showFailure();
        } else if (now - failedAt >= failureDisplayTime) {
            complete();
        }
    }

    // The game runs FMOD from here on, with or without every bank
    function complete():Void {
        FmodFlxUpdater.init();
        _loaded = true;
    }

    /** Shows the failure message. Override it for a custom look. **/
    function showFailure():Void {
        failureText = new TextField();
        failureText.defaultTextFormat = new TextFormat(null, 14, 0xffffff);
        failureText.width = openfl.Lib.current.stage.stageWidth;
        failureText.y = openfl.Lib.current.stage.stageHeight * 0.75;
        failureText.multiline = true;
        failureText.wordWrap = true;
        failureText.selectable = false;
        failureText.text = "FMOD did not fully start. The game starts anyway.";
        addChild(failureText);
    }

    override function destroy():Void {
        if (failureText != null) {
            removeChild(failureText);
            failureText = null;
        }
        super.destroy();
    }
}
