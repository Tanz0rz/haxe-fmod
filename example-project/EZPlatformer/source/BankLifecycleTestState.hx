package;

import flixel.FlxG;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test state for the bank lifecycle: refcounted load, play from the
 * loaded bank, real unload, and lookup failure after unload. Logs one
 * "BANK_TEST:" line per check; CI gates on "BANK_TEST: COMPLETE" with no
 * "pass=false".
 *
 * The default init auto-loads Master + strings through the registry, so
 * this state exercises refcounts on those, then unloads everything and
 * proves events stop resolving.
 *
 * Select via HAXEFMOD_TEST_STATE=bank-test (native) or ?test=bank-test (HTML5).
 */
class BankLifecycleTestState extends FlxState {
    var _failCount:Int = 0;
    var _passCount:Int = 0;
    var _done:Bool = false;
    var _framesWaited:Int = 0;

    static inline function log(message:String):Void {
        #if js
        js.Browser.console.log(message);
        #else
        trace(message);
        #end
    }

    function check(name:String, pass:Bool, detail:String):Void {
        if (pass) _passCount++ else _failCount++;
        log('BANK_TEST: $name pass=$pass $detail');
    }

    override public function create():Void {
        super.create();

        var label = new FlxText(0, 0, FlxG.width, "BANK_TEST running");
        label.setFormat(null, 16, FlxColor.WHITE, FlxTextAlign.CENTER, NONE, FlxColor.BLACK);
        label.y = (FlxG.height / 2) - (label.height / 2);
        add(label);

        log("BANK_TEST: Starting");

        var masterPath = FmodRuntime.bankPath("Master.bank");
        var stringsPath = FmodRuntime.bankPath("Master.strings.bank");

        // The default init registered both banks with one reference each
        check("master_loaded", FmodRuntime.banks.isLoaded(masterPath), "");
        check("master_refcount", FmodRuntime.banks.refCount(masterPath) == 1,
            'refs=${FmodRuntime.banks.refCount(masterPath)}');

        // Refcount up and down leaves the bank loaded
        FmodRuntime.banks.load(masterPath);
        check("refcount_bump", FmodRuntime.banks.refCount(masterPath) == 2, "");
        check("unload_keeps_bank", !FmodRuntime.banks.unload(masterPath), "");
        check("still_loaded", FmodRuntime.banks.isLoaded(masterPath), "");

        // Play an event from the bank to prove content resolves
        var instance:EventInstance = FmodRuntime.createInstance(FmodSongs.MainLevel);
        check("event_resolves", !instance.isNull(), "");
        check("event_starts", instance.start().isOk(), "");
        instance.stop(IMMEDIATE);
        instance.release();

        // Real unload: drop the last references
        check("unload_master", FmodRuntime.banks.unload(masterPath), "");
        check("unload_strings", FmodRuntime.banks.unload(stringsPath), "");
        check("master_gone", !FmodRuntime.banks.isLoaded(masterPath), "");

        // Events must stop resolving after their bank is unloaded
        var missing = StudioSystem.getEvent(FmodSongs.MainLevel);
        check("event_not_found_after_unload", missing.isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');

        // Reload so shutdown paths in the harness stay happy, then report
        // handle accounting (informational: lookups cache handles)
        FmodRuntime.banks.load(masterPath);
        FmodRuntime.banks.load(stringsPath);
        log('BANK_TEST: live_handles info=${StudioSystem.liveHandleCount()}');

        log('BANK_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'BANK_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();
        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
