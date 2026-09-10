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

    var assetsLoaded:Bool = false;
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
        // arrive in onLoaded, and the runtime waits for them.
        initialize();
        #end
    }

    function initialize():Void {
        var s = settings();
        if (s == null) s = {};
        s.banksProvided = true;
        FmodManager.Initialize(s);
    }

    /**
        Runs when lime has loaded the assets. The default banks are among
        them, so their bytes go to the runtime here. Completion waits for
        FMOD.
    **/
    override public function onLoaded():Void {
        super.onLoaded();
        _loaded = false;
        assetsLoaded = true;
        #if js
        provideBanks();
        #else
        // Native init loads the default banks inside Initialize, so the
        // bytes go in first
        provideBanks();
        initialize();
        #end
    }

    /** Hands every bank in autoLoadBanks that lime loaded to the runtime. **/
    function provideBanks():Void {
        var s = settings();
        var resolved = FmodRuntime.settings();
        if (resolved == null) resolved = haxefmod.runtime.FmodSettingsResolver.resolve(s);
        for (fileName in resolved.autoLoadBanks) {
            var path = FmodRuntime.bankPath(fileName, resolved.bankFolder);
            var bytes = Assets.exists(path) ? Assets.getBytes(path) : null;
            if (bytes != null) {
                FmodRuntime.provideBank(fileName, bytes);
            } else {
                trace('Error: FMOD - the preloader found no asset at $path. Add the bank folder to the project assets.');
            }
        }
    }

    override public function update(percent:Float):Void {
        super.update(percent);
        if (!assetsLoaded) return;
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
