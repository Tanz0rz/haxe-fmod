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
    default banks come from the loaded assets, so nothing is fetched
    twice. The preloader completes once FMOD reports initialized, and
    the first state plays events at once. Native targets initialize
    synchronously, so the preloader completes as soon as the assets do.

    A subclass overrides settings() to pass FmodSettings. The first
    initialization wins, so settings passed to FmodFlxSetup.init later
    are ignored. Override create() and update() for custom visuals the
    way FlxPreloader allows.

    When a default bank fails to load, the preloader shows the failure
    for failureDisplayTime seconds, then completes. The game then runs
    without audio, and the console names the bank.
**/
class FmodFlxPreloader extends FlxPreloader {
    /** How long the failure message stays before the game starts anyway, in seconds. **/
    public var failureDisplayTime:Float = 4;

    var initialized:Bool = false;
    var provided:Bool = false;
    var failedAt:Float = -1;
    var failureText:TextField;

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
        var s = settings();
        if (s == null) s = {};
        s.banksProvided = true;
        FmodManager.Initialize(s);
    }

    /**
        Lime reports the assets as loaded here on HTML5. On native targets
        this runs before the asset library is registered, so the banks are
        picked up from update() once the library exists.
    **/
    override public function onLoaded():Void {
        super.onLoaded();
        _loaded = false;
    }

    /** True once lime's default library holds every bank in autoLoadBanks. **/
    function banksAvailable():Bool {
        if (lime.utils.Assets.getLibrary("default") == null) return false;
        var resolved = resolvedSettings();
        for (fileName in resolved.autoLoadBanks) {
            if (!Assets.exists(FmodRuntime.bankPath(fileName, resolved.bankFolder))) return false;
        }
        return true;
    }

    function resolvedSettings():haxefmod.runtime.ResolvedFmodSettings {
        var resolved = FmodRuntime.settings();
        return resolved != null ? resolved : haxefmod.runtime.FmodSettingsResolver.resolve(settings());
    }

    /** Hands every bank in autoLoadBanks that lime loaded to the runtime. **/
    function provideBanks():Void {
        var resolved = resolvedSettings();
        for (fileName in resolved.autoLoadBanks) {
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            FmodRuntime.provideBank(fileName, Assets.getBytes(path));
        }
    }

    override public function update(percent:Float):Void {
        super.update(percent);
        if (!provided) {
            if (!banksAvailable()) {
                // The library appears a frame or two after the preloader
                // on native targets. A bank missing from the project assets
                // is reported once lime reports the load complete.
                if (_percent >= 1 && lime.utils.Assets.getLibrary("default") != null) reportMissing();
                return;
            }
            provided = true;
            provideBanks();
            // Native init loads the default banks inside Initialize, so the
            // bytes go in first. HTML5 initialized in create()
            initialize();
        }
        FmodManager.Update();
        if (FmodManager.IsInitialized()) {
            _loaded = true;
            return;
        }
        if (!FmodManager.InitializeFailed()) return;
        var now = haxe.Timer.stamp();
        if (failedAt < 0) {
            failedAt = now;
            showFailure();
        } else if (now - failedAt >= failureDisplayTime) {
            _loaded = true;
        }
    }

    var missingReported:Bool = false;

    /** Names the banks the project assets lack, then initializes so the failure path runs. **/
    function reportMissing():Void {
        if (missingReported) return;
        missingReported = true;
        var resolved = resolvedSettings();
        for (fileName in resolved.autoLoadBanks) {
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            if (!Assets.exists(path)) trace('Error: FMOD - the preloader found no asset at $path. Add the bank folder to the project assets.');
        }
        provided = true;
        initialize();
    }

    /** Shows the failure message. Override it for a custom look. **/
    function showFailure():Void {
        failureText = new TextField();
        failureText.defaultTextFormat = new TextFormat(null, 14, 0xffffff);
        failureText.width = openfl.Lib.current.stage.stageWidth;
        failureText.y = openfl.Lib.current.stage.stageHeight * 0.75;
        failureText.selectable = false;
        failureText.text = "FMOD could not load its banks. The game starts without audio.";
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
