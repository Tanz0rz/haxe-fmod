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
    var _awaitingAsync:Bool = false;
    var _asyncFrames:Int = 0;
    var _asyncMissing:haxefmod.studio.Bank;
    var _asyncDuplicate:haxefmod.studio.Bank;
    var _baseline:Int = 0;

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

        #if js
        // On html5 the shim preloads the master banks during its async init
        // (outside the registry), so the refcount/unload flow does not apply.
        // What CAN only be validated in a real browser is the async
        // fetch-into-virtual-filesystem loading path, so this target tests
        // that instead: both error legs exercise the full fetch machinery
        // (the happy path needs a bank that is not preloaded).
        // Warm the description cache first (lookups allocate one persistent
        // deduped handle), then capture the leak baseline: the probe
        // instance is released, so only the two async placeholders below
        // may outlive this create() call.
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        _baseline = StudioSystem.liveHandleCount();
        var probe:EventInstance = FmodRuntime.createInstance(FmodEvents.MusicMainLevel);
        check("event_resolves", !probe.isNull(), "");
        probe.release();
        _asyncMissing = FmodRuntime.banks.loadAsync("assets/fmod/Desktop/DoesNotExist.bank");
        check("async_missing_handle", !_asyncMissing.isNull(), "");
        _asyncDuplicate = FmodRuntime.banks.loadAsync(masterPath);
        check("async_duplicate_handle", !_asyncDuplicate.isNull(), "");
        _awaitingAsync = true;
        label.text = "BANK_TEST waiting on async fetches";
        return;
        #end

        // The default init registered both banks with one reference each
        check("master_loaded", FmodRuntime.banks.isLoaded(masterPath), "");
        check("master_refcount", FmodRuntime.banks.refCount(masterPath) == 1,
            'refs=${FmodRuntime.banks.refCount(masterPath)}');

        // Warm the event description cache, then capture the leak baseline.
        // Every handle allocated below is either released (the probe
        // instance) or freed and re-allocated in equal number (the two bank
        // handles across the unload/reload cycle), so the final live count
        // must match. The warmed description handle survives the unload as
        // a live-but-FMOD-invalid slot, which is exactly why it must be in
        // the baseline.
        StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        var baseline = StudioSystem.liveHandleCount();

        // Refcount up and down leaves the bank loaded
        FmodRuntime.banks.load(masterPath);
        check("refcount_bump", FmodRuntime.banks.refCount(masterPath) == 2, "");
        check("unload_keeps_bank", !FmodRuntime.banks.unload(masterPath), "");
        check("still_loaded", FmodRuntime.banks.isLoaded(masterPath), "");

        // Play an event from the bank to prove content resolves
        var instance:EventInstance = FmodRuntime.createInstance(FmodEvents.MusicMainLevel);
        check("event_resolves", !instance.isNull(), "");
        check("event_starts", instance.start().isOk(), "");
        instance.stop(IMMEDIATE);
        instance.release();

        // Real unload: drop the last references
        check("unload_master", FmodRuntime.banks.unload(masterPath), "");
        check("unload_strings", FmodRuntime.banks.unload(stringsPath), "");
        check("master_gone", !FmodRuntime.banks.isLoaded(masterPath), "");

        // Bank unloads process asynchronously; block until FMOD applies them
        StudioSystem.flushCommands();

        // Events must stop resolving after their bank is unloaded
        var missing = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("event_not_found_after_unload", missing.isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');

        // Reload so shutdown paths in the harness stay happy, then report
        // handle accounting (informational: lookups cache handles)
        FmodRuntime.banks.load(masterPath);
        FmodRuntime.banks.load(stringsPath);
        log('BANK_TEST: live_handles info=${StudioSystem.liveHandleCount()}');
        check("no_handle_leaks", StudioSystem.liveHandleCount() == baseline,
            'baseline=$baseline now=${StudioSystem.liveHandleCount()}');

        log('BANK_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        label.text = 'BANK_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();

        if (_awaitingAsync) {
            _asyncFrames++;
            var missingState = _asyncMissing.getLoadingState();
            var duplicateState = _asyncDuplicate.getLoadingState();
            var settled = missingState != FmodLoadingState.LOADING && duplicateState != FmodLoadingState.LOADING;
            if (settled || _asyncFrames > 600) {
                _awaitingAsync = false;
                // A missing URL must surface as ERROR, never hang or crash
                check("async_missing_errors", missingState == FmodLoadingState.ERROR,
                    'state=${(missingState : Int)}');
                // The fetch of an already-loaded bank succeeds over the
                // network, then the load itself reports the duplicate
                check("async_duplicate_errors", duplicateState == FmodLoadingState.ERROR,
                    'state=${(duplicateState : Int)}');
                // The two async placeholders persist by design (errored
                // handles keep reporting ERROR instead of being freed)
                check("no_handle_leaks", StudioSystem.liveHandleCount() == _baseline + 2,
                    'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');
                log('BANK_TEST: COMPLETE passed=$_passCount failed=$_failCount');
                _done = true;
            }
            return;
        }

        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            #if sys
            Sys.exit(_failCount > 0 ? 1 : 0);
            #end
        }
    }
}
