package tests.jsruntime;

import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.FmodResult;
import haxefmod.studio.Types;

/**
 * The html5 initialization contract, driven through the shipped Haxe
 * runtime layer compiled to js against the real wasm (the tests/js
 * harnesses talk to jaxe.js directly and cannot see this layer).
 *
 * Two modes, selected by RUNTIME_TEST_MODE before the script loads:
 *   ok      - autoLoadBanks resolve: isInitialized() flips true only
 *             once the banks are usable, and onceReady fires.
 *   missing - the banks 404: isInitialized() stays false (the game's
 *             banks are unusable), the bank settles in ERROR, and the
 *             failure warning traces exactly once.
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
		FmodRuntime.onceReady(() -> readyFired = true);
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
					check("once_ready_fired", readyFired, "");
					check("banks_loaded", FmodRuntime.banks.isLoaded(FmodRuntime.bankPath("Master.bank")), "");
					finish();
				} else if (polls > 300) {
					js.Syntax.code("clearInterval({0})", timer);
					check("initialized_once_banks_usable", false, "timed out");
					finish();
				}
			} else {
				// Give the failing fetches ample time to settle, then assert
				// the gate held the whole way
				if (polls == 100) {
					js.Syntax.code("clearInterval({0})", timer);
					check("missing_banks_hold_init_false", !FmodRuntime.isInitialized(), "");
					check("once_ready_not_fired", !readyFired, "");
					var state = FmodRuntime.banks.loadingState(FmodRuntime.bankPath("Master.bank"));
					check("missing_bank_settled_error", state == FmodLoadingState.ERROR, 'state=${(state : Int)}');
					var warns = traces.filter(t -> t.indexOf("default bank failed to load") >= 0);
					check("failure_warned_exactly_once", warns.length == 1, 'count=${warns.length}');
					finish();
				}
			}
		});
	}
}
