package tests;

import haxefmod.runtime.BankRegistry;
import haxefmod.runtime.FmodRuntime;

/**
 * The default bank failure path on the stub backend. A process gets one
 * init, so this suite owns its own process: the main suite initializes
 * with every bank provided, this one with a bank that cannot be.
 */
class TestPreloadFailure {
	static var passed = 0;
	static var failed = 0;

	static function assert(condition:Bool, name:String):Void {
		if (condition) passed++ else {
			failed++;
			Sys.println('  FAIL: $name');
		}
	}

	public static function main():Void {
		Sys.println("--- Preload failure ---");
		var stub = haxefmod.studio.native.NativeStudioStub;
		var traces:Array<String> = [];
		var originalTrace = haxe.Log.trace;
		haxe.Log.trace = function(v:Dynamic, ?infos:haxe.PosInfos) traces.push(Std.string(v));

		// The shims refuse empty data, and so does the stub
		var registry = new BankRegistry();
		stub.testSyntheticHandles = true;
		assert(registry.loadMemory("assets/fmod/Desktop/Empty.bank", haxe.io.Bytes.alloc(0)).isNull(), "loadMemory with no bytes fails");
		assert(!registry.isRegistered("assets/fmod/Desktop/Empty.bank"), "a failed memory load leaves no entry");

		// A loader that delivers no bytes has failed that bank
		FmodRuntime.provideBank("Master.bank", null);
		assert(FmodRuntime.initFailed(), "null bytes count as a failed bank");
		FmodRuntime.provideBankFailed("Master.bank", "reported again");
		var reports = traces.filter(t -> t.indexOf("Master.bank could not be provided") >= 0);
		assert(reports.length == 1 && reports[0].indexOf("delivered no bytes") >= 0, "a failed bank is reported once, with the first reason");

		// Handlers registered before init
		var readyRan = false;
		var failedRan = 0;
		FmodRuntime.onceReady(() -> readyRan = true, () -> failedRan++);

		FmodRuntime.provideBank("Master.strings.bank", haxe.io.Bytes.alloc(24));
		FmodRuntime.provideBank("Unrelated.bank", haxe.io.Bytes.alloc(8));
		stub.testBankMemoryLoads = [];
		FmodRuntime.init({autoLoadBanks: ["Master.bank", "Master.strings.bank"], banksProvided: true});

		// The stub never reports the system initialized, so the runtime's
		// own half of isInitialized is read directly
		assert(@:privateAccess FmodRuntime.defaultBanksLoaded, "the default banks are settled without the failed bank");
		assert(FmodRuntime.initFailed(), "initFailed stays true after init");
		assert(FmodRuntime.providedBankCount() == 1 && stub.testBankMemoryLoads.length == 1 && stub.testBankMemoryLoads[0] == 24,
			"the provided bank still loads from memory");
		assert(FmodRuntime.banks.isRegistered("assets/fmod/Desktop/Master.strings.bank"), "the loaded bank is registered");
		assert(!FmodRuntime.banks.isRegistered("assets/fmod/Desktop/Master.bank"), "the failed bank is not registered");
		assert(!FmodRuntime.allBanksProvided(), "a failed bank was never provided");
		assert(traces.filter(t -> t.indexOf("Unrelated.bank was provided but is not in autoLoadBanks") >= 0).length == 1,
			"a name outside autoLoadBanks is dropped with a warning");
		assert(traces.filter(t -> t.indexOf("Master.bank") >= 0 && t.indexOf("Error") >= 0).length == 1,
			"init does not report the failed bank a second time");

		// The failure wins over readiness, before and after init
		FmodRuntime.update();
		assert(!readyRan && failedRan == 1, "update runs onFailed instead of the ready handler");
		var lateReady = false;
		FmodRuntime.onceReady(() -> lateReady = true, () -> failedRan++);
		assert(!lateReady && failedRan == 2, "onceReady after init runs onFailed at once");
		FmodRuntime.update();
		assert(failedRan == 2, "a failed handler runs once");

		// Bytes for a bank the runtime already handled are dropped
		FmodRuntime.provideBank("Master.strings.bank", haxe.io.Bytes.alloc(24));
		FmodRuntime.update();
		assert(FmodRuntime.providedBankCount() == 1, "a bank provided after its load is ignored");

		haxe.Log.trace = originalTrace;
		Sys.println('  $passed passed, $failed failed');
		if (failed > 0) Sys.exit(1);
	}
}
