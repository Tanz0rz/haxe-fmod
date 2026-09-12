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
        // the hook. The frame hook runs inside FmodManager.Update and
        // counts its runs. In the browser the frame is driven through
        // browserFrame, and the animation frame requests are counted. The
        // reinstall leaves the re-arm to the running frame, so one request
        // stands after it. On HashLink the re-arm waits for the next loop
        // turn, which the installed flag covers.
        var previousHook = haxefmod.studio.CallbackDispatcher.frameHook;
        var runs = 0;
        haxefmod.studio.CallbackDispatcher.frameHook = function() {
            runs++;
            if (runs == 1) {
                FmodHeapsUpdater.removeHook();
                FmodHeapsUpdater.init();
            }
        };
        #if js
        // This check runs inside a live frame on HTML5 (create() is
        // reached from the updater's own tick). The loop state is saved
        // and the driven frame runs as its own. The request it armed is
        // handed back, so the outer frame arms the one request that stays.
        var arms = 0;
        var window:Dynamic = js.Browser.window;
        var realRequest:Dynamic = window.requestAnimationFrame;
        var savedInFrame = @:privateAccess FmodHeapsUpdater.inFrame;
        var savedRequest = @:privateAccess FmodHeapsUpdater.frameRequest;
        window.requestAnimationFrame = function(cb:Dynamic):Int {
            arms++;
            return realRequest.call(window, cb);
        };
        @:privateAccess FmodHeapsUpdater.inFrame = false;
        var thrown:Dynamic = null;
        try {
            @:privateAccess FmodHeapsUpdater.browserFrame(0.0);
        } catch (e:Dynamic) {
            thrown = e;
        }
        window.requestAnimationFrame = realRequest;
        haxefmod.studio.CallbackDispatcher.frameHook = previousHook;
        if (savedInFrame) {
            js.Browser.window.cancelAnimationFrame(@:privateAccess FmodHeapsUpdater.frameRequest);
            @:privateAccess FmodHeapsUpdater.frameRequest = savedRequest;
            @:privateAccess FmodHeapsUpdater.inFrame = true;
        }
        if (thrown != null) throw thrown;
        check("hardening_setup_remove_reinit_inside_tick",
            runs == 1 && arms == 1 && FmodHeapsUpdater.isInstalled(),
            'runs=$runs arms=$arms installed=${FmodHeapsUpdater.isInstalled()}');
        #else
        // The driven frame runs FmodManager.Update once by construction.
        // The proof here is that the reinstall replaced the event loop
        // handler and left the hook installed. The Kha and flixel hosts
        // drive their loops and catch a doubled tick.
        var before = @:privateAccess FmodHeapsUpdater.eventHandler;
        var thrown:Dynamic = null;
        try {
            @:privateAccess FmodHeapsUpdater.frame();
        } catch (e:Dynamic) {
            thrown = e;
        }
        haxefmod.studio.CallbackDispatcher.frameHook = previousHook;
        if (thrown != null) throw thrown;
        var after = @:privateAccess FmodHeapsUpdater.eventHandler;
        check("hardening_setup_remove_reinit_inside_tick",
            after != null && after != before && FmodHeapsUpdater.isInstalled(),
            'replaced=${after != before} installed=${FmodHeapsUpdater.isInstalled()}');
        #end
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
