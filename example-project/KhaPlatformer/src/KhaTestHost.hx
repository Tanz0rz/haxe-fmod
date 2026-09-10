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

    // Kha ships no global volume control, so the FMOD master bus is the
    // one control. The checks drive it and read each change back. The
    // focus-mute wiring the setup installs is checked through
    // setFocusThroughEngine instead.
    public function checkVolumeControls(check:String->Bool->String->Void):Void {
        FmodManager.SetMasterVolume(0.5);
        check("kha_master_volume", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        FmodManager.SetMasterMute(true);
        check("kha_master_mute", FmodManager.IsMasterMuted(), "");
        check("kha_master_volume_kept", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        FmodManager.SetMasterMute(false);
        check("kha_master_mute_cleared", !FmodManager.IsMasterMuted(), "");
        FmodManager.SetMasterVolume(1.0);
        check("kha_master_volume_restored", Math.abs(FmodManager.GetMasterVolume() - 1.0) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
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
