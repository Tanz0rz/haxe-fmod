package haxefmod.kha;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodSettings;
import kha.System;

/**
    One-call FMOD setup for Kha games. Call init() once from the
    System.start callback:

    - initializes FMOD (settings pass through to FmodManager.Initialize;
      first initialization wins, so settings are ignored if something
      already initialized FMOD)
    - installs FmodKhaUpdater so FmodManager.Update() runs every frame
    - mutes the FMOD master output while the application is paused or in
      the background, through System.notifyOnApplicationState

    Kha has no global volume control of its own, so the FMOD master bus
    is the volume: FmodManager.SetBusVolumeMaster and SetBusMuteMaster.

    Calling init() again is safe and keeps a single focus wiring.
**/
class FmodKhaSetup {
    static var wired:Bool = false;

    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodKhaUpdater.init();
        // Kha keeps its listeners forever, so wire once
        if (!wired) {
            wired = true;
            System.notifyOnApplicationState(onForeground, onForeground, onBackground, onBackground, null);
        }
    }

    static function onForeground():Void {
        FmodManager.SetWindowFocused(true);
    }

    static function onBackground():Void {
        FmodManager.SetWindowFocused(false);
    }
}
