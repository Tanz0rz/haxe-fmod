package fmodtest;

import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.EventInstance;
import haxefmod.studio.FmodResult;
import haxefmod.studio.StudioSystem;
import haxefmod.studio.Types;

/**
 * CI test scenario for the bank lifecycle: refcounted load, play from the
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
class BankLifecycleScenario implements TestScenario {
    var host:TestHost;

    public function new() {}

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
    var _syncLoaderLoaded:Bool = false;
    var _loaderErrored:Bool = false;

    static inline var MISSING_PATH = "assets/fmod/Desktop/DoesNotExist.bank";
    static inline var ALSO_MISSING_PATH = "assets/fmod/Desktop/AlsoMissing.bank";

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

    public function create(host:TestHost):Void {
        this.host = host;

        host.setStatus("BANK_TEST running");

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

        // Reload through the registry. Native loads synchronously, html5
        // goes back through the fetch pipeline, so the checks continue
        // from update() once both banks report loaded.
        FmodRuntime.banks.load(_masterPath);
        FmodRuntime.banks.load(_stringsPath);
        enterPhase("reload");
    }


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
        // (html5: failed fetch, native: NONBLOCKING open failure), two
        // concurrent loads of one missing path share a placeholder, and
        // the engine's bank loader surfaces both outcomes through callbacks.
        _errBaseline = StudioSystem.liveHandleCount();
        _asyncMissing = FmodRuntime.banks.loadAsync(MISSING_PATH);
        var concurrentA = FmodRuntime.banks.loadAsync(ALSO_MISSING_PATH);
        var concurrentB = FmodRuntime.banks.loadAsync(ALSO_MISSING_PATH);
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

        host.addBankLoader(["Master.bank"], () -> _loaderLoaded = true, null, true);
        // The synchronous mode routes through banks.load (still async
        // under the hood on html5) - the callback contract is identical
        host.addBankLoader(["Master.bank"], () -> _syncLoaderLoaded = true, null, false);
        host.addBankLoader(["DoesNotExist.bank"], null, () -> _loaderErrored = true, true);
        enterPhase("errors");
    }

    function finishErrors():Void {
        // The registry's CURRENT entry is the authority: a settled-ERROR
        // placeholder can legitimately be replaced (and its old handle
        // unloaded) by the loader's retry of the same path
        if (!_asyncMissing.isNull()) {
            check("async_missing_errors",
                FmodRuntime.banks.loadingState(MISSING_PATH) == FmodLoadingState.ERROR,
                'state=${(FmodRuntime.banks.loadingState(MISSING_PATH) : Int)}');
        }
        check("loader_error_surfaced", _loaderErrored, "");
        check("loader_loaded_fired", _loaderLoaded, "");
        check("sync_loader_loaded_fired", _syncLoaderLoaded, "");
        if (!_asyncConcurrent.isNull()) {
            check("async_concurrent_errors",
                FmodRuntime.banks.loadingState(ALSO_MISSING_PATH) == FmodLoadingState.ERROR,
                'state=${(FmodRuntime.banks.loadingState(ALSO_MISSING_PATH) : Int)}');
            // Errored entries persist by design (they keep reporting ERROR
            // instead of being freed). One entry per missing path: the
            // loader's retry either deduped onto the in-flight placeholder
            // or replaced a settled one, releasing the old handle either way
            check("no_error_leg_leaks", StudioSystem.liveHandleCount() == _errBaseline + 2,
                'baseline=$_errBaseline now=${StudioSystem.liveHandleCount()}');
        }

        startExtrasPhase();
    }

    var _extrasPath:String;
    var _extrasBaseline:Int = 0;
    var _bankCountBefore:Int = 0;

    /**
     * The second authored bank end to end: Spatial resolves only while
     * Extras is loaded, the system enumeration reflects it, and unloading
     * reclaims every handle it minted. Jump lives in BOTH banks, which
     * also proves a multi-bank event survives one of its banks unloading.
     */
    function startExtrasPhase():Void {
        _extrasPath = FmodRuntime.bankPath("Extras.bank");
        check("extras_not_loaded_initially", !FmodRuntime.banks.isLoaded(_extrasPath), "");
        check("spatial_missing_before_load", StudioSystem.getEvent(FmodEvents.SFXSpatial).isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        // Jump's description handle survives the Extras unload (the event
        // stays valid through Master), so warm it before the baseline
        StudioSystem.getEvent(FmodEvents.SFXJump);
        _bankCountBefore = StudioSystem.getBankCount();
        _extrasBaseline = StudioSystem.liveHandleCount();
        FmodRuntime.banks.load(_extrasPath);
        enterPhase("extras");
    }

    function finishExtras(loaded:Bool):Void {
        check("extras_loaded", loaded, 'frames=$_phaseFrames');
        check("extras_bank_count_bumped", StudioSystem.getBankCount() == _bankCountBefore + 1,
            'before=$_bankCountBefore now=${StudioSystem.getBankCount()}');
        var bank = FmodRuntime.banks.get(_extrasPath);
        check("extras_bank_valid", !bank.isNull() && bank.isValid(), "");
        if (!bank.isNull()) {
            check("extras_event_count", bank.getEventCount() == 2,
                'count=${bank.getEventCount()}');
            var events = bank.getEventList();
            var sawSpatial = false;
            for (e in events) if (e.getPath() == FmodEvents.SFXSpatial) sawSpatial = true;
            check("extras_event_list", events.length == 2 && sawSpatial,
                'count=${events.length} sawSpatial=$sawSpatial');
        }

        var desc = StudioSystem.getEvent(FmodEvents.SFXSpatial);
        check("spatial_resolves_after_load", !desc.isNull(), "");
        check("spatial_is_3d", desc.is3D(), "");
        check("spatial_doppler_enabled", desc.isDopplerEnabled(), "");
        // The macro range, not the spatializer override (FMOD reports the
        // event macros here)
        var distances = desc.getMinMaxDistance();
        check("spatial_distance_range", distances != null
            && distances.min < distances.max && distances.max > 0,
            distances == null ? "" : 'min=${distances.min} max=${distances.max}');

        var instance = desc.createInstance();
        check("spatial_instance_starts", !instance.isNull() && instance.start().isOk(), "");
        check("spatial_instance_live",
            instance.getPlaybackState() != FmodPlaybackState.STOPPED,
            'state=${(instance.getPlaybackState() : Int)}');
        instance.stop(IMMEDIATE);
        instance.release();
        StudioSystem.flushCommands();
        FmodManager.Update();

        check("extras_unload", FmodRuntime.banks.unload(_extrasPath), "");
        StudioSystem.flushCommands();
        check("spatial_missing_after_unload", StudioSystem.getEvent(FmodEvents.SFXSpatial).isNull(),
            'result=${StudioSystem.lastResult().toString()}');
        check("jump_survives_extras_unload", !StudioSystem.getEvent(FmodEvents.SFXJump).isNull(), "");
        check("extras_bank_count_restored", StudioSystem.getBankCount() == _bankCountBefore,
            'now=${StudioSystem.getBankCount()}');
        FmodManager.Update();
        check("no_extras_leaks", StudioSystem.liveHandleCount() == _extrasBaseline,
            'baseline=$_extrasBaseline now=${StudioSystem.liveHandleCount()}');

        log('BANK_TEST: COMPLETE passed=$_passCount failed=$_failCount');
        host.setStatus('BANK_TEST complete: $_passCount passed, $_failCount failed');
        _done = true;
        enterPhase("");
    }

    public function update(elapsed:Float):Void {
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
                || FmodRuntime.banks.loadingState(MISSING_PATH) != FmodLoadingState.LOADING;
            var concurrentSettled = _asyncConcurrent.isNull()
                || FmodRuntime.banks.loadingState(ALSO_MISSING_PATH) != FmodLoadingState.LOADING;
            var loaderSettled = _loaderErrored || _asyncMissing.isNull();
            var syncSettled = _syncLoaderLoaded;
            if ((missingSettled && concurrentSettled && loaderSettled && _loaderLoaded && syncSettled)
                || _phaseFrames > 600) {
                finishErrors();
            }
            return;
        }
        if (_phase == "extras") {
            _phaseFrames++;
            var ready = FmodRuntime.banks.isLoaded(_extrasPath);
            if (ready || _phaseFrames > 600) {
                finishExtras(ready);
            }
            return;
        }

        if (!_done) return;

        _framesWaited++;
        if (_framesWaited > 30) {
            host.exit(_failCount > 0 ? 1 : 0);
        }
    }
}
