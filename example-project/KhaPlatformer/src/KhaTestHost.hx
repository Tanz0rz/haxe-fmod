package;

import kha.graphics2.Graphics;
import fmodtest.TestHost;
import haxefmod.kha.FmodKhaBankLoader;
import haxefmod.kha.FmodKhaSetup;
import haxefmod.kha.FmodKhaUpdater;

/** The Kha side of the shared test scenarios. */
class KhaTestHost implements TestHost {
    /** The last status text. Kha ships no default font, so it is drawn as a bar. */
    public var status(default, null):String = "";

    public function new() {}

    public function setStatus(text:String):Void {
        status = text;
    }

    public function render(g2:Graphics):Void {
        g2.color = status.indexOf("failed") != -1 ? 0xffff8080 : 0xffffffff;
        g2.fillRect(120, 118, 80, 4);
    }

    public function exit(code:Int):Void {
        #if sys
        Sys.exit(code);
        #end
    }

    public function setupInit():Void {
        FmodKhaSetup.init();
    }

    public function checkSetupReinit(check:String->Bool->String->Void):Void {
        FmodKhaSetup.init();
        var installs = FmodKhaUpdater.installCount;
        check("hardening_setup_reinit_single_updater", installs == 1, 'count=$installs');
    }

    // Kha has no engine-level volume control to bridge, so the checks
    // drive the master bus through FmodManager and read it back
    public function checkVolumeBridge(check:String->Bool->String->Void):Void {
        FmodManager.SetBusVolumeMaster(0.5);
        check("kha_bridge_volume", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FmodManager.SetBusMuteMaster(true);
        check("kha_bridge_mute", FmodManager.GetBusMuteMaster(), "");
        check("kha_bridge_volume_kept", Math.abs(FmodManager.GetBusVolumeMaster() - 0.5) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
        FmodManager.SetBusMuteMaster(false);
        check("kha_bridge_mute_cleared", !FmodManager.GetBusMuteMaster(), "");
        FmodManager.SetBusVolumeMaster(1.0);
        check("kha_bridge_volume_restored", Math.abs(FmodManager.GetBusVolumeMaster() - 1.0) < 0.001,
            'value=${FmodManager.GetBusVolumeMaster()}');
    }

    // The application-state entry points the backends call are private,
    // and they are exactly the path a real focus change takes
    public function setFocusThroughEngine(focused:Bool):Void {
        if (focused) @:privateAccess kha.System.foreground() else @:privateAccess kha.System.background();
    }

    public function addBankLoader(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool):Void {
        new FmodKhaBankLoader(bankFiles, onLoaded, onError, async);
    }
}
