package;

import h2d.Object;
import h2d.Text;
import fmodtest.TestHost;
import haxefmod.studio.StudioSystem;
import haxefmod.heaps.FmodHeapsBankLoader;
import haxefmod.heaps.FmodHeapsSetup;
import haxefmod.heaps.FmodHeapsUpdater;
import hxd.Event;

/** The Heaps side of the shared test scenarios. */
class HeapsTestHost implements TestHost {
    public var root(default, null):Object;
    var label:Text;

    public function new(root:Object) {
        this.root = root;
    }

    public function setStatus(text:String):Void {
        if (label == null) {
            label = new Text(hxd.res.DefaultFont.get(), root);
            label.textAlign = Center;
            label.maxWidth = 320;
            label.x = 160;
            label.y = 120 - 6;
        }
        label.text = text;
    }

    public function exit(code:Int):Void {
        #if sys
        Sys.exit(code);
        #end
    }

    public function setupInit():Void {
        FmodHeapsSetup.init();
    }

    public function checkSetupReinit(check:String->Bool->String->Void):Void {
        FmodHeapsSetup.init();
        var installs = FmodHeapsUpdater.installCount;
        check("hardening_setup_reinit_single_updater", installs == 1 && FmodHeapsUpdater.isInstalled(),
            'count=$installs installed=${FmodHeapsUpdater.isInstalled()}');
        // A removeHook then init from inside the updater's own frame keeps
        // the hook, and the frame runs FmodManager.Update once. The re-arm
        // waits for the next loop turn, so one frame() call covers it. The
        // frame hook runs inside FmodManager.Update and counts its runs.
        var previousHook = haxefmod.studio.CallbackDispatcher.frameHook;
        var runs = 0;
        haxefmod.studio.CallbackDispatcher.frameHook = function() {
            runs++;
            if (runs == 1) {
                FmodHeapsUpdater.removeHook();
                FmodHeapsUpdater.init();
            }
        };
        @:privateAccess FmodHeapsUpdater.frame();
        haxefmod.studio.CallbackDispatcher.frameHook = previousHook;
        check("hardening_setup_remove_reinit_inside_tick", runs == 1 && FmodHeapsUpdater.isInstalled(),
            'runs=$runs installed=${FmodHeapsUpdater.isInstalled()}');
    }

    public function setUpdaterInstalled(installed:Bool):Void {
        if (installed) FmodHeapsUpdater.init() else FmodHeapsUpdater.removeHook();
    }

    // Heaps ships no global volume control, so the FMOD master bus is the
    // one control. The checks drive it and read each change back. The
    // focus-mute wiring the setup installs is checked through
    // setFocusThroughEngine instead.
    public function checkVolumeControls(check:String->Bool->String->Void):Void {
        FmodManager.SetMasterVolume(0.5);
        check("heaps_master_volume", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        // A bus mute is a Studio command, so flush before reading it back
        FmodManager.SetMasterMute(true);
        StudioSystem.flushCommands();
        check("heaps_master_mute", FmodManager.IsMasterMuted(), "");
        check("heaps_master_volume_kept", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        FmodManager.SetMasterMute(false);
        StudioSystem.flushCommands();
        check("heaps_master_mute_cleared", !FmodManager.IsMasterMuted(), "");
        FmodManager.SetMasterVolume(1.0);
        check("heaps_master_volume_restored", Math.abs(FmodManager.GetMasterVolume() - 1.0) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
    }

    public function setFocusThroughEngine(focused:Bool):Void {
        hxd.Window.getInstance().event(new Event(focused ? EFocus : EFocusLost));
    }

    public function addBankLoader(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool):Void {
        new FmodHeapsBankLoader(bankFiles, onLoaded, onError, async);
    }
}
