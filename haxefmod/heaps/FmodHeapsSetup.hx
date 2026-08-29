package haxefmod.heaps;

import haxefmod.FmodManager;
import haxefmod.runtime.FmodSettings;
import hxd.Event;

/**
    One-call FMOD setup for Heaps games. Call init() once from your
    hxd.App's init():

    - initializes FMOD (settings pass through to FmodManager.Initialize;
      first initialization wins, so settings are ignored if something
      already initialized FMOD)
    - installs FmodHeapsUpdater so FmodManager.Update() runs every frame
    - mutes the FMOD master output while the window is unfocused, through
      the window's focus events

    Heaps has no global volume control of its own, so the FMOD master bus
    is the volume: FmodManager.SetBusVolumeMaster and SetBusMuteMaster.

    Calling init() again is safe and keeps a single focus wiring.
**/
class FmodHeapsSetup {
    public static function init(?settings:FmodSettings):Void {
        FmodManager.Initialize(settings);
        FmodHeapsUpdater.init();
        var window = hxd.Window.getInstance();
        // Remove-then-add keeps exactly one wiring across repeated init
        // calls
        window.removeEventTarget(onWindowEvent);
        window.addEventTarget(onWindowEvent);
    }

    static function onWindowEvent(event:Event):Void {
        switch (event.kind) {
            case EFocus: FmodManager.SetWindowFocused(true);
            case EFocusLost: FmodManager.SetWindowFocused(false);
            default:
        }
    }
}
