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
 * "BANK_TEST:" line per check. CI gates on "BANK_TEST: COMPLETE" with no
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
    var _phase:String = "";
    var _phaseFrames:Int = 0;
    var _masterPath:String;
    var _stringsPath:String;
    var _warmed:Int = 0;
    var _baseline:Int = 0;
    var _errBaseline:Int = 0;
    var _asyncMissing:haxefmod.studio.Bank;
    var _asyncConcurrent:haxefmod.studio.Bank;
    var _loaderLoaded:Bool = false;
    var _loaderErrored:Bool = false;

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
        _label = label;

        log("BANK_TEST: Starting");

        _masterPath = FmodRuntime.bankPath("Master.bank");
        _stringsPath = FmodRuntime.bankPath("Master.strings.bank");

        // The default init registered both banks through the registry with
        // one reference each. On html5 they arrived through the async
        // fetch pipeline before IsInitialized let this state start, so the
        // exact same flow holds on every target.
        check("master_loaded", FmodRuntime.banks.isLoaded(_masterPath), "");
        check("master_refcount", FmodRuntime.banks.refCount(_masterPath) == 1,
            'refs=${FmodRuntime.banks.refCount(_masterPath)}');

        // A second load of a registry-owned bank shares the entry instead
        // of racing a duplicate load (or erroring, as the old html5 shim
        // ownership forced)
        var dup = FmodRuntime.banks.loadAsync(_masterPath);
        check("duplicate_load_shares_entry",
            (dup : Int) == (FmodRuntime.banks.get(_masterPath) : Int)
            && FmodRuntime.banks.refCount(_masterPath) == 2,
            'refs=${FmodRuntime.banks.refCount(_masterPath)}');
        FmodRuntime.banks.unload(_masterPath);

        // Warm the event description cache, then capture the leak baseline.
        _warmed = (StudioSystem.getEvent(FmodEvents.MusicMainLevel) : Int);
        _baseline = StudioSystem.liveHandleCount();

        // Refcount up and down leaves the bank loaded
        FmodRuntime.banks.load(_masterPath);
        check("refcount_bump", FmodRuntime.banks.refCount(_masterPath) == 2, "");
        check("unload_keeps_bank", !FmodRuntime.banks.unload(_masterPath), "");
        check("still_loaded", FmodRuntime.banks.isLoaded(_masterPath), "");

        // Play an event from the bank to prove content resolves
        var instance:EventInstance = FmodRuntime.createInstance(FmodEvents.MusicMainLevel);
        check("event_resolves", !instance.isNull(), "");
        check("event_starts", instance.start().isOk(), "");
        instance.stop(IMMEDIATE);
        instance.release();

        // Real unload: drop the last references
        check("unload_master", FmodRuntime.banks.unload(_masterPath), "");
        check("unload_strings", FmodRuntime.banks.unload(_stringsPath), "");
        check("master_gone", !FmodRuntime.banks.isLoaded(_masterPath), "");

        // Bank unloads process asynchronously. Block until FMOD applies them
        StudioSystem.flushCommands();

        // Events must stop resolving after their bank is unloaded, and the
        // unload sweep must have reclaimed the warmed description handle
        // along with the two bank handles
        var missing = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("event_not_found_after_unload", missing.isNull(),
            'lastResult=${StudioSystem.lastResult().toString()}');
        check("unload_reclaims_lookup_handles", StudioSystem.liveHandleCount() == _baseline - 3,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');

        // Reload through the registry. Native loads synchronously; html5
        // goes back through the fetch pipeline, so the checks continue
        // from update() once both banks report loaded.
        FmodRuntime.banks.load(_masterPath);
        FmodRuntime.banks.load(_stringsPath);
        enterPhase("reload");
    }

    var _label:FlxText;

    function enterPhase(phase:String):Void {
        _phase = phase;
        _phaseFrames = 0;
    }

    function finishReload():Void {
        // The fresh lookup must return a live, working handle even when
        // FMOD reuses the old object's address (the stale-slot aliasing
        // regression), and it must be a new handle because the sweep
        // bumped the old slot's generation
        var reloaded = StudioSystem.getEvent(FmodEvents.MusicMainLevel);
        check("event_resolves_after_reload", !reloaded.isNull() && reloaded.isValid(), "");
        check("reloaded_handle_is_fresh", (reloaded : Int) != _warmed,
            'warmed=$_warmed reloaded=${(reloaded : Int)}');
        check("no_handle_leaks", StudioSystem.liveHandleCount() == _baseline,
            'baseline=$_baseline now=${StudioSystem.liveHandleCount()}');

        // Error legs: a missing bank must settle in ERROR on every target
        // (html5: failed fetch; native: NONBLOCKING open failure), two
        // concurrent loads of one missing path share a placeholder, and
        // the flixel loader surfaces both outcomes through callbacks.
        _errBaseline = StudioSystem.liveHandleCount();
        _asyncMissing = FmodRuntime.banks.loadAsync("assets/fmod/Desktop/DoesNotExist.bank");
        var concurrentA = FmodRuntime.banks.loadAsync("assets/fmod/Desktop/AlsoMissing.bank");
        var concurrentB = FmodRuntime.banks.loadAsync("assets/fmod/Desktop/AlsoMissing.bank");
        _asyncConcurrent = concurrentA;
        if (_asyncMissing.isNull()) {
            // A backend may reject the missing file synchronously: that is
            // an acceptable error surface too, with nothing left behind
            check("missing_bank_fails_fast", !StudioSystem.lastResult().isOk(),
                'result=${StudioSystem.lastResult().toString()}');
        }
        check("async_concurrent_shared",
            _asyncConcurrent.isNull() || (concurrentA : Int) == (concurrentB : Int),
            'a=${(concurrentA : Int)} b=${(concurrentB : Int)}');

        var loader = new haxefmod.flixel.FmodFlxBankLoader(["Master.bank"],
            () -> _loaderLoaded = true);
        add(loader);
        var errLoader = new haxefmod.flixel.FmodFlxBankLoader(["DoesNotExist.bank"],
            null, () -> _loaderErrored = true);
        add(errLoader);
        enterPhase("errors");
    }

    function finishErrors():Void {
        if (!_asyncMissing.isNull()) {
            check("async_missing_errors",
                _asyncMissing.getLoadingState() == FmodLoadingState.ERROR,
                'state=${(_asyncMissing.getLoadingState() : Int)}');
            check("loader_error_surfaced", _loaderErrored, "");
        } else {
            // The synchronous-failure backend surfaced the loader error the
            // same way
            check("loader_error_surfaced", _loaderErrored, "");
        }
        check("loader_loaded_fired", _loaderLoaded, "");
        if (!_asyncConcurrent.isNull()) {
            check("async_concurrent_errors",
                _asyncConcurrent.getLoadingState() == FmodLoadingState.ERROR,
                'state=${(_asyncConcurrent.getLoadingState() : Int)}');
            // Errored placeholders persist by design (they keep reporting
            // ERROR instead of being freed); the loader's missing bank
            // deduped onto the first placeholder
            check("no_error_leg_leaks", StudioSystem.liveHandleCount() == _errBaseline + 2,
                'baseline=$_errBaseline now=${StudioSystem.liveHandleCount()}');
        }

        log('BANK_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        _label.text = 'BANK_TEST complete: $_passCount passed, $_failCount failed';
        _done = true;
        enterPhase("");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
        FmodManager.Update();

        if (_phase == "reload") {
            _phaseFrames++;
            var ready = FmodRuntime.banks.isLoaded(_masterPath)
                && FmodRuntime.banks.isLoaded(_stringsPath);
            if (ready || _phaseFrames > 600) {
                check("reload_completed", ready, 'frames=$_phaseFrames');
                finishReload();
            }
            return;
        }
        if (_phase == "errors") {
            _phaseFrames++;
            var missingSettled = _asyncMissing.isNull()
                || _asyncMissing.getLoadingState() != FmodLoadingState.LOADING;
            var concurrentSettled = _asyncConcurrent.isNull()
                || _asyncConcurrent.getLoadingState() != FmodLoadingState.LOADING;
            var loaderSettled = _loaderErrored || _asyncMissing.isNull();
            if ((missingSettled && concurrentSettled && loaderSettled && _loaderLoaded)
                || _phaseFrames > 600) {
                finishErrors();
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
