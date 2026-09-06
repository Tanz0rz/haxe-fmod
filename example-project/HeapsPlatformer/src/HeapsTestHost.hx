package;

import h2d.Object;
import h2d.Text;
import fmodtest.TestHost;
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
        check("hardening_setup_reinit_single_updater", installs == 1, 'count=$installs');
    }

    // Heaps has no engine-level volume control to bridge, so the checks
    // drive the master bus through FmodManager and read it back
    public function checkVolumeBridge(check:String->Bool->String->Void):Void {
        FmodManager.SetBusVolumeMaster(0.5);
        check("heaps_bridge_volume", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FmodManager.SetBusMuteMaster(true);
        check("heaps_bridge_mute", FmodManager.GetBusMuteMaster(), "");
        check("heaps_bridge_volume_kept", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FmodManager.SetBusMuteMaster(false);
        check("heaps_bridge_mute_cleared", !FmodManager.GetBusMuteMaster(), "");
        FmodManager.SetBusVolumeMaster(1.0);
        check("heaps_bridge_volume_restored", Math.abs(FmodManager.GetBusVolumeMaster() - 1.0) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
    }

    public function setFocusThroughEngine(focused:Bool):Void {
        hxd.Window.getInstance().event(new Event(focused ? EFocus : EFocusLost));
    }

    public function addBankLoader(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool):Void {
        new FmodHeapsBankLoader(bankFiles, onLoaded, onError, async);
    }
}
