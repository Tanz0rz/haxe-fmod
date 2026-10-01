package tests.jsruntime;

import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;

/**
 * The html5 initialization contract, driven through the shipped Haxe
 * runtime layer. That layer compiles to js and runs against the real
 * wasm. The tests/js harnesses talk to jaxe.js directly, so they cannot
 * see this layer.
 *
 * RUNTIME_TEST_MODE selects one of three modes before the script loads.
 *
 * Mode ok: autoLoadBanks resolve. isInitialized() flips true only once
 * the banks are usable, and onceReady fires.
 *
 * Mode missing: the banks 404. Each bank settles in ERROR and is
 * reported exactly once. Initialization completes without them, so
 * isInitialized() turns true and initFailed() reports the failure. The
 * onFailed side of a handler pair runs instead of the ready side. A
 * handler with no onFailed still runs.
 *
 * Mode provided: banksProvided is set and the bytes arrive after init,
 * the order an engine preloader uses in the browser. One bank is an
 * HTML error page, the answer a server gives for a missing file.
 * Initialization settles as failed and the onFailed side runs once.
 *
 * Compiled and run by tests/js/runtime-init-test.js.
 */
class RuntimeInitTest {
	static var checksFailed = 0;
	static var traces:Array<String> = [];

	static function check(label:String, pass:Bool, detail:String):Void {
		if (!pass) checksFailed++;
		js.Syntax.code("console.log({0})", 'RUNTIME_INIT_TEST: $label ${pass ? "pass" : "FAIL"} $detail');
	}

	static function finish():Void {
		js.Syntax.code("console.log({0})",
			'RUNTIME_INIT_TEST: ${checksFailed == 0 ? "COMPLETE" : "FAILED"} failures=$checksFailed');
		js.Syntax.code("process.exit({0})", checksFailed == 0 ? 0 : 1);
	}

	public static function main():Void {
		var mode:String = js.Syntax.code("globalThis.RUNTIME_TEST_MODE || 'ok'");
		haxe.Log.trace = function(v, ?pos) traces.push(Std.string(v));

		var folder = mode == "missing" ? "missing/banks" : "assets/fmod/Desktop";
		var readyFired = false;
		var pairReady = false;
		var pairFailed = 0;
		// Every handler records whether the module was up when it ran
		var ranBeforeReady = false;
		var note = function() if (!FmodRuntime.isInitialized()) ranBeforeReady = true;
		FmodRuntime.onceReady(() -> { note(); readyFired = true; });
		FmodRuntime.onceReady(() -> { note(); pairReady = true; }, () -> { note(); pairFailed++; });
		FmodRuntime.init({
			bankFolder: folder,
			autoLoadBanks: ["Master.bank", "Master.strings.bank"],
			banksProvided: mode == "provided",
		});
		check("init_not_ready_synchronously", !FmodRuntime.isInitialized(), "");
		if (mode == "provided") {
			var real:haxe.io.Bytes = haxe.io.Bytes.ofData(js.Syntax.code("globalThis.RUNTIME_TEST_STRINGS_BANK"));
			FmodRuntime.provideBank("Master.bank", haxe.io.Bytes.ofString("<!doctype html><html><body>not found</body></html>"));
			FmodRuntime.provideBank("Master.strings.bank", real);
		}

		var polls = 0;
		var timer:Dynamic = null;
		timer = js.Syntax.code("setInterval({0}, 50)", function() {
			polls++;
			FmodRuntime.update();
			if (mode == "ok") {
				if (FmodRuntime.isInitialized()) {
					js.Syntax.code("clearInterval({0})", timer);
					check("initialized_once_banks_usable", true, 'polls=$polls');
					check("once_ready_fired", readyFired && pairReady, "");
					check("once_ready_not_failed", pairFailed == 0 && !FmodRuntime.initFailed(), "");
					check("handlers_ran_after_ready", !ranBeforeReady, "");
					check("banks_loaded", FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Master.bank")), "");
					finish();
				} else if (polls > 300) {
					js.Syntax.code("clearInterval({0})", timer);
					check("initialized_once_banks_usable", false, "timed out");
					finish();
				}
			} else if (mode == "refused" || mode == "staggered") {
				if (FmodRuntime.initSettled() || polls > 200) {
					js.Syntax.code("clearInterval({0})", timer);
					var warns = traces.filter(t -> t.indexOf("failed to load") >= 0 || t.indexOf("could not start loading") >= 0);
					check(mode + "_settles", FmodRuntime.initSettled(), 'polls=$polls');
					check(mode + "_reports_failure", FmodRuntime.initFailed(), "");
					check(mode + "_pair_runs_on_failed", !pairReady && pairFailed == 1, 'failed=$pairFailed');
					check(mode + "_failure_reported_once", warns.length == 1, 'count=${warns.length}');
					if (mode == "staggered") check("staggered_slow_bank_loaded_at_settle", FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Master.bank")), 'polls=$polls');
					finish();
				}
			} else if (mode == "provided") {
				if (FmodRuntime.initSettled() || polls > 200) {
					js.Syntax.code("clearInterval({0})", timer);
					check("corrupt_provided_bank_settles", FmodRuntime.initSettled(), 'polls=$polls');
					check("corrupt_provided_bank_reports_failure", FmodRuntime.initFailed(), "");
					check("provided_pair_runs_on_failed", !pairReady && pairFailed == 1, 'failed=$pairFailed');
					check("provided_plain_handler_runs_anyway", readyFired, "");
					check("handlers_ran_after_ready", !ranBeforeReady, "");
					finish();
				}
			} else {
				// Give the failing fetches ample time to settle, then assert
				// that every bank was settled as a failure
				if (polls == 100) {
					js.Syntax.code("clearInterval({0})", timer);
					check("missing_banks_settle_initialized", FmodRuntime.isInitialized(), "");
					check("missing_banks_report_failure", FmodRuntime.initFailed(), "");
					check("pair_runs_on_failed", !pairReady && pairFailed == 1, 'failed=$pairFailed');
					check("plain_handler_runs_anyway", readyFired, "");
					check("handlers_ran_after_ready", !ranBeforeReady, "");
					// Counted before the state read below, which is a registry call
					// that warns on its own
					var warns = traces.filter(t -> t.indexOf("failed to load") >= 0);
					check("each_failure_reported_exactly_once", warns.length == 2, 'count=${warns.length}');
					var state = FmodRuntime.banks.loadingState(FmodRuntime.bankPath("Master.bank"));
					check("missing_bank_settled_error", state == FmodLoadingState.ERROR, 'state=${(state : Int)}');
					var late = 0;
					FmodRuntime.onceReady(() -> {}, () -> late++);
					check("late_pair_fails_at_once", late == 1, "");
					finish();
				}
			}
		});
	}
}
