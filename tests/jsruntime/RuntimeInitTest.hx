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
 * RUNTIME_TEST_MODE selects one of two modes before the script loads.
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
		FmodRuntime.onceReady(() -> readyFired = true);
		FmodRuntime.onceReady(() -> pairReady = true, () -> pairFailed++);
		FmodRuntime.init({
			bankFolder: folder,
			autoLoadBanks: ["Master.bank", "Master.strings.bank"],
		});
		check("init_not_ready_synchronously", !FmodRuntime.isInitialized(), "");

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
					check("banks_loaded", FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Master.bank")), "");
					finish();
				} else if (polls > 300) {
					js.Syntax.code("clearInterval({0})", timer);
					check("initialized_once_banks_usable", false, "timed out");
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
