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
**/
class FmodHeapsSetup {
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
