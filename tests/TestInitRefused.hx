package tests;

import haxefmod.runtime.FmodRuntime;
import haxefmod.studio.Types;

/**
 * The refused system path on the stub backend. FMOD refuses the output
 * type, so the system never initializes. A process gets one init, so
 * this suite owns its own process.
 */
class TestInitRefused {
	static var passed = 0;
	static var failed = 0;

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	public static function main():Void {
		Sys.println("--- Init refused ---");
		var stub = haxefmod.studio.native.NativeStudioStub;
		var traces:Array<String> = [];
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) traces.push(Std.string(v));

		var readyRan = false;
		var failedRan = 0;
		var plainRan = 0;
		FmodRuntime.onceReady(() -> readyRan = true, () -> failedRan++);
		FmodRuntime.onceReady(() -> plainRan++);
		assert(!FmodRuntime.initSettled() && !FmodRuntime.initFailed(), "nothing is settled or failed before init");

		stub.testRefuseFormat = true;
		var result = FmodRuntime.init({output: FmodOutputType.NOSOUND});
		assert(!result.isOk(), "init reports the refusal");
		assert(FmodRuntime.initFailed() && !FmodRuntime.isInitialized() && FmodRuntime.initSettled(),
			"a refused system is failed and settled, never initialized");
		assert(traces.filter(t -> t.indexOf("refused") >= 0).length == 1, "the refusal is traced once");

		// The handlers registered before init run from update
		FmodRuntime.update();
		assert(!readyRan && failedRan == 1, "update runs onFailed for the pair");
		assert(plainRan == 1, "a handler with no onFailed runs anyway");
		var late = 0;
		var latePlain = 0;
		FmodRuntime.onceReady(() -> {}, () -> late++);
		FmodRuntime.onceReady(() -> latePlain++);
		assert(late == 1 && latePlain == 1, "handlers after the refusal run at once");
		FmodRuntime.update();
		assert(failedRan == 1 && plainRan == 1 && late == 1 && latePlain == 1, "every handler runs once");

		var manager = haxefmod.FmodManager;
		assert(manager.InitializeFailed() && manager.InitializeSettled() && !manager.IsInitialized(),
			"the helper class reports the same");

		Sys.println('  $passed passed, $failed failed');
		if (failed > 0) Sys.exit(1);
	}
}
