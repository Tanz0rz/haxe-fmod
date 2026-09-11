package haxefmod.flixel;

import flixel.FlxG;
import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;

/**
    One-call FMOD setup for HaxeFlixel games. Call init() once from the
    first state's create(). init() does the following.

    It initializes FMOD. Settings pass through to FmodManager.Initialize.
    The first initialization wins. Settings are ignored if something
    already initialized FMOD, like an HTML5 preloader.

    It adds FmodFlxUpdater so FmodManager.Update() runs after every frame.

    It reports window focus changes to FmodRuntime.setWindowFocused, so
    the muteWhenUnfocused setting takes effect.

    It routes FlxG.sound volume and mute changes to the FMOD master bus.
    The plus, minus, and zero keys and the sound tray drive those changes.

    It silences the sound tray's own beep so all audio comes from FMOD.

    The sound tray stays visible as the volume UI. To bring its beep
    back, set FlxG.sound.soundTray.silent = false after init(). To hide
    the tray entirely, set FlxG.sound.soundTrayEnabled = false.

    Requires flixel 5.9.0 or later (FlxG.sound.onVolumeChange). Calling
    init() again is safe and rewires a recreated FlxGame.
**/
class FmodFlxSetup {
    #if FLX_SOUND_SYSTEM
    static var volumeHandler:Float->Void = _ -> applyVolume();
    static var readyHandler:Void->Void = () -> applyVolume();
    #end

    static var focusGainedHandler:Void->Void = () -> FmodRuntime.setWindowFocused(true);
    static var focusLostHandler:Void->Void = () -> FmodRuntime.setWindowFocused(false);

    /** Initializes FMOD and wires the updater, focus, and volume hooks. **/
    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodFlxUpdater.init();

        // Keep FMOD's focus state in sync so the master output mutes while
        // the window is backgrounded. That means no audio to an unfocused
        // window, and no burst on refocus. add() keeps a single wiring
        // across repeated init calls. It is also safe from inside a
        // dispatch, where a remove is deferred past the add.
        FlxG.signals.focusGained.add(focusGainedHandler);
        FlxG.signals.focusLost.add(focusLostHandler);

        #if FLX_SOUND_SYSTEM
        #if FLX_SOUND_TRAY
        if (FlxG.sound.soundTray != null) {
            FlxG.sound.soundTray.silent = true;
        }
        #end
        // add() keeps exactly one wiring across repeated init calls
        FlxG.sound.onVolumeChange.add(volumeHandler);
        applyVolume();
        // HTML5 initializes asynchronously, so the volume and mute applied
        // above can land before the master bus exists. Replaying once ready
        // makes a persisted volume (or mute) stick on every target.
        haxefmod.runtime.FmodRuntime.onceReady(readyHandler);
        #end
    }

    #if FLX_SOUND_SYSTEM
    // Reads muted and volume from the front end instead of using the
    // dispatched value. Mute then maps to the bus mute flag, and the
    // volume survives a mute/unmute round trip.
    static function applyVolume():Void {
        FmodManager.SetMasterVolume(FlxG.sound.volume);
        FmodManager.SetMasterMute(FlxG.sound.muted);
    }
    #end
}
