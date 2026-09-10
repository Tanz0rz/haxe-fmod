package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import fmodtest.TestHost;
import haxefmod.flixel.FmodFlxBankLoader;
import haxefmod.flixel.FmodFlxSetup;
import haxefmod.flixel.FmodFlxUpdater;

/** The flixel side of the shared test scenarios. */
class FlxTestHost implements TestHost {
    var state:FlxState;
    var label:FlxText;

    public function new(state:FlxState) {
        this.state = state;
    }

    public function setStatus(text:String):Void {
        if (label == null) {
            label = new FlxText(0, 0, FlxG.width, text);
            label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
            label.y = (FlxG.height / 2) - (label.height / 2);
            state.add(label);
        }
        label.text = text;
    }

    public function exit(code:Int):Void {
        #if sys
        Sys.exit(code);
        #end
    }

    public function setupInit():Void {
        FmodFlxSetup.init();
    }

    public function checkSetupReinit(check:String->Bool->String->Void):Void {
        FmodFlxSetup.init();
        // init() removes its postUpdate handler before adding it back, so a
        // second call leaves the same single hook installed
        check("hardening_setup_reinit_single_updater", FmodFlxUpdater.isInstalled(),
            'installed=${FmodFlxUpdater.isInstalled()} (one postUpdate hook)');
    }

    public function checkVolumeControls(check:String->Bool->String->Void):Void {
        FlxG.sound.volume = 0.5;
        check("flx_bridge_volume", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        FlxG.sound.toggleMuted();
        check("flx_bridge_mute", FmodManager.IsMasterMuted(), "");
        // Volume is carried by the mute flag, so it must survive the mute
        check("flx_bridge_volume_kept", Math.abs(FmodManager.GetMasterVolume() - 0.5) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
        FlxG.sound.toggleMuted();
        check("flx_bridge_mute_cleared", !FmodManager.IsMasterMuted(), "");
        FlxG.sound.volume = 1.0;
        check("flx_bridge_volume_restored", Math.abs(FmodManager.GetMasterVolume() - 1.0) < 0.001,
            'value=${FmodManager.GetMasterVolume()}');
    }

    public function setFocusThroughEngine(focused:Bool):Void {
        if (focused) FlxG.signals.focusGained.dispatch() else FlxG.signals.focusLost.dispatch();
    }

    public function addBankLoader(bankFiles:Array<String>, ?onLoaded:Void->Void, ?onError:Void->Void, async:Bool):Void {
        state.add(new FmodFlxBankLoader(bankFiles, onLoaded, onError, async));
    }
}
