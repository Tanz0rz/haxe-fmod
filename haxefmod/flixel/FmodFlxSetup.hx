package haxefmod.flixel;

import flixel.FlxG;
import haxefmod.FmodManager;
import haxefmod.runtime.FmodSettings;

/**
    One-call FMOD setup for HaxeFlixel games. Call init() once from the
    first state's create():

    - initializes FMOD (settings pass through to FmodManager.Initialize;
      first initialization wins, so settings are ignored if something
      already initialized FMOD, like an html5 preloader)
    - adds FmodFlxUpdater so FmodManager.Update() runs every frame
    - routes FlxG.sound volume and mute changes (the plus, minus, and
      zero keys and the sound tray) to the FMOD master bus
    - silences the sound tray's own beep so all audio comes from FMOD

    The sound tray stays visible as the volume UI. To bring its beep
    back, set FlxG.sound.soundTray.silent = false after init(). To hide
    the tray entirely, set FlxG.sound.soundTrayEnabled = false.

    Requires flixel 5.9.0 or newer (FlxG.sound.onVolumeChange). Calling
    init() again is safe and rewires a recreated FlxGame.
**/
class FmodFlxSetup {
    #if FLX_SOUND_SYSTEM
    static var volumeHandler:Float->Void = _ -> applyVolume();
    #end

    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodFlxUpdater.init();

        #if FLX_SOUND_SYSTEM
        #if FLX_SOUND_TRAY
        if (FlxG.sound.soundTray != null) {
            FlxG.sound.soundTray.silent = true;
        }
        #end
        // Remove-then-add keeps exactly one wiring across repeated init
        // calls and across a destroyed-and-recreated FlxGame (fresh signal)
        FlxG.sound.onVolumeChange.remove(volumeHandler);
        FlxG.sound.onVolumeChange.add(volumeHandler);
        applyVolume();
        #end
    }

    #if FLX_SOUND_SYSTEM
    // Reads muted and volume from the front end instead of using the
    // dispatched value, so mute maps to the bus mute flag and the volume
    // survives a mute/unmute round trip
    static function applyVolume():Void {
        FmodManager.SetBusVolumeMaster(FlxG.sound.volume);
        FmodManager.SetBusMuteMaster(FlxG.sound.muted);
    }
    #end
}
