package haxefmod.kha;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodRuntime;
import haxefmod.runtime.FmodSettings;
import kha.System;

/**
    One-call FMOD setup for Kha games. Call init() once from the
    System.start callback. init() does the following.

    It initializes FMOD. Settings pass through to FmodManager.Initialize.
    The first initialization wins. Settings are ignored if something
    already initialized FMOD.

    It installs FmodKhaUpdater so FmodManager.Update() runs every frame.

    It mutes the FMOD master output while the application is paused or
    in the background, through System.notifyOnApplicationState.

    Kha has no global volume control of its own, so the FMOD master bus
    is the volume. Use FmodManager.SetMasterVolume and SetMasterMute.

    Calling init() again is safe and keeps a single focus wiring.
**/
class FmodKhaSetup {
    static var wired:Bool = false;

    /** Initializes FMOD and wires the Kha updater and application state hooks. **/
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
        FmodRuntime.setWindowFocused(true);
    }

    static function onBackground():Void {
        FmodRuntime.setWindowFocused(false);
    }
}
